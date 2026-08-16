## tests/headless/test_paste_modify_flag_0244.tcl
##
## RED-first regression: ESC-ing a pending paste/merge must not LIE about the modify flag, and
## must not delete more than the merge brought in. Issue 0244 (part A: the flag) and the merge
## half of issue 0241 (part B: the scope of the teardown's delete).
##
## PART A -- THE FLAG
##   abort_operation()'s two STARTMERGE arms (callback.c) called set_modify(0) FLAT, with the
##   comment "aborted merge: no change, so reset modify flag set by delete()". True only if the
##   document was CLEAN before the paste. delete() does set the flag (select.c), but the PRE-MERGE
##   value need not be 0, so a document with real unsaved edits came back from a cancelled Ctrl+V
##   reporting itself unmodified.
##   That is data loss, not cosmetics: hierarchy_modified() then answers 0, which kills the
##   Close/Quit prompts (scheduler.c), save()'s `if(force || xctx->modified)` gate (actions.c) and
##   go_back()'s ascend prompt -- and clear_schematic() (File > New) runs
##   `if(cancel == 1) cancel = save(1, 0);` followed by remove_backup(), so the `~` autosave file
##   that held the only copy of the work is deleted with no prompt ever shown.
##   THE FIX under test: xctx->pre_merge_modified, latched in merge_file() (paste.c) before the
##   first mutation, and both arms now do `if(!xctx->pre_merge_modified) set_modify(0);`.
##   The obvious save/restore idiom (the one the PLACEMENT arm uses) is WRONG here and section A5
##   is its witness: merge_file() ends with an unconditional set_modify(1), so a `save = modified`
##   read taken at abort time always sees 1 and would leave a CLEAN document dirty after every
##   Ctrl+V/ESC. A2/B2 are the controls that catch that.
##
## PART B -- THE SCOPE
##   Those same arms called a bare `delete(1)` on WHATEVER IS SELECTED. The "selection == the
##   merged objects" invariant is established by merge_file() and nothing defends it afterwards,
##   so one Ctrl+A between the paste and the ESC turned the cancel into a whole-document delete
##   (measured at 7da044ff: 2 wires -> 0, reported modified=0). Issue 0241 fixed the PLACEMENT
##   sibling of this with an identity stamp; part B reuses it: merge_file() stamps the merged
##   selection and the arms re-select exactly that stamp before deleting.
##
## ISSUE 0265 / 0267 (section E, added 2026-08-08)
##   Those same arms were the ONLY teardown a pending merge had. Nothing bounded its lifetime, so a
##   second Ctrl+V -- or any placement arm, or any wire/line draw -- silently COMMITTED the pending
##   paste instead of cancelling it. Section E covers the gate that fixes it
##   (abort_pending_merge() + leave_merge_for(), callback.c) at every arm, in both directions, with
##   its controls; E4 is issue 0267, the stale pre_merge_modified latch, which did NOT fall out of
##   the gate (the pure-commit forms stay ungated) and needed xctx->modify_seq of its own.
##
## ISSUE 0266 (section F, added 2026-08-12)
##   `xschem move_objects END` -- an uppercase sub-verb -- does not commit the pending merge and
##   does not error either: it falls past the four lowercase strcmp()s into the one-shot coordinate
##   else and ARMS a deferred menu move (ui_state 296 -> 65832), so the following ESC deletes the
##   paste that the caller thought it had just committed. Section F covers the argument-shape
##   validation that fixes it, plus the same atof()-eats-a-non-number defect in the DELTA slots.
##
## SECTIONS: A the four control rows x both doors (`xschem merge <file>` and clipboard
## `xschem paste`) · B hierarchy_modified, the flag the prompts actually read · C the SECOND
## STARTMERGE arm (the one reached with STARTMOVE already cleared) · D1-D8 part B, ending with D8,
## the fluid-rollback door that the adversarial review of the fix found and that D7 does not cover ·
## E1-E6 issue 0265: a second gesture ABANDONS the pending paste (E1 merge-over-merge, E2 the twelve
## placement arms, E3 the reverse as a control, E4 issue 0267, E5 the wire/line draws, E6 the five
## things that must NOT move) · F1-F29 issue 0266: the move_objects dispatch slot (F1-F17 the
## rejections, F18-F29 the positive controls that keep the fix from becoming an over-gate).
##
## NOT HOLLOW (WIRING.md §10): the fixture holds one object of every type the merge carries -- 2
## wires, 1 instance, 1 text, 1 line -- and the merged file carries one of each too, so "wires == 2
## after the cancel" can only pass if the survivors really survived AND the merged ones really
## went. rects/lines/polygons/arcs have no `xschem get` counter, so their survival is proved by
## counting saved object records. Section A2 is the control that legitimately ends at modified=0:
## without it a stray set_modify(1) anywhere would pass the whole of part A.
##
## Pure headless -- no `xschem callback`, so it runs true-headless. From the repo ROOT:
##   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_paste_modify_flag_0244.tcl
## Prints "RESULT: ALL PASS" on success.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc note {msg} { puts "note: $msg" }

source [file join [file dirname [info script]] scratch.tcl]
set ::d0244     [test_scratch p0244]
set ::src0244   [file join $::d0244 src.sch]
set ::clean0244 [file join $::d0244 clean.sch]

set ::autosave_backup 0

## ---------------------------------------------------------------------------
## Fixture
## ---------------------------------------------------------------------------

## STARTMERGE (xschem.h) -- "a paste/merge is pending".
proc merging {} { return [expr {([xschem get ui_state] & 256) ? 1 : 0}] }

proc inst_lab {i} { return [xschem getprop instance $i lab] }
proc labcount {lab} {
  set n 0
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[inst_lab $i] eq $lab} { incr n }
  }
  return $n
}
proc textcount {pat} {
  set n 0
  for {set i 0} {$i < [xschem get texts] } {incr i} {
    if {[xschem getprop text $i txt_ptr] eq $pat} { incr n }
  }
  return $n
}

## Object-record lines (N wire, C instance, T text, L line, B rect, P poly, A arc) of the CURRENT
## drawing -- the only headless way to prove line/rect/poly/arc survival. DESTRUCTIVE to the modify
## flag (it saves), so always call it AFTER reading `modified`.
proc rec0244 {} {
  set f [file join $::d0244 snap.sch]
  xschem saveas $f
  set fh [open $f r]; set data [read $fh]; close $fh
  set n 0
  foreach ln [split $data \n] { if {[regexp {^[NCTLBPA] } $ln]} { incr n } }
  return $n
}

## The document under edit: one object of every type the merge brings in, so every survivor check
## has a survivor of the merged object's own type. Left DIRTY (modified == 1), which is the state
## the bug is about.
proc mkdoc {} {
  xschem clear force
  xschem wire 0 0 100 0
  xschem wire 0 100 100 100
  xschem instance devices/lab_pin.sym 300 0 0 0 {name=p1 lab=SURVIVOR}
  xschem text 400 400 0 0 {SURVIVORTEXT} {} 0.4 0
  xschem line 0 200 100 200
  xschem unselect_all
}

## Same drawing, saved and reloaded, so modified == 0 like a freshly opened cell.
## TRAP: `xschem saveas` zeroes the flag, so a "clean" fixture must be built by save+load and the
## flag read AFTER the load, never after a saveas taken mid-measurement.
proc mkdoc_clean {} {
  mkdoc
  xschem saveas $::clean0244
  xschem load $::clean0244
}

