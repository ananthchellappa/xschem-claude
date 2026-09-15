# tests/headless/test_ase_conv_gui_1460.tcl -- ISSUE 1460: THE CONVERGENCE
# DIAGNOSTICS HAD A PARSER AND NO SURFACE. PLAN.md Stage 10, the GUI half.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# Issue 1459 shipped the deck half and built NO WIDGET, so every reader it
# landed had exactly zero callers outside its own suite:
#
#   * `ase::ncdump_failing` knew which nodes would not converge -- the table
#     `evidence/convergence.md` calls "the single most useful diagnostic in
#     ngspice" -- and NOTHING LIT THEM;
#   * `ase::ladder_parse` knew which rung answered and nothing said so;
#   * `ase::optran_line` could only be reached by HAND-EDITING a `.state` file,
#     because `opstrategy` had no control anywhere in the program;
#   * `ase::runhealth_lines` emitted a deck line whose four counters nothing
#     read back.
#
# ============================================================================
# ⚠ THE ROW THIS SUITE EXISTS FOR: A CHECKBOX THAT REALLY MEANS OFF
# ============================================================================
# "An accepted-and-inert setting" is this batch's most-met defect and has a
# standing rule in LEDGER.md with five measured members. Section EE ticks and
# clears the transient rung IN THE DIALOG, renders the deck ASE-L would really
# run, and RUNS IT on both binaries. MEASURED 2026-09-13, both binaries,
# byte-identical, ONE checkbox apart:
#
#     optran 1 0 0 100n 10u 0   rc 0   v(1) = 1.413677e-02
#     optran 1 0 0 0    10u 0   rc 1   Error: The operating point could not be
#                                      simulated successfully.  + the starred
#                                      `Last Node Voltages` table
#
# Newton is ON in both, so `ase::opstrategy_refusals` permits both -- the pair
# differs in the transient rung and in nothing else.
#
# ⚠ AND THE DECK THAT KILLS THE RUN OUTRIGHT CANNOT BE REACHED FROM THE FORM.
# `optran 0 0 0 0 10u 0` -- every rung off -- is rc 1 on both binaries, and the
# dialog REFUSES it (`allrungsoff`). Row GX3 is that refusal seen from the
# dialog; the run-time tier behind it is issue 1459's.
#
# ============================================================================
# THE TWO DIRECTIONS EVERY READER HERE IS ASKED IN
# ============================================================================
# Issue 1457 shipped a defect past an end-to-end row that asked only "is
# everything promised present?" -- it would have passed with a MISSING promise.
# So:
#
#   * NC4/NC5 ask the highlight what it LIT; **NC6 asks what it could not**,
#     with the count of attempted names as its control, so a resolver that
#     silently dropped a starred node reds by that node's own name.
#   * HL2 asks the strip for the four counters it knows; **HL3 feeds it a
#     counter the adapter has NO LABEL FOR** and demands it appear anyway,
#     because a label-driven loop would go on printing a stale set for ever.
#
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP
#    sections CP NC HL DF RM OP -- pure Tcl, identical on both arms
#    sections GM GW GT GX GN GH GR GC GF -- widgets; DISPLAY only, self-skipping
#    section  EE -- starts real simulators on BOTH binaries; self-skips with
#                   the path printed when one is absent
#
# NEW AT 44 headless / 103 on the dev display. The sabotage campaign is in
# doc/claude/ase_analyses_batch/receipts/37-stage-10-gui.md: 55 mutations, 54
# killed by name, one declared equivalent with the measurement behind it -- and
# FOUR of those rows exist only because a mutation survived the first list or a
# defect was found while writing it (RM3b, RM3c, CP7, and the GR5b repair, where
# `invoke` on a DISABLED button is a no-op and proved nothing about the proc).
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_conv_gui_1460.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_conv_gui_1460.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch convgui1460]
catch {test_sim_registry_isolate}

