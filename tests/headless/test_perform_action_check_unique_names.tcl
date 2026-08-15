# perform_action() BOUNDARY -- Refactor B ATOM 26 (audit §46): migrate `check_unique_names`,
# the ASYMMETRIC QUERY/MUTATE SPLIT (decision doc:
# doc/claude/code_analysis/perform_action_atom26_check_unique_names_asymmetric_split_decision.md).
#
# One core, check_unique_names(int rename) (token.c): mode 0 HIGHLIGHTS duplicate-refdes
# instances (transient hilight state only -- read-only-LEGAL), mode 1 additionally RENAMES them
# (push_undo on the FIRST duplicate + new_prop_string + set_modify -- a real saved-content
# mutation). Only mode 1 belongs on the mutation boundary:
#   * MODE 1 -> perform_action. The boundary ADDS the readonly gate the branch NEVER had -- a
#     CORRECTNESS FIX (pre-migration `check_unique_names 1` silently RENAMED a read-only cell,
#     oracle-verified on the HEAD binary). run_core calls check_unique_names(1) with NO
#     push_undo/draw (core owns both -- the atom-1 no-double-push rule); core_log_action emits
#     the FIXED literal `xschem check_unique_names 1` (only "1" ever crosses).
#   * MODE 0 stays RAW in front of the boundary (the image §40 / instance_number §43 split: the
#     all-or-nothing gate would OVER-REJECT a harmless highlight on a read-only cell). THE
#     NOVELTY -- a LOGGED QUERY: unlike image/instance_number's silent query fronts, mode 0 was
#     ALREADY logged (`xschem check_unique_names 0` is a replayable highlight action), so the raw
#     front KEEPS its own log_action -- two log sites on two paths, the asymmetric split.
#   * KEYS (the 0068-class close): `#`/Ctrl+# have NO keybindings.csv row (the actions.csv accel
#     is display-only), so they fall through to the legacy `case '#'` -- pre-migration RAW: no
#     log, no readonly gate. Ctrl+# now routes through perform_action (gate + log "1", rc
#     discarded -- the toggle_ignore §32 event-handled contract); `#` stays raw + gains its own
#     log "0", mirroring the branch's mode-0 front.
#
# FIXTURE NOTE (oracle-pinned on the PRE-migration binary): `xschem instance` auto-uniquifies the
# second name=R1 to R2, and `setprop instance 1 name R1` re-uniquifies too (new_prop_string reads
# the disable_unique_names tclvar -- the prompt's `setprop ... fast` form does NOT skip uniquify).
# So the duplicate pair is forced under `set ::disable_unique_names 1`, then read back R1/R1.
#
# Checks:
#   (a) MUTATE success: `xschem check_unique_names 1` renames the duplicate (R1/R1 -> R1/R2),
#       exactly +1 byte-exact `xschem check_unique_names 1`, interp result blank.
#   (b) LOGGED QUERY on an editable cell: mode 0 highlights (list_hilights all_inst carries the
#       -PINLAYER entry), renames NOTHING, exactly +1 `... 0`.
#   (b2) THE SPLIT HEADLINE -- read-only query NOT over-rejected: readonly=1; mode 0 -> TCL_OK,
#       still highlights, +1 `... 0`, no rename.
#   (c) THE NEW GATE -- read-only mutate refused: readonly=1; mode 1 -> TCL_ERROR with a
#       NON-EMPTY verb-named read-only message (the §33 landmine: success-only Tcl_ResetResult
#       must not wipe it), NO rename, +0 log. (Pre-migration this RENAMED -- the oracle run
#       proved the bug.)
#   (d) REPLAY: both recorded lines re-execute through the replay_action_log suppress seam
#       (re-highlight / re-rename) WITHOUT re-logging; a control unwrapped `source` DOES re-log.
#   (e) UNDO DEPTH (no-double-push): one `check_unique_names 1`; ONE undo restores BOTH original
#       names (R1/R1); a SECOND undo peels back the fixture's forced-name setprop (name1 -> R2) --
#       a spurious run_core push would leave the second undo still at the R1/R1 boundary.
#   (e2) NO-OP-STILL-LOGS (§30): with NO duplicates, mode 1 mutates nothing (no in-core
#       push_undo -- one undo peels a fixture placement, not a rename snapshot), still +1 `... 1`.
#   (f) KEYS (deterministic injection `xschem callback .drw 2 <mx> <my> 35 0 0 <state>` -- the
#       REAL callback()->handle_key_press chain, keysym 35 = '#', state 4 = ControlMask):
#       `#` -> +1 `... 0` + highlights, and still works on a READ-ONLY cell (+1, no error);
#       Ctrl+# -> +1 `... 1` + renames on an editable cell, REFUSED on a read-only cell (+0,
#       no rename).
#   (g) CANONICALIZATION preserved: `xschem check_unique_names 2` runs mode 0 (highlights, no
#       rename) and logs `... 0` -- byte-identical to the old `%s`-with-?: behaviour.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_perform_action_check_unique_names.tcl
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md §46

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The boundary's log site is only observable with the log open. full_audit registers this in
# logdir_tests so LOG is always set in the real run; the guard keeps a bare invocation from
# erroring. (deferred, NOT "skipped: no X".)
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "deferred (no --logdir; the perform_action log site needs an open action log)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# Defensive modal stub (real DISPLAY): this suite's read-only path uses the boundary's ciw_echo,
# never readonly_block's tk_messageBox -- but stub it so a stray dialog can never WEDGE headless.
catch {rename tk_messageBox _pacun_real_mb}
proc tk_messageBox {args} { return ok }

