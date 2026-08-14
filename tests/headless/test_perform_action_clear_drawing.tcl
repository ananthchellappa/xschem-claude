# perform_action() BOUNDARY -- Refactor B ATOM 27 (audit §47): migrate the `clear_drawing` verb.
#
# `clear_drawing` is batch item 02 of the Refactor B batch plan (fresh scout 2026-07-18; decision doc
# doc/claude/code_analysis/perform_action_atom27_clear_drawing_decision.md): the lowest-friction SILENT
# mutation left in the pool. Pre-migration it was a free-everything verb with NO log, NO readonly gate,
# NO undo and NO second entry point (a PURE SCRIPTED verb -- zero repo callers). It is a BARE no-arg
# mutating verb in the delete (atom 24) mold: the run_core arm is `unselect_all(1); clear_drawing();`
# (selection torn down BEFORE the storage resets free the selected objects -- the branch's original
# order), always TCL_OK (void core), bare-verb log via core_log_action's DEFAULT `xschem %s` arm.
#
# THE TWO WINS the boundary delivers:
#   - the ONE log site: silent -> logged (`xschem clear_drawing`, byte-exact bare form) -- check (a);
#   - the NEW readonly gate: pre-migration a READ-ONLY view was silently EMPTIED (the 0041/0051
#     class, like reset_symbol §42) -- check (c) proves the correctness fix.
# THE ONE FRICTION is the ARITY GATE (F-validate, the reset_inst_prop §33 argc-gate): the OLD branch
# acted only inside `if(argc==2)`, so `xschem clear_drawing <extra>` was a SILENT TCL_OK no-op that
# log-on-success would PHANTOM-log. run_core validates argc==2 and returns TCL_ERROR otherwise
# (mutating nothing, logging nothing) -- the ONE deliberate behaviour tighten; check (b) is its proof.
#
# ACCEPTED IRREVERSIBILITY (decision doc §2, locked by check (f)): NO push_undo exists anywhere on
# this path -- not in the old branch, not in the core, and NONE is added (a spurious run_core push
# is exactly what (f)'s detector catches). The logged line replays faithfully (re-clears whatever is
# loaded) but `xschem undo` cannot un-clear -- today's shipped behaviour, unchanged.
#
# THE SHARED-TEARDOWN SILENT-CORE rule (audit §4 log-at-the-verb; locked by check (g) + the S7
# actions.c row): clear_drawing() (actions.c) is a shared teardown primitive of SEVEN raw C flows
# (load_schematic x3, disk pop_undo, mem_restore_slot, delete_schematic_data, clear_schematic = the
# separate `xschem clear` verb, plus two debug sites). ALL stay raw + silent below the boundary; a
# core-side log would spam every load/undo/close -- check (g) drives the sibling `xschem clear` and
# asserts +0 `xschem clear_drawing` lines.
#
# Checks:
#   (a) SUCCESS: 3 placed instances; `xschem clear_drawing` -> instances==0, texts==0, wires==0,
#       `get symbols` still >=1 (the "does not purge symbols" contract -- the delta vs `xschem
#       clear`), exactly +1 byte-exact `xschem clear_drawing` line, interp result blank.
#   (b) ARITY TIGHTEN: `xschem clear_drawing extra` -> TCL_ERROR, NON-EMPTY verb-named message (the
#       §33 landmine: success-only Tcl_ResetResult must not wipe it), NO mutation, +0 log.
#       (Pre-migration oracle, pinned on HEAD 2026-07-18: silent TCL_OK no-op.)
#   (c) THE NEW GATE: readonly 1; `xschem clear_drawing` -> TCL_ERROR read-only message, NO
#       mutation, +0 log. (Pre-migration oracle: rc=0 and the read-only view was EMPTIED.)
#   (d) REPLAY: the recorded line re-executes through the replay_action_log suppress seam
#       (re-clears) WITHOUT re-logging; a control unwrapped `source` DOES re-log (+1).
#   (e) NO-OP-STILL-LOGS (§30): clearing an already-empty sheet is a void SUCCESS -> still +1.
#   (f) NO-SPURIOUS-PUSH / accepted irreversibility: place ONE instance on an empty sheet (the
#       placement pushes the pre-placement EMPTY snapshot); clear_drawing; ONE undo -> instances
#       STAYS 0 (undo restored the pre-placement empty snapshot). A spurious run_core push_undo
#       would snapshot WITH the instance, so the undo would read 1 -- the detector.
#   (g) SHARED CORE / SIBLING UNTOUCHED: `xschem clear force` still works (fresh untitled sheet,
#       instances==0) and logs +0 `xschem clear_drawing` lines (its clear_schematic core calls
#       clear_drawing() RAW below the boundary -- the F-shared spam lock).
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_clear_drawing.tcl
# doc/claude/code_analysis/perform_action_atom27_clear_drawing_decision.md §5

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers this in
# logdir_tests so LOG is always set in the real run; the guard keeps a bare invocation from erroring.
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Exact-line counters (the recorded verbs are single-line, so match the whole line).
proc lc {v} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0; foreach l [split $b \n] { if {$l eq "xschem $v"} { incr n } }; return $n
}
proc cdc {} { return [lc clear_drawing] }         ;# `xschem clear_drawing` count
proc ninst {} { return [xschem get instances] }

