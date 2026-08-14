# Action-log coverage -- the three silent scheduler mutator branches record to
# the action log: File Save (`xschem save`), Reload (`xschem reload`), Edit Copy
# (`xschem copy`) -- issue 0062 remainder (issue 0071 atom 4).
#
# All three failed the 1:1 core test (atom-2 pattern, NOT atom-3):
#   save   -> save() (actions.c) is a shared confirm-wrapper also entered from
#             go_back/descend/window-close flows; the log lives at the ENTRY
#             sites: the scheduler branch (named-file arm only; the unnamed arm
#             delegates to saveas() whose dialog arm self-logs the resolved
#             `xschem saveas {f} schematic`) + the inline Ctrl-S key handler.
#             POLICY: an unmodified no-op save still logs (slice-1 norm; save()
#             force-writes on external mtime change so a modified-gate would
#             drop real writes); `save fast` = internal cellview machinery and
#             stays SILENT (setprop -fast axis).
#   reload -> the branch logs (`xschem reload` / `xschem reload zoom_full`);
#             action_reload's old Tcl-side log line was REMOVED (single site);
#             confirm dialogs live in the callers so Cancel logs nothing; the
#             inline Alt-S key reloads directly and logs at its own ok-arm.
#   copy   -> the branch logs `xschem copy` (mirrors cut, slice 1); the inline
#             Ctrl-C key + ctx-menu pick 15 call save_selection() directly and
#             log at their own sites (Ctrl-C under the selection guard).
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md
#
# Needs the action log open -> registered in full_audit.sh logdir_tests (--logdir):
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_save_reload_copy_selflog.tcl

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

# count log lines that EXACTLY match a pattern (glob, no wildcard = exact match)
proc logcount {pat} {
  if {[catch {open [xschem get actionlog_filename] r} fd]} { return -1 }
  set body [read $fd]; close $fd
  set n 0
  foreach line [split $body \n] { if {[string match $pat $line]} { incr n } }
  return $n
}

# scratch schematic (2 wires) in a private /tmp dir; paths derived from the
# script location, never [pwd] (cwd-independence, cf. 389c5319/39e4e431)
set work /tmp/atom4_save_reload_copy_work
file delete -force $work; file mkdir $work
set SCH $work/atom4.sch
proc write_fixture {f} {
  set fp [open $f w]
  puts $fp "v {xschem version=3.4.4 file_version=1.2}"
  puts $fp "G {}"
  puts $fp "V {}"
  puts $fp "S {}"
  puts $fp "E {}"
  puts $fp "N 100 100 200 100 {lab=A}"
  puts $fp "N 100 200 200 200 {lab=B}"
  close $fp
}
write_fixture $SCH

# COUNTING confirm stubs (atom-3 review finding: a bare `return x` stub masks
# regressions -- every section asserts its expected prompt count):
#   ask_save       -- must NEVER fire in this test (save is always confirm=0)
#   alert_         -- the action_reload / toolbar FileReload confirm dialog
#   tk_messageBox  -- the inline Alt-S reload confirm dialog
set ::ask_count 0    ; set ::ask_answer yes
set ::alert_count 0  ; set ::alert_answer 1
set ::msgbox_count 0 ; set ::msgbox_answer ok
proc ask_save {{cmd {}}} { incr ::ask_count; return $::ask_answer }
proc alert_ {msg {icon {}} {nowait 0} {cancel 0}} { incr ::alert_count; return $::alert_answer }
proc tk_messageBox {args} { incr ::msgbox_count; return $::msgbox_answer }

xschem load $SCH
check "fixture loaded (2 wires, unmodified)" \
  [expr {[xschem get wires] == 2 && ![xschem get modified]}]

set have_x [expr {![catch {winfo viewable .drw} vv] && $vv}]

