# RED-first regression: arming a second gesture on top of a live placement preview must not
# ORPHAN it. Issue 0242.
#
# THE INVARIANT
#   xctx->sympin_preview must never outlive START_SYMPIN.
#
# WHY IT BROKE
#   unselect_all() (select.c) zeroes ui_state wholesale whenever something is selected, and a live
#   placement preview is ALWAYS selected. So every actor that clears the selection dropped
#   START_SYMPIN|STARTMOVE without running the placement teardown -- which lives only in
#   abort_placement_preview() (callback.c) -- while sympin_preview / wirelabel_preview (plain
#   Xschem_ctx fields, not ui_state bits) and the preview INSTANCE both survived. The leftover is
#   not a cosmetic glyph: it is a connected, netlist-visible lab_pin/ipin that silently RENAMES the
#   net it sits on, committed by a user who never dropped it.
#
# WHY IT WAS TERMINAL ON SIX OF THE NINE DOORS
#   With sympin_preview stuck at 1, callback.c's Button-1 select/grab block (guarded on
#   !sympin_preview) refuses every press, and wire_label_try_commit() -- guarded on START_SYMPIN,
#   which is gone -- refuses every drop. ESC cannot repair it either: abort_placement_preview() is
#   gated on the very bit that was dropped. The canvas is dead for the rest of the session.
#
# THE FIX under test: every door calls leave_placement_for() before it arms (merge_file() in
# paste.c covers paste/merge/Ctrl+V/the -file replay form; place_symbol, place_text, add_graph,
# add_image and the undo/redo verbs in scheduler.c), and the three form `-place` arms now raise
# sympin_preview WITH START_SYMPIN instead of before it, so the pair is atomic.
#
# Pure headless -- no `xschem callback`, so it runs true-headless. From the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_placement_preview_doors.tcl
# Prints "RESULT: ALL PASS" on success.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc note {msg} { puts "note: $msg" }

proc sp {}        { return [xschem get sympin_preview] }
proc sympin_bit {} { return [expr {([xschem get ui_state] & 16384) ? 1 : 0}] }   ;# START_SYMPIN

## The invariant itself, as one assertable number. 0 = holds.
proc desync {} { return [expr {[sp] && ![sympin_bit]}] }

## How many lab_pin.sym instances are sitting in the drawing. The orphan oracle: the preview is a
## lab_pin, so a non-zero count after a cancelled gesture is an instance the user never dropped.
proc orphans {} {
  set n 0
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[xschem getprop instance $i cell::name] eq "lab_pin.sym"} { incr n }
  }
  return $n
}

## Does the orphan actually rename the net? `instance_net l1 p` resolves the net at the preview
## instance's pin; it errors when no such instance exists, which is the healthy answer.
proc renamed_net {} {
  if {[catch {xschem instance_net l1 p} r]} { return "" }
  return $r
}

## One real edit on a clean document, nothing selected: wires=1, modified=1.
proc setup {} {
  xschem abort_operation ; xschem abort_operation ; xschem abort_operation
  xschem clear force
  xschem wire 0 0 100 0
  xschem unselect_all
}
## Arm an Add-Wire-Label cursor preview named FOO on top of that edit.
proc arm {} { set ::label_new_name FOO ; xschem add_wire_label -place }
proc esc3 {} { xschem abort_operation ; xschem abort_operation ; xschem abort_operation }

set sym [file normalize [file join [file dirname [info script]] .. .. xschem_library devices lab_pin.sym]]
if {![file exists $sym]} { puts "RESULT: SKIP (no lab_pin.sym at $sym)" ; exit 0 }

## A one-wire cell to merge. Section E needs a merge source whose objects are COUNTABLE from Tcl:
## lab_pin.sym is fine for the door sections (they only assert cleanup) but merging a .sym adds
## rects/lines/texts and no instances, so it cannot show that a replay actually landed.
source [file join [file dirname [info script]] scratch.tcl]
set mergesrc [file join [test_scratch pvdoors] one_wire.sch]
set fh [open $mergesrc w]
puts $fh "v {xschem version=3.4.8RC file_version=1.3}"
puts $fh "G {}" ; puts $fh "K {}" ; puts $fh "V {}" ; puts $fh "S {}" ; puts $fh "E {}"
puts $fh "N 300 300 400 300 {lab=#net1}"
close $fh