## What gets pasted: one object of each type, all distinguishable from the survivors by name.
proc mksrc {} {
  xschem clear force
  xschem wire 500 500 600 500
  xschem instance devices/lab_pin.sym 700 500 0 0 {name=m1 lab=MERGED}
  xschem text 800 800 0 0 {MERGEDTEXT} {} 0.4 0
  xschem line 500 700 600 700
  xschem unselect_all
  xschem saveas $::src0244
}

## Load the same content into the clipboard, so the `xschem paste` form of every row pastes
## exactly what the `xschem merge <file>` form does. Both are merge_file(); the pair exists
## because Ctrl+V is the clipboard door and the bug report is about Ctrl+V.
##
## THE CLIPBOARD IS PROCESS-GLOBAL and NOT redirectable from a script: `xschem copy` / bare
## `xschem paste` use `clip_file`, a C snapshot of $USER_CONF_DIR/.clipboard.sch taken in
## Tcl_AppInit before this script runs, so no Tcl variable or `xschem set` can move it. Two
## consequences, both shared with the sibling tests that exercise this door
## (test_crossview_paste.tcl, test_paste_at_log.tcl):
##   - running this test OVERWRITES the developer's real ~/.xschem/.clipboard.sch. Unavoidable
##     without launching under a redirected $HOME, which is a runner change, not a test change;
##   - a CONCURRENT xschem session pressing Ctrl+C between our copy and our paste would swap the
##     file under us and redden ~40 checks with unrelated counts. Re-priming immediately before
##     each paste row (primed_doc below) narrows that window to a few milliseconds; it cannot
##     close it. Same idiom, same caveat, as test_paste_at_log.tcl's prime_clipboard_r1.
proc prime_clip {} {
  xschem load $::src0244
  xschem select_all
  xschem copy
}
## Fixture builders that re-prime the clipboard first when the row under test is the paste door.
proc primed_doc {form}       { if {$form eq "paste"} { prime_clip }; mkdoc }
proc primed_doc_clean {form} { if {$form eq "paste"} { prime_clip }; mkdoc_clean }

mksrc
prime_clip

mkdoc
set ::REC0244 [rec0244]
check "0244 fixture: 5 object records" $::REC0244 5
mkdoc
check "0244 fixture: 2 wires"          [xschem get wires]     2
check "0244 fixture: 1 instance"       [xschem get instances] 1
check "0244 fixture: 1 text"           [xschem get texts]     1
check "0244 fixture: dirty"            [xschem get modified]  1

# ---------------------------------------------------------------------------
# A. The modify flag across a cancelled paste -- the four control rows, in BOTH doors.
#    `merge` is the File>Merge door, bare `paste` is the Ctrl+V/clipboard door; both funnel
#    through merge_file(), and the pair is what proves the fix is at the funnel and not at a verb.
# ---------------------------------------------------------------------------
foreach {form armv} {
  merge {xschem merge $::src0244}
  paste {xschem paste}
} {
  # A1 -- THE BUG. A document with real unsaved edits, a paste, ESC. The wire is still there;
  #       before the fix only the flag was a lie.
  primed_doc $form
  check "0244 A1 $form: doc dirty before"   [xschem get modified] 1
  eval $armv
  check "0244 A1 $form: merge armed"        [merging] 1
  check "0244 A1 $form: merged wire in"     [xschem get wires] 3
  check "0244 A1 $form: arming kept dirty"  [xschem get modified] 1
  xschem abort_operation
  check "0244 A1 $form: FLAG SURVIVES ESC"  [xschem get modified] 1
  check "0244 A1 $form: not merging"        [merging] 0
  check "0244 A1 $form: survivors kept"     [xschem get wires] 2
  check "0244 A1 $form: merged wire gone"   [labcount MERGED] 0
  check "0244 A1 $form: records restored"   [rec0244] $::REC0244

  # A2 -- THE CONTROL that must stay 0. This is the ONLY case the old flat set_modify(0) was
  #       right about, and it is what makes A1 mean something: a fix that just wrote 1 everywhere
  #       (or the save/restore idiom the placement arm uses -- see the header) reddens exactly
  #       here, because merge_file() ends with an unconditional set_modify(1).
  primed_doc_clean $form
  check "0244 A2 $form: doc clean before"   [xschem get modified] 0
  eval $armv
  check "0244 A2 $form: arming dirties"     [xschem get modified] 1
  xschem abort_operation
  check "0244 A2 $form: back to clean"      [xschem get modified] 0
  check "0244 A2 $form: survivors kept"     [xschem get wires] 2

  # A3 -- ESC with nothing pending must not touch the flag either (it never did; this is the
  #       control that the fix is not "ESC now always keeps the flag").
  primed_doc $form
  xschem abort_operation
  check "0244 A3 $form: bare ESC keeps flag" [xschem get modified] 1

  # A4 -- committing the drop keeps the document dirty, obviously, but a latch that leaked into
  #       the commit path would show up here.
  #       TRAP: the commit verb is `xschem move_objects end <dx> <dy>` -- LOWERCASE, WITH deltas.
  #       scheduler.c compares argv[2] against "end", so `xschem move_objects END` matches nothing
  #       and falls into the one-shot form's `else`, which merely arms a DEFERRED menu move
  #       (ui_state |= MENUSTART) and commits NOTHING: measured ui 296 -> 65832, STARTMERGE still
  #       set, and the following ESC still deleted the paste. Issue 0244's session notes named
  #       `xschem move_objects END` as the commit constructor; it is not one.
  primed_doc $form
  eval $armv
  xschem move_objects end 0 0
  check "0244 A4 $form: commit dirty"       [xschem get modified] 1
  check "0244 A4 $form: merged wire stays"  [xschem get wires] 3
  check "0244 A4 $form: not merging"        [merging] 0
  xschem abort_operation
  check "0244 A4 $form: ESC after commit"   [xschem get modified] 1
  check "0244 A4 $form: commit survives ESC" [xschem get wires] 3

  # A5 -- the latch must be re-taken per merge, not once per session: a CLEAN document pasted
  #       into right after a DIRTY one was cancelled must still come back clean. A latch that is
  #       never refreshed (or a save/restore read taken at abort time) fails here.
  primed_doc $form
  eval $armv
  xschem abort_operation
  check "0244 A5 $form: dirty row kept flag" [xschem get modified] 1
  primed_doc_clean $form
  eval $armv
  xschem abort_operation
  check "0244 A5 $form: clean row still 0"   [xschem get modified] 0

  # A6 -- and the reverse order, so a latch stuck at 0 from the clean row cannot pass A1.
  primed_doc_clean $form
  eval $armv
  xschem abort_operation
  check "0244 A6 $form: clean row is 0"      [xschem get modified] 0
  primed_doc $form
  eval $armv
  xschem abort_operation
  check "0244 A6 $form: dirty row is 1"      [xschem get modified] 1
}

# ---------------------------------------------------------------------------
# B. hierarchy_modified -- the flag the prompts actually read. This is the consequence half of
#    the issue: `modified` is only a number, but hierarchy_modified() is what Close / Quit /
#    File>New / ascend gate on, and the whole cost of the bug is that it answered 0.
# ---------------------------------------------------------------------------
mkdoc
check "0244 B: hier_mod dirty before"  [xschem get hierarchy_modified] 1
xschem merge $::src0244
xschem abort_operation
check "0244 B: hier_mod survives ESC"  [xschem get hierarchy_modified] 1
mkdoc_clean
check "0244 B: hier_mod clean before"  [xschem get hierarchy_modified] 0
xschem merge $::src0244
xschem abort_operation
check "0244 B: hier_mod back to 0"     [xschem get hierarchy_modified] 0

