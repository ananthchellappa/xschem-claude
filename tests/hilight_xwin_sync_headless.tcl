#
#  File: hilight_xwin_sync_headless.tcl
#
#  HEADLESS (--nogui) Tier-C test: run the REAL cross-window highlight sync engine
#  AND the deep-gap relay over two logical contexts, with NO display. The full GUI
#  end-to-end test is hilight_xwin_sync.tcl (real Tk windows, animation); this one
#  exercises the same engine's TABLE reconciliation in the fast --nogui suite by
#  forcing the normally has_x-gated sync to run (xschem net_hilight_sync_force_headless 1)
#  -- every draw() inside the sync self-skips because a headless context has no
#  save_pixmap. See doc/claude/code_analysis/net_highlight_linked_windows_agent_guide.md §8.
#
#      cd tests
#      ../src/xschem --nogui --pipe -q --script hilight_xwin_sync_headless.tcl
#
#  NOTE: creating a second window under --nogui emits a few harmless Tcl warnings
#  (clone_canvas_bindings/winfo, toolbar_visible) which are swallowed; the context
#  is fully usable. The process exit code is the authoritative pass/fail.
#
#  Fixture (tests/hilight_xwin_sync/): CTRL surfaces 2 levels, BAR is buried 2
#  levels, FOO surfaces 1 level.
#

set here [file normalize [file dirname [info script]]]
cd [file join $here hilight_xwin_sync]

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } else {
    puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail
  }
}
proc has {lst elem} { expr {[lsearch -exact $lst $elem] >= 0} }

xschem load [file join [pwd] parent.sch]
set cur [xschem get current_win_path]

# --- build the linked SECONDARY window headless and descend it TWO levels ---
xschem unselect_all
catch { xschem schematic_in_new_window force window }
set nw [xschem get last_created_window]
catch { xschem copy_hierarchy $cur $nw }
xschem new_schematic switch $nw
xschem select instance xi fast ; xschem descend 1
xschem unselect_all ; xschem select instance xg fast ; xschem descend 1
check "secondary at .xi.xg. (2-level gap)" [xschem get sch_path] {.xi.xg.}

# turn on the headless-sync bypass for the rest of the test
xschem net_hilight_sync_force_headless 1

# ===========================================================================
# SURFACING deep net (the user's scenario): CTRL at .xi.xg. surfaces to top CTRL
# in the PRIMARY, with NO false buried cue on xi.
# ===========================================================================
xschem unselect_all
xschem hilight_netname CTRL
check "secondary highlights CTRL"           [has [xschem display_hilights] xi.xg.CTRL] 1
xschem new_schematic switch $cur
check "PRIMARY lit real surfacing net CTRL"  [has [xschem display_hilights] CTRL] 1
check "PRIMARY no false buried cue on xi"    [xschem hilight_buried xi] -1
# clear-through: unhilight in primary clears the deep secondary
xschem unhilight_all
check "primary cleared (surfacing)"          [xschem display_hilights] {}
xschem new_schematic switch $nw
check "deep secondary cleared through"       [xschem display_hilights] {}

# ===========================================================================
# BURIED deep net: BAR at .xi.xg. does not reach an xi pin -> PRIMARY shows a
# VALIDATED buried cue on xi (not a false net).
# ===========================================================================
xschem unhilight_all
xschem hilight_netname BAR
check "secondary highlights BAR"             [has [xschem display_hilights] xi.xg.BAR] 1
xschem new_schematic switch $cur
check "PRIMARY buried cue on xi (validated)" [expr {[xschem hilight_buried xi] >= 0}] 1
check "PRIMARY did NOT surface a BAR net"    [has [xschem display_hilights] BAR] 0
# clear-through the other way: unhilight in the secondary clears the primary
xschem new_schematic switch $nw
xschem unhilight_all
xschem new_schematic switch $cur
check "primary cleared from secondary (buried)" [xschem display_hilights] {}

# ===========================================================================
# SABOTAGE (green-but-hollow guard): relay OFF -> surfacing net must NOT populate
# the primary (falls back to clear-through-only), pinning the relay as the cause.
# ===========================================================================
xschem net_hilight_relay_enable 0
xschem new_schematic switch $nw
xschem unselect_all
xschem hilight_netname CTRL
xschem new_schematic switch $cur
check "SABOTAGE relay off: primary NOT lit"  [has [xschem display_hilights] CTRL] 0
xschem net_hilight_relay_enable 1
xschem new_schematic switch $nw ; xschem unhilight_all
xschem new_schematic switch $cur ; xschem unhilight_all

# ===========================================================================
# ADJACENT (+/-1) case runs headless too: bring the secondary up to .xi. (one
# level below the primary) and confirm the precise per-level translation.
# ===========================================================================
xschem new_schematic switch $nw
xschem go_back
check "secondary back at .xi. (1-level)"     [xschem get sch_path] {.xi.}
xschem unselect_all
xschem hilight_netname FOO
check "secondary(.xi.) highlights FOO"       [has [xschem display_hilights] xi.FOO] 1
xschem new_schematic switch $cur
check "PRIMARY +/-1 up-sync surfaced FOO"    [has [xschem display_hilights] FOO] 1
check "PRIMARY +/-1 byte-matches go_back"    [lsort [xschem display_hilights]] [lsort {FOO xi.FOO}]

xschem net_hilight_sync_force_headless 0
set summary [expr {$nfail ? "OVERALL: FAIL ($nfail)" : "OVERALL: ok"}]
puts $summary
exit [expr {$nfail ? 1 : 0}]