# Fixture: place `n` resistors at distinct coords; no selection.
proc fixture {{n 3}} {
  xschem clear force
  for {set i 0} {$i < $n} {incr i} {
    xschem instance devices/res.sym [expr {$i*40}] 0 0 0 "name=R[expr {$i+1}]"
  }
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: everything drawn is emptied, symbols survive, exactly +1 byte-exact
#     bare `xschem clear_drawing` (core_log_action default `xschem %s` arm), blank result.
# ---------------------------------------------------------------------------
fixture 3
check "(a) fixture: 3 instances placed" [expr {[ninst] == 3}] "instances=[ninst]"
check "(a) fixture: symbol table populated" [expr {[xschem get symbols] >= 1}] "symbols=[xschem get symbols]"
set c0 [cdc]
set res [xschem clear_drawing]
check "(a) scripted 'xschem clear_drawing' empties instances" [expr {[ninst] == 0}] "instances=[ninst]"
check "(a) texts emptied too" [expr {[xschem get texts] == 0}] "texts=[xschem get texts]"
check "(a) wires emptied too" [expr {[xschem get wires] == 0}] "wires=[xschem get wires]"
check "(a) symbols NOT purged (the contract delta vs 'xschem clear')" \
  [expr {[xschem get symbols] >= 1}] "symbols=[xschem get symbols]"
check "(a) interp result blank on success (boundary Tcl_ResetResult; no consumer existed)" \
  [expr {$res eq {}}] "res=>$res<"
check "(a) exactly +1 log line" [expr {[cdc] == $c0 + 1}] "c0=$c0 now=[cdc]"
# byte-exact bare form (core_log_action default `xschem %s` arm).
set fd [open [xschem get actionlog_filename] r]; set allD [read $fd]; close $fd
set exactD ""
foreach l [split $allD \n] { if {$l eq {xschem clear_drawing}} { set exactD $l } }
check "(a) logged line is byte-exact 'xschem clear_drawing' (bare-verb default form)" \
  [expr {$exactD eq "xschem clear_drawing"}] "got=>$exactD<"

# ---------------------------------------------------------------------------
# (b) THE ATOM-27 ARITY TIGHTEN. `xschem clear_drawing extra` -> TCL_ERROR, NON-EMPTY verb-named
#     message (the §33 landmine: success-only Tcl_ResetResult did not wipe it), NO mutation,
#     +0 log. Pre-migration oracle (HEAD 2026-07-18): rc=0, silent no-op.
# ---------------------------------------------------------------------------
fixture 3
set t0 [ninst]
set a0 [cdc]
set e1 [catch {xschem clear_drawing extra} m1]
check "(b) extra-arg: TCL_ERROR (was a silent no-op pre-migration)" [expr {$e1 == 1}] "rc=$e1"
check "(b) extra-arg: NON-EMPTY verb-named message (landmine: message survives on TCL_ERROR)" \
  [expr {[string match {*clear_drawing*argument*} $m1]}] "msg=>$m1<"
check "(b) extra-arg: NO log line (+0 -- failure not logged)" [expr {[cdc] == $a0}] "a0=$a0 now=[cdc]"
check "(b) extra-arg: NO mutation" [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"

# ---------------------------------------------------------------------------
# (c) THE NEW GATE. Pre-migration oracle (HEAD 2026-07-18): `xschem clear_drawing` on a READ-ONLY
#     view returned rc=0 and EMPTIED it. The boundary's ONE generic gate now refuses -> TCL_ERROR,
#     verb-named read-only message (non-empty), NO mutation, NO log.
# ---------------------------------------------------------------------------
fixture 3
set t0 [ninst]
xschem set readonly 1
set a0 [cdc]
set e3 [catch {xschem clear_drawing} m3]
check "(c) readonly: TCL_ERROR (pre-migration this silently EMPTIED the read-only view)" \
  [expr {$e3 == 1}] "rc=$e3"
check "(c) readonly: message names the verb + read-only (non-empty)" \
  [expr {[string match {*clear_drawing*read-only*} $m3]}] "msg=>$m3<"
check "(c) readonly: NO log line (+0)" [expr {[cdc] == $a0}] "a0=$a0 now=[cdc]"
check "(c) readonly: NO mutation (view NOT emptied)" [expr {[ninst] == $t0}] "before=$t0 after=[ninst]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) REPLAY. The recorded `xschem clear_drawing` replays through the replay_action_log suppress
#     seam: the effect applies (re-clears the loaded sheet) but is NOT re-logged; a control
#     unwrapped `source` DOES re-log.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_clear_drawing_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem clear_drawing"; close $fd

fixture 3
set nc [cdc]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (sheet emptied)" [expr {[ninst] == 0}] "instances=[ninst]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[cdc] == $nc}] "nc=$nc now=[cdc]"

