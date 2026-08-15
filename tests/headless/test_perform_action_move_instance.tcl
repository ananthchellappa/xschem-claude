# perform_action() BOUNDARY -- Refactor B ATOM 19: the NINETEENTH per-verb migration
# (audit §39 / §38 / §37 / §34 / §33 / §4). A HIGHER-FRICTION coverage gain now the
# friction-free pool is EMPTY -- a PURE SCRIPTED instance-reposition verb (`xschem
# move_instance inst x y rot flip [nodraw] [noundo]`, a `-` in any of x/y/rot/flip keeps
# the existing value) that logged NOTHING before this atom, carrying an INLINE mutation
# body (strictly 1:1 with the verb -- C3, no shared mutating core, like apply_pin_prop §38),
# a CONDITIONAL push_undo/draw (the noundo/nodraw C5 sub-mode) and an instance-name referent.
#
# It follows the apply_pin_prop §38 INLINE-body extraction + the reset_inst_prop §33
# single-referent + argc-gate templates, crossed with a CONDITIONAL single push_undo
# (replace_symbol §34 owns-the-push, but the flag GATES ONLY the undo, NOT the log) and the
# wire_cut §37 "log the flag FAITHFULLY" decision (see below).
#
# Migration (scheduler.c only -- no callback.c edit; a pure scripted verb):
#   - Branch (xschem_cmds_m) -> `return perform_action("move_instance", argc, argv)`. The
#     !xctx guard + the per-verb scheduler_readonly_reject are DROPPED (the boundary re-checks
#     both -- a readonly CONSOLIDATION, not a new gate: the old branch already refused on a
#     read-only cell, and test_readonly_guard.tcl locks that pre-migration).
#   - run_core arm = the WHOLE inline body verbatim: the argc<7 VALIDATION (early TCL_ERROR
#     BEFORE any mutation -- and BEFORE core_log_action could read argv[3..6] OOB on a short
#     call, the embed_rawfile §36 crash class), the nodraw/noundo flag parse, the get_instance
#     "instance not found" validation, `if(undo) push_undo()` (ONE conditional push owned here),
#     the dashed x/y/rot/flip sets, symbol_bbox + prep-flag resets, `if(dr) draw()`. NO
#     set_modify (the branch had none; a move on a SAVED sheet leaves modified==0). NO success
#     Tcl_SetResult (an incidental "0" leaks from an internal tcleval on the mutation path; the
#     boundary's success-path Tcl_ResetResult blanks it uniformly, no caller consumes it).
#   - core_log_action arm = the FAITHFUL FULL CALL `xschem move_instance <inst> <x> <y> <rot>
#     <flip> [nodraw] [noundo]` via log_action_argv/Tcl_Merge (instance name metachar-safe), a
#     `mi` array DISTINCT from av/ev/pp (the §36 collision lesson).
#
# THE noundo/nodraw LOG DECISION (the load-bearing design call, RESOLVED FROM THE CALLERS).
# Both flags are LOGGED FAITHFULLY -- the wire_cut `noalign` approach (§37), NOT the
# replace_symbol `fast` gate (§34). `fast` is a machinery sub-mode: replace_symbol is an
# internal sub-step of a larger logged op, so logging each `fast` call double-logs -> gate it
# OUT. move_instance has NO such internal caller -- grep-verified PURE SCRIPTED (no key/menu/
# palette/callback/C/Tcl caller). So nodraw/noundo are faithful user args a replay must
# reproduce; they are logged, not gated, and re-emitted in CANONICAL order (nodraw before
# noundo) -- order-independent booleans, so the canonical line replays to the identical effect.
#
# THE ARGC GATE -- a VALIDATING behaviour delta (check (b)). The old branch SILENTLY no-op'd on
# a short call (`if(argc>6)` false -> nothing, TCL_OK). The migration makes argc<7 an early
# TCL_ERROR + verb-named message, and -- via log-on-success -- records NO phantom line AND
# prevents core_log_action from reading argv[3..6] OUT OF BOUNDS. No caller relies on the
# silent no-op (grep-clean pure scripted). Captured in check (b).
#
# THE READONLY GATE -- a CONSOLIDATION, not a new fix (check (c)). The old branch ALREADY had a
# per-verb scheduler_readonly_reject (unlike apply_pin_prop §38 / embed_rawfile §36, where the
# boundary ADDED the gate). The migration REMOVES the per-verb gate and the boundary's generic
# one covers it -- SAME behaviour before/after (the reset_inst_prop §33 / replace_symbol §34
# consolidation). test_readonly_guard.tcl asserts move_instance refuses on both binaries.
#
# Checks:
#   (a) SUCCESS: a full move changes x0/y0/rot/flip + logs exactly +1 FAITHFUL line + byte-exact
#       `xschem move_instance R1 100 40 90 0` + the interp RESULT is BLANK (the boundary blanks
#       the incidental "0" leak). (a2) a metachar instance name (x2[3:0]) logs BRACE-QUOTED via
#       Tcl_Merge + replays without a Tcl error + re-moves.
#   (b) argc/validation gate: bare `xschem move_instance R1` (argc<7) AND `xschem move_instance`
#       (argc==2, the OOB-crash class) each -> TCL_ERROR + NON-EMPTY verb-named "needs:" message +
#       +0 log + NO mutation; `xschem move_instance BOGUS 1 1 0 0` -> TCL_ERROR "instance not
#       found" + +0 log + no mutation (failure is not logged, message survives success-only reset).
#   (c) READONLY reject (the CONSOLIDATION): TCL_ERROR + verb-named read-only message + no move +
#       +0 log -- SAME as pre-migration (the per-verb gate moved onto the boundary).
#   (d) noundo: `xschem move_instance R1 100 0 0 0 noundo` pushes NOTHING (one undo does NOT
#       restore the pre-move position -- it unwinds the instance PLACEMENT, so instances -> 0),
#       AND the noundo-log decision: the line is LOGGED WITH the `noundo` flag (faithful, not
#       gated). nodraw likewise (mutation identical + flag logged).
#   (e) REPLAY: the recorded line re-EXECUTES through the replay_action_log suppress seam but does
#       NOT re-log; a control unwrapped `source` DOES re-log.
#   (f) UNDO DEPTH normal move = SINGLE conditional push_undo: `xschem move_instance R1 100 0 0 0`
#       -> ONE undo restores the pre-move x0 (100 -> 0) with the instance PRESENT (instances==1);
#       a SECOND undo unwinds the placement (instances==0). A spurious extra push_undo would leave
#       x0==100 after undo#1 (post-move snapshot) OR the instance surviving undo#2 -- the
#       discriminator (the §33/§38 undo-depth lesson).
#   (g) DASHED keep-existing + nodraw + NO set_modify: `xschem move_instance R1 - - 180 -` changes
#       ONLY rot (x0/y0/flip untouched); `... nodraw` mutates identically; a move on a SAVED sheet
#       leaves modified==0 (no set_modify added).
#
# Effect oracle (byte-identical WRITABLE effect before/after atom 19 -- the migration MOVES the
# body + gates the log, it does not change the reposition): a resistor (devices/res.sym) placed
# at the origin (0 0 0 0). `xschem move_instance R1 100 40 90 0` sets x0=100 y0=40 rot=90 flip=0
# (read back via `xschem instance_coord R1` -> `{R1} {res.sym} 100 40 90 0`). Determined
# empirically on the pre-migration binary; the argc silent-no-op, the result "0" leak, the
# noundo undo-depth, the metachar round-trip and the no-set_modify all pinned there.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_move_instance.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §39

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers
# this in logdir_tests so LOG is always set in the real run; the guard keeps a bare
# invocation from erroring. (deferred, NOT "skipped: no X".)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# ANY move_instance* line -- to prove a FAILED call logs NOTHING and to count faithful logs.
proc mic {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match {xschem move_instance*} $l]} { incr n } }
  return $n
}
# lines exactly matching a pattern
proc micpat {pat} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
# instance_coord R1 -> {R1} {res.sym} x0 y0 rot flip ; fields 2..5
proc coordf {ref idx} { return [lindex [string trim [xschem instance_coord $ref]] $idx] }
proc x0v {} { return [coordf R1 2] }
proc y0v {} { return [coordf R1 3] }
proc rotv {} { return [coordf R1 4] }
proc flipv {} { return [coordf R1 5] }

