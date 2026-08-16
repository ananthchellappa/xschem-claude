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
# ISSUE 0263 -- `netlist` (sections B14/B15 and G). Filed here originally as section F residue,
# on the belief that the netlist merely READS the preview. Measured 2026-08-09, that is only half
# of it, and the smaller half:
#   * READ half. The preview is a fully-formed lab_pin in xctx->inst[], so
#     name_nodes_of_pins_labels_and_propagate() (netlist.c) treats it as a real label and
#     name_attached_nets() stamps its name onto the whole net it touches. A cell that netlists as
#     `R1 net1 GND 1k` / `R2 net1 GND 2k` emits `R1 FOO GND 1k` / `R2 FOO GND 2k` -- a
#     plausible-looking WRONG netlist with no diagnostic, in every backend (tedax shows the same
#     substitution, which is what proves it is the shared pass and not spice_netlist.c).
#   * COMMIT half, which the original filing denies. global_spice_netlist() push_undo()s the
#     document WITH the preview, then unselect_all(1) zeroes ui_state wholesale, then pop_undo()'s
#     clear_drawing() clears sympin_preview / wirelabel_preview / preview_sel, and the final
#     pop_undo() restores the snapshot with the preview baked in as an ordinary instance. Measured
#     ui 16424 -> 0, sp 1 -> 0, and three ESCs later `lab_pin.sym {l1 FOO}` is still standing with
#     `modified` reading 0 throughout. So `netlist` IS a door, and a terminal one: the user cannot
#     take the object back and is never told it is there.
# So the gate belongs at the netlist VERB (leave_placement_for + leave_merge_for), not in the
# traversal -- preview_sel, the identity a traversal filter would key off, is destroyed by the
# driver's own clear_drawing() before the pass that needs it. `-nohier` (global=0) skips the whole
# push/pop block and is the pure READ half, so it carries its own rows.
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

## --- section F helpers (issue 0262): the REPAIR clears three fields, not one -----------------
## `sp` above answers for sympin_preview only. The ratified repair (issue 0262 decision D1,
## repair_orphan_placement_preview() in callback.c) also clears wirelabel_preview and the
## preview_sel identity stamp, and neither has a probe in the `get` chain today -- the same fix
## adds both beside "sympin_preview" (scheduler.c). `xschem get <unknown>` does NOT throw: it
## answers the empty string, which an equality check would happily read as "not 1". So this maps
## a missing probe to the literal PROBE-MISSING, and a row whose oracle the binary does not have
## fails LOUDLY on the missing oracle rather than passing or failing for a silent reason.
proc probe {key} {
  if {[catch {xschem get $key} v]} { return PROBE-MISSING }
  if {$v eq {}} { return PROBE-MISSING }
  return $v
}
proc psel {} { return [probe preview_sel_n] }
proc wlp  {} { return [probe wirelabel_preview] }
## "is the stamp set at all", so a row can assert >0 through the equality-only `check` above.
proc psel_set {} {
  set v [psel]
  if {![string is integer -strict $v]} { return $v }
  return [expr {$v > 0 ? 1 : 0}]
}
## Did the repair name itself on the status bar (the 0241 rule)? Takes the captured line rather
## than reading it live, because every `xschem` call is itself a repair opportunity.
proc repaired {m} { return [expr {[string match {*Pending placement abandoned*} $m] ? 1 : 0}] }
## Whole text of a written .sch, for the F12 persist row.
proc filetext {f} {
  if {![file exists $f]} { return {} }
  set fh [open $f r] ; set t [read $fh] ; close $fh
  return $t
}

## --- section G helpers (issue 0263): the emitted DECK is the oracle -------------------------
## Everything above asserts xctx state. 0263's primary damage is in the FILE the netlister
## writes, so section G reads it back. `deck` returns the whole text (empty when the netlister
## produced nothing), `devline` the one line whose first token is $dev.
proc deck {tag ext} {
  set out [file join $::scratch $tag.$ext]
  if {![file exists $out]} { return {} }
  set fh [open $out r] ; set t [read $fh] ; close $fh
  return $t
}
proc devline {tag ext dev} {
  foreach l [split [deck $tag $ext] \n] {
    set l [string trim $l]
    if {[lindex [split $l] 0] eq $dev} { return $l }
  }
  return {}
}
## "does this token appear anywhere in the deck" -- catches a rename that landed on some OTHER
## net or device than the one devline looks at.
proc indeck {tag ext tok} { return [expr {[string match *$tok* [deck $tag $ext]] ? 1 : 0}] }
proc msg  {} { return [xschem get statusmsg] }
proc hold {} { return [xschem get statusmsg_hold] }