# ---------------------------------------------------------------------------
# C. THE SECOND ARM. abort_operation() has TWO STARTMERGE blocks: one nested inside the STARTMOVE
#    arm (everything above hits that one, because merge_file() leaves STARTMOVE|STARTMERGE
#    together) and a bare one below it, reached only when STARTMOVE has already been cleared while
#    STARTMERGE is still pending. Issue 0244 called that arm "reachable by inspection" and expected
#    no headless constructor; there is one -- move_objects(ABORT) clears STARTMOVE and returns
#    WITHOUT clearing STARTMERGE (the clear lives in the END tail, past that return), and the
#    `xschem move_objects abort` verb reaches it directly. Measured: ui 296 -> 264
#    (STARTMERGE|SELECTION, no STARTMOVE). In the GUI the same state is a click-without-drag
#    release on a pending paste.
#    Both defects live on this arm too, so it gets the same rows -- otherwise a fix applied to one
#    arm only would pass the whole of A and D.
# ---------------------------------------------------------------------------
mkdoc
xschem merge $::src0244
xschem move_objects abort
check "0244 C: bare arm reached"        [expr {[xschem get ui_state] == 264}] 1
xschem abort_operation
check "0244 C: dirty flag survives"     [xschem get modified] 1
check "0244 C: survivors kept"          [xschem get wires] 2
check "0244 C: paste removed"           [labcount MERGED] 0

mkdoc_clean
xschem merge $::src0244
xschem move_objects abort
xschem abort_operation
check "0244 C control: clean stays 0"   [xschem get modified] 0
check "0244 C control: survivors kept"  [xschem get wires] 2

mkdoc
xschem merge $::src0244
xschem move_objects abort
xschem select_all
xschem abort_operation
check "0244 C scope: wires survive"     [xschem get wires] 2
check "0244 C scope: instance survives" [labcount SURVIVOR] 1
check "0244 C scope: text survives"     [textcount SURVIVORTEXT] 1
check "0244 C scope: paste removed"     [labcount MERGED] 0
check "0244 C scope: flag dirty"        [xschem get modified] 1
check "0244 C scope: records restored"  [rec0244] $::REC0244

# ---------------------------------------------------------------------------
# D. PART B -- the teardown deletes the PASTE, not "whatever is selected".
#    The arms' delete(1) is selection-scoped, and between the paste and the ESC the user can
#    reach Ctrl+A / Edit>Select all / select_dangling_nets, none of which inspects ui_state.
#    Measured at 7da044ff: 2 wires + 1 inst + 1 text + 1 line, paste, Ctrl+A, ESC -> wires 0.
# ---------------------------------------------------------------------------
foreach {form armv} {
  merge {xschem merge $::src0244}
  paste {xschem paste}
} {
  # D1 -- the whole-document wipe. Every survivor type is asserted, and `records restored` is what
  #       covers the line (no `xschem get lines` exists).
  primed_doc $form
  eval $armv
  check "0244 D1 $form: merged in"          [xschem get wires] 3
  xschem select_all
  check "0244 D1 $form: selection grown"    [expr {[xschem get lastsel] > 1}] 1
  xschem abort_operation
  check "0244 D1 $form: wires survive"      [xschem get wires] 2
  check "0244 D1 $form: instance survives"  [labcount SURVIVOR] 1
  check "0244 D1 $form: text survives"      [textcount SURVIVORTEXT] 1
  check "0244 D1 $form: flag still dirty"   [xschem get modified] 1
  check "0244 D1 $form: records restored"   [rec0244] $::REC0244

  # D2 -- the UNDER-delete control. D1 alone is satisfied by a teardown that deletes NOTHING, and
  #       "leave the paste behind" is its own data-corruption bug (a connected, netlist-visible
  #       instance the user never dropped). So assert the merged objects of every type really went.
  primed_doc $form
  eval $armv
  xschem select_all
  xschem abort_operation
  check "0244 D2 $form: merged inst gone"   [labcount MERGED] 0
  check "0244 D2 $form: merged text gone"   [textcount MERGEDTEXT] 0
  check "0244 D2 $form: merged wire gone"   [xschem get wires] 2
  check "0244 D2 $form: nothing selected"   [xschem get lastsel] 0
  check "0244 D2 $form: merged line gone"   [rec0244] $::REC0244

  # D3 -- select_dangling_nets is the second grower, so the fix cannot be a select_all veto
  #       (the same argument as section H2 of test_add_wire_label.tcl).
  primed_doc $form
  eval $armv
  xschem select_dangling_nets
  xschem abort_operation
  check "0244 D3 $form: dangling wires kept"  [xschem get wires] 2
  check "0244 D3 $form: dangling inst kept"   [labcount SURVIVOR] 1
  check "0244 D3 $form: dangling paste gone"  [labcount MERGED] 0
  check "0244 D3 $form: dangling flag dirty"  [xschem get modified] 1
}

# D4 -- PARTIAL selections (WIRING.md §7 landmine 17), and an HONEST note about what this row can
#      and cannot catch. rebuild_selected_array() admits any non-zero `sel`, but delete() removes
#      only `sel == SELECTED` exactly: a stretch box-select marks a wire SELECTED1/SELECTED2 (one
#      ENDPOINT grabbed) and delete() is a provable no-op on it. On the PLACEMENT door that is a
#      live hazard -- three arms keep the user's pre-existing selection, so an unfiltered stamp
#      promotes partials and the "narrowing" deletes objects the unnarrowed code left standing
#      (the HIGH defect the 0241 review found, pinned by section H7 of test_add_wire_label.tcl).
#      On the MERGE door it CANNOT bite through the stamp: merge_file() runs unselect_all(1)
#      before loading, so at the moment stamp_placement_preview() is called every selected object
#      is a merged one and is fully SELECTED -- there is no partial for an unfiltered stamp to
#      promote. Removing stamp_placement_preview()'s sel-value filter therefore does NOT redden
#      this row, and no merge-door row can be built that it would redden.
#      What this row does pin is the other half: partials created AFTER the arm (the user boxing
#      an endpoint while the paste rides the cursor) must survive the cancel, i.e. the narrowing
#      must not widen the delete onto them. It is green pre-fix and post-fix by design -- it is a
#      guard, not a bug witness -- and its control below is what keeps it from being vacuous.
set saved_stretch [xschem get enable_stretch]
xschem set enable_stretch 1
mkdoc
xschem merge $::src0244
xschem select_inside -10 -10 10 110          ;# one endpoint of each survivor wire -> 2 PARTIALs
check "0244 D4 partial: grabbed"           [expr {[xschem get lastsel] >= 2}] 1
xschem abort_operation
check "0244 D4 partial: wires survive"     [xschem get wires] 2
check "0244 D4 partial: paste gone"        [labcount MERGED] 0
check "0244 D4 partial: flag dirty"        [xschem get modified] 1
# CONTROL, and the premise of the row: an ordinary delete() on that selection really is a no-op.
# Without it the survival above would prove nothing.
mkdoc
xschem select_inside -10 -10 10 110
xschem delete
check "0244 D4 control: plain delete no-op" [xschem get wires] 2
xschem set enable_stretch $saved_stretch

