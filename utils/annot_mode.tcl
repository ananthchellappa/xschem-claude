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

## Symbol types that are never devices, so naming them in "These symbol types
## have no operating-point values to show: ..." would be noise rather than news. `annotator` is the
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

## ===========================================================================
## ISSUE 0886 -- THE FOUR HELPERS THE PLAIN-ENGLISH PASS IS BUILT ON.
## ===========================================================================
## The user's ruling, verbatim 2026-08-27: "wording too cryptic. Give it in
## plain english with context, 9th grade level." Every sentence the two mints
## below render now says WHAT HAPPENED in the user's own nouns, gives the
## CONTEXT that makes it make sense and, wherever the user can act, says WHAT
## TO DO. These four are what make that possible without a second copy of
## anything: a time formatter, the menu-path deriver, the status-line budget,
## and the one renderer that puts a minted sentence on both sinks.

## A TIME, THE WAY AN ANALOG DESIGNER READS IT OFF AN X-AXIS: 4 ns, 30 us, 0 s.
##
## ⚠ IT REUSES `op_annot::eng_or_blank` RATHER THAN MINTING A SECOND FORMATTER
## (invariant I1). That helper emits NO unit letter -- 4e-09 comes back as `4n`
## -- so the `s` is appended here, and the SI prefix is split off the tail to
## land between the number and the unit. A reader would otherwise assume the
## helper already returns something printable beside a unit; it does not, and
## `4n s` is what you get if you assume it.
##
## ⚠ A VALUE THE FORMATTER CANNOT READ IS RETURNED UNCHANGED, NOT BLANKED, and
## that is the opposite of op_annot's own rule one layer down. Invariant I3
## blanks a MISSING measurement, which is right there -- the user is being told
## a number is not available. A time THIS proc cannot parse is a CALLER bug, and
## a caller bug that renders as an empty gap in a sentence is precisely the
## silence this whole mode exists to remove. Row A11-4 of
## tests/headless/test_op_annot.tcl is the only row that reaches this leg.
proc cadence::_annot_tsec {v} {
  set e {}
  catch {set e [::op_annot::eng_or_blank $v]}
  if {$e eq {}} { return $v }
  set last [string index $e end]
  if {[lsearch -exact {T G M k m u n p f a} $last] >= 0} {
    return "[string range $e 0 end-1] ${last}s"
  }
  return "$e s"
}

## THE MENU ENTRY THE `these results hold no operating point` SENTENCE SENDS THE
## USER TO, read from the menubar's own labels.
##
## ⚠ THE PATH IS DERIVED, NEVER TYPED (RULING D5-4).
## `annot_menu_path_waves_op` (src/xschem.tcl) composes it from the two label
## constants the menubar is BUILT from, so renaming the entry moves every
## printed path with it; issue 0661 is the measured example of that drift, one
## word apart and entirely plausible. Row A11-5 renames that mint and requires
## the new name to come back out of the sentence, which is the only way to tell
## a derived path from a hardcoded one that happens to be spelled right today.
##
## ⚠ THE LITERAL BELOW IS THE FALLBACK for a session that never loaded
## src/xschem.tcl's menu labels, and it is THE ONLY COPY OF IT IN THIS FILE.
## Row A11-6 greps for exactly that, and it is the row that survives someone
## deleting A11-5. Do not paste the path into a sentence; call this.
proc cadence::_annot_menu_op {} {
  set p {Waves > Op Annotate}
  catch {set p [::annot_menu_path_waves_op]}
  return $p
}