fixture 3
set nc [cdc]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (sheet emptied)" [expr {[ninst] == 0}] "instances=[ninst]"
check "(d) control (unwrapped source): re-logged (+1, re-executable action)" \
  [expr {[cdc] == $nc + 1}] "nc=$nc now=[cdc]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) NO-OP-STILL-LOGS (§30). Clearing an already-EMPTY sheet is a void SUCCESS (the core returns
#     void => TCL_OK), so log-on-success still emits +1 -- clearing nothing is a success, not a
#     failure (the floaters/toggle_ignore/delete no-op class).
# ---------------------------------------------------------------------------
xschem clear force
check "(e) empty sheet fixture" [expr {[ninst] == 0}] "instances=[ninst]"
set c0 [cdc]
set e5 [catch {xschem clear_drawing} m5]
check "(e) no-op clear on empty sheet: still TCL_OK" [expr {$e5 == 0}] "rc=$e5 msg=>$m5<"
check "(e) no-op clear STILL logs +1 under log-on-success" [expr {[cdc] == $c0 + 1}] "c0=$c0 now=[cdc]"

# ---------------------------------------------------------------------------
# (f) NO-SPURIOUS-PUSH / accepted irreversibility. `xschem clear force` resets the undo stack;
#     placing ONE instance pushes the pre-placement EMPTY snapshot. clear_drawing pushes NOTHING
#     (the accepted shipped no-undo), so ONE undo restores the pre-placement EMPTY snapshot ->
#     instances STAYS 0. A spurious run_core push_undo would snapshot WITH the instance, so the
#     undo would read 1 -- that is what this detector catches.
# ---------------------------------------------------------------------------
xschem clear force
xschem instance devices/res.sym 0 0 0 0 "name=R1"
check "(f) fixture: ONE instance placed" [expr {[ninst] == 1}] "instances=[ninst]"
xschem clear_drawing
check "(f) clear_drawing emptied the sheet" [expr {[ninst] == 0}] "instances=[ninst]"
xschem undo
check "(f) ONE undo stays at 0 (restored the pre-placement EMPTY snapshot -- the shipped irreversibility; a spurious run_core push_undo would resurrect the instance -> 1)" \
  [expr {[ninst] == 0}] "instances=[ninst]"

# ---------------------------------------------------------------------------
# (g) SHARED CORE / SIBLING UNTOUCHED. `xschem clear force` (clear_schematic) calls clear_drawing()
#     RAW below the boundary: it must still work AND log +0 `xschem clear_drawing` lines. A
#     core-side log_action in clear_drawing() (the F-shared spam regression) would trip this.
# ---------------------------------------------------------------------------
fixture 3
set cd0 [cdc]
xschem clear force
check "(g) sibling 'xschem clear force' still clears (fresh untitled sheet)" \
  [expr {[ninst] == 0}] "instances=[ninst]"
check "(g) sibling 'xschem clear force' logs +0 'xschem clear_drawing' lines (raw core below the boundary stays SILENT)" \
  [expr {[cdc] == $cd0}] "cd0=$cd0 now=[cdc]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
