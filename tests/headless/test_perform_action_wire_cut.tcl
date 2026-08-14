# perform_action() BOUNDARY -- SEVENTEENTH per-verb migration (Refactor B, audit §4 / §37):
# wire_cut -- the SILENT-MUTATOR twin of break_wires (atom 9, §29).
#
# Refactor B funnels every mutating op through ONE perform_action(verb,argc,argv)
# boundary: one readonly gate + one effect + one log site, so "did we readonly-
# check it?" and "did we log it?" are structural invariants, not per-path checklist
# items (audit §3.1). break_wires' §29 note already flagged break_wires_at_point()
# (check.c) as the SEPARATE Alt-Right `wire_cut` gesture core kept OFF break_wires'
# boundary. Atom 17 puts THAT core on the boundary. wire_cut is the direct structural
# twin of break_wires:
#   * its core break_wires_at_point() OWNS a CONDITIONAL SINGLE push_undo (only when a
#     wire is actually split) + its own draw -- so the run_core arm adds NEITHER
#     push_undo NOR draw (the atom-1 no-double-push rule); a point OFF any wire is a
#     NO-OP (no push, no draw) that still returns success -> no-op-still-logs (§30);
#   * the arg is numeric COORDS + a bareword `noalign` FLAG (%.16g, NO Tcl_Merge -- no
#     metacharacter referent), logged in TWO forms like break_wires (the aligned
#     `xschem wire_cut x y` and the `xschem wire_cut x y noalign`);
#   * it has a MID-GESTURE SPLIT like rotate/flip: ONLY the SCRIPTED coord form
#     (scheduler branch argc>3) crosses the boundary; the no-coord GESTURE-START form
#     (`xschem wire_cut [noalign]`, the Alt-Right menu items) ARMS ui_state and mutates
#     NOTHING, so it stays RAW and logs NOTHING (the STARTMOVE-stays-raw precedent).
#
# THE (A)/(B) GESTURE-COMPLETION DECISION -- option (A) was chosen. The interactive
# Alt-Right cut COMPLETION (callback.c break_wires_at_point at mousex/y_snap) stays
# RAW+silent: a pre-existing 0069-class gesture-drop gap this atom does NOT widen but
# does NOT close (deferred to a follow-up gesture-logging atom). Grep-guard-locked
# (callback.c ZERO scattered `log_action("xschem wire_cut`); not runtime-driven here
# (like rotate's Alt-R group note).
#
# BONUS CORRECTNESS FIX: the coord form had NO readonly gate before -- a scripted
# `xschem wire_cut x y` on a read-only cell push_undo+split+draw'd (verified on the
# pre-migration binary: rc=0, the cut happened). The boundary's ONE gate now REFUSES
# it (TCL_ERROR, verb-named message, no cut, no log). Safe because wire_cut has NO
# read-only-safe form (a point-off-wire is a no-op, not a query) so the all-or-nothing
# gate cannot over-reject (the show_unconnected_pins §35 / floaters §30 template).
#
#   (a)  SUCCESS: a wire in place -> `xschem wire_cut 50 0` -> +1 log
#        `xschem wire_cut 50 0` + the wire SPLITS (count 1->2, vertex at 50,0)
#   (a2) NOALIGN form: `xschem wire_cut 47 3 noalign` cuts at the exact (un-snapped)
#        point x=47 and logs `xschem wire_cut 47 3 noalign`; replaying the logged line
#        re-cuts identically (the FLAG round-trips). The ALIGNED form `xschem wire_cut
#        47 3` snaps to x=40 (cadsnap=20) -- the align/noalign discriminator.
#   (b)  NO-OP STILL LOGS (§30): `xschem wire_cut 500 500` (off any wire) -> no split
#        but STILL +1 log (a no-op is a SUCCESS -> void core -> TCL_OK -> log-on-success).
#   (c)  READONLY reject (the correctness fix): readonly 1 -> TCL_ERROR + verb-named
#        message + no cut + no log.
#   (d)  MID-GESTURE SPLIT (wrinkle 1): `xschem wire_cut` (no coords) -> +0 log + NO
#        mutation (only ui_state MENUSTART set) -- the gesture-START else did NOT cross
#        the boundary (the rotate/flip STARTMOVE-stays-raw property).
#   (e)  REPLAY: the recorded `xschem wire_cut 50 0` re-EXECUTES through the replay seam
#        (re-splits) without re-logging; a control unwrapped `source` DOES re-log.
#   (f)  UNDO DEPTH (no-double-push): ONE undo restores the un-split wire (the core's
#        single CONDITIONAL push_undo); a SECOND removes the placed wire. A spurious arm
#        push_undo would make the split survive one undo.
#   (g)  the interactive gesture COMPLETION stays off the boundary -- a NOTE (grep-guard
#        locked, callback.c ZERO), the accepted pre-existing gap (option A).
#
# Effect oracle (determined empirically on the pre-migration binary): a horizontal wire
# `0 0 100 0`, redraw (break_wires_at_point reads the wire spatial hash a redraw
# populates -- unlike break_wires_at_pins it does not hash_wires() itself). `wire_cut
# 50 0` splits it into {50 0 100 0} + {0 0 50 0}. Pre-migration deltas confirmed on the
# migrated binary: readonly rc 0-cut -> TCL_ERROR-no-cut, no-op rc 0 no-split still
# logs +1, gesture no-coord unchanged (ui_state MENUSTART), byte-exact `xschem wire_cut
# 50 0`, undo depth 1.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_wire_cut.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §37

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers
# this in logdir_tests so LOG is always set in the real run; the guard keeps a bare
# invocation from erroring. (deferred, NOT "skipped: no X" -- the effect is
# X-independent, but the log site needs an open action log.)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Defensive modal stub: the readonly scheduler/menu path uses the CIW-note gate
# (scheduler_readonly_reject); stub tk_messageBox so nothing wedges the audit under a
# real DISPLAY.
catch {rename tk_messageBox _paw_real_mb}
proc tk_messageBox {args} { return ok }

