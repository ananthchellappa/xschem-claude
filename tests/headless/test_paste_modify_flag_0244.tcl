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
## SECTIONS: A the four control rows x both doors (`xschem merge <file>` and clipboard
## `xschem paste`) · B hierarchy_modified, the flag the prompts actually read · C the SECOND
## STARTMERGE arm (the one reached with STARTMOVE already cleared) · D1-D8 part B, ending with D8,
## the fluid-rollback door that the adversarial review of the fix found and that D7 does not cover.
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

xschem clear force

puts ""
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