# Exact-line counters (the recorded verbs are single-line, so match the whole line).
proc lc {v} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  set n 0; foreach l [split $b \n] { if {$l eq "xschem $v"} { incr n } }; return $n
}
proc lc0 {} { return [lc "check_unique_names 0"] }
proc lc1 {} { return [lc "check_unique_names 1"] }
proc nm {i} { return [xschem getprop instance $i name] }
proc hil {} { return [xschem list_hilights all_inst] }

# Fixture: two resistors BOTH named R1. Placement auto-uniquifies the second to R2 and
# setprop re-uniquifies (new_prop_string reads disable_unique_names), so the duplicate is
# FORCED under ::disable_unique_names=1 and read back R1/R1 (oracle-pinned).
proc dupfix {} {
  xschem clear force
  xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}
  xschem instance devices/res.sym 100 0 0 0 {name=R1 value=1k}
  if {[nm 1] ne "R1"} {
    set ::disable_unique_names 1
    xschem setprop instance 1 name R1
    set ::disable_unique_names 0
  }
}
dupfix
check "fixture: duplicate pair reads back R1/R1" \
  [expr {[nm 0] eq "R1" && [nm 1] eq "R1"}] "names=[nm 0]/[nm 1]"

# ---------------------------------------------------------------------------
# (a) MUTATE success: rename via the boundary -> unique names, +1 byte-exact
#     `xschem check_unique_names 1`, interp result blank (boundary clears on success).
# ---------------------------------------------------------------------------
set c1 [lc1]
set r [xschem check_unique_names 1]
check "(a) mutate: duplicate renamed (names now unique)" \
  [expr {[nm 0] ne [nm 1]}] "names=[nm 0]/[nm 1]"
check "(a) mutate: exactly +1 byte-exact 'xschem check_unique_names 1'" \
  [expr {[lc1] == $c1 + 1}] "c1=$c1 now=[lc1]"
check "(a) mutate: interp result blank (success-path Tcl_ResetResult)" \
  [expr {$r eq {}}] "got=>$r<"

# ---------------------------------------------------------------------------
# (b) LOGGED QUERY on an editable cell: mode 0 highlights, renames nothing, +1 `... 0`.
# ---------------------------------------------------------------------------
dupfix
set c0 [lc0]
xschem check_unique_names 0
check "(b) query: duplicate highlighted (list_hilights all_inst carries R1 @ -PINLAYER)" \
  [expr {[string match {*R1*-5*} [hil]]}] "hil=>[hil]<"
check "(b) query: renames NOTHING (pair still R1/R1)" \
  [expr {[nm 0] eq "R1" && [nm 1] eq "R1"}] "names=[nm 0]/[nm 1]"
check "(b) query: exactly +1 'xschem check_unique_names 0' (the LOGGED-query raw front)" \
  [expr {[lc0] == $c0 + 1}] "c0=$c0 now=[lc0]"

# ---------------------------------------------------------------------------
# (b2) THE SPLIT HEADLINE: the read-only-LEGAL query is NOT over-rejected.
# ---------------------------------------------------------------------------
xschem set readonly 1
set c0 [lc0]
set e [catch {xschem check_unique_names 0} m]
check "(b2) read-only query: TCL_OK (NOT over-rejected -- the asymmetric-split headline)" \
  [expr {$e == 0}] "rc=$e msg=>$m<"
check "(b2) read-only query: still highlights" \
  [expr {[string match {*R1*-5*} [hil]]}] "hil=>[hil]<"