# D5 -- a paste that is COMMITTED and only then Ctrl+A'd + ESC'd must delete nothing: the stamp
#      must die at the commit, or a later, unrelated ESC would delete the objects it named.
#      (The move_objects(END) tail, move.c, is where STARTMERGE is cleared. See the A4 trap for
#      why the verb must be `move_objects end 0 0` and not `move_objects END`.)
mkdoc
xschem merge $::src0244
xschem move_objects end 0 0
check "0244 D5: committed"                 [merging] 0
xschem select_all
xschem abort_operation
check "0244 D5: nothing deleted"           [xschem get wires] 3
check "0244 D5: paste still there"         [labcount MERGED] 1
check "0244 D5: survivors still there"     [labcount SURVIVOR] 1

# D6 -- an EMPTY paste arms nothing (merge_file() clears STARTMERGE again when lastsel == 0), so a
#      following Ctrl+A + ESC must likewise delete nothing. This is the paste.c early-clear path,
#      the one place a stamp could be left set with the bit already gone.
set ::empty0244 [file join $::d0244 empty.sch]
xschem clear force
xschem saveas $::empty0244
mkdoc
xschem merge $::empty0244
check "0244 D6: empty merge not armed"     [merging] 0
xschem select_all
xschem abort_operation
check "0244 D6: nothing deleted"           [xschem get wires] 2
check "0244 D6: instance survives"         [labcount SURVIVOR] 1

# D7 -- the stamp must survive the DRAG. A pending paste is a live move gesture: every motion
#      event runs move_objects(RUBBER), and under fluid editing a RUBBER step can go through
#      fluid_reroute_restore() -> mem_restore_slot() -> clear_drawing(), which calls
#      clear_placement_preview() while the save/restore bracket puts ui_state (STARTMERGE
#      included) back verbatim. If that reached the merge stamp, the cancel after a drag would
#      resolve 0 objects and silently LEAVE the paste in the drawing -- the backstop turning into
#      an orphan. Drive the drag headlessly with `move_objects step` (== one RUBBER) and assert
#      the cancel still knows what to remove.
mkdoc
xschem merge $::src0244
xschem move_objects step 150 150
xschem move_objects step 220 260
check "0244 D7: still merging after drag" [merging] 1
xschem select_all
xschem abort_operation
check "0244 D7: paste removed after drag"  [labcount MERGED] 0
check "0244 D7: merged text removed"       [textcount MERGEDTEXT] 0
check "0244 D7: survivors kept"            [xschem get wires] 2
check "0244 D7: instance survives"         [labcount SURVIVOR] 1
check "0244 D7: flag dirty"                [xschem get modified] 1
check "0244 D7: records restored"          [rec0244] $::REC0244

# D8 -- THE FLUID-ROLLBACK DOOR. Found by the adversarial review of this fix, not by D7.
#      A pending paste is a live move gesture, and if a fluid snapshot is armed for it, every
#      RUBBER step runs fluid_reroute_restore() (move.c) -> mem_restore_slot() -> clear_drawing()
#      -> clear_placement_preview(). That bracket preserves ui_state VERBATIM on purpose, so
#      STARTMERGE survives while the stamp is destroyed: ESC then resolves 0 objects, deletes
#      NOTHING, and on a clean document still clears the modify flag -- the paste is left in the
#      drawing and the buffer reports itself saved. That is strictly worse than the pre-fix
#      behaviour, which deleted the (still selected) merged objects.
#      D7 does NOT cover it: a plain `merge` + `move_objects step` never arms a fluid snapshot
#      (move.c gates it on fluid_editing && stretch_select). The snapshot needs a stretch gesture,
#      and stretch_select LEAKS across merge_file()'s unselect_all(1) -- in the GUI, Ctrl+m
#      (move with attached nets) followed by Ctrl+V.
#      The fix: the six "restore ritual" brackets in move.c put xctx->preview_sel_n back beside
#      ui_state and the id counters (which they already restore, so the stamped ids stay valid).
#      fluid_editing is a plain Tcl global (xschem.tcl `set_ne fluid_editing 1`), NOT a C-mirrored
#      name: there is no `xschem get fluid_editing`, and `xschem set fluid_editing <v>` is a
#      SILENT NO-OP. Write the variable, and then ASSERT it -- with fluid_editing 0 this whole
#      section degrades into D7 and passes without testing anything (that is exactly how D7 came
#      to look like coverage it did not have).
set fluid0244 [set ::fluid_editing]
set ::fluid_editing 1
check "0244 D8: fluid editing really on" [set ::fluid_editing] 1
mkdoc
xschem select_all
xschem move_objects start 100 30 stretch     ;# arms the fluid snapshot (stretch_select)
xschem merge $::src0244                      ;# ...which survives into the paste's own gesture
check "0244 D8: merge armed over stretch"  [merging] 1
check "0244 D8: merged in"                 [xschem get wires] 3
xschem move_objects step 20 20               ;# one RUBBER step -> the fluid rollback
xschem abort_operation
check "0244 D8: paste removed"             [labcount MERGED] 0
check "0244 D8: merged text removed"       [textcount MERGEDTEXT] 0
check "0244 D8: survivors kept"            [xschem get wires] 2
check "0244 D8: instance survives"         [labcount SURVIVOR] 1
check "0244 D8: flag dirty"                [xschem get modified] 1

# and the flag half, which only shows on a CLEAN document (on a dirty one pre_merge_modified is 1
# and the guard correctly refuses to clear it, hiding the defect)
mkdoc_clean
xschem select_all
xschem move_objects start 100 30 stretch
xschem merge $::src0244
xschem move_objects step 20 20
xschem abort_operation
check "0244 D8 clean: paste removed"       [labcount MERGED] 0
check "0244 D8 clean: survivors kept"      [xschem get wires] 2
check "0244 D8 clean: back to clean"       [xschem get modified] 0
set ::fluid_editing $fluid0244

# ---------------------------------------------------------------------------
# E. ISSUE 0265 -- NOTHING TEARS DOWN A PENDING PASTE, so a second gesture silently COMMITS it.
#    (Plus issue 0267, which falls out of the same fix; see E4.)
#
#    STARTMERGE had exactly ONE setter (merge_file(), paste.c) and three teardown-bearing clears:
#    the commit tail (move.c) and abort_operation()'s two arms. Every OTHER way the bit went away
#    was unselect_all()'s wholesale `ui_state = 0` (select.c) -- which fires whenever anything is
#    selected, and a pending paste is ALWAYS selected, because that selection is what the drag
#    carries. So the paste was never CANCELLED by the next gesture, it was silently ACCEPTED.
#    Measured pre-fix on a 1-wire document:
#        merge, merge, ESC       wires 1 -> 2 -> 3 -> 2   (paste #1 COMMITTED)
#        merge, place_symbol     ui 296 -> 8232, merged wire committed; ESC removes only the symbol
#    Both sequences also printed the fluid layer's "fluid_gesture_arm() re-armed while a prior
#    gesture was still armed" warning -- a free second oracle on stderr, silent after the fix
#    (checked outside this script; there is no in-process seam for it).
#
#    THE FIX under test: abort_pending_merge() (callback.c) is the teardown the two ESC arms used
#    to carry inline, and leave_merge_for() is the gate every ARM now calls -- merge_file() itself,
#    all twelve stamp_placement_preview() placement arms, and the eleven wire/line draw arms
#    (plan_modal_gesture_exclusion.md phase 4's remaining direction). Pure-commit forms are
#    deliberately NOT gated (E6), and neither are undo/redo (E6): a pending merge is undo-covered.
#
#    NOT HOLLOW: every row asserts BOTH halves -- the previous paste really went (labcount MERGED,
#    textcount MERGEDTEXT, `wires`) AND the fixture really survived (SURVIVOR / SURVIVORTEXT /
#    record count, which is the only headless proof for the line). A gate that deleted everything
#    and a gate that deleted nothing both redden.
# ---------------------------------------------------------------------------