# ---------------------------------------------------------------------------
# A. Baseline contract -- no door. ESC on a live preview leaves nothing behind.
# ---------------------------------------------------------------------------
setup
check "A1 clean: no preview armed"        [sp] 0
arm
check "A2 armed: sympin_preview raised"   [sp] 1
check "A2 armed: START_SYMPIN raised"     [sympin_bit] 1
check "A2 armed: invariant holds"         [desync] 0
check "A2 armed: preview instance exists" [xschem get instances] 1
esc3
check "A3 ESC: preview flag cleared"      [sp] 0
check "A3 ESC: no orphan left"            [orphans] 0
check "A3 ESC: net not renamed"           [renamed_net] {}
check "A3 ESC: the real edit survived"    [xschem get wires] 1
check "A3 ESC: invariant holds"           [desync] 0

# ---------------------------------------------------------------------------
# B. One door per section. Each: arm the preview, fire the door, ESC three times.
#    Pre-fix every row below left sympin_preview=1 and/or a committed lab_pin.
#
#    `modified` is deliberately NOT asserted on the merge doors: ESC-ing a paste clobbers an
#    already-dirty document's flag to 0 (issue 0244, landing separately). That is a flag-only
#    defect with its own repro and its own fix; asserting it here would pin the wrong contract.
# ---------------------------------------------------------------------------
proc door_case {tag body} {
  setup ; arm
  uplevel 1 $body
  esc3
  check "$tag: sympin_preview cleared"   [sp] 0
  check "$tag: invariant holds"          [desync] 0
  check "$tag: no orphan lab_pin"        [orphans] 0
  check "$tag: net not renamed"          [renamed_net] {}
  check "$tag: the real edit survived"   [xschem get wires] 1
}

## B1 Ctrl+V. The 4-keystroke repro from the issue: `l`, a name, Ctrl+V.
##    merge_file(2) -> unselect_all(1). Terminal pre-fix (ui 16424 -> 296, sp stuck at 1).
xschem clear force ; xschem wire 900 900 1000 900 ; xschem select_all ; xschem copy
door_case "B1 paste (Ctrl+V)" { xschem paste }

## B2 Merge a named file -- the `b` key / File > Merge. Same funnel, different entry.
door_case "B2 merge <file>" { xschem merge $::sym }

## B3 The action-log REPLAY form. The gate needs a live placement, so a real replay run (which
##    has none) is unaffected -- but a user who pastes while a preview rides the cursor reaches
##    the identical merge_file(), and pre-fix it was terminal here too.
door_case "B3 paste x y -file (replay form)" { xschem paste 200 200 -file $::sym }

## B4 Redo. pop_undo_keep_selection() ends with an UNCONDITIONAL unselect_all(0), so redo is a
##    door even with an empty redo stack -- pre-fix sp stuck at 1 with ui_state 8.
door_case "B4 redo" { xschem redo }

## B5 Undo. The ONE row here that was already green before the fix, and deliberately kept: a DISK
##    undo self-cleans by accident, via clear_drawing()'s sympin_preview reset (actions.c) on the
##    reload. That accident does not cover the memory backend, `xschem undo 1 1` (a redo wearing
##    the undo verb) or an empty stack -- and all three still run the unconditional unselect_all(0)
##    at the end of pop_undo_keep_selection(). This row pins the gate that makes undo correct on
##    purpose rather than by backend.
door_case "B5 undo" { xschem undo }

## B6 Place text (`T`). Under --nogui the text dialog cannot open, which is exactly the CANCELLED
##    dialog case: the unselect_all(1) has already run, so pre-fix this left ui=0 with sp=1 --
##    terminal on a dialog the user backed out of.
door_case "B6 place_text" { catch {xschem place_text} }

## B7 Insert symbol. Reaches the orphan with NO unselect_all at all: it just ORs PLACE_SYMBOL
##    over the live preview, so the two placements share one STARTMOVE.
door_case "B7 place_symbol <file>" { xschem place_symbol $::sym }

## B8 Add graph. See section D for the undo baseline this door used to destroy.
door_case "B8 add_graph" { xschem add_graph }

