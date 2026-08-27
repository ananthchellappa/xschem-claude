#  File: utils/annot_mode.tcl        (sourced from cadence_style_rc)
#
#  Operating-point annotation MODE — the writer of the `annot_show` mask, and the
#  target of the three chords bound in src/cadence_style_rc:
#
#      6        -> cadence::annot_mode op      annot_show |= 1  ADD device OP info
#      Alt-6    -> cadence::annot_mode opvolt  annot_show |= 2  ADD node voltages
#      Ctrl-6   -> cadence::annot_mode none    annot_show  = 0  clear BOTH
#
#  ⚠ TWO ADDITIVE SETTERS AND ONE CLEAR-ALL — issue 0614, RULED by the user
#  2026-08-22, and it is NOT the obvious reading. `6` NEVER turns anything off and
#  is NOT a toggle: pressing it twice leaves the mask unchanged, and pressing it
#  while voltages are on leaves them on. `Alt-6` is NO LONGER mask 3 — it ORs bit1
#  in and leaves bit0 exactly as it found it, so from a clean start it gives mask
#  2, voltages ALONE, a state the old three-state cascade could not reach. `Ctrl-6`
#  is the ONLY off switch.
#
#  Step S8 of doc/claude/specs/op_annotation.md. S7 gave `hide=op` teeth behind
#  the `annot_show` bitmask (bit0 device OP info, bit1 node voltages; see
#  text_hidden() in src/actions.c) and left it at 0 with NOTHING in a running
#  session able to write it — measured, even the shipped **Annotate Operating
#  Point** menu item produced a loaded raw and a still-dark annotator, because
#  it sets `show_hidden_texts` and S7 decision D3 makes the class bits ignore
#  that variable entirely. This file, plus the two menu bodies repaired in
#  src/xschem.tcl, are that writer.
#
#  FOUR THINGS EVERY PRESS DOES, IN THIS ORDER:
#    1. write the mask THROUGH `xschem set annot_show` (never a bare
#       `set ::annot_show` — S7 decision D4; a bare set leaves the C field stale
#       until the next bulk sync, and `annot_show` is an INT, so `true`/`on`/`yes`
#       all atoi to 0, i.e. silently OFF);
#    2. load a raw IF, and only if, nothing is annotated yet (see the guard note);
#    3. `xschem update_all_sym_bboxes` then `xschem redraw` — the pair the
#       `Show hidden texts` checkbutton uses (src/xschem.tcl:15036). Bboxes change
#       when hidden texts appear, and annot_show_sync_cache() lives inside
#       update_all_sym_bboxes (scheduler.c:13651), so no extra sync call is needed;
#    4. SAY WHAT HAPPENED, HELD, on the status line.
#
#  ⚠ REQUIREMENT 4 IS THE DELIVERABLE, NOT A COURTESY. The two first-run
#  confusions — "there is no raw file" and "nothing on this sheet has an OP
#  descriptor" — are both SILENT today: measured, `xschem annotate_op
#  /nonexistent.raw` returns rc=0, sets the interp result to the FILE PATH,
#  writes nothing to the status bar and only prints `raw_read(): failed to open
#  file` to stderr. Both are reported here, in ONE line (decision D5): fixing the
#  raw only to meet the descriptor problem on the next press is the shape D5
#  rejects.
#
#  ⚠ AND IT IS `statusmsg -hold`, NOT `statusmsg`. Measured: a plain statusmsg is
#  erased by ONE `<Motion>` event (the field reverts to `mouse = ... selected: 0
#  path: .`), and a key press is always followed by pointer motion in real use —
#  while a naive headless check, which never generates motion, still passes.
#  Issue 0248 / STATUSMSG_HOLD_MS is the machinery; `xschem get statusmsg_hold`
#  is its only headless seam.
#
#  ⚠ A FAILED annotate_op DESTROYS A GOOD ANNOTATION, SILENTLY. scheduler.c:2409
#  deletes the previously loaded OP and unsets `ngspice::ngspice_data` BEFORE it
#  tries to open the new file, and returns rc=0 either way. So this file (a) never
#  reloads while an annotation is LIVE, (b) never reloads while a raw is merely
#  loaded, and (c) `file exists` the candidate before handing it over. Success is
#  RE-ASKED from `xschem raw loaded` afterwards and never taken from annotate_op's
#  rc — the prototype's one virtue is that it never claims a success it cannot
#  prove (sg13g2_display_fet_params returns blank rather than a wrong number).
#
#  ⚠ NO PDK TOKEN APPEARS IN THIS FILE, deliberately. Every PDK-specific fact
#  lives in the descriptors registered by the PDK's own procs file
#  (sky130_procs.tcl, gf180_procs.tcl, sg13g2_procs.tcl). This file's whole
#  vocabulary is `xschem set annot_show`, `xschem raw loaded`,
#  `xschem annotate_op`, `ase::last_rawfile` / `ase::session_for_current`,
#  `op_annot::devpath` / `op_annot::type` / `op_annot::_annotated`,
#  `xschem update_all_sym_bboxes`, `xschem redraw`, `xschem statusmsg -hold`.
#  If a PDK name ever appears below, the generalization has failed.
#
#  ⚠ NO HIERARCHY WALK (invariant I6). "Is anything on this sheet annotatable?"
#  is answered on the CURRENT LEVEL ONLY. S3's descend-and-restore walk is
#  deferred (issues 0436/0442/0443) and its restore discipline is a known breach
#  (0431); none of it is needed to answer this question.
#
#  ⚠ INVARIANT I4: nothing here modifies the schematic. No instance is placed, no
#  modify flag is set, nothing is written to the .sch. The mask is view state.
#
#  Pure Tcl, no C change, PROC DEFINITIONS ONLY — this file is sourced headless by
#  tests/headless/test_op_annot.tcl section N, where `bind` and `winfo` do not
#  exist. The three Tk binds live in src/cadence_style_rc next to the Ctrl-4
#  precedent, because that is where a user looking to remap a displaced chord
#  reads (decision D1).
# ---------------------------------------------------------------------------

namespace eval cadence {}