## The G9 orphan oracle. `orphans` above matches the cell name EXACTLY against `lab_pin.sym`, which
## is what a placement preview reports -- but a MERGED lab_pin reports `devices/lab_pin` (the path
## form written in the merge source), so `orphans` silently counts it as zero. That blindness made
## the original G9 row's "no orphan" checks pass for the wrong reason. Everything in sections A-F
## places rather than merges its lab_pins, so `orphans` stays as it is; G9, which does both, counts
## with this one instead.
proc labpins {} {
  set n 0
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[string match *lab_pin* [xschem getprop instance $i cell::name]]} { incr n }
  }
  return $n
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
set scratch [test_scratch pvdoors]
set mergesrc [file join $scratch one_wire.sch]
set fh [open $mergesrc w]
puts $fh "v {xschem version=3.4.8RC file_version=1.3}"
puts $fh "G {}" ; puts $fh "K {}" ; puts $fh "V {}" ; puts $fh "S {}" ; puts $fh "E {}"
puts $fh "N 300 300 400 300 {lab=#net1}"
close $fh

## B14/B15 and section G run the REAL `netlist` verb, so the netlister needs somewhere to write.
## Point it at this test's scratch dir (hoisted above section B): without it the decks land in the
## developer's $netlist_dir, which is both a litter source and a way for one run to read another
## run's deck.
set ::netlist_dir $scratch

## The section G cell, one file per row so no row can read a stale deck: ONE unnamed net with TWO
## resistors on it plus two grounds. Two devices, not one, because 0263 renames the NET -- both
## R-lines must move together, which a single-device fixture cannot show. Netlists as
##   R1 net1 GND 1k / R2 net1 GND 2k
## with nothing armed, and the 4 instances / 1 wire are the "the fixture survived" oracle.
proc mkcell {tag} {
  set fx [file join $::scratch $tag.sch]
  set f [open $fx w]
  puts $f {v {xschem version=3.4.8RC file_version=1.3}}
  foreach k {G K V S F E} { puts $f "$k {}" }
  puts $f {N 0 0 300 0 {}}
  puts $f {C {devices/res} 100 30 0 0 {name=R1 value=1k}}
  puts $f {C {devices/res} 200 30 0 0 {name=R2 value=2k}}
  puts $f {C {devices/gnd} 100 60 0 0 {name=G1 lab=GND}}
  puts $f {C {devices/gnd} 200 60 0 0 {name=G2 lab=GND}}
  close $f
  return $fx
}
## Load a fresh copy of it: clean modify flag, nothing selected, status field parked on "-".
proc gload {tag} {
  esc3
  xschem load [mkcell $tag]
  xschem unselect_all
  xschem statusmsg "-"
}
## The merge source for the G8/G9 paste rows: a lab_pin named BAR sitting ON the fixture's net, so
## an undropped paste renames it exactly the way an undropped placement does.
set onelab [file join $scratch one_lab.sch]
set fh [open $onelab w]
puts $fh "v {xschem version=3.4.8RC file_version=1.3}"
puts $fh "G {}" ; puts $fh "K {}" ; puts $fh "V {}" ; puts $fh "S {}" ; puts $fh "E {}"
puts $fh "C {devices/lab_pin} 100 0 0 0 {name=lb lab=BAR}"
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

## B14 `netlist` -- issue 0263, and the door this file spent its first life calling a non-door (see
##    the old section F note, now deleted). global_*_netlist()'s unselect_all(1) drops the gesture
##    bits and its pop_undo() round trip restores a snapshot with the preview baked in, so pre-fix
##    the ESC below has nothing left to abort and the lab_pin is a permanent, committed instance.
##    `catch` because the verb returns the netlister's error code, not because it may throw.
door_case "B14 netlist" { catch {xschem netlist} }

