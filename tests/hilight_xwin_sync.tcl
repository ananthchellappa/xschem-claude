#
#  File: hilight_xwin_sync.tcl
#
#  Regression for issue 0073 — a net highlighted in a PARENT window must appear in
#  a linked descend-NEW-WINDOW child (highlights were synced only ONCE, at descend
#  time). See doc/claude/issues/0073-hilight-not-synced-into-linked-descend-new-window.md
#
#  This is a GUI test: descend-into-new-window needs a real Tk toplevel, so it must
#  run headful (NOT --nogui), e.g.:
#
#      cd tests
#      DISPLAY=:0 ../src/xschem -q --script hilight_xwin_sync.tcl
#
#  Fixture (tests/hilight_xwin_sync/): parent.sch instantiates child.sym as `xi`
#  with a lab_pin FOO on xi's FOO pin; child.sch has an internal net FOO. Highlight
#  FOO in the parent AFTER the child window exists and the child (at .xi.) must show
#  `xi.FOO` — matching the single-window "highlight then descend" ground truth.
#
#  Asserts the highlight-table sync (display_hilights). Live redraw reuses the
#  already-verified guarded borrow+draw() of net_hilight_redraw_other_windows and is
#  not pixel-asserted here (headless print png renders a blank/steady frame).
#

set here [file normalize [file dirname [info script]]]
cd [file join $here hilight_xwin_sync]

# GUI --script swallows stdout, so mirror results to a log file too (override with
# env XWIN_SYNC_LOG). The process exit code is the authoritative pass/fail signal.
set logpath [expr {[info exists ::env(XWIN_SYNC_LOG)] ? $::env(XWIN_SYNC_LOG) : [file join $here hilight_xwin_sync results.log]}]
set logfh [open $logpath w]
set nfail 0
proc check {desc got want} {
  global nfail logfh
  if {$got eq $want} {
    set line "ok   - $desc"
  } else {
    set line "$desc (got '$got' want '$want'): FAIL"
    incr nfail
  }
  puts $line
  puts $logfh $line; flush $logfh
}
# membership helper: is $elem in the display_hilights list $lst ?
proc has {lst elem} { expr {[lsearch -exact $lst $elem] >= 0} }

xschem load [file join [pwd] parent.sch]
set cur [xschem get current_win_path]

# --- descend into xi in a NEW window (mimics hi_descend_newwin) ---
xschem unselect_all
xschem schematic_in_new_window force window
set nw [xschem get last_created_window]
xschem copy_hierarchy $cur $nw
xschem copy_hilights
xschem new_schematic switch $nw
xschem select instance xi fast
xschem descend 1
check "child descended to .xi."        [xschem get sch_path] {.xi.}
check "child starts with no highlight"  [xschem display_hilights] {}

# --- highlight FOO in the PARENT window (AFTER the child window exists) ---
xschem new_schematic switch $cur
xschem unselect_all
xschem hilight_netname FOO
check "parent highlights FOO"           [has [xschem display_hilights] FOO] 1

# --- the linked child must now show the internal net (issue 0073 fix) ---
xschem new_schematic switch $nw
set chn [xschem display_hilights nets]
check "child synced xi.FOO net"         [has $chn xi.FOO] 1

# --- clear-through: unhilight in the parent clears the child too ---
xschem new_schematic switch $cur
xschem unhilight_all
check "parent cleared"                  [xschem display_hilights] {}
xschem new_schematic switch $nw
check "child cleared through"           [xschem display_hilights] {}

# --- CHILD->PARENT (ascend direction, issue 0073): highlight the internal net INSIDE the
#     child window; the linked PARENT must light the net that pin connects to, WITHOUT any
#     interaction in the parent. Byte-target is the single-window "highlight-inside then
#     go_back" ground truth: parent table -> {FOO} {xi.FOO}. ---
xschem new_schematic switch $nw
xschem unselect_all
xschem hilight_netname FOO
check "child highlights internal FOO"    [has [xschem display_hilights] xi.FOO] 1
xschem new_schematic switch $cur
check "parent synced FOO net (up)"       [has [xschem display_hilights nets] FOO] 1
check "parent up-sync byte-matches go_back" [lsort [xschem display_hilights]] [lsort {FOO xi.FOO}]
# clear-through the OTHER way: unhilight in the child clears the parent's synced net too
xschem new_schematic switch $nw
xschem unhilight_all
check "child cleared (up)"               [xschem display_hilights] {}
xschem new_schematic switch $cur
check "parent cleared through (up)"      [xschem display_hilights] {}