## the fixture, whole and alone: no merge residue, no placement residue, every survivor type.
## `modified` is read BEFORE rec0244 (which saves, and a saveas zeroes the flag).
proc fixture0265 {tag} {
  check "$tag: wires survive"     [xschem get wires] 2
  check "$tag: instance survives" [labcount SURVIVOR] 1
  check "$tag: text survives"     [textcount SURVIVORTEXT] 1
  check "$tag: one instance"      [xschem get instances] 1
  check "$tag: merged inst gone"  [labcount MERGED] 0
  check "$tag: merged text gone"  [textcount MERGEDTEXT] 0
  check "$tag: not merging"       [merging] 0
  check "$tag: flag dirty"        [xschem get modified] 1
  check "$tag: records restored"  [rec0244] $::REC0244
}

# E1 -- THE BUG, both doors. A second merge must ABANDON the first, not commit it. The load-bearing
#      number is `wires` after merge #2: 3 (survivors + ONE paste) and not 4.
foreach {form armv} {
  merge {xschem merge $::src0244}
  paste {xschem paste}
} {
  # the clipboard is primed once per row and survives the second `xschem paste` untouched, so no
  # re-prime is needed (or possible: prime_clip loads src0244 over the document under test).
  primed_doc $form
  eval $armv
  check "0265 E1 $form: merge #1 armed"   [merging] 1
  check "0265 E1 $form: paste #1 in"      [xschem get wires] 3
  eval $armv
  check "0265 E1 $form: merge #2 armed"   [merging] 1
  check "0265 E1 $form: PASTE #1 GONE"    [xschem get wires] 3
  check "0265 E1 $form: one merged inst"  [labcount MERGED] 1
  check "0265 E1 $form: one merged text"  [textcount MERGEDTEXT] 1
  xschem abort_operation
  fixture0265 "0265 E1 $form"

  # the flag half: two merges on a CLEAN document must still come back clean, i.e. the teardown's
  # restore feeds the next merge's latch (merge_file() re-latches pre_merge_modified AFTER
  # leave_merge_for(), which is why this is not the same check as A2).
  primed_doc_clean $form
  eval $armv
  eval $armv
  xschem abort_operation
  check "0265 E1 $form: clean stays clean" [xschem get modified] 0
  check "0265 E1 $form: clean survivors"   [xschem get wires] 2
}

# E1b -- three merges: the teardown must be re-entrant, not a one-shot. A stamp cleared but not
#        re-taken, or a latch consumed once, shows up here and nowhere in E1.
mkdoc
xschem merge $::src0244
xschem merge $::src0244
xschem merge $::src0244
check "0265 E1b: still exactly one paste" [labcount MERGED] 1
check "0265 E1b: wires"                   [xschem get wires] 3
xschem abort_operation
fixture0265 "0265 E1b"

# E2 -- EVERY PLACEMENT ARM. Enumerated from the state the teardown owns (the twelve
#      stamp_placement_preview() sites) and not from the verbs the bug report named -- 0242's
#      coverage lesson, whose own verb census was five arms short. Seven of the twelve are drivable
#      headlessly; the other five are click/dialog paths (context-menu Insert symbol / Insert text,
#      the `t` key, the screen grab, add_image's file chooser) and `xschem callback` segfaults under
#      --nogui, so they are covered by code inspection and by their scriptable twins here.
#      `place_text` is in the list on purpose even though its dialog cannot open headlessly: the
#      gate must fire on the ARM, before the dialog, so the paste is gone even when the placement
#      that displaced it never materializes.
foreach {arm armscript live liveexp} {
  place_symbol   {xschem place_symbol devices/lab_pin.sym}
                 {expr {([xschem get ui_state] & 8192) ? 1 : 0}} 1
  add_wire_label {set ::label_new_name E2LAB; xschem add_wire_label -place}
                 {xschem get sympin_preview} 1
  add_sch_pin    {set ::pin_new_name E2PIN; set ::pin_new_dir in; xschem add_sch_pin -place}
                 {xschem get sympin_preview} 1
  add_symbol_pin {set ::pin_new_name E2SP; set ::pin_new_dir in; xschem add_symbol_pin -place}
                 {xschem get sympin_preview} 1
  net_label      {xschem net_label 0}
                 {expr {([xschem get ui_state] & 16384) ? 1 : 0}} 1
  add_graph      {xschem add_graph}
                 {expr {([xschem get ui_state] & 16384) ? 1 : 0}} 1
  place_text     {xschem place_text}
                 {expr {([xschem get ui_state] & 1024) ? 1 : 0}} 0
} {
  mkdoc
  xschem merge $::src0244
  check "0265 E2 $arm: paste armed"    [merging] 1
  check "0265 E2 $arm: paste in"       [xschem get wires] 3
  eval $armscript
  check "0265 E2 $arm: PASTE GONE"     [xschem get wires] 2
  check "0265 E2 $arm: merged inst gone" [labcount MERGED] 0
  check "0265 E2 $arm: merged text gone" [textcount MERGEDTEXT] 0
  check "0265 E2 $arm: not merging"    [merging] 0
  check "0265 E2 $arm: placement live" [eval $live] $liveexp
  xschem abort_operation
  fixture0265 "0265 E2 $arm"
}

# E3 -- THE REVERSE, a control that was already green (issue 0242): a merge armed on top of a live
#      placement tears the placement down. It is here so that a "fix" which merely swapped which
#      gesture wins cannot pass section E.
mkdoc
set ::label_new_name E3LAB
xschem add_wire_label -place
check "0265 E3: preview armed"       [xschem get sympin_preview] 1
xschem merge $::src0244
check "0265 E3: preview torn down"   [xschem get sympin_preview] 0
check "0265 E3: merge armed"         [merging] 1
check "0265 E3: no orphan label"     [labcount E3LAB] 0
check "0265 E3: paste in"            [xschem get wires] 3
xschem abort_operation
check "0265 E3: no orphan after ESC" [labcount E3LAB] 0
fixture0265 "0265 E3"