## B15 The `-nohier` arm. global=0 takes a different route through the driver -- no push_undo, no
##    unselect_all, no pop_undo -- so it is the pure READ half of 0263 and needs its own row rather
##    than riding on B14's. Its STATE was already correct before the fix (the gesture survives and
##    ESC still takes the preview back); what was wrong is the DECK, which section G asserts. This
##    row is the no-regression pin saying that gating the verb did not break the arm already clean.
door_case "B15 netlist -nohier" { catch {xschem netlist -nohier} }

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
# F. THE BARE `unselect_all` DOOR, AND THE CLASS-WIDE ANSWER TO IT -- issue 0262, decided.
#
#    THIS SECTION USED TO BE A `note:`. It said the bare `xschem unselect_all` VERB still orphans,
#    that gating it would put a delete() behind ~817 scripted call sites (issue 0123's objection),
#    and that the C tripwire check_placement_preview_invariant() "reports it on stderr instead".
#    Two of those three sentences survive the decision; the third does not.
#
#    WHAT CHANGED. The tripwire's report-only form rested on 0262's own premise that the door is
#    "not reachable from the GUI: no key, menu item or toolbar button issues the bare verb while a
#    preview is live". Measured FALSE (issue 0397) on two routes:
#      * the DEFAULT chord Ctrl+Button2 -- `button,2,ctrl,canvas,edit.cycle_pin_type`
#        (mousebindings.csv) -> addpin::cycle_type (xschem.tcl), whose re-arm guard tests
#        `[winfo exists .addpin]`. A live Add-Wire-Label preview belongs to `.addlabel`, so the
#        guard is false and the fallback branch runs the bare verb. Row F9.
#      * Hilight > "Compare schematics", whose entire -command body is
#        `xschem unselect_all ; xschem redraw` (xschem.tcl). Row F10.
#    And the resulting state is TERMINAL: sympin_preview stuck at 1 kills the Button-1 select/grab
#    block and wire_label_try_commit() (see the header), ESC cannot repair it because
#    abort_placement_preview() is gated on the bit that is gone, and the only in-session recovery
#    measured is `clear`/`load`/`new` -- i.e. discarding the document. Nor is the bare verb the last
#    door: `save`/`saveas`/Ctrl+S reaches the same desync through save_schematic()'s own
#    unselect_all(1), and PERSISTS the undropped object into the .sch (issue 0358). Rows F11/F12.
#
#    THE RATIFIED DECISION (issue 0262 D1-D10). Do NOT gate the verb -- it arms nothing, so the
#    "whatever you just pressed is what you meant" rule has no subject, and 0123's objection to a
#    delete() behind 866 scripted / 82 C call sites (re-measured 2026-08-11) stands unchanged.
#    Instead check_placement_preview_invariant() becomes the permanent, CLASS-WIDE answer in a
#    REPAIRING form: at its two existing sitings -- callback() entry and xschem() entry BEFORE
#    dispatch -- a detected desync now calls repair_orphan_placement_preview(), which clears
#    sympin_preview, wirelabel_preview and the preview_sel stamp, posts one held status line, and
#    DELETES NOTHING. Every door in the class, named or not yet found, goes from TERMINAL to
#    ORPHAN-ONLY at one site.
#
#    WHAT THIS SECTION THEREFORE PINS, and just as importantly what it does not:
#      * the canvas comes back (F1, F2) -- by clearing the FLAG, never by re-arming the bit;
#      * the two other fields come back too, and both are load-bearing, not hygiene: a surviving
#        stamp (F4) points at what is now a REAL document object, so a later unrelated abort can
#        delete the user's work; a surviving wirelabel_preview (F5) makes end_place_move_copy_zoom()
#        route the NEXT symbol drop into wire_label_try_commit(), which refuses while the branch
#        still claims the click;
#      * the repair names itself once (F6), because a repair the user cannot see is
#        indistinguishable from the bug (the 0241 rule);
#      * the ORPHAN AND THE RENAMED NET STAY (F3, F7, F8, F12). That is the knowingly-kept residue
#        of decision D3, written here as a contract so nobody "improves" it into a deferred
#        delete() by accident. It is also why 0358 stays open: a repair is retroactive and cannot
#        un-write a file (decision D9 rule B -- a door that COMMITS or PERSISTS still needs its own
#        verb gate, the shape `netlist` got in 0263);
#      * the construction seam still opens the raw door (F13) and closes again (F14);
#      * and the repair never fires on a healthy session (F15, F16), which is what makes it safe to
#        put behind all 866 call sites: its precondition is itself already a defect.
# ---------------------------------------------------------------------------