# --- DEEP ASCEND RE-SYNC (issue 0073 child->parent via go_back): descend the secondary a
#     SECOND level in place (into xg, at .xi.xg.) and highlight the grandchild-internal net BAR.
#     Across the 2-level gap POPULATING must NOT cross (the exact cross-level net needs the
#     unloaded intermediate netlist, and a verbatim deep-entry copy would paint a bogus buried
#     cue on xi -- wrong when a deep net actually SURFACES higher up, §9c). So the primary stays
#     EMPTY here. Only when the secondary ASCENDS to .xi. (depth-1) does the go_back hook run the
#     FULL translation. Byte-target (single-window deep ascend): the .xi. table is {xi.xg.BAR} {xi.BAR}. ---
xschem new_schematic switch $nw
xschem unselect_all
xschem select instance xg fast
xschem descend 1
check "secondary descended to .xi.xg."   [xschem get sch_path] {.xi.xg.}
xschem unselect_all
xschem hilight_netname BAR
check "grandchild highlights BAR"        [has [xschem display_hilights] xi.xg.BAR] 1
xschem new_schematic switch $cur
check "primary not populated across 2-level gap (no false cue)" [xschem display_hilights] {}
# ascend the secondary one level: the go_back hook must now re-sync the primary (full translation)
xschem new_schematic switch $nw
xschem go_back
check "secondary ascended to .xi."       [xschem get sch_path] {.xi.}
xschem new_schematic switch $cur
check "primary synced on ascend (go_back hook)" [expr {[llength [xschem display_hilights]] > 0}] 1
check "primary mirrors deep-ascend table" [lsort [xschem display_hilights]] [lsort {xi.xg.BAR xi.BAR}]
# clear for the animation block
xschem new_schematic switch $nw ; xschem unhilight_all
xschem new_schematic switch $cur ; xschem unhilight_all

# --- DEEP-GAP CLEAR-THROUGH, NO FALSE CUE (issue 0073 §9c): the secondary sits TWO levels below
#     the primary (.xi.xg.), with NO window at the intermediate .xi.. Across such a gap POPULATING
#     must not cross (can't validate whether the deep net surfaces -> must NOT paint a buried cue),
#     but CLEARING must (else a highlight the user cleared everywhere lingers -> stale). Assert:
#     (a) a deep highlight does NOT populate the primary; (b) clearing the primary clears the deep
#     secondary (the orphan mop-up's clear-through). ---
xschem new_schematic switch $nw
xschem unselect_all
xschem select instance xg fast
xschem descend 1
check "secondary re-descended to .xi.xg." [xschem get sch_path] {.xi.xg.}
xschem unselect_all
xschem hilight_netname BAR
check "deep secondary highlights BAR"     [has [xschem display_hilights] xi.xg.BAR] 1
# (a) a deep highlight must NOT populate the primary across the 2-level gap (no bogus buried cue)
xschem new_schematic switch $cur
check "primary not populated by deep highlight" [xschem display_hilights] {}
# (b) clearing the primary must still clear the deep secondary (orphan clear-through, no stale)
xschem unhilight_all
check "primary cleared (deep)"            [xschem display_hilights] {}
xschem new_schematic switch $nw
check "deep secondary cleared through (no stale)" [xschem display_hilights] {}
# leave the secondary back at .xi. and both clear for the animation block
xschem go_back
xschem unhilight_all
xschem new_schematic switch $cur ; xschem unhilight_all

