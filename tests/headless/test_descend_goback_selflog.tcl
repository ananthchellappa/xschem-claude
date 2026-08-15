# Action-log coverage -- descend_symbol and go_back self-log at their C cores
# (issue 0071 atom 3).
#
# Both passed the 1:1 test (unlike atom 2's shared delete()): every caller of
# descend_symbol() / go_back() IS the user verb, so the log lives in the core:
#   descend_symbol() (save.c)  -> `xschem descend_symbol -inst <name>` -- the
#     SELF-CONTAINED form (replay selects the instance itself), because the
#     recording-time selection may come from an unlogged path (hi_descend
#     dialog) whose wrapper line the core-log dedup suppresses; a bare
#     selection-dependent line would diverge on replay (review finding).
#     Empty instname falls back to bare + flushed select_at, like descend.
#   go_back() (actions.c)      -> `xschem go_back` (`xschem go_back <what>` if what!=1)
#     (Ctrl-E, BackSpace, ctx menu call it directly; Tcl walk-ups arrive via the
#     branch and MUST log -- their descends already log via descend_schematic's
#     core self-log, so a silent ascend would drift the replayed hierarchy level.
#     The currsch==0 no-op and the save-prompt Cancel return before the log.)
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md
#
# Needs the action log open -> registered in full_audit.sh logdir_tests (--logdir):
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_descend_goback_selflog.tcl

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "SKIP: no action log open -- run with --logdir"
  puts "RESULT: SKIP (no log)"
  exit 0
}

# count log lines that EXACTLY match a verb (glob, no wildcard = exact line match)
proc logcount {pat} {
  if {[catch {open [xschem get actionlog_filename] r} fd]} { return -1 }
  set body [read $fd]; close $fd
  set n 0
  foreach line [split $body \n] { if {[string match $pat $line]} { incr n } }
  return $n
}
# `xschem descend` (into schematic) is a DIFFERENT verb (`xschem descend [-inst n]`)
# that must never be minted by a symbol descend
proc descend_sch_count {} {
  return [expr {[logcount {xschem descend}] + [logcount {xschem descend -inst*}]}]
}
# the canonical descend_symbol log line for the fixture instance
set DS {xschem descend_symbol -inst x1}

# hierarchy fixture: parent schematic with one instance x1 of descend_child.sym
set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
set work /tmp/atom3_descend_goback_work
file delete -force $work; file mkdir $work
foreach fn {descend_parent.sch descend_child.sch descend_child.sym} {
  file copy -force $fixdir/$fn $work/$fn
}
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work:$fixdir:$XSCHEM_LIBRARY_PATH"

# counting save-prompt stub: no section below may prompt unless it asserts so,
# and the Cancel sections steer the answer via ::ask_answer ("" = Cancel).
set ::ask_count 0
set ::ask_answer no
proc ask_save {{cmd {}}} { incr ::ask_count; return $::ask_answer }

xschem load $work/descend_parent.sch
check "fixture loaded (1 instance, at top level)" \
  [expr {[xschem get instances] == 1 && [xschem get currsch] == 0}]

# ---------------------------------------------------------------------------
# 1) script `xschem descend_symbol` -> exactly one self-contained
#    `xschem descend_symbol -inst x1`; never the bare form, never the
#    descend-into-schematic verb
# ---------------------------------------------------------------------------
xschem unselect_all
xschem select instance 0
set d0 [logcount $DS] ; set s0 [descend_sch_count]
xschem descend_symbol
check "script descend_symbol descended (currsch 0 -> 1)" [expr {[xschem get currsch] == 1}]
check "script descend_symbol -> +1 '$DS'" \
  [expr {[logcount $DS] == $d0 + 1}] "d0=$d0 now=[logcount $DS]"
check "script descend_symbol -> no bare 'xschem descend_symbol' line ever" \
  [expr {[logcount {xschem descend_symbol}] == 0}]
check "script descend_symbol -> +0 'xschem descend' (separate verb)" \
  [expr {[descend_sch_count] == $s0}]

# ---------------------------------------------------------------------------
# 2) script `xschem go_back` -> exactly one `xschem go_back`
# ---------------------------------------------------------------------------
set g0 [logcount "xschem go_back"]
xschem go_back
check "script go_back returned to top (currsch 1 -> 0)" [expr {[xschem get currsch] == 0}]
check "script go_back -> +1 'xschem go_back'" \
  [expr {[logcount {xschem go_back}] == $g0 + 1}] \
  "g0=$g0 now=[logcount {xschem go_back}]"