## F1-F8 THE BARE VERB. One episode, read in one pass: `msg`/`hold` are captured FIRST because the
##       repair runs at the next xschem() entry whatever that entry happens to be, and every probe
##       below is itself an xschem() entry.
setup ; arm
xschem statusmsg "-"
xschem unselect_all
set fmsg [msg] ; set fhold [hold]
check "F1 bare verb: preview flag repaired"      [sp] 0
check "F2 bare verb: START_SYMPIN still down"    [sympin_bit] 0
check "F2 bare verb: invariant restored"         [desync] 0
check "F3 bare verb: orphan KEPT (D3 residue)"   [orphans] 1
check "F4 bare verb: stamp died with preview"    [psel] 0
check "F5 bare verb: label flag cleared"         [wlp] 0
check "F6 bare verb: repair names itself"        [repaired $fmsg] 1
check "F6 bare verb: repair line is held"        $fhold 1
check "F7 bare verb: modify flag untouched"      [xschem get modified] 1
check "F8 bare verb: net still renamed (D3)"     [renamed_net] FOO
esc3

## F9 GUI ROUTE 1 (issue 0397): the DEFAULT Ctrl+Button2 chord. Reproducible true-headless because
##    the guard it fails is `[info commands winfo] ne {} && [winfo exists .addpin]`, and under
##    --nogui `winfo` does not exist at all -- so the same fallback branch runs, for a reason a
##    real X session reaches by having `.addlabel` open instead of `.addpin`. The existence check
##    is what stops this row quietly measuring nothing if the proc is ever renamed.
setup ; arm
check "F9 route exists: addpin::cycle_type"      [llength [info commands ::addpin::cycle_type]] 1
catch {addpin::cycle_type}
check "F9 Ctrl+MMB: preview flag repaired"       [sp] 0
check "F9 Ctrl+MMB: invariant restored"          [desync] 0
check "F9 Ctrl+MMB: orphan KEPT (D3 residue)"    [orphans] 1
esc3

## F10 GUI ROUTE 2 (issue 0397): the Hilight > Compare schematics checkbutton, whose -command body
##     is reproduced verbatim. `redraw` touches no state, so this row is the bare verb reached by a
##     menu -- which is exactly the point: it is a MENU ITEM, and 0262 said none existed.
setup ; arm
eval {xschem unselect_all ; xschem redraw}
check "F10 Compare menu: preview flag repaired"  [sp] 0
check "F10 Compare menu: invariant restored"     [desync] 0
esc3

## F11/F12 THE SAVE DOOR (issue 0358) -- the half this decision covers, and the half it does not.
##     save_schematic()'s own unselect_all(1) sits one line before write_xschem_file(), so the
##     canvas dies exactly as above (F11, covered by the repair) AND the object the user never
##     dropped is written into the file with the wire's net renamed after it, while `modified` goes
##     to 0 and the user is told the buffer is clean (F12, NOT covered -- the repair is retroactive
##     and cannot un-write a file). F12 asserts the residue as a CONTRACT, not a wish: it is what
##     keeps 0358 open and pointed at a verb gate of the 0263 shape.
setup ; arm
set f11 [file join $::scratch f11.sch]
file delete -force $f11
catch {xschem saveas $f11}
check "F11 saveas: preview flag repaired"        [sp] 0
check "F11 saveas: invariant restored"           [desync] 0
check "F12 saveas: orphan PERSISTED (0358)"      [expr {[string match *lab_pin* [filetext $f11]] ? 1 : 0}] 1
esc3

## F13/F14 THE CONSTRUCTION SEAM. gate_bypass is the ratified test-only seam (issue 0247) that the
##     other gates already honour, and G9 below depends on being able to BUILD a desync. The repair
##     must honour it too -- and must resume the moment the seam closes, so a suite cannot leave a
##     permanent opt-out behind it.
setup ; arm
xschem test_gate_bypass 1
xschem unselect_all
check "F13 bypass: raw door still opens"         [sp] 1
xschem test_gate_bypass 0
check "F14 bypass closed: repair resumes"        [sp] 0
check "F14 bypass closed: invariant restored"    [desync] 0
esc3