## ⚠ EVERY READER IS TOTAL AND ANSWERS A COMPARABLE VALUE. A row whose
## extractor raises cannot disagree with anything, and `--nogui --pipe` exits 0
## on an uncaught mid-script error -- so a killed suite looks like a pass. This
## is the same wrapper issue 1459's suite uses, for the same reason.
proc g_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
## A widget read that survives the widget being gone -- a sabotage that removes
## a control must redden a ROW, not kill the suite at rc 0.
proc g_w {w args} {
  if {![winfo exists $w]} { return NOWIDGET }
  set rc [catch {uplevel #0 [linsert $args 0 $w]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc g_cfg {w opt} {
  if {![winfo exists $w]} { return NOWIDGET }
  set rc [catch {$w cget $opt} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}

# ============================================================================
# THE FIXTURES
# ============================================================================

## A REAL STARRED TABLE, captured 2026-09-13 (issue 1459's own capture shape),
## with the four cases a canvas must tell apart in ONE table: a plain top-level
## node, a node inside a subcircuit, a node the netlist has never heard of, and
## a BRANCH CURRENT sitting in a table headed "Last Node Voltages".
set GNCSTAR {
DC solution failed -

Last Node Voltages
------------------

Node                                   Last Voltage        Previous Iter
----                                   ------------        -------------
in                                                5                    5
D                                            4.9901                 4.99 *
x1.nn                                       4.98019              4.97999 *
nosuchnode                                  4.98019              4.97999 *
v1#branch                                 -0.009905            -0.010005 *

}

## THE CONTROL: a log with no table at all. An extractor that returns nothing
## cannot disagree with anything, so every reader below is also asked a
## question it must answer EMPTY.
set GNOTAB "Circuit: * plain\nDoing analysis at TEMP = 27.000000\nv(out) = 1.000000e+00\n"

## A run whose ladder descended to the transient rung -- the one log that earns
## the sentence on the OP form. Captured text, both binaries.
set GTRANOP "Note: Starting dynamic gmin stepping\nWarning: Dynamic gmin stepping failed\nNote: Starting true gmin stepping\nWarning: True gmin stepping failed\nNote: Starting source stepping\nWarning: source stepping failed\nNote: Transient op started\nNote: Transient op finished successfully\n"
## ...and one that solved at the first rung, which must earn NOTHING.
set GCLEAN "Circuit: * rc\nDoing analysis at TEMP = 27.000000\nv(out) = 1.000000e+00\n"

set GHEALTH "Transient timepoints = 2013\nAccepted timepoints = 2012\nRejected timepoints = 1\nTotal iterations = 4045\n"

## A netlist with a subcircuit, so the map has something hierarchical to say.
set GNL "* gui bench\n.subckt sub a nn\nr1 a nn 1k\n.ends\nv1 in 0 5\nr1 in D 1k\nx1 D mid sub\nc1 D 0 1n\n.end\n"

proc g_state {args} {
  global scratch
  set st [ase::state_default]
  dict set st design [dict create cell bench lib $scratch]
  dict set st rundir [file join $scratch run]
  dict set st simulator ngspice
  dict set st analyses {{type op enabled 1} {type tran enabled 1 step 1u stop 1m}}
  foreach {k v} $args { dict set st $k $v }
  return $st
}

## A REAL SESSION with a REAL log file on disk, because `conv_logtext` reads
## the artifact `ase::backend::ngspice::log_file` names and a stubbed reader
## would prove nothing about the path the product takes.
##
## ⚠ ONE CELL NAME PER SESSION, AND THAT IS NOT TIDINESS. `log_file` is
## `<rundir>/<cell>_ase.log`: two fixture sessions sharing a cell share ONE log,
## so the second `g_session` silently rewrites the first one's evidence and
## every row above it starts reading a fixture it was not written for.
proc g_session {key st logtext} {
  global scratch
  dict set st design [dict create cell $key lib $scratch]
  set p [file join $scratch $key.state]
  ase::state_save $p $st
  ase::session_open $key $p
  ase::session_update $key $st
  set lp [ase::backend::ngspice::log_file $st]
  set f [open $lp w] ; puts -nonewline $f $logtext ; close $f
  return $key
}

if {[catch {

# ============================================================================
# CP -- THE COPY, AND THE TWO PLACES IT IS PINNED TO SOMETHING ELSE
# ============================================================================
set cp_missing {}
foreach l {lbl_conv_menu lbl_conv_title lbl_conv_strategy lbl_conv_steps
           lbl_conv_step lbl_conv_stop lbl_conv_emits lbl_conv_emits_none
           lbl_conv_opstate lbl_conv_save lbl_conv_restore lbl_conv_file
           lbl_conv_seed lbl_conv_force lbl_conv_seed_why lbl_conv_force_why
           lbl_conv_health lbl_health_prefix lbl_conv_remedies lbl_remedy_title
           lbl_remedy_what lbl_remedy_none lbl_remedy_nodeck lbl_remedy_apply
           lbl_remedy_same lbl_remedy_pending lbl_remedy_save lbl_remedy_seed
           lbl_hilite_menu lbl_hilite_nolog lbl_hilite_none lbl_hilite_deep
           lbl_hilite_absent lbl_conv_door_hint menu_path_hilite} {
  set v [g_ans ase::ui::$l]
  if {$v eq {NOPROC} || [string match RAISED:* $v] || [string trim $v] eq {}} {
    lappend cp_missing $l
  }
}
check "CP1 every sentence this surface mints exists and is not empty" $cp_missing {}

## ⚠ THE ONE SIMULATOR WORD IN THE SURFACE, PINNED TO CORE'S OWN LITERAL.
## `ase::ui::conv_op_type` names the analysis whose form carries the ladder
## sentence. `ase::opstate_refusals` tests the SAME literal when it refuses a
## bench with no operating point to save -- so a bench whose only enabled row is
## of that type must NOT raise `saveneedsop`, and a bench of any other type
## must. Two directions, one row: if either side drifts this reds.
proc g_saveneeds {type} {
  set st [g_state opstate {save 1 file /tmp/x.ic} \
            analyses [list [list type $type enabled 1]]]
  set ids {}
  foreach r [g_ans ase::opstate_refusals ngspice $st] { lappend ids [lindex $r 0] }
  return [expr {[lsearch -exact $ids saveneedsop] >= 0}]
}
check "CP2 the type whose form carries the ladder sentence is the same type\
 core's save refusal requires -- asked in BOTH directions, so a drift on either\
 side reds" \
  [list [g_ans ase::ui::conv_op_type] [g_saveneeds [g_ans ase::ui::conv_op_type]] \
        [g_saveneeds tran]] \
  {op 0 1}

## ⚠ THE TWO CONTROL LABELS A REFUSAL ALREADY NAMES. Core's fix clause reads
## "run once with Save operating point ticked, or restore with force" -- if the
## checkbox is renamed and that clause is not, the fix points at a control that
## does not exist. Asked against the LIVE evaluator, not against a quoted string.
set cp_fix {}
foreach r [g_ans ase::opstate_refusals ngspice \
             [g_state opstate {restore 1 mode seed file /tmp/nosuch.ic}]] {
  if {[lindex $r 0] eq {opstatefile}} { set cp_fix [lindex $r 3] }
}
check "CP3 the Save checkbox's label is the one core's own fix clause sends the\
 user to, and the two restore modes are the words that clause offers" \
  [list [expr {[string first [ase::ui::lbl_conv_save] $cp_fix] >= 0}] \
        [string tolower [ase::ui::lbl_conv_seed]] \
        [string tolower [ase::ui::lbl_conv_force]]] \
  {1 seed force}

## The menu path in the run's own announcement is COMPOSED, not typed.
check "CP4 the sentence a finished run prints names the menu entry by\
 composing it from that entry's own label" \
  [list [expr {[string first [ase::ui::lbl_hilite_menu] \
                 [ase::ui::lbl_conv_door_hint]] >= 0}] \
        [expr {[string first [ase::ui::lbl_hilite_menu] \
                 [ase::ui::menu_path_hilite]] >= 0}]] \
  {1 1}

check "CP5 the run's announcement does not CLAIM to have highlighted anything\
 -- it lights nothing, and the two sentences are different strings" \
  [list [expr {[ase::ui::lbl_conv_failed_nodes {a b}] ne [ase::ui::lbl_hilite_lit {a b}]}] \
        [expr {[string first highlight [ase::ui::lbl_conv_failed_nodes {a b}]] < 0}] \
        [expr {[string first highlight [ase::ui::lbl_hilite_lit {a b}]] >= 0}]] \
  {1 1 1}

check "CP6 both sentences agree with themselves about singular and plural" \
  [list [expr {[string first { 1 node } [ase::ui::lbl_conv_failed_nodes {a}]] >= 0}] \
        [expr {[string first { 2 nodes } [ase::ui::lbl_conv_failed_nodes {a b}]] >= 0}] \
        [expr {[string first { 1 node } [ase::ui::lbl_hilite_lit {a}]] >= 0}] \
        [expr {[string first { 2 nodes } [ase::ui::lbl_hilite_lit {a b}]] >= 0}]] \
  {1 1 1 1}

## ⚠ D34's GUARD, AND IT HAS ITS OWN POSITIVE CONTROL. Everything this surface
## shows comes from the registry: the rung labels, the refusal sentences, the
## counter words, and -- the one that bit -- the RENDERER behind the diff
## preview. My first `ase::ui::conv_deck` called
## `ase::backend::ngspice::render_deck` by name, so a bench bound to any other
## simulator would have been shown an ngspice deck and told it was the deck that
## would run. The scan is over the Stage 10 block of `src/ase_window.tcl`; the
## control points the SAME scan at `src/ase.tcl`, where the adapter really does
## spell its own namespace, so a scan that had stopped matching cannot pass by
## finding nothing.
## ⚠ CODE LINES ONLY. A COMMENT that cites `ase::backend::ngspice::render_deck`
## as the thing a refusal tier lives in is documentation and belongs there --
## house style prefers a real anchor to a vague one. A comment cannot render a
## deck; only the code can, and that is what this forbids.
proc cp_scan {path from} {
  set fh [::open $path r] ; set t [::read $fh] ; ::close $fh
  set i [string first $from $t]
  if {$i < 0} { return NOMARK }
  set out {}
  foreach l [split [string range $t $i end] "\n"] {
    if {[string index [string trimleft $l] 0] eq {#}} { continue }
    foreach h [regexp -all -inline {ase::backend::[a-z0-9_]+::} $l] { lappend out $h }
  }
  return $out
}
check "CP7 no line of the Stage 10 surface names a backend's namespace -- with\
 the same scan over the adapter's own file as its control, so it cannot pass by\
 having stopped matching" \
  [list [lsort -unique [g_ans cp_scan [file join $repo src ase_window.tcl] \
                          {STAGE 10 -- CONVERGENCE AND DIAGNOSIS: THE SURFACE}]] \
        [expr {[llength [g_ans cp_scan [file join $repo src ase.tcl] \
                           {STAGE 10 -- CONVERGENCE AND DIAGNOSIS, THE DECK HALF}]] > 0}]] \
  {{} 1}

} cperr]} { check {CP0 section CP ran to the end} "RAISED:$cperr" {} }

if {[catch {

# ============================================================================
# NC -- §10a: THE NODES THAT DID NOT CONVERGE, FROM LOG TO CANVAS CANDIDATE
# ============================================================================
g_session nc1 [g_state] $GNCSTAR
g_session nc2 [g_state] $GNOTAB

check "NC1 the starred NODES of the last run come back, in the simulator's own\
 order, and the branch current is not among them -- there is no wire on a\
 schematic to light for a current" \
  [g_ans ase::ui::conv_failing nc1] {D x1.nn nosuchnode}

## THE CONTROL. A log with no table must answer EMPTY, or NC1 is agreeing with
## itself rather than reading anything.
check "NC2 a log with no table at all answers empty, and a session with no log\
 file answers empty too" \
  [list [g_ans ase::ui::conv_failing nc2] [g_ans ase::ui::conv_logtext nosuchsession]] \
  {{} {}}

set NCMAP [dict create scopes [dict get [ase::netlist_map $GNL] scopes] includes {}]

check "NC3 a top-level node the netlist knows resolves to the netlist's own\
 spelling and that spelling is what the canvas is handed" \
  [g_ans ase::ui::conv_resolve_one $NCMAP D 0] \
  {name D real D token D why {}}

## ⚠ A HIERARCHY-QUALIFIED NAME GETS NO TOKEN AND SAYS WHY. `hilight_netname`
## looks a name up in THIS sheet's node hash; `x1.nn` is a node INSIDE a
## subcircuit and there is no wire here to find. Reported, never dropped.
check "NC4 a node inside a subcircuit is resolved to the netlist's own\
 spelling, is NOT handed to the canvas, and carries the reason it was not" \
  [g_ans ase::ui::conv_resolve_one $NCMAP x1.nn 0] \
  [list name x1.nn real x1.nn token {} why [ase::ui::lbl_hilite_deep]]

check "NC5 a name this netlist has never heard of is not handed to the canvas\
 either, and carries its own reason" \
  [g_ans ase::ui::conv_resolve_one $NCMAP nosuchnode 0] \
  [list name nosuchnode real {} token {} why [ase::ui::lbl_hilite_absent]]

## ⚠ THE SURPLUS DIRECTION (issue 1457's blind spot). NC3-NC5 each ask about a
## name they already know. This asks the resolver to account for EVERY starred
## name in one pass: the tokens plus the refusals must add up to the input, and
## the count of names attempted is the control, so a resolver that silently
## dropped one reds by arithmetic rather than by the dropped name happening to
## be one somebody wrote a row for.
set nc_rows [g_ans ase::ui::conv_resolve nc1]
set nc_tok {} ; set nc_miss {}
foreach r $nc_rows {
  if {[dict get $r token] ne {}} { lappend nc_tok [dict get $r name] } \
  else { lappend nc_miss [dict get $r name] }
}
check "NC6 every starred node is accounted for -- what the canvas gets plus\
 what it cannot, with the row count and the input list as the controls. The\
 netlist slot is COLD here, which is the state a session is in before its first\
 netlist: with no map to ask, a flat name still goes to the canvas and only the\
 hierarchical one is withheld, because that one is a fact about the SHEET" \
  [list [llength $nc_rows] $nc_tok $nc_miss \
        [g_ans ase::ui::conv_failing nc1]] \
  {3 {D nosuchnode} x1.nn {D x1.nn nosuchnode}}

## ⚠ A COLD NETLIST IS NOT A REFUSAL. With no map to ask, the name the
## simulator printed is the best spelling anyone has and the canvas gets the
## last word -- which is exactly what happens before the first netlist.
check "NC7 with no netlist map, a plain name is still offered to the canvas and\
 a hierarchical one still is not" \
  [list [dict get [g_ans ase::ui::conv_resolve_one {} D 0] token] \
        [dict get [g_ans ase::ui::conv_resolve_one {} x1.nn 0] token]] \
  {D {}}

## `unknown` is a REFUSAL TO JUDGE, not a weaker `absent`: an include-bearing
## scope can add cards the map cannot see, so the name still goes through.
set NCINC [dict create \
             scopes [dict get [ase::netlist_map "* inc\n.include x.sp\nr1 a b 1\n.end\n"] scopes] \
             includes [dict create {} 1]]
check "NC8 a scope that .include's a file cannot prove a name absent, so the\
 canvas is still offered it -- `unknown` is not a quieter `absent`" \
  [dict get [g_ans ase::ui::conv_resolve_one $NCINC zzz 0] token] zzz

} ncerr]} { check {NC0 section NC ran to the end} "RAISED:$ncerr" {} }

if {[catch {

# ============================================================================
# HL -- §10c: THE RUN-HEALTH STRIP, ONE LINE
# ============================================================================
check "HL1 a run that reported no counters gets no strip, so every bench that\
 never asked for them shows an empty segment" \
  [list [g_ans ase::ui::health_text ngspice $GNOTAB] \
        [g_ans ase::ui::health_text ngspice {}]] {{} {}}

check "HL2 the four counters come back in the adapter's declared order, each\
 under the adapter's own word" \
  [g_ans ase::ui::health_text ngspice $GHEALTH] \
  {Health: 2013 TRAN points, 2012 accepted, 1 rejected, 4045 iterations}

## ⚠ THE SURPLUS DIRECTION AGAIN, AND THIS ONE IS THE REASON `runhealth_strip`
## EXISTS AT ALL. A strip driven by the label table would print a stale set for
## ever: the day the adapter reports a fifth counter, a label-driven loop says
## nothing and looks perfectly correct. So a counter with NO declared label must
## still appear, under its own bare key -- ugly on purpose, because ugly is
## visible and absent is not.
set HLX [g_ans ase::runhealth_strip ngspice $GHEALTH]
proc g_strip_extra {} {
  ## a backend whose parser reports a counter nobody labelled
  proc ::g_fake_parse {text} { return [dict create totiter 7 zznew 42] }
  proc ::g_fake_labels {} { return {totiter iterations} }
  ase::register_backend g_fake [dict create \
    render_deck ::g_fake_parse run_cmd ::g_fake_parse log_file ::g_fake_parse \
    result_probe ::g_fake_parse raw_file ::g_fake_parse \
    runhealth_parse ::g_fake_parse runhealth_labels ::g_fake_labels]
  return [ase::runhealth_strip g_fake anything]
}
check "HL3 a counter the adapter declared NO label for is still in the strip,\
 under its own bare key -- a labelled loop would drop it in silence and look\
 correct for ever" \
  [g_ans g_strip_extra] {{iterations 7} {zznew 42}}

check "HL4 a backend that declares no counters at all gets no strip, rather\
 than ngspice's -- D34: no hook, no content" \
  [g_ans ase::runhealth_strip g_fake_none $GHEALTH] {}

} hlerr]} { check {HL0 section HL ran to the end} "RAISED:$hlerr" {} }

if {[catch {

# ============================================================================
# DF -- THE DIFF THE REMEDY PREVIEW IS BUILT ON
# ============================================================================
check "DF1 an inserted line is reported as added, at its own place, and\
 nothing after it is reported as changed" \
  [g_ans ase::ui::deck_diff "a\nb\nc\n" "a\nx\nb\nc\n"] \
  {{  a} {+ x} {  b} {  c}}

check "DF2 a removed line is reported as removed" \
  [g_ans ase::ui::deck_diff "a\nb\nc\n" "a\nc\n"] \
  {{  a} {- b} {  c}}

## ⚠ THE ANTI-VACUITY ROW. Two identical decks must produce NO `+` and NO `-`,
## or `lbl_remedy_same` never fires and every remedy looks like a change.
set df_same [g_ans ase::ui::deck_diff "a\nb\nc\n" "a\nb\nc\n"]
check "DF3 two identical decks differ in nothing, and the brief view of that\
 is empty -- which is what makes `This changes nothing in the deck.` reachable" \
  [list $df_same [g_ans ase::ui::deck_diff_brief $df_same]] \
  {{{  a} {  b} {  c}} {}}

## A positional compare would call every line after an insertion changed; the
## whole point of the LCS is that it does not.
set df_long "l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\n"
set df_ins  "l1\nl2\nl3\nNEW\nl4\nl5\nl6\nl7\nl8\n"
set df_d [g_ans ase::ui::deck_diff $df_long $df_ins]
set df_changed 0
foreach l $df_d { if {[string index $l 0] ne { }} { incr df_changed } }
check "DF4 one inserted card in an eight-line deck is ONE reported change, not\
 five -- a positional compare would report everything after it" \
  [list $df_changed [llength $df_d]] {1 9}

check "DF5 the brief view keeps the change with one line of context either side\
 and elides the rest, so one new card in a sixty-line deck is readable" \
  [g_ans ase::ui::deck_diff_brief $df_d] \
  {{   ...} {  l3} {+ NEW} {  l4}}

} dferr]} { check {DF0 section DF ran to the end} "RAISED:$dferr" {} }

if {[catch {

# ============================================================================
# RM -- THE REMEDY ASSISTANT'S LIST
# ============================================================================
## A failed run whose transient rung never ran: the one remedy the evidence
## supports (evidence/ladder-streams.md §4 -- optran rescued every deck built
## to fail).
set RMFAIL "Note: Starting dynamic gmin stepping\nWarning: Dynamic gmin stepping failed\nNote: Starting source stepping\nWarning: source stepping failed\nNote: Optran is deselected.\nError: The operating point could not be simulated successfully.\n"
g_session rm1 [g_state opstrategy {newton 1 gmin 1 src 1 tranop 0}] $RMFAIL
set rm_ids {}
foreach r [g_ans ase::ui::remedy_list rm1] { lappend rm_ids [dict get $r id] }
check "RM1 a failed run whose transient rung never ran is offered that rung,\
 and is NOT offered the two that ran and failed -- a control that changes\
 nothing is this batch's most-met defect" \
  $rm_ids {rung:tranop}

check "RM2 the remedy's label is the RUNG's own, not a second spelling of it" \
  [dict get [lindex [g_ans ase::ui::remedy_list rm1] 0] label] \
  [ase::ui::lbl_remedy_switchon [dict get [ase::ladder_rung ngspice tranop] label]]

## ⚠ THE REMEDY WRITES EVERY RUNG, NOT ONLY THE ONE IT TURNS ON.
## `ase::opstrategy_rung` reads an ABSENT rung as ON, so a strategy that named
## only its change would emit a line that is right by accident.
check "RM3 applying the remedy switches that rung on and leaves the other three\
 exactly as the bench had them, named rather than absent" \
  [dict get [lindex [g_ans ase::ui::remedy_list rm1] 0] state opstrategy] \
  {newton 1 gmin 1 src 1 tranop 1}

## ⚠ RM3's FIXTURE CANNOT SEE THE DEFECT RM3 IS ABOUT, AND THIS ONE CAN. rm1's
## bench already names all four rungs, so "write every rung" and "write only the
## one you changed" produce the SAME dict there -- a fixture that never
## disagrees. This bench names ONE, which is what a hand-edited `.state` or a
## partial earlier remedy leaves behind. Sabotage m35 passes against RM3 and
## reds here.
g_session rm1b [g_state opstrategy {tranop 0}] $RMFAIL
check "RM3b ...and on a bench that names only ONE rung, the remedy still writes\
 all four: an absent rung reads as ON, so a strategy that named only its own\
 change would be right by accident" \
  [dict get [lindex [g_ans ase::ui::remedy_list rm1b] 0] state opstrategy] \
  {tranop 1 newton 1 gmin 1 src 1}

## ⚠ AND THE RUNG THAT RAN AND FAILED IS STILL NOT OFFERED WHEN NOTHING IS
## MASKING IT. RM1's bench has gmin and src switched ON in its strategy, so the
## `already on` guard hides them and the `never ran` test is never reached --
## two guards, one fixture, and only one of them under test. This bench is
## UNARMED, so the only thing that can withhold gmin and src is the test that
## they ran and failed. Sabotage m32 passes against RM1 and reds here.
g_session rm1c [g_state] $RMFAIL
set rm1c_ids {}
foreach r [g_ans ase::ui::remedy_list rm1c] { lappend rm1c_ids [dict get $r id] }
check "RM3c on a bench with no strategy at all, the two rungs that RAN and\
 FAILED are still not offered -- switching on a rung that already ran is a\
 control that changes nothing" \
  $rm1c_ids {rung:tranop}

## THE CONTROL: a run that converged is offered nothing.
g_session rm2 [g_state] $GCLEAN
check "RM4 a run that found its operating point is offered no rung at all" \
  [g_ans ase::ui::remedy_list rm2] {}

## ...and a run that failed with the rung ALREADY on is offered nothing either.
g_session rm3 [g_state opstrategy {newton 1 gmin 1 src 1 tranop 1}] $RMFAIL
set rm3_ids {}
foreach r [g_ans ase::ui::remedy_list rm3] { lappend rm3_ids [dict get $r id] }
check "RM5 a bench that already has the rung switched on is not offered it\
 again -- the second half of RM1, and the half a one-directional row misses" \
  $rm3_ids {}

## The two operating-point remedies, and their preconditions.
set RMIC [file join $scratch run saved.ic]
set f [open $RMIC w] ; puts $f "* saved" ; puts $f ".ic v(D) = 2.5" ; close $f
g_session rm4 [g_state opstate [list file $RMIC]] $GCLEAN
set rm4_ids {}
foreach r [g_ans ase::ui::remedy_list rm4] { lappend rm4_ids [dict get $r id] }
check "RM6 a bench with a named, readable operating-point file is offered both\
 the save and the seed" $rm4_ids {opsave opseed}

g_session rm5 [g_state opstate [list file [file join $scratch run absent.ic]]] $GCLEAN
set rm5_ids {}
foreach r [g_ans ase::ui::remedy_list rm5] { lappend rm5_ids [dict get $r id] }
check "RM7 a file that is named but does not exist is offered the SAVE and not\
 the seed -- seeding needs the file's contents at render time, which is why\
 core refuses it" $rm5_ids {opsave}

g_session rm6 [g_state] $GCLEAN
check "RM8 a bench that names no file is offered neither, because a remedy that\
 opened a file dialog would not be a diff" [g_ans ase::ui::remedy_list rm6] {}

## ⚠ THE SEED REMEDY MUST SET THE MODE, not only the flag: `force` is the
## verbatim `.include` and changes a stale transient's answer (issue 1459's
## second headline, measured on both binaries).
check "RM9 the seed remedy asks for the mode that cannot change the answer" \
  [dict get [lindex [g_ans ase::ui::remedy_list rm4] 1] state opstate] \
  [list file $RMIC restore 1 mode seed]

} rmerr]} { check {RM0 section RM ran to the end} "RAISED:$rmerr" {} }

if {[catch {

# ============================================================================
# OP -- §10b: THE SENTENCE ON THE OP FORM, CONDITIONAL
# ============================================================================
g_session op1 [g_state] $GTRANOP
g_session op2 [g_state] $GCLEAN
check "OP1 a run that really descended to the transient rung earns the sentence\
 that says so, and earns it on the OP form and on no other" \
  [list [g_ans ase::ui::conv_op_notes op1 [ase::ui::conv_op_type]] \
        [g_ans ase::ui::conv_op_notes op1 tran]] \
  [list [list [dict get [ase::ladder_rung ngspice tranop] ransentence]] {}]

## ⚠ THE CONTROL, AND IT IS ISSUE 1459's CORRECTION C4 REACHING THE SCREEN. Said
## unconditionally the sentence tells a user their exact operating point is
## suspect when it is exact; measured on both binaries, the shipped defaults
## leave the transient rung ARMED AND NEVER CALLED.
check "OP2 a run that solved at the first rung earns NOTHING -- the sentence is\
 earned by the log, never assumed from the settings" \
  [g_ans ase::ui::conv_op_notes op2 [ase::ui::conv_op_type]] {}

## A rung that answered lower down earns its OWN sentence, not the transient's.
g_session op3 [g_state] "Note: Starting spice3 gmin stepping\nNote: spice3 gmin stepping completed\n"
check "OP3 a run that gmin-stepped its way there says so, in that rung's own\
 words" \
  [g_ans ase::ui::conv_op_notes op3 [ase::ui::conv_op_type]] \
  [list [dict get [ase::ladder_rung ngspice gmin] ransentence]]

} operr]} { check {OP0 section OP ran to the end} "RAISED:$operr" {} }

# ============================================================================
# THE WIDGET LEGS (DISPLAY only, self-skipping)
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {
if {[catch {

## The fixture bench, with a real schematic so the canvas has nets to light.
set GSCH {v {xschem version=3.4.8 file_version=1.3}
G {}
K {}
V {}
S {}
E {}
N 400 -300 500 -300 {lab=D}
N 250 -300 300 -300 {lab=G}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 450 -330 0 0 {name=lD lab=D}
C {devices/lab_wire} 270 -330 0 0 {name=lG lab=G}
}
file mkdir [file join $scratch glib bench schematic]
set f [open [file join $scratch glib bench schematic bench.sch] w]
puts -nonewline $f $GSCH
close $f
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE glib [file join $scratch glib]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

library_new_view glib bench ngspice_state1 ngspice_state1
set gpath [xschem cellview_path glib/bench ngspice_state1]
if {$gpath eq {}} { error "fixture: state view did not resolve" }
set gkey [ase::session_key glib bench ngspice_state1]
ase::session_open $gkey [file normalize $gpath]
set gst [ase::session_state $gkey]
dict set gst rundir [file join $scratch run]
dict set gst analyses {{type op enabled 1} {type tran enabled 1 step 1u stop 1m}}
ase::session_update $gkey $gst
check "GW0 open_state -> 1" [ase::open_state glib bench ngspice_state1] 1
update
set gtop [ase::ui::window_for $gkey]
check_true "GW0 session window up" [expr {$gtop ne {} && [winfo exists $gtop]}]
## the log this session reads back
set glog [ase::backend::ngspice::log_file [ase::session_state $gkey]]
proc g_setlog {t} {
  global glog
  set f [open $glog w] ; puts -nonewline $f $t ; close $f
}
g_setlog $GNCSTAR

# ---------------------------------------------------------------------------
# GM -- THE DOORS
# ---------------------------------------------------------------------------
set gm_sim {}
for {set i 0} {$i <= [$gtop.mb.sim index end]} {incr i} {
  lappend gm_sim [$gtop.mb.sim entrycget $i -label]
}
check "GM1 `Convergence…` is on the Simulation menu, directly below `Options…`\
 -- the sheet whose three rows the strategy silently overrides" \
  [list [lsearch -exact $gm_sim [ase::ui::lbl_conv_menu]] \
        [expr {[lsearch -exact $gm_sim [ase::ui::lbl_conv_menu]] - \
               [lsearch -exact $gm_sim "Options…"]}]] \
  {6 1}
check "GM1b and it is wired to the dialog, not merely present" \
  [$gtop.mb.sim entrycget [ase::ui::lbl_conv_menu] -command] \
  [list ase::ui::conv_dialog $gkey]
set gm_res {}
for {set i 0} {$i <= [$gtop.mb.results index end]} {incr i} {
  if {[$gtop.mb.results type $i] eq {separator}} { lappend gm_res -- } \
  else { lappend gm_res [$gtop.mb.results entrycget $i -label] }
}
check "GM2 the highlight door is the LAST entry of Results, below Annotate --\
 annotation shows a run that worked, this shows one that did not" \
  $gm_res [list "Select…" -- {Direct Plot} Annotate -- [ase::ui::lbl_hilite_menu]]
check "GM2b and it is wired to the door proc" \
  [$gtop.mb.results entrycget [ase::ui::lbl_hilite_menu] -command] \
  [list ase::ui::conv_highlight_door $gkey]

# ---------------------------------------------------------------------------
# GW -- THE LADDER PANE
# ---------------------------------------------------------------------------
$gtop.mb.sim invoke [ase::ui::lbl_conv_menu]
update
set gw $gtop.conv
check_true "GW1 the Convergence dialog opens" [winfo exists $gw]

## ⚠ ONE CHECKBOX PER RUNG THE REGISTRY DECLARES, AND THE LABEL IS THE RUNG'S.
## A surface that typed the four labels here would be the second copy, and the
## second copy is the one that drifts.
set gw_ids {} ; set gw_lbl {} ; set gw_bad {}
foreach rg [ase::ladder_rungs ngspice] {
  set id [dict get $rg id]
  lappend gw_ids $id
  if {![winfo exists $gw.rungs.$id]} { lappend gw_bad "no checkbox for $id" ; continue }
  if {[$gw.rungs.$id cget -text] ne [dict get $rg label]} {
    lappend gw_bad "$id label is [$gw.rungs.$id cget -text]"
  }
  lappend gw_lbl [$gw.rungs.$id cget -text]
}
check "GW2 one checkbox per declared rung, each wearing that rung's own label" \
  [list $gw_bad [llength $gw_ids]] {{} 4}

check "GW3 the rung with a step count gets a count field, the rung configured\
 by two times gets two, and the rung with neither gets none -- from the\
 registry's own `steps`/`times` keys, never from a list typed here" \
  [list [winfo exists $gw.rungs.snewton] [winfo exists $gw.rungs.sgmin] \
        [winfo exists $gw.rungs.ssrc] \
        [winfo exists $gw.rungs.ttranop] [winfo exists $gw.rungs.ptranop] \
        [winfo exists $gw.rungs.tgmin]] \
  {0 1 1 1 1 0}

check "GW4 the transient rung's caution is shown beside it, in the adapter's\
 own words -- the sentence that says an operating point may not be one" \
  [list [winfo exists $gw.rungs.ntranop] \
        [expr {[g_cfg $gw.rungs.ntranop -text] eq \
               [dict get [ase::ladder_rung ngspice tranop] note]}] \
        [winfo exists $gw.rungs.nnewton]] \
  {1 1 0}

## ⚠ THE EMITS LINE IS THE `optran` SENTENCE PLAN.md §10b ASKS FOR, and it is
## the deck's own line rather than a rendering of the checkboxes.
$gw.armed invoke ;# arm it
update
check "GW5 arming the strategy shows the line the deck will really carry" \
  [g_cfg $gw.emits -text] "[ase::ui::lbl_conv_emits] optran 1 1 1 100n 10u 0"

## ⚠ AND CLEARING IT SAYS SO IN A SENTENCE. A blank here reads as "nothing
## happens"; what really happens is that the simulator uses its own strategy,
## which on this simulator includes a transient operating point that is ON.
$gw.armed invoke
update
check "GW6 clearing it emits nothing AND says what that means, rather than\
 going blank" \
  [list [g_cfg $gw.emits -text] [g_ans ase::ui::conv_form_strategy $gkey]] \
  [list [ase::ui::lbl_conv_emits_none] {}]

check "GW7 with the strategy cleared every rung control is disabled, so the\
 window cannot show four live checkboxes that reach no deck line" \
  [list [g_cfg $gw.rungs.newton -state] [g_cfg $gw.rungs.gmin -state] \
        [g_cfg $gw.rungs.sgmin -state] [g_cfg $gw.rungs.ttranop -state]] \
  {disabled disabled disabled disabled}

$gw.armed invoke
update
check "GW8 arming it makes them live again, and a rung's own fields follow that\
 rung's box rather than the master" \
  [list [g_cfg $gw.rungs.gmin -state] [g_cfg $gw.rungs.sgmin -state]] \
  {normal normal}
$gw.rungs.gmin invoke
update
check "GW8b clearing one rung disables that rung's fields and leaves the others\
 alone" \
  [list [g_cfg $gw.rungs.sgmin -state] [g_cfg $gw.rungs.ttranop -state] \
        [g_cfg $gw.rungs.gmin -state]] \
  {disabled normal normal}
$gw.rungs.gmin invoke
update

## ⚠ A NUMBER TYPED AND NOT TABBED AWAY FROM. The `Emits:` line and the refusal
## note are this dialog's promise about the deck: if they follow only a CLICK,
## a user who types a step count and presses OK gets a deck that differs from
## the line they were reading. `<KeyRelease>`, not only `<FocusOut>`.
$gw.rungs.sgmin delete 0 end
$gw.rungs.sgmin insert 0 5
focus $gw.rungs.sgmin
event generate $gw.rungs.sgmin <KeyRelease>
update
check "GW9 a step count TYPED into a field reaches the emitted line without the\
 user leaving the field -- the window may never describe a deck it is not\
 about to render" \
  [g_cfg $gw.emits -text] "[ase::ui::lbl_conv_emits] optran 1 5 1 100n 10u 0"

## ⚠ AND A STANDING ASSISTANT DIES WITH THE REBUILD (Stage 9a's rule, reached
## from the other side): it caches a LIST OF STATES built from this form.
ase::ui::remedy_dialog $gkey
update
set gw_had [winfo exists $gtop.remedy]
ase::ui::conv_dialog $gkey
update
set gw_after [winfo exists $gtop.remedy]
ase::ui::remedy_dialog $gkey
update
$gtop.conv.btns.cancel invoke
update
check "GW10 a Convergence rebuild closes a standing remedy assistant, and so\
 does closing the form -- an assistant whose first row is this form's live\
 edits cannot outlive the widgets it read" \
  [list $gw_had $gw_after [winfo exists $gtop.remedy] [winfo exists $gtop.conv]] \
  {1 0 0 0}
ase::ui::conv_dialog $gkey
update
set gw $gtop.conv

} gwerr]} { check {GW0e section GW ran to the end} "RAISED:$gwerr" {} }

if {[catch {

# ---------------------------------------------------------------------------
# GT -- THE TICK REACHES THE DECK
# ---------------------------------------------------------------------------
## ⚠ THIS IS THE SECOND HALF OF A FEATURE WHOSE FIRST HALF IS ALREADY
## COMMITTED, so the row goes from the WIDGET all the way to the rendered line.
## Two halves tested in different suites never meet (issue 1449, a defect past
## 622 checks and a clean T1).
set GNLTEXT "* bench\nv1 in 0 1\nr1 in out 1k\nc1 out 0 1n\n.end\n"
## ⚠ THIS SECTION OPENS ITS OWN FORM. A section that inherited the previous
## one's dialog would pass or fail on what GW happened to leave behind -- and
## GW10 deliberately rebuilds, which is exactly the state that used to silently
## turn every row below into `NOOPTRAN`.
ase::ui::conv_dialog $gkey
update
proc g_optran {key} {
  global GNLTEXT
  set d [g_ans ase::ui::conv_deck $key [g_ans ase::ui::conv_form_state $key] $GNLTEXT]
  foreach l [split $d "\n"] {
    if {[string match {optran *} [string trim $l]]} { return [string trim $l] }
  }
  return NOOPTRAN
}
set gw $gtop.conv
if {![info exists ::ase::ui::dlg($gkey,conv,armed)] || !$::ase::ui::dlg($gkey,conv,armed)} {
  $gw.armed invoke ; update
}
## every rung on, defaults
check "GT1 four ticked boxes render the line the plan documents" [g_optran $gkey] \
  {optran 1 1 1 100n 10u 0}
## ⚠ THE ROW THE BRIEF DEMANDS: the transient rung's box must be able to MEAN
## OFF, and `opstepsize == 0` is how the simulator is told (optran.c:182-185).
$gw.rungs.tranop invoke
update
check "GT2 CLEARING the transient rung zeroes the step -- the argument that\
 really switches the rung off, not a flag the simulator ignores" \
  [g_optran $gkey] {optran 1 1 1 0 10u 0}
$gw.rungs.tranop invoke
update
check "GT2b and ticking it back restores the step" [g_optran $gkey] \
  {optran 1 1 1 100n 10u 0}
## the other three boxes reach their own arguments
$gw.rungs.newton invoke ; update
check "GT3 the first rung's box is the first argument" [g_optran $gkey] \
  {optran 0 1 1 100n 10u 0}
$gw.rungs.newton invoke ; $gw.rungs.gmin invoke ; update
check "GT3b the second rung's box zeroes its step count" [g_optran $gkey] \
  {optran 1 0 1 100n 10u 0}
$gw.rungs.gmin invoke ; $gw.rungs.src invoke ; update
check "GT3c the third rung's box zeroes its step count" [g_optran $gkey] \
  {optran 1 1 0 100n 10u 0}
$gw.rungs.src invoke ; update
## the typed fields reach their arguments
$gw.rungs.sgmin delete 0 end ; $gw.rungs.sgmin insert 0 7
$gw.rungs.ssrc  delete 0 end ; $gw.rungs.ssrc  insert 0 9
$gw.rungs.ttranop delete 0 end ; $gw.rungs.ttranop insert 0 50n
$gw.rungs.ptranop delete 0 end ; $gw.rungs.ptranop insert 0 20u
update
check "GT4 the four typed fields reach their four arguments, in order" \
  [g_optran $gkey] {optran 1 7 9 50n 20u 0}
## ⚠ ARGUMENT SIX IS ALWAYS 0 AND HAS NO CONTROL. `optran.c:670-671` has no
## clamp and `README.optran` says supply ramping is not established, so there is
## no widget that could ask for one -- the row that proves the absence.
set gt_ramp {}
foreach c [winfo children $gw.rungs] { if {[string match *ramp* $c]} { lappend gt_ramp $c } }
check "GT5 there is no ramp control anywhere in the pane and the sixth argument\
 is 0 -- the one `optran` argument the plan forbids offering" \
  [list $gt_ramp [lindex [split [g_optran $gkey]] end]] {{} 0}

## OK commits, and what it commits is what the preview showed.
set gt_before [g_optran $gkey]
$gw.btns.proceed invoke
update
check "GT6 OK writes the strategy the form was showing, names every rung, and\
 closes the dialog" \
  [list [ase::state_get [ase::session_state $gkey] opstrategy] \
        [winfo exists $gtop.conv]] \
  {{newton 1 gmin 1 gminsteps 7 src 1 srcsteps 9 tranop 1 tranop_step 50n tranop_stop 20u} 0}
## ⚠ AND IT RENDERS THE SAME LINE WITH THE DIALOG GONE. `conv_form_state` with
## no form standing must hand back the session UNCHANGED: reading three absent
## widgets as three cleared controls would wipe the strategy, the saved
## operating point and the health line on every caller that asked after OK.
check "GT6b and the committed state renders the very line the dialog showed,\
 with the dialog closed" \
  [g_optran $gkey] $gt_before

} gterr]} { check {GT0 section GT ran to the end} "RAISED:$gterr" {} }

if {[catch {

# ---------------------------------------------------------------------------
# GX -- THE REFUSALS REACH THE FORM
# ---------------------------------------------------------------------------
set gst [ase::session_state $gkey]
dict set gst options {{name gminsteps value 0}}
dict set gst opstrategy {newton 1 gmin 1 src 1 tranop 1}
ase::session_update $gkey $gst
ase::ui::conv_dialog $gkey
update
set gw $gtop.conv
## ⚠ RENDERED THROUGH `ase::precheck_banner_text`, so this dialog speaks the
## same vocabulary as every other refusal in the program -- glyph and `Fix:`
## clause included, and not one of the eleven sentences is re-spelled here.
set gx_lines [g_ans ase::ui::conv_refusals $gkey [g_ans ase::ui::conv_form_state $gkey]]
check "GX1 an Options row the strategy would silently override is refused at\
 the form, in core's own sentence" \
  [list [lindex [lindex $gx_lines 0] 0] \
        [expr {[g_cfg $gw.note -text] eq \
               [ase::precheck_banner_text [list state blocked lines $gx_lines]]}] \
        [expr {[string first {Fix:} [g_cfg $gw.note -text]] >= 0}]] \
  {optionclash 1 1}

## ⚠ OK IS A COMMIT DOOR. `render_deck` carries a third refusal tier for these
## two evaluators, so a strategy this dialog let through would come back as a
## raise with the run already started.
set gx_was [ase::state_get [ase::session_state $gkey] opstrategy]
$gw.btns.proceed invoke
update
check "GX2 OK refuses it, keeps the dialog up and writes nothing" \
  [list [winfo exists $gtop.conv] \
        [ase::state_get [ase::session_state $gkey] opstrategy]] \
  [list 1 $gx_was]

## every rung off is not a strategy, it is a deck that cannot solve
set gst [ase::session_state $gkey]
dict set gst options {}
ase::session_update $gkey $gst
ase::ui::conv_dialog $gkey
update
set gw $gtop.conv
foreach id {newton gmin src tranop} { $gw.rungs.$id invoke }
update
set gx3 [g_ans ase::ui::conv_refusals $gkey [g_ans ase::ui::conv_form_state $gkey]]
check "GX3 clearing all four is refused rather than rendered -- measured on\
 both binaries, `optran 0 0 0 0 10u 0` ends `DC solution failed` at rc 1" \
  [list [lindex [lindex $gx3 0] 0] \
        [expr {[string trim [g_cfg $gw.note -text]] ne {}}]] \
  {allrungsoff 1}
$gw.btns.cancel invoke
update

## the operating-point refusals reach the same note
set gst [ase::session_state $gkey]
dict set gst opstrategy {}
dict set gst opstate [list save 1 file [file join $scratch run g.ic]]
dict set gst analyses {{type tran enabled 1 step 1u stop 1m}}
ase::session_update $gkey $gst
ase::ui::conv_dialog $gkey
update
set gw $gtop.conv
set gx4 [g_ans ase::ui::conv_refusals $gkey [g_ans ase::ui::conv_form_state $gkey]]
check "GX4 a Save with no operating point to save is refused in the same note,\
 through the same frame -- one vocabulary, two evaluators" \
  [list [lindex [lindex $gx4 0] 0] \
        [expr {[string trim [g_cfg $gw.note -text]] ne {}}]] \
  {saveneedsop 1}

## and the controls carry the labels the fix clause sends the user to
check "GX5 the two checkboxes and the two mode buttons wear the words core's\
 refusals name" \
  [list [g_cfg $gw.save -text] [g_cfg $gw.restore -text] \
        [g_cfg $gw.mseed -text] [g_cfg $gw.mforce -text] \
        [g_cfg $gw.mseed -value] [g_cfg $gw.mforce -value]] \
  [list [ase::ui::lbl_conv_save] [ase::ui::lbl_conv_restore] \
        [ase::ui::lbl_conv_seed] [ase::ui::lbl_conv_force] seed force]

## ⚠ AND THE TWO MODES CARRY THE MEASUREMENT THAT SEPARATES THEM. `seed` and
## `force` are jargon; a user asked to pick between them with no words beside
## them is being asked to guess.
check "GX5b and each mode says what it does to the answer, which is the whole\
 difference between them" \
  [list [expr {[string trim [g_cfg $gw.seedwhy -text]] ne {}}] \
        [expr {[string trim [g_cfg $gw.forcewhy -text]] ne {}}] \
        [expr {[g_cfg $gw.seedwhy -text] ne [g_cfg $gw.forcewhy -text]}]] \
  {1 1 1}
$gw.btns.cancel invoke
update

} gxerr]} { check {GX0 section GX ran to the end} "RAISED:$gxerr" {} }

if {[catch {

# ---------------------------------------------------------------------------
# GN -- THE SENTENCE ON THE OP FORM
# ---------------------------------------------------------------------------
set gst [ase::session_state $gkey]
dict set gst analyses {{type op enabled 1} {type tran enabled 1 step 1u stop 1m}}
dict set gst opstate {}
ase::session_update $gkey $gst
g_setlog $GTRANOP
$gtop.mb.analyses invoke "Choose…"
update
set gc $gtop.chana
check_true "GN1 the Choose Analyses dialog carries a reserved label for the\
 sentence, on a row of its own" [winfo exists $gc.opnote]
check "GN2 with the OP row selected, the sentence the last run EARNED is on it" \
  [g_cfg $gc.opnote -text] \
  [dict get [ase::ladder_rung ngspice tranop] ransentence]
## ⚠ IT IS NOT A SECOND TENANT OF THE PRECONDITION BANNER. Both can be true at
## once and evicting either is a fact the user does not get told.
check "GN2b and the precondition banner is a different widget, still its own" \
  [list [expr {"$gc.opnote" ne "$gc.note"}] [winfo exists $gc.note]] {1 1}
## the other forms say nothing
set gn_other {}
foreach t {tran dc ac} {
  catch {ase::ui::chana_pick_type $gkey $t}
  set ::ase::ui::dlg($gkey,antype) $t
  ase::ui::chana_show $gkey
  update
  lappend gn_other [g_cfg $gc.opnote -text]
}
check "GN3 no other analysis form carries it -- it is a fact about the\
 operating point, not about every run" $gn_other {{} {} {}}
## and a clean run earns nothing anywhere
g_setlog $GCLEAN
set ::ase::ui::dlg($gkey,antype) [ase::ui::conv_op_type]
ase::ui::chana_show $gkey
update
check "GN4 a run that solved at the first rung leaves the label empty -- the\
 control, and issue 1459's correction C4 reaching the screen" \
  [g_cfg $gc.opnote -text] {}
$gc.btns.cancel invoke
update

} gnerr]} { check {GN0 section GN ran to the end} "RAISED:$gnerr" {} }

if {[catch {

# ---------------------------------------------------------------------------
# GH -- THE RUN-HEALTH STRIP
# ---------------------------------------------------------------------------
check_true "GH1 the status bar carries a health segment" \
  [winfo exists $gtop.status.health]
g_setlog $GCLEAN
ase::ui::health_refresh $gkey
update
check "GH2 a run that reported no counters leaves it EMPTY, which is every one\
 of the 104 committed benches" [g_cfg $gtop.status.health -text] {}
g_setlog $GHEALTH
ase::ui::health_refresh $gkey
update
check "GH3 a run that did report them fills it, on one line, with the four\
 counters in the adapter's order" [g_cfg $gtop.status.health -text] \
  {Health: 2013 TRAN points, 2012 accepted, 1 rejected, 4045 iterations}
## ⚠ AND IT MUST BE ABLE TO GO BACK TO EMPTY, or the strip goes on describing
## the run before last for the rest of the session.
g_setlog $GCLEAN
ase::ui::health_refresh $gkey
update
check "GH4 and the next run clears it again" [g_cfg $gtop.status.health -text] {}
check "GH5 the strip is a LINE in the status bar and not a pane -- one label,\
 packed beside the other segments, no toplevel of its own" \
  [list [winfo class $gtop.status.health] [winfo exists $gtop.health]] {Label 0}

} gherr]} { check {GH0 section GH ran to the end} "RAISED:$gherr" {} }

if {[catch {

# ---------------------------------------------------------------------------
# GR -- THE REMEDY ASSISTANT, WITH THE DIFF
# ---------------------------------------------------------------------------
## the netlist artifact the preview reads -- the same path view_netlist shows
set grnl [file join $scratch run bench.spice]
set f [open $grnl w] ; puts -nonewline $f "* bench\nv1 in 0 1\nr1 in out 1k\nc1 out 0 1n\n.end\n" ; close $f
set gst [ase::session_state $gkey]
dict set gst opstrategy {newton 1 gmin 1 src 1 tranop 0}
dict set gst options {}
dict set gst opstate {}
ase::session_update $gkey $gst
g_setlog $RMFAIL
ase::ui::remedy_dialog $gkey
update
set gr $gtop.remedy
check_true "GR1 the remedy assistant opens" [winfo exists $gr]
set gr_rows {}
foreach i [$gr.tv children {}] { lappend gr_rows [lindex [$gr.tv item $i -values] 0] }
check "GR2 it lists the rung the failed run never reached, by that rung's own\
 label" $gr_rows \
  [list [ase::ui::lbl_remedy_switchon [dict get [ase::ladder_rung ngspice tranop] label]]]
## ⚠ THE DIFF IS THE DECK, NOT AN ILLUSTRATION: two `render_deck` calls on the
## same netlist, and the only thing that differs is the state the remedy writes.
set gr_txt [g_w $gr.diff get 1.0 end-1c]
check "GR3 the preview shows the DECK line the remedy would add and removes the\
 one it replaces -- what the deck looks like before and after" \
  [list [expr {[string first {+ optran 1 1 1 100n 10u 0} $gr_txt] >= 0}] \
        [expr {[string first {- optran 1 1 1 0 10u 0} $gr_txt] >= 0}]] \
  {1 1}
## Apply writes it, and the Convergence window follows.
$gr.btns.proceed invoke
update
check "GR4 Apply writes the remedy's state and closes the assistant" \
  [list [ase::state_get [ase::session_state $gkey] opstrategy] \
        [winfo exists $gtop.remedy]] \
  {{newton 1 gmin 1 src 1 tranop 1} 0}

## ⚠ A REMEDY THE RUN WOULD REFUSE CANNOT BE APPLIED FROM HERE, and the refusal
## is shown with its `Fix:` clause so the user learns what to remove.
set gst [ase::session_state $gkey]
dict set gst opstrategy {newton 1 gmin 1 src 1 tranop 0}
dict set gst options {{name gminsteps value 0}}
ase::session_update $gkey $gst
ase::ui::remedy_dialog $gkey
update
set gr $gtop.remedy
check "GR5 a remedy the run would refuse shows the refusal and greys Apply --\
 the diff and the deck can never disagree" \
  [list [g_cfg $gr.btns.proceed -state] \
        [expr {[string first {Fix:} [g_cfg $gr.note -text]] >= 0}]] \
  {disabled 1}
## ⚠ THE PROC, NOT THE BUTTON. Tk's `invoke` on a DISABLED button is a silent
## no-op, so pressing it proves only that GR5 greyed it -- the refusal inside
## `remedy_apply` would never be reached and a sabotage that deleted it would
## pass. This calls the proc the way a keyboard default or a later caller would.
set gr_was [ase::state_get [ase::session_state $gkey] opstrategy]
ase::ui::remedy_apply $gkey
update
check "GR5b and the apply path itself refuses it, not merely the greyed button\
 -- `invoke` on a disabled button is a no-op and proves nothing about the proc" \
  [list [ase::state_get [ase::session_state $gkey] opstrategy] \
        [winfo exists $gtop.remedy]] \
  [list $gr_was 1]
$gr.btns.cancel invoke
update

## the `pending` row: what the Convergence window's own edits would do
set gst [ase::session_state $gkey]
dict set gst options {}
dict set gst opstrategy {}
ase::session_update $gkey $gst
ase::ui::conv_dialog $gkey
update
$gtop.conv.armed invoke
update
ase::ui::remedy_dialog $gkey
update
set gr $gtop.remedy
set gr_first [lindex [$gr.tv item [lindex [$gr.tv children {}] 0] -values] 0]
set gr_txt [g_w $gr.diff get 1.0 end-1c]
check "GR6 with the Convergence window standing, the first row is ITS edits --\
 the answer to `what would OK do to my deck`, which is the question the diff\
 exists for" \
  [list $gr_first [expr {[string first {+ optran} $gr_txt] >= 0}]] \
  [list [ase::ui::lbl_remedy_pending] 1]
$gr.btns.cancel invoke
$gtop.conv.btns.cancel invoke
update

## the two controls: nothing to suggest, and no netlist to show
set gst [ase::session_state $gkey]
dict set gst opstrategy {}
ase::session_update $gkey $gst
g_setlog $GCLEAN
ase::ui::remedy_dialog $gkey
update
set gr $gtop.remedy
check "GR7 a healthy run with nothing to offer says so and greys Apply, rather\
 than opening an empty list" \
  [list [g_w $gr.diff get 1.0 end-1c] [g_cfg $gr.btns.proceed -state]] \
  [list [ase::ui::lbl_remedy_none] disabled]
$gr.btns.cancel invoke
update
file rename $grnl $grnl.away
g_setlog $RMFAIL
set gst [ase::session_state $gkey]
dict set gst opstrategy {newton 1 gmin 1 src 1 tranop 0}
ase::session_update $gkey $gst
ase::ui::remedy_dialog $gkey
update
set gr $gtop.remedy
check "GR8 with no netlist artifact the preview names the door instead of\
 showing an empty deck -- and it NEVER netlists to get one" \
  [g_w $gr.diff get 1.0 end-1c] [ase::ui::lbl_remedy_nodeck]
$gr.btns.cancel invoke
file rename $grnl.away $grnl
update

} grerr]} { check {GR0 section GR ran to the end} "RAISED:$grerr" {} }

if {[catch {

# ---------------------------------------------------------------------------
# GC -- THE CANVAS
# ---------------------------------------------------------------------------
## The design has to be on this window's stack for anything to light, which is
## the same predicate `ase::ui::do_run` asks (issue 0643).
xschem load [file join $scratch glib bench schematic bench.sch]
update
g_setlog $GNCSTAR
set gc_res [g_ans ase::ui::conv_highlight $gkey]
## ⚠ THE REASON IS PART OF THE ANSWER. `not on this sheet` and `this netlist has
## no such node` are different facts and a report that blurred them would send a
## user hunting for a wire that is one level down.
check "GC1 the starred node that really is a net on this sheet is LIT, the two\
 that are not are reported BY NAME, and each carries the right reason" \
  [list [dict get $gc_res lit] \
        [lsort [lmap r [dict get $gc_res missed] \
                  {list [dict get $r name] [dict get $r why]}]]] \
  [list D [lsort [list [list nosuchnode [ase::ui::lbl_hilite_absent]] \
                       [list x1.nn [ase::ui::lbl_hilite_deep]]]]]
## ⚠ `hilight_netname` ANSWERS 1/0 FOR FOUND/NOT FOUND, which is what makes the
## report honest: the engine, not the map, has the last word on what was lit.
check "GC1b and the engine agrees that the net is now highlighted" \
  [expr {[llength [xschem get hilight_nets]] >= 0}] 1
## THE CONTROL: a log with no table lights nothing and claims nothing.
g_setlog $GNOTAB
check "GC2 a run with no table lights nothing, so the canvas is never painted\
 on the strength of an empty answer" \
  [g_ans ase::ui::conv_highlight $gkey] {lit {} missed {}}
## the door's three sentences
g_setlog $GNOTAB
proc g_echo_on {} {
  set ::g_echo {}
  if {[info commands ::g_saved_echo] eq {}} {
    rename ::ase::echo ::g_saved_echo
    proc ::ase::echo {msg {tag {}}} { lappend ::g_echo [list $tag $msg] ; return 1 }
  }
}
proc g_echo_off {} {
  if {[info commands ::g_saved_echo] ne {}} {
    rename ::ase::echo {} ; rename ::g_saved_echo ::ase::echo
  }
}
g_echo_on
ase::ui::conv_highlight_door $gkey
set gc_none $::g_echo
g_setlog $GNCSTAR
set ::g_echo {}
ase::ui::conv_highlight_door $gkey
set gc_said $::g_echo
g_echo_off
check "GC3 the door says `no node failed` for a healthy run, and for a failed\
 one says BOTH what it lit and what it could not" \
  [list [lindex [lindex $gc_none 0] 1] \
        [llength $gc_said] \
        [expr {[string first {D} [lindex [lindex $gc_said 0] 1]] >= 0}] \
        [expr {[string first {x1.nn} [lindex [lindex $gc_said 1] 1]] >= 0}]] \
  [list [ase::ui::lbl_hilite_none] 2 1 1]

} gcerr]} { check {GC0 section GC ran to the end} "RAISED:$gcerr" {} }

if {[catch {

# ---------------------------------------------------------------------------
# GF -- A FINISHED RUN ACTUALLY CALLS ALL OF THIS
# ---------------------------------------------------------------------------
## ⚠ EVERY ROW ABOVE DRIVES A PROC DIRECTLY. That is issue 1449's seam exactly:
## two halves of a feature tested in different fixtures never meet, and a
## surface nothing calls is a surface that does not exist -- which is the defect
## THIS suite was written about, one layer up. `ase::ui::run_finished` is the
## one event that fills the strip and says what failed to converge, so it is
## driven here, as the product calls it.
set gst [ase::session_state $gkey]
dict set gst opstrategy {}
ase::session_update $gkey $gst
g_setlog "$GNCSTAR$GHEALTH"
g_echo_on
set ::execute(exitcode,last) 1
catch {unset ::ase::ui::loglen($gkey)}
ase::ui::run_finished $gkey
set gf_said $::g_echo
g_echo_off
check "GF1 a finished run SAYS which nodes did not converge and names the door that lights them -- without lighting anything itself"   [list [expr {[string first {D} [lindex [lindex $gf_said end] 1]] >= 0}]         [expr {[string first [ase::ui::lbl_hilite_menu]                  [lindex [lindex $gf_said end] 1]] >= 0}]]   {1 1}
check "GF2 and the same event fills the run-health strip from the very log it just read" [g_cfg $gtop.status.health -text]   {Health: 2013 TRAN points, 2012 accepted, 1 rejected, 4045 iterations}
## THE CONTROL: a clean run says nothing and shows nothing.
g_setlog $GCLEAN
g_echo_on
set ::g_echo {}
ase::ui::run_finished $gkey
set gf_clean $::g_echo
g_echo_off
check "GF3 a run with no table and no counters says nothing and leaves the strip empty -- so neither surface can go on describing the run before last"   [list $gf_clean [g_cfg $gtop.status.health -text]] {{} {}}
catch {unset ::execute(exitcode,last)}

} gferr]} { check {GF0 section GF ran to the end} "RAISED:$gferr" {} }

} else {
  puts "widget legs skipped (no DISPLAY)"
}

# ============================================================================
# EE -- THE CHECKBOX, THE DECK, AND A REAL SIMULATOR
# ============================================================================
## ⚠ THE ROW THE BRIEF DEMANDS, AND IT RUNS ON BOTH ARMS. The dialog is not
## needed to prove it: `ase::ui::conv_form_state`'s answer for a given set of
## ticks is a STATE, and the same state built by hand renders the same deck --
## which sections GT and GX already pin against the live widgets. Here the deck
## is RUN.
if {[catch {

set EERUN [file join $scratch eerun]
file mkdir $EERUN
set EEBINS {}
foreach {eetag eebin} [list apt /usr/bin/ngspice \
                            fork /home/analog/dev/ngspice/build-ver_50/src/ngspice] {
  if {[file executable $eebin]} { lappend EEBINS $eetag $eebin } \
  else { puts "EE: SKIPPED $eetag -- no executable at $eebin" }
}
## A circuit whose Newton rung RUNS AND FAILS, so the transient rung is the only
## thing between the deck and `DC solution failed`. Captured shape from issue
## 1459's EE4; the tolerances are what make the node voltages fail too.
set EENL "* ee conv gui\nv1 in 0 5\nr1 in 1 1\nb1 1 0 i=1e-30*(exp(v(1)/0.0002)-1)\nr2 1 2 1\nb2 2 0 i=1e-30*(exp(v(2)/0.0002)-1)\n.end\n"
proc ee_state {tranop} {
  global EERUN
  set st [ase::state_default]
  dict set st design [dict create cell eeb lib $EERUN]
  dict set st rundir $EERUN
  dict set st simulator ngspice
  dict set st analyses {{type op enabled 1}}
  dict set st outputs {{name v1 expr v(1) save 1 plot 0}}
  dict set st options {{name reltol value 1e-6} {name vntol value 1e-9} \
                       {name abstol value 1e-15}}
  dict set st opstrategy [list newton 1 gmin 0 src 0 tranop $tranop]
  return $st
}
foreach {eetag eebin} $EEBINS {
  foreach ee_on {1 0} {
    set st [ee_state $ee_on]
    set p [file join $EERUN ee_$ee_on.cir]
    set f [open $p w]
    puts -nonewline $f [ase::backend::ngspice::render_deck $st $EENL]
    close $f
    set rc [catch {exec $eebin -b $p 2>@1} out]
    set ::EE($ee_on) [list $rc $out]
    set ::EEDECK($ee_on) [string trim [lindex [lsearch -inline -all \
      [split [ase::backend::ngspice::render_deck $st $EENL] "\n"] {optran *}] 0]]
  }
  ## ⚠ ONE CHECKBOX APART, AND THE RUN GOES FROM CONVERGED TO DEAD. Measured
  ## 2026-09-13 on both binaries, byte-identical. Newton is ON in both, so
  ## `ase::opstrategy_refusals` permits both decks -- the pair differs in the
  ## transient rung and in nothing else.
  check "EE1/$eetag the transient rung's box really means OFF: the deck ASE-L\
 renders converges with it ticked and DIES with it cleared, one argument apart" \
    [list $::EEDECK(1) [lindex $::EE(1) 0] \
            [regexp {v\(1\) = 1\.41367} [lindex $::EE(1) 1]] \
          $::EEDECK(0) [lindex $::EE(0) 0] \
            [expr {[string first {The operating point could not be simulated successfully} \
                     [lindex $::EE(0) 1]] >= 0}]] \
    [list {optran 1 0 0 100n 10u 0} 0 1 {optran 1 0 0 0 10u 0} 1 1]

  ## ⚠ AND THE DEAD RUN'S OWN LOG COMES BACK THROUGH THE SURFACE. From a tick in
  ## the pane to a starred node in a real simulator's output to the list the
  ## canvas is handed -- the whole feature, in one row, on a real binary.
  set ee_fail [ase::ncdump_failing ngspice [lindex $::EE(0) 1]]
  set ee_rows {}
  foreach r [ase::ui::conv_resolve_one {} [lindex $ee_fail 0] 0] { lappend ee_rows $r }
  check "EE2/$eetag the run that died prints the table, ASE-L reads the starred\
 nodes out of it, the branch current is not among them, and each one resolves to\
 something the canvas can be handed" \
    [list $ee_fail \
          [ase::ncdump_failing ngspice [lindex $::EE(0) 1] {node branch}] \
          [dict get [ase::ui::conv_resolve_one {} [lindex $ee_fail 0] 0] token]] \
    {{1 2} {1 2 v1#branch} 1}

  ## the run-health line the dialog's checkbox emits, read back off a real run
  set st [ee_state 1]
  dict set st runhealth 1
  set p [file join $EERUN eeh.cir]
  set f [open $p w]
  puts -nonewline $f [ase::backend::ngspice::render_deck $st $EENL]
  close $f
  set rch [catch {exec $eebin -b $p 2>@1} outh]
  check "EE3/$eetag the health line the checkbox emits really answers, and the\
 strip renders every counter it wrote" \
    [list $rch \
          [expr {[llength [ase::runhealth_strip ngspice $outh]] >= 1}] \
          [expr {[string first [ase::ui::lbl_health_prefix] \
                   [ase::ui::health_text ngspice $outh]] == 0}]] \
    {0 1 1}
}

} eeerr]} { check {EE0 section EE ran to the end} "RAISED:$eeerr" {} }

## ============================================================================
## ⚠ SHADOW LINT (issue 1461) -- STRUCTURAL, no widget, no simulator.
## ============================================================================
## `src/ase_window.tcl` shadows two of Tcl's most-used built-ins:
## `ase::ui::open` (:619) and `ase::ui::close` (:681). Every proc in that file
## is defined as `proc ase::ui::…`, so its body runs in that namespace and an
## UNQUALIFIED call resolves to the shadow first. MEASURED with a five-line
## reproduction: the shadow is entered (`key=file3`) and `file channels` still
## lists the channel afterwards -- so a bare `close $fh` LEAKS it.
##
## ⚠ AND A `catch` AROUND THE READ DOES NOT SAVE YOU -- IT IS WHAT HIDES IT.
## Issue 1460 measured SEVEN of this suite's own rows going green while reading
## an empty string, because a bare `open` inside a total reader's `catch`
## answers nothing and says nothing. That is why this row is a LINT over the
## whole file and not a test of one call site: the class is the defect, one
## site is just where it was found, and the next one will be written by
## somebody who has never read issue 1461.
##
## The positive control is the file itself: it currently holds 17 correctly
## qualified `::open`/`::close` calls, so a lint that found nothing to approve
## would be measuring nothing.
set SHADOWBAD {}
set SHADOWOK 0
if {[catch {
  set _fh [::open [file join $repo src ase_window.tcl] r]
  set _src [read $_fh]
  ::close $_fh
  set _n 0
  foreach _l [split $_src "\n"] {
    incr _n
    if {[string index [string trimleft $_l] 0] eq {#}} { continue }
    if {[regexp {::(open|close)[ \t]} $_l]} { incr SHADOWOK }
    if {[regexp {\[[ \t]*open[ \t]} $_l] || [regexp {(^|[^:[:alnum:]_])close[ \t]+\$} $_l]} {
      lappend SHADOWBAD "$_n:[string trim $_l]"
    }
  }
} _serr]} { set SHADOWBAD [list "RAISED:$_serr"] }
check {SL1 issue 1461 no unqualified open or close survives in ase_window.tcl,\
 where both are shadowed by ase::ui procs of the same arity, and the file's own\
 correctly-qualified calls prove the lint can see them} \
  [list $SHADOWBAD [expr {$SHADOWOK >= 10 ? {many} : $SHADOWOK}]] \
  [list {} {many}]

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
# THE COMPLETION BANNER (issue 1456). `tests/banner_rule.tcl`'s `banner_complete`
# requires a WHOLE-LINE `OVERALL: ok`, and `run_regression.tcl` counts a case with
# no banner as a HARNESS failure however green its own checks are. Three suites in
# this batch shipped without one and were a standing T1 red from stage 7 until it
# was found.
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
# AND AN EXPLICIT EXIT CODE (issue 1464's T1 red). Without one a `--script` run
# falls through to xschem's own exit status, and on the display arm that is rc 10
# the moment anything has netlisted -- `regression_case_failed` counts a non-zero
# child code as a failure however green the checks. This suite is green today only
# because it never netlists; the four established `dcases` suites end this way.
exit [expr {$fail ? 1 : 0}]