# ---------------------------------------------------------------------------
# 3) REPLAY: the logged -inst line is self-contained -- with NOTHING selected,
#    evaluating it verbatim descends (this is the review-finding regression
#    guard: a selection-dependent bare line would silently no-op here)
# ---------------------------------------------------------------------------
xschem unselect_all
set d0 [logcount $DS]
eval $DS
check "replaying '$DS' with empty selection descends" [expr {[xschem get currsch] == 1}]
check "the replay re-logs itself once (terminal-command norm)" \
  [expr {[logcount $DS] == $d0 + 1}]
xschem go_back
# unknown instance name -> TCL_ERROR, no descend, no line
set d0 [logcount $DS]
set rc [catch {xschem descend_symbol -inst no_such_inst} err]
check "descend_symbol -inst <bogus> errors out, stays at top, logs nothing" \
  [expr {$rc == 1 && [xschem get currsch] == 0 && [logcount $DS] == $d0 \
         && [logcount {xschem descend_symbol -inst*}] == $d0}] "rc=$rc err=$err"

# ---------------------------------------------------------------------------
# 4) no-op cases log NOTHING (refusal paths return before the core log)
# ---------------------------------------------------------------------------
xschem unselect_all
set d0 [logcount {xschem descend_symbol -inst*}]
xschem descend_symbol
check "no-op descend_symbol (empty selection) stayed at top" [expr {[xschem get currsch] == 0}]
check "no-op descend_symbol -> no phantom line" \
  [expr {[logcount {xschem descend_symbol -inst*}] == $d0}]
set g0 [logcount "xschem go_back"]
xschem go_back
check "no-op go_back (already at top) -> no phantom line" \
  [expr {[logcount {xschem go_back}] == $g0}]

# ---------------------------------------------------------------------------
# 5) non-default `what` is preserved: `xschem go_back 2` (the programmatic
#    no-title-reset form used by the traversal walk-ups) logs `xschem go_back 2`
# ---------------------------------------------------------------------------
xschem unselect_all
xschem select instance 0
xschem descend_symbol
set g0 [logcount "xschem go_back"] ; set g2 [logcount "xschem go_back 2"]
xschem go_back 2
check "go_back 2 returned to top" [expr {[xschem get currsch] == 0}]
check "go_back 2 -> +1 'xschem go_back 2'" \
  [expr {[logcount {xschem go_back 2}] == $g2 + 1}]
check "go_back 2 -> +0 bare 'xschem go_back'" [expr {[logcount {xschem go_back}] == $g0}]

check "sections 1-5 fired no save prompt" [expr {$::ask_count == 0}] "count=$::ask_count"

# ---------------------------------------------------------------------------
# 6) go_back save-prompt CANCEL refuses the ascend and logs NOTHING (the
#    Cancel early-return sits BEFORE the core log site)
# ---------------------------------------------------------------------------
xschem unselect_all
xschem select instance 0
xschem descend_symbol
xschem set readonly 0            ;# descended views may open read-only by default
xschem line -40 -45 40 -45       ;# genuine symbol edit -> modified -> go_back prompts
check "symbol view edit set modified" [expr {[xschem get modified] == 1}]
set ::ask_count 0 ; set ::ask_answer {}   ;# "" = Cancel
set g0 [logcount "xschem go_back"]
xschem go_back
check "cancelled go_back stayed put (still descended)" [expr {[xschem get currsch] == 1}]
check "cancelled go_back prompted once" [expr {$::ask_count == 1}] "count=$::ask_count"
check "cancelled go_back -> no 'xschem go_back' line" \
  [expr {[logcount {xschem go_back}] == $g0}]
set ::ask_count 0 ; set ::ask_answer no   ;# now discard the edit and really ascend
xschem go_back
check "declined-save go_back ascended and logged once" \
  [expr {[xschem get currsch] == 0 && [logcount {xschem go_back}] == $g0 + 1 && $::ask_count == 1}]

# ---------------------------------------------------------------------------
# 7) EMBEDDED-symbol descend cancel refuses BEFORE any log: save() cancel
#    (ask_save "") makes descend_symbol return 0 -- no line, no level change
# ---------------------------------------------------------------------------
set embpar $work/emb_parent.sch
set fp [open $embpar w]
puts $fp "v {xschem version=3.4.4 file_version=1.2}"
puts $fp "G {}"
puts $fp "V {}"
puts $fp "S {}"
puts $fp "E {}"
puts $fp "N 200 200 300 200 {}"
puts $fp "C {descend_child.sym} 0 0 0 0 {name=x1 embed=true}"
close $fp
file delete -force $work/emb_parent~.sch
xschem load $embpar
xschem wire 200 300 300 300      ;# modify the parent so the embedded guard fires
xschem unselect_all
xschem select instance 0
set ::ask_count 0 ; set ::ask_answer {}   ;# Cancel the embedded-save prompt
set d0 [logcount {xschem descend_symbol -inst*}]
xschem descend_symbol
check "cancelled embedded descend stayed at top" [expr {[xschem get currsch] == 0}]
check "cancelled embedded descend prompted" [expr {$::ask_count >= 1}] "count=$::ask_count"
check "cancelled embedded descend -> no descend_symbol line" \
  [expr {[logcount {xschem descend_symbol -inst*}] == $d0}]