## F15 NO FALSE POSITIVE, MID-ARM -- the landmine. The modeless form re-issues `-place` on every
##     keystroke and raises sympin_preview WITH START_SYMPIN, so the invariant holds throughout and
##     the repair must stay asleep. A detection condition widened to fire on a healthy live preview
##     (dropping the `!(ui_state & START_SYMPIN)` half) reddens this row and section C with it.
setup
set ::label_new_name F
xschem add_wire_label -place
foreach ch {FO FOO FOOB FOOBA FOOBAR} { set ::label_new_name $ch ; xschem add_wire_label -place }
xschem statusmsg "-"
set fmsg2 [msg]
check "F15 mid-arm: preview still live"          [sp] 1
check "F15 mid-arm: stamp still set"             [psel_set] 1
check "F15 mid-arm: exactly one preview"         [orphans] 1
check "F15 mid-arm: repair stayed asleep"        [repaired $fmsg2] 0
esc3

## F16 NO FALSE POSITIVE, IDLE. The bare verb with nothing armed -- i.e. what all 866 scripted call
##     sites and 82 C call sites actually do, `unselect_all` as a housekeeping PREFIX to a fresh
##     selection. Nothing to repair, nothing said.
setup
xschem statusmsg "-"
xschem unselect_all
set fmsg3 [msg]
check "F16 idle: no preview flag"                [sp] 0
check "F16 idle: no stamp"                       [psel] 0
check "F16 idle: repair stayed silent"           [repaired $fmsg3] 0
esc3

## F17 note: `xschem net_label 0` (place_net_label, actions.c) sets START_SYMPIN with NO
##     sympin_preview, so that preview class sits OUTSIDE the repair's detection condition by
##     design -- decision D5 declined to widen it, because the wider surface has never been
##     measured for false positives and a false positive now costs state rather than a log line.
##     Recorded so this file stays honest about what is NOT covered.
note "not covered: place_net_label's START_SYMPIN-without-sympin_preview class (issue 0262 D5)"

## F18 note: every row above enters through xschem(). The repair's OTHER siting, at callback()
##     entry, needs a window and so is not exercised here -- it is covered by inspection and by
##     issue 0397's xvfb transcript.
note "not covered: the callback() siting of the repair (needs X; see issue 0397)"

## F19 note: POST-FIX HAZARD found while writing this section, for whoever implements the repair.
##     preview_sel is ONE slot shared by the placement and the merge stamps (select.c,
##     paste.c), and clear_placement_preview() zeroes preview_sel_n WHOLESALE. G9b below
##     deliberately builds `arm placement, then merge` -- which leaves sympin_preview stuck at 1
##     (the 0262 desync itself) while the MERGE owns the stamp. A repair that clears the stamp
##     unconditionally at the next entry would destroy the merge's identity and redden G9b's
##     "after netlist: merge gone" row. The stamp clear needs to be conditional on no other
##     gesture owning the slot.
note "hazard: repair's clear_placement_preview() vs the merge stamp co-armed in G9b (see comment)"

# ---------------------------------------------------------------------------
# G. THE DECK ITSELF -- issue 0263. Sections A-F assert xctx state; a state-only suite cannot see
#    0263's headline damage, which is a WRONG NETLIST FILE with no error anywhere. Every row here
#    loads a fresh copy of the fixture, so no row can inherit another's document or read another's
#    deck.
#
#    THE FIXTURE, netlisted with nothing armed:  R1 net1 GND 1k  /  R2 net1 GND 2k
#    Pre-fix, with a `FOO` label preview riding the cursor:  R1 FOO GND 1k  /  R2 FOO GND 2k
#    -- BOTH devices move, because what the undropped label renames is the NET.
# ---------------------------------------------------------------------------
xschem set netlist_type spice

## G0 CONTROL. Nothing armed: the fixture's own deck. If this row ever moves, every row below is
##    measuring the fixture rather than the gate.
gload g0
xschem netlist
check "G0 control deck: R1 line"          [devline g0 spice R1] {R1 net1 GND 1k}
check "G0 control deck: R2 line"          [devline g0 spice R2] {R2 net1 GND 2k}
check "G0 control: fixture instances"     [xschem get instances] 4
check "G0 control: fixture wires"         [xschem get wires] 1

## G1 THE PRIMARY ROW. A live placement preview must not reach the netlister.
gload g1 ; arm
xschem netlist
check "G1 armed netlist: R1 line"         [devline g1 spice R1] {R1 net1 GND 1k}
check "G1 armed netlist: R2 line"         [devline g1 spice R2] {R2 net1 GND 2k}
check "G1b armed netlist: no FOO in deck" [indeck g1 spice FOO] 0

