# ASE's user-visible messages must reach the ACTION LOG, not only its mirror (issue 0207).
#
# The user's report: in Ctrl-4 "select signals to plot" mode every pick prints
#     ase: queued trace 'v(x1.minus)'
#     ase: Direct Plot — 3 trace(s) queued
# to the CIW, and none of it reaches Xschem.log.
#
# The mechanism: `ciw_echo` (src/ciw.tcl:113) is a pure Tk widget append. The action-log
# FILE is written only by C `log_action()` (src/util.c:489), which then MIRRORS the line
# into the pane via log_action_echo (util.c:424). The flow is file -> pane, ONE WAY, and
# the CIW's title bar carries the log's path (ciw.tcl:44-48), which is why the pane looks
# like a view of the file. ASE called `ciw_echo` directly at 66 sites, so ~66 user-visible
# messages lived in the mirror of a file they were never in.
#
# The fix is the `ase::echo` seam (src/ase.tcl): pane echo AND
# `xschem log_action -result|-error`, i.e. `#= ` / `#! ` source-able COMMENT lines
# (log_output, util.c:536). Comments are the sanctioned carrier for non-replayable text
# (doc/claude/specs/action_logging.md), so the log's source-ability invariant holds.
#
# NOT in scope, and asserted absent: a REPLAYABLE line for the pick itself (issue 0204's
# left-undone item 1). A `#=` comment is not replayable by design — see issue 0208.
#
# Legs:
#   PS0-PS1   harness sanity: the log is open, the seam proc exists
#   PS2-PS5   ONE real Ctrl-4 pick: the per-pick line and the ESC summary reach BOTH the
#             pane and the file, the file copy prefixed `#= `
#   PS6       the mode-entry notice too (the whole notice stream, not two lines)
#   PS7       an `error`-tagged notice lands as `#! `, not `#= `
#   PS8       the pane gets each message EXACTLY ONCE (log_output must not re-mirror)
#   PS9       every new log line is still a `#` comment or an `xschem ` command
#   PS10      an EMPTY message logs NOTHING (the landmine: `xschem log_action -result`
#             with a missing value used to write the literal line `-result`)
#   PS11      the C backstop: a value-less flag writes nothing, on every flag
#   PS12      a message ending in a BACKSLASH cannot swallow the following log line
#             (a Tcl comment ending in `\` continues onto the next line)
#   PS13      the pick still writes NO replayable line — (B) is out of scope, not done
#   PS14-PS19 issue 0650: the two sinks only X can witness — the `.statusbar.12`
#             fallback with the CIW CLOSED (PS14) and its 28-char budget (PS15),
#             the mapped-CIW discriminator (PS16), the REFUTATION that a close
#             only WITHDRAWS so `winfo exists` is the wrong predicate (PS17),
#             the once-per-message pane fence while withdrawn (PS19), and the
#             opt-in non-blocking `.xschem_notify` popup (PS18)
#   RP1-RP3   the log still `source`s cleanly after the picks, and the ASE lines are inert
#
# MUST run under X with --logdir (a real CIW pane AND a real action log) -> registered in
# full_audit.sh logdir_tests. --nolog would disable both, and --nolog + --logdir is a fatal
# abort (util.c:344-349) -- which is why the registration is a list membership and not an
# extra flag: the audit's dispatch is an if/elif chain and logdir_tests is its first arm.
# Without the flag PS0 reds and 16 of the 26 checks go with it; the other 10 assert
# ABSENCES (PS9, PS10a, PS10b, PS11, PS13, RP2, RP3 ...) and pass vacuously over a log
# that was never opened, so all 26 are worthless without it (issue 0415).
#   ./src/xschem --pipe -q --logdir "$(mktemp -d)" \
#       --script tests/headless/test_ase_log_seam_0207.tcl
# or, gated:
#   tests/headless/run_suites.sh --logdir test_ase_log_seam_0207
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; the CIW pane is a witness)"; flush stdout; exit 0 }
update idletasks
focus -force .drw
update idletasks

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name got} { check $name [expr {$got ? 1 : 0}] 1 }
proc note {name got} { puts "note: $name = {$got}"; flush stdout }

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
## issue 0658: a throw-away XSCHEM_SHAREDIR + a CHILD xschem launched against it
## (PS27 -- the GUI user's degraded startup, the only row that reaches the
## ciw_create guard at src/xschem.tcl:16705)
source [file join $here sharefarm.tcl]
set scratch [test_scratch ase_log_seam_0207]

proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }

# --- the two witnesses ----------------------------------------------------------
# the FILE (test_select_at.tcl:23-30, the established --logdir idiom)
proc loglines {} {
  set fn [xschem get actionlog_filename]
  if {$fn eq {} || ![file exists $fn]} { return {} }
  set fd [open $fn r]; set body [read $fd]; close $fd
  return [split [string trimright $body \n] \n]
}
proc newlines {n0} { lrange [loglines] $n0 end }
# the PANE (test_ciw.tcl:53 / test_ciw_puts_capture.tcl:21-24)
proc pane_text  {} { if {![winfo exists .ciw.l.t]} { return {} } ; .ciw.l.t get 1.0 end }
proc pane_lines {} { split [string trimright [pane_text] \n] \n }
proc pane_count {s} {
  set n 0
  foreach l [pane_lines] { if {[string first $s $l] >= 0} { incr n } }
  return $n
}
proc has {lines s} {
  foreach l $lines { if {[string first $s $l] >= 0} { return 1 } }
  return 0
}
# the exact source strings. The summary/entry lines carry U+2014 EM DASH
# (src/ase_window.tcl:1623,1672) — an ASCII hyphen never matches.
set MSG_PICK    {ase: queued trace 'v(named)'}
set MSG_SUMMARY "ase: Direct Plot — 1 trace(s) queued"
set MSG_ENTRY   "ase: Direct Plot — click wires/net labels"

