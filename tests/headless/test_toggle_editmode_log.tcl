# Action-log coverage -- the two EDIT-MODE toggles record a REPLAYABLE line
# (issue 0062 tail / atom 16). `toggle_stretch` and `toggle_orthogonal_wiring` used
# to log the RELATIVE flip (`xschem toggle_stretch`), which REPLAYS WRONG: replayed
# against a different start state it lands on the OPPOSITE value. The fix logs the
# ABSOLUTE resolved state read back AFTER the flip (the set-class / 0066 cadsnap rule):
#   xschem set enable_stretch <0|1>
#   xschem set orthogonal_wiring <0|1>
# and a scheduler `set <var>` replay arm reproduces the effect without re-logging.
#
# Run:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_toggle_editmode_log.tcl

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

proc loglines {} {
  if {[catch {open [xschem get actionlog_filename] r} fd]} { return {} }
  set b [read $fd]; close $fd
  return [split [string trimright $b \n] \n]
}
proc has_line {pat} { expr {[lsearch -exact [loglines] $pat] >= 0} }
proc count_line {pat} {
  set n 0
  foreach l [loglines] { if {$l eq $pat} { incr n } }
  return $n
}

# The pure-view toggles pop `alert_` modals (toggle_show_netlist / toggle_draw_pixmap)
# that would HANG headless under X -- stub them.
proc alert_ {msg {icon {}} {nowait 0} {cancel 0}} { return 1 }
proc tk_messageBox {args} { return ok }

# fixture: any schematic so xctx exists (the set arms + toggles guard on xctx).
xschem load xschem_library/examples/nand2.sch
xschem unselect_all

# ---------------------------------------------------------------------------
# (a) ABSOLUTE resolved logging, NOT the relative flip -- from a KNOWN start state
# ---------------------------------------------------------------------------
xschem set enable_stretch 0
set n0 [llength [loglines]]
xschem toggle_stretch
check "toggle_stretch from 0 logs ABSOLUTE 'xschem set enable_stretch 1'" \
  [has_line "xschem set enable_stretch 1"]
xschem toggle_stretch
check "toggle_stretch from 1 logs ABSOLUTE 'xschem set enable_stretch 0'" \
  [has_line "xschem set enable_stretch 0"]
check "no relative 'xschem toggle_stretch' line is ever recorded" \
  [expr {![has_line "xschem toggle_stretch"]}]

xschem set orthogonal_wiring 0
xschem toggle_orthogonal_wiring
check "toggle_orthogonal_wiring from 0 logs ABSOLUTE 'xschem set orthogonal_wiring 1'" \
  [has_line "xschem set orthogonal_wiring 1"]
xschem toggle_orthogonal_wiring
check "toggle_orthogonal_wiring from 1 logs ABSOLUTE 'xschem set orthogonal_wiring 0'" \
  [has_line "xschem set orthogonal_wiring 0"]
check "no relative 'xschem toggle_orthogonal_wiring' line is ever recorded" \
  [expr {![has_line "xschem toggle_orthogonal_wiring"]}]

# ---------------------------------------------------------------------------
# (c) THE DIVERGENCE LOCK -- the whole point of the atom.
#   Record a toggle from start=0 (logs `set ...1`); set the live state to 1;
#   replay the LOGGED absolute line -> STAYS 1. A control replay of the relative
#   `xschem toggle_stretch` from state 1 -> FLIPS to 0. Absolute avoids the
#   divergence the relative form causes.
# ---------------------------------------------------------------------------
xschem set enable_stretch 0
xschem toggle_stretch                        ;# records "xschem set enable_stretch 1"
set absline [lindex [loglines] end]
check "recorded line is the ABSOLUTE set form" \
  [string equal $absline "xschem set enable_stretch 1"] "got=$absline"
xschem set enable_stretch 1                  ;# diverge: live state now 1 (record time was 0)
eval $absline                                ;# replay the ABSOLUTE line
check "ABSOLUTE replay from a DIVERGED state -> value HOLDS at 1" \
  [expr {$::enable_stretch == 1}] "got=$::enable_stretch"
# control: the RELATIVE form, replayed from state 1, FLIPS to 0 (the bug avoided)
xschem set enable_stretch 1
eval "xschem toggle_stretch"                 ;# the pre-fix relative form, replayed
check "CONTROL: relative replay from state 1 -> FLIPS to 0 (divergence the absolute form avoids)" \
  [expr {$::enable_stretch == 0}] "got=$::enable_stretch"

# same divergence lock for orthogonal_wiring
xschem set orthogonal_wiring 0
xschem toggle_orthogonal_wiring              ;# records "xschem set orthogonal_wiring 1"
set oabs [lindex [loglines] end]
xschem set orthogonal_wiring 1               ;# diverge
eval $oabs
check "ABSOLUTE orthogonal replay from diverged state HOLDS at 1" \
  [expr {$::orthogonal_wiring == 1}] "got=$::orthogonal_wiring"

# ---------------------------------------------------------------------------
# (d) the replayed `set orthogonal_wiring` reproduces the SIDE EFFECTS
#   (manhattan_lines zeroed when OFF, rubber redraw) and does NOT error headless.
#   manhattan_lines has no Tcl getter; the arm's side-effect code is locked
#   statically by the grep-guard S1 row. Here: the replay applies without error
#   and lands on the resolved var value.
# ---------------------------------------------------------------------------
check "replay 'set orthogonal_wiring 0' applies without error" \
  [expr {![catch {xschem set orthogonal_wiring 0}] && $::orthogonal_wiring == 0}]