# ---------------------------------------------------------------------------
# 1) COPY
# ---------------------------------------------------------------------------
# 1a) script `xschem copy` with a selection -> exactly +1 `xschem copy`
xschem unselect_all
xschem select wire 0
set c0 [logcount {xschem copy}]
xschem copy
check "script copy (selection) -> +1 'xschem copy'" \
  [expr {[logcount {xschem copy}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem copy}]"

# 1b) script copy on EMPTY selection: no-op still logs (slice-1 norm, branch
#     comment documents it; clipboard-only so the replayed line is always safe)
xschem unselect_all
set c0 [logcount {xschem copy}]
xschem copy
check "script copy (empty selection) still logs (slice-1 no-op norm)" \
  [expr {[logcount {xschem copy}] == $c0 + 1}]

if {$have_x} {
  # 1c) Ctrl-C key (keysym 'c'=99, state ControlMask=4): inline handler calls
  #     save_selection() directly (bypasses the branch) -> its own log site
  update idletasks; catch { focus -force .drw }; update idletasks
  xschem unselect_all
  xschem select wire 0
  set c0 [logcount {xschem copy}]
  xschem callback .drw 2 0 0 99 0 0 4
  update idletasks
  check "Ctrl-C KEY (selection) -> +1 'xschem copy'" \
    [expr {[logcount {xschem copy}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem copy}]"

  # 1d) Ctrl-C with NOTHING selected: under the selection guard -> no phantom
  xschem unselect_all
  set c0 [logcount {xschem copy}]
  xschem callback .drw 2 0 0 99 0 0 4
  update idletasks
  check "Ctrl-C KEY (empty selection) -> no phantom line" \
    [expr {[logcount {xschem copy}] == $c0}]

  # 1e) ctx-menu pick 15 (copy): direct save_selection() + ctxmenu_log_cmd table
  #     copy under the actionlog_cmd_logged dedup -> EXACTLY one line
  #     (test_context_menu_log check 1 asserts the same line exists; keep green)
  xschem unselect_all
  xschem select wire 0
  set c0 [logcount {xschem copy}]
  proc context_menu {} { return 15 }
  xschem callback .drw 5 100 100 0 3 0 1024
  update idletasks
  check "ctx-menu pick 15 -> exactly +1 'xschem copy' (table, deduped)" \
    [expr {[logcount {xschem copy}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem copy}]"
} else {
  check "keyboard/ctx-menu copy (skipped: no X)" 1 "no display"
}

# ---------------------------------------------------------------------------
# 2) SAVE
# ---------------------------------------------------------------------------
# 2a) script save of a MODIFIED buffer -> +1 `xschem save`, buffer clean after
xschem unselect_all
xschem wire 300 300 400 300
check "edit set modified" [expr {[xschem get modified] == 1}]
set s0 [logcount {xschem save}]
xschem save
check "script save (modified) -> +1 'xschem save'" \
  [expr {[logcount {xschem save}] == $s0 + 1}] "s0=$s0 now=[logcount {xschem save}]"
check "script save wrote (modified flag cleared)" [expr {![xschem get modified]}]

# 2b) no-op save (unmodified buffer) STILL LOGS -- the documented policy
set s0 [logcount {xschem save}]
xschem save
check "script save (unmodified no-op) still logs (documented policy)" \
  [expr {[logcount {xschem save}] == $s0 + 1}]

# 2c) `xschem save fast` = internal machinery -> SILENT
xschem wire 300 350 400 350
set s0 [logcount {xschem save}]
set sf0 [logcount {xschem save fast}]
xschem save fast
check "save fast wrote (modified flag cleared)" [expr {![xschem get modified]}]
check "save fast -> NO line (machinery, setprop -fast axis)" \
  [expr {[logcount {xschem save}] == $s0 && [logcount {xschem save fast}] == $sf0}]

# 2d) File>Save menu path: menu_action_logged wrapper + branch self-log
#     dedup (actionlog_cmd_logged) -> EXACTLY one line
set s0 [logcount {xschem save}]
menu_action_logged {xschem save}
check "menu_action_logged {xschem save} -> exactly +1 (dedup)" \
  [expr {[logcount {xschem save}] == $s0 + 1}] "s0=$s0 now=[logcount {xschem save}]"

# 2e) read-only: branch rejects with TCL_ERROR BEFORE the log -> no line
xschem set readonly 1
set s0 [logcount {xschem save}]
set rc [catch {xschem save} err]
check "read-only script save rejects (TCL_ERROR) and logs nothing" \
  [expr {$rc == 1 && [logcount {xschem save}] == $s0}] "rc=$rc err=$err"

if {$have_x} {
  # 2f) Ctrl-S under read-only: save() no-ops -> the inline log is gated -> no line
  set s0 [logcount {xschem save}]
  xschem callback .drw 2 0 0 115 0 0 4
  update idletasks
  check "Ctrl-S KEY (read-only) -> no phantom line" \
    [expr {[logcount {xschem save}] == $s0}]
  xschem set readonly 0

  # 2g) Ctrl-S key (keysym 's'=115, state ControlMask=4): inline save(0,0)
  #     bypasses the branch -> its own log site
  xschem wire 300 400 400 400
  check "edit set modified (for Ctrl-S)" [expr {[xschem get modified] == 1}]
  set s0 [logcount {xschem save}]
  xschem callback .drw 2 0 0 115 0 0 4
  update idletasks
  check "Ctrl-S KEY saved (modified flag cleared)" [expr {![xschem get modified]}]
  check "Ctrl-S KEY -> +1 'xschem save'" \
    [expr {[logcount {xschem save}] == $s0 + 1}] "s0=$s0 now=[logcount {xschem save}]"
} else {
  xschem set readonly 0
  check "keyboard save (skipped: no X)" 1 "no display"
}
check "no save section fired the ask_save prompt" [expr {$::ask_count == 0}] \
  "count=$::ask_count"

# ---------------------------------------------------------------------------
# 3) RELOAD
# ---------------------------------------------------------------------------
# 3a) script `xschem reload` -> +1 bare line; discards the buffer edit
xschem wire 300 450 400 450
check "edit set modified (for reload)" [expr {[xschem get modified] == 1}]
set w [xschem get wires]
set r0 [logcount {xschem reload}]
xschem reload
check "script reload discarded the edit (wire count back, unmodified)" \
  [expr {[xschem get wires] == $w - 1 && ![xschem get modified]}]
check "script reload -> +1 'xschem reload'" \
  [expr {[logcount {xschem reload}] == $r0 + 1}] "r0=$r0 now=[logcount {xschem reload}]"

# 3b) arg form is preserved: `xschem reload zoom_full` logs the arg form, not bare
set r0 [logcount {xschem reload}]
set rz0 [logcount {xschem reload zoom_full}]
xschem reload zoom_full
check "reload zoom_full -> +1 'xschem reload zoom_full'" \
  [expr {[logcount {xschem reload zoom_full}] == $rz0 + 1}]
check "reload zoom_full -> +0 bare 'xschem reload'" \
  [expr {[logcount {xschem reload}] == $r0}]

# 3c) File>Reload proc (action_reload, menu row nolog) CONFIRMED -> exactly +1.
#     This is the double-log regression guard: action_reload used to write its
#     own `xschem log_action {xschem reload}` line, removed in this atom.
set ::alert_count 0 ; set ::alert_answer 1
set r0 [logcount {xschem reload}]
action_reload
check "action_reload confirmed -> exactly +1 'xschem reload' (no double)" \
  [expr {[logcount {xschem reload}] == $r0 + 1}] "r0=$r0 now=[logcount {xschem reload}]"
check "action_reload prompted once (counting stub)" [expr {$::alert_count == 1}] \
  "count=$::alert_count"

# 3d) File>Reload CANCELLED -> the branch is never reached -> no line
set ::alert_count 0 ; set ::alert_answer 0
set r0 [logcount {xschem reload}]
action_reload
check "action_reload cancelled -> no line" [expr {[logcount {xschem reload}] == $r0}]
check "action_reload cancel prompted once" [expr {$::alert_count == 1}] \
  "count=$::alert_count"

if {$have_x} {
  # 3e) Alt-S key (keysym 's'=115, state Mod1Mask=8): inline reload bypasses the
  #     branch (direct load_schematic) -> its own log site, inside the ok arm
  set ::msgbox_count 0 ; set ::msgbox_answer ok
  xschem wire 300 500 400 500
  set w [xschem get wires]
  set r0 [logcount {xschem reload}]
  xschem callback .drw 2 0 0 115 0 0 8
  update idletasks
  check "Alt-S KEY reloaded (edit discarded)" \
    [expr {[xschem get wires] == $w - 1 && ![xschem get modified]}]
  check "Alt-S KEY confirmed once" [expr {$::msgbox_count == 1}] "count=$::msgbox_count"
  check "Alt-S KEY -> +1 'xschem reload'" \
    [expr {[logcount {xschem reload}] == $r0 + 1}] "r0=$r0 now=[logcount {xschem reload}]"

  # 3f) Alt-S CANCELLED -> ok-arm skipped -> no reload, no line
  set ::msgbox_count 0 ; set ::msgbox_answer cancel
  xschem wire 300 550 400 550
  set w [xschem get wires]
  set r0 [logcount {xschem reload}]
  xschem callback .drw 2 0 0 115 0 0 8
  update idletasks
  check "Alt-S KEY cancelled -> no reload (edit kept)" \
    [expr {[xschem get wires] == $w && [xschem get modified] == 1}]
  check "Alt-S KEY cancelled -> no line" [expr {[logcount {xschem reload}] == $r0}]
  check "Alt-S cancel confirmed once" [expr {$::msgbox_count == 1}] "count=$::msgbox_count"
  xschem reload   ;# drop the kept edit (logs one more line, not asserted)
} else {
  check "keyboard reload (skipped: no X)" 1 "no display"
}

check "no reload/copy section fired the ask_save prompt" [expr {$::ask_count == 0}] \
  "count=$::ask_count"

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