## The three modes, as the INTEGER bitmask xctx->annot_show wants, applied to the
## mask that is ALREADY set:
##   none   -> 0          the ONLY off switch, clears BOTH bits
##   op     -> cur | 1    ADD device OP info      (bit0; bit1 UNTOUCHED)
##   opvolt -> cur | 2    ADD node voltages       (bit1; bit0 UNTOUCHED)
## Issue 0614's ruling. `opvolt` from a clean start is 2, NOT 3 — voltages alone.
## `op` applied twice is idempotent, and `op` applied to mask 2 gives 3: it can
## never take the voltages away. Only `none` clears anything.
##
## ⚠ IT IS A PURE FUNCTION AND MUST STAY ONE. The live mask arrives as an
## ARGUMENT (default 0) and is never read here; `cadence::annot_mode` does the
## `xschem get annot_show` and hands it over. A version that read the mask itself
## would make the table depend on session state and leave the sequence rows as its
## only guard.
##
## An unknown spelling RAISES, and names the three that work. op_annot's own
## discipline is the opposite for DATA (a missing vector renders BLANK, I3) —
## but a mode spelling is not data, it is a bind body or a script getting the
## call wrong, and a caller bug that renders as "annotation quietly stayed off"
## is the failure mode this whole step exists to kill.
##
## THE SPELLINGS none/op/opvolt ARE KEPT while their semantics change: a user rc
## that calls `cadence::annot_mode opvolt` must keep working (invariant I5), and
## renaming would buy cosmetics only.
proc cadence::_annot_mask {mode {cur 0}} {
  if {![string is integer -strict $cur]} { set cur 0 }
  switch -exact -- $mode {
    none   { return 0 }
    op     { return [expr {$cur | 1}] }
    opvolt { return [expr {$cur | 2}] }
  }
  error "cadence::annot_mode: unknown mode \"$mode\": use none, op or opvolt"
}

## Symbol types that are never devices, so naming them in "no OP descriptor for
## symbol type(s): ..." would be noise rather than news. `annotator` is the
## carrier symbol itself — the very thing displaying the block — and the pins and
## labels are connectivity, not instances anyone would annotate.
namespace eval cadence {
  variable _annot_skip_types \
    {{} annotator ipin opin iopin label show_label noconn netlist_commands launcher}
}

