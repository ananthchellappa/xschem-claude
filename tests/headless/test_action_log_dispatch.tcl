# Action-log Phase 1, Layer A first slice: Tcl-backed actions dispatched through
# the binding table (dispatch_input_action, callback.c) are recorded in the
# action log -- the canonical d->tcl command verbatim on success, a
# '# failed: <cmd>' comment on error (recorded AFTER evaluation, same rule as
# CIW-typed commands, so the file stays source-able). C-backed actions are NOT
# logged yet (that is the next slice -- needs the canonical command surfaced
# from actions.csv).
# Run under X with --pipe; pass --logdir so the log lands in a temp dir:
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_action_log_dispatch.tcl
update idletasks
focus -force .drw
update idletasks

proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"
  if {!$ok} {incr ::fails}
}
set ::fails 0

proc key {ks {st 0}} { xschem callback .drw 2 400 300 $ks 0 0 $st; update idletasks }
proc loglines {} {
  set fd [open [xschem get actionlog_filename] r]
  set body [read $fd]
  close $fd
  return [split [string trimright $body \n] \n]
}

check "action log open" [expr {[xschem get actionlog_filename] ne {}}]

# 1) success path: K (keysym 75) -> hilight.un_highlight_all_net_pins, Tcl-backed
#    "xschem unhilight_all". The exact command must appear in the file, raw.
set n0 [llength [loglines]]
key 75
set lines [loglines]
check "Tcl-backed key logged verbatim" \
  [expr {[lsearch -exact $lines {xschem unhilight_all}] >= $n0}]

# 2) idle gate still respected upstream: at semaphore>=2 the chord is skipped
#    entirely, so nothing new may be logged either.
xschem set semaphore 2
set n0 [llength [loglines]]
key 75
check "idle_only chord skipped while busy -> not logged" \
  [expr {[llength [loglines]] == $n0}]
xschem set semaphore 0

# 3) failure path: make `=` (keysym 61 -> tools.execute_tcl_command, Tcl-backed
#    "tclcmd") fail by renaming the proc away; the log must get a comment, not
#    the raw command (replaying a failing line would abort `source`).
rename tclcmd __saved_tclcmd
set n0 [llength [loglines]]
key 61
set lines [loglines]
check "failed action logged as comment" \
  [expr {[lsearch -exact $lines {# failed: tclcmd}] >= $n0}]
check "failed action not logged raw" \
  [expr {[lsearch -exact $lines {tclcmd}] < 0}]
rename __saved_tclcmd tclcmd

# 4) C-backed actions (Layer A slice 2): the canonical actions.csv command is
#    logged after the fn handles the event. Wheel-up on the canvas dispatches
#    view.zoom_in (C fn); the file must gain exactly `xschem zoom_in`.
set n0 [llength [loglines]]
xschem callback .drw 4 400 300 0 4 0 0
update idletasks
check "C-backed action logs canonical csv command" \
  [expr {[lsearch -exact [loglines] {xschem zoom_in}] >= $n0}]

# 4b) record -> replay equivalence: zoom_in is relative, so undo it once with a
#     direct (undispatched, unlogged) zoom_out, then `source` the log -- the
#     replayed zoom_in must land the zoom exactly back where the wheel left it.
set z1 [xschem get zoom]
xschem zoom_out
check "direct zoom_out disturbed the view" [expr {[xschem get zoom] ne $z1}]
check "direct scheduler call is not logged" \
  [expr {[lsearch -exact [loglines] {xschem zoom_out}] < 0}]
uplevel #0 [list source [xschem get actionlog_filename]]
check "replaying the log restores the zoom" [expr {[xschem get zoom] eq $z1}]

# 4c) Phase 3 minted the view subcommands: Up arrow dispatches view.scroll_up,
#     whose csv command is now `xschem scroll up` -> the line IS logged
#     (test_phase3_mints.tcl covers the whole batch; this guards the dispatch
#     seam). Truly command-less ids (e.g. graph routing) remain silent.
set n0 [llength [loglines]]
key 65362
check "minted C-backed action logs its csv command" \
  [expr {[lsearch -exact [loglines] {xschem scroll up}] >= $n0}]

# 4d) the push subcommand: menu-only ids are ignored (returns 0), registry ids
#     accept (returns 1; probing with a Tcl-backed id is side-effect-free --
#     the Tcl dispatch branch never reads log_cmd).
check "set_action_log_cmd unknown id -> 0" \
  [expr {[xschem set_action_log_cmd nonsense.id whatever] == 0}]
check "set_action_log_cmd registry id -> 1" \
  [expr {[xschem set_action_log_cmd file.clear_schematic {xschem clear schematic}] == 1}]

# 5) the whole file stays source-able (header comment, raw commands, # comments)
check "file is source-able" \
  [expr {![catch {uplevel #0 [list source [xschem get actionlog_filename]]} err]}]

# clean RAIL teardown (issue 0002 hardening): destroy the auto-opened CIW and
# let the event loop deliver it while the client is still alive, THEN exit
destroy .ciw
update

puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