# E4 -- ISSUE 0267. pre_merge_modified is latched once, at the arm, and describes the document
#      BEFORE the paste. Gating every arm bounds a pending merge against every ARMING gesture --
#      but NOT against the pure-commit forms (`xschem wire x1 y1 x2 y2`, `xschem text ...`, and the
#      menus/keybindings/replay that reach them), which are deliberately never gated. So real edits
#      can still land between the arm and the ESC, and restoring a flag that predates them reported
#      those edits SAVED: measured pre-fix, on a CLEAN document, wires=3 inst=1 texts=1 modified=0
#      with the new wire and the new text still on screen and the buffer claiming to be saved.
#      The fix is xctx->merge_modify_seq (xschem.h): set_modify() bumps a sequence on every
#      declaration of dirtiness, merge_file() latches it at the arm, and the teardown restores the
#      flag only while the two still match. Both abort_operation() arms are exercised.
#      CLEAN document is mandatory -- on a dirty one pre_merge_modified is already 1 and the old
#      code refused to clear the flag anyway, hiding the defect (the same trap as D8).
mkdoc_clean
xschem merge $::src0244
xschem move_objects abort
check "0265 E4 bare: bare arm reached"  [expr {[xschem get ui_state] == 264}] 1
xschem wire 2000 2000 2100 2000
xschem text 3000 3000 0 0 {E4NOTE} {} 0.4 0
check "0265 E4 bare: edits landed"      [xschem get wires] 4
xschem abort_operation
check "0265 E4 bare: paste removed"     [labcount MERGED] 0
check "0265 E4 bare: merged text gone"  [textcount MERGEDTEXT] 0
check "0265 E4 bare: new wire survives" [xschem get wires] 3
check "0265 E4 bare: new text survives" [textcount E4NOTE] 1
check "0265 E4 bare: MODIFIED"          [xschem get modified] 1

mkdoc_clean
xschem merge $::src0244
xschem wire 2000 2000 2100 2000
xschem text 3000 3000 0 0 {E4NOTE} {} 0.4 0
check "0265 E4 nested: nested arm"      [merging] 1
xschem abort_operation
check "0265 E4 nested: paste removed"   [labcount MERGED] 0
check "0265 E4 nested: new wire kept"   [xschem get wires] 3
check "0265 E4 nested: new text kept"   [textcount E4NOTE] 1
check "0265 E4 nested: MODIFIED"        [xschem get modified] 1

# E4 CONTROL, and the premise of the two rows above: the sequence guard must not degrade into
# "the flag is now always dirty". A clean document, a paste, the gesture's OWN machinery (a drag
# step and a selection change -- neither is an edit), then ESC, must still come back CLEAN.
mkdoc_clean
xschem merge $::src0244
xschem move_objects step 40 40
xschem select_all
xschem abort_operation
check "0265 E4 control: still clean"    [xschem get modified] 0
check "0265 E4 control: survivors kept" [xschem get wires] 2
check "0265 E4 control: paste gone"     [labcount MERGED] 0

# E5 -- PART B (plan_modal_gesture_exclusion.md phase 4): a DRAW cancels a live merge. The other
#      direction already worked, because merge_file() calls leave_placement_for() and that helper is
#      the wire/line teardown too. Pre-fix the paste stayed armed UNDER the new draw -- measured
#      ui_state 297 = STARTWIRE|STARTMERGE|STARTMOVE|SELECTION -- so one ESC had to serve two
#      gestures. `snap_wire` arms MENUSTART (65536) rather than STARTWIRE: this run has
#      infix_interface 0, and gating BOTH interface branches is 0247's lesson.
foreach {arm armscript bit} {
  wire_gui  {xschem wire gui}  1
  line_gui  {xschem line gui}  4
  snap_wire {xschem snap_wire} 65536
} {
  mkdoc
  xschem merge $::src0244
  check "0265 E5 $arm: paste in"      [xschem get wires] 3
  eval $armscript
  check "0265 E5 $arm: PASTE GONE"    [xschem get wires] 2
  check "0265 E5 $arm: not merging"   [merging] 0
  check "0265 E5 $arm: merged inst gone" [labcount MERGED] 0
  check "0265 E5 $arm: draw armed"    [expr {([xschem get ui_state] & $bit) ? 1 : 0}] 1
  xschem abort_operation
  fixture0265 "0265 E5 $arm"
}

# E6 -- THE CONTROLS: four things that must NOT move.
#
# E6a  A pure COMMIT form is never gated (plan landmine 2: `xschem wire x1 y1 x2 y2` and friends
#      are the replay/test seams). The paste must still be pending afterwards, and the committed
#      wire must survive the ESC that removes it. This is the row that keeps the gate honest about
#      WHY 0267 needed a second mechanism.
mkdoc
xschem merge $::src0244
xschem wire 2000 2000 2100 2000
check "0265 E6a commit-form: still merging" [merging] 1
check "0265 E6a commit-form: both in"       [xschem get wires] 4
xschem abort_operation
check "0265 E6a commit-form: paste removed" [labcount MERGED] 0
check "0265 E6a commit-form: commit kept"   [xschem get wires] 3

# E6b  UNDO is deliberately NOT gated, unlike leave_placement_for()'s call sites. A pending merge is
#      fully covered by the undo stack (merge_file() pushes its baseline BEFORE loading), so `undo`
#      already removes the paste -- and a delete()+push_undo run in front of the pop would make undo
#      RESTORE it. This row is the evidence for that decision, not decoration.
mkdoc
xschem merge $::src0244
xschem undo
check "0265 E6b undo: paste rolled back"  [xschem get wires] 2
check "0265 E6b undo: merged inst gone"   [labcount MERGED] 0
check "0265 E6b undo: survivors kept"     [labcount SURVIVOR] 1
check "0265 E6b undo: not merging"        [merging] 0

# E6c  A READ-ONLY window arms nothing, so there is no pending paste for any of this to act on
#      (the `merge` and `paste` verbs both run scheduler_readonly_reject, which raises a Tcl error).
#      leave_merge_for()'s own readonly guard is therefore unreachable today and is kept as a local
#      guard, exactly like leave_placement_for()'s.
mkdoc
xschem set readonly 1
check "0265 E6c readonly: merge refused"  [catch {xschem merge $::src0244}] 1
check "0265 E6c readonly: not merging"    [merging] 0
check "0265 E6c readonly: nothing merged" [xschem get wires] 2
xschem set readonly 0

# E6d  The teardowns run move_objects(ABORT), which zeroes xctx->paste_from -- the field merge_file()
#      had already set for the merge it is about to arm. merge_file() puts it back. Without the
#      restore a Ctrl+V over a pending gesture reports source 0 (named file) instead of 2
#      (clipboard), and the cross-window selection transfer (1) loses the SelectionClear abort that
#      reads it. `xschem get paste_from` is a seam added by 0265 for exactly this row.
mkdoc
xschem merge $::src0244
check "0265 E6d paste_from: fresh merge"   [xschem get paste_from] 0
prime_clip
mkdoc
xschem paste
check "0265 E6d paste_from: fresh paste"   [xschem get paste_from] 2
xschem paste
check "0265 E6d paste_from: paste over paste" [xschem get paste_from] 2
xschem merge $::src0244
check "0265 E6d paste_from: merge over paste" [xschem get paste_from] 0
xschem abort_operation

# E6e  THE SEAM ITSELF. `xschem test_gate_bypass 1` must really disable the new gate -- otherwise a
#      green section E could mean "the gate never runs". With the bypass on, the pre-fix behaviour
#      comes back exactly: the paste is committed by the placement arm and outlives the ESC.
mkdoc
xschem merge $::src0244
xschem test_gate_bypass 1
xschem place_symbol devices/lab_pin.sym
check "0265 E6e bypass: gate disabled"    [labcount MERGED] 1
xschem test_gate_bypass 0
xschem abort_operation
check "0265 E6e bypass: pre-fix residue"  [labcount MERGED] 1
check "0265 E6e bypass: default is off"   [expr {[catch {xschem place_symbol devices/lab_pin.sym}] ? 1 : 0}] 0
xschem abort_operation

