# Action-log coverage -- the Cadence Ctrl-E parent-WINDOW hop records a replayable
# line (issue 0053-class multi-window nav, issue 0071 atom 12).
#
# Ctrl-E is a raw Tk bind (cadence_style_rc:180 -> cadence::return_one_level; break),
# so it never reaches dispatch_input_action -- the sub must self-log. return_one_level
# has three branches: (1) in-place `xschem go_back` ascent (already logged by the
# go_back core, atom 3); (2) the PARENT-WINDOW hop `cadence::focus_window $parent`
# (utils/cadence_nav.tcl), which called `xschem new_schematic switch $win` and logged
# NOTHING -> a replayed session drifted to the wrong window and every later edit
# landed in the wrong context; (3) root `xschem go_back` (also logged by the core).
#
# THE FIX (atom 12): focus_window now logs `xschem new_schematic switch <win_path>`
# at the entry seam, AFTER its same-window early-out. NOT in the C core: `new_schematic
# switch` is shared by the tab-strip click machinery (xschem.tcl, `... switch $w {} 0`),
# alt2 toggle and window-open paths -- a core log would flood every tab redraw. The
# referent is the Tk win_path (the form `switch` resolves natively); in the ordered
# whole-log replay it is as stable as the monotonic window number (both encode creation
# order), and the common parent `.drw` is rock-solid.
#
# Needs the action log open AND a live Tk canvas (drives the raw Ctrl-E bind end to
# end) -> registered in full_audit.sh logdir_tests (--pipe -q --logdir, NOT --nogui):
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_cadence_window_hop_log.tcl

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}
proc result {} {
  puts ""
  puts [expr {$::fails==0 ? {RESULT: ALL PASS} : "RESULT: $::fails FAILED"}]
  flush stdout
  exit [expr {$::fails!=0}]
}

set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "SKIP: no action log open -- run with --logdir"
  puts "RESULT: SKIP (no log)"
  exit 0
}
# Display-less box: the parent hop + the raw Ctrl-E bind need a live canvas -> self-skip
# (atom-8/11 pattern) so a headless CI box never counts this as a hollow PASS.
if {[info commands winfo] eq {}} {
  puts "SKIP: no Tk (display-less session)"
  puts "RESULT: SKIP (no Tk)"
  exit 0
}

# a no-motion RMB release would open the context menu -> stub it (no RMB here, but keep
# the harness convention so a stray release cannot block on Tk).
proc context_menu {} {return 21}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
source [file join $REPO utils cadence_nav.tcl]

# Pin mouse_follows_focus 0 so the explicit `new_schematic switch` context move is not
# undone by the pointer-warp EnterNotify under WSLg (the issue-0054 desync the focus_window
# comment documents). This stabilizes the C-context assertions; the logged line -- the atom's
# deliverable -- is independent of it.
set mouse_follows_focus 0

# --- log helpers -----------------------------------------------------------
proc logtext {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  return $b
}
proc loglines {} { return [split [string trimright [logtext] \n] \n] }
proc logcount {} { return [llength [loglines]] }
# lines appended since index $n0 (0-based) that string-match $pat
proc newmatch {n0 pat} {
  set n 0
  foreach l [lrange [loglines] $n0 end] { if {[string match $pat $l]} { incr n } }
  return $n
}
# the LAST logged line that string-matches $pat (the just-recorded replay form), or {}
proc lastmatch {pat} {
  set hit {}
  foreach l [loglines] { if {[string match $pat $l]} { set hit $l } }
  return $hit
}

# --- fixtures: hierarchy A -> x1(B) -> x2(C) (mirrors test_descend_newwin_return) --
set ::work /tmp/atom12_cadence_window_hop_log.[pid]
file delete -force $::work; file mkdir $::work
proc subsym {path} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.4 file_version=1.2}"
  puts $fp "G {type=subcircuit\ntemplate=\"name=x1\"}"
  puts $fp "V {}"; puts $fp "S {}"; puts $fp "E {}"
  puts $fp "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=inout}"
  puts $fp "T {@symname} -20 -34 0 0 0.2 0.2 {}"
  close $fp
}
proc sch_with_inst {path sym instname} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.4 file_version=1.2}"
  puts $fp "G {}"; puts $fp "V {}"; puts $fp "S {}"; puts $fp "E {}"
  if {$sym ne {}} { puts $fp "C {$sym} 0 0 0 0 {name=$instname}" }
  close $fp
}
subsym $::work/b.sym
subsym $::work/c.sym
sch_with_inst $::work/a.sch b.sym x1
sch_with_inst $::work/b.sch c.sym x2
sch_with_inst $::work/c.sch {} {}
set XSCHEM_LIBRARY_PATH $::work

proc tail {} { return [file tail [xschem get schname]] }
proc reset_top {} { catch {xschem new_schematic destroy_all force}; update idletasks }