if {[catch {

# --- fixture (test_sod_pick_no_select_0204.tcl:92-112) ---------------------------
# a NAMED wire with a lab_pin driving it, plus a device to click for the error arm
wfile [file join $scratch sp.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 0 200 0 {}
C {devices/lab_pin} 0 0 0 0 {name=l1 lab=NAMED}
C {devices/res} 400 -200 0 0 {name=R1 value=1k}}

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}
xschem load [file join $scratch sp.sch]
xschem zoom_full; update idletasks

proc bbox_centre {inst} {
  lassign [lindex [split [xschem instance_bbox $inst] "\n"] 0] _ x1 y1 x2 y2
  list [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}]
}
lassign [bbox_centre R1] RX RY
set WNX 100 ; set WNY 0                     ;# on the NAMED wire, clear of the label

# dp_finish would try to build a viewer toplevel for an unregistered key
# (0204:132-133) — stub it, and ONLY it. ciw_echo and the log file are the witnesses
# here, so unlike the other ASE suites this one must NOT shadow ciw_echo.
rename ase::ui::dp_finish ase::ui::dp_finish_real
proc ase::ui::dp_finish {key queue {qcolors {}}} { set ::plotted $queue }
set ::plotted {}

# Arm a real Direct-Plot-flavour mode. do_raise 0 skips ase::ui::design_window, so no ASE
# session window has to exist — byte-identical to what Ctrl-4 reaches
# (src/cadence_style_rc:221 -> ase::direct_plot_for_current -> ase::ui::direct_plot ->
#  select_on_design $key {save 0 plot 1} plot 0, ase_window.tcl:2036-2038).
proc arm_sod {} {
  catch {ase::ui::sod_end K}
  array unset ::ase::ui::sod K,*
  unset -nocomplain ::ase::ui::sod(active)
  ase::ui::select_on_design K {save 0 plot 1} plot 0
  update idletasks
}

# --- PS0-PS1  harness sanity ----------------------------------------------------
check_true "PS0 action log open (needs --logdir)" [expr {[xschem get actionlog_filename] ne {}}]
check_true "PS0b CIW log pane exists"             [winfo exists .ciw.l.t]
check      "PS1 the ase::echo seam exists"        [expr {[info commands ::ase::echo] ne {}}] 1

# --- PS2-PS6  ONE real Ctrl-4 pick, both witnesses ------------------------------
set n0 [llength [loglines]]
arm_sod
ase::ui::sod_click K $WNX $WNY
update idletasks
ase::ui::sod_end K
update idletasks
set new [newlines $n0]
note "log lines added by the pick" [llength $new]
note "the added lines" [join $new "  |  "]

check "PS2 the pick's message is in the CIW pane"   [has [pane_lines] $MSG_PICK] 1
check "PS3 the pick's message is in the LOG FILE"   [has $new "#= $MSG_PICK"] 1
check "PS4 the ESC summary is in the CIW pane"      [has [pane_lines] $MSG_SUMMARY] 1
check "PS5 the ESC summary is in the LOG FILE"      [has $new "#= $MSG_SUMMARY"] 1
check "PS6 the mode-entry notice is in the LOG FILE too" [has $new "#= $MSG_ENTRY"] 1

# --- PS7  an error-tagged notice becomes `#! `, not `#= ` -----------------------
# ase::no_session_notice is the honest report when Ctrl-4 finds no ASE session; its
# notices are `error`-tagged (src/ase.tcl).
set n1 [llength [loglines]]
ase::no_session_notice
update idletasks
set enew [newlines $n1]
note "no_session_notice lines" [join $enew "  |  "]
# Which of no_session_notice's arms fires is fixture-dependent (this scratch schematic is
# not under a registered library, so the design_of_path arm reports first) — so derive the
# expected text from the file line rather than hardcoding one arm's wording, and make the
# non-vacuity explicit: `has` with an EMPTY needle returns 0 (string first {} x == -1), so
# PS7d cannot pass on a missing line.
check_true "PS7a an error-tagged notice reached the FILE" [expr {[llength $enew] > 0}]
set errline [lindex $enew 0]
set errtext [string range $errline 3 end]
check_true "PS7a2 and it is a real, non-empty message" [expr {$errtext ne {}}]
check "PS7b it carries the ERROR prefix `#! `" [string range $errline 0 2] {#! }
check "PS7c it is NOT the result prefix"       [string match {#= *} $errline] 0
check "PS7d the pane got the same text"        [has [pane_lines] $errtext] 1

# --- PS8  the pane gets each message exactly ONCE -------------------------------
# log_output() writes the file only (the Tcl caller does the pane echo), so routing
# through the seam must not double up in the pane.
check "PS8 the pick line appears in the pane exactly once" [pane_count $MSG_PICK] 1

# --- PS9  the format gate, in-test ----------------------------------------------
# test_selflog_output.tcl's rule: every logical line is a `#` comment or `xschem ...`
set bad {}
foreach l $new { if {![string match "#*" $l] && ![string match "xschem *" $l]} { lappend bad $l } }
check "PS9 every new log line is a comment or an xschem command" $bad {}

# --- PS10  an EMPTY message logs NOTHING ----------------------------------------
# The landmine: `xschem log_action -result` with a MISSING value fell through the
# dispatcher's argc>3 gates to the bare-line arm and wrote the literal line `-result`,
# which then aborts a replay `source`. 8 ASE sites pass a bare catch-result variable.
set n2 [llength [loglines]]
ase::echo {}
ase::echo {} error
update idletasks
check "PS10a an empty ase::echo adds no log line" [expr {[llength [loglines]] - $n2}] 0
check "PS10b and no stray flag line was written"  [has [newlines $n2] {-result}] 0

# --- PS11  the C backstop, every value-taking flag -------------------------------
set n3 [llength [loglines]]
foreach fl {-result -error -noecho -suppressecho -suppress} { catch {xschem log_action $fl} }
update idletasks
check "PS11 a value-less log_action flag writes nothing" [expr {[llength [loglines]] - $n3}] 0

# --- PS12  a trailing backslash must not swallow the next line -------------------
# `#= foo\` + newline makes the FOLLOWING line part of the comment (verified: a
# `puts X` on the next line never runs). The seam pads the logged copy.
set n4 [llength [loglines]]
ase::echo "ase: trailing backslash \\"
xschem log_action {xschem set ps12_marker 1}
update idletasks
set bnew [newlines $n4]
check "PS12a the backslash message was logged"        [has $bnew {ase: trailing backslash}] 1
check "PS12b it does NOT end in a bare backslash"     [string match {*\\} [lindex $bnew 0]] 0
# The physical line always survives — the damage is done at SOURCE time, so this leg must
# replay, not grep. Without the pad, `#= …\` swallows the next line and the marker never
# runs (measured: a `puts X` after such a comment never executes).
proc marker_ran {marker} {
  set fn [xschem get actionlog_filename]
  set i [interp create]
  $i eval [list set ::want $marker]
  $i eval {set ::marked 0}
  $i eval {proc xschem {args} { if {[lindex $args 0] eq {set} && [lindex $args 1] eq $::want} { set ::marked 1 } ; return {} }}
  catch {$i eval [list source $fn]}
  set r [$i eval {set ::marked}]
  interp delete $i
  return $r
}
check "PS12c the FOLLOWING log line still EXECUTES on replay" [marker_ran ps12_marker] 1

# PS12d: the same hazard hiding behind a TRAILING NEWLINE. log_output() emits no prefix
# after the final newline, so "foo\\\n" lands as `#= foo\` too — and `[string index $msg
# end]` sees the newline, not the backslash. The seam trimrights first.
ase::echo "ase: trailing backslash then newline \\\n"
xschem log_action {xschem set ps12d_marker 1}
update idletasks
check "PS12d a backslash BEFORE a trailing newline is guarded too" [marker_ran ps12d_marker] 1

# --- PS13  (B) is still out of scope --------------------------------------------
# 0204 removed the pick's replayable `xschem select_at x y` line on purpose. This fix
# does NOT restore it: a `#=` comment is not replayable. Pin that, so a future (B)
# lands deliberately (issue 0208) rather than by accident.
set repl {}
foreach l $new { if {[string match "xschem *" $l]} { lappend repl $l } }
check "PS13 the pick still writes NO replayable command line" $repl {}

# --- RP1-RP3  the log still sources, and the ASE lines are inert -----------------
set fn [xschem get actionlog_filename]
set sub [interp create]
$sub eval {set ::ran {}}
$sub eval {proc xschem {args} {lappend ::ran $args; return {}}}
set src_err {}
set src_ok [expr {[catch {$sub eval [list source $fn]} src_err] ? 0 : 1}]
if {!$src_ok} { note "source error" $src_err }
check "RP1 the whole log file still sources cleanly" $src_ok 1
set ran [$sub eval {set ::ran}]
interp delete $sub
check "RP2 replay executed no ASE proc as a command" \
  [expr {[string first {ase::} $ran] >= 0 ? 1 : 0}] 0
check "RP3 replay never executed a bare flag as a command" \
  [expr {[string first {-result} $ran] >= 0 ? 1 : 0}] 0


# ============================================================================
# PS14-PS19 -- ISSUE 0650: THE TWO SINKS ONLY AN X SESSION CAN WITNESS
# ============================================================================
# The user's measured state, 2026-08-23: CIW closed, one gate-off netlist,
# VISIBLE SINKS REACHED = 0. `.statusbar.12` was {} before AND after,
# `.statusbar.1` was unchanged, no popup appeared, and the only surviving trace
# was one `#! ` line in a log file nobody was reading.
#
# ⚠ THE ISSUE'S OWN MECHANISM SENTENCE IS FALSE, WHICH IS WHY PS17 EXISTS.
# 0650's sink table says ciw_echo "No-ops silently when shut
# (src/ciw.tcl:120-121)" and 0653 says "The CIW is a closable toplevel. Closed
# -> silent no-op." src/ciw.tcl:53 is
#   wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}
# so a close WITHDRAWS: `.ciw` and `.ciw.l.t` still EXIST, ismapped is 0, and
# ciw_echo happily writes into the invisible widget (measured: the pane text
# GREW). A row-3 condition built on `winfo exists` therefore evaluates TRUE in
# precisely the user's situation, the fallback never fires, and it passes
# review. The predicate is `winfo ismapped`. PS17 pins the Tk fact so the wrong
# predicate cannot come back silently; SAB-N2 is the sabotage that reinstates it
# and must redden PS14/PS15.
#
# ⚠ AND `.statusbar.12` CLIPS AT ~28-42 CHARACTERS WITH NO WARNING. Measured
# twice on this box at 1000x800 with a live mouse readout in `.statusbar.1`:
# 199px / first clip at char 30, and 314px / first clip at char 42. That is
# issue 0639's defect class in a field an order of magnitude smaller, so PS15
# is not decoration -- it is the row that keeps the fallback from being a
# truncated fragment. The wall itself is recorded as issue 0654.
#
# GREEN BEFORE THE CHANGE, deliberately (controls, not evidence): PS16 (nothing
# writes .statusbar.12 today, so "unchanged while the CIW is mapped" is
# trivially true), PS17 (a pure measurement of Tk's withdraw semantics) and
# PS19 (ciw_echo already writes exactly once). They exist to STAY green: PS16 is
# what makes PS14 mean something, and PS19 is the notice-count fence that
# test_ase_locked_wire_pick_0160 and test_sod_pick_no_select_0204 also stand on.

## the drawing window's shared status field. Both C writers prefix
## xctx->top_path (hilight.c:2201 writes *BUSY* here, hilight.c:2305 CLEARS it
## unconditionally at the end of propagate_logic), so a Tcl sink must use
## `xschem get top_path` -- "" for the main window -- and never a bare
## `.statusbar.12`. `xschem get topwindow` returns "." and would build
## "..statusbar.12"; src/xschem.tcl:14146 already ships that bug for .statusbar.7.
proc sbar_path {} { return "[xschem get top_path].statusbar.12" }
proc sbar_text {} {
  if {![winfo exists [sbar_path]]} { return NO-WIDGET }
  if {[catch {[sbar_path] cget -text} t]} { return NO-TEXT }
  return $t
}
proc sbar_set {t} { catch {[sbar_path] configure -text $t} }

## Close the CIW the way the USER closes it -- through the REAL handler
## registered at ciw.tcl:53, not `wm withdraw` typed by the test. The whole
## point of PS17 is that those are the same thing and that the widget survives.
proc ciw_close_via_wm {} {
  if {![winfo exists .ciw]} { return 0 }
  set h [wm protocol .ciw WM_DELETE_WINDOW]
  if {$h eq {}} { return 0 }
  uplevel #0 $h
  update idletasks
  return [expr {[winfo ismapped .ciw] ? 0 : 1}]
}
proc ciw_show {} {
  catch {wm deiconify .ciw}
  for {set i 0} {$i < 100} {incr i} {
    update idletasks ; update
    if {[winfo exists .ciw] && [winfo ismapped .ciw]} { return 1 }
    after 20
  }
  return 0
}
## every -text / text-widget body under a toplevel, so an opt-in popup can be
## read without this suite knowing its internal widget names
proc subtree_text {w} {
  set out {}
  if {![winfo exists $w]} { return {} }
  catch { append out [$w cget -text] "\n" }
  catch { append out [$w get 1.0 end] "\n" }
  foreach c [winfo children $w] { append out [subtree_text $c] }
  return $out
}

# a real one of the feature's own sentences: 89 characters, three times the
# statusbar's measured wall
set PS_LONG {ASE: device operating-point parameters (gm, gds, vth, ...) were NOT saved in this deck.}

# --- PS14: the CAN'T-MISS FALLBACK, in the user's exact state ----------------
sbar_set {}
set ps14_closed [ciw_close_via_wm]
ase::echo $PS_LONG error
update idletasks
set ps14_sb [sbar_text]
check "PS14 0650 with the CIW closed through its REAL WM_DELETE_WINDOW handler,\
 a notice reaches [sbar_path]" \
  [list $ps14_closed \
        [expr {$ps14_sb ne {} && $ps14_sb ne {NO-WIDGET} && $ps14_sb ne {NO-TEXT} ? 1 : 0}] \
        [expr {[string first [string range $ps14_sb 0 9] $PS_LONG] == 0 ? 1 : 0}]] \
  {1 1 1}
note "PS14 statusbar text" $ps14_sb

# --- PS15: and it is BUDGETED, with the source message proving non-vacuity ---
check "PS15 0654 the fallback text is <= 28 chars while the SOURCE message is\
 longer (the budget is proved, not assumed)" \
  [list [expr {[string length $ps14_sb] > 0 ? 1 : 0}] \
        [expr {[string length $ps14_sb] <= 28 ? 1 : 0}] \
        [expr {[string length $PS_LONG] > 28 ? 1 : 0}]] \
  {1 1 1}

# --- PS16: THE DISCRIMINATOR. Mapped CIW -> the statusbar is left alone ------
# GREEN BEFORE THE CHANGE. Without it PS14 would pass for a sink that writes the
# statusbar unconditionally, which would stomp *BUSY* (hilight.c:2201) on every
# ASE notice and turn a shared field into ASE's private one.
sbar_set PS16-SENTINEL
set ps16_shown [ciw_show]
ase::echo $PS_LONG error
update idletasks
check "PS16 0650 with the CIW MAPPED the identical notice leaves the statusbar\
 UNCHANGED (and still reaches the pane)" \
  [list $ps16_shown [sbar_text] [expr {[pane_count $PS_LONG] >= 1 ? 1 : 0}]] \
  {1 PS16-SENTINEL 1}

# --- PS17: the refutation, pinned so it cannot come back ---------------------
# GREEN BEFORE THE CHANGE -- it is a measurement of Tk, not of us. It is here so
# that a future `winfo exists .ciw.l.t` predicate (0650's own literal words) is
# read as the dead-code-in-the-user's-situation defect it is.
ciw_close_via_wm
set ps17_pane_before [string length [pane_text]]
ase::echo {ase: PS17 written into an invisible widget}
update idletasks
check "PS17 0650 REFUTATION: closing the CIW WITHDRAWS it -- .ciw.l.t still\
 EXISTS, ismapped is 0, and ciw_echo still writes into it" \
  [list [expr {[winfo exists .ciw] ? 1 : 0}] \
        [expr {[winfo exists .ciw.l.t] ? 1 : 0}] \
        [expr {[winfo ismapped .ciw] ? 1 : 0}] \
        [expr {[string length [pane_text]] > $ps17_pane_before ? 1 : 0}]] \
  {1 1 0 1}

# --- PS19: the pane still gets each message EXACTLY ONCE, withdrawn ---------
# GREEN BEFORE THE CHANGE, and the fence that keeps the new sinks from doubling
# the counts test_ase_locked_wire_pick_0160:126 and
# test_sod_pick_no_select_0204:138/295 assert (`llength $::notices == 1`).
set PS19_MSG {ase: PS19 exactly once while withdrawn}
ase::echo $PS19_MSG
update idletasks
check "PS19 0650 with the CIW withdrawn the pane STILL receives each message\
 exactly once (PS8's contract, under the new sinks)" [pane_count $PS19_MSG] 1

# --- PS18: the opt-in popup (R-0653-a/-b), non-blocking and reusable --------
# ⚠ alert_ (src/xschem.tcl:11954) is the WRONG precedent and this row is why:
# it uses a FIXED `.alert` path and `tkwait window .alert`. ase::op_cards_capture
# emits up to SIX notices inside ase::netlist inside Netlist-and-Run, so a modal
# would stall the run and the second notice would raise `window name .alert
# already exists`. The user asked for "dismissed with OK button or ESC button",
# never for blocking. If a future implementation DOES block, this suite hangs
# here rather than reddening -- that is the loudest signal available and it is
# deliberate.
set ps18_style_had [info exists ::notify_style]
if {$ps18_style_had} { set ps18_style_old $::notify_style }
catch {destroy .xschem_notify}
sbar_set PS18-SENTINEL
set ::notify_style popup
set ps18_rc1 [catch {::xschem::notify {PS18 first notice}} ps18_e1]
update idletasks ; update
set ps18_up1 [expr {[winfo exists .xschem_notify] ? 1 : 0}]
set ps18_rc2 [catch {::xschem::notify {PS18 second notice}} ps18_e2]
update idletasks ; update
set ps18_up2 [expr {[winfo exists .xschem_notify] ? 1 : 0}]
set ps18_body [subtree_text .xschem_notify]
set ps18_both [expr {[string first {PS18 first notice} $ps18_body] >= 0 &&
                     [string first {PS18 second notice} $ps18_body] >= 0 ? 1 : 0}]
set ps18_sb [sbar_text]
set ps18_gone 0
if {[winfo exists .xschem_notify]} {
  catch {focus -force .xschem_notify}
  catch {event generate .xschem_notify <Escape>}
  update idletasks ; update
  set ps18_gone [expr {![winfo exists .xschem_notify] ? 1 : 0}]
}
if {$ps18_style_had} { set ::notify_style $ps18_style_old } \
else { unset -nocomplain ::notify_style }
catch {destroy .xschem_notify}
check "PS18 0653 R-0653-b ::notify_style popup: ONE reusable non-blocking\
 toplevel, a second notice APPENDS without raising, the statusbar is left\
 alone, and <Escape> destroys it" \
  [list $ps18_rc1 $ps18_up1 $ps18_rc2 $ps18_up2 $ps18_both $ps18_sb $ps18_gone] \
  [list 0 1 0 1 1 PS18-SENTINEL 1]
if {$ps18_rc1} { note "PS18 first notify error" $ps18_e1 }


# ============================================================================
# PS20-PS27 -- ISSUE 0658: THE DURABLE LOG MUST SURVIVE A MISSING CHANNEL
# ============================================================================
# The driver reproduced it: `rename ::xschem::notify ::v_saved_notify`, then
# `ase::echo "ASE: a refusal the user must see" error`, and the log file did not
# grow by one byte. Zero sinks, nothing raised, and the sink 0650's own table
# calls "the one that survives a shut window" was not written. This suite is the
# only one with BOTH a real CIW pane and a real durable log, so it owns the
# file-level assertions (PS21/PS22) and the R6 cross-product (PS24-PS26).
#
# The channel (src/ciw.tcl:246) loads at src/xschem.tcl:14854, AFTER op_annot
# (:14796), ase (:14802) and wave_viewer (:14806) -- after every one of its
# callers, and inside the very file whose failure is the hazard. The fix is a
# minimal, deliberately degraded bootstrap defined in src/xschem.tcl BEFORE
# :14796 and REDEFINED by ciw.tcl; the full contract, and the golden marker
# string `NOTICE CHANNEL DEGRADED`, are written out at the head of the
# NT16-NT21 / NTD1-NTD7 block in tests/headless/test_ase_core.tcl.
#
# GREEN BEFORE THE CHANGE, deliberately (controls, not evidence, in PS16/PS17's
# sense): PS24, PS25 and PS26 -- the 0650 cross-product {withdrawn, iconified,
# never-created} x {ciw, popup}, which was an ad-hoc adversary measurement in
# the 0650 crew and has NO committed rows. The brief says "you must not regress
# it"; with no green number on disk to diff, the only way to honour that is to
# commit the rows. PS24's iconify half is also the row that must REDDEN rather
# than self-skip if the live WM refuses iconify (issue 0646) -- so it reports
# which WM was live rather than shrugging.

## one field of the ::xschem::notify_last witness, with a speaking placeholder
proc ps_field {k} {
  if {![info exists ::xschem::notify_last]} { return NO-notify_last }
  if {[catch {dict get $::xschem::notify_last $k} v]} { return NO-KEY-$k }
  return $v
}
## run $body with ::xschem::notify RENAMED AWAY -- the driver's reproduction --
## restoring it on every exit path including a raising body
proc ps_no_notify {body} {
  set had [expr {[info commands ::xschem::notify] ne {}}]
  if {$had} { rename ::xschem::notify ::ps_saved_notify }
  set rc [catch {uplevel 1 $body} e]
  if {$had} {
    catch {rename ::xschem::notify {}}
    catch {rename ::ps_saved_notify ::xschem::notify}
  }
  if {$rc} { return [list ERR $e] }
  return $e
}
## count whole-log lines containing $s
proc ps_logcount {s} {
  set n 0
  foreach l [loglines] { if {[string first $s $l] >= 0} { incr n } }
  return $n
}
## Which window manager is actually running on this display? Issue 0645: the
## Xvfb arm's default AUDIT_WM=openbox was not installed on this box for a
## while and the arm fell back to WM-LESS with only a stderr warning, so a suite
## whose subject is iconify/mapping MUST say what was live or it is a bare-Xvfb
## measurement wearing a window manager's name.
proc ps_wm_name {} {
  set n {}
  catch {
    set r [exec xprop -root -notype _NET_SUPPORTING_WM_CHECK]
    if {[regexp {window id # (0x[0-9a-fA-F]+)} $r -> id]} {
      regexp {= "(.*)"} [exec xprop -id $id -notype _NET_WM_NAME] -> n
    }
  }
  if {$n eq {}} {
    if {[info exists ::env(AUDIT_WM)]} { return "NONE-REPORTED (AUDIT_WM=$::env(AUDIT_WM))" }
    return {NONE (no _NET_SUPPORTING_WM_CHECK -- bare X server, no WM)}
  }
  return $n
}
note "PS20-PS27 live window manager" [ps_wm_name]
note "PS20-PS27 DISPLAY" [expr {[info exists ::env(DISPLAY)] ? $::env(DISPLAY) : {NONE}}]

# --- PS20: R3 -- the bootstrap is OVERRIDDEN, in the REAL configuration ------
# "Assert the live xschem::notify is the four-sink one, NOT merely that the proc
# exists. A bootstrap that silently wins in the normal case would delete every
# visible sink and pass a naive test." Behavioural discriminators only: the full
# channel RAISES on an unknown option (src/ciw.tcl:257) and keeps -menu/-command
# as distinct witness fields. Nothing here CALLS the bootstrap -- a direct call
# would fire the once-latch and make PS23 read its own side effect.
set ps20_n0 [llength [loglines]]
set ps20_raise [catch {::xschem::notify {PS20 unknown option probe} -no_such_option x}]
::xschem::notify {PS20 an ordinary notice in the normal configuration} \
  -menu {Outputs > Save All…} -command {puts hi}
update idletasks
check "PS20 0658 R3 with everything loaded normally the LIVE channel is the\
 four-sink one (raises on an unknown option, keeps the remedy as fields) and a\
 notice announces NO degradation" \
  [list [expr {[info commands ::xschem::notify_bootstrap] ne {} ? 1 : 0}] \
        $ps20_raise [ps_field menu] [ps_field command] \
        [expr {[has [newlines $ps20_n0] {NOTICE CHANNEL DEGRADED}] ? 1 : 0}]] \
  [list 1 1 {Outputs > Save All…} {puts hi} 0]

# --- PS21: R1 ASSERTED ON THE FILE -- the row that is red at HEAD ------------
# Measured at HEAD: log 330 -> 330 bytes, and the file itself carried the two
# control lines and NEITHER degraded line. `sinks` is NOT the witness here:
# ciw.tcl:271-274 claims `ciw` whenever ::ciw_echo merely fails to raise, even
# with no pane to write to (issue 0662), and with the channel gone notify_last
# does not update at all, so it reports the PREVIOUS notice's dict.
set ps21_msg {PS21-0658 a refusal the user must see with the channel gone}
set ps21_n0  [llength [loglines]]
set ps21_rc  [catch {ps_no_notify {ase::echo $::ps21_msg error}} ps21_r]
set ps21_new [newlines $ps21_n0]
check "PS21 0658 R1 with ::xschem::notify RENAMED AWAY, ase::echo still writes\
 the DURABLE LOG LINE -- asserted on the FILE, as a `#! ` error line" \
  [list $ps21_rc [expr {[has $ps21_new "#! $ps21_msg"] ? 1 : 0}]] {0 1}
note "PS21 new log lines" $ps21_new

# --- PS22: R2 -- the other delegate, same file assertion ---------------------
set ps22_msg {PS22-0658 the waveform viewer delegate must reach the log too}
set ps22_n0  [llength [loglines]]
set ps22_rc  [catch {ps_no_notify {wviewer::echo $::ps22_msg error}} ps22_r]
check "PS22 0658 R2 with the channel still gone wviewer::echo writes its own\
 durable `#! ` line" \
  [list $ps22_rc [expr {[has [newlines $ps22_n0] "#! $ps22_msg"] ? 1 : 0}]] {0 1}

# --- PS23: R4 -- announced ONCE for the whole session, not per notice --------
# 0497 rule 1: count per pass, never alert per item. Three MORE degraded
# notices; all three must be logged, and the whole file must still carry exactly
# ONE `NOTICE CHANNEL DEGRADED` line -- the one PS21 already provoked. The
# restore is verified in the same row so a later PS cannot inherit a broken
# channel silently.
set ps23_n0 [llength [loglines]]
ps_no_notify {
  foreach i {1 2 3} { catch {ase::echo "PS23-0658 further degraded notice $i" error} }
}
set ps23_new [newlines $ps23_n0]
set ps23_cnt 0
foreach l $ps23_new {
  if {[string first {PS23-0658 further degraded notice} $l] >= 0} { incr ps23_cnt }
}
set ps23_back [catch {::xschem::notify {PS23 the channel is back} -short PS23BACK}]
check "PS23 0658 R4 the degraded-state announcement fires ONCE for the whole\
 session while every degraded notice is still logged, and the channel restores" \
  [list [ps_logcount {NOTICE CHANNEL DEGRADED}] $ps23_cnt $ps23_back [ps_field short]] \
  [list 1 3 0 PS23BACK]

# --- PS24: R6 -- ICONIFIED x ciw --------------------------------------------
# GREEN BEFORE THE CHANGE. The 0650 cross-product has no committed rows at all;
# "you must not regress it" is unmeasurable without them. ⚠ NEVER A SELF-SKIP:
# if the live WM refuses `wm iconify` this row REDDENS (issue 0646 -- a raise
# self-skip masked a never-raise regression), and the note above names the WM.
sbar_set PS24-SENTINEL
ciw_show
catch {wm iconify .ciw}
for {set i 0} {$i < 100} {incr i} {
  update idletasks ; update
  if {![winfo ismapped .ciw]} break
  after 20
}
set ps24_unmapped [expr {[winfo ismapped .ciw] ? 0 : 1}]
ase::echo $PS_LONG error
update idletasks
set ps24_sb [sbar_text]
check "PS24 0650/0658 R6 with the CIW ICONIFIED (not withdrawn) a notice still\
 reaches [sbar_path]" \
  [list $ps24_unmapped \
        [expr {($ps24_sb ne {PS24-SENTINEL} && $ps24_sb ne {} && \
                $ps24_sb ne {NO-WIDGET} && $ps24_sb ne {NO-TEXT}) ? 1 : 0}]] \
  {1 1}
note "PS24 statusbar text" $ps24_sb

# --- PS25: R6 -- NEVER-CREATED x ciw ----------------------------------------
# GREEN BEFORE THE CHANGE. The --nolog / never-created leg: `.ciw` does not
# exist at all (src/xschem.tcl:16705 skips ciw_create), which is a DIFFERENT
# predicate from withdrawn (PS14) and iconified (PS24). Destroy is the closest
# reachable equivalent inside a live session.
sbar_set PS25-SENTINEL
catch {destroy .ciw}
update idletasks ; update
set ps25_gone [expr {[winfo exists .ciw] ? 0 : 1}]
ase::echo $PS_LONG error
update idletasks
set ps25_sb [sbar_text]
catch {ciw_create}
update idletasks ; update
check "PS25 0650/0658 R6 with NO .ciw AT ALL a notice still reaches the\
 statusbar, and ciw_create brings the pane back for everything downstream" \
  [list $ps25_gone \
        [expr {($ps25_sb ne {PS25-SENTINEL} && $ps25_sb ne {} && \
                $ps25_sb ne {NO-WIDGET} && $ps25_sb ne {NO-TEXT}) ? 1 : 0}] \
        [expr {[winfo exists .ciw] ? 1 : 0}]] \
  {1 1 1}

# --- PS26: R6 -- NEVER-CREATED x popup --------------------------------------
# GREEN BEFORE THE CHANGE. withdrawn x popup is PS18's; iconified x popup takes
# the identical `$style eq {popup}` branch (src/ciw.tcl, the style test precedes
# the CIW-visibility test) and is stated here rather than re-rowed.
set ps26_had [info exists ::notify_style]
if {$ps26_had} { set ps26_old $::notify_style }
catch {destroy .xschem_notify}
catch {destroy .ciw}
update idletasks ; update
sbar_set PS26-SENTINEL
set ::notify_style popup
set ps26_rc [catch {::xschem::notify {PS26 a notice with no CIW in existence}} ps26_e]
update idletasks ; update
set ps26_up [expr {[winfo exists .xschem_notify] ? 1 : 0}]
set ps26_body [subtree_text .xschem_notify]
set ps26_sb [sbar_text]
if {$ps26_had} { set ::notify_style $ps26_old } else { unset -nocomplain ::notify_style }
catch {destroy .xschem_notify}
catch {ciw_create}
update idletasks ; update
check "PS26 0650/0658 R6 with NO .ciw and ::notify_style popup the notice\
 raises the popup and leaves the shared statusbar ALONE" \
  [list $ps26_rc $ps26_up \
        [expr {[string first {PS26 a notice with no CIW in existence} $ps26_body] >= 0 ? 1 : 0}] \
        $ps26_sb] \
  [list 0 1 1 PS26-SENTINEL]

# --- PS26b: R6 -- ICONIFIED x popup, so the cross-product is 6/6 committed ---
# GREEN BEFORE THE CHANGE. The sixth cell. It takes the same `$style eq {popup}`
# branch as PS26, but the brief's cross-product is {withdrawn, iconified,
# never-created} x {ciw, popup} and an argued-equivalent cell is not a measured
# one -- 0650's whole lesson is that a sentence about a mechanism can be false.
set ps26b_had [info exists ::notify_style]
if {$ps26b_had} { set ps26b_old $::notify_style }
catch {destroy .xschem_notify}
ciw_show
catch {wm iconify .ciw}
for {set i 0} {$i < 100} {incr i} {
  update idletasks ; update
  if {![winfo ismapped .ciw]} break
  after 20
}
set ps26b_unmapped [expr {[winfo ismapped .ciw] ? 0 : 1}]
sbar_set PS26B-SENTINEL
set ::notify_style popup
set ps26b_rc [catch {::xschem::notify {PS26b a notice with the CIW iconified}} ps26b_e]
update idletasks ; update
set ps26b_up [expr {[winfo exists .xschem_notify] ? 1 : 0}]
set ps26b_body [subtree_text .xschem_notify]
set ps26b_sb [sbar_text]
if {$ps26b_had} { set ::notify_style $ps26b_old } else { unset -nocomplain ::notify_style }
catch {destroy .xschem_notify}
check "PS26b 0650/0658 R6 with the CIW ICONIFIED and ::notify_style popup the\
 notice raises the popup and leaves the shared statusbar ALONE" \
  [list $ps26b_unmapped $ps26b_rc $ps26b_up \
        [expr {[string first {PS26b a notice with the CIW iconified} $ps26b_body] >= 0 ? 1 : 0}] \
        $ps26b_sb] \
  [list 1 0 1 1 PS26B-SENTINEL]

# --- PS27: THE GUI USER'S DEGRADED STARTUP ----------------------------------
# The user in this batch was never in a headless session. This is the only row
# that reaches the `ciw_create` call at src/xschem.tcl:16705, which runs ONLY
# under `[info exists has_x]` -- so an X child is the only way to prove that a
# dead ciw.tcl does not take the GUI startup down with it.
#
# ⚠ ORIGINALLY RED, AND NOT IN THE WAY 0658 PREDICTED. 0658 said xschem.tcl
# "continues past a failed source"; measured, the ciw.tcl source (:14854 on this
# tree) was a BARE `source`, the raise propagated out of xschem.tcl, and
# Tcl_AppInit walked on into `tclgetdoublevar(cairo_font_line_spacing)` against
# unset variables. The child SIGSEGVed -- `CHILDKILLED SIGSEGV`, the 0423/0424
# exit-139 signature. 0658's catch at :14854 is what makes THIS child exit 0;
# issue 0663 separately fixed the class in C, so a failed source of any OTHER
# helper now announces one `STARTUP ABORTED: ...` line and exits 1 rather than
# faulting (tests/headless/test_startup_guard_0663.tcl).
if {![info exists ::env(DISPLAY)] || $::env(DISPLAY) eq {}} {
  check "PS27 0658 the GUI user's degraded startup needs a DISPLAY" NO-DISPLAY 0
} else {
  set ps27_msg {PS27-0658 an ASE refusal in a degraded GUI session}
  set ps27_farm [share_farm $repo [file join $scratch farm_bad_gui] \
    [list ciw.tcl "error {0658 deliberate failure at the TOP of ciw.tcl}\n"]]
  set ps27_inner [string map [list @MSG@ $ps27_msg] {
    puts "PS27-MARK notify=[expr {[info commands ::xschem::notify] ne {} ? 1 : 0}]"
    puts "PS27-MARK ciw_echo=[expr {[info commands ::ciw_echo] ne {} ? 1 : 0}]"
    catch {::ase::echo {@MSG@} error} r
    puts "PS27-MARK ase=$r"
    flush stdout
    exit 0
  }]
  set ps27 [share_farm_child $ps27_farm [file join $scratch c_gui] $ps27_inner {--pipe -q}]
  note "PS27 child status" [dict get $ps27 -status]
  check "PS27 0658 an X child whose ciw.tcl FAILS TO SOURCE still STARTS (exit\
 0, not SIGSEGV), writes the notice to its durable log, and names ciw.tcl as\
 the cause" \
    [list [dict get $ps27 -status] \
          [share_farm_count [dict get $ps27 -log] $ps27_msg] \
          [expr {[string first {NOTICE CHANNEL DEGRADED} [dict get $ps27 -out]] >= 0 ? 1 : 0}] \
          [expr {[string first {ciw.tcl} [dict get $ps27 -out]] >= 0 ? 1 : 0}]] \
    [list 0 1 1 1]
}

# leave the session as we found it: CIW visible, status field clear
sbar_set {}
ciw_show

} err]} {
  puts "FATAL: $err"
  puts "$::errorInfo"
  incr fail
}

catch {rename ase::ui::dp_finish {}}
catch {rename ase::ui::dp_finish_real ase::ui::dp_finish}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else            { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
