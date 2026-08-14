# Issue 0124 -- Ctrl+Shift+H must NOT phantom-log a cancelled make_sch_from_sel dialog.
#
# The key dispatches the C-backed action sym.make_schematic_and_symbol_from_selected_
# components; the act handler returns 1 unconditionally, and before the fix dispatch's
# Layer-A fallback recorded `xschem make_sch_from_sel` even when the Save dialog was
# cancelled (empty filename) or refused (name == current schematic) -- a phantom line
# whose replay re-pops a dialog for an edit that never happened. Fix: the actions.csv
# row is nolog, so d->log_cmd stays NULL and ONLY the core self-log (save.c, real edit
# only) ever writes the line -- from every entry point.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests (--logdir):
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_key_make_sch_from_sel_log.tcl

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

# --------------------------------------------------------------------------
# Fixture: real schematic saved into the logdir; stub the disk/dialog helpers
# (make_symbol_lcc writes files, the dialogs block under X).
# --------------------------------------------------------------------------
xschem load xschem_library/examples/nand2.sch
set logdir  [file dirname [xschem get actionlog_filename]]
set scratch [file join $logdir key_msfs_gen.sch]
xschem saveas $scratch schematic
proc tk_messageBox {args} {return ok}
proc make_symbol_lcc {args} {return {}}
set ::sfd_ret {}
set ::sfd_calls 0
proc save_file_dialog {args} {incr ::sfd_calls; return $::sfd_ret}

# --------------------------------------------------------------------------
# A1) subcommand cancel: empty filename -> no-op -> NO line (scheduler-path control)
# --------------------------------------------------------------------------
set ::sfd_ret {}
xschem select_all
set n0 [logcount "xschem make_sch_from_sel"]
xschem make_sch_from_sel
check "A1 subcommand cancel logs nothing" \
  [expr {[logcount {xschem make_sch_from_sel}] == $n0}] \
  "n0=$n0 now=[logcount {xschem make_sch_from_sel}]"

# --------------------------------------------------------------------------
# A2) subcommand success: real filename -> core self-logs exactly one line
# --------------------------------------------------------------------------
set ::sfd_ret [file join $logdir key_msfs_lcc.sch]
xschem select_all
set n0 [logcount "xschem make_sch_from_sel"]
xschem make_sch_from_sel
check "A2 subcommand success logs exactly one line" \
  [expr {[logcount {xschem make_sch_from_sel}] == $n0 + 1}] \
  "n0=$n0 now=[logcount {xschem make_sch_from_sel}]"

# --------------------------------------------------------------------------
# KEY path -- the actual 0124 bug. Drive the full Tk event: keysym 72 ('H'),
# state 5 = Ctrl|Shift (handle_key_press strips ShiftMask for printable
# keysyms -> rstate 4 matches the ControlMask canvas binding).
# --------------------------------------------------------------------------
if {[catch {winfo viewable .drw} vv] || !$vv} {
  check "key path (skipped: no X)" 1 "no display"
} else {
  update idletasks; catch { focus -force .drw }; update idletasks

  # B) KEY cancelled/refused dialog logs nothing -- two drives:
  #    (i) empty filename (cancel), (ii) filename == current sch (overwrite-refuse)
  # E) and neither drive mutates the buffer (no edit ever happened)
  xschem load $scratch
  xschem select_all
  set inst_before [xschem get instances]
  set n0 [logcount "xschem make_sch_from_sel"]
  set ::sfd_ret {}
  xschem callback .drw 2 400 300 72 0 0 5 ; update idletasks
  xschem select_all
  set ::sfd_ret $scratch
  xschem callback .drw 2 400 300 72 0 0 5 ; update idletasks
  check "B KEY cancelled/refused dialog logs nothing (issue 0124 phantom)" \
    [expr {[logcount {xschem make_sch_from_sel}] == $n0}] \
    "n0=$n0 now=[logcount {xschem make_sch_from_sel}]"
  check "E KEY cancel mutates nothing" \
    [expr {[xschem get instances] == $inst_before}] \
    "before=$inst_before after=[xschem get instances]"

  # C) KEY success: core self-logs exactly one line (not +2: Layer A silent)
  set ::sfd_ret [file join $logdir key_msfs_lcc2.sch]
  xschem select_all
  set n0 [logcount "xschem make_sch_from_sel"]
  xschem callback .drw 2 400 300 72 0 0 5 ; update idletasks
  check "C KEY success logs exactly one line (core, no Layer-A double)" \
    [expr {[logcount {xschem make_sch_from_sel}] == $n0 + 1}] \
    "n0=$n0 now=[logcount {xschem make_sch_from_sel}]"

  # D) KEY on a read-only buffer: dispatch's mutates=1 readonly gate fires BEFORE
  #    the fn -> no log line (D1) AND the Save dialog never even opens (D2)
  xschem load $scratch
  xschem select_all
  xschem set readonly 1
  set ::sfd_ret {}
  set calls0 $::sfd_calls
  set n0 [logcount "xschem make_sch_from_sel"]
  xschem callback .drw 2 400 300 72 0 0 5 ; update idletasks
  check "D1 KEY readonly logs nothing" \
    [expr {[logcount {xschem make_sch_from_sel}] == $n0}] \
    "n0=$n0 now=[logcount {xschem make_sch_from_sel}]"
  check "D2 KEY readonly never opens the dialog" \
    [expr {$::sfd_calls == $calls0}] "calls0=$calls0 now=$::sfd_calls"
  xschem set readonly 0
}

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