## B9 Insert image -- gated before the file chooser, so a cancelled chooser is covered too.
door_case "B9 add_image" { catch {xschem add_image} }

## B10-B13 `net_label` -- a door the issue's 17-verb census did NOT contain. Found by the tripwire
##    while verifying the fix: place_net_label() (actions.c) ORs START_SYMPIN over the live preview
##    and shares its STARTMOVE, exactly like place_symbol. One arm, four types, four routes each
##    (Alt+Shift+L, Ctrl+P, Ctrl+Shift+P and this scripted verb). Measured orphan=1 on every type
##    before the gate. This is the whole argument for enumerating arms from the ui_state bits they
##    set rather than from the verbs a bug report happened to name (the 0247 lesson, WIRING §8 D).
door_case "B10 net_label 0 (lab_wire)" { xschem net_label 0 }
door_case "B11 net_label 1 (lab_pin)"  { xschem net_label 1 }
door_case "B12 net_label 2 (ipin)"     { xschem net_label 2 }
door_case "B13 net_label 3 (opin)"     { xschem net_label 3 }

# ---------------------------------------------------------------------------
# C. One undo baseline per gesture (add_wire_label.md #8) -- the sabotage target.
#    The modeless form re-issues `-place` on EVERY keystroke. All of those re-arms must share ONE
#    baseline, so a single undo returns to the pre-arm document. If the teardown ever stops
#    no-op'ing at the re-arms (drop the START_SYMPIN term that gates it) each keystroke pushes its
#    own baseline and this section goes red.
# ---------------------------------------------------------------------------
setup
set ::label_new_name F
xschem add_wire_label -place
foreach ch {FO FOO FOOB FOOBA FOOBAR} {
  set ::label_new_name $ch
  xschem add_wire_label -place
  check "C1 re-arm $ch: invariant holds"      [desync] 0
  check "C1 re-arm $ch: exactly one preview"  [orphans] 1
}
check "C2 after 6 re-arms: one preview only" [xschem get instances] 1
esc3
check "C3 ESC after re-arms: no orphan"      [orphans] 0
check "C3 ESC after re-arms: wire survived"  [xschem get wires] 1
check "C3 ESC after re-arms: invariant"      [desync] 0

## C3b THE UNDO-DEPTH ORACLE -- the sabotage detector the landmine asks for, and which did not
##     exist anywhere in the suite before this file (grep: neither test_add_wire_label.tcl nor
##     test_sch_add_pin.tcl asserts undo depth).
##
##     Six keystrokes, one COMMITTED drop, then ONE undo must return the document to its pre-arm
##     state. The drop itself pushes nothing (move_objects END under START_SYMPIN), so the single
##     baseline taken at the FIRST arm is the only rollback point.
##
##     What it catches: anything that makes the placement teardown fire at a `-place` RE-ARM
##     instead of no-op'ing there. The teardown clears sympin_preview, so the next keystroke's
##     `sympin_preview && START_SYMPIN` test goes false and takes the push_undo() branch -- one
##     fresh baseline per character typed.
##
##     TWO real edits before the gesture, not one, and TWO undos after it. One undo alone cannot
##     tell the cases apart: every spurious per-keystroke baseline snapshots the SAME document
##     (the preview was just torn down), so rolling back one of them looks exactly like rolling
##     back the single correct baseline. The SECOND undo is the discriminator -- with one baseline
##     it reaches past the gesture and removes wire B; with six it merely eats another keystroke
##     and wire B is still standing.
setup                                  ;# wire A: 0 0 -> 100 0
xschem wire 0 100 100 100              ;# wire B: its own undo baseline
xschem unselect_all
check "C3b two real edits"                   [xschem get wires] 2
set ::label_new_name F
xschem add_wire_label -place
foreach ch {FO FOO FOOB FOOBA FOOBAR} { set ::label_new_name $ch ; xschem add_wire_label -place }
check "C3b drop committed"                   [xschem add_wire_label -drop 50 0] 1
check "C3b drop: label is in the drawing"    [orphans] 1
check "C3b drop: flag cleared on commit"     [sp] 0
xschem undo
check "C3b undo 1 removes the label"         [orphans] 0
check "C3b undo 1 keeps both real edits"     [xschem get wires] 2
xschem undo
check "C3b undo 2 reaches PAST the gesture"  [xschem get wires] 1