## THE STATUS LINE HOLDS 255 BYTES, AND THIS IS THE ONE PLACE THAT KNOWS IT.
##
## ⚠ ISSUE 0639, AND THE OVERFLOW WAS ALREADY LIVE BEFORE A WORD WAS
## REWRITTEN. Measured on the shipped binary 2026-08-27: the widest annotation
## mask, the no-operating-point state and five symbol types built a 257
## character line, `xschem get statusmsg` read back 255, and the tail died
## mid-token -- `nmos pmos res cap ...` arrived as `cap .`.
##
## ⚠ THE WALL IS A BYTE COUNT, NOT A CHARACTER COUNT, AND THE DIFFERENCE IS
## USER DATA. The C side stores the line in statusmsg_text[256] (src/xschem.h)
## and `my_strncpy` fills it in BYTES. An earlier revision of this proc counted
## Tcl CHARACTERS and justified it by noting that every sentence minted here is
## plain printable ASCII -- which is true of the WORDING and false of the
## sentence, because three of the eight states paste the user's own results-file
## path into it. A designer whose project lives under an accented or non-Latin
## directory therefore built a line of 251 characters and 281 bytes; this proc
## waved it through, C cut it at 255 bytes, and the amputation was back with no
## `...` to show for it -- measured 2026-08-28, and the reason row A11-9 exists.
## `cadence::_annot_bytes` is now the only ruler either half uses.
##
## ⚠ IT CUTS AT A SPACE AND MARKS THE CUT. The shipped defect was a sentence
## that stopped mid-word with nothing saying it had. A reader would otherwise
## assume a plain `string range` is enough; a plain `string range` is what
## produced `cap .`.
##
## ⚠ ONLY THE STATUS LINE IS TRIMMED. `cadence::_annot_say` writes the WHOLE
## sentence to the CIW, which is the record and which scrolls, and the fitted
## copy to the bar. Rows A11-1, A11-2 and A11-10 hold that split honest.
## The length the C side will see, in the units the C side counts.
##
## ⚠ `string bytelength` IS THE FAITHFUL ONE ON Tcl 8.6, and it is gone in
## Tcl 9. It reports the modified-UTF-8 form `Tcl_GetString` really hands over,
## surrogate pairs and all; `encoding convertto utf-8` under-counts a non-BMP
## character by two bytes on 8.6. The fallback is there so this file still loads
## on a Tcl that removed the command, where the two forms agree anyway.
proc cadence::_annot_bytes {s} {
  if {![catch {string bytelength $s} n]} { return $n }
  return [string length [encoding convertto utf-8 $s]]
}

proc cadence::_annot_fit {m} {
  set n [string length $m]
  if {[cadence::_annot_bytes $m] <= 255} { return $m }
  ## Shrink a CHARACTER window until what it holds fits 252 BYTES, leaving
  ## three for the marker. `string range` cannot split a character, so the
  ## window boundary is always a legal place to stop.
  if {$n > 252} { set n 252 }
  while {$n > 0 && [cadence::_annot_bytes [string range $m 0 [expr {$n - 1}]]] > 252} {
    incr n -1
  }
  set cut [string last { } [string range $m 0 [expr {$n - 1}]]]
  if {$cut < 1} { set cut $n }
  return "[string range $m 0 [expr {$cut - 1}]]..."
}

## THE ONE RENDERER: a minted sentence, onto both sinks the annotation surface
## speaks through.
##
## ⚠ THE TWO SINKS DIFFER IN ONE WAY ONLY, DELIBERATELY. The CIW gets the
## sentence WHOLE; the held status line gets it through `cadence::_annot_fit`.
## Issue 0639's unmade choice is made here: nothing is dropped from the record,
## and the bar shows a marked elision instead of an amputation. Recorded as an
## unratified decision -- `owed.sh add rule 0886`.
##
## ⚠ `cadence::_annot_ciw` STAYS THE ONE EMITTER beneath this (invariant I1).
## This proc adds the status-line half; it does not become a second channel.
## Issue 0873's property -- muting the CIW must redden at least one row -- is
## measured against that emitter and is untouched by this.
##
## ⚠ `-hold`, NOT A PLAIN STATUS LINE WRITE: pointer motion erases an unheld
## line before the user has finished reading it (issue 0248).
proc cadence::_annot_say {m {tag {}}} {
  cadence::_annot_ciw $m $tag
  catch {xschem statusmsg -hold [cadence::_annot_fit $m]}
}

