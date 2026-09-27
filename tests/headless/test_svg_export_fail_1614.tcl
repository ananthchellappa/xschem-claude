# tests/headless/test_svg_export_fail_1614.tcl
#
# ISSUE 1614 -- a failed SVG export left the user's grid switched off, and leaked
# svg_colors.
#
# `svg_draw()` in src/svgdraw.c switches `draw_grid` off so the exported picture
# has no grid, and restores the user's value in exactly ONE place, after fclose()
# at the end of the function. The two `fopen` failure paths used to sit BETWEEN
# those two points and `return` without restoring, so an export that could not open
# its file switched the grid off and left it off. A read-only directory, a full
# disk or a stale network mount was enough. svg_colors is my_calloc'd before the
# open and leaked on the same two paths.
#
# Driven at 5d7380b2, headless, into a directory with mode 500: draw_grid 1 before,
# **0 after**, no file written, and `xschem print svg` still reported rc=0 -- so the
# only signal was one dbg(0, ...) line on stderr, while the visible consequence in
# the GUI was the grid vanishing from the canvas, which does not point at a failed
# write.
#
# ⚠ THE rc=0 IS NOT THIS ISSUE'S AND IS NOT FENCED HERE. Whether `xschem print svg`
# should report failure is a separate and larger question about that verb's
# contract; row F4 RECORDS today's rc=0 as an observation so that a future change is
# a deliberate one, and says in its own name that it is not asserting rc=0 is
# correct.
#
# THE FIX IS AN ORDER, NOT A CLEANUP TAIL. The open moved ABOVE the grid change, so
# there is now no `return` between `tclsetvar("draw_grid", "0")` and its restore.
# That invariant is cheaper to hold than three copies of a cleanup tail: a fourth
# exit added later would miss one again, which is exactly how this happened. Row G1
# asserts the invariant over the live text; F1 drives it.
#
# SECTIONS
#   F1-F5   BEHAVIOURAL, headless. The failed export preserves the setting for BOTH
#           values (F1, F2) -- two values, so a fix that hardcoded 1 cannot pass --
#           the successful export restores it (F3), the exported picture really is
#           gridless whatever the user's setting (F5, which is the REASON the
#           function touches the grid at all), and F4 records the rc.
#   G1-G3   STRUCTURAL, over the comment-stripped body of svg_draw(). G1 is the
#           invariant. G2 is the leak. G3 pins the DELIBERATE choice not to move the
#           allocation below the open.
#
# ⚠ F1/F2/F4 need a directory the process cannot write to. Running as root defeats
# mode 500, so they probe first and `skip:` rather than passing vacuously.
#
# ARMED SPELLING
#   tests/headless/run_suites.sh --nogui test_svg_export_fail_1614
# Registered in tests/run_regression.tcl in `hcases` only: nothing here needs a
# display.
#
# FLOOR: 8 checks (5 behavioural + 3 structural). Measured 2026-09-27.
# RAISED, NEVER LOWERED.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc skiprow {names why} { puts "skip: $names -- $why" ; flush stdout }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]

set scratch [test_scratch svgfail]
set SVGC [file join $repo src svgdraw.c]