## -> {path level source} for the raw this cell would use, or {} {} none.
##
## ASE FIRST, AND ITS LEVEL TRAVELS WITH THE PATH. `ase::session_for_current`
## (ase.tcl:2351) walks the hierarchy stack and answers {key level lib cell view}
## or {}; `ase::last_rawfile` (ase.tcl:689) answers the backend raw path only if
## the file exists. Passing the path ALONE would bind the raw to the CURRENT
## level and reproduce spec landmine 4's silent device-path collapse the moment
## the user has descended — which is precisely what annotate_op's optional
## `level` argument is for.
##
## Otherwise the SHIPPED fallback spelling, the one `select_raw`
## (src/xschem.tcl:14471) already resolves for both **Annotate Operating Point**
## menu items — a second spelling here would be an I1-shaped drift in the path
## instead of in the vector name. Two deliberate differences from select_raw:
## it is not CALLED (it pops a tk_getOpenFile whenever has_x — a modal dialog on
## every key press), and its trailing-slash `regsub` is done on a LOCAL copy,
## because select_raw does it under `global` and rewrites the user's
## `netlist_dir` preference as a side effect of being read.
proc cadence::_annot_raw_candidate {} {
  if {[llength [info commands ::ase::session_for_current]] &&
      [llength [info commands ::ase::last_rawfile]]} {
    if {![catch {::ase::session_for_current} s] && [llength $s] >= 2} {
      if {![catch {::ase::last_rawfile [lindex $s 0]} p] && $p ne {}} {
        ## ⚠ issue 0838: this chord is the OTHER door into the same data, and it
        ## has no session gate of any kind (deliberately — see the file header),
        ## so greying ASE-L's `Results > Annotate` while leaving `6` live would
        ## make that menu a decoration. The session says whether its raw still
        ## describes the deck on disk; a stale one is reported, never annotated.
        ##
        ## ⚠ AND IT DOES NOT FALL THROUGH TO THE netlist_dir ARM. That arm would
        ## reach for `$netlist_dir/$cell.raw` — very often the SAME stale file
        ## under another name — and turn a refusal into a silent success. When a
        ## session owns this sheet, its answer is the answer.
        set stale 0
        if {[llength [info commands ::ase::results_stale]]} {
          catch {set stale [::ase::results_stale [lindex $s 0]]}
        }
        if {$stale} { return [list $p [lindex $s 1] stale] }
        return [list $p [lindex $s 1] ase]
      }
    }
  }
  set nd {}
  catch {set nd [uplevel #0 {set netlist_dir}]}
  regsub {/$} $nd {} nd
  set sn {}
  catch {set sn [xschem get schname]}
  set cell [file tail [file rootname $sn]]
  if {$nd eq {} || $cell eq {}} { return [list {} {} none] }
  return [list "$nd/$cell.raw" {} netlist_dir]
}

## -> {n-annotatable {symbol types with no device path}} for the CURRENT sheet.
##
## ⚠ INSTANCE NAMES, NEVER INDICES. get_instance() (scheduler.c:187) takes an
## all-digit string as an INDEX, so `op_annot::devpath 0` answers a plausible
## WRONG device path (`@m.x0.mzz`) rather than an error — a loop that fed it
## indices would find every sheet annotatable and this whole report would be a
## lie that never fails a test.
##
## Deduped by `cell::name`, because that is what both `cell::type` and a
## descriptor's `match` globs are functions of (op_annot::_matches), so one
## instance per distinct cell answers for all of them. Every term catch-wrapped:
## a status line must not raise out of a key press.
proc cadence::_annot_scan {} {
  variable _annot_skip_types
  set n 0
  set missing {}
  set seen {}
  if {[catch {xschem get instances} ni]} { return [list 0 {}] }
  if {![string is integer -strict $ni]} { return [list 0 {}] }
  for {set i 0} {$i < $ni} {incr i} {
    if {[catch {xschem getprop instance $i name} nm]} continue
    if {$nm eq {}} continue
    set cell {}
    catch {set cell [xschem getprop instance $i cell::name]}
    if {$cell eq {}} { set cell $nm }
    if {[lsearch -exact $seen $cell] >= 0} continue
    lappend seen $cell
    set t {}
    catch {set t [::op_annot::type $nm]}
    if {[lsearch -exact $_annot_skip_types $t] >= 0} continue
    set p {}
    catch {set p [::op_annot::devpath $nm]}
    if {$p ne {}} { incr n ; continue }
    if {[lsearch -exact $missing $t] < 0} { lappend missing $t }
  }
  return [list $n [lsort $missing]]
}

## The one held status line. <state> is one of
##   off | live | noop | loaded | failed | noraw | nopath
## and <types> is _annot_scan's second element, already known to matter only
## when NOTHING on the sheet was annotatable.
##
## Both first-run confusions land in the SAME line (decision D5). The descriptor
## clause is omitted when the sheet carries no candidate device at all, because
## "no OP descriptor for symbol type(s):" with nothing after it says less than
## silence.
## ⚠ WORDED OFF THE RESULTING MASK, NOT OFF THE MODE — issue 0614. Under additive
## semantics a mode-worded line LIES: `Alt-6` from a clean start produces mask 2
## and a mode switch would still announce "device OP info + node voltages" while
## showing voltages alone. It also had no wording at all for mask 2, the state the
## ruling just created. The first argument is therefore the MASK.
##
## ⚠ THE WORDING WAS DELIBERATELY TERSER THAN THE View MENU'S, AND ISSUE 0678 MADE
## IT STRICTLY TRUE RATHER THAN MERELY TERSE. Until 0678 bit1 also gated branch
## currents, so mask 2's "node voltages" understated the checkbutton's "Show node
## voltage / branch current annotation". The user reversed that on a real bench
## 2026-08-24: the currents moved to bit0, and the menu pair read "Show device OP /
## branch current annotation" / "Show node voltage annotation". These four strings
## are deliberately UNCHANGED -- mask 2 is now exact, and mask 1's "device OP info"
## stays terse for the currents the way it always did for the id=/gm= block. Every
## committed golden string (rows N3/N5/N6/N8/N9/N10/N10b/N15/N23) is byte-identical.
##
## ⚠ THAT MENU PAIR NO LONGER EXISTS (issue 0682, same day, same bench): annotation
## visibility moved to ASE-L `Results > Annotate` -- *Operating Point info* (bit0) /
## *DC Node Voltages* (bit1) -- and the `View > Show / Hide` pair was deleted. So
## there is no longer a second, wordier surface for these lines to be terser THAN.
## They stay as they are: the comparison is gone, the reasoning that made each
## string exact is not, and churning committed goldens to chase a deleted menu
## would be change for its own sake. Note the ASE-L labels are Cadence's and do
## NOT partition the two content classes, so they could not have served as the
## reference wording anyway.
##
## ⚠ ISSUE 0868 WIDENED THE SWITCH FROM `& 3` TO `& 7`, AND THE FOUR SHIPPED
## WORDINGS ARE BYTE-IDENTICAL. Before the widening, mask 4 -- transient node
## voltages ON and painted on the sheet -- fell on the `0` arm and reported
## "OP annotation OFF": not merely silence, the OPPOSITE of what was on the
## screen. The four new arms name the transient class in the same shape the
## shipped ones name theirs. Row V21 of tests/headless/test_op_annot.tcl asserts
## all eight, so a re-wording of the shipped four reds in this file rather than
## in six unrelated statusmsg rows.
proc cadence::_annot_msg {mask state path types} {
  if {![string is integer -strict $mask]} { set mask 0 }
  switch -exact -- [expr {$mask & 7}] {
    0 { set m "OP annotation OFF" }
    1 { set m "OP annotation ON (device OP info)" }
    2 { set m "OP annotation ON (node voltages)" }
    3 { set m "OP annotation ON (device OP info + node voltages)" }
    4 { set m "OP annotation ON (transient node voltages)" }
    5 { set m "OP annotation ON (device OP info + transient node voltages)" }
    6 { set m "OP annotation ON (node voltages + transient node voltages)" }
    7 { set m "OP annotation ON (device OP info + node voltages + transient node voltages)" }
    default { set m "OP annotation" }
  }
  switch -exact -- $state {
    live    { append m " -- raw already loaded" }
    noop    { append m " -- a raw is loaded but it published no operating point:\
                        use Waves > Op Annotate, or `xschem raw_clear` then press\
                        again" }
    loaded  { append m " -- loaded $path" }
    failed  { append m " -- COULD NOT LOAD $path" }
    noraw   { append m " -- NO RAW FILE: $path" }
    nopath  { append m " -- NO RAW FILE for this cell" }
    stale   { append m " -- STALE RESULTS NOT USED: [file tail $path] is older than\
                        the deck it describes; the last run did not produce it. Re-run." }
  }
  if {$state ne {off} && [llength $types]} {
    set shown $types
    set tail {}
    if {[llength $types] > 4} {
      set shown [lrange $types 0 3]
      set tail { ...}
    }
    append m " -- no OP descriptor for symbol type(s): [join $shown { }]$tail"
  }
  return $m
}

## ⚠ ISSUE 0872 / RULING 0856 — THE DETECTOR THE MODE CHOOSER NEVER HAD.
## The user's ruling, verbatim: "if OP is part of the run, then plot from OP.
## We haven't yet built anything for annotating from TRAN results, so it should
## do nothing silently." Commit e31975e7 made the OPERATING POINT PUBLISHER obey
## it -- update_op() in src/save.c refuses anything that is not `op` or `dc`.
## The MODE CHOOSER did not, and a reader would reasonably assume it did not
## NEED to: the mask is only a VISIBILITY switch, so flipping it looks like it
## cannot put a number on a sheet. IT CAN. `xschem set cursor2_x` publishes a
## transient sample into the very cursor_b_val[] array the render gates read
## (row V25 pins that publish as a DELIBERATE typed request), and those gates
## ask only whether a point IS published, never which analysis minted it. So on
## a transient sheet the numbers are already sitting there and bit1 alone
## reveals them, under a status line calling them OP node voltages.
##
## ⚠ AND THIS IS NOT WHERE ISSUE 0872 SAID THE DEFECT WAS. That issue blamed
## the shared render class -- the ANNOT_SHOW_VOLTAGE-or-ANNOT_SHOW_TRAN return
## in annot_class_mask(), src/actions.c. Measured with the transient mode never
## invoked and bit2 never set, Alt-6 ALONE already repaints the transient's
## numbers, so that return is not in the chain in this direction at all. The
## fix belongs where the MODE is chosen, and that is here. What the render class
## still lacks -- a provenance stamp, so masks 4 and 6 over an OPERATING POINT
## database stop calling its numbers transient, and so the ASE-L
## `Results > Annotate` checkbuttons cannot write the mask past this refusal --
## is issue 0877, and it needs a user ruling before anyone builds it.
##
## Answers 1 when the ATTACHED database can supply an operating point, AND when
## NOTHING is attached at all. The second half is not laxity: with no database
## there is nothing to ask, and a refusal keyed on "the database is not op" that
## also swallowed "there is no database to ask" would stop the chord being able
## to FIND a raw at all -- row V31b leg 2 is that guard, and it is why the
## `loaded < 0` arm returns 1 rather than 0.
##
## ⚠ SO THIS PREDICATE IS ASKED TWICE, AND THE SECOND ASK IS NOT OPTIONAL.
## `annot_mode`'s own candidate search runs on exactly the `loaded < 0` arm this
## proc waves through, and what it loads is very often the transient the user
## just ran. update_op()'s guard is NOT a backstop for that: measured, it only
## declines to PUBLISH, so the mask is still written, the sentence is still
## minted, and raw_read()'s tail gate still publishes at cursor B. The second
## ask -- and the unwind that follows it -- lives at the end of the candidate
## branch in `annot_mode` below, and row V31c is what sees it. An earlier
## revision of this paragraph called update_op() the backstop; it is not, and
## the sentence shipped while the defect it excused was one key press away.
##
## The op/dc set and its spelling are copied from update_op()'s own guard, so
## one grep finds one predicate shape and a later widening (issue 0860) moves
## both together. `xschem raw sim_type` RAISES with nothing loaded -- measured,
## not assumed -- hence the catch rather than a comparison against {}; an
## unreadable sim_type with a database attached refuses, exactly as update_op()
## refuses a NULL one.
proc cadence::_annot_op_db_ok {} {
  set loaded -1
  catch {set loaded [xschem raw loaded]}
  if {![string is integer -strict $loaded] || $loaded < 0} { return 1 }
  set st {}
  if {[catch {xschem raw sim_type} st]} { set st {} }
  if {$st eq {op} || $st eq {dc}} { return 1 }
  return 0
}

## cadence::annot_mode none|op|opvolt — the bind target. See the file header.
proc cadence::annot_mode {mode} {
  ## THE CURRENT MASK IS PULLED THROUGH `xschem get`, never $::annot_show: the
  ## mask is PER-CONTEXT (xctx->annot_show), so under the tabbed interface the Tcl
  ## mirror belongs to whichever context wrote it last. A read that fails for any
  ## reason degrades to 0, which makes `op`/`opvolt` behave like the old hard set
  ## rather than doing something unpredictable.
  set cur 0
  catch {set cur [xschem get annot_show]}
  if {![string is integer -strict $cur]} { set cur 0 }
  set mask [cadence::_annot_mask $mode $cur] ;# raises on an unknown spelling

  ## ⚠ RULING 0856, AND IT IS A SILENT RETURN ON PURPOSE (issue 0872). The
  ## ruling is "it should do nothing silently", so this returns BEFORE the mask
  ## is written and before any sentence is minted: no paint, no status line, no
  ## CIW. A fix that only gated the PAINT would leave the worst face of 0872
  ## standing -- with a transient attached and nothing published, Alt-6 painted
  ## nothing but still told the user to run `Waves > Op Annotate`, which is the
  ## exact operation the 0856 guard refuses on a transient. Row V31 plants a
  ## held sentinel before each press and requires it to SURVIVE, because
  ## "said nothing" cannot be read off a status line that is never empty.
  ##
  ## ⚠ `$mask != 0` EXEMPTS THE OFF SWITCH, AND THAT TERM IS LOAD-BEARING.
  ## Ctrl-6 must always clear: clearing never puts a number on a sheet, and a
  ## refusal that swallowed Ctrl-6 would strand the user with bit2 armed and no
  ## way to turn it off -- a worse defect than the one being fixed. Row V31
  ## leg 2 is that exemption's only guard, and sabotage S14b drops this term.
  if {$mask != 0 && ![cadence::_annot_op_db_ok]} { return }

  xschem set annot_show $mask

  set state off
  set path {}
  set types {}

  if {$mask != 0} {
    set annotated 0
    catch {set annotated [::op_annot::_annotated]}
    set loaded -1
    catch {set loaded [xschem raw loaded]}
    if {![string is integer -strict $loaded]} { set loaded -1 }

    if {$annotated} {
      ## The display's own three-term gate says the numbers are live. Reloading
      ## here would be the destructive path for no gain.
      set state live
    } elseif {$loaded >= 0} {
      ## A raw IS loaded and every row still renders blank — issue 0451's fourth
      ## indistinguishable cause. Saying "raw already loaded" would be a lie
      ## about a blank block, and reloading would throw away a good file.
      ##
      ## ⚠ THERE IS ONLY ONE CAUSE LEFT, AND THIS IS WHY IT IS NOT ASKED FOR
      ## (issue 0459 closes here, issue 0864 is what closed it). This branch used
      ## to choose between two sentences by reading the shipped menu checkbutton
      ## `Simulation > Graphs > Live annotate probes with 'b' cursor`, because
      ## that switch was _annotated's first term and could blank a populated
      ## block on its own. After 0864 it is not a term of _annotated at all — it
      ## means "follow cursor B and re-annotate as it moves" and nothing else —
      ## so with a database attached the ONLY way the gate can fail is
      ## annot_p < 0: a file that published no operating point. The sentence
      ## that named the switch is DELETED rather than re-worded, because it can
      ## no longer be true, and a plausible wrong REASON is the same defect as
      ## save.c ruling D5-1's plausible wrong NUMBER. Users who used to see it
      ## now see the `noop` sentence, which names the real cause and the way
      ## out — this branch is a dead end, the guard above blocks the auto-load.
      ##
      ## ⚠ Row N10c greps this file's CODE lines for the deleted arm and for the
      ## switch's name; prose above may name both freely, code may not. After
      ## 0864 the `live` arm above is taken first whenever a point is published,
      ## so on that path — every real user's — N10c is the ONLY row that can see
      ## the arm come back. It is not the only row in the tree: measured
      ## 2026-08-27, restoring this arm also reddens N10b, whose fixture has
      ## annot_p < 0 and therefore reaches the selector below.
      set state noop
    } else {
      set cand [cadence::_annot_raw_candidate]
      set path [lindex $cand 0]
      set lvl  [lindex $cand 1]
      if {[lindex $cand 2] eq {stale}} {
        ## issue 0838. The path is REPORTED (the user needs to know which file
        ## was refused) but nothing is loaded and the mask, already written
        ## above, simply renders the `-` placeholders invariant I3 asks for.
        set state stale
      } elseif {$path eq {}} {
        set state nopath
      } elseif {![file exists $path]} {
        set state noraw
      } else {
        if {$lvl ne {} && [string is integer -strict $lvl]} {
          catch {xschem annotate_op $path $lvl}
        } else {
          catch {xschem annotate_op $path}
        }
        ## RE-ASKED, never taken from annotate_op's rc: measured, it returns 0
        ## for a file that does not exist and for one that will not parse.
        set after -1
        catch {set after [xschem raw loaded]}
        if {[string is integer -strict $after] && $after >= 0} {
          ## ⚠ RULING 0856, THE SECOND ASK, AND THE FIRST ONE CANNOT COVER IT.
          ## The gate at the top of this proc runs BEFORE any search: with
          ## nothing attached `_annot_op_db_ok` deliberately answers yes, so
          ## that `6` can still go and find a file (row V31b leg 2). But the
          ## file it finds is very often the transient the user just ran, and
          ## the branch above has now LOADED it. Measured before this arm
          ## existed: one Alt-6 on a sheet with `$netlist_dir/<cell>.raw` a
          ## transient wrote mask 2, attached the transient and said
          ## "OP annotation ON (node voltages) -- loaded <that transient>" --
          ## byte for byte the defect issue 0872 was filed about, one key press
          ## from the most ordinary desktop state there is.
          ##
          ## ⚠ AND update_op()'s OWN GUARD IS NOT A BACKSTOP FOR THIS. That guard
          ## (src/save.c) only declines to PUBLISH the operating point. It does
          ## not stop the mask being written, it does not stop the sentence
          ## being minted, and it does not stop raw_read()'s tail gate
          ## publishing at cursor B on this very load -- so on a sheet carrying
          ## a waveform strip with cursor B live, the transient's sample lands
          ## on the pins under a status line calling it OP node voltages.
          ##
          ## ⚠ IT UNWINDS, IT DOES NOT REFUSE EARLIER. The tempting shortcut --
          ## making the first gate say no when nothing is attached -- breaks the
          ## chord's ability to find a raw at all: measured, it reds V31b and
          ## five section-N rows, because pressing `6` with nothing loaded must
          ## still search, still load, and still name the file it could not
          ## find. So the search runs, and what it landed is put back.
          ##
          ## THE UNWIND IS BOTH HALVES. The mask goes back to what the user had
          ## (`$cur`, never a bare 0 -- a press must not clear bits the press
          ## did not set), and the database this proc attached ITSELF is
          ## detached. Leaving it attached is not "nothing": the waveform
          ## viewer would suddenly hold data the user never loaded, and cursor
          ## motion would start publishing from it. We are only here because
          ## `xschem raw loaded` was < 0 on entry, so the clear returns the
          ## session to exactly the state the key press found.
          if {![cadence::_annot_op_db_ok]} {
            catch {xschem raw clear}
            catch {xschem set annot_show $cur}
            catch {xschem update_all_sym_bboxes}
            catch {xschem redraw}
            return
          }
          set state loaded
        } else {
          set state failed
        }
      }
    }

    ## Only when NOTHING here can be annotated is the descriptor clause news.
    set scan [cadence::_annot_scan]
    if {[lindex $scan 0] == 0} { set types [lindex $scan 1] }
  }

  ## The `Show hidden texts` pair (src/xschem.tcl:15036): bboxes change when
  ## hidden texts appear, and annot_show_sync_cache() rides inside the first.
  catch {xschem update_all_sym_bboxes}
  catch {xschem redraw}

  ## LAST, so nothing above can overwrite it, and HELD so pointer motion cannot.
  catch {xschem statusmsg -hold [cadence::_annot_msg $mask $state $path $types]}
  return
}

# ===========================================================================
# ISSUE 0868 -- ON-REQUEST TRANSIENT NODE-VOLTAGE ANNOTATION AT THE WAVEFORM
#               CURSOR. The FOURTH chord, and the ASE-L menu entry beside it.
# ===========================================================================
# The user's request, verbatim 2026-08-26:
#
#   "MUST ONLY HAPPEN WHEN USER REQUESTS IT!! Alt-6 and 6 are for OP info and OP
#    node voltages. We can add a menu item in Results > Annotate for annotating
#    TRAN node voltages for time-point given by cursor B, or A - whatever the
#    convention is - if there is only one cursor in the waveform viewer's active
#    tab, use that. If A and B are there, then use cursor-A. Give user a way to
#    enter this mode with a different shortcut through cadence_style_rc - maybe
#    Alt-Shift-6"
#
#      Alt-Shift-6 -> cadence::annot_tran   annot_show |= 4   (ANNOT_SHOW_TRAN)
#
# ⚠ IT IS NOT A SPELLING OF `annot_mode`, AND `_annot_mask` IS DELIBERATELY NOT
# TOUCHED -- `tran` still raises there. The three OP chords are pure mask
# arithmetic: they turn a rendering switch on and the numbers were already
# published. This one PUBLISHES: it resolves a time point, hands it to the
# engine, and only then arms its bit. Folding it into the mask table would make
# `cadence::annot_mode tran` look like a peer of `opvolt` while being a
# fundamentally different operation, and it would lose the refusal states.
#
# ⚠ THE MASK IS ARMED LAST (guard G13). A mode armed before a publish that then
# refuses leaves the user looking at an armed mode over the PREVIOUS request's
# numbers -- RULING D5-1 with an extra step. Rows V14/V15/V16 of
# tests/headless/test_op_annot.tcl each assert "and the mask never gained bit2".
#
# ⚠ THE SNAPSHOT IS HELD, AND THE SENTENCE IS WHAT KEEPS IT HONEST. After a
# successful request the number stays on the sheet while the cursor moves on --
# the mode is a snapshot, not a live follow (that is the Live-annotate box, and
# it is a different feature). So the `ok` sentence NAMES THE TIME POINT AND THE
# CURSOR LETTER: under RULING D5-1 an undated number is the defect, and the
# provenance is the only thing that makes a held one truthful. Recorded as an
# unratified decision in doc/claude/issues/0868-*.md.
# ---------------------------------------------------------------------------

## -> {t which src} -- the time point to annotate at, the cursor letter it came
## from and where it was read -- or {} when NO cursor is on anywhere.
##
## ⚠ THE USER'S RULE, IN ORDER: "if there is only one cursor in the waveform
## viewer's active tab, use that. If A and B are there, then use cursor-A."
## So A wins whenever it is on, and B is used only when A is not. Row V11 of
## tests/headless/test_op_annot.tcl is the ONLY row that can tell a
## rule-honouring build from a B-preferring one; V12 and V13 stay green under
## both, by construction.
##
## ⚠ READ THE SUBJECT OF THE USER'S SENTENCE: "the waveform VIEWER'S active
## tab", not the schematic's own graph cursors. The viewer keeps its cursors in
## its OWN xschem context and mirrors which of them are on in
## wviewer::cva / wviewer::cvb, keyed BY TOKEN -- and the tab stash keys every
## per-view array on the token, so reading them describes the ACTIVE TAB by
## construction and there is no separate "which tab" question to get wrong.
## Positions are per-context reads, so the context has to be BORROWED, exactly
## as wviewer::readout_refresh (src/wave_viewer.tcl) borrows it for the readout
## bar, which is the shipped caller this copies.
##
## ⚠ THE BORROW ALWAYS GIVES THE CONTEXT BACK, and the reads are bracketed in a
## `catch` so a throw cannot escape past leave_ctx. A borrow that entered and
## never left would strand the user in the waveform window's context with the
## schematic still on screen -- issue 0173's exact shape, from a path nobody
## would think to look at. Row B12b of tests/headless/test_annot_show_menu.tcl
## greps this body for both halves; row B12 is the only behavioural row in the
## tree that can see the borrow at all, because headless there is no viewer.
##
## THE FALLBACK IS THE CURRENT CONTEXT'S OWN GRAPH CURSORS, and it is not a
## consolation prize: it is what makes the mode work for a plain xschem user
## with a graph on the sheet and no ASE session, and it is the only arm a
## headless row can construct. `xschem get graph_flags` bit1 (2) is cursor A and
## bit2 (4) is cursor B -- measured 0 / 2 / 4 / 6 for none / A / B / both.
proc cadence::_annot_tran_cursor {} {
  set key {}
  if {[llength [info commands ::ase::session_for_current]]} {
    catch {set key [lindex [::ase::session_for_current] 0]}
  }
  if {$key ne {} && [llength [info commands ::wviewer::enter_ctx]] &&
      [llength [info commands ::wviewer::leave_ctx]] &&
      [llength [info commands ::wviewer::window_for]]} {
    set top {}
    catch {set top [::wviewer::window_for $key]}
    set live 0
    catch {set live [expr {$top ne {} && [winfo exists $top]}]}
    if {$live} {
      set va 0 ; set vb 0
      catch {set va [expr {[info exists ::wviewer::cva($key)] && $::wviewer::cva($key)}]}
      catch {set vb [expr {[info exists ::wviewer::cvb($key)] && $::wviewer::cvb($key)}]}
      if {$va || $vb} {
        set ticket [::wviewer::enter_ctx $key]
        if {[lindex $ticket 0]} {
          set xa {} ; set xb {}
          catch {
            if {$va} { catch {set xa [xschem get cursor1_x]} }
            if {$vb} { catch {set xb [xschem get cursor2_x]} }
          }
          ::wviewer::leave_ctx $key $ticket
          if {$va && $xa ne {}} { return [list $xa A viewer] }
          if {$vb && $xb ne {}} { return [list $xb B viewer] }
        }
      }
    }
  }
  set fl 0
  catch {set fl [xschem get graph_flags]}
  if {![string is integer -strict $fl]} { set fl 0 }
  if {$fl & 2} {
    set x {}
    catch {set x [xschem get cursor1_x]}
    if {$x ne {}} { return [list $x A sheet] }
  }
  if {$fl & 4} {
    set x {}
    catch {set x [xschem get cursor2_x]}
    if {$x ne {}} { return [list $x B sheet] }
  }
  return {}
}

## THE ONE MINT (RULING D5-4): every user-facing sentence of the transient mode
## is built here and RENDERED by callers -- the chord, the ASE-L menu entry, the
## CIW line and the held status line all pass through this proc. A second
## `statusmsg` string composed inside a menu body is the shape this forbids, and
## row V18 of tests/headless/test_op_annot.tcl greps every other candidate file
## for these strings and requires zero.
##
## SIX STATES, DISTINGUISHABLE BY NAME so the caller can act on the cause and
## the user is told which one it was. Issue 0857's ruling, verbatim: "if OP has
## been run but we don't have device info, and user is wanting to annotate by
## pressing 6, then, yes, we want to say something in the CIW." The same applies
## to every way this mode can decline.
##   ok         published -- names the time point AND the cursor letter
##   okclamped  published, but the cursor is OUTSIDE the data and the boundary
##              sample was held (RULING D4-4) -- names the time the number was
##              MEASURED at first, then where the cursor actually is, then why
##              the two differ
##   nocursor   no cursor is on anywhere, so there is no time to annotate at
##   noraw      no database is attached to this sheet
##   notran     a database is attached but it is not a transient analysis
##   nodata     the engine had nothing to resolve the request against
##
## ⚠ `okclamped` IS ISSUE 0869, AND IT IS RULING D5-1 (issue 0869). The shipped
## `ok` sentence rendered the REQUESTED time unconditionally: with the last
## sample at 4e-09 and cursor B parked at 4.5e-09 the sheet painted `d 4` -- the
## correct held boundary value -- beside "Transient annotation at t = 4.5e-09",
## a number presented as measured for a time it was never measured at, and worse
## than a bare wrong number because the sentence lends it authority.
##
## ⚠ AND ISSUE 0869's OWN RECOMMENDED OPTION 1 IS MEASURABLY WRONG, which is why
## it was not taken. It says "render the annotated point's own x". Measured over
## the whole sweep, that x reads 2e-09 for a requested 3e-09 whose painted number
## genuinely IS the interpolated value at 3e-09 -- a fresh D5-1 breach in the
## opposite direction, and it reds row V2's premise. In range the shipped
## arithmetic really does return the value AT the requested time, so the two
## times are the same number and the SHIPPED sentence stays byte-identical; only
## out of range do they differ, and only there does this sixth state appear.
## Row V26b is the in-range control that reds an unconditional clause.
##
## ⚠ THE `req` PARAMETER IS OPTIONAL SO THE FIVE SHIPPED CALLERS DO NOT MOVE.
## They pass three arguments, exactly as before; row V27 re-asserts all five
## through the widened signature for that reason, and V17 is left untouched.
##
## ⚠ AN UNKNOWN STATE RAISES, and names it. `_annot_msg`'s own discipline (row
## N2): op_annot blanks for missing DATA (invariant I3), but a state spelling is
## a CALLER bug, and a caller bug that renders as a polite apology is exactly the
## silence this mode exists to remove.
proc cadence::_annot_tran_msg {state t which {req {}}} {
  switch -exact -- $state {
    ok       { return "Transient annotation at t = $t (cursor $which)" }
    okclamped { return "Transient annotation at t = $t (cursor $which at $req,\
                        outside the data -- holding the boundary sample)" }
    nocursor { return "Transient annotation -- NO CURSOR: turn on cursor A or B\
                       in the waveform viewer" }
    noraw    { return "Transient annotation -- NO RAW FILE loaded" }
    notran   { return "Transient annotation -- the loaded database is not a\
                       transient analysis" }
    nodata   { return "Transient annotation -- nothing to annotate at t = $t" }
  }
  error "cadence::_annot_tran_msg: unknown state \"$state\":\
         use ok, okclamped, nocursor, noraw, notran or nodata"
}

## THE TIME THE PAINTED NUMBER WAS ACTUALLY MEASURED AT, or {} when it cannot
## be established. Issue 0869: the sentence must name THIS, not the time the
## user's cursor happened to be parked at, whenever the two differ.
##
## ⚠ NO C CHANGE IS NEEDED AND NONE WAS MADE. Three already-shipped calls:
##   `xschem raw annot`          -> {annot_p annot_x annot_sweep_idx}
##   `xschem raw list`           -> the column names, newline separated
##   `xschem raw value <sw> -1`  -> point -1 falls through to cursor_b_val[],
##                                  which is the requested time already clamped
##                                  into the data's own span (RULING D4-6)
## A reader would otherwise assume `annot_x` -- the second element, which is
## right there -- is the answer. It is NOT: `annot_x` is the REQUESTED time, the
## very number issue 0869 is about.
##
## ⚠ EVERY STEP IS CAUGHT AND THE FAILURE RETURNS {}, NOT A NUMBER. The caller
## treats {} as "cannot tell" and mints the shipped `ok` sentence, which names
## the requested time and nothing else. That degrades to today's behaviour; what
## it must never do is invent a time, which is the D5-1 defect this fixes.
proc cadence::_annot_tran_efft {} {
  set a {}
  if {[catch {xschem raw annot} a]} { return {} }
  if {[llength $a] != 3} { return {} }
  if {![string is integer -strict [lindex $a 0]] || [lindex $a 0] < 0} { return {} }
  set names {}
  if {[catch {xschem raw list} names]} { return {} }
  set sw [lindex [split $names "\n"] [lindex $a 2]]
  if {$sw eq {}} { return {} }
  set v {}
  if {[catch {xschem raw value $sw -1} v]} { return {} }
  if {![string is double -strict $v]} { return {} }
  return $v
}

## THE ONE EMITTER, and it is deliberately not a bare `catch {::ase::echo ...}`.
## ISSUE 0857 is about a chord that says NOTHING when it cannot deliver; a
## catch-and-discard would reproduce that defect precisely at the moment the
## message matters, on any session where the CIW is not up. So the sinks are
## tried in order and the last one always works.
##
## ⚠ THIS IS THE CHORD-SIDE CIW ROUTE ISSUE 0857's HALF 2 NEEDS. It is recorded
## in 0857 so that work renders through this rather than minting a second
## mechanism -- two channels for "the annotation chord could not deliver" is the
## drift invariant I1 forbids.
proc cadence::_annot_ciw {msg {tag {}}} {
  if {[llength [info commands ::ase::echo]]} {
    if {![catch {::ase::echo $msg $tag}]} { return 1 }
  }
  if {[llength [info commands ::xschem::notify]]} {
    if {![catch {::xschem::notify $msg}]} { return 1 }
  }
  catch {puts stderr $msg}
  return 0
}

## cadence::annot_tran -- THE ONE CODE PATH both entry points drive (the
## `Alt-Shift-6` chord in src/cadence_style_rc and the ASE-L
## `Results > Annotate > Transient Node Voltages (at cursor)` item in
## src/ase_window.tcl). Returns the state name, so a caller -- and a headless row
## -- can see the decision without reading a sink.
##
## ⚠ THE ORDER OF THE FIRST FOUR STEPS IS A GUARD, NOT A STYLE (G13). Every
## refusal returns with the mask UNTOUCHED and nothing published; the bit is
## armed only after the engine says it annotated. Rows V14/V15/V16 assert the
## mask on each refusal, and sabotage variant S13 -- moving the arm above the
## refusals -- must redden all three.
##
## ⚠ THE MASK IS PULLED THROUGH `xschem get annot_show`, never $::annot_show:
## the mask is PER-CONTEXT (xctx->annot_show), so under the tabbed interface the
## Tcl mirror belongs to whichever context wrote it last. Same reasoning as
## cadence::annot_mode above, and the same S7 decision D4 spelling for the write.
proc cadence::annot_tran {} {
  set cur [cadence::_annot_tran_cursor]
  if {![llength $cur]} {
    cadence::_annot_ciw [cadence::_annot_tran_msg nocursor {} {}] warn
    catch {xschem statusmsg -hold [cadence::_annot_tran_msg nocursor {} {}]}
    return nocursor
  }
  set t     [lindex $cur 0]
  set which [lindex $cur 1]

  ## ⚠ THE CONVERSE OF RULING 0856, AND IT IS A REFUSAL RATHER THAN A LIMIT.
  ## The user ruled that an operating-point surface must not show a transient's
  ## numbers; a TRANSIENT mode must not show an operating point's. Both
  ## detectors already exist -- `xschem raw loaded` answers -1 with nothing
  ## attached and `xschem raw sim_type` answers `op` / `dc` / `tran` -- so
  ## nothing new is invented here. `dc` and `ac` are NOT accepted: annotating at
  ## an x-axis value would be meaningful for them, but the user asked for TRAN
  ## and widening it is scope the request does not carry.
  set loaded -1
  catch {set loaded [xschem raw loaded]}
  if {![string is integer -strict $loaded] || $loaded < 0} {
    cadence::_annot_ciw [cadence::_annot_tran_msg noraw {} {}] warn
    catch {xschem statusmsg -hold [cadence::_annot_tran_msg noraw {} {}]}
    return noraw
  }
  set st {}
  if {[catch {xschem raw sim_type} st]} { set st {} }
  if {$st ne {tran}} {
    cadence::_annot_ciw [cadence::_annot_tran_msg notran {} {}] warn
    catch {xschem statusmsg -hold [cadence::_annot_tran_msg notran {} {}]}
    return notran
  }

  ## The engine resolves the time point against xctx->raw through the SHIPPED
  ## cursor arithmetic (invariant I1) -- so an out-of-range t holds the boundary
  ## sample, RULING D4-4, and a vector missing from the raw renders blank, I3.
  ## `xschem annotate_at` answers 0 when there was nothing to annotate against
  ## and the call was a byte-exact no-op.
  set rc 0
  if {[catch {xschem annotate_at $t} rc]} { set rc 0 }
  if {![string is integer -strict $rc]} { set rc 0 }
  if {!$rc} {
    cadence::_annot_ciw [cadence::_annot_tran_msg nodata $t $which] warn
    catch {xschem statusmsg -hold [cadence::_annot_tran_msg nodata $t $which]}
    return nodata
  }

  set mask 0
  catch {set mask [xschem get annot_show]}
  if {![string is integer -strict $mask]} { set mask 0 }
  xschem set annot_show [expr {$mask | 4}]

  ## The `Show hidden texts` pair (src/xschem.tcl): bboxes change when hidden
  ## texts appear, and annot_show_sync_cache() rides inside the first.
  catch {xschem update_all_sym_bboxes}
  catch {xschem redraw}

  ## LAST, so nothing above can overwrite it, and HELD so pointer motion cannot
  ## erase it (issue 0248). Both sinks: the CIW is where the user asked for it
  ## and the status line is where the three OP chords already speak.
  ## ⚠ ISSUE 0869, RULING D5-1: THE SENTENCE NAMES THE TIME THE NUMBER WAS
  ## MEASURED AT. Out of range the engine HOLDS the boundary sample (RULING
  ## D4-4 -- a boundary holds, it never extrapolates), which is correct
  ## behaviour; the defect was that the sentence went on naming the cursor's
  ## time regardless, so a `d 4` measured at 4e-09 was captioned 4.5e-09.
  ##
  ## ⚠ NEVER EXACT FLOAT EQUALITY, AND THAT IS NOT PEDANTRY. The effective time
  ## is read back through the SINGLE-PRECISION cursor_b_val[] array, so an
  ## in-range request comes back a few ULPs away from the double the caller
  ## sent and an `==` test would caption every ordinary annotation as clamped.
  ## The tolerance is RELATIVE, with an absolute floor so t = 0 works: 1e-6 is
  ## about 16x the worst single-precision relative error, and the only thing
  ## that can push the two further apart than that is the D4-4 clamp itself.
  ## Row V26b is the in-range control that reds a clause appended
  ## unconditionally, and sabotage S15b inverts this comparison.
  ##
  ## ⚠ THE STATE NAME RETURNED IS STILL `ok` IN BOTH CASES. `okclamped` is a
  ## wording of the same success, not a different outcome: rows V11/V12/V13 read
  ## this return value, `ase::ui::annot_apply` discards it, and the new
  ## information belongs in the sentence, where the user is.
  set te [cadence::_annot_tran_efft]
  if {$te ne {} && abs($te - $t) > 1.0e-6 * (abs($t) + abs($te) + 1.0e-30)} {
    set m [cadence::_annot_tran_msg okclamped $te $which $t]
  } else {
    set m [cadence::_annot_tran_msg ok $t $which]
  }
  cadence::_annot_ciw $m
  catch {xschem statusmsg -hold $m}
  return ok
}
