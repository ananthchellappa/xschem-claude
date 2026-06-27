# Detachable tabs & true multi-window  (specs/multi_window_detach.md)
#
# GUI smoke: opens real Tk toplevels, driven entirely by script. Needs a display.
# Standard invocation (from src/):
#   DISPLAY=:0 ./xschem --pipe -q --nolog --script ../tests/headless/test_multi_window.tcl
#
# RED-first skeleton. Checks map 1:1 to the spec's acceptance list MW1..MW8 and to
# claude_suggs/plan_multi_window_detach.md phases:
#   MW1..MW4  Phase 0  (introspection seam + force-a-window)   <-- live
#   MW5..MW8  Phase 1-3 (per-window tabs, detach, attach, lock) <-- pending stubs
# Each live check is expected to FAIL until its phase lands (that is the RED state).

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
proc pend {name} { puts "pend: $name (not yet implemented)" }

# Locate an in-repo example schematic set, relative to this script.
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
proc ex {name} { global repo; return [file join $repo xschem_library examples $name] }
set sch1 [ex nand2.sch]
set sch2 [ex dlatch.sch]
set sch3 [ex flop.sch]

# Find the `xschem windows` entry whose current_name matches *pat*, or {} .
# Each entry is a list {win_path top_path group xwindow current_name}.
proc win_entry {pat} {
  if {[catch {xschem windows} wl]} { return {} }
  foreach e $wl { if {[string match $pat [lindex $e 4]]} { return $e } }
  return {}
}

# Baseline: one schematic, the main window.
catch {xschem new_schematic destroy_all {}}
xschem load $sch1
update idletasks

# MW1 — `xschem windows` lists the open contexts; baseline is one entry, group "."
set wl {}
catch {xschem windows} wl
check "MW1 xschem windows lists base context in group ." \
  [expr {[llength $wl] == 1 && [lindex [lindex $wl 0] 2] eq "."}] "(=> {$wl})"

# MW2 — create_window forces a real toplevel even in tabbed mode
set ::tabbed_interface 1
catch {xschem new_schematic create_window .x1 $sch2}
update idletasks
check "MW2 create_window yields a real toplevel (not a tab) in tabbed mode" \
  [expr {[winfo exists .x1.drw] && [winfo toplevel .x1.drw] eq ".x1"}] \
  "(=> exists=[winfo exists .x1.drw] top=[catch {winfo toplevel .x1.drw} t; set t])"

# MW3 — that window has its own X id, distinct from the main canvas
set okMW3 0
catch {
  set okMW3 [expr {[winfo id .drw] ne [winfo id .x1.drw]}]
}
check "MW3 forced window has a distinct X window id" $okMW3 \
  "(main=[catch {winfo id .drw} a; set a] new=[catch {winfo id .x1.drw} b; set b])"

# MW4 — load_new_window -window opens in a separate toplevel; libmgr routes through it
catch {xschem load_new_window -window $sch3}
update idletasks
set e3 [win_entry *flop*]
check "MW4a load_new_window -window opens in its own window (group != .)" \
  [expr {$e3 ne {} && [lindex $e3 2] ne "."}] "(=> {$e3})"
set body {}
catch {set body [info body libmgr::open_view]}
check "MW4b libmgr New-window checkbox routes through 'load_new_window -window'" \
  [string match {*load_new_window -window*} $body] {}

# MW1b (Phase 1.1) — group attribution: with a forced window AND a tab open, the
# window reports its own group (.x1) and tabs report the main group (.). Pins the
# top_path-derived grouping that Phase 0 delivered (regression guard for the
# per-window-tab work to come).
catch {xschem new_schematic destroy_all {}}
xschem load $sch1
set ::tabbed_interface 1
catch {xschem new_schematic create_window .x1 $sch2}
catch {xschem new_schematic create {} $sch3}
update idletasks
set groups {}
foreach e [xschem windows] { lappend groups [lindex $e 2] }
check "MW1b grouping: forced window is its own group, tabs are group ." \
  [expr {[lsearch -exact $groups .x1] >= 0 && [lsearch -exact $groups .] >= 0}] \
  "(groups=$groups)"

# MW5 (detach) — tear a tab off into its own window: the context moves from group
# . to a new group .xN, gets a fresh X window, and its tab button disappears.
catch {xschem new_schematic destroy_all {}}
xschem load $sch1
set ::tabbed_interface 1
xschem new_schematic create {} $sch2   ;# a tab sharing the main canvas
update idletasks
set te [win_entry *dlatch*]
set tabwin [lindex $te 0]               ;# e.g. .x1.drw
set tabxid [lindex $te 3]               ;# its X id == main's while a tab
set tabbtn ".tabs[string map {.drw {}} $tabwin]"  ;# .x1.drw -> .tabs.x1
catch {xschem new_schematic detach $tabwin}
update idletasks
set de [win_entry *dlatch*]
check "MW5 detach moves the tab to its own group (.xN) with a new X id" \
  [expr {$de ne {} && [lindex $de 2] ne "." && [lindex $de 3] ne $tabxid \
         && ![winfo exists $tabbtn]}] \
  "(before=$te after=$de btn=$tabbtn exists=[winfo exists $tabbtn])"

# MW6 — after detach BOTH windows still render: GCs were validly recreated against
# the detached window (a stale GC bound to the old window would BadDrawable / error).
set okdraw 1
set err {}
foreach w [list .drw $tabwin] {
  if {[catch {xschem new_schematic switch $w; xschem redraw} e]} { set okdraw 0; lappend err $w:$e }
}
check "MW6 both windows draw after detach (GCs recreated, no BadDrawable)" \
  [expr {$okdraw && [winfo id .drw] ne [winfo id $tabwin]}] "($err)"