# ---------------------------------------------------------------------------
# F. ISSUE 0266 -- the `move_objects` DISPATCH SLOT. (added 2026-08-12)
#
#    The verb dispatches on argv[2] with four bare strcmp()s against the lowercase literals
#    "start"/"step"/"end"/"abort" (scheduler.c), and EVERYTHING else falls into the one-shot
#    coordinate else, whose only commit-vs-arm discriminator is an argument COUNT
#    (`argc > 3 + nparam`). Nothing ever asks whether argv[2] is a NUMBER, so atof() turns every
#    typo into 0.0 and four distinct silent wrong answers follow. All four measured at d99f3791:
#      `move_objects END`        argc 3 -> the count test is false -> `ui_state |= MENUSTART;
#                                ui_state2 = MENUSTARTMOVE`, rc 0, NOTHING COMMITTED. On a pending
#                                merge ui_state went 296 -> 65832 and the next ESC deleted the paste.
#      `move_objects END 40 40`  argc 5 -> the count test is TRUE -> it really commits, at
#                                dx = atof("END") = 0.0: the wire landed at `N 0 40 100 40` where
#                                the control `move_objects 40 40` gives `N 40 40 140 40`. Worse than
#                                the no-op: it writes the document, at the wrong coordinate, rc 0.
#      `40 END` / `40 {}` / `kissing 40 40` / `stretch 40 40`
#                                the same species in the other slots -- every one committed at a
#                                corrupted delta with rc 0 (measured (40,0), (40,0), (0,40), (0,40)).
#      `move_objects 40`         a TRUNCATED line arms a menu move (ui 8 -> 65544). That is the
#                                action-log replay hazard this item exists for: a replay log is
#                                `source`d as Tcl, and because this branch answers TCL_OK for every
#                                spelling, a truncated / hand-edited / mis-cased move line replays
#                                as a ui_state mutation with NO diagnostic.
#
#    THE FIX under test: pure argument-SHAPE validation inside that final else, placed BEFORE the
#    `if(kissing)` / `if(stretch)` side effects -- the slot must be a number, or the flag word
#    `kissing`/`stretch` with no deltas, or absent; anything else is a TCL_ERROR naming the token.
#    Only the TYPE and COUNT of the verb's own arguments are inspected: no state precondition is
#    added to the pure-commit coordinate form (plan landmine 2 -- that form is the replay/test seam).
#
#    NOT HOLLOW: F18-F29 are the positive controls and they carry every shipped caller shape --
#    the three arm forms (toolbar/M bare, Ctrl+M `stretch`, Shift+M `kissing`), the commit form with
#    negative / fractional / exponent deltas, the rot/flip/-anchor form, and the start/step/end/abort
#    seam -- so a fix that over-gates (rejects the commit form, or drops the kissing/stretch
#    whitelist) reddens F18-F26 instead of passing quietly. F15 is the ORDERING witness: the reject
#    must fire before select_attached_nets(), which is the one thing every other row is blind to.
#
#    DELIBERATELY NOT COVERED HERE: the stranded ui_state2 that a PRE-EXISTING bad arm leaves behind
#    (it survives abort_operation and `xschem clear force`) -- that is issue 0268. F4 asserts only
#    that a rejected line never WRITES it.
# ---------------------------------------------------------------------------

set ::wire0266 [file join $::d0244 w0266.sch]

## A one-wire CLEAN document (save+load, so modified == 0 like a freshly opened cell), fully
## selected. CLEAN is mandatory for F17: mkdoc leaves the buffer dirty, and on a dirty buffer
## "a rejected line must not set the modify flag" cannot fail.
proc mkwire0266 {} {
  xschem clear force
  xschem set no_draw 1
  xschem wire 0 0 100 0
  xschem set no_draw 0
  xschem unselect_all
  xschem saveas $::wire0266
  xschem load $::wire0266
  xschem select_all
}

## The wire object record of the CURRENT drawing -- the only headless way to prove the wire did
## not move. DESTRUCTIVE to the modify flag (it saves), so always call it AFTER reading
## `modified` -- same caveat as rec0244.
proc wirerec0266 {} {
  set f [file join $::d0244 snap0266.sch]
  xschem saveas $f
  set fh [open $f r]; set data [read $fh]; close $fh
  foreach ln [split $data \n] { if {[string match {N *} $ln]} { return [string trim $ln] } }
  return {}
}

## An L of two wires with ONLY the horizontal one selected. select_attached_nets() grows
## `lastsel` 1 -> 2 on this fixture (measured), which is what makes F15 an ordering witness.
proc mkL0266 {} {
  xschem clear force
  xschem set no_draw 1
  xschem wire 0 0 100 0
  xschem wire 100 0 100 100
  xschem set no_draw 0
  xschem unselect_all
  xschem select wire 0 fast
}

## MENUSTART (65536) in ui_state, MENUSTARTMOVE (256) in ui_state2 -- the two bits a rejected
## line must never write.
proc armed0266  {} { return [expr {([xschem get ui_state]  & 65536) ? 1 : 0}] }
proc armed20266 {} { return [expr {([xschem get ui_state2] & 256)   ? 1 : 0}] }

# F0 -- PRECONDITION. F4 and F12 assert that the MENUSTARTMOVE / MENUSTART bits are NOT written by
#      a rejected line; nothing in this file clears ui_state2, so if a previous section had left
#      256 set those two rows would be hollow. Prove they start clear.
xschem clear force
xschem unselect_all
check "0266 F0: MENUSTART clear at entry"     [armed0266]  0
check "0266 F0: MENUSTARTMOVE clear at entry" [armed20266] 0

# F1-F6 -- THE FILED DEFECT, on the gesture it was filed against: a pending merge.
mkdoc
xschem merge $::src0244
set ::ui0266 [xschem get ui_state]
check "0266 F1: merge armed (ui_state 296)"  $::ui0266 296
check "0266 F1: END REJECTED"                [catch {xschem move_objects END} ::e0266] 1
check "0266 F2: error names the token"       [string match "*move_objects*END*" $::e0266] 1
check "0266 F3: ui_state untouched"          [xschem get ui_state] $::ui0266
check "0266 F3: MENUSTART not set"           [armed0266] 0
check "0266 F4: MENUSTARTMOVE not written"   [armed20266] 0
check "0266 F5: merge still pending"         [merging] 1
check "0266 F5: paste still in"              [xschem get wires] 3
# F6 -- the correct spelling still commits, immediately after the rejected one. The error must not
#       half-consume the gesture.
xschem move_objects end 0 0
check "0266 F6: correct form commits"        [merging] 0
check "0266 F6: paste kept"                  [xschem get wires] 3
check "0266 F6: merged inst kept"            [labcount MERGED] 1
xschem abort_operation