proc slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
## /* ... */ and // stripped. The fix's own comment in svgdraw.c quotes the
## defective shape and names `return`, so a structural row reading the raw file
## would answer "the bug is still here" for ever. Not a C tokeniser: a `/*` inside
## a string literal would fool it, and this sentence is the limit statement rather
## than a claim that none can exist.
proc nocomment_c {text} {
  regsub -all {/\*.*?\*/} $text " " text
  set out {}
  foreach l [split $text "\n"] { regsub {//.*$} $l "" l ; lappend out $l }
  return [join $out "\n"]
}
## A C function body: its opening line to the first column-0 `}`. ZZNOFUNC if it is
## not there, so no row can pass by finding nothing.
proc cfunc_body {src name} {
  set on 0 ; set out {}
  foreach l [split $src "\n"] {
    if {$on} {
      if {[regexp {^\}} $l]} { return [join $out "\n"] }
      lappend out $l ; continue
    }
    if {[regexp "^\[a-zA-Z_\].*\[ \t\*\]$name\[ \t\]*\\(" $l]} { set on 1 }
  }
  if {$on} { return [join $out "\n"] }
  return ZZNOFUNC
}

set FIX [file join $repo xschem_library examples 0_examples_top.sch]

#############################################################################
## Is there a directory this process genuinely cannot write to?
#############################################################################
set nowrite [file join $scratch nowrite]
file mkdir $nowrite
catch {file attributes $nowrite -permissions 0500}
set probe [file join $nowrite .probe]
set unwritable [catch {set p [open $probe w] ; close $p ; file delete $probe}]

#############################################################################
## F -- BEHAVIOURAL
#############################################################################
proc export_to {dest gridval} {
  global FIX
  set ::draw_grid $gridval
  catch {xschem load $FIX}
  catch {xschem zoom_full}
  set rc [catch {xschem print svg $dest}]
  return [list $rc $::draw_grid [file exists $dest]]
}

if {!$unwritable} {
  skiprow "F1/F2/F4" "no directory this process cannot write to -- mode 0500 did not take (running as root?), so a failed open cannot be produced and these rows would pass without measuring anything"
} else {
  ## F1/F2 -- the defect. TWO values, so a fix that restored a hardcoded 1 fails F2.
  set bad [file join $nowrite out.svg]
  set r1 [export_to $bad 1]
  check "F1 an export that cannot open its file leaves draw_grid at 1 and writes no file" \
    [list [lindex $r1 1] [lindex $r1 2]] {1 0}
  set r0 [export_to $bad 0]
  check "F2 the same with draw_grid 0 -- the value is PRESERVED, not set to a constant" \
    [list [lindex $r0 1] [lindex $r0 2]] {0 0}
  ## F4 -- an observation, deliberately not a judgement. See the header.
  check "F4 OBSERVATION ONLY, asserting today's behaviour so a change to it is deliberate: the verb reports rc=0 on a failed export. This row does NOT claim rc=0 is correct -- that is the print verb's contract and a separate issue" \
    [lindex $r1 0] 0
}

## F3/F5 -- the success path, which needs no unwritable directory.
set good [file join $scratch good.svg]
set g1 [export_to $good 1]
check "F3 a successful export restores draw_grid to 1 and writes the file" \
  [list [lindex $g1 1] [lindex $g1 2]] {1 1}

## F5 -- the REASON svg_draw() touches the grid at all: the exported picture must be
## gridless whatever the user's setting. Asserted as a SHAPE -- the two exports are
## byte-identical -- rather than by hunting for grid marks, which would be a fence
## keyed to a symptom.
set withgrid [file join $scratch wg.svg]
set nogrid   [file join $scratch ng.svg]
export_to $withgrid 1
export_to $nogrid 0
set same 0
if {[file exists $withgrid] && [file exists $nogrid]} {
  set same [expr {[slurp $withgrid] eq [slurp $nogrid]}]
}
check "F5 the exported SVG is byte-identical whether the user's grid is on or off -- which is WHY the function turns it off, and what the restore has to put back" \
  $same 1

#############################################################################
## S -- STRUCTURAL, over svg_draw()'s comment-stripped body.
#############################################################################
set SBODY [cfunc_body [nocomment_c [slurp $SVGC]] svg_draw]
set lines [split $SBODY "\n"]

## Walk the body once: find the grid-set line and the restore line, and count the
## `return` statements strictly between them. That number must be ZERO, and it is
## the invariant the fix installed.
set iset -1 ; set irestore -1 ; set between 0
for {set i 0} {$i < [llength $lines]} {incr i} {
  set l [lindex $lines $i]
  if {$iset < 0 && [regexp {tclsetvar\s*\(\s*"draw_grid"\s*,\s*"0"\s*\)} $l]} { set iset $i ; continue }
  if {$iset >= 0 && $irestore < 0 && [regexp {tclsetboolvar\s*\(\s*"draw_grid"\s*,\s*old_grid\s*\)} $l]} { set irestore $i ; continue }
  if {$iset >= 0 && $irestore < 0 && [regexp {(^|\W)return(\W|$)} $l]} { incr between }
}
check "G1 THE INVARIANT: in svg_draw()'s comment-stripped body both the draw_grid set and its restore are present, in that order, with ZERO `return` statements between them -- greps those two spellings and counts returns in the span, and says nothing about returns outside it" \
  [list [expr {$iset >= 0}] [expr {$irestore > $iset}] $between] {1 1 0}

## G2 -- the leak. Both fopen failure paths free svg_colors. Counted as occurrences
## of the free inside the span from the first fopen to the grid set, which is where
## the two failure paths now live.
##
## ⚠ THIS ROW IS NOT INDEPENDENT OF G1, AND SAYING SO IS THE POINT. Its span is
## bounded by the grid-set line, so reverting the ORDER moves the frees out of the
## span and reddens G2 as well as G1 -- measured. Removing one `my_free` alone
## reddens G2 alone, also measured, so the row does fence the leak on its own; it
## just is not blind to the order. A span bounded by a `}` or by the fopen block's
## own extent would be independent but would also drift the moment the block is
## re-shaped, and this file has already learned once today that a fence keyed to the
## wrong landmark dies quietly.
set iopen -1
for {set i 0} {$i < [llength $lines]} {incr i} {
  if {[regexp {fd\s*=\s*fopen} [lindex $lines $i]]} { set iopen $i ; break }
}
set frees 0
if {$iopen >= 0 && $iset > $iopen} {
  for {set i $iopen} {$i < $iset} {incr i} {
    if {[regexp {my_free\s*\(\s*_ALLOC_ID_\s*,\s*&svg_colors\s*\)} [lindex $lines $i]]} { incr frees }
  }
}
check "G2 THE LEAK: between the first `fd = fopen` and the draw_grid set, svg_draw() frees svg_colors twice -- one per failure path. Greps that one spelling in that span; it does not know how many failure paths there are" \
  [list [expr {$iopen >= 0}] $frees] {1 2}

## G3 -- the ordering choice that is NOT an oversight, pinned so nobody "tidies" it.
## svg_colors is allocated ABOVE the open on purpose: on a calloc failure no file has
## been created, and moving the allocation below the open would start leaving a
## zero-length .svg behind on that path.
set icalloc -1
for {set i 0} {$i < [llength $lines]} {incr i} {
  if {[regexp {svg_colors\s*=\s*my_calloc} [lindex $lines $i]]} { set icalloc $i ; break }
}
check "G3 svg_colors is allocated BEFORE the first fopen, deliberately -- moving it after would leave a zero-length .svg behind when the calloc fails, which is why the failure paths free it instead of the allocation moving" \
  [list [expr {$icalloc >= 0}] [expr {$iopen > $icalloc}]] {1 1}

#############################################################################
puts "RESULT: [expr {$fail ? "$fail FAILED ($npass passed)" : "ALL PASS ($npass checks)"}]"
if {$fail} { puts "OVERALL: FAIL" } else { puts "OVERALL: ok ($npass checks)" }
catch {file attributes $nowrite -permissions 0700}
test_scratch_drop $scratch