check "replay 'set orthogonal_wiring 1' applies without error" \
  [expr {![catch {xschem set orthogonal_wiring 1}] && $::orthogonal_wiring == 1}]

# ---------------------------------------------------------------------------
# (e) the replay `set <var>` form does NOT itself re-log (bypass invariant):
#   a log there would double every replayed line.
# ---------------------------------------------------------------------------
set nb [llength [loglines]]
xschem set enable_stretch 1
xschem set enable_stretch 0
xschem set orthogonal_wiring 1
xschem set orthogonal_wiring 0
check "the 'set enable_stretch'/'set orthogonal_wiring' replay arms self-log NOTHING (bypass)" \
  [expr {[llength [loglines]] == $nb}] "delta=[expr {[llength [loglines]]-$nb}]"

# ---------------------------------------------------------------------------
# (f) the pure-VIEW toggles still log NOTHING (0066 display policy) -- unchanged.
#   NB toggle_ignore was DROPPED from this group by Refactor B atom 12: it is a real
#   MUTATOR (it edits the *_ignore attribute), not a pure-view toggle -- it was silent
#   only because its scheduler branch lacked a log_action. The atom-12 perform_action
#   migration now logs `xschem toggle_ignore` UNCONDITIONALLY (even a no-selection
#   no-op), the coverage add + the no-op-still-logs property (audit §30/§32); that
#   logging is covered by test_perform_action_toggle_ignore.tcl.
# ---------------------------------------------------------------------------
xschem unselect_all
set nv [llength [loglines]]
xschem toggle_colorscheme; xschem toggle_colorscheme
xschem toggle_draw_pixmap; xschem toggle_draw_pixmap
xschem toggle_show_netlist; xschem toggle_show_netlist
check "pure-view toggles (colorscheme/draw_pixmap/show_netlist) log NOTHING" \
  [expr {[llength [loglines]] == $nv}] "delta=[expr {[llength [loglines]]-$nv}]"

# ---------------------------------------------------------------------------
# (g) THE MENU PATH (Options menu checkbuttons) -- the review's finding. A bare
#   -variable checkbutton flips the tcl var directly, bypassing toggle_*_cmd, so it
#   logged NOTHING (and for orthogonal_wiring, whose verb has NO key, that menu is the
#   ONLY interactive control). The checkbuttons now carry a -command that routes through
#   the self-logging cmd: exactly one net flip + the ABSOLUTE line, per real menu click.
# ---------------------------------------------------------------------------
set optmenu {}
foreach w {.menubar.option .x1.menubar.option} { if {[winfo exists $w]} { set optmenu $w; break } }
if {$optmenu ne {}} {
  proc menu_idx {mb label} {
    for {set i 0} {$i <= [$mb index end]} {incr i} {
      if {![catch {$mb entrycget $i -label} l] && $l eq $label} { return $i }
    }
    return -1
  }
  foreach {label var} {"Enable stretch" enable_stretch "Enable orthogonal wiring" orthogonal_wiring} {
    set i [menu_idx $optmenu $label]
    check "menu '$label' checkbutton exists" [expr {$i >= 0}]
    if {$i < 0} continue
    global $var
    set $var 0
    set n0 [llength [loglines]]
    $optmenu invoke $i                          ;# a real menu click (Tk pre-flips, -command runs)
    set added [lrange [loglines] $n0 end]
    check "menu '$label' click -> ONE net flip to 1" [expr {[set $var] == 1}] "got=[set $var]"
    check "menu '$label' click logs EXACTLY ONE absolute line" \
      [expr {[llength $added] == 1 && [lindex $added 0] eq "xschem set $var 1"}] "added=$added"
  }
} else {
  check "menu path -- deferred (no-menu env)" 1
}

# ---------------------------------------------------------------------------
# (b) key 'y' (fire_key 121 0) and the registered-action dispatch path dedup to
#   EXACTLY ONE line (the relative csv log_cmd copy is skipped via the dispatch
#   after-eval actionlog_cmd_logged gate). Needs a viewable canvas (real dispatch).
# ---------------------------------------------------------------------------
set have_x [expr {![catch {winfo viewable .drw} vv] && $vv}]
if {$have_x} {
  proc fire_key {keysym state} { xschem callback .drw 2 200 200 $keysym 0 0 $state; update idletasks }
  xschem set enable_stretch 0
  set exp [expr {!$::enable_stretch}]         ;# value AFTER the key's flip
  set n0 [llength [loglines]]
  fire_key 121 0                              ;# key 'y' -> edit.toggle_stretch
  set added [lrange [loglines] $n0 end]
  check "key 'y' logs EXACTLY ONE line" [expr {[llength $added] == 1}] "added=$added"
  check "key 'y' logs the ABSOLUTE 'xschem set enable_stretch $exp'" \
    [expr {[lsearch -exact $added "xschem set enable_stretch $exp"] >= 0}] "added=$added"
  check "key 'y' does NOT log the relative csv copy 'xschem toggle_stretch'" \
    [expr {[lsearch -exact $added "xschem toggle_stretch"] < 0}] "added=$added"
} else {
  check "key 'y' dispatch dedup -- deferred (no-X env)" 1
}

puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
