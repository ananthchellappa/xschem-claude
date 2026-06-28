#
#  File: buried_hilight.tcl
#
#  Headless regression for the BURIED-NET HIGHLIGHT INDICATOR.
#  See doc/claude/specs/buried_net_hilight.md and
#  doc/claude/suggestions/plan_buried_net_hilight.md
#
#  Must run UNDER xschem (so the `xschem` command is available):
#
#      cd tests
#      ../src/xschem --nogui --pipe -q --script buried_hilight.tcl
#
#  Fixture (tests/buried_hilight/): a 4-level hierarchy A > x_b > x_c > x_d.
#  Cell D (d.sch) owns an internal net `buried_d` (a local lab_pin label, NOT a
#  port of d.sym). Highlighting it deep inside x_d and climbing back up must light
#  a "buried highlight" cue on each ancestor instance along the path.
#
#  Asserts the detection only (drawing is verified manually — see the spec's
#  acceptance checklist; a green suite here does NOT prove the pixels).
#

set here [file normalize [file dirname [info script]]]
set fixdir [file join $here buried_hilight]
cd $fixdir

set STYLE 3        ;# a deterministic, non-zero style index (0 would alias the
                   ;# memset default and could mask an uninitialised field)
set nfail 0

# check: ends a failing line in "FAIL" so run_regression's `FAIL$` grep catches it.
proc check {desc got want} {
  global nfail
  if {$got eq $want} {
    puts "ok   - $desc"
  } else {
    puts "$desc (got '$got' want '$want'): FAIL"
    incr nfail
  }
}

proc godown {inst} {
  xschem unselect_all
  if {[xschem select instance $inst] ne "1"} { puts "select $inst: FAIL" }
  if {[xschem descend] ne "1"} { puts "descend $inst: FAIL" }
}

xschem load {a.sch}

# Descend A -> x_b -> x_c -> x_d (now viewing cell D).
godown x_b
godown x_c
godown x_d

# Highlight the buried net inside D with a known style.
check "highlight buried net buried_d in D" \
      [xschem hilight_netname -style $STYLE buried_d] 1

# Climb back up: each ancestor instance must inherit the buried cue (the buried
# net's style index), because the highlight lives strictly under that instance and
# is not exposed at its pins.
xschem go_back   ;# now in C
check "at C: instance x_d inherits buried cue" [xschem hilight_buried x_d] $STYLE

xschem go_back   ;# now in B
check "at B: instance x_c inherits buried cue" [xschem hilight_buried x_c] $STYLE

xschem go_back   ;# now in A (top)
check "at A: instance x_b inherits buried cue" [xschem hilight_buried x_b] $STYLE

# Only unhilight-all can clear a buried cue from above (by design).
xschem unhilight_all
check "after unhilight_all: x_b cue cleared" [xschem hilight_buried x_b] -1

# --- Acceptance #4: a net that DOES reach a pin colors the instance (existing
# behavior) and must NOT additionally produce a redundant buried cue. This is the
# meaningful contrast with buried_d above: BOTH nets create a highlight entry deep
# under x_d (path .x_b.x_c.x_d.), but only the one not exposed at x_d's pin yields a
# cue. A bare "no cue" here would be hollow without that contrast — net A reaches
# d.sym's pin A, so the exclusion in compute_buried_hilights() is what must fire. ---
godown x_b
godown x_c
godown x_d
check "highlight pin-reaching net A in D" [xschem hilight_netname -style $STYLE A] 1
xschem go_back   ;# now in C
check "at C: x_d gets NO buried cue for a pin-reaching net" [xschem hilight_buried x_d] -1
xschem unhilight_all

# --- Recency tie-break (the spec rule): with several buried nets under one instance,
# the MOST RECENTLY applied one lends its style to the cue. Two orderings pin the rule
# down: it must beat BOTH a lowest-index and a highest-index tie-break.
# (We are in cell C here; godown x_d descends into D.) ---

# R1: apply low (2) then high (6) -> latest is 6. A min-rule would wrongly give 2.
godown x_d
xschem hilight_netname -style 2 buried_d
xschem hilight_netname -style 6 buried_d2
xschem go_back   ;# C
check "recency: latest of {2 then 6} wins (=6, not min)" [xschem hilight_buried x_d] 6
xschem unhilight_all

# R2: apply high (6) then low (2) -> latest is 2. A max-rule would wrongly give 6.
godown x_d
xschem hilight_netname -style 6 buried_d
xschem hilight_netname -style 2 buried_d2
xschem go_back   ;# C
check "recency: latest of {6 then 2} wins (=2, not max)" [xschem hilight_buried x_d] 2
xschem unhilight_all

if {$nfail} {
  puts "buried_hilight: $nfail check(s): FAIL"
} else {
  puts "buried_hilight: all checks PASS"
}