## G2 The `-nohier` arm emits the top level through the same shared naming pass, so it is wrong in
##    exactly the same way while reaching it by a different route. Own arm, own assertion.
gload g2 ; arm
xschem netlist -nohier
check "G2 -nohier: R1 line"               [devline g2 spice R1] {R1 net1 GND 1k}
check "G2 -nohier: R2 line"               [devline g2 spice R2] {R2 net1 GND 2k}
check "G2b -nohier: no FOO in deck"       [indeck g2 spice FOO] 0

## G3 BACKEND INDEPENDENCE. The rename happens in netlist.c's shared
##    name_nodes_of_pins_labels_and_propagate(), not in spice_netlist.c, so a fix that only made
##    the SPICE deck right would be the wrong fix. tedax is the cheapest second backend to read.
xschem set netlist_type tedax
gload g3 ; arm
xschem netlist
check "G3 tedax: conn line for R1"        [indeck g3 tdx {conn net1 R1 1}] 1
check "G3 tedax: no FOO conn"             [indeck g3 tdx {conn FOO}] 0
xschem set netlist_type spice

## G4 STATE AFTER the netlist and BEFORE any ESC -- the commit half. The gesture must have been
##    ABANDONED, not accepted: no lab_pin anywhere, and the fixture's own 4 instances only.
gload g4 ; arm
xschem netlist
check "G4 after netlist: sympin cleared"  [sp] 0
check "G4 after netlist: invariant holds" [desync] 0
check "G4 after netlist: no orphan"       [orphans] 0
check "G4 after netlist: instances"       [xschem get instances] 4

## G5 ...and ESC afterwards has nothing to roll back and destroys nothing.
esc3
check "G5 netlist+ESC: instances"         [xschem get instances] 4
check "G5 netlist+ESC: wires"             [xschem get wires] 1
check "G5 netlist+ESC: no orphan"         [orphans] 0

## G6 THE TEARDOWN NAMES ITSELF (the 0241 rule). The 5000 ms hold is what keeps this line on the
##    status bar: the netlister's own select-info lines land one call later and would otherwise
##    take the field with the user none the wiser.
gload g6 ; arm
xschem netlist
check "G6 gate names itself"              [msg] {Netlist: pending placement abandoned}
check "G6 gate message is held"           [hold] 1

## G7 MODIFY CONTRACT (0244/0267/0270): abandoning a gesture must not touch the flag in either
##    direction. Both rows were ALREADY GREEN before the fix -- the netlist's pop_undo round trip
##    happens to restore the flag it found -- so they prove nothing about 0263 and are kept purely
##    as the regression pin that the new teardown does not start lying.
gload g7 ; arm
check "G7 clean buffer before netlist"    [xschem get modified] 0
xschem netlist
check "G7 clean buffer: still clean"      [xschem get modified] 0
esc3
gload g7b
xschem wire 0 500 100 500 ; xschem unselect_all
arm
check "G7b dirty buffer before netlist"   [xschem get modified] 1
xschem netlist
check "G7b dirty buffer: still dirty"     [xschem get modified] 1
esc3

## G8 THE MERGE TWIN (issue 0265's rule at the same verb). A pending paste is ALWAYS selected, so
##    the driver's unselect_all(1) silently ACCEPTS it exactly as it accepts a placement -- and the
##    merged lab_pin renames the net on the way out.
gload g8
xschem merge $::onelab
check "G8 merge armed: STARTMERGE"        [expr {([xschem get ui_state] & 256) ? 1 : 0}] 1
xschem netlist
check "G8 after netlist: instances"       [xschem get instances] 4
check "G8b merge deck: R1 line"           [devline g8 spice R1] {R1 net1 GND 1k}
check "G8b merge deck: no BAR in deck"    [indeck g8 spice BAR] 0
esc3
check "G8 netlist+ESC: instances"         [xschem get instances] 4
check "G8 netlist+ESC: wires"             [xschem get wires] 1