set ::ask_answer no
xschem load $work/descend_parent.sch   ;# back to the clean fixture for the key tests

# ---------------------------------------------------------------------------
# 8/9/10) KEYBOARD + CONTEXT-MENU paths -- the actual 0071 gap: these call the
# cores DIRECTLY (never the scheduler branches) and used to log nothing.
#   `i`       -> `xschem descend_symbol -inst x1`
#   Ctrl-E    -> `xschem go_back`
#   BackSpace -> `xschem go_back`   (second direct caller, callback.c XK_BackSpace)
#   Ctrl-E at top level -> nothing (currsch==0 guard -> no phantom)
#   ctx-menu picks 13/14 -> exactly ONE line each (core log + table-copy dedup)
# Needs a real X window to dispatch key/button events.
# ---------------------------------------------------------------------------
if {[catch {winfo viewable .drw} vv] || !$vv} {
  check "keyboard/ctx-menu descend/go_back (skipped: no X)" 1 "no display"
} else {
  update idletasks; catch { focus -force .drw }; update idletasks
  # `i` key: keysym 'i' (0x69 = 105), state 0
  xschem unselect_all
  xschem select instance 0
  set d0 [logcount $DS]
  xschem callback .drw 2 0 0 105 0 0 0
  update idletasks
  check "'i' KEY descended (currsch 0 -> 1)" [expr {[xschem get currsch] == 1}]
  check "'i' KEY -> +1 '$DS'" [expr {[logcount $DS] == $d0 + 1}] \
    "d0=$d0 now=[logcount $DS]"
  # Ctrl-E: keysym 'e' (0x65 = 101), state ControlMask (4)
  set g0 [logcount "xschem go_back"]
  xschem callback .drw 2 0 0 101 0 0 4
  update idletasks
  check "Ctrl-E KEY returned to top (currsch 1 -> 0)" [expr {[xschem get currsch] == 0}]
  check "Ctrl-E KEY -> +1 'xschem go_back'" \
    [expr {[logcount {xschem go_back}] == $g0 + 1}]
  # BackSpace: keysym XK_BackSpace (0xFF08 = 65288), state 0
  xschem unselect_all
  xschem select instance 0
  xschem descend_symbol
  set g0 [logcount "xschem go_back"]
  xschem callback .drw 2 0 0 65288 0 0 0
  update idletasks
  check "BackSpace KEY returned to top (currsch 1 -> 0)" [expr {[xschem get currsch] == 0}]
  check "BackSpace KEY -> +1 'xschem go_back'" \
    [expr {[logcount {xschem go_back}] == $g0 + 1}]
  # Ctrl-E at TOP level: go_back(1) hits the currsch==0 no-op -> no line
  set g0 [logcount "xschem go_back"]
  xschem callback .drw 2 0 0 101 0 0 4
  update idletasks
  check "Ctrl-E KEY at top level -> no phantom 'xschem go_back'" \
    [expr {[logcount {xschem go_back}] == $g0}]

  # context menu: stub the Tcl `context_menu` chooser, fire a Button3 release
  # (ButtonRelease=5, state=Button3Mask=1024) -- the seam that calls
  # context_menu_action. Its ctxmenu_log_cmd table carries copies of both
  # commands; actionlog_cmd_logged dedup must keep them to ONE line each.
  xschem unselect_all
  xschem select instance 0
  set d0 [logcount $DS]
  proc context_menu {} { return 13 }
  xschem callback .drw 5 100 100 0 3 0 1024
  update idletasks
  check "ctx-menu pick 13 descended" [expr {[xschem get currsch] == 1}]
  check "ctx-menu pick 13 -> exactly +1 (core log, table copy deduped)" \
    [expr {[logcount $DS] == $d0 + 1 && [logcount {xschem descend_symbol}] == 0}] \
    "d0=$d0 now=[logcount $DS]"
  set g0 [logcount "xschem go_back"]
  proc context_menu {} { return 14 }
  xschem callback .drw 5 100 100 0 3 0 1024
  update idletasks
  check "ctx-menu pick 14 returned to top" [expr {[xschem get currsch] == 0}]
  check "ctx-menu pick 14 -> exactly +1 'xschem go_back' (deduped)" \
    [expr {[logcount {xschem go_back}] == $g0 + 1}] \
    "g0=$g0 now=[logcount {xschem go_back}]"
}

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
