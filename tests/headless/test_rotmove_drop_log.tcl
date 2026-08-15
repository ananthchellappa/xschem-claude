# Action-log coverage -- a mid-move/copy ROTATE/FLIP drop records a replayable
# line (issue 0069's final sibling, issue 0071 atom 13).
#
# end_move_copy_logged (callback.c) used to write a dead marker
#   `# move selection with rotate/flip (...): no single-command replay`
# (and `# duplicate ...` for copy) when the user pressed Alt-R / Shift-R /
# Shift-V / Alt-F mid-drag, so a replayed session dropped the object at the
# WRONG orientation (the translation replayed, the rotation was lost). The drop
# now logs the scheduler's own coordinate replay form:
#   xschem move_objects <dx> <dy> <rot> <flip> [local] [-anchor ax ay] [kissing]
#   xschem copy_objects <dx> <dy> <rot> <flip> [local] [-anchor ax ay] [kissing]
# - `local` = the per-object in-place transform (Alt-R/F on a single object),
#   pivot-independent -> no anchor rider
# - `-anchor ax ay` pins the shared group-rotate pivot (Shift-R/F/V, or Alt-R/F
#   on a multi-object connected drag) because a whole-log replay's move START
#   seeds x1/y1 from the replay-time cursor, not the recorded grab point -> the
#   rotation would land about the wrong point (the atom-9 paste G-record lesson)
# - the replay arm calls move_objects/copy_objects(START/END) directly, never
#   the gesture funnel, so a replayed line never re-logs (coordinate-form-bypass)
#
# The byte-identical saveas oracle is the judge of the pivot: the recorded line,
# replayed into a fresh identical buffer, must save byte-for-byte to the drop --
# and (the -anchor cases) STILL match with the cursor parked far away, proving
# the anchor overrides START's mouse-seeded pivot (the move/copy analog of the
# paste test's T6b G-record poison).
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_rotmove_drop_log.tcl

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

set ::work /tmp/atom13_rotmove_drop_log.[pid]
file delete -force $::work; file mkdir $::work

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
proc readfile {p} { set fd [open $p r]; set b [read $fd]; close $fd; return $b }
proc findline {lines pat} { return [lindex $lines [lsearch -glob $lines $pat]] }
# instance coords: {name} {sym} x0 y0 rot flip -> {x0 y0 rot flip}
proc inst_geom {i} {
  if {[catch {xschem instance_coord $i} r]} { return {} }
  return [lrange $r 2 5]
}
# event drivers (xschem callback .drw <event> <mx> <my> <key> <button> <aux> <state>)
proc motion {x y} { xschem callback .drw 6 $x $y 0 0 0 0; update idletasks }
proc keyev {x y keysym state} { xschem callback .drw 2 $x $y $keysym 0 0 $state }
proc click1 {x y} {
  xschem callback .drw 4 $x $y 0 1 0 0
  xschem callback .drw 5 $x $y 0 1 0 256
}
# keysyms used mid-drag:
#   'm'=109 (start move)   'c'=99 (start copy)
#   Alt-R = 'r'=114 state 8  -> single-object per-object in-place rotate (local)
#   Shift-R = 'R'=82 state 0 -> GROUP rotate about the shared anchor (even 1 obj)
#   Shift-V = 'V'=86 state 0 -> group rot+rot+flip (rot=2 flip=1)
#   Alt-F = 'f'=102 state 8  -> single-object per-object in-place flip (local)

# force plain (non-cadence, non-fluid) moves so the gesture is a bare translate+
# transform; isolated instances (no attached wires) also guarantee no kissing/
# stretch reroute -> the recorded line and its replay are deterministic. Both
# golden and replay run in the SAME session, so any residual setting is applied
# to both anyway; this just narrows what has to be reasoned about.
catch {set fluid_editing 0}
catch {xschem set fluid_editing 0}
catch {set cadence_compat 0}
catch {xschem set cadence_compat 0}

# a canonical blank schematic buffer, written ONCE so golden + replay start identical
set ::BLANK [file join $::work blank.sch]
xschem clear force schematic
xschem saveas $::BLANK schematic