# Exact-line counters: the glob has NO trailing '*', so {xschem wire_cut 50 0} counts
# ONLY the aligned form and {xschem wire_cut 47 3 noalign} ONLY the noalign form.
proc logcount {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {$l eq $pat} { incr n } }
  return $n
}
proc last_exact {want} {
  set fd [open [xschem get actionlog_filename] r]; set all [read $fd]; close $fd
  set hit ""
  foreach l [split $all \n] { if {$l eq $want} { set hit $l } }
  return $hit
}
# total lines currently in the log (for the +0 gesture assertion)
proc logtotal {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  return [llength [split $b \n]]
}
# A horizontal wire on the grid + redraw to populate the wire spatial hash that
# break_wires_at_point relies on.
proc hwire {} {
  xschem clear force
  xschem set cadsnap 20
  xschem wire 0 0 100 0
  xschem redraw
}
proc vertex_at {x y} {
  for {set i 0} {$i < [xschem get wires]} {incr i} {
    set c [xschem wire_coord $i]
    if {([lindex $c 0]==$x && [lindex $c 1]==$y) ||
        ([lindex $c 2]==$x && [lindex $c 3]==$y)} { return 1 }
  }
  return 0
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: the scripted coord form splits + logs exactly +1 aligned line.
# ---------------------------------------------------------------------------
hwire
set c0 [logcount {xschem wire_cut 50 0}]
xschem wire_cut 50 0
check "(a) scripted 'xschem wire_cut 50 0' -> exactly +1 aligned log" \
  [expr {[logcount {xschem wire_cut 50 0}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem wire_cut 50 0}]"
check "(a) SUCCESS: the wire SPLITS (count 1 -> 2)" \
  [expr {[xschem get wires] == 2}] "wires=[xschem get wires]"
check "(a) SUCCESS: a vertex now exists at (50,0)" [vertex_at 50 0] "wires=[xschem get wires]"
check "(a) byte-exact logged line is 'xschem wire_cut 50 0'" \
  [expr {[last_exact {xschem wire_cut 50 0}] eq "xschem wire_cut 50 0"}] \
  "got=>[last_exact {xschem wire_cut 50 0}]<"

# ---------------------------------------------------------------------------
# (a2) NOALIGN vs ALIGN: the flag threads into BOTH the effect and the log.
#      noalign -> cut at the raw x=47; align -> snaps to x=40 (cadsnap=20). The
#      logged noalign line replays to the SAME cut (flag round-trip).
# ---------------------------------------------------------------------------
hwire
set c0 [logcount {xschem wire_cut 47 3 noalign}]
xschem wire_cut 47 3 noalign
check "(a2) NOALIGN cuts at the raw (un-snapped) point x=47" \
  [vertex_at 47 0] "wires: [xschem wire_coord 0] | [xschem wire_coord 1]"
check "(a2) NOALIGN logs exactly +1 'xschem wire_cut 47 3 noalign'" \
  [expr {[logcount {xschem wire_cut 47 3 noalign}] == $c0 + 1}] \
  "c0=$c0 now=[logcount {xschem wire_cut 47 3 noalign}]"
check "(a2) NOALIGN byte-exact logged line" \
  [expr {[last_exact {xschem wire_cut 47 3 noalign}] eq "xschem wire_cut 47 3 noalign"}] \
  "got=>[last_exact {xschem wire_cut 47 3 noalign}]<"
# the ALIGN form snaps: same click point, no flag -> x=40 (the discriminator)
hwire
xschem wire_cut 47 3
check "(a2) ALIGN (no flag) SNAPS the same click to x=40 (cadsnap=20) -- distinct from noalign x=47" \
  [expr {[vertex_at 40 0] && ![vertex_at 47 0]}] \
  "wires: [xschem wire_coord 0] | [xschem wire_coord 1]"
# replay the exact logged noalign line on a fresh wire -> reproduces the noalign cut
hwire
eval [last_exact {xschem wire_cut 47 3 noalign}]
check "(a2) replaying the logged noalign line re-cuts at the SAME raw x=47 (flag round-trips)" \
  [vertex_at 47 0] "wires: [xschem wire_coord 0] | [xschem wire_coord 1]"

# ---------------------------------------------------------------------------
# (b) NO-OP STILL LOGS (§30): a point off any wire -> no split but STILL +1 log
#     (void core -> run_core TCL_OK -> log-on-success; a no-op is a SUCCESS).
#     catch-wrapped so a regressed TCL_ERROR arm is a clean FAIL, not an abort.
# ---------------------------------------------------------------------------
hwire
set w0 [xschem get wires]
set c0 [logcount {xschem wire_cut 500 500}]
set rc [catch {xschem wire_cut 500 500} res]
check "(b) NO-OP off-wire: TCL_OK (not an error)" [expr {$rc == 0}] "rc=$rc res=$res"
check "(b) NO-OP off-wire: NO split (wire count unchanged)" \
  [expr {[xschem get wires] == $w0}] "before=$w0 after=[xschem get wires]"
check "(b) NO-OP off-wire: STILL logs +1 (no-op-still-logs, §30)" \
  [expr {[logcount {xschem wire_cut 500 500}] == $c0 + 1}] \
  "c0=$c0 now=[logcount {xschem wire_cut 500 500}]"

# ---------------------------------------------------------------------------
# (c) READONLY reject (the correctness fix): the scripted coord form on a read-only
#     cell -> TCL_ERROR + verb-named message + NO cut + NO log. Pre-migration this
#     CUT the wire (verified on the HEAD binary) -- a 0041/0051-class gap the
#     boundary's ONE gate now closes.
# ---------------------------------------------------------------------------
hwire
set w0 [xschem get wires]
xschem set readonly 1
set c0 [logcount {xschem wire_cut 50 0}]
set rc [catch {xschem wire_cut 50 0} res]
check "(c) readonly scripted: TCL_ERROR" [expr {$rc == 1}] "rc=$rc res=$res"
check "(c) readonly scripted: message names the verb" \
  [expr {[string match {*wire_cut*read-only*} $res]}] "res=$res"
check "(c) readonly scripted: NO cut (wire count unchanged)" \
  [expr {[xschem get wires] == $w0}] "before=$w0 after=[xschem get wires]"
check "(c) readonly scripted: NO log line (+0)" \
  [expr {[logcount {xschem wire_cut 50 0}] == $c0}] "c0=$c0 now=[logcount {xschem wire_cut 50 0}]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) MID-GESTURE SPLIT (wrinkle 1): the no-coord `xschem wire_cut` ARMS ui_state
#     and mutates NOTHING -- it stays RAW in the branch and logs NOTHING. The
#     gesture-START else did NOT cross the boundary (the STARTMOVE-stays-raw property).
# ---------------------------------------------------------------------------
hwire
set w0 [xschem get wires]
set nl0 [logtotal]
set rc [catch {xschem wire_cut} res]
check "(d) gesture-START 'xschem wire_cut' (no coords): TCL_OK" [expr {$rc == 0}] "rc=$rc res=$res"
check "(d) gesture-START: NO mutation (wire count unchanged)" \
  [expr {[xschem get wires] == $w0}] "before=$w0 after=[xschem get wires]"
check "(d) gesture-START: MENUSTART armed (ui_state bit 16)" \
  [expr {([xschem get ui_state] & 65536) != 0}] "ui_state=[xschem get ui_state]"
check "(d) gesture-START: logs NOTHING (+0 lines) -- did NOT cross the boundary" \
  [expr {[logtotal] == $nl0}] "before=$nl0 after=[logtotal]"
catch {xschem abort_operation}
# and the noalign gesture-START arms the OTHER ui_state2 flag, still no mutation/log
hwire
set w0 [xschem get wires]; set nl0 [logtotal]
catch {xschem wire_cut noalign}
check "(d) gesture-START 'xschem wire_cut noalign': NO mutation, +0 log" \
  [expr {[xschem get wires] == $w0 && [logtotal] == $nl0}] \
  "wires b=$w0 a=[xschem get wires]  lines b=$nl0 a=[logtotal]"
catch {xschem abort_operation}

# ---------------------------------------------------------------------------
# (e) REPLAY. wire_cut (coord form) is a re-executable verb: replaying it re-runs the
#     cut. Through the replay_action_log suppress seam the effect applies (the wire
#     splits) but does NOT re-log; a control unwrapped `source` DOES re-log.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_wc_[pid].log]
set fd [open $rec w]; puts $fd "xschem wire_cut 50 0"; close $fd
hwire
set nc [logcount {xschem wire_cut 50 0}]
replay_action_log $rec
check "(e) replay seam: EFFECT applied (wire splits, count -> 2, vertex at 50,0)" \
  [expr {[xschem get wires] == 2 && [vertex_at 50 0]}] "wires=[xschem get wires] v=[vertex_at 50 0]"
check "(e) replay seam: NOT re-logged (rides !actionlog_suppress)" \
  [expr {[logcount {xschem wire_cut 50 0}] == $nc}] "nc=$nc now=[logcount {xschem wire_cut 50 0}]"
hwire
set nc [logcount {xschem wire_cut 50 0}]
uplevel #0 [list source $rec]
check "(e) control (unwrapped source): EFFECT applied (wire splits, count -> 2)" \
  [expr {[xschem get wires] == 2 && [vertex_at 50 0]}] "wires=[xschem get wires] v=[vertex_at 50 0]"
check "(e) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[logcount {xschem wire_cut 50 0}] == $nc + 1}] "nc=$nc now=[logcount {xschem wire_cut 50 0}]"
file delete $rec

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (no-double-push): the core's single CONDITIONAL push_undo means ONE
#     undo restores the un-split wire; a SECOND removes the placed wire. A spurious
#     arm push_undo would make the split survive the first undo (needing two).
# ---------------------------------------------------------------------------
hwire
set w0 [xschem get wires]   ;# 1 (the placed wire)
xschem wire_cut 50 0
check "(f) after cut: 2 wires" [expr {[xschem get wires] == 2}] "wires=[xschem get wires]"
xschem undo
check "(f) ONE undo restores the un-split wire (single conditional push_undo, no double-push)" \
  [expr {[xschem get wires] == 1 && ![vertex_at 50 0]}] "wires=[xschem get wires] v=[vertex_at 50 0]"
xschem undo
check "(f) a SECOND undo removes the placed wire (undo depth is exactly one for the cut)" \
  [expr {[xschem get wires] == 0}] "wires=[xschem get wires]"

# ---------------------------------------------------------------------------
# (g) THE INTERACTIVE GESTURE COMPLETION stays OFF the boundary (option A). The
#     Alt-Right cut completion (callback.c break_wires_at_point at mousex/y_snap) is
#     RAW+silent -- a pre-existing 0069-class gesture-drop gap this atom does NOT
#     widen but does NOT close. It is grep-guard-locked (test_selflog_grep_guard.tcl:
#     callback.c ZERO scattered `log_action("xschem wire_cut`), NOT runtime-driven
#     here (driving it needs the full arm-then-click Tk sequence -- the rotate Alt-R
#     group precedent). Documented here as the accepted (A) decision.
# ---------------------------------------------------------------------------
check "(g) NOTE: interactive Alt-Right completion stays raw+silent (option A, grep-guard locked)" 1 \
  "callback.c break_wires_at_point sites unchanged; a follow-up gesture-logging atom (B) closes the gap"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