## G9 THE CO-ARMED ORDERS. preview_sel is ONE slot shared by the placement and the merge, so a
##    caller holding both must tear the PLACEMENT down first -- its stamp is a superset of the
##    merge's (see merge_file(), paste.c). gate_bypass is the only way to build a co-armed state at
##    all: it is exactly what the arms' own gates otherwise prevent.
##
##    THIS ROW'S ORIGINAL PREMISE WAS WRONG AND IS CORRECTED HERE (measured 2026-08-09, post-fix).
##    It asserted that both orders end at the fixture's own 4 instances, i.e. that the netlist
##    reclaims BOTH objects. Neither order ever holds two LIVE gestures, so neither can: both
##    `add_wire_label -place` and merge_file() run their own unselect_all(1), which zeroes ui_state
##    wholesale (select.c), so the SECOND arm always strips the FIRST one's bit while leaving its
##    object in the drawing. That stranded object is the pre-existing 0262 orphan -- by then an
##    ordinary committed instance with no gesture bit and no stamp -- and leave_placement_for() /
##    leave_merge_for() early-return on it BY DESIGN (issue 0263 decision D10: 0262 is a separate,
##    filed defect and this fix deliberately does not reach into it). Measured, both orders:
##      merge then placement -> ui 16424, STARTMERGE already gone, the merged BAR stranded
##      placement then merge -> ui 296, START_SYMPIN already gone, the placed FOO stranded
##    The four placement arms whose stamp really IS a superset (ctx-menu text, `t`, the screen grab,
##    place_net_label's failed-place_symbol path) all need `xschem callback` and a window, so the
##    ordering rule itself stays code-proved, not asserted here.
##
##    What each order DOES prove, and why both are kept: they exercise the two gates SEPARATELY.
##    G9a's live gesture is the placement, so only leave_placement_for() can clear it; G9b's is the
##    merge, so only leave_merge_for() can. Either gate going missing reddens exactly one of them.

## G9a MERGE, THEN PLACEMENT -- the placement is the live one.
gload g9a
xschem test_gate_bypass 1
xschem merge $::onelab
arm
xschem test_gate_bypass 0
check "G9a co-armed: instances"           [xschem get instances] 6
check "G9a co-armed: lab_pins"            [labpins] 2
check "G9a live gesture is the placement" [expr {([xschem get ui_state] & 16384) ? 1 : 0}] 1
check "G9a the merge bit is already gone" [expr {([xschem get ui_state] & 256) ? 1 : 0}] 0
xschem netlist
check "G9a after netlist: placement gone" [xschem get instances] 5
check "G9a after netlist: lab_pins"       [labpins] 1
check "G9a after netlist: sympin cleared" [sp] 0
check "G9a deck: no FOO"                  [indeck g9a spice FOO] 0
note "residue: the 0262-stranded merge is a committed instance by now, so the deck correctly carries it -- R1 line is [devline g9a spice R1] (issue 0262, not 0263)"
esc3
check "G9a netlist+ESC: instances"        [xschem get instances] 5
check "G9a netlist+ESC: wires"            [xschem get wires] 1

## G9b PLACEMENT, THEN MERGE -- the merge is the live one, and sympin_preview is stuck at 1 with
##     START_SYMPIN gone, which is the 0262 desync itself. The netlist must still take the paste.
gload g9b
xschem test_gate_bypass 1
arm
xschem merge $::onelab
xschem test_gate_bypass 0
check "G9b co-armed: instances"           [xschem get instances] 6
check "G9b co-armed: lab_pins"            [labpins] 2
check "G9b live gesture is the merge"     [expr {([xschem get ui_state] & 256) ? 1 : 0}] 1
check "G9b the sympin bit is already gone" [sympin_bit] 0
xschem netlist
check "G9b after netlist: merge gone"     [xschem get instances] 5
check "G9b after netlist: lab_pins"       [labpins] 1
check "G9b deck: no BAR"                  [indeck g9b spice BAR] 0
note "residue: the 0262-stranded placement is committed by now -- R1 line is [devline g9b spice R1] (issue 0262, not 0263)"
esc3
check "G9b netlist+ESC: instances"        [xschem get instances] 5
check "G9b netlist+ESC: wires"            [xschem get wires] 1

## G10 SILENCE WHEN IDLE / the replay seam. With nothing armed the gate must be a total no-op --
##     this is the contract that keeps tests/headless/gold/*.spice byte-identical and keeps the
##     `-keep_symbols` cellview/reroute calls in xschem.tcl from announcing themselves. ALREADY
##     GREEN before the fix (there is no gate to be silent yet); it is a regression pin only.
gload g10
xschem netlist
check "G10 idle netlist: status untouched" [msg] {-}
check "G10 idle netlist: no hold armed"    [hold] 0
esc3

puts ""
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else            { puts "RESULT: $fail FAILURE(S) of [expr {$npass+$fail}] checks" }
exit [expr {$fail ? 1 : 0}]