# fresh buffer holding the given instances (a flat list of {sym x y} triples),
# all selected. Used for BOTH the golden gesture and the replay so they start
# byte-identical.
proc fresh {insts} {
  xschem clear force
  xschem load $::BLANK
  set i 0
  foreach {sym x y} $insts {
    xschem instance $sym $x $y 0 0 [list name=R[incr i]]
  }
  xschem select_all
  rebuild_ok
}
proc rebuild_ok {} { catch {xschem rebuild_selected_array} }

# Drive one move/copy gesture with an optional mid-drag transform key, log-check
# the emitted line shape, then prove the byte-identical replay oracle (incl. the
# poisoned-cursor variant for the -anchor cases).
#
#  tag       label
#  verb      move_objects | copy_objects
#  startkey  109 (move) | 99 (copy)
#  insts     {sym x y ...} placed + selected in the fresh buffer
#  gx gy     grab-cursor screen pos (sets the shared pivot for group rotates)
#  dx dy     drop screen pos
#  keysym st mid-drag transform key + state ({} = plain translate, no transform)
#  shape     one of: local | anchor | plain
proc gesture_check {tag verb startkey insts gx gy dx dy keysym st shape} {
  fresh $insts
  set n0 [llength [loglines]]
  motion $gx $gy
  keyev  $gx $gy $startkey 0            ;# start the gesture at the grab cursor
  motion $dx $dy                        ;# drag
  if {$keysym ne {}} { keyev $dx $dy $keysym $st }
  click1 $dx $dy                        ;# drop
  set lines [newlines $n0]
  set pat "xschem $verb *"
  check "$tag drop logs exactly one $verb line" \
    [expr {[countglob $lines $pat] == 1}] "lines={$lines}"
  check "$tag no dead rotate/flip marker on the drop" \
    [expr {[countglob $lines {*rotate/flip*no single-command replay*}] == 0}]
  set line [findline $lines $pat]
  if {$line eq {}} {
    check "$tag replay (skipped: no line)" 0
    return {}
  }
  # line shape: [0]xschem [1]verb [2]dx [3]dy [4]rot [5]flip [6]local|-anchor ...
  if {$shape eq {plain}} {
    check "$tag plain line carries NO transform args (regression)" \
      [expr {[llength $line] == 4}] "line={$line}"
  } elseif {$shape eq {local}} {
    check "$tag line is `dx dy rot flip local`" \
      [expr {[llength $line] == 7 && [string is integer -strict [lindex $line 4]] \
             && [string is integer -strict [lindex $line 5]] \
             && [lindex $line 6] eq {local}}] "line={$line}"
  } else { ;# anchor
    check "$tag line is `dx dy rot flip -anchor ax ay` (shared pivot, no local)" \
      [expr {[llength $line] == 9 && [string is integer -strict [lindex $line 4]] \
             && [string is integer -strict [lindex $line 5]] \
             && [lindex $line 6] eq {-anchor}}] "line={$line}"
  }
  # golden = the drop's save
  xschem saveas [file join $::work g.sch] schematic
  set golden [readfile [file join $::work g.sch]]
  # replay into a fresh IDENTICAL buffer + selection
  fresh $insts
  set n1 [llength [loglines]]
  eval $line
  xschem saveas [file join $::work r.sch] schematic
  check "$tag replay save is byte-identical to the drop" \
    [expr {[readfile [file join $::work r.sch]] eq $golden}] \
    "golden bytes=[string length $golden] replay bytes=[string length [readfile [file join $::work r.sch]]]"
  check "$tag replay logs nothing (bypass invariant)" \
    [expr {[llength [loglines]] == $n1}] "n1=$n1 now=[llength [loglines]]"
  # the -anchor rider must make the replay independent of the replay-time cursor:
  # park it FAR away (START would seed x1/y1 here) -> must still be byte-identical.
  if {$shape eq {anchor}} {
    fresh $insts
    motion 950 730                       ;# poison the mouse-seeded pivot
    eval $line
    xschem saveas [file join $::work rp.sch] schematic
    check "$tag replay is pivot-poison independent (anchor rides the line)" \
      [expr {[readfile [file join $::work rp.sch]] eq $golden}] \
      "golden bytes=[string length $golden] poisoned bytes=[string length [readfile [file join $::work rp.sch]]]"
  }
  return $line
}

