# Action-log coverage -- the apply_hilight CLICK-to-apply arm records a
# REPLAYABLE line (issue 0065 §4 / issue 0067 §5, issue 0071 atom 15).
#
# apply_hilight (utils/apply_hilight.tcl) has TWO apply arms that share the Tcl
# proc net_hilight_apply:
#   IMMEDIATE arm -- something is already selected -> net_hilight_apply at once.
#     Reached by a CIW-typed `apply_hilight {..}` (channel-recorded) AND by the
#     cadence_style_rc raw F5 bind (bypasses dispatch_input_action -> the 0067
#     class, previously UNLOGGED).
#   CLICK arm -- nothing selected -> aphl::show_prompt + a pending style; the next
#     ButtonRelease that lands on a net fires aphl::try_apply -> net_hilight_apply.
#     The style application was UNLOGGED (the last live click-gesture hole); the
#     click's own SELECTION is already logged (`xschem select_at x y`, atom 1).
#
# Both entry sites now log the RESOLVED positional row `net_hilight_apply {row}`
# (NOT the shared proc -- that would flood the channel/startup; NOT the raw named
# style -- net_hilight_apply reads a POSITIONAL row). net_hilight_apply is the
# faithful verb by construction: it runs net_hilight_style_norm on its arg the
# SAME way at record and at replay, so a sloppy row coerces identically both times
# (the atom-8 set_live divergence lock is satisfied without a raw-preserving twin).
# Typed path stays exactly-once via ciw_exec's `-emitted` dedup; the F5 raw bind
# and the click gesture self-log.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_apply_hilight_log.tcl

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
# Display-less box: Tk never loads, so sourcing apply_hilight.tcl's bind block is
# skipped (it self-guards on winfo/.drw), but the gesture section needs real Tk
# events -- self-skip the whole test like every other GUI test (atom 8 lesson).
if {[info commands winfo] eq {}} {
  puts "SKIP: no Tk (display-less session)"
  puts "RESULT: SKIP (no Tk)"
  exit 0
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set work /tmp/atom15_apply_hilight_log_work.[pid]
file delete -force $work; file mkdir $work

# apply_hilight uses busresize::is_label_type (instance branch of sel_has_net) and
# net_hilight_apply / net_hilight_style_* (always loaded from xschem.tcl).
source [file join $REPO utils bus_resize.tcl]
source [file join $REPO utils apply_hilight.tcl]

proc logbody {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd; return $b
}
proc logcountf {f pat} {
  if {[catch {open $f r} fd]} { return -1 }
  set b [read $fd]; close $fd
  set n 0
  foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
proc logcount {pat} { return [logcountf [xschem get actionlog_filename] $pat] }
proc applycount {} { return [logcount {net_hilight_apply *}] }
proc loglines {} { return [split [logbody] \n] }
# highlighted-net count via the globals status dump (there is no `get hilight_nets`)
proc hn {} { if {[regexp {hilight_nets=(\d+)} [xschem globals] -> n]} { return $n } ; return -1 }
# does the current style table contain a row whose non-index columns match $want[1..]?
proc style_installed {want} {
  global net_hilight_style
  set tail [lrange [net_hilight_style_norm $want 0] 1 end]
  foreach row $net_hilight_style {
    if {[lrange [net_hilight_style_norm $row 0] 1 end] eq $tail} { return 1 }
  }
  return 0
}
# fresh single-wire buffer; midpoint (mx,my) is a selectable point on the wire
proc fresh_wire {{x1 100} {x2 300} {y 100}} {
  xschem clear force
  xschem wire $x1 $y $x2 $y
  xschem rebuild_connectivity
  catch { xschem unhilight_all }
}
set save_table $::net_hilight_style

# ---------------------------------------------------------------------------
# A) CIW-typed apply_hilight (immediate arm) records EXACTLY ONCE via the
#    channel `-emitted` dedup -- as the resolved net_hilight_apply line, not a
#    second apply_hilight copy (the atom-7/8 self-logging-Tcl-seam pattern).
# ---------------------------------------------------------------------------
fresh_wire
xschem unselect_all ; xschem select_all
check "A0 a wire net is selected (sel_has_net)" [expr {[aphl::sel_has_net] == 1}]
set STYA {color green thickness 2 pattern {8 4}}
set c0 [applycount]
set a0 [logcount {apply_hilight *}]
# replicate ciw_exec's dedup wrapper around a typed command
xschem log_action -reset
eval [list apply_hilight $STYA]
if {![xschem log_action -emitted]} { xschem log_action -noecho [list apply_hilight $STYA] }
check "A1 typed apply_hilight records exactly one net_hilight_apply line" \
  [expr {[applycount] == $c0 + 1}] "c0=$c0 now=[applycount]"
check "A1 typed apply_hilight does NOT also record an apply_hilight copy (dedup)" \
  [expr {[logcount {apply_hilight *}] == $a0}] "a0=$a0 now=[logcount {apply_hilight *}]"
# double-quote the pattern: the row's {8 4} makes the glob's braces unbalanced,
# which brace-quoting {..} would reject at parse time.
set apline [lindex [loglines] end-1]
check "A1 the recorded line is the RESOLVED positional row" \
  [string match "net_hilight_apply {0 green 2 {8 4}*" $apline] "line=$apline"
check "A1 the style was applied to the selection (net highlighted)" [expr {[hn] == 1}]

# ---------------------------------------------------------------------------
# B) raw-bind immediate arm (the cadence F5 path -- no channel wrapper) logs its
#    sole record: apply_hilight called directly -> +1 net_hilight_apply line.
# ---------------------------------------------------------------------------
fresh_wire
xschem unselect_all ; xschem select_all
set STYB {color blue thickness 4}
set c0 [applycount]
apply_hilight $STYB                       ;# raw F5 bind reaches exactly this
check "B1 raw-bind immediate arm logs +1 net_hilight_apply line" \
  [expr {[applycount] == $c0 + 1}] "c0=$c0 now=[applycount]"
check "B1 raw-bind apply highlighted the selected net" [expr {[hn] == 1}]
check "B1 raw-bind installed the blue/4 style" [style_installed {0 blue 4 {} 0 0 none 0}]

# ---------------------------------------------------------------------------
# C) the CLICK arm as a FULL Tk gesture (gesture-test-full-sequence lesson: a lone
#    synthetic event passed while the feature was broken -- drive the whole
#    ButtonPress/Release so the C select self-logs `select_at` AND the raw
#    +aphl::on_release bind fires). Assert select_at THEN net_hilight_apply, then
#    REPLAY the pair and assert the net carries the applied style.
# ---------------------------------------------------------------------------
set mapped [expr {[winfo exists .drw] && ![catch {winfo ismapped .drw} m] && $m}]
if {!$mapped} {
  check "C click-gesture deferred (no-X env): window not mapped" 1
} else {
  catch { set ::mouse_follows_focus 0 }   ;# pin the explicit click vs WSLg pointer-warp thrash
  fresh_wire
  xschem zoom_full ; update
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  set sx [expr {int((200 + $xo) / $zm)}]  ;# wire midpoint (200,100) -> screen
  set sy [expr {int((100 + $yo) / $zm)}]
  xschem unselect_all
  set stage0 [applycount]
  apply_hilight {color red thickness 3 pattern {20 20}}   ;# nothing selected -> stage prompt
  check "C0 nothing-selected apply_hilight staged a pending prompt, no immediate line" \
    [expr {$::aphl::pending ne {} && [applycount] == $stage0}] \
    "pending='$::aphl::pending' count $stage0->[applycount]"
  set ap0 [applycount]; set se0 [logcount {xschem select_at *}]
  set before [logbody]            ;# string-delta capture (line-index slicing hits the trailing-empty off-by-one)
  event generate .drw <ButtonPress-1> -x $sx -y $sy
  event generate .drw <ButtonRelease-1> -x $sx -y $sy
  update ; after 60 ; update      ;# flush the after-idle aphl::try_apply
  set delta [split [string range [logbody] [string length $before] end] \n]
  check "C1 gesture recorded a select_at line (the click's selection)" \
    [expr {[logcount {xschem select_at *}] == $se0 + 1}] "se0=$se0 now=[logcount {xschem select_at *}]"
  check "C1 gesture recorded exactly one net_hilight_apply line (the style)" \
    [expr {[applycount] == $ap0 + 1}] "ap0=$ap0 now=[applycount]"
  # ORDER: the select_at (flushed by try_apply's own log_action) precedes the apply
  set isel -1; set iapp -1; set sel_line {}; set app_line {}
  for {set i 0} {$i < [llength $delta]} {incr i} {
    set L [lindex $delta $i]
    if {$isel < 0 && [string match {xschem select_at *} $L]} { set isel $i; set sel_line $L }
    if {$iapp < 0 && [string match {net_hilight_apply *} $L]} { set iapp $i; set app_line $L }
  }
  check "C2 select_at is logged BEFORE net_hilight_apply" \
    [expr {$isel >= 0 && $iapp >= 0 && $isel < $iapp}] "isel=$isel iapp=$iapp delta={$delta}"
  check "C2 the click applied the style (net highlighted, pending cleared)" \
    [expr {[hn] == 1 && $::aphl::pending eq {}}]

  # REPLAY the pair into a fresh, scrambled pass: recreate the wire, unhilight and
  # unselect, then re-eval select_at + net_hilight_apply -> the net carries the style.
  fresh_wire
  xschem unselect_all
  check "C3 pre-replay: net not highlighted, nothing selected" \
    [expr {[hn] == 0 && [xschem get lastsel] == 0}]
  set r0 [applycount]
  eval $sel_line     ;# xschem select_at 200 100  -> re-selects the wire
  check "C3 replayed select_at re-selected the wire" [expr {[xschem get lastsel] >= 1}]
  eval $app_line     ;# net_hilight_apply {0 red 3 {20 20} 0 0 none 0}
  check "C3 replayed net_hilight_apply re-highlighted the net" [expr {[hn] == 1}]
  check "C3 replayed net_hilight_apply installed the applied style" \
    [style_installed {0 red 3 {20 20} 0 0 none 0}]
  check "C3 replaying the pair did NOT itself self-log (bypass invariant)" \
    [expr {[applycount] == $r0}] "r0=$r0 now=[applycount]"
}

# ---------------------------------------------------------------------------
# D) Esc-cancel and a non-net click log NOTHING (scope: no phantom line).
# ---------------------------------------------------------------------------
fresh_wire
xschem unselect_all
set ::aphl::pending [aphl::parse {color red thickness 3}]   ;# a prompt is pending
set c0 [applycount]
aphl::on_key Escape
check "D1 Esc-cancel clears the pending prompt" [expr {$::aphl::pending eq {}}]
check "D1 Esc-cancel logs nothing" [expr {[applycount] == $c0}]

# a non-net click: pending set, nothing selected -> try_apply must not fire/log
xschem unselect_all
set ::aphl::pending [aphl::parse {color red thickness 3}]
set c0 [applycount]
aphl::try_apply
check "D2 non-net click logs nothing (sel_has_net gate)" [expr {[applycount] == $c0}]
check "D2 non-net click keeps the prompt pending (still waiting)" \
  [expr {$::aphl::pending ne {}}]
set ::aphl::pending ""

# ---------------------------------------------------------------------------
# E) raw-fidelity lock (atom-8 divergence class): a sloppy row (width 2.5) is
#    logged as the resolved row and REPLAYS to the SAME live state as the
#    in-session apply, because net_hilight_apply norms it identically both times
#    (2.5 -> 1) -- no raw-preserving twin needed, faithful BY CONSTRUCTION.
# ---------------------------------------------------------------------------
fresh_wire
xschem unselect_all ; xschem select_all
set c0 [applycount]
apply_hilight {color orange thickness 2.5}      ;# sloppy width
check "E1 sloppy apply logged one net_hilight_apply line" [expr {[applycount] == $c0 + 1}]
set eline [lindex [loglines] end-1]
check "E1 the logged row carries the sloppy value VERBATIM (2.5, not pre-normalized)" \
  [string match {net_hilight_apply {0 orange 2.5*}} $eline] "line=$eline"
# in-session live state: net_hilight_apply coerced 2.5 -> width 1
set live_after_session [expr {[style_installed {0 orange 1 {} 0 0 none 0}]}]
check "E1 in-session apply coerced width 2.5 -> 1 (net_hilight_style_norm)" $live_after_session
# replay the verbatim sloppy line into a scrambled pass -> SAME coerced width-1 style
fresh_wire
set ::net_hilight_style $save_table              ;# scramble the table away from orange/1
catch { xschem update_net_hilight_style }
xschem unselect_all ; xschem select_all
eval $eline
check "E2 replaying the sloppy line reproduces the SAME live width-1 orange style" \
  [style_installed {0 orange 1 {} 0 0 none 0}] "replay diverged from session"

# ---------------------------------------------------------------------------
# F) machinery stays silent: a direct scripted net_hilight_apply (no apply_hilight
#    wrapper, no channel) does not self-log -- the proc itself is silent; only the
#    two entry sites log (a channel-typed direct call is recorded by ciw_exec, not
#    by this proc, exactly like set_live's replay form).
# ---------------------------------------------------------------------------
fresh_wire
xschem unselect_all ; xschem select_all
set c0 [applycount]
net_hilight_apply {0 purple 3 {} 0 0 none 0}     ;# direct scripting / replay form
check "F1 direct net_hilight_apply does not self-log (silent machinery / replay form)" \
  [expr {[applycount] == $c0}] "c0=$c0 now=[applycount]"

# ---------------------------------------------------------------------------
# G) --nogui child: the immediate arm records and its logged line replays with no
#    Tk loaded (atom-7/8 lesson: prove the seam headless).
# ---------------------------------------------------------------------------
set XSCHEM [file join $REPO src xschem]
set childscript $work/ng_child.tcl
set fp [open $childscript w]
puts $fp [list set REPO $REPO]
puts $fp {source [file join $REPO utils bus_resize.tcl]}
puts $fp {source [file join $REPO utils apply_hilight.tcl]}
puts $fp {xschem clear force; xschem wire 100 100 300 100; xschem rebuild_connectivity}
puts $fp {xschem unselect_all; xschem select_all}
puts $fp {set rc1 [catch {apply_hilight {color green thickness 2}} e1]}
puts $fp {set rc2 [catch {net_hilight_apply {0 green 2 {} 0 0 none 0}} e2]}
puts $fp "set fp \[open [list $work/ng_rc] w\]; puts \$fp \[list \$rc1 \$rc2 \$e1 \$e2\]; close \$fp"
puts $fp {exit 0}
close $fp
set nglogdir $work/ng_logdir; file mkdir $nglogdir
catch {exec $XSCHEM --nogui --pipe -q --logdir $nglogdir --script $childscript \
         < /dev/null > $work/ng.out 2> $work/ng.err}
set nglog [file join $nglogdir Xschem.log]
check "G1 --nogui child ran and wrote a log" [file exists $nglog]
set ngres {9 9}
catch {set fp [open $work/ng_rc r]; set ngres [string trim [read $fp]]; close $fp}
check "G2 apply_hilight + net_hilight_apply survive with no Tk" \
  [expr {[lrange $ngres 0 1] eq {0 0}}] "rc,err=$ngres"
check "G3 the immediate arm recorded its net_hilight_apply line in the --nogui log" \
  [expr {[logcountf $nglog {net_hilight_apply *}] == 1}] \
  "n=[logcountf $nglog {net_hilight_apply *}] (exactly the apply_hilight arm; the direct call is silent)"

# restore the session table
set ::net_hilight_style $save_table
catch { xschem update_net_hilight_style }
file delete -force $work
catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