# Fixture: a resistor placed at the origin (0 0 0 0). move_instance targets by NAME, so no
# selection is needed. `clear force` resets the undo stack; the instance-place snapshot is the
# only pre-existing undo slot, so undo depth is deterministic.
proc fixture {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}
  xschem redraw
}

# ---------------------------------------------------------------------------
# (a) SUCCESS: a full move changes x0/y0/rot/flip, logs exactly +1 faithful line, the logged
#     line is byte-exact, and the interp result is BLANK (the boundary blanks the "0" leak).
# ---------------------------------------------------------------------------
fixture
check "(a) fixture: R1 at the origin (0 0 0 0)" \
  [expr {[x0v] eq "0" && [y0v] eq "0" && [rotv] eq "0" && [flipv] eq "0"}] "coord=[string trim [xschem instance_coord R1]]"
set c0 [mic]
set r [xschem move_instance R1 100 40 90 0]
check "(a) move -> exactly +1 log line" [expr {[mic] == $c0 + 1}] "c0=$c0 now=[mic]"
check "(a) effect applied: x0=100 y0=40 rot=90 flip=0" \
  [expr {[x0v] eq "100" && [y0v] eq "40" && [rotv] eq "90" && [flipv] eq "0"}] "coord=[string trim [xschem instance_coord R1]]"
