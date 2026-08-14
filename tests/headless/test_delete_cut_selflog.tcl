# Action-log coverage -- the Delete key and Ctrl-X self-log (issue 0071 atom 2).
#
# The two inline legacy-switch key handlers (XK_Delete, Ctrl-X) call delete()
# directly and never reach the `xschem delete` / `xschem cut` scheduler branches,
# so before this atom they recorded NOTHING. They now self-log at the handler:
#   Delete key -> `xschem delete`
#   Ctrl-X     -> `xschem cut`   (a cut fills the clipboard -- NOT a delete on replay)
# delete() itself is a shared primitive (aborts / merges / preview teardown call it
# too), so it is deliberately NOT the log site: the cut/delete VERBS live at the
# scheduler branch (already self-logs) + these keys.
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md
#
# Needs the action log open -> registered in full_audit.sh logdir_tests (--logdir):
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_delete_cut_selflog.tcl

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
# fresh single wire, selectable at its midpoint (50,0)
proc mkwire {} { xschem clear force; xschem wire 0 0 100 0; xschem unselect_all; xschem redraw }

# ---------------------------------------------------------------------------
# 1) the `xschem delete` subcommand records exactly one `xschem delete`, no cut
#    (scheduler branch self-logs; establishes the baseline the keys must match)
# ---------------------------------------------------------------------------
mkwire
xschem select_at 50 0
set d0 [logcount "xschem delete"] ; set c0 [logcount "xschem cut"]
xschem delete
check "script delete -> +1 'xschem delete'" [expr {[logcount {xschem delete}] == $d0 + 1}] \
  "d0=$d0 now=[logcount {xschem delete}]"
check "script delete -> +0 'xschem cut'"    [expr {[logcount {xschem cut}] == $c0}]

# ---------------------------------------------------------------------------
# 2) the `xschem cut` subcommand records exactly one `xschem cut` and ZERO
#    `xschem delete` -- a cut is not a delete on replay (it fills the clipboard)
# ---------------------------------------------------------------------------
mkwire
xschem select_at 50 0
set d0 [logcount "xschem delete"] ; set c0 [logcount "xschem cut"]
xschem cut
check "script cut -> +1 'xschem cut'"    [expr {[logcount {xschem cut}] == $c0 + 1}] \
  "c0=$c0 now=[logcount {xschem cut}]"
check "script cut -> +0 'xschem delete'" [expr {[logcount {xschem delete}] == $d0}] \
  "d0=$d0 now=[logcount {xschem delete}]"

# ---------------------------------------------------------------------------
# 3/4/5) the KEYBOARD paths -- the actual 0071 gap: the inline handlers call
# delete() directly, bypassing the scheduler branches, and used to log nothing.
# Needs a real X window to dispatch key events.
#   Delete key            -> `xschem delete`
#   Delete key, empty sel -> nothing (SELECTION guard -> no phantom)
#   Ctrl-X                -> `xschem cut`  (NOT delete)
# ---------------------------------------------------------------------------
if {[catch {winfo viewable .drw} vv] || !$vv} {
  check "keyboard delete/cut (skipped: no X)" 1 "no display"
} else {
  update idletasks; catch { focus -force .drw }; update idletasks
  # Delete key: keysym XK_Delete (0xFFFF = 65535), state 0
  mkwire
  xschem select_at 50 0
  set d0 [logcount "xschem delete"]
  xschem callback .drw 2 50 0 65535 0 0 0
  update idletasks
  check "Delete KEY -> +1 'xschem delete'" [expr {[logcount {xschem delete}] == $d0 + 1}] \
    "d0=$d0 now=[logcount {xschem delete}]"
  # Delete key with NOTHING selected: the SELECTION guard means no delete, no log
  mkwire
  xschem unselect_all
  set d0 [logcount "xschem delete"]
  xschem callback .drw 2 50 0 65535 0 0 0
  update idletasks
  check "Delete KEY empty selection -> no phantom 'xschem delete'" \
    [expr {[logcount {xschem delete}] == $d0}] "d0=$d0 now=[logcount {xschem delete}]"
  # Ctrl-X: keysym 'x' (0x78 = 120), state ControlMask (4)
  mkwire
  xschem select_at 50 0
  set d0 [logcount "xschem delete"] ; set c0 [logcount "xschem cut"]
  xschem callback .drw 2 50 0 120 0 0 4
  update idletasks
  check "Ctrl-X KEY -> +1 'xschem cut'" [expr {[logcount {xschem cut}] == $c0 + 1}] \
    "c0=$c0 now=[logcount {xschem cut}]"
  check "Ctrl-X KEY -> +0 'xschem delete' (it is a cut, not a delete)" \
    [expr {[logcount {xschem delete}] == $d0}] "d0=$d0 now=[logcount {xschem delete}]"
}

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