## The one held status line. <state> is one of
##   off | live | noop | loaded | failed | noraw | nopath
## and <types> is _annot_scan's second element, already known to matter only
## when NOTHING on the sheet was annotatable.
##
## Both first-run confusions land in the SAME line (decision D5). The descriptor
## clause is omitted when the sheet carries no candidate device at all, because
## "These symbol types have no operating-point values to show:" with nothing
## after it says less than silence.
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
##
## ⚠ AND ISSUE 0886 RE-WORDED ALL EIGHT, WHICH IS WHY THE PARAGRAPHS ABOVE READ
## AS HISTORY. "OP annotation OFF" and its seven relatives are gone; the arms now
## say what is on the schematic in the user's own words -- "Annotation is off. The
## schematic is not showing simulation numbers.", "Showing device operating-point
## values on the schematic.", and so on, worded off the user's ratified
## `Results > Annotate` labels. The user's ruling, verbatim 2026-08-27: "wording
## too cryptic. Give it in plain english with context, 9th grade level." The
## REASONING above is untouched -- what each arm has to be true ABOUT did not
## change -- and row V21 still asserts all eight, byte for byte.
proc cadence::_annot_msg {mask state path types} {
  ## ⚠ ISSUE 0857, RULED BY THE USER 2026-08-27, VERBATIM: "Yes, 6 does
  ## nothing when there is ONLY a TRAN result. But, it's a good idea to say
  ## 'No OP results available' in the CIW." So RULING 0856's "do nothing"
  ## keeps standing for the SCREEN -- nothing published, no bit armed, no
  ## number painted -- and stops standing for the user, who was left holding a
  ## key that looked broken. `cadence::annot_mode`'s TWO silent returns render
  ## this state; nothing else does.
  ##
  ## ⚠ IT RETURNS BEFORE THE MASK SWITCH, AND THAT IS THE POINT, NOT AN
  ## OPTIMISATION. Every other sentence in this proc opens with "Showing ..."
  ## or "Annotation is off ..." (issue 0886's wording; it was
  ## "OP annotation ON/OFF (...)" before), which is a claim about what the
  ## screen is now showing. On both refusal paths the mask is never written, or is
  ## written and put straight back, so that prefix would describe a change that
  ## did not happen -- RULING D5-1's shape, a caption with no measurement
  ## behind it. A reader who assumed every arm of this proc carries the prefix
  ## would be wrong here, deliberately.
  ##
  ## ⚠ `path` CARRIES THE ANALYSIS TYPE FOR THIS STATE ONLY -- `tran`,
  ## `ac`, whatever `xschem raw sim_type` answered -- and not a file path. Two
  ## shapes, ONE arm (RULING D5-4): the type is named when the attached
  ## database can say what it is, and left out when it cannot, because
  ## "the results loaded here are a '' analysis" says less than silence. Row
  ## V42 of tests/headless/test_op_annot.tcl pins both shapes byte for byte,
  ## and row V43 requires the fragment "No operating point results are loaded"
  ## to appear on a code line of THIS file and of no other -- so the sentence
  ## below is grep-visible on purpose. (Issue 0886 moved that fragment one word:
  ## it read "... results available" until the plain-English pass.)
  if {$state eq {notop}} {
    if {$path eq {}} {
      return "No operating point results are loaded. The results loaded here are\
              not an operating point, so there are no operating-point numbers to\
              show. Run an operating point analysis, or press Alt-Shift-6 for\
              node voltages at the waveform cursor."
    }
    return "No operating point results are loaded. These are from a '$path' run\
            instead, so there are no operating-point numbers to show. Run an\
            operating point analysis, or press Alt-Shift-6 for node voltages at\
            the waveform cursor."
  }
  if {![string is integer -strict $mask]} { set mask 0 }
  switch -exact -- [expr {$mask & 7}] {
    0 { set m "Annotation is off. The schematic is not showing simulation\
               numbers." }
    1 { set m "Showing device operating-point values on the schematic." }
    2 { set m "Showing DC node voltages on the schematic." }
    3 { set m "Showing device operating-point values and DC node voltages on the\
               schematic." }
    4 { set m "Showing node voltages at the waveform cursor on the schematic." }
    5 { set m "Showing device operating-point values, and node voltages at the\
               waveform cursor, on the schematic." }
    6 { set m "Showing DC node voltages, and node voltages at the waveform\
               cursor, on the schematic." }
    7 { set m "Showing device operating-point values, DC node voltages, and node\
               voltages at the waveform cursor, on the schematic." }
    default { set m "Annotation settings changed." }
  }
  switch -exact -- $state {
    live    { append m " These results were already loaded." }
    noop    { append m " The loaded results do not include an operating point, so\
                        there are no device values to show. Load a different\
                        results file from [cadence::_annot_menu_op], then press\
                        again." }
    loaded  { append m " Loaded results from $path." }
    failed  { append m " Could not read the results file $path, so nothing was\
                        placed on the schematic." }
    noraw   { append m " There is no results file at $path yet. Run a simulation\
                        first." }
    nopath  { append m " No results file has been found for this cell. Run a\
                        simulation first." }
    stale   { append m " The results file [file tail $path] is older than the circuit it describes,\
                        so it was not used - it is from an earlier run. Run the\
                        simulation again." }
  }
  if {$state ne {off} && [llength $types]} {
    set shown $types
    set tail {}
    if {[llength $types] > 4} {
      set shown [lrange $types 0 3]
      set tail { and more}
    }
    append m " These symbol types have no operating-point values to show:\
              [join $shown {, }]$tail."
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
  ##
  ## ⚠ IT IS NO LONGER A SILENT RETURN, AND THE USER IS WHY (issue 0857,
  ## ruled 2026-08-27). Nothing is published, no bit is armed and no number is
  ## painted -- RULING 0856 is untouched -- but the press now SAYS which of the
  ## two things happened instead of leaving a key that appears dead. The
  ## sim_type is read HERE, before anything else runs, because it is the only
  ## thing that lets the sentence name the analysis the user actually has.
  ##
  ## ⚠ BOTH SINKS, NOT THE CIW ALONE. The user's words were "say something
  ## in the CIW", and the CIW is where a person running ASE-L looks -- but the
  ## three OP chords have always spoken on the held status line, and a plain
  ## xschem user with no ASE-L window open would see a CIW-only sentence not at
  ## all. `cadence::_annot_ciw` is the ONE emitter (invariant I1); this is its
  ## first call site outside `cadence::annot_tran`. Recorded as an unratified
  ## decision -- `owed.sh add rule 0857`.
  if {$mask != 0 && ![cadence::_annot_op_db_ok]} {
    set st {}
    if {[catch {xschem raw sim_type} st]} { set st {} }
    cadence::_annot_say [cadence::_annot_msg $cur notop $st {}] warn
    return
  }

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
      ## indistinguishable cause. Saying "These results were already loaded."
      ## would be a lie about a blank block, and reloading would throw away a
      ## good file. (Issue 0886: that clause read "-- raw already loaded"
      ## before the plain-English pass.)
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
          ##
          ## ⚠ AND IT SPEAKS NOW (issue 0857, ruled 2026-08-27). The three
          ## unwind statements below are byte-for-byte what they were, because
          ## they are what RULING 0856 asks for and sabotage S18 deletes them
          ## to check that row V31c still sees it. What is added is the
          ## sentence: the user pressed a key, the program went and found a
          ## file, decided it was the wrong kind and put everything back, and
          ## until now said nothing about any of it.
          ##
          ## ⚠ THE ANALYSIS TYPE IS READ BEFORE THE CLEAR. After
          ## `xschem raw clear` the accessor RAISES "No raw file loaded", so a
          ## sentence minted after the unwind could only ever be the typeless
          ## shape -- it would have thrown away the one fact that makes the
          ## line worth reading. Row V31c golds the named shape on all four
          ## legs, which is what pins this ordering.
          if {![cadence::_annot_op_db_ok]} {
            set st {}
            if {[catch {xschem raw sim_type} st]} { set st {} }
            catch {xschem raw clear}
            catch {xschem set annot_show $cur}
            catch {xschem update_all_sym_bboxes}
            catch {xschem redraw}
            cadence::_annot_say [cadence::_annot_msg $cur notop $st {}] warn
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
  catch {xschem statusmsg -hold [cadence::_annot_fit [cadence::_annot_msg $mask $state $path $types]]}
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
## than a bare wrong number because the sentence lends it authority. (That is the
## PRE-0886 spelling, quoted as it was measured. Both sentences were rewritten by
## the plain-English pass and now read the time as 4.5 ns; the defect and the fix
## are unchanged.)
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
    ok       { return "Showing each node's voltage at [cadence::_annot_tsec $t],\
                       where cursor $which is on the waveform." }
    okclamped { return "Cursor $which is at [cadence::_annot_tsec $req], outside\
                        the time range of the run. Showing each node's voltage at\
                        [cadence::_annot_tsec $t], the closest point that was\
                        actually measured." }
    nocursor { return "Turn on cursor A or cursor B in the waveform window first.\
                       The schematic then shows each node's voltage at the time\
                       that cursor marks." }
    noraw    { return "No simulation results are loaded, so there are no voltages\
                       to show. Run a simulation first, then try again." }
    notran   { return "These results are not from a transient run, so there is no\
                       time axis to read a voltage at. Run a transient simulation\
                       to use this." }
    nodata   { return "The results have no values at [cadence::_annot_tsec $t], so\
                       nothing was placed on the schematic." }
    staleraw { return "The results file [file tail $req] is older than the circuit it describes,\
                       so it was not used - it is from an earlier run. Run the\
                       simulation again, then try again." }
    viewerdiff { return "The results file [file tail $req] on disk is from a different simulation run\
                       than the one the waveform window is showing, so nothing was\
                       placed on the schematic. Plot the results again in the\
                       waveform window, then try again." }
  }
  error "cadence::_annot_tran_msg: unknown state \"$state\":\
         use ok, okclamped, nocursor, noraw, notran, staleraw, viewerdiff or nodata"
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

## -> the CURRENT window's database reduced to something two windows can be
## COMPARED on, or {} when there is nothing to reduce. Five elements: the
## analysis type, the dataset count, the point count, the column names and
## every column's value at the LAST point.
##
## ⚠ THIS IS A COMPARATOR, NOT A CHECKSUM, and the difference matters to the
## reader. It is computed in whichever window it is called in, through the
## SHIPPED read-only verbs and nothing else, so the same file read twice into
## two windows prints the same list and two different RUNS of the same deck
## print different ones. The last point is where a re-run shows up most
## reliably -- a longer or shorter sweep moves the point count, a changed
## supply or device moves the final sample of nearly every node.
##
## ⚠ COST, because it runs on a key press. One `xschem raw list` plus one
## `xschem raw value` per column, per window. Those are hash lookups into an
## array already in memory; there is no disk access and no re-parse.
proc cadence::_annot_db_print {} {
  set out {}
  set v {}
  if {[catch {xschem raw sim_type} v]} { return {} }
  lappend out $v
  if {[catch {xschem raw datasets} v]} { return {} }
  lappend out $v
  set np 0
  if {[catch {xschem raw points} np]} { return {} }
  if {![string is integer -strict $np] || $np < 1} { return {} }
  lappend out $np
  set names {}
  if {[catch {xschem raw list} names]} { return {} }
  set names [split [string trimright $names "\n"] "\n"]
  lappend out $names
  set last [expr {$np - 1}]
  set vals {}
  foreach n $names {
    set x {}
    catch {set x [xschem raw value $n $last]}
    lappend vals $x
  }
  lappend out $vals
  return $out
}

## -> {path print} for the transient the WAVEFORM VIEWER is showing for this
## sheet's session, or {} when there is no viewer, it holds nothing, or what it
## holds is not a transient.
##
## ⚠ ISSUE 0881, AND IT IS THE HALF THE MODE WAS MISSING. The user's words,
## verbatim 2026-08-27: "The info should already be available -- it's been
## loaded to display waveforms in the waveform viewer." The other half of this
## mode already crosses the window boundary correctly -- the cursor resolver
## borrows the viewer's context to read cursor A -- and this is the same borrow
## asked a different question. Without it the supplier could only REBUILD a
## path out of the preferences, so a viewer showing a file that lives anywhere
## else got the user's original complaint back with a new sentence on it.
##
## ⚠ THE BORROW ALWAYS GIVES THE CONTEXT BACK, same discipline and same reason
## as `cadence::_annot_tran_cursor`: a borrow that entered and never left would
## strand the user in the waveform window's context with the schematic still on
## screen, which is issue 0173's shape from a path nobody would look at.
##
## ⚠ THE Tk PROBE IS ASKED ONLY WHERE Tk EXISTS. `winfo` is absent under
## --nogui, so an unconditional `winfo exists` would make this arm unreachable
## to every headless row and the feature would be pinned on the Tk suite alone.
## `wviewer::enter_ctx` refuses an unregistered token on its own -- it answers a
## ticket of 0 -- so the ticket, not the widget, is the authority here.
##
## ⚠ ONLY A TRANSIENT IS OFFERED. A viewer switched to a digital database or to
## an operating point must not divert the supply: this returns {} and the
## session's own candidate is used, which is the behaviour every row before
## this item asserted.
proc cadence::_annot_viewer_db {} {
  set key {}
  if {[llength [info commands ::ase::session_for_current]]} {
    catch {set key [lindex [::ase::session_for_current] 0]}
  }
  if {$key eq {}} { return {} }
  if {![llength [info commands ::wviewer::enter_ctx]] ||
      ![llength [info commands ::wviewer::leave_ctx]] ||
      ![llength [info commands ::wviewer::window_for]]} { return {} }
  set top {}
  catch {set top [::wviewer::window_for $key]}
  if {$top eq {}} { return {} }
  if {[llength [info commands ::winfo]]} {
    set live 0
    catch {set live [winfo exists $top]}
    if {!$live} { return {} }
  }
  set ticket [::wviewer::enter_ctx $key]
  if {![lindex $ticket 0]} { return {} }
  set path {}
  set print {}
  catch {
    set ld -1
    catch {set ld [xschem raw loaded]}
    if {[string is integer -strict $ld] && $ld >= 0} {
      set st {}
      catch {set st [xschem raw sim_type]}
      if {$st eq {tran}} {
        catch {set path [xschem raw rawfile]}
        set print [cadence::_annot_db_print]
      }
    }
  }
  ::wviewer::leave_ctx $key $ticket
  if {$path eq {} || ![file exists $path]} { return {} }
  return [list $path $print]
}

## -> {loaded state path} -- what the CURRENT window holds after this proc has
## tried to supply it, the reason when it could not, and the file it reached
## for. `loaded` is `xschem raw loaded`'s own answer, RE-ASKED; `state` is one
## of ok | noraw | stale.
##
## ⚠ ISSUE 0881, AND THE USER REPRODUCED IT AT THEIR OWN BENCH 2026-08-27,
## VERBATIM: "I do a TRAN run and then Alt-Shift-6 and Results > Annotate >
## Transient Node.. don't annotate anything onto the schematic - yes, there is
## the 'Transient annotation -- NO RAW ..' message.. - bad. Given that results
## are being loaded and plotted, we have enough info to satisfy user intent.
## The ultimate goal of any UI is to satisfy user intent." And: "The info
## should already be available - it's been loaded to display waveforms in the
## waveform viewer."
##
## ⚠ WHAT A READER WOULD OTHERWISE ASSUME: that `xschem raw loaded` is a
## question about the session. IT IS NOT -- it is a question about the CURRENT
## WINDOW. The waveform viewer attaches the run's results to its OWN window's
## context on purpose: `wviewer::attach_raw` (src/wave_viewer.tcl) calls
## `wviewer::switch_ctx` FIRST, commented "never clear a foreign ctx", and only
## then hands the file to `ase::attach_dbs`. So on a real bench the viewer's
## window holds the transient and the schematic window holds nothing, and the
## refusal this proc replaces was reading the wrong window's answer. Half of
## this mode ALREADY crosses that boundary correctly -- the cursor resolver
## borrows the viewer's context to read cursor A -- so the defect was one
## asymmetry, not a missing feature.
##
## ⚠ IT ASKS THE VIEWER WHICH FILE, THEN SUPPLIES THE SCHEMATIC WINDOW WITH
## THAT FILE. Both halves are load-bearing and the first one is the fix.
## There is no cross-window raw registry in the C engine (checked), so the
## numbers cannot be painted on the sheet without a database attached to the
## SHEET's window -- `annotate_at` resolves against xctx->raw of the window it
## is called in. But a supplier that only knew how to REBUILD a path from the
## preferences would answer with a file the user may not be looking at, which
## is not what the user asked for: their words were "The info should already be
## available -- it's been loaded to display waveforms in the waveform viewer."
## So `cadence::_annot_viewer_db` asks the viewer what it actually holds, and
## the two copies are then COMPARED before any number is believed -- see the
## `viewerdiff` note below.
##
## ⚠ ONE DISCOVERY MECHANISM, NOT TWO (RULING D5-4's spirit).
## `cadence::_annot_raw_candidate` already answers "where are this sheet's
## results", already prefers the ASE session's own file over the shipped
## fallback, and already refuses a file older than the deck (issue 0838). A
## second lookup written out longhand here would drift the first time one of
## the three learned something the other did not. Row V39 of
## tests/headless/test_op_annot.tcl slices this body and requires exactly one
## call to that proc and no source spelled out on its own.
##
## ⚠ IT HANDS THE FILE TO `xschem annotate_op`, NOT TO `xschem raw read`.
## Two reasons, and neither is cosmetic: annotate_op is the same verb
## `cadence::annot_mode`'s candidate branch already uses, and it stamps the raw
## with the session LEVEL, which is what makes the database findable after the
## user has descended. Row V47 is the structural witness for both -- neither is
## visible to a behavioural row while the session stub sits at level 0.
##
## ⚠ AND IT ASKS FOR `tran` BY NAME FIRST. THE SHIPPED FALLBACK IS THE SECOND
## ASK, NOT THE FIRST, AND THE ORDER IS THE WHOLE POINT.
## annotate_op with no type token runs op -> dc -> tran, and the commonest
## results file a real bench produces carries the deck's `.op` in the same file
## as its `.tran` -- ngspice writes one plot per analysis into one raw. On that
## file the fallback stops at the OPERATING POINT, and the transient mode then
## refused its own supply with "the loaded database is not a transient
## analysis" -- about a file whose transient is on the user's screen. Measured,
## and the sentence was false: reading the same file with the `tran` token
## gives 5 points, sim_type tran and v(a) = 3 at the 3 ns cursor. Row V45.
## The fallback is still run when the explicit ask finds no transient, and it
## is what lets an OPERATING-POINT-only session ATTACH and meet the honest
## `notran` refusal below rather than being told there is no results file at
## all. Row V35b is that path.
##
## ⚠ SUCCESS IS RE-ASKED FROM `xschem raw loaded`, NEVER TAKEN FROM THE rc.
## Measured: annotate_op returns the same rc for a file it loaded and a file it
## could not parse. A supplier that trusted the rc would walk on into the
## analysis check with nothing attached and tell the user their transient is
## not a transient. Row V37 is the only row that can see this.
##
## ⚠ AND THE TWO COPIES ARE COMPARED BEFORE ANY NUMBER IS BELIEVED
## (RULING D5-1). The viewer holds its copy in MEMORY; this reads the file
## again, off disk, into another window. Re-running the simulator overwrites
## that file in place, so the two can be different runs -- and then the sheet
## would carry run N+1's numbers while the traces beside it are still run N's,
## with nothing saying so. Measured before this guard: the viewer plotting
## v(a) = 3 V at the cursor and the schematic painting 30 V, no refusal, no
## warning. `cadence::_annot_db_print` reduces a database to what two windows
## can be compared on; a mismatch is refused by name and the sentence tells the
## user to re-plot. Rows V52 and V52b.
##
## ⚠ WHAT THE COMPARISON CANNOT SEE, stated so nobody reads it as a proof.
## The print is the analysis type, the dataset and point counts, the column
## names and every column's value at the LAST point. A re-run that changed a
## value only in the middle of the sweep and left every last sample and the
## whole shape identical would pass it. Closing that would mean comparing every
## sample of every column on every key press; the print is the cheap 95%, and
## the honest fix for the rest is a shared database, which is a C change and is
## not this item.
proc cadence::_annot_tran_supply {} {
  set cand [cadence::_annot_raw_candidate]
  set path [lindex $cand 0]
  set lvl  [lindex $cand 1]
  if {[lindex $cand 2] eq {stale}} { return [list -1 stale $path] }

  ## THE WAVEFORM VIEWER IS ASKED FIRST, AND ITS ANSWER WINS THE FILE.
  ## The session question -- is this sheet's results file still current --
  ## stayed above, with the ONE builder that answers it. This asks a different
  ## question of a different subject: which file is on the user's screen right
  ## now. When the viewer is showing a transient for this sheet, that file is
  ## the answer, whatever a path rebuilt from the preferences would have said.
  set vw [cadence::_annot_viewer_db]
  set vprint {}
  if {[llength $vw]} {
    set path   [lindex $vw 0]
    set vprint [lindex $vw 1]
  }

  if {$path eq {} || ![file exists $path]} { return [list -1 noraw $path] }
  if {$lvl eq {} || ![string is integer -strict $lvl]} { set lvl -1 }

  ## THE TRANSIENT IS ASKED FOR BY NAME FIRST, AND THE SHIPPED FALLBACK IS THE
  ## SECOND ASK, NOT THE FIRST.
  catch {xschem annotate_op $path $lvl tran}
  set after -1
  catch {set after [xschem raw loaded]}
  if {![string is integer -strict $after] || $after < 0} {
    catch {xschem annotate_op $path $lvl}
    set after -1
    catch {set after [xschem raw loaded]}
  }
  if {![string is integer -strict $after] || $after < 0} {
    return [list -1 noraw $path]
  }

  ## THE TWO WINDOWS ARE COMPARED BEFORE A SINGLE NUMBER IS BELIEVED.
  if {[llength $vprint] && [cadence::_annot_db_print] ne $vprint} {
    return [list $after viewerdiff $path]
  }
  return [list $after ok $path]
}

## -> whether the unwind ran. Puts back what `cadence::_annot_tran_supply` did:
## the database it attached is detached and the annotation mask goes back to
## what the user had before the key press.
proc cadence::_annot_tran_unwind {attached mask} {
  if {!$attached} { return 0 }
  catch {xschem raw clear}
  catch {xschem set annot_show $mask}
  catch {xschem update_all_sym_bboxes}
  catch {xschem redraw}
  return 1
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
    cadence::_annot_say [cadence::_annot_tran_msg nocursor {} {}] warn
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
  ##
  ## ⚠ ISSUE 0881: NOTHING ATTACHED HERE IS NOT THE SAME AS NOTHING TO
  ## ANNOTATE. `xschem raw loaded` answers for the CURRENT WINDOW, and the
  ## waveform viewer deliberately keeps the run's results in its own window's
  ## context -- so the user who has just run a transient, is looking at the
  ## traces and puts a cursor on gets -1 here and used to be told
  ## "NO RAW FILE loaded" about a file that was on their screen. The supply
  ## goes and gets it; see `cadence::_annot_tran_supply` above for which file
  ## and why through annotate_op.
  ##
  ## ⚠ AND IT IS BELOW THE CURSOR RESOLVE, WHICH IS A GUARD, NOT AN
  ## ACCIDENT OF WRITING ORDER. Hoisting the supply above it would make a key
  ## press that REFUSES ("no cursor is on anywhere") attach a database to the
  ## user's session on its way out -- the very thing the issue 0872 unwind in
  ## `cadence::annot_mode` exists to prevent, arriving through the new door.
  ## Row V14 asserts the state and the mask on that refusal and would not
  ## notice; row V38 asserts the registry afterwards and is the only thing that
  ## does.
  ## THE MASK AS THE KEY PRESS FOUND IT. Every refusal below puts it back
  ## through `cadence::_annot_tran_unwind`, so a press that declines leaves the
  ## user's own annotation settings exactly where they were.
  set mask0 0
  catch {set mask0 [xschem get annot_show]}
  if {![string is integer -strict $mask0]} { set mask0 0 }

  set attached 0
  set loaded -1
  catch {set loaded [xschem raw loaded]}
  if {![string is integer -strict $loaded] || $loaded < 0} {
    set sup [cadence::_annot_tran_supply]
    set loaded [lindex $sup 0]
    ## ⚠ ISSUE 0838's RULE, CARRIED THROUGH THE NEW DOOR. A results file
    ## older than the deck it describes is REPORTED and never used: annotating
    ## it would put the previous run's numbers on a changed circuit under an
    ## authoritative caption, which is RULING D5-1 with the sentence lending it
    ## weight. The sentence names the file, because "not used" without saying
    ## which file is not something a user can act on. Note the waveform viewer
    ## checks staleness nowhere, so the user can be watching those very traces
    ## while this refuses -- that collision is filed as issue 0884 and needs
    ## the user's ruling.
    if {[lindex $sup 1] eq {stale}} {
      cadence::_annot_say [cadence::_annot_tran_msg staleraw {} {} [lindex $sup 2]] warn
      return staleraw
    }
    if {![string is integer -strict $loaded] || $loaded < 0} {
      cadence::_annot_say [cadence::_annot_tran_msg noraw {} {}] warn
      return noraw
    }
    ## FROM HERE ON THIS KEY PRESS OWNS A DATABASE THE SESSION DID NOT HAVE,
    ## and every way out below has to put it back.
    set attached 1
    ## ⚠ RULING D5-1 -- THE TWO WINDOWS DISAGREE, SO NOTHING IS PUBLISHED.
    ## The viewer holds its copy in memory and this read the file again off
    ## disk; a re-run in between makes them different runs. Measured before
    ## this arm: the waveform screen showing 3 V at the cursor and the
    ## schematic painting 30 V beside the same node, with no refusal and no
    ## warning anywhere. The sentence tells the user to re-plot, because that
    ## is the action that makes the two agree.
    if {[lindex $sup 1] eq {viewerdiff}} {
      set m [cadence::_annot_tran_msg viewerdiff {} {} [lindex $sup 2]]
      cadence::_annot_tran_unwind $attached $mask0
      cadence::_annot_say $m warn
      return viewerdiff
    }
  }
  ## ⚠ READ BEFORE THE UNWIND, NOT AFTER. `xschem raw sim_type` RAISES once the
  ## database is detached, so a sentence minted after the unwind could only ever
  ## be the typeless shape -- the same ordering the 0872 unwind above needs, for
  ## the same reason.
  set st {}
  if {[catch {xschem raw sim_type} st]} { set st {} }
  if {$st ne {tran}} {
    ## ⚠ THE REFUSAL MUST NOT PUBLISH, AND UNTIL THIS UNWIND IT DID.
    ## Getting here means the supply attached a database to find out what it
    ## was, and `xschem annotate_op` runs update_op() and draw() on its way --
    ## so with the OP annotation bits already on (a previous `6`, or an
    ## `annot_show` line in the user's xschemrc) the operating point LANDED ON
    ## THE SHEET on the very path that then said "the loaded database is not a
    ## transient analysis". Measured: 0.5 V painted beside node `a` while the
    ## cursor sat at 3 ns. That is RULING D5-1 -- a number nobody asked for,
    ## published by a refusal -- and it is issue 0872's shape arriving through
    ## the new door. Rows V46 and V35b.
    cadence::_annot_tran_unwind $attached $mask0
    cadence::_annot_say [cadence::_annot_tran_msg notran {} {}] warn
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
    ## Same rule as the `notran` arm above: a refusal puts back whatever the
    ## supply attached on its way in.
    cadence::_annot_tran_unwind $attached $mask0
    cadence::_annot_say [cadence::_annot_tran_msg nodata $t $which] warn
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
  cadence::_annot_say $m
  return ok
}