# F7-F14 -- the DELTA slots. These forms did NOT no-op pre-fix, they COMMITTED at a corrupted
#           delta, so the second row of each pair is the one that matters. The expected value is
#           the literal fixture record, NOT a baseline read taken just before the call: wirerec0266
#           saves, and `xschem saveas` drops the selection, which would leave the move with nothing
#           to move and turn every one of these into a hollow green.
#           `{lab=#net1}` in the pre-fix values is the node annotation a real commit leaves behind;
#           a rejected line must not produce that either, so the row is a byte-identity row.
foreach {tag form prefix} {
  F7  {xschem move_objects END 40 40}     {N 0 40 100 40 {lab=#net1}}
  F9  {xschem move_objects 40 END}        {N 40 0 140 0 {lab=#net1}}
  F10 {xschem move_objects 40 {}}         {N 40 0 140 0 {lab=#net1}}
  F13 {xschem move_objects kissing 40 40} {N 0 40 100 40 {lab=#net1}}
  F14 {xschem move_objects stretch 40 40} {N 0 40 100 40 {lab=#net1}}
} {
  mkwire0266
  check "0266 $tag: {$form} REJECTED"   [catch $form ::e0266] 1
  check "0266 $tag: doc byte-identical" [wirerec0266] {N 0 0 100 0 {}}
  note  "0266 $tag: pre-fix this COMMITTED at {$prefix}"
}

# F8 -- the delta corruption spelled out: `END 40 40` used to swallow dx and shift every later
#       argument one slot left, landing the wire at N 0 40 100 40 instead of N 40 40 140 40.
mkwire0266
catch {xschem move_objects END 40 40}
check "0266 F8: dx NOT eaten (pre-fix landed at N 0 40 100 40)" \
      [expr {[wirerec0266] eq "N 0 40 100 40 {lab=#net1}"}] 0

# F11/F12 -- THE TRUNCATED REPLAY LINE. `move_objects 40` is a half-written log line; pre-fix it
#            armed a deferred menu move (ui 8 -> 65544) and answered TCL_OK.
mkwire0266
check "0266 F11: truncated {40} REJECTED"   [catch {xschem move_objects 40} ::e0266] 1
check "0266 F12: MENUSTART not set"         [armed0266] 0
check "0266 F12: MENUSTARTMOVE not written" [armed20266] 0

# F15 -- ORDERING. The reject must fire BEFORE `if(stretch) select_attached_nets();`, so a rejected
#        line leaves no selection change behind. On mkL0266 select_attached_nets() grows lastsel
#        1 -> 2 (measured on the ARM form), so lastsel == 1 is the witness that it never ran.
mkL0266
check "0266 F15: only the h-wire selected"   [xschem get lastsel] 1
check "0266 F15: {stretch 40 40} REJECTED"   [catch {xschem move_objects stretch 40 40} ::e0266] 1
check "0266 F15: select_attached_nets NEVER RAN" [xschem get lastsel] 1

# F16 -- MIS-CASED AND UNKNOWN SUB-VERBS. All rejected -- the fix does NOT make the sub-verbs
#        case-insensitive (the rejected alternative in the issue file): a verb whose log-replay
#        surface wants exactly one spelling gets exactly one.
mkwire0266
foreach sv {Start End Abort Step START STEP ABORT foo abort_it} {
  check "0266 F16: sub-verb '$sv' REJECTED" [catch {xschem move_objects $sv} ::e0266] 1
}
xschem abort_operation

# F17 -- a rejected line must not DIRTY the document. Clean fixture, the whole negative set, one
#        read of the flag at the end (no wirerec0266 in between -- it saves, which zeroes it).
mkwire0266
check "0266 F17: clean before"   [xschem get modified] 0
catch {xschem move_objects END}
catch {xschem move_objects END 40 40}
catch {xschem move_objects 40 END}
catch {xschem move_objects 40 {}}
catch {xschem move_objects 40}
catch {xschem move_objects kissing 40 40}
catch {xschem move_objects stretch 40 40}
catch {xschem move_objects foo}
check "0266 F17: STILL CLEAN"    [xschem get modified] 0
xschem abort_operation

# ---- F18-F29 THE POSITIVE CONTROLS ----------------------------------------------------------
# Every shipped call site shape. These are green before the fix by construction; they are here so
# that an over-gating fix cannot pass section F. F18-F21 are the three arm forms the GUI ships
# (xschem.tcl toolbar/Edit menu + actions.csv M / Control+M / Shift+M).

# F18 -- bare arm: toolbar, Edit > Move objects, M.
mkwire0266
check "0266 F18: bare arm accepted" [catch {xschem move_objects} ::e0266] 0
check "0266 F18: bare arm ARMS"     [armed0266] 1
xschem abort_operation

# F19 -- Ctrl+M. select_attached_nets() DOES run on the arm path (the ordering fix must not
#        suppress it, only order it) -- lastsel grows 1 -> 2.
mkL0266
check "0266 F19: stretch arm accepted"      [catch {xschem move_objects stretch} ::e0266] 0
check "0266 F19: stretch arm ARMS"          [armed0266] 1
check "0266 F19: select_attached_nets RAN"  [xschem get lastsel] 2
xschem abort_operation

# F20 -- Shift+M.
mkwire0266
check "0266 F20: kissing arm accepted" [catch {xschem move_objects kissing} ::e0266] 0
check "0266 F20: kissing arm ARMS"     [armed0266] 1
xschem abort_operation

# F21 -- both flags, no deltas.
mkwire0266
check "0266 F21: stretch+kissing arm accepted" [catch {xschem move_objects stretch kissing} ::e0266] 0
check "0266 F21: stretch+kissing arm ARMS"     [armed0266] 1
xschem abort_operation

# F22-F25 -- THE PURE-COMMIT COORDINATE FORM gains no precondition (landmine 2). Negative,
#            fractional and exponent deltas are all live shipped forms (wireedit_54 uses
#            `-90 -40 stretch kissing`), so the numeric predicate must be strtod, not isdigit.
foreach {tag form want} {
  F22 {xschem move_objects 40 40}                     {N 40 40 140 40 {lab=#net1}}
  F23 {xschem move_objects -90 -40 stretch kissing}   {N -90 -40 10 -40 {lab=#net1}}
  F24 {xschem move_objects 40.5 -0.5}                 {N 40.5 -0.5 140.5 -0.5 {lab=#net1}}
  F25 {xschem move_objects 1e2 40}                    {N 100 40 200 40 {lab=#net1}}
} {
  mkwire0266
  check "0266 $tag: {$form} accepted" [catch $form ::e0266] 0
  check "0266 $tag: moved exactly"    [wirerec0266] $want
}

# F26 -- the rot/flip/local/-anchor parser is POSITIONAL and sits in the same else. No argument may
#        be re-indexed by the validation.
mkwire0266
check "0266 F26: rot/-anchor form accepted" [catch {xschem move_objects 0 0 1 0 -anchor 0 0 kissing} ::e0266] 0
check "0266 F26: rotation applied"          [wirerec0266] "N 0 0 0 100 {lab=#net1}"

# F27/F28 -- the incremental start/step/end/abort seam. The four sub-verb branches are ahead of the
#            final else and must never reach the new validation at all.
mkwire0266
check "0266 F27: start accepted" [catch {xschem move_objects start 0 0} ::e0266] 0
check "0266 F27: step accepted"  [catch {xschem move_objects step 40 40} ::e0266] 0
check "0266 F27: end accepted"   [catch {xschem move_objects end 40 40} ::e0266] 0
check "0266 F27: gesture committed" [wirerec0266] "N 40 40 140 40 {lab=#net1}"
mkwire0266
check "0266 F28: abort accepted" [catch {xschem move_objects abort} ::e0266] 0

# F29 -- re-pin of the A4/D5 constructor the rest of this file leans on: `end 0 0` on a pending
#        merge still commits.
mkdoc
xschem merge $::src0244
check "0266 F29: end 0 0 accepted"  [catch {xschem move_objects end 0 0} ::e0266] 0
check "0266 F29: merge committed"   [merging] 0
check "0266 F29: paste kept"        [xschem get wires] 3

xschem clear force

puts ""
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