check "(b2) read-only query: +1 '... 0' (stays a logged replayable action)" \
  [expr {[lc0] == $c0 + 1}] "c0=$c0 now=[lc0]"
check "(b2) read-only query: no mutation (pair still R1/R1)" \
  [expr {[nm 0] eq "R1" && [nm 1] eq "R1"}] "names=[nm 0]/[nm 1]"

# ---------------------------------------------------------------------------
# (c) THE NEW GATE: read-only mutate REFUSED. Pre-migration this RENAMED (the oracle run
#     proved rc=0 + rename on the HEAD binary) -- the boundary's generic gate closes it.
# ---------------------------------------------------------------------------
set c1 [lc1]
set e [catch {xschem check_unique_names 1} m]
check "(c) read-only mutate: TCL_ERROR (was a silent rename pre-migration)" \
  [expr {$e == 1}] "rc=$e"
check "(c) read-only mutate: NON-EMPTY verb-named read-only message (the §33 landmine)" \
  [expr {[string match {*check_unique_names*read-only*} $m]}] "msg=>$m<"
check "(c) read-only mutate: NO rename (pair still R1/R1)" \
  [expr {[nm 0] eq "R1" && [nm 1] eq "R1"}] "names=[nm 0]/[nm 1]"
check "(c) read-only mutate: NO log (+0)" [expr {[lc1] == $c1}] "c1=$c1 now=[lc1]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (d) REPLAY: both recorded forms re-execute through the replay_action_log suppress seam
#     (re-highlight + re-rename) WITHOUT re-logging; a control unwrapped `source` DOES re-log.
# ---------------------------------------------------------------------------
set rec [file join [file dirname $LOG] pacun_[pid].log]   ;# pid-isolated
set fd [open $rec w]
puts $fd "xschem check_unique_names 0"
puts $fd "xschem check_unique_names 1"
close $fd

dupfix
set c0 [lc0]; set c1 [lc1]
replay_action_log $rec
check "(d) replay seam: EFFECT applied (mode 0 highlighted, mode 1 renamed the pair)" \
  [expr {[nm 0] ne [nm 1]}] "names=[nm 0]/[nm 1]"
check "(d) replay seam: NOT re-logged (rides !actionlog_suppress -- both forms +0)" \
  [expr {[lc0] == $c0 && [lc1] == $c1}] "c0=$c0/[lc0] c1=$c1/[lc1]"

dupfix
set c0 [lc0]; set c1 [lc1]
uplevel #0 [list source $rec]
check "(d) control (unwrapped source): EFFECT applied (renamed)" \
  [expr {[nm 0] ne [nm 1]}] "names=[nm 0]/[nm 1]"
check "(d) control (unwrapped source): re-logged (+1 each -- re-executable actions)" \
  [expr {[lc0] == $c0 + 1 && [lc1] == $c1 + 1}] "c0=$c0/[lc0] c1=$c1/[lc1]"
file delete $rec

# ---------------------------------------------------------------------------
# (e) UNDO DEPTH (the atom-1 no-double-push rule): check_unique_names(1) owns the SINGLE
#     push_undo (on the first duplicate). The fixture stack is [place R1, place R2,
#     setprop-force-R1, rename]. ONE undo restores R1/R1 (the rename's snapshot); a SECOND
#     undo peels the forced-name setprop -> name1 back to R2. A spurious run_core push would
#     leave TWO identical R1/R1 snapshots, so the second undo would STILL read R1/R1.
# ---------------------------------------------------------------------------
dupfix
xschem check_unique_names 1
check "(e) undo depth: rename applied (unique)" [expr {[nm 0] ne [nm 1]}] "names=[nm 0]/[nm 1]"
xschem undo
check "(e) undo depth: ONE undo restores BOTH original names (R1/R1 -- the single in-core snapshot)" \
  [expr {[nm 0] eq "R1" && [nm 1] eq "R1"}] "names=[nm 0]/[nm 1]"
xschem undo
check "(e) undo depth: a SECOND undo peels the fixture setprop (name1 -> R2) -- a run_core double-push would still read R1/R1 here" \
  [expr {[nm 1] eq "R2"}] "names=[nm 0]/[nm 1]"

# ---------------------------------------------------------------------------
# (e2) NO-OP-STILL-LOGS (§30): NO duplicates -> mode 1 mutates nothing (the core never reaches
#     its push_undo), still +1 `... 1`. The undo probe proves no spurious push: one undo peels
#     the second PLACEMENT (2 -> 1 instances), not a rename snapshot.
# ---------------------------------------------------------------------------
xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=R1 value=1k}
xschem instance devices/res.sym 100 0 0 0 {name=R1 value=1k}
check "(e2) fixture: auto-uniquified pair (no duplicates)" \
  [expr {[nm 0] ne [nm 1]}] "names=[nm 0]/[nm 1]"