check "(a) RESULT BLANK: the boundary blanks the pre-migration incidental '0' leak" [expr {$r eq ""}] "r=>$r<"
# byte-exact: Tcl_Merge quotes MINIMALLY, so a plain refdes + numeric coords log unbraced.
check "(a) logged line is byte-exact 'xschem move_instance R1 100 40 90 0'" \
  [expr {[micpat {xschem move_instance R1 100 40 90 0}] == 1}] "count=[micpat {xschem move_instance R1 100 40 90 0}]"

# (a2) METACHAR referent (the §33 replay-safe lesson): an arrayed instance name `x2[3:0]` carries
# Tcl metacharacters. A RAW line would replay `[3:0]` as a command substitution; log_action_argv/
# Tcl_Merge brace-quotes it. Assert the logged line is brace-quoted AND replaying it re-moves.
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=x2[3:0] value=1k}
xschem redraw
set nm [xschem getprop instance 0 name]
check "(a2) arrayed instance instname is literally x2\[3:0\]" [string equal $nm {x2[3:0]}] "name=$nm"
xschem move_instance {x2[3:0]} 50 0 0 0
check "(a2) arrayed name: move applied (x0 -> 50)" [expr {[coordf {x2[3:0]} 2] eq "50"}] "x0=[coordf {x2[3:0]} 2]"
set fd [open [xschem get actionlog_filename] r]; set allA [read $fd]; close $fd
set exactA ""
foreach l [split $allA \n] { if {[string match {xschem move_instance *x2*} $l]} { set exactA $l } }
check "(a2) arrayed name logged BRACE-QUOTED (Tcl_Merge), not raw" \
  [expr {$exactA eq {xschem move_instance {x2[3:0]} 50 0 0 0}}] "got=>$exactA<"
