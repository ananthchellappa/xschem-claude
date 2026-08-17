# test_ngspice_data_ctx.tcl — the lazy `ngspice::ngspice_data` view ACROSS WINDOWS.
#
# Casemode batch **item 5b, fix round**. Spec: `doc/claude/specs/raw_case_mode.md`
# section 13.7. Companion suite: `test_ngspice_data_view.tcl` (121 checks, true
# headless) covers the view itself; this file covers the one thing that file
# cannot, because it needs a SECOND WINDOW: what a Tcl context switch does to a
# traced array.
#
# THE DEFECT. `ngspice::ngspice_data` was in `tctx::global_array_list`, so every
# tab/window create, switch and close ran restore_ctx's `unset -nocomplain` over it
# — and an unset DESTROYS every trace on the variable. The lazy view became a
# frozen eager copy keyed only by the database's stored spellings, and since item
# 5b deleted the Tcl-side `string tolower` and `v(...)` rungs on purpose, the
# schematic operating-point overlay then read `?` for EVERY node after one Ctrl-T.
# Measured on this road: BEFORE `get_voltage MidNode` = 0, AFTER = `?`; a pristine
# HEAD binary was unaffected, so it was a regression of this item, not a pre-existing
# hole. All 375 checks of the batch's other suites stayed green through it.
#
# THE OTHER HALF. Taking the array out of that list is what fixes it, but the
# membership was also what gave each window its own (usually empty) array. That is
# now enforced in C: nd_view_owned() (src/save.c) answers only while the publishing
# database is reachable from the CURRENT context, and a read from a window that does
# not own it drops the elements the owning window materialised. CS113e/CS113f are
# that half — without them a sibling window read the publisher's numbers for any
# net that happened to share a name.
#
# RUN WITH A DISPLAY (this file drives real windows; --nogui cannot):
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog \
#     --script tests/headless/test_ngspice_data_ctx.tcl
# full_audit.sh runs it on its own display arm; it is deliberately NOT in that
# script's nogui_tests list.

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}
proc pcall {args} {
  if {[llength $args] == 1} { set args [lindex $args 0] }
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
proc arr_get {n} {
  if {[catch {set ::ngspice::ngspice_data($n)} r]} { return {<unset>} }
  return $r
}
proc arr_names {} { return [lsort [array names ::ngspice::ngspice_data]] }
proc isnum {v} { return [string is double -strict $v] }
# arithmetic on an ERR: string (a verb this binary does not have) raises a Tcl error
# that aborts the file with NO RESULT line, under which a sabotage reads as "nothing
# went red". Every number that reaches an `expr` goes through this first.
proc num {v {dflt -9999}} {
  if {[string is double -strict $v]} { return $v }
  return $dflt
}

set fixdir [file join [file dirname [info script]] .. .. doc claude casemode_batch fixtures]
set presraw [file normalize [file join $fixdir tr_preserve.raw]]
set foldraw [file normalize [file join $fixdir tr_fold.raw]]

check CS113-fixtures-present [expr {[file exists $presraw] && [file exists $foldraw]}] \
  "($presraw)"

# ---------------------------------------------------------------------------
# publish in the first window
# ---------------------------------------------------------------------------
eqcheck CS113a-premise-read [pcall xschem raw read $presraw tran -case preserve] 1
eqcheck CS113b-premise-published [pcall xschem update_op] 1
set owner [xschem get current_win_path]
check CS113c-the-overlay-reads-a-number-in-the-publishing-window \
  [isnum [ngspice::get_voltage MidNode]] "(win=$owner got '[ngspice::get_voltage MidNode]')"
set before [ngspice::get_voltage MidNode]
# MATERIALISE SEVERAL ELEMENTS, on purpose and before the switch. One is not
# enough to catch the shape that leaked: the drop walks its own list while Tcl
# delivers an unset callback for every element EXCEPT the one whose read trace is
# running, so with a single key the re-entrancy never happens. CS113e3 below is
# what fails when the walk is not detached from that list.
foreach cs113_n {In i(Vs) v(MidNode) v(In)} { set cs113_x [arr_get $cs113_n] }
check CS113c2-several-elements-materialised \
  [expr {[llength [array names ::ngspice::ngspice_data]] >= 5}] \
  "(names=[arr_names])"

# ---------------------------------------------------------------------------
# a second window: no database of its own
# ---------------------------------------------------------------------------
eqcheck CS113d-second-window-created [pcall xschem new_schematic create noconfirm {}] 1
after 300
update
set sibling [xschem get current_win_path]
check CS113d2-and-we-are-in-it [expr {$sibling ne $owner}] "(owner=$owner sibling=$sibling)"
# THE OWNERSHIP GUARD. This window never annotated anything, so it must read `?`
# — including for a net whose element the OTHER window had already materialised,
# which is the shape that leaked before the guard dropped them.
eqcheck CS113e-a-window-that-never-annotated-reads-? [ngspice::get_voltage MidNode] {?}
eqcheck CS113e2-and-so-does-the-element-read-directly [arr_get MidNode] <unset>
# EVERY element the other window materialised is gone, not just the first one the
# read happened to touch.
set cs113_left {}
foreach cs113_n {In i(Vs) v(MidNode) v(In) MidNode} {
  if {[arr_get $cs113_n] ne {<unset>}} { lappend cs113_left $cs113_n }
}
eqcheck CS113e3-and-NONE-of-the-other-materialised-elements-survived $cs113_left {}
eqcheck CS113f-and-it-enumerates-only-the-two-bookkeeping-entries \
  [arr_names] [list {n\ points} {n\ vars}]

# ---------------------------------------------------------------------------
# back to the publisher: THE BLOCKER
# ---------------------------------------------------------------------------
pcall xschem new_schematic switch $owner
after 300
update
eqcheck CS113g-we-are-back [xschem get current_win_path] $owner
# One line for the whole fix round: before it, this read `?`.
eqcheck CS113h-THE-OVERLAY-READS-A-NUMBER-AGAIN-AFTER-THE-ROUND-TRIP \
  [ngspice::get_voltage MidNode] $before
eqcheck CS113h2-and-the-folded-spelling-resolves-through-the-same-ladder \
  [ngspice::get_voltage midnode] $before
eqcheck CS113h3-and-the-current-spelling-too [ngspice::get_voltage In] \
  [arr_get {v(In)}]
# ...and it is still a LAZY VIEW, not a copy that survived by luck: `zz_ctx` did
# not exist when the publisher ran, so only a live view can answer for it.
eqcheck CS113i-still-a-view-rename-in-the-database \
  [pcall xschem raw rename {v(MidNode)} zz_ctx] 1
check CS113j-and-the-view-follows-it [expr {[arr_get zz_ctx] eq $before}] \
  "(zz_ctx='[arr_get zz_ctx]' want '$before')"
eqcheck CS113k-and-enumeration-is-rebuilt-from-the-database \
  [llength [arr_names]] [expr {[num [pcall xschem raw vars] 0] + 2}]

# ---------------------------------------------------------------------------
# a database loaded in the SIBLING must not become the publisher
# ---------------------------------------------------------------------------
# The view is pinned to the database that published, and per-window on top of it.
# Loading another raw in the other window changes neither.
pcall xschem new_schematic switch $sibling
after 200
update
eqcheck CS113l-sibling-loads-its-own-database [pcall xschem raw read $foldraw tran] 1
# it did not publish (no update_op), and it does not own ours
eqcheck CS113m-sibling-still-reads-? [ngspice::get_voltage in] {?}
pcall xschem new_schematic switch $owner
after 200
update
eqcheck CS113n-and-the-publisher-window-is-unchanged [arr_get zz_ctx] $before

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
flush stdout
exit [expr {$fail ? 1 : 0}]