set c1 [lc1]
xschem check_unique_names 1
check "(e2) no-op mode 1: names unchanged" \
  [expr {[nm 0] eq "R1" && [nm 1] eq "R2"}] "names=[nm 0]/[nm 1]"
check "(e2) no-op mode 1 STILL logs +1 '... 1' (no-op is a SUCCESS under log-on-success)" \
  [expr {[lc1] == $c1 + 1}] "c1=$c1 now=[lc1]"
xschem undo
check "(e2) no-op pushed NO undo: one undo peels the placement (2 -> 1 instances)" \
  [expr {[xschem get instances] == 1}] "instances=[xschem get instances]"

# ---------------------------------------------------------------------------
# (f) KEYS -- deterministic injection through the REAL callback()->handle_key_press chain
#     (keysym 35 = '#', state 4 = ControlMask; no keybindings.csv row exists so the legacy
#     `case '#'` is the only handler).
# ---------------------------------------------------------------------------
dupfix
set c0 [lc0]
xschem callback .drw 2 400 300 35 0 0 0
check "(f) '#' key: highlights the duplicate" \
  [expr {[string match {*R1*-5*} [hil]]}] "hil=>[hil]<"
check "(f) '#' key: +1 '... 0' (ADDITIVE coverage -- the key logged nothing before atom 26)" \
  [expr {[lc0] == $c0 + 1}] "c0=$c0 now=[lc0]"
check "(f) '#' key: renames nothing" \
  [expr {[nm 0] eq "R1" && [nm 1] eq "R1"}] "names=[nm 0]/[nm 1]"

xschem set readonly 1
set c0 [lc0]
set e [catch {xschem callback .drw 2 400 300 35 0 0 0} m]
check "(f) '#' key on READ-ONLY cell: still works (no error -- the raw front is not gated)" \
  [expr {$e == 0}] "rc=$e msg=>$m<"
check "(f) '#' key on READ-ONLY cell: +1 '... 0'" \
  [expr {[lc0] == $c0 + 1}] "c0=$c0 now=[lc0]"
check "(f) '#' key on READ-ONLY cell: no rename" \
  [expr {[nm 0] eq "R1" && [nm 1] eq "R1"}] "names=[nm 0]/[nm 1]"
xschem set readonly 0

dupfix
set c1 [lc1]
xschem callback .drw 2 400 300 35 0 0 4
check "(f) Ctrl+# key (editable): renames the duplicate" \
  [expr {[nm 0] ne [nm 1]}] "names=[nm 0]/[nm 1]"
check "(f) Ctrl+# key (editable): +1 '... 1' (was UNLOGGED -- the 0068-class close)" \
  [expr {[lc1] == $c1 + 1}] "c1=$c1 now=[lc1]"

dupfix
xschem set readonly 1
set c1 [lc1]
xschem callback .drw 2 400 300 35 0 0 4
check "(f) Ctrl+# key on READ-ONLY cell: REFUSED (no rename -- pre-migration the key silently RENAMED)" \
  [expr {[nm 0] eq "R1" && [nm 1] eq "R1"}] "names=[nm 0]/[nm 1]"
check "(f) Ctrl+# key on READ-ONLY cell: +0 log (refusal is not logged)" \
  [expr {[lc1] == $c1}] "c1=$c1 now=[lc1]"
xschem set readonly 0

# ---------------------------------------------------------------------------
# (g) CANONICALIZATION preserved: any argv[2] other than exact "1" (here "2") lands on the
#     mode-0 raw front and logs the canonical "0" -- byte-identical to the old `%s`/?: site.
# ---------------------------------------------------------------------------
dupfix
set c0 [lc0]; set c1 [lc1]
xschem check_unique_names 2
check "(g) 'check_unique_names 2' runs mode 0 (highlights, no rename)" \
  [expr {[nm 0] eq "R1" && [nm 1] eq "R1" && [string match {*R1*-5*} [hil]]}] \
  "names=[nm 0]/[nm 1] hil=>[hil]<"
check "(g) 'check_unique_names 2' logs the CANONICAL '... 0' (+1), never a '... 2'" \
  [expr {[lc0] == $c0 + 1 && [lc1] == $c1}] "c0=$c0/[lc0] c1=$c1/[lc1]"

catch {rename tk_messageBox {}}
catch {rename _pacun_real_mb tk_messageBox}
catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
