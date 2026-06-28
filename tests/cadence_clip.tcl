#
#  File: cadence_clip.tcl
#
#  Headless regression for the ALT-SHIFT-C "capture lib/cell/view" helper.
#  See doc/claude/specs/cadence_capture_lcv.md
#
#  Run UNDER xschem (the `xschem` command must be available):
#      cd tests
#      ../src/xschem --nogui --pipe -q --script cadence_clip.tcl
#
#  Covers the headless-verifiable logic: the pure slash-path parser and the
#  text-selection branch of cadence::capture_lcv. The live X clipboard and the
#  instance / current-cell branches (which need a registered library) are
#  verified in the GUI -- see the spec.
#

set here  [file normalize [file dirname [info script]]]
set utils [file normalize [file join $here .. utils]]
set fix   [file join $here buried_hilight]   ;# reuse the small a.sch fixture

if {[info commands ciw_echo] eq ""} { proc ciw_echo {args} {} }
source [file join $utils cadence_nav.tcl]
source [file join $utils cadence_clip.tcl]

# Capture what would be copied without needing Tk's clipboard (absent under --nogui).
set ::captured "<none>"
proc cadence::clip_put {s} { set ::captured $s ; ciw_echo "copied to clipboard: $s" result }

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

# --- pure slash-path parser ----------------------------------------------
check "slashpath bare lcv"        [cadence::first_slashpath "lib/cell/view"]        {lib/cell/view}
check "slashpath embedded"        [cadence::first_slashpath "go to amp/stage1/M3 now"] {amp/stage1/M3}
check "slashpath two-component"   [cadence::first_slashpath "devices/res"]          {devices/res}
check "slashpath first-of-many"   [cadence::first_slashpath "a/b then c/d/e"]       {a/b}
check "slashpath single word"     [cadence::first_slashpath "plainword"]            {}
check "slashpath empty"           [cadence::first_slashpath ""]                     {}

# --- text-selection branch (real selection, stubbed clip sink) ------------
cd $fix
xschem load {a.sch}
xschem unselect_all
xschem text 100 100 0 0 {place at amp/stage1/M3} {} 0.4 1   ;# fresh load -> text index 0
xschem select text 0
set ::captured "<none>"
cadence::capture_lcv
check "capture_lcv text branch copies slash path" $::captured {amp/stage1/M3}

# text note with no slash path -> nothing copied
xschem load {a.sch}
xschem unselect_all
xschem text 100 100 0 0 {just a label} {} 0.4 1
xschem select text 0
set ::captured "<none>"
cadence::capture_lcv
check "capture_lcv text branch no-path leaves clipboard untouched" $::captured {<none>}

# nothing selected and current cell not in a registered library -> nothing copied
xschem load {a.sch}
xschem unselect_all
set ::captured "<none>"
cadence::capture_lcv
check "capture_lcv none branch unregistered cell does not copy" $::captured {<none>}

if {$nfail} { puts "cadence_clip: $nfail check(s): FAIL" } \
else        { puts "cadence_clip: all checks PASS" }