# replay-safety: re-place at the origin, eval the EXACT logged line, assert it resolved + moved.
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=x2[3:0] value=1k}
xschem redraw
set rrc [catch {uplevel #0 $exactA} rres]
check "(a2) arrayed name: the logged line REPLAYS without a Tcl error (metachar-safe)" [expr {$rrc == 0}] "rc=$rrc res=>$rres<"
check "(a2) arrayed name: replay applied the move (x0 -> 50)" [expr {[coordf {x2[3:0]} 2] eq "50"}] "x0=[coordf {x2[3:0]} 2]"

# ---------------------------------------------------------------------------
# (b) argc/validation gate: a short call and the not-found call each -> TCL_ERROR, NON-EMPTY
#     verb-named message, +0 log, NO mutation. The message-non-empty check is the landmine
#     proof (success-only reset did not wipe it). `xschem move_instance` (argc==2) is the
#     OOB-crash class -- the gate must fire before core_log_action reads argv[3..6].
# ---------------------------------------------------------------------------
fixture
set t0x [x0v]
set a0 [mic]
set e1 [catch {xschem move_instance R1} m1]
check "(b) short (argc<7): TCL_ERROR" [expr {$e1 == 1}] "rc=$e1"
check "(b) short: NON-EMPTY verb-named message (landmine: Tcl_ResetResult did not wipe it)" \
  [expr {[string match {*move_instance*needs*} $m1]}] "msg=>$m1<"
check "(b) short: NO log line (+0 -- failure not logged, no phantom line)" [expr {[mic] == $a0}] "a0=$a0 now=[mic]"
check "(b) short: NO mutation" [expr {[x0v] eq $t0x}] "before=$t0x after=[x0v]"

set a1 [mic]
set e2 [catch {xschem move_instance} m2]
check "(b) bare (argc==2, the OOB class): TCL_ERROR (no crash -- gate before core_log_action reads argv 3..6)" [expr {$e2 == 1}] "rc=$e2"
check "(b) bare: NON-EMPTY verb-named message" [expr {[string match {*move_instance*needs*} $m2]}] "msg=>$m2<"
check "(b) bare: NO log line (+0)" [expr {[mic] == $a1}] "a1=$a1 now=[mic]"

set a2 [mic]
set e3 [catch {xschem move_instance BOGUS 1 1 0 0} m3]
check "(b) not-found: TCL_ERROR" [expr {$e3 == 1}] "rc=$e3"
check "(b) not-found: NON-EMPTY verb-named message (landmine)" \
  [expr {[string match {*move_instance*not found*} $m3]}] "msg=>$m3<"
check "(b) not-found: NO log line (+0 -- failure not logged)" [expr {[mic] == $a2}] "a2=$a2 now=[mic]"
check "(b) not-found: NO mutation" [expr {[x0v] eq $t0x}] "before=$t0x after=[x0v]"

# ---------------------------------------------------------------------------
# (c) READONLY reject (the CONSOLIDATION): the boundary's ONE generic gate refuses -> TCL_ERROR,
#     verb-named read-only message (non-empty), NO mutation, NO log. SAME behaviour as
#     pre-migration (the old branch had a per-verb gate; it moved onto the boundary --
#     test_readonly_guard.tcl locks the pre-migration refusal).
# ---------------------------------------------------------------------------
fixture
set t0x [x0v]
xschem set readonly 1
set a0 [mic]
set e4 [catch {xschem move_instance R1 100 40 90 0} m4]
check "(c) readonly: TCL_ERROR" [expr {$e4 == 1}] "rc=$e4"
check "(c) readonly: message names the verb + read-only (non-empty)" \
  [expr {[string match {*move_instance*read-only*} $m4]}] "msg=>$m4<"
check "(c) readonly: NO log line (+0)" [expr {[mic] == $a0}] "a0=$a0 now=[mic]"
check "(c) readonly: NO mutation" [expr {[x0v] eq $t0x}] "before=$t0x after=[x0v]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) noundo: the CONDITIONAL push_undo is SKIPPED (`if(undo)`), so the move pushes NOTHING --
#     one undo unwinds the instance PLACEMENT (instances -> 0), it does NOT restore the pre-move
#     position. AND the noundo-log decision: the line is LOGGED WITH the `noundo` flag (faithful,
#     the wire_cut approach -- NOT gated out like replace_symbol's fast).
# ---------------------------------------------------------------------------
fixture
set c0 [mic]
xschem move_instance R1 100 0 0 0 noundo
check "(d) noundo: move applied (x0 -> 100)" [expr {[x0v] eq "100"}] "x0=[x0v]"
check "(d) noundo: exactly +1 log line" [expr {[mic] == $c0 + 1}] "c0=$c0 now=[mic]"
check "(d) noundo LOG DECISION: the line is logged WITH the noundo flag (faithful, not gated)" \
  [expr {[micpat {xschem move_instance R1 100 0 0 0 noundo}] == 1}] "count=[micpat {xschem move_instance R1 100 0 0 0 noundo}]"
xschem undo
check "(d) noundo: ONE undo removes the instance (the move pushed NOTHING, so undo unwinds the placement) -- an unconditional push would leave the instance + restore x0=0 here" \
  [expr {[xschem get instances] == 0}] "instances=[xschem get instances]"

# nodraw: the mutation is identical (headless can't observe the draw); assert the flag logs too.
fixture
set c0 [mic]
xschem move_instance R1 55 66 0 0 nodraw
check "(d) nodraw: move applied identically (x0=55 y0=66)" [expr {[x0v] eq "55" && [y0v] eq "66"}] "coord=[string trim [xschem instance_coord R1]]"
check "(d) nodraw LOG: the line is logged WITH the nodraw flag" \
  [expr {[micpat {xschem move_instance R1 55 66 0 0 nodraw}] == 1}] "count=[micpat {xschem move_instance R1 55 66 0 0 nodraw}]"

# ---------------------------------------------------------------------------
# (e) REPLAY. The recorded line re-EXECUTES through the replay_action_log suppress seam but does
#     NOT re-log; a control unwrapped `source` DOES re-log. move_instance is self-contained
#     (name + coords in the line), so replay re-resolves + re-moves.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] paw_move_instance_[pid].log]   ;# pid-isolated
set fd [open $rec w]; puts $fd "xschem move_instance R1 100 40 90 0"; close $fd

fixture
set nc [mic]
replay_action_log $rec
check "(e) replay seam: EFFECT applied (x0 -> 100, rot -> 90)" [expr {[x0v] eq "100" && [rotv] eq "90"}] "coord=[string trim [xschem instance_coord R1]]"
check "(e) replay seam: NOT re-logged (rides !actionlog_suppress)" [expr {[mic] == $nc}] "nc=$nc now=[mic]"

fixture
set nc [mic]
uplevel #0 [list source $rec]
check "(e) control (unwrapped source): EFFECT applied (x0 -> 100)" [expr {[x0v] eq "100"}] "x0=[x0v]"
check "(e) control (unwrapped source): re-logged (+1, re-executable action)" [expr {[mic] == $nc + 1}] "nc=$nc now=[mic]"
file delete $rec

# ---------------------------------------------------------------------------
# (f) UNDO DEPTH (the atom-1 no-double-push rule): run_core owns the SINGLE conditional push_undo
#     (captured BEFORE the sets, so the snapshot is the pre-move position). The fixture's undo
#     stack holds the instance-place snapshot + the move's ONE push. So ONE undo restores the
#     pre-move x0 (100 -> 0) with the instance PRESENT, and a SECOND undo unwinds the placement
#     (instances -> 0). A spurious run_core double-push would leave x0==100 after undo#1 (a
#     post-move snapshot) OR the instance surviving undo#2 -- the discriminator.
# ---------------------------------------------------------------------------
fixture
xschem move_instance R1 100 0 0 0
check "(f) undo depth: move took (x0 -> 100)" [expr {[x0v] eq "100"}] "x0=[x0v]"
xschem undo
check "(f) undo depth: ONE undo restores the pre-move x0 (100 -> 0), instance PRESENT (single push captured the pre-move state)" \
  [expr {[x0v] eq "0" && [xschem get instances] == 1}] "x0=[x0v] instances=[xschem get instances]"
xschem undo
check "(f) undo depth: a SECOND undo unwinds the placement (instances -> 0) -- move's single push is the ONLY move snapshot; a double-push would leave the instance here" \
  [expr {[xschem get instances] == 0}] "instances=[xschem get instances]"

# ---------------------------------------------------------------------------
# (g) DASHED keep-existing + nodraw + NO set_modify. `xschem move_instance R1 - - 180 -` changes
#     ONLY rot; a move on a SAVED sheet leaves modified==0 (the branch had no set_modify).
# ---------------------------------------------------------------------------
fixture
xschem move_instance R1 - - 180 -
check "(g) dashed keep-existing: ONLY rot changed (x0=0 y0=0 rot=180 flip=0)" \
  [expr {[x0v] eq "0" && [y0v] eq "0" && [rotv] eq "180" && [flipv] eq "0"}] "coord=[string trim [xschem instance_coord R1]]"

# NO set_modify: save the fixture (clears modified) then move; modified must stay 0.
set recf [file join [file dirname $LOG] paw_move_instance_mod_[pid].sch]
fixture
xschem saveas $recf
check "(g) set_modify oracle: modified==0 after saveas" [expr {[xschem get modified] == 0}] "modified=[xschem get modified]"
xschem move_instance R1 100 0 0 0
check "(g) NO set_modify added: a move on a SAVED sheet leaves modified==0 (byte-faithful body)" \
  [expr {[xschem get modified] == 0}] "modified=[xschem get modified]"
file delete $recf

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
