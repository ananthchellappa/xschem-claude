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
##   off | live | notlive | noop | loaded | failed | noraw | nopath
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
proc cadence::_annot_msg {mask state path types} {
  if {![string is integer -strict $mask]} { set mask 0 }
  switch -exact -- [expr {$mask & 3}] {
    0 { set m "OP annotation OFF" }
    1 { set m "OP annotation ON (device OP info)" }
    2 { set m "OP annotation ON (node voltages)" }
    3 { set m "OP annotation ON (device OP info + node voltages)" }
    default { set m "OP annotation" }
  }
  switch -exact -- $state {
    live    { append m " -- raw already loaded" }
    notlive { append m " -- a raw is loaded but backannotation is off\
                        (live_cursor2_backannotate 0)" }
    noop    { append m " -- a raw is loaded but it published no operating point:\
                        use Waves > Op Annotate, or `xschem raw_clear` then press\
                        again" }
    loaded  { append m " -- loaded $path" }
    failed  { append m " -- COULD NOT LOAD $path" }
    noraw   { append m " -- NO RAW FILE: $path" }
    nopath  { append m " -- NO RAW FILE for this cell" }
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
      ## ⚠ WHICH of _annotated's two remaining terms failed is ASKED, not assumed
      ## (issue 0459). Naming `live_cursor2_backannotate 0` unconditionally was
      ## measured FALSE on the shipped `Waves > Op` route: `xschem raw_read`
      ## leaves `raw loaded` 0 with `raw annot` -1 while the flag is 1, so the
      ## line accused a variable that was innocent and never named the real
      ## cause. A plausible wrong REASON is the same defect as save.c ruling
      ## D5-1's plausible wrong NUMBER, and this branch is a dead end — the
      ## guard above blocks the auto-load — so the way out is named too.
      set lv 1
      catch {set lv [uplevel #0 {set live_cursor2_backannotate}]}
      if {[catch {expr {$lv ? 1 : 0}} lvb]} { set lvb 1 }
      set state [expr {$lvb ? {noop} : {notlive}}]
    } else {
      set cand [cadence::_annot_raw_candidate]
      set path [lindex $cand 0]
      set lvl  [lindex $cand 1]
      if {$path eq {}} {
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