# Any uncaught error below must NOT kill the script (the RESULT banner would be
# lost). One catch wraps every section: an error = one FAIL + clean banner.
if {[catch {

# ---------------------------------------------------------------------------
# T1) MOVE + Alt-R (single object) -> per-object in-place rotate -> `local`.
#     Pivot-independent; the byte-identical replay reproduces the orientation.
# ---------------------------------------------------------------------------
set l1 [gesture_check "T1 move Alt-R" move_objects 109 {res.sym 100 100} \
          200 200 400 360 114 8 local]
if {$l1 ne {}} {
  check "T1 recorded rot=1 flip=0" \
    [expr {[lindex $l1 4] == 1 && [lindex $l1 5] == 0}] "line={$l1}"
}

# ---------------------------------------------------------------------------
# T2) MOVE + Shift-R on a SINGLE object -> mid-drag Shift-R is ALWAYS the GROUP
#     rotate about the shared anchor (x1/y1 = grab cursor), even one object ->
#     `-anchor`. This is the central pivot case; the poison-cursor replay proves
#     the anchor overrides START's mouse seed.
# ---------------------------------------------------------------------------
set l2 [gesture_check "T2 move Shift-R" move_objects 109 {res.sym 100 100} \
          200 200 400 360 82 0 anchor]
if {$l2 ne {}} {
  check "T2 recorded rot=1 flip=0" \
    [expr {[lindex $l2 4] == 1 && [lindex $l2 5] == 0}] "line={$l2}"
}

# ---------------------------------------------------------------------------
# T3) MOVE + Shift-R with TWO objects -> group rotate about the shared anchor;
#     both geometries reproduced byte-identically (incl. the poison replay).
# ---------------------------------------------------------------------------
gesture_check "T3 move Shift-R x2" move_objects 109 {res.sym 100 100 res.sym 220 140} \
  200 200 380 340 82 0 anchor

# ---------------------------------------------------------------------------
# T4) COPY + Alt-R (single) -> `local`. The drop leaves original+copy (2 inst);
#     replay on the same 1-inst selection reproduces both byte-identically.
# ---------------------------------------------------------------------------
gesture_check "T4 copy Alt-R" copy_objects 99 {res.sym 100 100} \
  200 200 400 360 114 8 local

# ---------------------------------------------------------------------------
# T5) COPY + Shift-R (group, single object) -> `-anchor`; poison replay too.
# ---------------------------------------------------------------------------
gesture_check "T5 copy Shift-R" copy_objects 99 {res.sym 100 100} \
  200 200 400 360 82 0 anchor

# ---------------------------------------------------------------------------
# T6) MOVE + Shift-V -> rot+rot+flip (final rot=2 flip=1) about the anchor.
#     Locks that BOTH transform facets ride and the composite replays.
# ---------------------------------------------------------------------------
set l6 [gesture_check "T6 move Shift-V" move_objects 109 {res.sym 100 100} \
          200 200 400 360 86 0 anchor]
if {$l6 ne {}} {
  check "T6 recorded rot=2 flip=1 (vertical flip)" \
    [expr {[lindex $l6 4] == 2 && [lindex $l6 5] == 1}] "line={$l6}"
}

# ---------------------------------------------------------------------------
# T7) MOVE + Alt-F (single) -> per-object in-place FLIP -> `local`, rot=0 flip=1.
# ---------------------------------------------------------------------------
set l7 [gesture_check "T7 move Alt-F" move_objects 109 {res.sym 100 100} \
          200 200 400 360 102 8 local]
if {$l7 ne {}} {
  check "T7 recorded rot=0 flip=1" \
    [expr {[lindex $l7 4] == 0 && [lindex $l7 5] == 1}] "line={$l7}"
}

# ---------------------------------------------------------------------------
# T8) REGRESSION: a plain translate (no transform key) still logs the bare
#     `move_objects dx dy` form and replays byte-identically -- the new parse
#     must not disturb the pre-existing plain path.
# ---------------------------------------------------------------------------
gesture_check "T8 move plain" move_objects 109 {res.sym 100 100} \
  200 200 400 360 {} 0 plain

# ---------------------------------------------------------------------------
# T9) ESC-abort mid-move-rotate logs NOTHING and leaves the object unchanged.
# ---------------------------------------------------------------------------
fresh {res.sym 100 100}
set g0 [inst_geom 0]
set n0 [llength [loglines]]
motion 200 200
keyev  200 200 109 0            ;# 'm' start move
motion 400 360                  ;# drag
keyev  400 360 82 0             ;# Shift-R mid-drag
keyev  400 360 65307 0          ;# Escape -> abort
check "T9 ESC-abort logs no move_objects line" \
  [expr {[countglob [newlines $n0] {xschem move_objects *}] == 0}] "new={[newlines $n0]}"
check "T9 ESC-abort logs no dead marker" \
  [expr {[countglob [newlines $n0] {*rotate/flip*no single-command replay*}] == 0}]
check "T9 ESC-abort left the object at its original geometry" \
  [expr {[inst_geom 0] eq $g0}] "orig={$g0} now={[inst_geom 0]}"

# ---------------------------------------------------------------------------
# T10) the `nothing` exclusion (callback.c:1614/1629): a genuine intuitive
#      press-drag-release that GRABS the object (drag_elements=1) but never
#      moves (zero delta) must log nothing. This is the mouse path the exclusion
#      guards -- driven by pressing LMB at the object's on-screen position
#      (screen = (schematic + origin) / zoom) then releasing without motion.
#      (A keyboard-'m' no-motion drop has drag_elements==0, so it is NOT
#      `nothing` and logs the pre-existing plain `move_objects 0 0` -- not this
#      arm's concern and unchanged by atom 13.)
# ---------------------------------------------------------------------------
fresh {res.sym 100 100}
set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
set sx [expr {(100 + $xo) / $zm}]
set sy [expr {(100 + $yo) / $zm}]
set n0 [llength [loglines]]
xschem callback .drw 4 $sx $sy 0 1 0 0        ;# LMB press ON the object -> grab
check "T10 press grabbed the object (STARTMOVE armed)" \
  [expr {([xschem get ui_state] & 32) != 0}] "ui_state=[xschem get ui_state]"
xschem callback .drw 5 $sx $sy 0 1 0 256      ;# release, no motion -> nothing
check "T10 no-motion press-release logs no move_objects line" \
  [expr {[countglob [newlines $n0] {xschem move_objects *}] == 0}] "new={[newlines $n0]}"
check "T10 no-motion press-release logs no dead marker" \
  [expr {[countglob [newlines $n0] {*rotate/flip*no single-command replay*}] == 0}]

# ---------------------------------------------------------------------------
# T11) whole-log sweep: the dead rotate/flip marker never appeared anywhere.
# ---------------------------------------------------------------------------
check "T11 no rotate/flip 'no single-command replay' marker anywhere" \
  [expr {[countglob [loglines] {*rotate/flip*no single-command replay*}] == 0}]

# ---------------------------------------------------------------------------
# T12) the coordinate replay forms are the replay themselves -> a scripted
#      `move_objects dx dy rot flip local` / `... -anchor ax ay` must NOT
#      self-log (locks S3; already probed per-section via "replay logs nothing"
#      but asserted here directly for both riders).
# ---------------------------------------------------------------------------
fresh {res.sym 100 100}
set n0 [llength [loglines]]
xschem move_objects 40 60 1 0 local
check "T12 scripted move_objects ... local logs nothing" \
  [expr {[countglob [newlines $n0] {xschem move_objects *}] == 0}] "new={[newlines $n0]}"
fresh {res.sym 100 100}
set n0 [llength [loglines]]
xschem move_objects 40 60 1 0 -anchor 100 100
check "T12 scripted move_objects ... -anchor logs nothing" \
  [expr {[countglob [newlines $n0] {xschem move_objects *}] == 0}] "new={[newlines $n0]}"

} ::t_err]} {
  check "uncaught error in test body" 0 $::t_err
}

file delete -force $::work
puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