## Same for the schematic Add-Pin form, whose arm shares the machinery.
setup
set ::pin_new_name P1 ; set ::pin_new_dir in
xschem add_sch_pin -place
check "C4 add_sch_pin armed: sp raised"      [sp] 1
check "C4 add_sch_pin armed: invariant"      [desync] 0
set ::pin_new_name P12
xschem add_sch_pin -place
check "C5 add_sch_pin re-arm: invariant"     [desync] 0
check "C5 add_sch_pin re-arm: one instance"  [xschem get instances] 1
esc3
check "C6 add_sch_pin ESC: flag cleared"     [sp] 0
check "C6 add_sch_pin ESC: nothing left"     [xschem get instances] 0
check "C6 add_sch_pin ESC: wire survived"    [xschem get wires] 1

# ---------------------------------------------------------------------------
# D. The add_graph undo baseline (issue 0242 landmine).
#    add_graph re-sets START_SYMPIN after its own unselect_all(1), so pre-fix a graph armed on top
#    of a label preview inherited sympin_preview=1 -- and abort_placement_preview()'s
#    `(sympin_preview && START_SYMPIN) ? delete(0) : delete(1)` discriminator then read TRUE for
#    the GRAPH and removed it with no undo baseline of its own. Tearing the preview down at the
#    door makes that discriminator's stated premise true, so the graph aborts with delete(1) again.
# ---------------------------------------------------------------------------
setup ; arm
check "D1 preview live before graph"        [sp] 1
xschem add_graph
check "D2 graph armed: preview torn down"   [sp] 0
check "D2 graph armed: invariant holds"     [desync] 0
check "D2 graph armed: no orphan lab_pin"   [orphans] 0
xschem abort_operation
check "D3 graph ESC: invariant holds"       [desync] 0
check "D3 graph ESC: wire survived"         [xschem get wires] 1

# ---------------------------------------------------------------------------
# E. Replay / coordinate-form bypass: with NO placement live the gate is a no-op, so the
#    action-log replay path is untouched. (scheduler.c's paste branch commits directly and never
#    re-logs; nothing here may change that.)
# ---------------------------------------------------------------------------
setup
check "E1 no preview live"                   [sp] 0
xschem paste 200 200 -file $::mergesrc
check "E2 replay landed the merged wire"     [xschem get wires] 2
check "E3 replay did not touch the flag"     [sp] 0
check "E3 replay invariant holds"            [desync] 0
esc3
## The coordinate form COMMITS outright (that is what makes it the replay seam -- it arms no
## pending STARTMERGE for a later drop), so ESC has nothing to roll back. Asserted so a future
## change to the gate's siting that turned replay back into a pending gesture would show up here.
check "E4 replay ESC: merge stayed committed" [xschem get wires] 2
check "E4 replay ESC: invariant holds"       [desync] 0

# ---------------------------------------------------------------------------
# F. KNOWN RESIDUE -- reported, not fixed here. Both are informational (note:, not check:) so this
#    file stays a contract for what 0242 actually closed.
#      * the bare `xschem unselect_all` VERB still orphans: it arms nothing, so the ratified
#        "whatever you just pressed is what you meant" rule has no subject, and gating it would
#        put a delete() behind 817 scripted call sites -- the same objection that keeps the
#        teardown out of unselect_all() itself (issue 0123). The C tripwire
#        check_placement_preview_invariant() reports it on stderr instead.
#      * `netlist` netlists the preview instance. It clears no gesture bits (sp and START_SYMPIN
#        both end at 0), so it is not a door and leaves no terminal state -- a different defect.
# ---------------------------------------------------------------------------
setup ; arm ; xschem unselect_all
note "residue: after `xschem unselect_all` sympin_preview=[sp] START_SYMPIN=[sympin_bit] orphans=[orphans] (issue 0262)"
esc3
setup ; arm ; xschem netlist
note "residue: after `xschem netlist` sympin_preview=[sp] orphans=[orphans] (issue 0263)"
esc3

puts ""
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else            { puts "RESULT: $fail FAILURE(S) of [expr {$npass+$fail}] checks" }
exit [expr {$fail ? 1 : 0}]