# a full-body catch so a mid-run Tk hiccup fails cleanly (RESULT line still prints)
set ::ok [catch {

# ===========================================================================
# H1: Ctrl-E parent-window hop (return_one_level branch 2) logs exactly ONE
#     `xschem new_schematic switch <parent>` line; child stays open.
# ===========================================================================
reset_top
xschem load $::work/a.sch; update idletasks
xschem unselect_all; xschem select instance 0
hi_descend target=new_window; update idletasks
set w2 [xschem get current_win_path]
check "H1 descend-newwin opened child showing B (currsch 1, linked to .drw)" \
  [expr {$w2 ne {.drw} && [tail] eq {b.sch} && [xschem get currsch]==1 &&
         [cadence::parent_window $w2] eq {.drw} && [cadence::entry_level $w2]==1}] \
  "win=$w2 sch=[tail] currsch=[xschem get currsch] parent=[cadence::parent_window $w2]"

set n0 [logcount]
cadence::return_one_level; update idletasks
check "H1 Ctrl-E hop focused the parent window .drw showing A" \
  [expr {[xschem get current_win_path] eq {.drw} && [tail] eq {a.sch} && [xschem get currsch]==0}] \
  "win=[xschem get current_win_path] sch=[tail] currsch=[xschem get currsch]"
check "H1 hop logged exactly one `new_schematic switch .drw` line" \
  [expr {[newmatch $n0 {xschem new_schematic switch .drw}]==1}] \
  "n=[newmatch $n0 {xschem new_schematic switch .drw}]"
check "H1 hop logged no OTHER `new_schematic switch` line" \
  [expr {[newmatch $n0 {xschem new_schematic switch *}]==1}] \
  "total switch lines=[newmatch $n0 {xschem new_schematic switch *}]"
check "H1 child window kept open (hop is a focus move, not a close)" \
  [cadence::win_live $w2] "win_live($w2)=[cadence::win_live $w2]"

# ===========================================================================
# H2: same-window no-op -- focus_window to the CURRENT window logs NOTHING
#     (the `$win eq $cur` early-out precedes the log).
# ===========================================================================
check "H2 precondition: current window is .drw" \
  [expr {[xschem get current_win_path] eq {.drw}}] "win=[xschem get current_win_path]"
set n0 [logcount]
cadence::focus_window .drw; update idletasks
check "H2 same-window focus_window logged nothing" \
  [expr {[logcount]==$n0}] "delta=[expr {[logcount]-$n0}]"

# ===========================================================================
# H3: the in-place branch (return_one_level branch 1, cur>entry) logs
#     `xschem go_back` via the atom-3 core, NOT a switch line.
# ===========================================================================
reset_top
xschem load $::work/a.sch; update idletasks
xschem unselect_all; xschem select instance 0
hi_descend target=new_window; update idletasks   ;# child B, entry 1
set w2c [xschem get current_win_path]
xschem unselect_all; xschem select instance 0; xschem descend; update idletasks  ;# in-place B->C
check "H3 child descended further in place to C (entry stays 1)" \
  [expr {[xschem get current_win_path] eq $w2c && [tail] eq {c.sch} &&
         [xschem get currsch]==2 && [cadence::entry_level $w2c]==1}] \
  "sch=[tail] currsch=[xschem get currsch] entry=[cadence::entry_level $w2c]"
set n0 [logcount]
cadence::return_one_level; update idletasks
check "H3 in-place Ctrl-E unwound within the child (C->B, no window hop)" \
  [expr {[xschem get current_win_path] eq $w2c && [tail] eq {b.sch} && [xschem get currsch]==1}] \
  "win=[xschem get current_win_path] sch=[tail] currsch=[xschem get currsch]"
check "H3 in-place branch logged `xschem go_back` (atom-3 core), not a switch" \
  [expr {[newmatch $n0 {xschem go_back}]>=1}] "go_back=[newmatch $n0 {xschem go_back}]"
check "H3 in-place branch logged NO `new_schematic switch` line" \
  [expr {[newmatch $n0 {xschem new_schematic switch *}]==0}] \
  "switch=[newmatch $n0 {xschem new_schematic switch *}]"

# ===========================================================================
# H4: REPLAY ORACLE -- the just-recorded switch line, re-evaluated, resolves to
#     the recorded window. Both referent directions (parent `.drw` AND a child
#     `.xN.drw`), proving the Tk-path referent is replayable in-session.
# ===========================================================================
reset_top
xschem load $::work/a.sch; update idletasks
xschem unselect_all; xschem select instance 0
hi_descend target=new_window; update idletasks
set w2r [xschem get current_win_path]                 ;# we are IN the child

# (a) child -> parent: record `switch .drw`, then replay that exact logged line
cadence::focus_window .drw; update idletasks
set line_parent [lastmatch {xschem new_schematic switch .drw}]
check "H4a recorded a `switch .drw` line to replay" [expr {$line_parent ne {}}] "line=$line_parent"
# go back into the child, then REPLAY the recorded line and check it lands in .drw
cadence::focus_window $w2r; update idletasks
check "H4a re-entered child before replay" \
  [expr {[xschem get current_win_path] eq $w2r}] "win=[xschem get current_win_path]"
set n0 [logcount]
eval $line_parent; update idletasks                   ;# the replay
check "H4a replayed `switch .drw` line landed in the parent window" \
  [expr {[xschem get current_win_path] eq {.drw}}] "win=[xschem get current_win_path]"

# (b) parent -> child: record `switch <childpath>`, replay it from .drw
cadence::focus_window $w2r; update idletasks           ;# record `switch .x1.drw`
set line_child [lastmatch "xschem new_schematic switch $w2r"]
check "H4b recorded a `switch $w2r` line to replay" [expr {$line_child ne {}}] "line=$line_child"
cadence::focus_window .drw; update idletasks
eval $line_child; update idletasks
check "H4b replayed `switch $w2r` line landed in the child window" \
  [expr {[xschem get current_win_path] eq $w2r}] "win=[xschem get current_win_path]"

# ===========================================================================
# H6 (bypass invariant): a replayed `xschem new_schematic switch` re-enters the C
#     branch, never the Tcl focus_window proc, so it logs NOTHING -- no double.
#     (Folded here: the eval calls above must not have appended switch lines.)
# ===========================================================================
set n0 [logcount]
xschem new_schematic switch .drw; update idletasks
check "H6 a scripted/replayed `switch` line does not itself log (bypass invariant)" \
  [expr {[newmatch $n0 {xschem new_schematic switch *}]==0}] \
  "switch=[newmatch $n0 {xschem new_schematic switch *}]"

# ===========================================================================
# H7 (scope): a DIRECT core `new_schematic switch` -- the tab-strip / alt2 /
#     window-open machinery form -- logs NOTHING (proves the log lives ONLY at
#     the focus_window seam, so those callers stay correctly silent).
# ===========================================================================
check "H7 precondition: child $w2r still live for the machinery switch" \
  [cadence::win_live $w2r] "win_live=[cadence::win_live $w2r]"
cadence::focus_window .drw; update idletasks
set n0 [logcount]
catch { xschem new_schematic switch $w2r {} 0 }        ;# the tab-strip no-draw form
update idletasks
check "H7 direct core `new_schematic switch ... {} 0` logged nothing (machinery)" \
  [expr {[newmatch $n0 {xschem new_schematic switch *}]==0}] \
  "switch=[newmatch $n0 {xschem new_schematic switch *}]"

# ===========================================================================
# H5: END TO END via the raw Ctrl-E Tk bind (the shipping rc profile). Install
#     the verbatim cadence_style_rc:180 binding on the child canvas (the rc clones
#     it to child windows via clone_canvas_bindings), fire a real <Control-Key-e>,
#     and assert ONE switch line + focus on the parent. Driving the real event
#     through the real binding is mandatory (a direct proc call once passed while
#     the binding was dead -- see the gesture-test-full-sequence lesson).
# ===========================================================================
reset_top
xschem load $::work/a.sch; update idletasks
xschem unselect_all; xschem select instance 0
hi_descend target=new_window; update idletasks
set w2e [xschem get current_win_path]
# verbatim from cadence_style_rc:180 (bind .drw <Control-Key-e> {...}); cloned to $w2e
bind $w2e <Control-Key-e> {cadence::return_one_level; break}
check "H5 precondition: in child $w2e before Ctrl-E" \
  [expr {[xschem get current_win_path] eq $w2e && [tail] eq {b.sch}}] \
  "win=[xschem get current_win_path] sch=[tail]"
set n0 [logcount]
event generate $w2e <Control-Key-e>; update
# The DELIVERABLE: the raw Ctrl-E bind reached focus_window and recorded exactly one
# replayable hop line. (The live post-event context is NOT asserted here -- a full
# `update` processes the pointer-warp events and WSLg focus-follows-mouse can thrash the
# live context; H1's direct-call path already proves the context move deterministically.)
check "H5 Ctrl-E (raw Tk bind) logged exactly one `new_schematic switch .drw` line" \
  [expr {[newmatch $n0 {xschem new_schematic switch .drw}]==1}] \
  "n=[newmatch $n0 {xschem new_schematic switch .drw}]"
# End-to-end proof that the recorded hop is faithful: replay the just-recorded line
# from the child and confirm it resolves to the parent (deterministic, no live thrash).
set line_e2e [lastmatch {xschem new_schematic switch .drw}]
cadence::focus_window $w2e; update idletasks
check "H5 re-entered child before replaying the recorded Ctrl-E line" \
  [expr {[xschem get current_win_path] eq $w2e}] "win=[xschem get current_win_path]"
eval $line_e2e; update idletasks
check "H5 the recorded Ctrl-E hop line replays to the parent window .drw" \
  [expr {[xschem get current_win_path] eq {.drw}}] "win=[xschem get current_win_path]"

} err]
if {$::ok} {
  check "test body ran without error" 0 "err=$err"
}
catch {reset_top}
catch {file delete -force $::work}
result