# MW5b — the tab right-click menu routes "Detach to window" through the command
set tbody {}
catch {set tbody [info body tab_ctx_cmd]}
check "MW5b tab context menu routes through 'new_schematic detach'" \
  [string match {*new_schematic detach*} $tbody] {}

# MWc — closing a REAL window while in tabbed mode must destroy its toplevel, not
# leave a zombie (context gone, toplevel still on screen). Guards the destroy
# dispatch-by-context-kind fix: a window context routes to destroy_window even
# though tabbed_interface=1.
catch {xschem new_schematic destroy_all {}}
xschem load $sch1
set ::tabbed_interface 1
xschem new_schematic create_window .x1 $sch2   ;# fresh load => not modified, no dialog
update idletasks
set had [winfo exists .x1]
xschem new_schematic destroy .x1.drw {}
update idletasks
check "MWc closing a window destroys its toplevel (no zombie)" \
  [expr {$had && ![winfo exists .x1] && ![winfo exists .x1.drw]}] \
  "(had=$had after .x1=[winfo exists .x1] .x1.drw=[winfo exists .x1.drw])"

# MWk — user canvas bindings (e.g. cadence_style_rc binds on .drw, which override
# C defaults with a trailing 'break') must propagate to new windows, else custom
# shortcuts like Control-x->descend silently fall through to the default action.
catch {xschem new_schematic destroy_all {}}
xschem load $sch1
set ::tabbed_interface 1
bind .drw <Control-Key-x> {set ::marker DESCEND; break}
xschem new_schematic create_window .x1 $sch2
update idletasks
check "MWk user .drw bindings clone onto new windows" \
  [string match {*DESCEND*break*} [bind .x1.drw <Control-Key-x>]] \
  "(=> [bind .x1.drw <Control-Key-x>])"
bind .drw <Control-Key-x> {}  ;# clean up

# MWf — a new window must focus its CANVAS (.xN.drw), not the toplevel frame, or
# key bindings (CTRL-W/CTRL-Q/f) — which live on the canvas — get no keystrokes.
catch {xschem new_schematic destroy_all {}}
xschem load $sch1
set ::tabbed_interface 1
xschem new_schematic create_window .x1 $sch2
update
check "MWf new window focuses its canvas (keys reach it)" \
  [expr {[focus] eq {.x1.drw}}] "(focus=[focus])"

# MWw — end-to-end: a key event on the new window's canvas reaches the C handler.
# CTRL-W (close) on the focused canvas must close THIS window (proves keys like
# CTRL-W/CTRL-Q/f are delivered to the canvas binding, and the close is clean).
focus -force .x1.drw
event generate .x1.drw <Control-KeyPress-w>
update
check "MWw CTRL-W on the canvas reaches the handler and closes the window" \
  [expr {![winfo exists .x1]}] "(.x1 exists=[winfo exists .x1])"

# MWs — per-window context switch: with multiple real windows in tabbed mode, a
# FocusIn on a window's canvas must make xctx follow it, or input routes to the
# wrong schematic. Drives the C callback directly (FocusIn event type = 9).
catch {xschem new_schematic destroy_all {}}
xschem load $sch1
set ::tabbed_interface 1
xschem new_schematic create_window .x1 $sch2
xschem new_schematic create_window .x2 $sch3
update
set ::mouse_follows_focus 0
xschem callback .x1.drw 9 100 100 0 0 0 0; update
set c1 [xschem get current_win_path]
xschem callback .drw 9 100 100 0 0 0 0; update
set c2 [xschem get current_win_path]
xschem callback .x2.drw 9 100 100 0 0 0 0; update
set c3 [xschem get current_win_path]
set ::mouse_follows_focus 1
check "MWs focus follows the window the event came from (no cross-window input)" \
  [expr {$c1 eq {.x1.drw} && $c2 eq {.drw} && $c3 eq {.x2.drw}}] \
  "(.x1->$c1 .drw->$c2 .x2->$c3)"

# MWn — schematic_in_new_window honors the 'window' option: plain opens a tab
# (group .), 'window' forces a real top-level (group .xN). This is what makes the
# cadence CTRL-SHIFT-N (open instance schematic read-only) land in a window.
catch {xschem new_schematic destroy_all {}}
xschem load $sch1
set ::tabbed_interface 1
xschem unselect_all
xschem schematic_in_new_window force; update      ;# lastsel==0 => current sch in new tab
set gtab [lindex [lindex [xschem windows] end] 2]
catch {xschem new_schematic destroy_all {}}
xschem load $sch1; xschem unselect_all
xschem schematic_in_new_window force window; update ;# ... in a real window
set ge [lindex [xschem windows] end]
check "MWn schematic_in_new_window 'window' opens a real window, plain opens a tab" \
  [expr {$gtab eq "." && [lindex $ge 2] ne "." && [winfo toplevel [lindex $ge 0]] eq [lindex $ge 2]}] \
  "(plain group=$gtab  window entry={$ge})"

# ---- Pending: Phase 3 (attach / re-home back, mode lock) ----
pend "MW7 attach moves a detached context back into a target group"
pend "MW8 mode lock relaxed: Tabbed-interface menu not disabled with >=2 contexts"

catch {xschem new_schematic destroy_all {}}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
