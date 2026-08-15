# Action-log coverage -- the paste/merge DROP records a replayable line
# (issue 0069 paste_at slice, issue 0071 atom 9).
#
# end_move_copy_logged (callback.c) used to write a dead marker
#   `# paste/merge drop at delta ...`
# for a STARTMERGE drop, so a replayed session silently skipped every pasted or
# merged object. The drop now logs the scheduler's coordinate replay form:
#   xschem paste <dx> <dy> [<rot> <flip> [local]] [-file {f}]
# - clipboard paste logs the bare form; replay re-reads the REPLAY-TIME
#   clipboard file (faithful-to-op accepted delta, documented at the log site)
# - a file MERGE carries its recorded source via -file {f} (stashed in
#   xctx->merge_source by merge_file)
# - a mid-gesture rotate/flip rides as `rot flip` (+ `local` for the per-object
#   in-place variant)
# - the replay arm calls merge_file + move_objects(END) directly, never the
#   gesture funnel, so a replayed line never re-logs (coordinate-form-bypass
#   invariant)
# - the ctx-menu pick 8 table line was removed (the pick only STARTS the
#   gesture; a kept line would replay a second merge on top of the drop's)
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_paste_at_log.tcl

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
# Display-less box: the gesture events need a live canvas -- self-skip (atom-8).
if {[info commands winfo] eq {}} {
  puts "SKIP: no Tk (display-less session)"
  puts "RESULT: SKIP (no Tk)"
  exit 0
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set work /tmp/atom9_paste_at_log_work.[pid]
file delete -force $work; file mkdir $work

# a no-motion RMB release opens the context menu -> stub it or the script HANGS
proc context_menu {} {return 21}

proc logtext {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  return $b
}
proc loglines {} { return [split [string trimright [logtext] \n] \n] }
proc newlines {n0} { return [lrange [loglines] $n0 end] }
proc countglob {lines pat} {
  set n 0
  foreach l $lines { if {[string match $pat $l]} { incr n } }
  return $n
}
# event drivers (xschem callback .drw <event> <mx> <my> <key> <button> <aux> <state>)
proc motion {x y} { xschem callback .drw 6 $x $y 0 0 0 0; update idletasks }
proc click1 {x y} {
  xschem callback .drw 4 $x $y 0 1 0 0
  xschem callback .drw 5 $x $y 0 1 0 256
}
# instance coords: {name} {sym} x0 y0 rot flip. Empty on a missing instance
# (e.g. a paste that committed nothing) so callers fail their checks instead
# of throwing "instance not found" out of the script.
proc inst_geom {i} {
  if {[catch {xschem instance_coord $i} r]} { return {} }
  return [lrange $r 2 5]
}

# Any uncaught error below must NOT kill the script: the RESULT banner would
# be lost (full_audit sees a hang/garbage, not a FAIL) and, before the xinit.c
# automation gate, an erroring --script raised a MODAL Tk dialog on the
# desktop. One catch wraps every section: an error = one FAIL + clean banner
# + workdir cleanup.
if {[catch {

# ---------------------------------------------------------------------------
# T1) clipboard paste drop -> exactly one replayable line, delta == displacement
# ---------------------------------------------------------------------------
xschem clear force schematic
xschem instance res.sym 100 100 0 0 {name=R1}
xschem select instance R1
xschem copy
xschem unselect_all

set n0 [llength [loglines]]
xschem paste            ;# interactive form: starts the pending merge
motion 300 200
motion 400 300
click1 400 300          ;# drop
set lines [newlines $n0]
check "T1 drop logs exactly one paste line" \
  [expr {[countglob $lines {xschem paste *}] == 1}] "lines={$lines}"
check "T1 old '# paste/merge drop' marker is gone" \
  [expr {[countglob $lines {# paste/merge drop*}] == 0}]
check "T1 paste committed (2 instances)" [expr {[xschem get instances] == 2}]
set pline [lindex $lines [lsearch -glob $lines {xschem paste *}]]
if {$pline ne {}} {
  lassign $pline - - dx dy
  check "T1 bare clipboard form (no rot/flip, no -file)" \
    [expr {[llength $pline] == 4}] "line={$pline}"
  # clipboard holds R1 at (100,100): pasted copy must sit at (100+dx, 100+dy)
  lassign [inst_geom 1] px py prot pflip
  check "T1 delta == object displacement" \
    [expr {$px == 100 + $dx && $py == 100 + $dy}] "logged=($dx,$dy) pasted=($px,$py)"
} else {
  check "T1 bare clipboard form (no rot/flip, no -file)" 0 "no paste line recorded"
  check "T1 delta == object displacement" 0 "no paste line recorded"
}

# ---------------------------------------------------------------------------
# T2) REPLAY the logged line in a fresh buffer: same object, same coords,
#     and the replay logs NOTHING (coordinate-form-bypass invariant)
# ---------------------------------------------------------------------------
if {$pline ne {}} {
  xschem clear force schematic
  set n0 [llength [loglines]]
  eval $pline
  check "T2 replay pastes the clipboard (1 instance)" [expr {[xschem get instances] == 1}]
  lassign [inst_geom 0] rx ry rrot rflip
  check "T2 replay lands at the recorded coords" \
    [expr {$rx == $px && $ry == $py && $rrot == $prot && $rflip == $pflip}] \
    "recorded=($px,$py,$prot,$pflip) replay=($rx,$ry,$rrot,$rflip)"
  check "T2 replay logs nothing (bypass invariant)" \
    [expr {[llength [loglines]] == $n0}] "n0=$n0 now=[llength [loglines]]"
} else {
  check "T2 replay (skipped: no recorded line)" 0
}

# ---------------------------------------------------------------------------
# T3) ESC-abort mid-paste logs nothing and leaves no objects
# ---------------------------------------------------------------------------
xschem clear force schematic
set n0 [llength [loglines]]
xschem paste
motion 300 200
xschem callback .drw 2 300 200 65307 0 0 0   ;# Escape
check "T3 ESC-abort leaves no objects" [expr {[xschem get instances] == 0}]
check "T3 ESC-abort logs nothing" \
  [expr {[countglob [newlines $n0] {xschem paste *}] == 0}] "new={[newlines $n0]}"

# re-prime the clipboard right before each paste section (narrows the window
# in which a CONCURRENT xschem session's copy could swap the shared
# ~/.xschem/.clipboard.sch under us -- atom-9 review)
proc prime_clipboard_r1 {} {
  xschem clear force schematic
  xschem instance res.sym 100 100 0 0 {name=R1}
  xschem select instance R1
  xschem copy
  xschem unselect_all
  xschem clear force schematic
}

# ---------------------------------------------------------------------------
# T4) no-motion drop still pastes -> still logs, delta == displacement
# ---------------------------------------------------------------------------
prime_clipboard_r1
set n0 [llength [loglines]]
xschem paste
click1 250 150          ;# drop without any motion event
set lines [newlines $n0]
check "T4 no-motion drop logs exactly one paste line" \
  [expr {[countglob $lines {xschem paste *}] == 1}] "lines={$lines}"
check "T4 no-motion drop pasted (1 instance)" [expr {[xschem get instances] == 1}]
set pline4 [lindex $lines [lsearch -glob $lines {xschem paste *}]]
if {$pline4 ne {}} {
  lassign $pline4 - - dx4 dy4
  lassign [inst_geom 0] px4 py4 - -
  check "T4 delta == displacement" \
    [expr {$px4 == 100 + $dx4 && $py4 == 100 + $dy4}] "logged=($dx4,$dy4) pasted=($px4,$py4)"
} else {
  check "T4 delta == displacement" 0 "no paste line recorded"
}

# ---------------------------------------------------------------------------
# T5) Alt-R mid-paste (single object -> per-object in-place rotate): the line
#     carries `rot flip local` and the replay reproduces the orientation.
#     (Shift-R mid-gesture is the GROUP rotate about the shared anchor -- T6.)
# ---------------------------------------------------------------------------
prime_clipboard_r1
set n0 [llength [loglines]]
xschem paste
motion 400 300
xschem callback .drw 2 400 300 114 0 0 8     ;# Alt-R: in-place rotate during the move
click1 400 300
set lines [newlines $n0]
set pline5 [lindex $lines [lsearch -glob $lines {xschem paste *}]]
check "T5 rotated drop logs one paste line" [expr {$pline5 ne {}}] "lines={$lines}"
if {$pline5 ne {}} {
  check "T5 line carries rot flip local" \
    [expr {[llength $pline5] == 7 && [lindex $pline5 4] == 1 && [lindex $pline5 5] == 0 \
           && [lindex $pline5 6] eq {local}}] "line={$pline5}"
  set geom5 [inst_geom 0]
  check "T5 pasted instance is rotated" [expr {[lindex $geom5 2] == 1}] "geom={$geom5}"
  xschem clear force schematic
  set n0 [llength [loglines]]
  eval $pline5
  check "T5 replay reproduces coords+orientation" \
    [expr {[inst_geom 0] eq $geom5}] "recorded={$geom5} replay={[inst_geom 0]}"
  check "T5 rotated replay logs nothing" \
    [expr {[llength [loglines]] == $n0}] "n0=$n0 now=[llength [loglines]]"
} else {
  check "T5 replay (skipped: no recorded line)" 0
}

# ---------------------------------------------------------------------------
# T6) rotate mid-paste with TWO objects -> group rotate (no 'local'), replay
#     reproduces both geometries exactly
# ---------------------------------------------------------------------------
xschem clear force schematic
xschem instance res.sym 100 100 0 0 {name=R1}
xschem instance res.sym 200 160 0 0 {name=R2}
xschem select instance R1
xschem select instance R2 add
xschem copy
xschem unselect_all
xschem clear force schematic
set n0 [llength [loglines]]
xschem paste
motion 500 400
xschem callback .drw 2 500 400 82 0 0 0      ;# 'R': >1 object -> group rotate
click1 500 400
set lines [newlines $n0]
set pline6 [lindex $lines [lsearch -glob $lines {xschem paste *}]]
check "T6 group-rotated drop logs one paste line" [expr {$pline6 ne {}}] "lines={$lines}"
if {$pline6 ne {}} {
  check "T6 line carries rot flip -anchor ax ay, NO local (group pivot)" \
    [expr {[llength $pline6] == 9 && [lindex $pline6 4] == 1 && [lindex $pline6 5] == 0 \
           && [lindex $pline6 6] eq {-anchor}}] "line={$pline6}"
  check "T6 two instances pasted" [expr {[xschem get instances] == 2}]
  set geom6 [list [inst_geom 0] [inst_geom 1]]
  xschem clear force schematic
  set n0 [llength [loglines]]
  eval $pline6
  check "T6 replay reproduces the group geometry" \
    [expr {[list [inst_geom 0] [inst_geom 1]] eq $geom6}] \
    "recorded={$geom6} replay={[list [inst_geom 0] [inst_geom 1]]}"
  check "T6 group replay logs nothing" [expr {[llength [loglines]] == $n0}]

  # T6b) the -anchor rider makes the replay independent of the clipboard's G
  # record: a whole-log replay regenerates the clipboard via the replayed
  # `xschem copy` with a DIFFERENT pointer position (atom-9 review, confirmed
  # major). Poison the G record and replay -> geometry must still match.
  set clipf [expr {[info exists ::USER_CONF_DIR]
                   ? [file join $::USER_CONF_DIR .clipboard.sch]
                   : [file join $::env(HOME) .xschem .clipboard.sch]}]
  if {[file exists $clipf]} {
    set fd [open $clipf r]; set clip [read $fd]; close $fd
    regsub {G \{[^\}]*\}} $clip "G { 987 -654 }" clip2
    set fd [open $clipf w]; puts -nonewline $fd $clip2; close $fd
    xschem clear force schematic
    eval $pline6
    check "T6b replay is G-record independent (anchor rides the line)" \
      [expr {[list [inst_geom 0] [inst_geom 1]] eq $geom6}] \
      "recorded={$geom6} replay={[list [inst_geom 0] [inst_geom 1]]}"
  } else {
    check "T6b replay is G-record independent (anchor rides the line)" 0 "no clipboard file at $clipf"
  }
} else {
  check "T6 replay (skipped: no recorded line)" 0
}

# ---------------------------------------------------------------------------
# T7) file MERGE drop -> `-file {f}` rides the line; replay re-reads the file
# ---------------------------------------------------------------------------
set mfile [file join $work merge_src.sch]
set fd [open $mfile w]
puts $fd "C {res.sym} 50 50 0 0 {name=RM1}"
close $fd
xschem clear force schematic
set n0 [llength [loglines]]
xschem merge $mfile
motion 350 250
motion 420 260
click1 420 260
set lines [newlines $n0]
set pline7 [lindex $lines [lsearch -glob $lines {xschem paste *}]]
check "T7 merge drop logs one paste line" \
  [expr {[countglob $lines {xschem paste *}] == 1}] "lines={$lines}"
if {$pline7 ne {}} {
  check "T7 line carries -file with the merge source" \
    [expr {[llength $pline7] == 6 && [lindex $pline7 4] eq {-file} \
           && [lindex $pline7 5] eq $mfile}] "line={$pline7}"
  check "T7 merge committed (1 instance)" [expr {[xschem get instances] == 1}]
  lassign $pline7 - - dx7 dy7
  lassign [inst_geom 0] px7 py7 - -
  check "T7 delta == displacement from the file coords" \
    [expr {$px7 == 50 + $dx7 && $py7 == 50 + $dy7}] "logged=($dx7,$dy7) pasted=($px7,$py7)"
  set geom7 [inst_geom 0]
  xschem clear force schematic
  set n0 [llength [loglines]]
  eval $pline7
  check "T7 replay re-merges the file at the same coords" \
    [expr {[xschem get instances] == 1 && [inst_geom 0] eq $geom7}] \
    "recorded={$geom7} replay={[inst_geom 0]}"
  check "T7 merge replay logs nothing" [expr {[llength [loglines]] == $n0}]
} else {
  check "T7 replay (skipped: no recorded line)" 0
}

# ---------------------------------------------------------------------------
# T8) ctx-menu paste (pick 8): the pick line is GONE, only the drop line lands
# ---------------------------------------------------------------------------
xschem clear force schematic
xschem instance res.sym 100 100 0 0 {name=R1}
xschem select instance R1
xschem copy
xschem unselect_all
proc context_menu {} {return 8}              ;# next RMB opens 'paste' pick
set n0 [llength [loglines]]
xschem callback .drw 4 300 200 0 3 0 0       ;# RMB press
xschem callback .drw 5 300 200 0 3 0 1024    ;# RMB release -> context menu -> pick 8
proc context_menu {} {return 21}             ;# restore the hang guard
motion 380 260
click1 380 260
set lines [newlines $n0]
check "T8 ctx-menu paste records exactly ONE line (the drop)" \
  [expr {[countglob $lines {xschem paste *}] == 1}] "lines={$lines}"
check "T8 no bare pick line 'xschem paste'" \
  [expr {[countglob $lines {xschem paste}] == 0}] "lines={$lines}"
check "T8 ctx paste committed (2 instances)" [expr {[xschem get instances] == 2}]
# a clipboard drop must be the bare 4-element form -- locks the
# merge_source-vs-clip_file source test (a stale/poisoned source would leak a
# -file rider onto a clipboard line; atom-9 review)
set pline8 [lindex $lines [lsearch -glob $lines {xschem paste *}]]
check "T8 clipboard drop line is the bare 4-element form" \
  [expr {$pline8 ne {} && [llength $pline8] == 4}] "line={$pline8}"

# ---------------------------------------------------------------------------
# T10) pending-merge COMPLETION: a coordinate paste line with a merge already
#      pending completes IT (no second merge stacked) and logs nothing --
#      this is how a channel-recorded interactive `xschem paste` + the drop
#      line replay to exactly one paste
# ---------------------------------------------------------------------------
prime_clipboard_r1
set n0 [llength [loglines]]
xschem paste                    ;# pending STARTMERGE (interactive form)
xschem paste 40 20              ;# coordinate form: must COMPLETE the pending merge
check "T10 completion pastes exactly once" [expr {[xschem get instances] == 1}]
lassign [inst_geom 0] cx cy - -
check "T10 completion applies the delta" \
  [expr {$cx == 140 && $cy == 120}] "pasted=($cx,$cy) want=(140,120)"
check "T10 completion logs nothing (both forms are replay/machinery)" \
  [expr {[llength [loglines]] == $n0}] "n0=$n0 now=[llength [loglines]]"

# ---------------------------------------------------------------------------
# T11) empty merge must NOT leave STARTMERGE dangling: a later real move drop
#      would be mislogged as a paste and the move line suppressed (atom-9
#      review, confirmed major)
# ---------------------------------------------------------------------------
set emptyf [file join $work empty.sch]
close [open $emptyf w]
xschem clear force schematic
xschem instance res.sym 100 100 0 0 {name=R1}
xschem merge $emptyf
check "T11 empty merge leaves no dangling STARTMERGE" \
  [expr {([xschem get ui_state] & 256) == 0}] "ui_state=[xschem get ui_state]"
set n0 [llength [loglines]]
xschem select instance R1
xschem callback .drw 6 100 100 0 0 0 0
xschem callback .drw 2 100 100 109 0 0 0   ;# 'm': start move at the mouse
xschem callback .drw 6 140 140 0 0 0 0
click1 140 140
set lines [newlines $n0]
check "T11 real move after empty merge logs move_objects, not paste" \
  [expr {[countglob $lines {xschem move_objects *}] == 1 \
         && [countglob $lines {xschem paste *}] == 0}] "lines={$lines}"

# ---------------------------------------------------------------------------
# T9) whole-log sweep: the dead marker never appeared
# ---------------------------------------------------------------------------
check "T9 no '# paste/merge drop' marker anywhere in the log" \
  [expr {[countglob [loglines] {# paste/merge drop*}] == 0}]

} ::t_err]} {
  check "uncaught error in test body" 0 $::t_err
}

file delete -force $work
puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
