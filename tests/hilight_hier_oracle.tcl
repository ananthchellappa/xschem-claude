#
#  File: hilight_hier_oracle.tcl
#
#  HEADLESS (--nogui) regression for the SINGLE-WINDOW hierarchical highlight
#  translation -- the ORACLE that the multi-window cross-window sync and the
#  deep-gap relay (issue 0073) must byte-match. Because the +/-1 sync and the
#  relay reuse the exact same pin/bus translation as hilight_child_pins /
#  hilight_parent_pins, whatever a SINGLE window produces by descend/ascend is
#  the ground truth for what the linked windows must show. This runs the
#  translation math with NO second window and NO display, so it can join the
#  fast --nogui suite (Tier A of doc/claude/code_analysis/
#  net_highlight_linked_windows_agent_guide.md §8).
#
#      cd tests
#      ../src/xschem --nogui --pipe -q --script hilight_hier_oracle.tcl
#
#  Reuses the tests/hilight_xwin_sync/ fixture:
#    parent.sch      : xi (child.sym), pins FOO (1-level surfacing) + CTRL
#    child.sch       : ipin FOO; xg (grandchild.sym) pin CTRL wired to top,
#                      pin BAR wired to a buried lab_pin (no port)
#    grandchild.sch  : ipin BAR (buried) + ipin CTRL (surfaces 2 levels)
#
#  So: FOO surfaces 1 level, CTRL surfaces 2 levels, BAR is buried 2 levels.
#

set here [file normalize [file dirname [info script]]]
cd [file join $here hilight_xwin_sync]
# fixture hygiene: a prior test that made an unsaved edit may have left a ~-backing file
# (e.g. parent~.sch, from descend-autosave) that xschem would load INSTEAD of the .sch,
# silently changing the fixture; delete any before loading.
foreach f [glob -nocomplain *~.sch] { catch {file delete -force $f} }

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} {
    puts "ok   - $desc"
  } else {
    puts "$desc (got '$got' want '$want'): FAIL"
    incr nfail
  }
}
# membership: is $elem in the display_hilights list $lst ?
proc has {lst elem} { expr {[lsearch -exact $lst $elem] >= 0} }

proc reload {} {
  # fresh top every subtest, no highlights carried over
  xschem load [file join [pwd] parent.sch]
  xschem unhilight_all
}

# ---------------------------------------------------------------------------
# DOWN direction (parent net -> child pin net, via hilight_child_pins on descend)
# ---------------------------------------------------------------------------
reload
xschem hilight_netname FOO
check "top highlights FOO"                 [has [xschem display_hilights] FOO] 1
xschem select instance xi fast
xschem descend 1
check "descended to .xi."                  [xschem get sch_path] {.xi.}
check "DOWN: .xi. shows xi.FOO"            [has [xschem display_hilights] xi.FOO] 1

# ---------------------------------------------------------------------------
# UP 1-level: FOO highlighted at .xi. surfaces to top FOO on go_back
# ---------------------------------------------------------------------------
reload
xschem select instance xi fast
xschem descend 1
xschem unselect_all
xschem hilight_netname FOO
check "at .xi. FOO highlighted"            [has [xschem display_hilights] xi.FOO] 1
xschem go_back
check "back at top"                        [xschem get sch_path] {.}
check "UP1: FOO surfaced to top"           [has [xschem display_hilights] FOO] 1

# ---------------------------------------------------------------------------
# UP 2-level SURFACING (the relay's byte-target for a surfacing net): CTRL
# highlighted at .xi.xg. must surface all the way to top CTRL, and leave NO
# buried cue on xi (it reaches xi's pin).
# ---------------------------------------------------------------------------
reload
xschem select instance xi fast ; xschem descend 1
xschem unselect_all
xschem select instance xg fast ; xschem descend 1
check "descended to .xi.xg."               [xschem get sch_path] {.xi.xg.}
xschem unselect_all
xschem hilight_netname CTRL
check "at .xi.xg. CTRL highlighted"        [has [xschem display_hilights] xi.xg.CTRL] 1
xschem go_back
check "up to .xi. (CTRL)"                  [xschem get sch_path] {.xi.}
check "UP2 mid: CTRL at .xi."              [has [xschem display_hilights] xi.CTRL] 1
xschem go_back
check "up to top (CTRL)"                    [xschem get sch_path] {.}
check "UP2 SURFACING: CTRL reached top"    [has [xschem display_hilights] CTRL] 1
check "UP2 SURFACING: no buried cue on xi" [xschem hilight_buried xi] -1

# ---------------------------------------------------------------------------
# UP 2-level BURIED (the relay's byte-target for a buried net): BAR highlighted
# at .xi.xg. does NOT reach any xi pin, so at top it must NOT surface as a net
# but MUST light a buried cue on xi (validated buried).
# ---------------------------------------------------------------------------
reload
xschem select instance xi fast ; xschem descend 1
xschem unselect_all
xschem select instance xg fast ; xschem descend 1
xschem unselect_all
xschem hilight_netname BAR
check "at .xi.xg. BAR highlighted"         [has [xschem display_hilights] xi.xg.BAR] 1
xschem go_back
check "UP2 buried mid: BAR at .xi."        [has [xschem display_hilights] xi.BAR] 1
xschem go_back
check "back at top (BAR)"                   [xschem get sch_path] {.}
check "UP2 BURIED: BAR did NOT surface"    [has [xschem display_hilights] BAR] 0
check "UP2 BURIED: buried cue on xi"       [expr {[xschem hilight_buried xi] >= 0}] 1

set summary [expr {$nfail ? "OVERALL: FAIL ($nfail)" : "OVERALL: ok"}]
puts $summary
exit [expr {$nfail ? 1 : 0}]