# --- ANIMATION (issue 0073 animated-highlight): a BLINK style applied in the parent must
#     animate in BOTH windows simultaneously, including the MAIN window while the CHILD is the
#     focused/current context. Covers: (a) the child's tick is armed on the first animating
#     apply (arming order); (b) the main window .drw is not frozen as a "background tab" when a
#     detached window is current (front-of-.drw tracker). Needs the Tk event loop (vwait). ---
if {[info exists ::env(XWIN_SYNC_NO_ANIM)]} {
  puts "(animation checks skipped: XWIN_SYNC_NO_ANIM set)"
} else {
  net_hilight_style_merge {{4 "purple" 3 {20 20} 0 1200 none 0}}
  xschem update_net_hilight_style
  xschem new_schematic switch $cur ; xschem update_net_hilight_style
  xschem new_schematic switch $nw  ; xschem update_net_hilight_style
  # apply a BLINK highlight in the PARENT, keeping the PARENT current (the user's obs 2/5:
  # the child should start blinking with NO interaction in the child window).
  xschem new_schematic switch $cur
  xschem unselect_all
  xschem hilight_netname -style 4 FOO
  check "parent reports animating"        [xschem get net_hilight_animated $cur] 1
  check "child reports animating"         [xschem get net_hilight_animated $nw] 1
  # ARMING (obs 2/5): the child's per-window tick must be ARMED by the sync's re-arm, WITHOUT
  # any switch/interaction in the child. net_hilight_after($win) holds the live after-id.
  check "child tick armed on first apply (no switch)" \
        [expr {[info exists ::net_hilight_after($nw)] ? 1 : 0}] 1
  # SUSTAINED (obs 3): now focus the CHILD; the MAIN window must keep animating (not freeze as a
  # background tab), and the child animates too. Instrument the tick and run the event loop.
  rename net_hilight_anim_tick _xwin_real_tick
  array set ::xwin_tc {}
  proc net_hilight_anim_tick {win} { incr ::xwin_tc($win); _xwin_real_tick $win }
  xschem new_schematic switch $nw
  after 1800 {set ::xwin_done 1} ; vwait ::xwin_done
  set pc [expr {[info exists ::xwin_tc($cur)] ? $::xwin_tc($cur) : 0}]
  set cc [expr {[info exists ::xwin_tc($nw)]  ? $::xwin_tc($nw)  : 0}]
  puts "tick fires: parent($cur)=$pc child($nw)=$cc"
  puts $logfh "tick fires: parent($cur)=$pc child($nw)=$cc"
  # Require SUSTAINED animation (>=3 in ~1.8s), not just the one initial armed tick: a window that
  # is armed once and then frozen (redraw returns 0 forever) fires exactly 1, which >0 would miss.
  check "child window animates (sustained)"  [expr {$cc >= 3}] 1
  check "main window animates while child focused (sustained)" [expr {$pc >= 3}] 1
  rename net_hilight_anim_tick {} ; rename _xwin_real_tick net_hilight_anim_tick

  # --- CHILD->PARENT ANIMATION (issue 0073 ascend): a BLINK highlight applied IN THE CHILD must
  #     animate in the linked PARENT too, with the CHILD kept focused (the up-sync must populate
  #     AND arm the parent's tick). Also re-exercises the front-of-.drw fix (8b): the main window
  #     $cur must animate as the front tab while the detached child $nw is current. ---
  xschem new_schematic switch $cur ; xschem unhilight_all
  xschem new_schematic switch $nw  ; xschem unhilight_all
  xschem new_schematic switch $nw
  xschem unselect_all
  xschem hilight_netname -style 4 FOO
  check "child(up) reports animating"      [xschem get net_hilight_animated $nw] 1
  check "parent(up) reports animating"     [xschem get net_hilight_animated $cur] 1
  # ARMING: the parent's per-window tick must be armed by the up-sync's re-arm, no switch to $cur.
  check "parent tick armed by up-sync (no switch)" \
        [expr {[info exists ::net_hilight_after($cur)] ? 1 : 0}] 1
  rename net_hilight_anim_tick _xwin_real_tick2
  array set ::xwin_tc2 {}
  proc net_hilight_anim_tick {win} { incr ::xwin_tc2($win); _xwin_real_tick2 $win }
  after 1800 {set ::xwin_done2 1} ; vwait ::xwin_done2
  set pc2 [expr {[info exists ::xwin_tc2($cur)] ? $::xwin_tc2($cur) : 0}]
  set cc2 [expr {[info exists ::xwin_tc2($nw)]  ? $::xwin_tc2($nw)  : 0}]
  puts "up tick fires: parent($cur)=$pc2 child($nw)=$cc2"
  puts $logfh "up tick fires: parent($cur)=$pc2 child($nw)=$cc2"
  check "parent window animates via up-sync (sustained)" [expr {$pc2 >= 3}] 1
  rename net_hilight_anim_tick {} ; rename _xwin_real_tick2 net_hilight_anim_tick
}

# --- BULK-HIGHLIGHT BATCHING (issue 0074 / code-review perf): a multi-net highlight loop must sync
#     a linked descend child ONCE at the end, not once per net. (a) the suspend/resume bracket must
#     DEFER the per-net sync (child stays untouched mid-batch) and fire it on resume; (b) the real
#     net_hilight_apply loop (which brackets internally) must still leave the child synced. The
#     secondary is back at .xi. (depth-1) after the sections above. ---
xschem new_schematic switch $cur ; xschem unhilight_all
xschem new_schematic switch $nw  ; xschem unhilight_all
check "batch: secondary at .xi."          [xschem get sch_path] {.xi.}
# (a) mechanism: two highlights under one suspend must not touch the child until resume
xschem new_schematic switch $cur
xschem net_hilight_sync_suspend
xschem hilight_netname FOO
xschem hilight_netname FOO
xschem new_schematic switch $nw
check "child NOT synced mid-batch (suspend defers)" [xschem display_hilights] {}
xschem new_schematic switch $cur
xschem net_hilight_sync_resume
xschem new_schematic switch $nw
check "child synced on resume (one batched sync)"   [has [xschem display_hilights] xi.FOO] 1
# (b) real loop path: net_hilight_apply brackets the foreach internally
xschem new_schematic switch $cur ; xschem unhilight_all
net_hilight_apply {6 orange 2 {} 0 0 none 0} FOO
xschem new_schematic switch $nw
check "child synced via net_hilight_apply loop"     [has [xschem display_hilights] xi.FOO] 1
xschem new_schematic switch $cur ; xschem unhilight_all

set summary [expr {$nfail ? "OVERALL: FAIL ($nfail)" : "OVERALL: ok"}]
puts $summary
puts $logfh $summary
close $logfh
exit [expr {$nfail ? 1 : 0}]
