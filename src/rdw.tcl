# rdw.tcl -- the Results Display Window (RDW).
#
# Item B3 of doc/claude/op_param_batch/PLAN.md, feature 1245.
# Spec: doc/claude/specs/op_param_lists.md sections 4.2 (B1/B2/B3/B7) and
# 5.1 (Q6, Q10).  Rulings: doc/claude/op_param_batch/DECISIONS.md D-3, D-4,
# D-5 and driver decision DD-1.
#
# ============================================================================
# WHY THIS WINDOW EXISTS, IN THE USER'S OWN WORDS
# ============================================================================
# The text must be SELECTABLE and COPYABLE so it can be pasted into
# design-review documents.  That is not a nice-to-have; it is the reason this
# is a window and not a line in the CIW.  So the pane is a real Tk text with
# a real selection, `-exportselection 1` so the X PRIMARY selection and
# Ctrl-C both work, and `-state disabled` so nobody can type into a record of
# a simulation.
#
# NOT `textwindow` (xschem.tcl:13567).  That proc takes a FILENAME, opens an
# EDITABLE widget, and its Save writes back to that file -- building on it
# would offer to save a results dump over one of the user's design files.
#
# ============================================================================
# WHAT THIS WINDOW SAYS, AND WHAT IT DOES NOT
# ============================================================================
# It says what THIS run's currently selected raw slot actually holds and
# actually computed for exactly this device path, which primitive each number
# belongs to, which columns the simulator did not compute, which ones came
# back non-finite, THAT THE LIST IS NOT EVERYTHING THE DEVICE HAS, and -- when
# there is nothing -- WHICH of the five silences this is.
#
# It does NOT say that the run converged.  An empty `nonfinite` bucket is not
# proof: the same NaN in an ASCII raw arrives as a finite 0 and lands in
# `devices` (src/save.c, deliberate; issue 1272 is still open).  No sentence
# below claims convergence.
#
# ============================================================================
# THE SEAM'S ANSWER IS FIVE KEYS (ase::backend_hook <sim> op_param_set)
# ============================================================================
#   devices   ordered {<rawdev> {{<param> <value>} ...}}, raw-file order,
#             one entry per PRIMITIVE the request covers
#   absent    ordered {<rawdev> <param>} -- columns the raw NAMES and the
#             simulator did not compute
#   nonfinite ordered {<rawdev> <param> <text>} -- columns the raw DOES carry,
#             holding Inf/NaN: a device that did not converge
#   complete  the honesty flag AS DATA (0 for today's ngspice)
#   state     no_devpath | no_raw | not_op | not_annotated | ok
#
# ⚠ THE SHARPEST TRAP, MEASURED AND NOT INFERRED: a real device can appear in
# NO `devices` entry at all.  An all-dims=0 device answers
#     devices {} absent {{@m.x1.m9 id} {@m.x1.m9 vth}} state ok
# and a binary raw with NaN/Inf answers
#     devices {} nonfinite {{@m.x1.m8 id nan} {@m.x1.m8 vth inf}} state ok
# A renderer that walks `dict keys [dict get $ans devices]` prints an EMPTY
# dump for a real, named, non-converged device.  So the row set is the UNION
# of the rawdev names in all THREE buckets -- rdw::_rowdevs, below.
#
# ============================================================================
# THE THREE RENDERING OBLIGATIONS, ALL RULED, NONE OPTIONAL
# ============================================================================
# 1. `complete` 0 MUST BE VISIBLE (DD-1's corollary).  Key 3's answer is
#    incomplete BY CONSTRUCTION today, and a caller that renders the pairs
#    silently reads as a COMPLETE list -- the failure D-4 exists to prevent.
# 2. `nonfinite` renders "(did not converge)", never a blank and never the raw
#    `nan`/`inf` text.  A non-converged operating point is a RESULT a designer
#    wants told, not a gap.  Invariant I3 forbids the raw text.
# 3. The four non-`ok` states are FOUR DIFFERENT SENTENCES, and `ok` with an
#    empty union is a FIFTH.  `not_op` in particular means the user is looking
#    at a transient: say so, and say what to do.  None of them says
#    "nothing found".
#
# ============================================================================
# THREE LAYERS, SO THE RENDERER IS TESTABLE WITH NO Tk AT ALL
# ============================================================================
#   pure      _cadence_path  _rowdevs  _incomplete_line  _nonfinite_text
#             _state_sentence  format_answer  block_text  button_state
#             font_limits  _accept_size  _chosen_size  font_size
#             set_font_size  font_step  _font_tip                (issue 1368)
#   context   header  sim  dump  dump_devpath  push  status   (xschem/op_annot,
#             still no Tk)
#   Tk        have_tk  open  close  build  render_pane  set_list
#             palette  color  _font  _pane_chars  _apply_font    (issue 1368)
# (illustrative, not exhaustive -- `rdw::inert` was in this list until item B5
# deleted the proc, and the list is where that showed.)
#
# ⚠ SURVIVING --nogui BY NOT BEING CONSTRUCTED.  This file is reached by the
# UNGUARDED bare `source` block in xschem.tcl, so a single Tk command executed
# at SOURCE time aborts startup (issue 0663's mechanism).  Nothing below runs
# at source time but `namespace eval` and `proc`; every Tk command sits inside
# a proc behind rdw::have_tk.
#
# ⚠ THE BUTTONS ARE INERT IN THIS ITEM.  B3 ships the column, the greying and
# a test-drivable path to each button.  Item B5 wires them to the store and
# ships the two scope dialogs.  This file calls the list store not at all.
#
# Suite: tests/headless/test_rdw_window_1245.tcl (both arms).

namespace eval rdw {
    # THE STORE.  A list of blocks, NEWEST FIRST.  The pane is a projection of
    # this and never the other way round, which is what makes every renderer
    # row drivable under --nogui.
    variable blocks {}

    # Which list the button column is greying for: annotation | summary | all.
    # Spec 4.2 B7 greys per list; item B4 owns the keys that select one and
    # MUST drive rdw::set_list rather than minting a second state variable
    # (invariant I1's shape: one builder, several consumers).
    variable listkind annotation

    # The window's own status line.  Always settable, headless included.
    variable statusmsg {}

    # An explicit backend override, for the suite and for B4/B5.  Empty means
    # "resolve it" -- see rdw::sim.
    variable sim {}
}

# ---------------------------------------------------------------------------
# The live-Tk predicate.  Shape copied from simconf_have_tk (xschem.tcl:4009),
# NOT called across the namespace boundary.  The second half is not
# decoration: under --nogui `winfo` really is an undefined command, so
# `[info exists ::has_x]` alone would still raise.
proc rdw::have_tk {} {
    return [expr {[info exists ::has_x] && [llength [info commands winfo]] > 0}]
}

# ---------------------------------------------------------------------------
# THE PURE LAYER.  No Tk, no `xschem`, no backend: hand it a dict, get lines.

# Q6's already-taken default spelling.  The user asked for
# `M2B:/xdut/xbg/xamp1`; the tree has three spellings and none is that one, so
# this mints it from `xschem get sch_path`, whose measured shape carries BOTH
# a leading and a trailing dot (`.xdut.xbg.xamp1.`).  At the top sheet
# sch_path is `.` and the trim yields the empty string, so the header
# degenerates to `M1:/` -- the path stays rooted and the header's shape stays
# constant with depth, so two pastes from different sheets still align.
#
# `sim_sch_path` is deliberately NOT used: it strips every level above the
# point the raw was loaded at, so the header would stop matching the schematic
# the user is looking at.
proc rdw::_cadence_path {schpath} {
    return "/[string map {. /} [string trim $schpath .]]"
}

# THE UNION.  See the trap block at the top of this file: `devices` alone is
# not the row set, because a device whose every column is absent, or whose
# every column is non-finite, has no `devices` entry at all and is still a
# real device the user is looking at.  First-appearance order across
# devices -> absent -> nonfinite, raw-file order within each.
proc rdw::_rowdevs {ans} {
    set devs {}
    catch {set devs [dict keys [dict get $ans devices]]}
    set abs {}
    catch {set abs [dict get $ans absent]}
    foreach e $abs { lappend devs [lindex $e 0] }
    set nf {}
    catch {set nf [dict get $ans nonfinite]}
    foreach e $nf { lappend devs [lindex $e 0] }
    set out {}
    foreach d $devs {
        if {[lsearch -exact $out $d] < 0} { lappend out $d }
    }
    return $out
}

# OBLIGATION 1, and it is DD-1's corollary rather than a nicety: the seam
# hands `complete` over as DATA, and a window that renders the pairs without
# it reads as a complete list.  Printed only in state `ok` with a non-empty
# union -- under `no_raw` it would pair "no results are loaded" with "this is
# what the run saved", and under ok-with-nothing it says the same thing twice
# as the fifth sentence already does.
#
# ⚠ ISSUE 1374 CUT IT TO A LABEL, ON THE USER'S RULING: "This is too verbose!
# Just say 'annotated list' or 'summary list'".  The obligation is untouched
# and so is the FACT; what went is 64 of the 121 characters it took to state
# it.  MEASURED at the shipped geometry (pane -width 96, -wrap word): the old
# sentence took TWO display lines of a FOUR-line preamble sitting above six
# rows of data, and this one takes ONE.
#
# ⚠ AND THE SHORTENING IS A REPAIR, NOT ONLY A TRIM.  The old wording -- "these
# are the operating-point columns this run saved for this device" -- POINTS AT
# THE ROWS ON SCREEN, and on a narrowed block those are six of the eighty-eight
# the run saved, so the deixis was FALSE and `rdw::_narrow_line` one line below
# it had to correct it.  This wording states the fact without pointing at
# anything, so it is true of a narrowed block and of key 3's un-narrowed one
# alike.  Locked as `RW_INC` in the window suite, which asserts it in 39 rows.
proc rdw::_incomplete_line {ans} {
    set c 0
    catch {set c [dict get $ans complete]}
    if {[string is boolean -strict $c] && $c} { return {} }
    return {Not everything the device has - only what this run saved.}
}

# OBLIGATION 2.  A column the raw carries for a device that did not converge
# is a RESULT, not a gap: it renders as words, never as the raw text and never
# as the blank an ABSENT column gets.  Invariant I3 forbids painting `nan`.
proc rdw::_nonfinite_text {text} {
    return {(did not converge)}
}

# The footnote that makes a blank value legible.  Invariant I3 says a missing
# vector renders BLANK -- not 0, not NaN, not the previous run's number -- and
# a bare blank after a colon reads as a bug, so the block says once what a
# blank means, exactly when there is one.
proc rdw::_absent_line {} {
    return {A blank value means the raw names that column but the simulator did not compute it.}
}

# ISSUE 1282 / RULING DD-5.  THE SEAM'S ALLOW-LIST IS `{op dc}`, NOT `{op}`.
# ase.tcl:8803 copied it DELIBERATELY from update_op()'s own guard in
# src/save.c, so that this window and the on-sheet annotation agree about what
# counts as an operating point.  A raw whose current slot is a DC transfer
# characteristic therefore answers `ok` with real point-0 numbers, and this
# window presented them under a heading saying "operating-point" with the word
# `dc` NOWHERE ON SCREEN (measured: sim_type dc, state ok, block mentions dc
# zero times).  A DC sweep's point 0 is the first step of the sweep, not the
# circuit's quiescent point, and pasting that into a design review under an
# "operating point" heading is the plausible-wrong-number failure invariant I3
# exists to prevent.  DD-5 takes option (a): KEEP RENDERING IT, AND NAME THE
# ANALYSIS.  Option (c), refusing `dc`, is forbidden -- it would contradict the
# allow-list and red row G3b of the seam's suite, a cross-language fence over
# save.c's own op/dc strcmps.
#
# ⚠ THE WORDING IS NOT DD-5's QUOTED SPECIMEN, AND save.c IS WHAT MOVED IT.
# The ruling proposes "these numbers come from the `dc` analysis at its first
# point, not from a standalone operating point".  That asserts something FALSE
# for a case save.c creates itself: save.c:1073 and :1120 both carry
#     if(raw->npoints[...] > 1 && !strcmp(sim_type, "op")) sim_type = "dc";
# so a MULTI-POINT `Operating Point` plot is renamed `dc` BY THE READER, and a
# user who ran nothing but an operating point would be told they ran a sweep.
# MEASURED: a three-point `Plotname: Operating Point` raw answers
# `xschem raw sim_type` = dc.  DD-5's DECISION is implemented; only its
# specimen wording is refuted.  The sentence below names what the LOADED
# RESULTS CALL THEMSELVES rather than what the user ran, which is true in both
# cases and asserts nothing stronger.  The exact wording is on the owed ledger
# as a rule debt for the user.
#
# ⚠ THE GATE IS `$sty ne {} && $sty ne "op"`.  The empty half is not
# decoration: a hand-built ctx and a failed `xschem raw sim_type` both produce
# {}, and a sentence that fired on those would be indistinguishable from an
# honest one.  Fired only in state `ok` with a non-empty union -- on the fifth
# silence it would put "these numbers come from..." over a block with no
# numbers.
## `a` or `an`, for a word that came from the simulator (issue 1297).
## ⚠ VOWEL-INITIAL IS THE TEST, NOT A LIST OF KNOWN ANALYSES: the kinds are
## whatever the raw's `Plotname` mapped to, so a list would be wrong for the
## first kind nobody anticipated. It is not perfect English for every possible
## token, and it does not have to be -- it is right for `op`, `ac`, `dc`,
## `tran`, `noise`, `sp` and `sens`, which is every kind this tree produces.
proc rdw::_article {word} {
    if {[regexp -nocase {^[aeiou]} $word]} { return "an" }
    return "a"
}

proc rdw::_analysis_line {ctx} {
    set sty {}
    catch {set sty [dict get $ctx simtype]}
    if {$sty eq {} || $sty eq {op}} { return {} }
    return "These numbers come from the first point of results xschem reports as a $sty analysis, not as a standalone operating point. A $sty sweep's first point is one sweep step, and xschem also reports a multi-point operating point as $sty."
}

# ===========================================================================
# ISSUE 1300 -- THE NARROWING.  KEYS 1 AND 2 SELECT A LIST'S CONTENT, NOT ONLY
# ITS IDENTITY.
# ===========================================================================
# The user's first complaint, in their own words: "1 key dumps ALL OP info for
# a MOS FET in the RDW, when it's supposed to dump only those parameters that
# get annotated on the schematic."  MEASURED on their own design before this
# fix: keys 1, 2 and 3 rendered BYTE-IDENTICAL 1939-character blocks, and key 1
# printed 88 rows for one MOSFET of which their PDK's annotation list declares
# six.  `rdw::format_answer` took no list argument and no caller ever gave it
# one -- item B4 shipped the IDENTITY and left the CONTENT to the item that
# owns the store, and no item ever took it.
#
# ⚠ WHY THE USER SAYS "WAS WORKING OK BEFORE", WHICH IS A REAL QUESTION AND NOT
# A THROWAWAY.  Until 2026-09-05 00:41 the deck used save shape `c`, which
# emits one `.save @dev[param]` card per DECLARED parameter, so the raw held the
# annotation list and nothing else and an UNNARROWED pane LOOKED narrowed --
# measured on the user's own tb_bandgap: 468 cards, 78 devices, exactly the six
# parameters `id gm gds vgs vth vds`.  Shape `d` -- `set altshow` plus
# `show all`, chosen automatically by `ase::op_save_tier` when the backend
# reports `altshow_op_dump`, which the user's ngspice-46+ does -- merges the
# whole dump into the raw instead: 212 devices, 7825 parameters, 88 of them for
# their M18.  NOTHING ABOUT THIS WINDOW REGRESSED.  The deck stopped covering
# for the pane, and the pane's silence became visible.
#
# ⚠ THE NARROWING HAS EXACTLY ONE DEFINITION IN THIS TREE AND IT IS NOT HERE.
# `::op_param_lists::effective` is it, and `rdw::_list_params` -- item R2's
# reader, built for the reorder -- is this file's one door on to it.  Issue
# 1300 costed and refused the alternative, "filter from
# `op_annot::descriptor`'s `params`", because it mints a SECOND definition of
# "the annotation list" beside ruling DD-6's, which is precisely the drift
# invariant I1 exists to prevent.  Reusing R2's reader also means the pane's
# narrowing and the pane's ORDER come from one list, so a reorder the user
# makes with Up or Down cannot put the two out of step.
#
# ⚠ AND IT IS THE RENDERER, NOT THE SEAM.  `ase::op_param_set`'s own written
# contract is "which parameter columns THIS RUN'S CURRENTLY SELECTED RAW SLOT
# actually holds"; key 3's content IS that answer (ruling D-5) and the
# `complete` flag is a statement about it.  Narrowing there would make key 3
# unimplementable and turn DD-1's honesty flag into a lie.
#
# ⚠ AND IT DOES NOT REACH THE DECK -- RULINGS DD-4 AND DD-6, "a display
# decision NEVER changes what the simulator is asked to save".  Nothing here
# writes a descriptor, calls `op_param_lists::apply` or names
# `op_annot::save_cards`.  Row NW8 of the window suite drives a real instance's
# `.save` cards on all three list identities and golds that they do not move.

# "88 columns" / "1 column".  The count and its agreement TOGETHER, because
# they are always used together and two helpers is how a sentence ends up
# reading "1 columns" (issue 1297's family: the analysis kind that read "a op
# analysis" because the article was a literal).
#
# ⚠ ISSUE 1374 MOVED THE AGREEMENT ON TO THE TOTAL, AND DROPPED THE VERB.  It
# answered "82 columns are" / "1 column is" while the sentence counted what was
# WITHHELD and made it the subject of a clause.  The label counts what is SHOWN
# out of the total -- "6 of 88 columns", "1 of 1 column" -- so the noun agrees
# with the TOTAL and the verb went with the clause.  The proc keeps its whole
# reason for existing (one helper for count-plus-agreement) and its one caller,
# `rdw::_narrow_line`.
proc rdw::_cols_are {n} {
    if {$n == 1} { return {1 column} }
    return "$n columns"
}

# ⚠ THE NARROWING IS SAID OUT LOUD, AND THAT IS DD-1's OBLIGATION ONE SURFACE
# FURTHER OUT.  DD-1's corollary is that a renderer which prints the pairs
# silently reads as a COMPLETE list; a pane that silently drops 82 of 88 rows
# has exactly that shape, and worse, because the reader cannot tell it from a
# device that published six columns.  So a narrowed block says WHICH list
# narrowed it, HOW MANY of the published columns it is showing, how many of the
# withheld DID NOT CONVERGE, and -- when it is showing none of them -- that key
# 3 has them.
#
# ⚠ ISSUE 1374: IT IS A LABEL, NOT A PARAGRAPH.  The user's ruling, verbatim,
# about this sentence and the DD-1 one above it: "This is too verbose!  Just
# say 'annotated list' or 'summary list'".  What they were reading was THREE
# sentences, 190 characters (226 with a withheld non-convergence), and MEASURED
# at the shipped geometry it wrapped to two of FOUR preamble display lines
# sitting above SIX rows of data -- half the block was preamble, re-emitted per
# device.  Every ⚠ below survives that cut because every one of them argues
# WHICH FACT must appear, and not one of them was ever an argument for the
# number of words used to state it.  KEPT: the list's identity, the tense
# anchor, the counts, the withheld non-convergence, and the pointer on a block
# with nothing else on it.  GONE: "not in that list and not shown", "this run
# published N for this device", "Every column this run published for this
# device is in that list", and the pointer on a block that has rows.
#
# ⚠ IT GOES IN THE BLOCK, NOT IN WINDOW CHROME.  The block is what the user
# pastes into a design review (item R3), and a window title or a label above
# the pane does not travel with a paste.  Row NW10 is the fence.
#
# ⚠ AND IT IS PAST TENSE ON PURPOSE.  Issue 1300 refused a `list: annotation`
# label as "worse than silence", on the ground that a label naming a list whose
# content is identical for all three IMPLIES a narrowing that did not happen.
# Half of that objection lapses the moment the narrowing is real.  The half
# that does NOT lapse is that a standing block is a RECORD and the store is
# LIVE: `rdw::_reslot_block` is a strict permutation ("adds nothing, removes
# nothing"), so no edit path re-narrows a block already on screen, and a Delete
# would leave a present-tense label asserting something false.  "at this dump"
# is what makes the sentence true for the life of the block -- four words, and
# issue 1374 kept them for that reason and no other.  Dropping them re-opens
# issue 1300's option-(c) objection in full.
#
# ⚠ THE WITHHELD NON-CONVERGENCE GETS ITS OWN CLAUSE, AND KEPT IT THROUGH
# ISSUE 1374's CUT, AGAINST A GENERAL INSTRUCTION TO BE BRIEF.  Ruling DD-1 and
# issue 1272 both say a `nonfinite` row is the one fact a designer most wants
# to be told about -- it means the device did not converge -- so narrowing it
# away in silence throws away exactly what obligation 2 exists to preserve.  It
# is still withheld (the alternative is a pane whose length depends on how
# badly the circuit failed), and it is COUNTED, so the fact survives the
# narrowing even when the row does not.  THREE reasons it also survived 1374:
# it is a RESULT the simulator reported, not an EXPLANATION of the display,
# and explanations are what the user struck out; MEASURED on their own M18 the
# clause is ABSENT (`wnf == 0`), so deleting it would have shortened the screen
# they complained about by ZERO characters; and its silence promises nothing,
# because an empty nonfinite bucket is not proof of convergence (src/save.c
# turns an ASCII NaN into a confident 0 -- see this file's own head, issue
# 1272).  It costs 29 characters and, measured, leaves the ordinary shape at 95
# -- still one display line.  DECISION, unratified, on rule debts 1300 and 1374.
#
# ⚠ AND THE WITHHELD-NON-CONVERGENCE CLAUSE IS BUILT BEFORE THE BRANCH, NOT
# INSIDE ONE OF THEM.  The first revision appended it after the `norder == 0`
# arm had already returned, so the ONE case in which every row is withheld was
# the ONE case that never mentioned a withheld row failing to converge -- the
# exact fact the paragraph above says must survive the narrowing, lost in the
# case where nothing else survives it.  MEASURED: the same answer under a
# non-empty list said "1 of the withheld did not converge" and under an empty
# one said nothing, and an empty list is reachable from a shared settings file
# (`list class mos annotation` with no `param` rows under it sets owned=1 with
# an empty list).  Rows NW12 and NW15 are the fences and NW4's own golden used
# to spell the omission.
#
# ⚠ TWO ARMS WHERE THERE WERE THREE (issue 1374).  The `withheld == 0` arm
# said "Every column this run published for this device is in that list" in 122
# characters; "6 of 6 columns" is the same fact in the general arm's own words,
# and one arm fewer is one place fewer for an arm-specific omission -- which is
# precisely the defect the paragraph above is about.  What survives as a branch
# is the ONE thing the counts cannot say: `norder == 0` means the LIST was
# empty, while `kept == 0` under a non-empty list means the list declares
# columns THIS RUN DID NOT PUBLISH.  Both show no rows; they are different
# diagnoses and only the first is fixed in the settings file.
#
# ⚠ AND THE POINTER IS ONE RULE, NOT A PROPERTY OF AN ARM: "Press 3" appears
# exactly when `kept == 0`, i.e. when the block has NO ROWS on it and the
# pointer is the only next step.  On a block that has rows the counts already
# say more are being withheld, and the window chrome's head reads "Keys 1/2/3:
# <list>" -- so a pointer there is navigation, which is the class of thing the
# user struck out.  ⚠ THE CHROME IS ONE DUMP BEHIND, THOUGH (measured:
# `rdw::apply_list_state` is called only from `rdw::build` and `rdw::set_list`,
# and `rdw::push` calls neither), so on the FIRST dump of a session it still
# reads "Select a device and press 1".  That is issue 1367/1355's surface, not
# this one's; if it is ever decided the pointer must be on every block, put it
# back HERE, in the one builder, and not in a second one.
proc rdw::_narrow_line {name total withheld wnf norder} {
    set nf {}
    if {$wnf > 0} { set nf " $wnf withheld did not converge." }
    set kept [expr {$total - $withheld}]
    set what "$kept of [rdw::_cols_are $total]"
    if {$norder == 0} { set what "empty, $what" }
    set out "Narrowed to the $name at this dump: $what.$nf"
    if {$kept == 0} { append out " Press 3 for all $total." }
    return $out
}

# THE NAME OF THE LIST THAT REALLY NARROWED THIS BLOCK, IN THE STORE'S OWN
# WORDS.  No leading article: both sentences above supply their own.
#
# ⚠ IT IS THE ENTRY THAT ANSWERED, NOT THE CLASS THAT WAS ASKED, AND THE FIRST
# REVISION GOT THAT WRONG ON THE USER'S OWN DEVICE.  `rdw::_narrow_spec`
# resolves the rows through `rdw::_list_params $cls $ln $cell`, which is
# flavor-aware -- `op_param_lists::governs` lets a DEVICE-FLAVOR entry win --
# and then handed `rdw::_narrow_line` the CLASS.  MEASURED by two adversaries
# on tb_bandgap /x1/x1 M18 after the shipped Delete -> "this cell only"
# gesture: the pane showed the flavor entry's rows under "Narrowed to the mos
# annotation list", while `effective mos annotation` held a different set.  The
# NAME came from one entry and the COUNT from the other, in the one block this
# window exists to have pasted into a design review.
#
# ⚠ AND THE WORDING IS `rdw::_edit`'s, NOT A SECOND ONE.  Its `governing` arm
# already says "for cells matching <glob> of class <cls>" about the same store
# key; a fresh phrasing here would be the two-wordings drift this file keeps
# paying for.  Row NW11 is the fence, and it also fences the flavor path
# itself: before it, passing `{}` for the cell -- silently ignoring every
# per-cell list -- left window, keys and store all green.
proc rdw::_narrowed_list {cls listname scope} {
    # ISSUE 1373: the store's class KEY is not what a person reads.  One
    # accessor, resolved once, for both arms.
    set d [::op_param_lists::class_label $cls]
    if {[llength $scope] == 2 && [lindex $scope 0] eq {flavor}} {
        return "$listname list for cells matching [lindex [lindex $scope 1] 1] of class $d"
    }
    return "$d $listname list"
}

# Keep only the rows `order` declares, in ALL THREE BUCKETS, and count what was
# dropped.  Answers {ans total kept withheld-nonfinite}.
#
# ⚠ THE THREE BUCKETS ARE THREE DIFFERENT FACTS AND THE FILTER IS ONE RULE.
# `devices` is a measurement, `absent` a column the raw does not carry,
# `nonfinite` one it carries for a device that did not converge; the seam keeps
# them apart so a caller can render each differently, and this proc does not
# collapse them -- it applies the same membership test to each and rebuilds the
# same five-key answer, so every downstream reader (`_rowdevs`, the absent
# footnote, `_incomplete_line`) sees a well-formed narrowed answer rather than
# a special case.
#
# ⚠ `total`, `kept` AND `wnf` COUNT DISTINCT COLUMNS, NOT ROWS, and that is
# what makes the word in the sentence true.  One XR1 resolves to SEVERAL
# primitives (ruling D-3) and each of them publishes its own copy of the same
# column; the first revision counted every copy, so a five-primitive XR1
# publishing two distinct columns was told "2 columns are not in that list ...
# this run published 5 for this device" -- both numbers row counts, printed one
# line under the DD-1 line that uses "columns" in the correct per-vector sense.
# A single block used the word with two meanings one line apart.
#
# ⚠ THE REMEDY IS THE COUNT AND NOT THE WORD, because DD-1's line has the prior
# claim on "column" and the narrowing is a decision about NAMES: a list
# declares `id`, not `id on rend1`.  So the three buckets contribute their
# distinct param names to ONE set, and a name is withheld exactly when no list
# declares it.  `wnf` is then the withheld names that came back non-finite,
# which keeps it comparable with the withheld count it is quoted beside -- a
# row count there could read "5 of the withheld did not converge" under "3
# columns are not in that list".
#
# THE FILTER ITSELF IS STILL PER ROW: a column the list declares keeps every
# primitive's copy, so ruling D-3's attribution of a number to the primitive
# that published it is untouched.  Rows NW13 (the count) and F7/Q4 (the
# attribution) are the two fences.
proc rdw::_narrow_answer {ans order} {
    set pairs [dict create]
    catch {set pairs [dict get $ans devices]}
    set abs {}
    catch {set abs [dict get $ans absent]}
    set nf {}
    catch {set nf [dict get $ans nonfinite]}
    set seen {}     ;# every distinct column this run published for this device
    set nfseen {}   ;# ... and which of those came back non-finite
    set np [dict create]
    foreach d [dict keys $pairs] {
        set keep {}
        foreach pv [dict get $pairs $d] {
            set p [lindex $pv 0]
            if {[lsearch -exact $seen $p] < 0} { lappend seen $p }
            if {[lsearch -exact $order $p] >= 0} { lappend keep $pv }
        }
        if {[llength $keep]} { dict set np $d $keep }
    }
    set na {}
    foreach e $abs {
        set p [lindex $e 1]
        if {[lsearch -exact $seen $p] < 0} { lappend seen $p }
        if {[lsearch -exact $order $p] >= 0} { lappend na $e }
    }
    set nn {}
    foreach e $nf {
        set p [lindex $e 1]
        if {[lsearch -exact $seen $p] < 0} { lappend seen $p }
        if {[lsearch -exact $nfseen $p] < 0} { lappend nfseen $p }
        if {[lsearch -exact $order $p] >= 0} { lappend nn $e }
    }
    set kept 0 ; set wnf 0
    foreach p $seen {
        if {[lsearch -exact $order $p] >= 0} { incr kept ; continue }
        if {[lsearch -exact $nfseen $p] >= 0} { incr wnf }
    }
    set out $ans
    catch {dict set out devices   $np}
    catch {dict set out absent    $na}
    catch {dict set out nonfinite $nn}
    return [list $out [llength $seen] $kept $wnf]
}

# WHAT NARROWS THIS BLOCK, OR {} FOR "NOTHING DOES".  Answers
# {listname class ordered-raw-param-names governing-scope}.
#
# ⚠ THE FOURTH ELEMENT IS WHICH ENTRY ANSWERED, AND IT IS TAKEN FROM THE ONE
# SCANNER.  `rdw::_scope_for` is the single reader of `op_param_lists::governs`
# in this file (issue 1348 split it out for exactly this reason), so the
# caption cannot name one entry while the rows come from another -- which is
# what shipped, and what row NW11 now fences.
#
# ⚠ {} IS THE ANSWER FOR A CALLER THAT CANNOT NAME A LIST, AND IT IS NOT THE
# SAME AS AN EMPTY LIST.  A ctx with no `list` key (every hand-built context in
# the suites, and any future caller of the door that has no window state to
# read), a ctx on list `all` (ruling D-5's escape hatch), and a device whose
# type the editor cannot resolve all narrow NOTHING -- today's block, byte for
# byte.  A class that resolves and whose list is genuinely EMPTY narrows
# everything away and says so in a sentence, which is a different fact and gets
# different words.  Reading one as the other would either lose every row of a
# block nobody asked to narrow, or print a header with nothing under it.
#
# ⚠ THIS IS THE ONLY PROC IN THIS BLOCK THAT IS NOT PURE: it reads the list
# store, through `rdw::_list_params` and no other way.  Row NW7 of the window
# suite golds that chain and golds that neither this proc nor the renderer
# names `op_annot::descriptor`.
proc rdw::_narrow_spec {ctx} {
    set ln {}
    catch {set ln [dict get $ctx list]}
    if {$ln ne {annotation} && $ln ne {summary}} { return {} }
    set cls {}
    catch {set cls [dict get $ctx class]}
    if {$cls eq {}} { return {} }
    set cell {}
    catch {set cell [dict get $ctx cellname]}
    return [list $ln $cls [rdw::_list_params $cls $ln $cell] \
                 [rdw::_scope_for $cls $ln $cell]]
}

# ISSUE 1284.  THE ANSWER DICT IS NOT TRUSTED INPUT.  It is whatever a backend
# hands over, and ruling D-5 records that the user IS BUILDING A CUSTOM NGSPICE
# the seam exists to admit -- so the first backend to hand this window a shape
# it did not expect will be the user's own.  The shipped ngspice backend cannot
# produce any of these (it builds `devices` with `dict set` and gates every
# value through `op_annot::raw_class`'s `string is double -strict`), which is
# exactly why nothing here was ever exercised.
#
# FOUR SHAPES MEASURED, plus two found while planning:
#   * a malformed `devices` value fell into _rowdevs's dict-level catch, the
#     union came back empty, and the window rendered the FIFTH SILENCE -- a
#     statement about the RAW, and FALSE, because the run may have saved
#     plenty and it is the ANSWER that could not be read;
#   * a malformed per-device VALUE RAISED out of this pure renderer, which
#     every suite row and every widget path calls;
#   * a malformed `absent` bucket and a malformed `nonfinite` bucket RAISE the
#     same way (measured while planning B2a, not in the issue).
# So one predicate validates the whole answer BEFORE anything walks it, and a
# flawed answer gets its OWN sentence naming the backend, because the remedy is
# there and not in the run.
#
# Every walk below is `llength`-checked rather than `catch`-wrapped-per-use, so
# the renderer stays PURE: one verdict, taken once, before any rendering.
proc rdw::_wellformed {v} { return [expr {[catch {llength $v}] ? 0 : 1}] }

# ⚠ ISSUE 1284, SECOND PASS: THE FIRST FIX WAS REFUTED, AND THIS IS THE HALF
# THAT WAS WRONG.  B2a's `_answer_flaw` opened
#     if {[catch {dict keys [dict get $ans devices]} devs]} { return 1 }
# so an ABSENT `devices` key was malformed BY CONSTRUCTION, and the call sat
# ELEVEN lines ABOVE the state branch.  A third-party backend's perfectly legal
# minimal refusal `{state no_raw}` therefore rendered a complaint about the
# BACKEND where HEAD rendered "No simulation results are loaded.  Run a
# simulation, or load a raw file, then ask again." -- and MEASURED, all four
# non-`ok` states did it, not just `no_raw`.  That is the exact class ruling
# D-5 exists to admit: the user is building a custom ngspice and it will be the
# first backend to occupy this seam, so a window that greets a correct minimal
# answer with an accusation sends its author hunting a bug that is in here.
#
# THE RULE, AND BOTH HALVES ARE LOAD-BEARING:
#   * A NON-`ok` STATE IS A COMPLETE AND LEGAL ANSWER ON ITS OWN.  `devices`,
#     `absent`, `nonfinite` and `complete` are required only when `state` is
#     `ok`, so the state is read FIRST (rdw::_answer_state, below) and a
#     refusal returns its own sentence with NO shape check of any kind.
#   * AN ABSENT BUCKET IS EMPTY, NOT MALFORMED.  Only a key that is PRESENT
#     and un-walkable is a flaw.  `dict exists` is measured safe on a malformed
#     dict (returns 0, never raises), so the guard cannot itself become the
#     raise it is here to prevent.
# Invariant I3 applied to a SENTENCE rather than to a number: a plausible wrong
# statement on screen is the same failure as a plausible wrong value.
#
# ⚠ ISSUE 1284 SECTION 5, CLOSED BY ITEM B2d.  The second pass above fixed
# the four MEASURED shapes and left two that section 5 filed and nobody closed,
# while 1284's ACCEPT row says "1284 FIXED".  Both are UNDERSPECIFIED entries:
# well-formed lists that do not carry what the seam contracts them to carry.
# Each gets its own NAMED predicate rather than an inline literal, so each new
# guarantee can be neutralised on its own and has a sabotage handle that does
# not have to borrow the whole-predicate one.
#
#   * `rdw::_bucket_width` -- THE TWO BUCKETS ARE NOT THE SAME WIDTH, and the
#     shared `llength $e < 2` gate was the bug.  `absent` is a `{<rawdev>
#     <param>}` PAIR; `nonfinite` is a `{<rawdev> <param> <text>}` TRIPLE (item
#     B1's re-do added the third field).  A two-field nonfinite entry passed the
#     shared gate and then rendered `(did not converge)` -- an assertion the
#     window made on NO evidence, because `rdw::_nonfinite_text` discards its
#     argument and returns the words unconditionally.  Obligation 2 says the
#     words report what the raw actually holds; here the raw was never quoted.
#
#   * `rdw::_named` -- ARITY WAS THE WRONG QUESTION.  A `devices` pair `{{} 1.5}`
#     has arity 2 and rendered `     : 1.5`, a value belonging to no parameter:
#     the "blank row that means nothing" this predicate's own comment gives as
#     the reason it rejects a short bucket entry.  The right question is whether
#     the entry NAMES a parameter, asked of the devices pair's FIRST field and
#     of a bucket entry's SECOND.  It may NOT be asked as arity: F19's
#     value-less `{id}` has arity 1, a perfectly good name, and must keep
#     rendering `(no value reported)`.
#
# Neither is reachable through the shipped ngspice backend -- `ase::op_param_split`
# returns {} for an empty parameter and `ase::op_param_set` always emits a
# nonfinite TRIPLE -- which is ruling D-5's point, not an argument for leaving
# them: the first backend to occupy these shapes will be the user's own custom
# ngspice, and "(did not converge)" about a column nobody reported would send
# its author hunting a convergence problem that does not exist.
proc rdw::_bucket_width {key} { return [expr {$key eq {nonfinite} ? 3 : 2}] }
proc rdw::_named {n} { return [expr {[string trim $n] eq {} ? 0 : 1}] }

proc rdw::_answer_flaw {ans} {
    if {[dict exists $ans devices]} {
        set pairs [dict get $ans devices]
        set devs {}
        if {[catch {dict keys $pairs} devs]} { return 1 }
        foreach d $devs {
            set pv [dict get $pairs $d]
            if {![rdw::_wellformed $pv]} { return 1 }
            foreach e $pv {
                if {![rdw::_wellformed $e]} { return 1 }
                if {[llength $e] < 1} { return 1 }
                ## A pair with no parameter NAME renders a value under nothing.
                ## Arity is deliberately NOT the question here: a value-less
                ## `{id}` is a named column with nothing reported for it, and
                ## `_value_text` has words for that.
                if {![rdw::_named [lindex $e 0]]} { return 1 }
            }
        }
    }
    foreach key {absent nonfinite} {
        if {![dict exists $ans $key]} { continue }
        set b [dict get $ans $key]
        if {![rdw::_wellformed $b]} { return 1 }
        foreach e $b {
            if {![rdw::_wellformed $e]} { return 1 }
            ## A short entry would render a device sub-header with an empty
            ## parameter name, which is a blank row that means nothing -- and a
            ## short NONFINITE entry would additionally make the window assert
            ## non-convergence with nothing quoted from the raw.
            if {[llength $e] < [rdw::_bucket_width $key]} { return 1 }
            if {![rdw::_named [lindex $e 1]]} { return 1 }
        }
    }
    return 0
}

# THE STATE, READ ONCE AND READ FIRST.  Answers {hasstate state}.  An answer
# with no readable `state` -- including one that is not a dict at all -- is
# ITSELF malformed and gets the sentence naming the backend, because the remedy
# is there.  HEAD instead defaulted to `set state unknown`, inventing a state
# name the backend never sent and then rendering a sentence that blames this
# window for the backend's omission.  A state that IS present but unrecognised
# is a different fact and keeps its own sentence, naming that state.
proc rdw::_answer_state {ans} {
    set st {}
    if {[catch {dict get $ans state} st]} { return [list 0 {}] }
    return [list 1 $st]
}

proc rdw::_flaw_line {sim} {
    if {$sim eq {}} { set sim simulator }
    return "The $sim operating-point reader answered in a shape this window could not read, so nothing is shown for this device. This is a fault in that reader's answer, not a statement about the run."
}

# ONE PAIR IS ONE LINE, AND DATA MAY NOT BREAK THAT.  A newline inside a value
# made one pair render as TWO lines, the second unindented and carrying NO TAG,
# which breaks the one-pair-one-line model `block_text` and `render_pane`
# share -- the paste shape and the pane would then disagree about how many
# lines a block has.  A device name and a parameter name do it too.  Collapsed
# here rather than stripped, so nothing silently joins two words.
proc rdw::_oneline {s} { return [string map [list "\n" { } "\r" { } "\t" { }] $s] }

# ⚠ ONE BLOCK ENTRY IS ONE LINE, AND THE GUARANTEE LIVES AT THE EMIT POINT.
# `_oneline` above covered the three DATA fragments (parameter name, value,
# device name) and nothing else, so the guarantee held for four of the seam's
# five keys and failed on the fifth: `_state_sentence`'s default arm echoes
# the backend's own `state` verbatim, so an answer as small as
#     {devices {} absent {} nonfinite {} complete 0 state "weird\n    id  : 1.11e-05"}
# rendered 4 block entries as 5 lines of text, the extra one a correctly
# indented, correctly formatted operating-point row that NO BUCKET EVER
# CARRIED.  Measured on the fixed tree before this proc existed; the same
# escape existed in `_flaw_line`'s backend name, in `_sim_refusal`, in the
# `dim` device-path line, and in dump_devpath's "could not answer: $ans",
# which interpolates a caught Tcl error and so is multi-line by nature.
# Wrapping each fragment separately would have been nine edits and a tenth
# site the next author forgets, so EVERY line this file appends to a block
# goes through here instead: the paste shape, the pane and the block's own
# entry count can then never disagree, whatever a backend sends.  That is
# invariant I3 read as "a plausible wrong LINE is as bad as a plausible wrong
# number" -- an injected row is indistinguishable from a measured one once it
# is on the clipboard.  The pair rows still one-line their name and value
# BEFORE this point, because the column width is computed from the name and a
# newline would inflate it.
proc rdw::_line {tag text} { return [list $tag [rdw::_oneline $text]] }

# INVARIANT I3, AND THE BLANK'S ONE MEANING.  A `devices` pair carrying no
# value at all, or an empty string, used to render BYTE-IDENTICALLY to an
# ABSENT column -- so the one honest distinction this renderer makes was lost,
# and the per-block blank footnote ("the raw names that column but the
# simulator did not compute it") was then FALSE about them.  Words, in the same
# family as `(did not converge)`, keep the blank glyph meaning exactly one
# thing, and leave the footnote's "rides exactly once" golden where it is.
#
# ISSUE 1341 / RULING DD-7 -- ENGINEERING NOTATION, THROUGH THE SHEET'S OWN
# PROC.  The user asked for "engineering notation - just like annotation on
# the schematic", and "just like" is not "looks similar": `eng_or_blank`
# (src/op_annot.tcl:1266) is the proc `op_annot::text` (:2125) puts on the
# sheet, so calling THAT ONE here is what makes the two surfaces unable to
# disagree about a value nobody wrote a golden for.  It also carries the
# user's own `ev_precision`, which to_eng reads at call time (xschem.tcl:1902)
# and a second %.4g ladder living in this file would not: at the shipped 4 the
# two are numerically identical, and they part company the first time the user
# sets it to 6 -- which is exactly the disagreement this item exists to stop.
#
# ⚠ IT IS A WRAPPER, NOT A SUBSTITUTION.  DD-7 rejects the one-liner
# `set v [::op_annot::eng_or_blank $v]` at the call site, because that proc
# returns EMPTY for everything that is not a finite double and this window's
# values frequently are not one.  Four arms, and three of them are the reason:
#
#   BLANK      stays first and stays words (issue 1284, above).
#   A NUMBER   is engineered by the sheet's proc.
#   NOT A
#   NUMBER     passes through VERBATIM.  A model name, a `-` placeholder for a
#              column the PDK declines to compute, a geometry already written
#              `1.5u`, a swept pair `1.5 2.5`: the one-liner blanks every one
#              of them, and a blanked value here does not read as "not a
#              number", it reads as the ABSENT column's blank -- whose footnote
#              then says something FALSE about it.
#   A NON-
#   FINITE
#   NUMBER     gets `_nonfinite_text`, the words the nonfinite BUCKET already
#              gets.  eng_or_blank blanks `nan`, and an empty string where
#              `nan` used to print is issue 1272's defect wearing engineering
#              notation -- a silent loss of the one thing the user needed
#              told.  Invariant I3 forbids painting the raw `nan` too, so the
#              old pass-through was not the answer either.
#
# ⚠ THE `string is double -strict` GATE IS WHAT SPLITS THE LAST TWO, and it is
# also a lock on the safety gate eng_or_blank already carries: to_eng is
# `uplevel #0 expr [join $args]`, so a NON-NUMERIC string that reached it
# unguarded would EVALUATE at global scope -- and these values arrive from a
# raw file.  A `devices` pair holding `[set ::whatever 1]` is not a double, so
# it never gets near it.  This file therefore names eng_or_blank and never
# names to_eng; the suite's row EN2 fences both halves by counting them here.
#
# ⚠ AND THE GATE STOPS THE COMMAND SUBSTITUTION, NOT THE EVALUATION -- ISSUE
# 1345 CORRECTED THE PARAGRAPH ABOVE, WHICH OVERSTATED IT.  Every string that
# PASSES the gate still reaches `expr` at global scope, and expr REBASES
# numeric literals.  MEASURED on this binary, window and sheet alike:
#   010 -> 8   007 -> 7   00000000012 -> 10   0x10 -> 16   0b101 -> 5
# (`08` and `09` are not doubles at all and take the verbatim arm.)  So a
# leading-zero value prints as a DIFFERENT NUMBER, in both surfaces.  NOT
# HARDENED HERE, deliberately: normalising the literal in this file would
# print 10 where the sheet prints 8, which is the one disagreement ruling DD-7
# forbids, and to_eng is the whole tree's formatter and not this window's to
# redefine.  Latent as shipped -- the only registrant of the `devices` bucket
# (ase.tcl:9098) fills it from `xschem raw value` through op_annot::raw_class,
# i.e. C-formatted decimals that never carry a leading zero -- and the
# plausible way in is a future TEXT-PARSING producer such as the blanket
# `set altshow` dump (issues 1333-1336).  Row EN9 pins the agreement and the
# measured values, so a one-sided hardening reds rather than drifts.
#
# ⚠ `1e400` IS THE INPUT THAT MADE THE NON-FINITE ARM WORTH ITS OWN BRANCH.
# MEASURED on this binary: it passes `string is double -strict`, and `to_eng`
# answers the string `infT` -- which reads like a measurement and would paste
# into a design review as one.  `_finite` catches it (the `$v*0.0 == 0.0`
# raise, op_annot.tcl:1179), which is how it reaches the non-finite arm below.
# Since issue 1345 this proc asks that predicate ITSELF rather than reading
# eng_or_blank's blank as the answer -- see the next paragraph, which is the
# whole reason the order of the two questions matters.
#
# ⚠ AND THE {} FROM A DECLINING FORMATTER IS NOT THE {} FROM A NON-FINITE
# VALUE -- ISSUE 1345, AND READING ONE AS THE OTHER IS THE WORST THING THIS
# WINDOW CAN DO.  This proc used to decide "non-finite" by seeing an EMPTY
# string come back from eng_or_blank.  That proc answers {} for TWO reasons a
# caller cannot tell apart: the value really is nan/inf, or `to_eng` could not
# format a perfectly finite number -- and the second is REACHABLE FROM A
# SHIPPED MENU.  `Simulation > Set netlist / graph / annotation precision`
# (xschem.tcl:17738-17740) is a bare `input_line` with no validation whose OK
# button runs `eval set ev_precision [.dialog.f1.e get]`, so anything typed
# sticks; MEASURED, all eight of `-1  2.5  abc  4x  +4  0x4  6.  6.0` stick and
# all eight make `format %.${pr}g` raise inside to_eng (:1928/1930).  From that
# moment EVERY correctly measured value in this pane read `(did not converge)`
# -- a statement about the CIRCUIT, for a number the simulator computed
# perfectly well, on the one surface this feature exists to have pasted into a
# design review.  It also broke this item's own headline promise: the SHEET
# blanks the row there (op_annot.tcl:2125 emits `id =`) while the window
# asserted a non-convergence, so the two surfaces DID disagree.
#
# ⚠ THE PARAGRAPH ABOVE DESCRIBES A DOOR THAT IS NOW SHUT -- ISSUES 1352 AND
# 1602 -- AND IT IS KEPT BECAUSE IT IS WHY THIS PROC IS SHAPED AS IT IS.  Two
# halves of it are no longer true of the shipped tree.  `eval set ev_precision
# [.dialog.f1.e get]` became `eval $cmd [list [.dialog.f1.e get]]` in 2a22bfb7
# (issue 1352: the typed text was being run as a script).  And since issue 1602
# the menu entry routes through `set_ev_precision` (xschem.tcl, just above
# to_eng), which REFUSES anything that is not a plain decimal integer from 1 to
# 71 and says so, so none of the eight values above can reach ev_precision from
# that dialog any more.  THE FALLBACK BELOW IS STILL LOAD-BEARING: a
# ~/.xschem/xschemrc line `set ev_precision abc` never passes that gate, and
# 1602 measured a class the old table missed -- `4f`, `4s` and `4e0` do not
# raise at all, they end the format specifier early and print a DIFFERENT
# NUMBER (a true 1.11e-05 became `11.1000gu`), which no fallback can catch.
#
# THE FIX IS TO ASK, NOT TO INFER.  `op_annot::_finite` (op_annot.tcl:1179) is
# the discriminator eng_or_blank gates on itself, so consulting it adds no
# second opinion about what non-finite means -- the drift item R5 exists to
# remove -- and it also subsumes the old NOFMT sentinel: with the predicate
# asked FIRST, an empty answer can only be the formatter declining, and the
# fallback is the raw text, unformatted but TRUE.  Rows EN8 (behavioural, all
# eight precisions) and EN10 (structural, the predicate is asked and asked
# first) fence it.
#
# TWO COSTS, both recorded on rule debt 1345_window_prints_what_the_sheet_blanks.
#   (1) In that state the window prints a number where the sheet prints a
#       BLANK.  Every alternative is worse: `(did not converge)` is false,
#       and a blank here means "the raw names the column but the simulator did
#       not compute it" and its footnote would then lie about a measured value.
#   (2) An op_annot that never loaded (unreachable as shipped -- xschem.tcl
#       :16780 sources it before :16821 sources this file) makes _finite raise
#       too, and the catch defaults to FINITE, so a `nan` prints raw again
#       exactly as it did before item R5.  MEASURED by renaming both procs
#       away: 1.11e-05 -> `1.11e-05`, nan -> `nan`, and both come straight back
#       when they are renamed home.
proc rdw::_value_text {v} {
    if {[string trim $v] eq {}} { return {(no value reported)} }
    if {![string is double -strict $v]} { return [rdw::_oneline $v] }
    ## ISSUE 1345.  ASK, DO NOT INFER.  op_annot::_finite is the predicate
    ## eng_or_blank itself gates on, so there is exactly one spelling of "is
    ## this finite" between the two surfaces and they cannot disagree about a
    ## non-convergence.  It is consulted BEFORE the words are chosen, which is
    ## what stops an empty formatter answer being read as a verdict.
    set fin 1
    if {[catch {::op_annot::_finite $v} fin]
        || ![string is boolean -strict $fin]} { set fin 1 }
    if {!$fin} { return [rdw::_nonfinite_text $v] }
    ## FINITE FROM HERE DOWN, so an empty answer is the FORMATTER declining and
    ## nothing else, and the fallback is the raw text -- unformatted but TRUE.
    set e {}
    catch {set e [::op_annot::eng_or_blank $v]}
    if {$e ne {}} { return [rdw::_oneline $e] }
    return [rdw::_oneline $v]
}

# OBLIGATION 3.  The four non-`ok` states otherwise all arrive as the same
# empty list, and `ok` with an empty union is a FIFTH silence -- the common
# one under measured rule R1 (gm/gds/vth exist only if the deck saved them;
# `save all` does not include them), and neither an error nor a bug.
proc rdw::_state_sentence {state ctx} {
    set inst {}
    catch {set inst [dict get $ctx instname]}
    set dp {}
    catch {set dp [dict get $ctx devpath]}
    set sty {}
    catch {set sty [dict get $ctx simtype]}
    switch -exact -- $state {
        no_raw {
            return {No simulation results are loaded. Run a simulation, or load a raw file, then ask again.}
        }
        not_annotated {
            return {Operating-point results are loaded but nothing has been published from them yet. Annotate them first (Waves > Op Annotate, or key 6), then ask again.}
        }
        not_op {
            ## ⚠ `[rdw::_article]`, NOT A BARE `a` -- ISSUE 1297. The analysis
            ## kind comes from the simulator, so the sentence read "a op
            ## analysis" for the one kind this window exists to talk about.
            return "The loaded results are [rdw::_article $sty] $sty analysis, not an operating point. Nothing was read from them: load the operating-point results and ask again. (An OP+TRAN run writes both to one file, and reading the transient makes it the current one.)"
        }
        no_devpath {
            return "$inst has no operating-point descriptor, so there is no device path to ask about. A PDK registers one with op_annot::register."
        }
        ok {
            return "This run's raw holds no operating-point columns for $dp. Only parameters the deck explicitly saved appear here."
        }
    }
    return "The operating-point reader answered with a state this window does not know: '$state'."
}

# THE BLOCK.  `ans` is the seam's five-key answer; `ctx` is
# {header devpath simtype instname}.  Returns an ordered list of {tag line}
# pairs -- ONE model, rendered to the pane by rdw::render_pane and to the
# paste shape by rdw::block_text, so the two can never drift.
#
#   line 1  M2B:/xdut/xbg/xamp1        tag hdr   (Q6's default, as asked)
#   line 2  the raw's own device path  tag dim   (what a user pastes into
#                                                 ngspice; omitted when empty)
#   line 3  the incompleteness sentence, or the ONE state sentence
#   then    per primitive of the union, "  <rawdev>", suppressed only when
#           there is exactly one primitive whose name equals line 2
#   then    "    %-*s : %s", the width being the longest param name in the
#           block capped at 24, right-trimmed so a blank leaves no trailing
#           space.  devices pairs first, then nonfinite, then absent.
#   then    the blank-value footnote, only when `absent` is non-empty
#   then    ONE empty separator line.
#
# ⚠ DATA NEVER BECOMES A FORMAT SPEC.  The format string is a literal and
# every value is an argument, nothing is `subst`ed or `eval`ed, so a `%` or a
# `[` in a device path or a parameter name passes through verbatim.
proc rdw::format_answer {ans ctx} {
    set hdr {}
    catch {set hdr [dict get $ctx header]}
    set dp {}
    catch {set dp [dict get $ctx devpath]}
    ## ISSUE 1284, SECOND PASS.  THE STATE COMES FIRST, AND THE ORDER IS HALF
    ## THE FIX -- B2a's version consulted `_answer_flaw` ELEVEN LINES ABOVE
    ## this branch, so a legal `{state no_raw}` was accused of being malformed.
    ## Three arms, in this order and no other:
    ##   (a) NO READABLE STATE, including an `ans` that is not a dict at all,
    ##       is itself a malformed answer -> the sentence naming the backend.
    ##   (b) A NON-`ok` STATE is a complete and legal answer on its own -> its
    ##       own sentence, with NO shape check, because a refusal makes no
    ##       claim about data and nothing may walk what it did not claim.
    ##   (c) ONLY UNDER `ok` is the shape consulted, and there only for a
    ##       bucket that is PRESENT.
    lassign [rdw::_answer_state $ans] hasstate state
    if {!$hasstate} {
        set who {}
        catch {set who [dict get $ctx sim]}
        return [rdw::_refusal $ctx [rdw::_flaw_line $who]]
    }
    if {$state ne {ok}} {
        return [rdw::_refusal $ctx [rdw::_state_sentence $state $ctx]]
    }

    ## A malformed answer that DOES claim `ok` must not reach any walk below,
    ## and must not fall into the fifth silence -- which is a statement about
    ## the RAW and would be false.  The sentence names the backend because the
    ## remedy is there.
    if {[rdw::_answer_flaw $ans]} {
        set who {}
        catch {set who [dict get $ctx sim]}
        return [rdw::_refusal $ctx [rdw::_flaw_line $who]]
    }

    set out {}
    lappend out [rdw::_line hdr $hdr]
    if {$dp ne {}} { lappend out [rdw::_line dim $dp] }

    set devs [rdw::_rowdevs $ans]
    if {[llength $devs] == 0} {
        lappend out [rdw::_line note [rdw::_state_sentence $state $ctx]]
        lappend out [list {} {}]
        return $out
    }

    ## RULING DD-5.  Between the device path and the incompleteness line, so a
    ## reader learns WHAT the numbers are before being told the list of them is
    ## partial.
    set an [rdw::_analysis_line $ctx]
    if {$an ne {}} { lappend out [rdw::_line note $an] }

    set inc [rdw::_incomplete_line $ans]
    if {$inc ne {}} { lappend out [rdw::_line note $inc] }

    ## ISSUE 1300.  THE NARROWING, AND ITS SENTENCE.
    ##
    ## ⚠ THE ORDER OF THE TWO NOTES IS DELIBERATE.  DD-1's incompleteness line
    ## is about THE RUN -- these are the columns the deck saved -- and this one
    ## is about THE DISPLAY.  A reader learns what the numbers are, then that
    ## the run's set is partial, then that the pane narrowed it further; put
    ## the other way round the DD-1 sentence reads as an explanation of the
    ## narrowing, which is a different and false claim.
    ##
    ## ⚠ AND THE ANSWER IS REPLACED, NOT SIDE-STEPPED.  Everything below --
    ## the row set, the width, the sub-header suppression, the absent footnote
    ## -- is computed from `$ans`, so narrowing the ANSWER narrows all of them
    ## with one change and leaves each of those decisions with exactly one
    ## implementation.  A filter applied only to the row loop would have left
    ## the footnote explaining a blank that is no longer on screen and the
    ## width padding to a name that is no longer printed.
    set norder {}
    set nspec [rdw::_narrow_spec $ctx]
    if {$nspec ne {}} {
        set norder [lindex $nspec 2]
        lassign [rdw::_narrow_answer $ans $norder] ans ntot nkept nwnf
        lappend out [rdw::_line note \
            [rdw::_narrow_line \
                [rdw::_narrowed_list [lindex $nspec 1] [lindex $nspec 0] \
                                     [lindex $nspec 3]] \
                $ntot [expr {$ntot - $nkept}] $nwnf [llength $norder]]]
        set devs [rdw::_rowdevs $ans]
    }

    set pairs [dict create]
    catch {set pairs [dict get $ans devices]}
    set abs {}
    catch {set abs [dict get $ans absent]}
    set nf {}
    catch {set nf [dict get $ans nonfinite]}

    set rows {}
    set w 0
    foreach d $devs {
        set r {}
        if {[dict exists $pairs $d]} {
            ## ⚠ THE PARAMETER NAME AND THE VALUE ARE BOTH ONE-LINED, AND A
            ## VALUE-LESS OR EMPTY PAIR BECOMES WORDS (issue 1284).  An absent
            ## column's blank is built below and is deliberately NOT passed
            ## through _value_text: the blank has exactly one meaning and the
            ## per-block footnote is what says it.
            foreach pv [dict get $pairs $d] {
                lappend r [list [rdw::_oneline [lindex $pv 0]] \
                                [rdw::_value_text [lindex $pv 1]]]
            }
        }
        foreach e $nf {
            if {[lindex $e 0] eq $d} {
                lappend r [list [rdw::_oneline [lindex $e 1]] \
                                [rdw::_nonfinite_text [lindex $e 2]]]
            }
        }
        foreach e $abs {
            if {[lindex $e 0] eq $d} {
                lappend r [list [rdw::_oneline [lindex $e 1]] {}]
            }
        }
        foreach pv $r {
            set l [string length [lindex $pv 0]]
            if {$l > $w} { set w $l }
        }
        lappend rows [list $d $r]
    }
    if {$w > 24} { set w 24 }

    # RULING D-3.  One XR1 resolves to several primitives and two of them can
    # both publish a parameter spelled `i`; without the per-primitive
    # sub-header the two numbers cannot be told apart, which is exactly why
    # the seam's return shape was amended from a flat {param value} list.
    # Suppressed on the ordinary single-primitive case, where it would just
    # repeat line 2.
    set showdev 1
    if {[llength $devs] == 1 && [lindex $devs 0] eq $dp} { set showdev 0 }

    foreach dr $rows {
        if {$showdev} { lappend out [rdw::_line dev "  [lindex $dr 0]"] }
        foreach pv [lindex $dr 1] {
            lappend out [rdw::_line {} [string trimright \
                [format {    %-*s : %s} $w [lindex $pv 0] [lindex $pv 1]]]]
        }
    }
    if {[llength $abs] > 0} { lappend out [rdw::_line note [rdw::_absent_line]] }
    lappend out [list {} {}]
    ## ISSUE 1300, THE ORDER HALF.  A narrowed block is rendered in THE LIST'S
    ## OWN ORDER, not the raw file's, and the permutation is `_reslot_block`'s
    ## -- item R2's, unchanged and re-used.  Two reasons, and neither is taste:
    ## item R2 (issue 1338) already promises that Up and Down move the row in
    ## this window, and a key that re-rendered in raw order would undo that
    ## promise on the very next press of 1; and "the list's order" then has one
    ## implementation in this file instead of two that can disagree.
    ##
    ## Every surviving row is one the list declares -- that is what the filter
    ## did -- so the permutation is TOTAL within each primitive and cannot
    ## leave a row stranded.  It stays confined to one primitive's contiguous
    ## run (ruling D-3), so no number moves under a device that did not publish
    ## it.  The un-narrowed block is not re-slotted at all: key 3's order is
    ## the raw file's, by ruling D-5, and there is no list to sort it by.
    if {[llength $norder]} {
        set out [lindex [rdw::_reslot_block $out $norder] 0]
    }
    return $out
}

# The paste shape: the block's lines, tags dropped.  The trailing separator
# makes the text end in a newline, so two dumps pasted one after the other are
# separated in the document too.
proc rdw::block_text {block} {
    set out {}
    foreach e $block { lappend out [lindex $e 1] }
    return [join $out "\n"]
}

# Spec 4.2 B7's table, AS DATA rather than as a switch buried in a widget
# callback, so the greying can be asserted with no Tk.
#
#   button        annotation (1)   summary (2)   all (3)
#   Up / Down     reorder          reorder       reorder
#   Delete        remove           remove        GREYED   (list 3 is live from
#                                                          the run and has no
#                                                          persisted state)
#   Add           --               add           add (the dialog asks which)
#   Save          write            write         write
#
# The spec's Add cell for list 1 is an em dash, which does not say greyed
# versus absent.  DECISION (ladder L2, rule debt 1245_B3_add_greyed_on_list1):
# GREYED.  The column then keeps a constant shape as the user switches lists;
# an absent button moves the other four under the pointer.
proc rdw::button_state {id kind} {
    if {$id eq {add} && $kind eq {annotation}} { return disabled }
    if {$id eq {delete} && $kind eq {all}} { return disabled }
    return normal
}

# THE LIST ACTIONS' ids AND LABELS, ONCE (invariant I1).  `rdw::build` packs
# them, `rdw::apply_list_state` greys them and `rdw::_button_label` reads them
# back to name the button in the status line; two literal lists would drift the
# moment a label is reworded, and the status line's whole obligation is that a
# message NAMES THE BUTTON IT CAME FROM.
#
# ⚠ IT IS NOT THE COLUMN'S WIDGET LIST, AND THE DIFFERENCE IS LOAD-BEARING.
# Two widgets sit in `.rdw.b` and deliberately outside this table: `aA` (issue
# 1368) and Close (issue 1382).  Neither acts on a list, so neither may enter
# `rdw::_active_phrase`'s sentence about which buttons act on THIS list, and
# neither is ever greyed -- which is exactly what being absent here buys, since
# `rdw::apply_list_state` configures a -state only for what this table names.
proc rdw::_buttons {} { return {up Up down Down delete Delete add Add save Save} }

proc rdw::_button_label {id} {
    foreach {i l} [rdw::_buttons] { if {$i eq $id} { return $l } }
    return {}
}

# WHICH BUTTONS ACTUALLY DO SOMETHING ON THIS LIST IDENTITY, ONCE.
#
# ⚠ IT EXISTS BECAUSE THE CHROME LINE SPELLED THE ANSWER BESIDE THE CODE THAT
# DECIDES IT AND THE TWO PARTED COMPANY.  List 3's sentence said "only Add
# works here"; `rdw::button_state` returns `normal` for `save` on EVERY kind,
# and an adversary pressed Save on list 3 and got a 1627-byte
# op_param_lists.conf written to disk.  Nothing in the tree tested Save's
# success arm at all, so one row golded the false literal and no row could
# contradict it.  Deriving the sentence from this proc is what makes the two
# move together; row LX12 is the fence.
#
# TWO REASONS A BUTTON DOES NOTHING, AND BOTH ARE `rdw::button`'s OWN ARMS:
#   * it is GREYED -- `rdw::button_state`, which the command path consults too;
#   * it is enabled and REFUSES ON IDENTITY GROUNDS.  Up and Down on list 3
#     answer "list 3 is live from the simulator and has no stored order to
#     change", which is a property of the identity and not of the cursor, so it
#     can be answered here.  Every other refusal in that proc is about the
#     STATE of the moment -- no dump yet, no row marked, a pick running -- and
#     is deliberately NOT modelled: a chrome line that changed as the user
#     clicked would be describing the moment rather than the list.
proc rdw::_active_buttons {kind} {
    set out {}
    foreach {id label} [rdw::_buttons] {
        if {[rdw::button_state $id $kind] ne {normal}} { continue }
        if {$kind eq {all} && ($id eq {up} || $id eq {down})} { continue }
        lappend out $id
    }
    return $out
}

# The same answer as a clause, in the LIST ACTIONS' own labels
# (`rdw::_buttons`), so the sentence names what the user is looking at.
#
# ⚠ IT IS A CLAIM ABOUT THE FIVE, NOT ABOUT THE COLUMN, AND THE TWO STOPPED
# BEING THE SAME THING AT ISSUE 1368.  `.rdw.b` also holds `aA` (1368) and
# Close (1382), neither of which acts on a list and neither of which is in
# `rdw::_buttons`, so on list 3 the sentence reads "only Add and Save do
# anything here" over a column of seven controls, four of which do something.
# That is deliberate -- the sentence answers the user's own question, "which of
# these buttons will do something to THIS list" -- but it is looser prose than
# it was when the column and the table were the same five widgets, and it is
# recorded here rather than quietly reworded because the copy is the user's to
# rule on (issue 1382, decision F).
proc rdw::_active_phrase {kind} {
    set names {}
    foreach id [rdw::_active_buttons $kind] { lappend names [rdw::_button_label $id] }
    if {[llength $names] == 0} { return {no button does anything} }
    if {[llength $names] == 1} { return "only [lindex $names 0] does anything" }
    return "only [join [lrange $names 0 end-1] {, }] and [lindex $names end] do anything"
}

# ---------------------------------------------------------------------------
# THE LIST IDENTITY, IN WORDS, ONCE -- ISSUE 1355
# ---------------------------------------------------------------------------
# THE USER'S SECOND COMPLAINT, VERBATIM: "When I use 2 key, the RDW doesn't say
# 'summary' view, so it's not clear.  The fact that the Delete button is NOT
# greyed out is a clue."
#
# It was a true reading of the only signal on offer.  MEASURED at HEAD
# d81b4b24 on the user's own M18:/x1/x1 -- the title was `Results Display
# Window` on all three identities, the status line was EMPTY on the whole dump
# path, and `.rdw` had three children, none of which named a list.  The entire
# on-screen encoding of a three-valued identity was `rdw::button_state`'s two
# booleans over five buttons, wordlessly -- and lists 1 and 2 differ by exactly
# ONE of them, the Add button.  The Delete grey the user reached for separates
# list 3 from the other two and says nothing about 1 versus 2, so their clue
# was evidence for "not list 3" and no evidence at all for "I am on summary".
#
# ⚠ THE GREYING IS NOT THE DEFECT AND IS NOT TOUCHED.  It is DERIVED state and
# it is correct: spec 4.2 B7 says Delete removes from the summary list, and a
# real Delete on summary really does move the store (measured).  What was
# missing is the state it is derived FROM, never stated anywhere.
#
# ⚠ AND THIS IS NOT A SECOND ANNOUNCEMENT BESIDE THE BLOCK'S.  Issue 1353's
# `rdw::_narrow_line` already names a list, in the PAST tense, about THE BLOCK
# -- "at this dump" -- because a block is a RECORD that travels
# with the paste.  What follows is PRESENT tense and about THE BUTTONS: the
# identity `::rdw::listkind` holds NOW, which is what Up, Down, Delete and Add
# will act on whatever dump the user happens to be reading.  Two facts, two
# tenses, one builder each and no third: press 2 without re-dumping and the
# block still says `annotation` over buttons acting on `summary`, which is the
# gap the user fell into.  Rows LX5 and LX10 of the window suite are the
# fences.
#
# One table for the NAME, one for the GLOSS, and a phrase that composes them,
# for the same reason `rdw::_buttons` exists: four surfaces read these strings
# -- the scope dialog's two radiobuttons, the scope dialog's new statement, the
# chrome line and the window title -- and four literals would drift the moment
# one of them is reworded.  This file's own rule, at rdw::_edit's store tail:
# "no second wording for a fact the store already words".

proc rdw::_list_name {ln} {
    switch -exact -- $ln {
        annotation { return {the annotation list} }
        summary    { return {the summary list} }
        all        { return {everything this run published} }
    }
    return {}
}

proc rdw::_list_gloss {ln} {
    switch -exact -- $ln {
        annotation { return {drawn on the sheet} }
        summary    { return {computed, not drawn} }
        all        { return {live from the simulator} }
    }
    return {}
}

proc rdw::_list_phrase {ln} {
    set n [rdw::_list_name $ln]
    if {$n eq {}} { return {} }
    return "$n ([rdw::_list_gloss $ln])"
}

# THE LIST AN EDIT FROM THIS BUTTON WILL ACTUALLY WRITE, WHICH IS NOT ALWAYS
# THE LIST THE USER IS STANDING ON.
#
# ⚠ SPEC 4.2 B7's Add CELL: "annotation list (1): -- | summary list (2): add to
# annotation | all (3): add to annotation or summary (the dialog asks which)".
# So an Add pressed on the SUMMARY list writes the ANNOTATION list.  MEASURED
# on the user's own M18, standing on summary with the dialog naming no list at
# all: `Add: gm is already in the mos annotation list` -- a verdict about a
# list the window had given them no reason to think they were editing.  That is
# the same failure as the Delete complaint, one button along.
#
# The behaviour is the spec's and is not changed here; what changes is that
# there is now ONE proc that answers "which list", so `rdw::button`'s default,
# `rdw::scope_dialog`'s pre-set choice and the dialog's own statement cannot
# give three answers.  Whether Add SHOULD write the annotation list from list 2
# is a question for the user: issue 1357, rule debt 1357.
proc rdw::_edit_list {op kind} {
    if {$op eq {add} || $kind eq {all}} { return annotation }
    return $kind
}

# THE SCOPE DIALOG'S STATEMENT, OR {} ON LIST 3 WHERE THE QUESTION ALREADY ASKS.
#
# THE USER'S OWN WORDS: "I ... press Delete and get the pop up dialog asking
# where to apply, but it doesn't say 'summary list' - which would be good for
# the user to know."  MEASURED: on annotation and on summary the dialog is
# BYTE-IDENTICAL and names no list; only on list 3 does it name one, because
# only there does it have to ASK.  So the answer is a STATEMENT in the exact
# slot list 3 uses for its QUESTION -- same widget path, same padding -- and
# the dialog names a list in all three states instead of one.
#
# ⚠ IT NAMES THE TARGET, NOT THE IDENTITY.  Naming `::rdw::listkind` would have
# printed "the summary list" over an Add that writes the annotation one, which
# is worse than the silence it replaces.
proc rdw::_scope_statement {op listname} {
    if {$listname eq {all}} { return {} }
    set t [rdw::_edit_list $op $listname]
    set s "This changes [rdw::_list_phrase $t]."
    if {$t ne $listname} {
        append s " Add writes there even from [rdw::_list_name $listname] -\
 press 3 first to choose the list."
    }
    return $s
}

# THE CHROME LINE ABOVE THE PANE.
#
# ⚠ PRESENT TENSE, AND ABOUT THE BUTTONS RATHER THAN ABOUT THE PANE.  The
# clause that matters is "not the block you are reading": the user pressed
# Delete while looking at a block, and the buttons obey `::rdw::listkind`,
# which a key press moves without re-rendering anything.
#
# ⚠ AND IT DOES NOT SAY THE PANE IS WIDER THAN THE LIST.  The diagnosis that
# proposed this line also proposed a second sentence -- "The pane shows every
# row this run published" -- and said in the same breath that it must be
# DELETED when the narrowing landed.  It landed FIRST (issue 1353), so the
# sentence is never written.  A window that went on telling the user the pane
# is wider than the list after it stopped being true would be the defect this
# file already carries a scar from: a status line citing a fixed issue 1312 as
# its reason.  Row LX4 is the fence.
#
# ⚠ LIST 3's SENTENCE NAMES THE BUTTONS THAT WORK THERE, AND IT ASKS RATHER
# THAN SPELLS.  It used to read "only Add works here", which was FALSE: Save is
# not greyed on any list and a real press on list 3 wrote a 1627-byte
# op_param_lists.conf to disk.  `rdw::_active_phrase` is now the one answer and
# this line quotes it; row LX12 is the fence.  On lists 1 and 2 the pane shows
# only rows the list already declares (issue 1353), so an Add from a narrowed
# pane can only ever answer "already in the list" -- press 3, click the row,
# press Add is the working path, and nothing on screen said so before this
# line.
#
# ⚠ AND THE `Keys 1/2/3:` PREFIX IS CONDITIONAL, BECAUSE THE KEYS ARE.  Ruling
# D-2 puts the bare digits in the CADENCE PROFILE ONLY (src/cadence_style_rc),
# while src/xschem.tcl adds Tools > Results Display Window UNCONDITIONALLY.
# MEASURED with no cadence rc sourced: `bind .drw <Key-1>` is the empty string,
# real Key-1/2/3 events on the canvas leave `::rdw::listkind` where it stood,
# and the label named them anyway -- false on every open of this window outside
# that profile, on a surface written to answer a user's confusion.  The advice
# "press 1 or 2 to edit a list" goes with it for the same reason.  Rows LX14
# (both values, pure) and LK3 (off the real binds of the real canvas) fence it.
#
# ⚠ AND THE SUMMARY LINE CARRIES THE Add EXCEPTION, because "the buttons edit
# this list" was FALSE THERE.  Spec 4.2 B7 sends an Add made from list 2 to the
# ANNOTATION list -- `rdw::_edit_list` is that answer, the scope dialog already
# says it out loud (`rdw::_scope_statement`), and this line said the opposite
# three rows away in the suite.  The exception is DERIVED from the same proc,
# so if issue 1357 ever rules that Add should write the summary list the
# sentence follows.  Row LX13 asserts the claim against the code.
proc rdw::_chrome_add_note {kind} {
    if {$kind eq {all}} { return {} }
    if {[rdw::button_state add $kind] ne {normal}} { return {} }
    set t [rdw::_edit_list add $kind]
    if {$t eq $kind} { return {} }
    return " Add writes [rdw::_list_name $t]."
}

# DO THE BARE 1/2/3 DIGITS THIS LINE NAMES ACTUALLY REACH THIS WINDOW?
#
# It asks the LIVE BINDINGS rather than a profile flag, because the binds are
# what the user's fingers meet: an rc that rebinds them, a profile that does
# not source cadence_style_rc, and a future menu route all give the same
# honest answer.  `rdw::key` is the one thing those binds call and has no
# other caller, so its name in the script is the test.
#
# ⚠ AND IT ASKS BOTH WIDGETS, WHICH IT DID NOT (issue 1367).  It used to ask
# the CANVAS alone, and that was right only until issue 1358 bound the same
# four digits on `.rdw` itself so the window could hear its own refresh keys.
# After that a stock profile answered 0 -- the canvas has no such binds -- and
# the chrome fell to its unkeyed wording while the digits really did work,
# with the keyboard inside the window.  The line was then false in the
# direction that matters least (it under-promised), but the SAME zero drove
# the "Showing" head, which over-promised: see below.  The keys reach this
# window if EITHER widget carries them.
proc rdw::_keys_bound {} {
    if {![rdw::have_tk]} { return 0 }
    foreach w {.drw .rdw} {
        if {[catch {winfo exists $w} ok] || !$ok} { continue }
        set all 1
        foreach k {<Key-1> <Key-2> <Key-3>} {
            set b {}
            if {[catch {bind $w $k} b]} { set all 0 ; break }
            ## Either spelling of the one door: the canvas binds call
            ## `rdw::key` directly, the window's own binds (issue 1358) go
            ## through `rdw::_digit`, and `rdw::_digit`'s only act is to call
            ## `rdw::key`.  Both names, because matching one of them made a
            ## stock profile answer 0 while the digits really worked.
            if {![string match {*rdw::key*} $b] &&
                ![string match {*rdw::_digit*} $b]} { set all 0 ; break }
        }
        if {$all} { return 1 }
    }
    return 0
}

# THE TEXT, PURE, SO EVERY COMBINATION OF `keyed` AND `filled` IS ASSERTED ON
# THE ARM WITH NO DISPLAY AT ALL (row LX14).  `rdw::_chrome_line` is the one
# caller and is the only thing here that touches the live keyboard or the
# store.
#
# ⚠ `Showing` IS A CLAIM ABOUT THE PANE, AND THE PANE CAN BE EMPTY (issue
# 1367).  MEASURED in a stock profile, driven through the Tools menu entry
# src/xschem.tcl:17638 adds unconditionally: the window opens, `.rdw.p.t` holds
# ONE character -- the Tk text widget's mandatory trailing newline -- and
# `::rdw::blocks` is empty, while this line read `Showing the annotation list
# (drawn on the sheet) - the buttons edit this list, not the block you are
# reading.`  Two false statements in one sentence: nothing was being shown, and
# there was no block to be reading.  The previous wording, `Keys 1/2/3:`, was
# false in a stock profile for its own reason and was replaced BY that
# sentence; a third wording that is false in a fourth way is not progress, so
# the emptiness is asked about rather than assumed.
#
# The three heads say only what is true of the state they are in:
#   filled          -> `Showing <list>`, which is now a claim the pane backs;
#   empty, keyed    -> nothing is here yet AND the way to put something here;
#   empty, unkeyed  -> nothing is here yet, and no promise about a key.
proc rdw::_chrome_text {kind keyed {filled 1}} {
    set p [rdw::_list_phrase $kind]
    if {$p eq {}} { return {} }
    if {!$filled} {
        set h "No device has been sent here yet - $p"
        if {$keyed} {
            return "$h. Select a device and press [rdw::_digit_for $kind]."
        }
        return "$h."
    }
    set head [expr {$keyed ? "Keys 1/2/3: $p" : "Showing $p"}]
    if {$kind eq {all}} {
        set s "$head -"
        if {$keyed} { append s " press 1 or 2 to edit a list;" }
        return "$s [rdw::_active_phrase $kind] here."
    }
    return "$head - the buttons edit this list, not the block you are\
 reading.[rdw::_chrome_add_note $kind]"
}

# WHICH DIGIT SELECTS THIS LIST, out of `rdw::_digit_map` and never out of a
# second literal -- the map is already the one answer issue 1358's row KB1
# locks against src/cadence_style_rc, so a digit that changes meaning changes
# here too.
proc rdw::_digit_for {kind} {
    foreach {d k} [rdw::_digit_map] { if {$k eq $kind} { return $d } }
    return 1
}

proc rdw::_chrome_line {kind} {
    variable blocks
    return [rdw::_chrome_text $kind [rdw::_keys_bound] \
                [expr {[llength $blocks] > 0 ? 1 : 0}]]
}

# THE WINDOW TITLE.  The SECOND surface, not the first: a window manager may
# truncate it and it is the furthest thing on screen from the pane.  It is
# taken anyway because it is the one surface that survives the window being
# small or the pane being scrolled, and it is what an alt-tab shows.  An
# identity this window cannot name falls back to the spec's plain title rather
# than to a half-written one.
proc rdw::_title {kind} {
    set n [rdw::_list_name $kind]
    if {$n eq {}} { return {Results Display Window} }
    return "Results Display Window - $n"
}

# ---------------------------------------------------------------------------
# TWO ONE-LINE ACCESSORS THAT NAME A CHOICE THE WHOLE WINDOW RESTS ON.
# They exist so the choice has ONE place, and so a reviewer can flip either
# and watch the suite say which promise broke.

# The pane is READ-ONLY.  Nobody may type into a record of a simulation.
proc rdw::_pane_state {} { return disabled }

# The pane owns the X PRIMARY selection.  This is the user's stated reason the
# window exists at all: select, Ctrl-C, paste into a design-review document.
proc rdw::_exportsel {} { return 1 }

# NEWEST DUMP ON TOP.  One accessor names the end of the pane a new dump lands
# at, and both the store (rdw::push) and the view (rdw::render_pane) honour
# it, so they cannot disagree about which end is new.
proc rdw::_insert_index {} { return 1.0 }

# ---------------------------------------------------------------------------
# THE CONTEXT LAYER.  Reads xschem and op_annot; still no Tk.

# {cadence-line devpath-line}.
#
# ⚠ INVARIANT I1, ONE NAME BUILDER.  Line 2 is op_annot::devpath's OWN string,
# byte for byte, including the empty string for an instance no descriptor
# claims.  This file builds no raw device name of its own, ever: a hand-built
# path spelled without the leading `@` makes the seam answer
# `devices {} state ok`, byte-identical to "unknown device", which is the
# wrong-answer-wearing-a-healthy-state that returned item B1 [F].
proc rdw::header {instname} {
    set p {}
    catch {set p [xschem get sch_path]}
    set dp {}
    catch {set dp [::op_annot::devpath $instname]}
    return [list "$instname:[rdw::_cadence_path $p]" $dp]
}

# Which backend answers.  An explicit ::rdw::sim override wins (the suite and
# items B4/B5 drive it); else the single registered backend when there is
# exactly one; else ngspice if it is registered; else nothing.
#
# ⚠ THE SEAM IS NEVER CALLED BY ITS PROC NAME.  Naming the ngspice proc
# directly is behaviourally identical TODAY, which is precisely why it would
# be a defect: the whole point of the seam is that nothing above it changes
# when the user's wildcard ngspice arrives (ruling D-5).
proc rdw::sim {} {
    variable sim
    if {[info exists sim] && $sim ne {}} { return $sim }
    set names {}
    catch {set names [::ase::backend_names]}
    if {[llength $names] == 1} { return [lindex $names 0] }
    if {[lsearch -exact $names ngspice] >= 0} { return ngspice }
    return {}
}

# A refusal that is still a block: the header the user asked about, and one
# sentence saying why there is no answer.  A caught refusal, never a raise --
# this is reached from a menu item and, later, from a key.
proc rdw::_refusal {ctx text} {
    set hdr {}
    catch {set hdr [dict get $ctx header]}
    set dp {}
    catch {set dp [dict get $ctx devpath]}
    set out {}
    lappend out [rdw::_line hdr $hdr]
    if {$dp ne {}} { lappend out [rdw::_line dim $dp] }
    lappend out [rdw::_line note $text]
    lappend out [list {} {}]
    return $out
}

# THE SEAM'S ONLY DOOR.  Resolve the hook, call it, format the answer, push
# the block.  Returns the block.
# ISSUE 1282 part 2.  "No such simulator" and "a simulator that registered
# without an operating-point reader" are DIFFERENT FACTS WITH DIFFERENT
# REMEDIES -- check the name, versus add a hook -- and this feature's whole
# obligation 3 is that different silences get different sentences.  One
# `catch {ase::backend_hook $s op_param_set}` arm produced ONE sentence for
# both.  ase::backend_hook already mints two distinct errors (ase.tcl:550
# "unknown simulator" and :553 "unknown hook"), so no new information is
# needed, only a caller that asks which case it is -- and asking membership
# BEFORE the call keeps one source of truth rather than parsing an error
# string.  `op_param_set` is deliberately NOT on register_backend's required
# list (ase.tcl:534), so "registered, no reader" is genuinely reachable.
# ⚠ Item B5 is the first thing that sets ::rdw::sim, so the split has to exist
# before B5, not after.
proc rdw::_sim_refusal {s} {
    set names {}
    catch {set names [::ase::backend_names]}
    if {[lsearch -exact $names $s] < 0} {
        return "No simulator named $s is registered, so there is nothing to ask for this device. Check the name, or register a backend for it with ase::register_backend."
    }
    return "Simulator $s is registered but declares no operating-point reader - the op_param_set hook - so this window has nothing to show for it. A backend adds that hook to publish operating-point columns."
}

# ISSUE 1300.  THE LIST IDENTITY AND THE DEVICE'S CLASS, ADDED TO A CONTEXT
# THAT DOES NOT ALREADY CARRY THEM.
#
# ⚠ IT IS THE THIRD THING THE SEAM'S ONLY DOOR AMENDS, FOR THE SAME REASON AS
# THE FIRST TWO.  `sim` was added there for issue 1284 and `simtype` for issue
# 1298, both because items B4 and B5 call `rdw::dump_devpath` with contexts
# they build themselves, and a fact the renderer needs that only ONE caller
# supplies is a fact the other callers silently render without.  The list is
# exactly that shape: `rdw::key` moves `::rdw::listkind` and every other caller
# knows nothing about it.
#
# ⚠ A ctx THAT ALREADY NAMES A LIST WINS, and so does one that already names a
# class.  The suites' hand-built contexts are the reason -- twenty of them in
# `test_rdw_window_1245.tcl` alone -- and the rule is the one `simtype` already
# follows: an explicit value is a caller's decision and this door does not
# overrule it.
#
# ⚠ AND AN UNRESOLVABLE INSTANCE GETS NO CLASS AT ALL, not a guessed one.
# `rdw::_narrow_spec` reads a missing class as "narrow nothing", so a device
# the editor cannot resolve renders exactly the block it renders today rather
# than being narrowed by somebody else's list.  Invariant I3's spirit: a
# missing datum renders blank, never a wrong assertion.
proc rdw::_list_ctx {ctx} {
    variable listkind
    if {![dict exists $ctx list]} { catch {dict set ctx list $listkind} }
    if {![dict exists $ctx class]} {
        set inst {}
        catch {set inst [dict get $ctx instname]}
        set tc [rdw::_type_cell $inst]
        if {$tc ne {}} {
            catch {dict set ctx class [::op_param_lists::class [lindex $tc 0]]}
            catch {dict set ctx cellname [lindex $tc 1]}
        }
    }
    return $ctx
}

## ⚠ THE BUILDER, SPLIT OUT OF THE DOOR (item: blocks follow a list edit).
## `rdw::dump_devpath` is still THE SEAM'S ONLY DOOR for a NEW dump -- every
## comment below about contexts and rulings DD-5/1298/1300 is about this
## builder and still governs -- but a REBUILD of a block already in the store
## must produce a block by exactly the same route, or the two would drift and
## this file would be paying for two builders again (issues 1288, 1300, 1355
## are all that shape).  So: this proc makes a block, `dump_devpath` makes one
## and pushes it, and `rdw::_rebuild_block` makes one and REPLACES with it.
proc rdw::_make_block {devpath ctx} {
    set s [rdw::sim]
    ## The renderer's malformed-answer sentence names the backend, so the
    ## backend has to be in the context it is handed (issue 1284).
    catch {dict set ctx sim $s}
    ## ⚠ AND SO DOES THE ANALYSIS KIND -- ISSUE 1298. This proc is THE SEAM'S
    ## ONLY DOOR, and items B4 and B5 call it with contexts they build
    ## themselves. Ruling DD-5's "name the analysis" sentence was a property of
    ## rdw::dump alone, so any other caller silently got a DC sweep rendered as
    ## an operating point -- the defect issue 1282 was filed and fixed for,
    ## coming straight back through the door the fix did not cover.
    ## A ctx that already carries an explicit `simtype` still wins, so the
    ## suite's hand-built contexts are unaffected, and `{}` stays meaningful:
    ## a failed read and a hand-built ctx both produce it, and _analysis_line
    ## deliberately says nothing for `{}` rather than guess.
    if {![dict exists $ctx simtype]} {
        catch {dict set ctx simtype [xschem raw sim_type]}
    }
    ## ⚠ AND SO DOES THE LIST IDENTITY -- ISSUE 1300, and it is the same
    ## argument a third time: keys 1, 2 and 3 selected a list that never
    ## reached the renderer, so all three printed the same block.
    set ctx [rdw::_list_ctx $ctx]
    if {$s eq {}} {
        set blk [rdw::_refusal $ctx \
            {No simulator backend is registered, so there is nothing to ask for this device.}]
    } elseif {[catch {::ase::backend_hook $s op_param_set} hook]} {
        set blk [rdw::_refusal $ctx [rdw::_sim_refusal $s]]
    } elseif {[catch {uplevel #0 [list $hook $devpath]} ans]} {
        set blk [rdw::_refusal $ctx \
            "The operating-point reader for $s could not answer: $ans"]
    } else {
        set blk [rdw::format_answer $ans $ctx]
    }
    return $blk
}

proc rdw::dump_devpath {devpath ctx} {
    ## ⚠ THE VALUE HANDED BACK IS THE VALUE STORED (issue 1322).  `push`
    ## now stamps the block with what it was about, so returning the builder's
    ## `$blk` would hand the caller an UNSTAMPED copy of a block the store
    ## holds stamped -- two values for one dump, and the caller's is the one
    ## that cannot say which device it came from.
    return [rdw::push [rdw::_make_block $devpath $ctx]]
}

# The whole round trip for one instance name: the header, the ONE name
# builder's device path, the current analysis kind, then the seam.  Item B4
# calls this from its keys.
proc rdw::dump {instname} {
    set h [rdw::header $instname]
    set sty {}
    catch {set sty [xschem raw sim_type]}
    set ctx [dict create header [lindex $h 0] devpath [lindex $h 1] \
                         simtype $sty instname $instname]
    return [rdw::dump_devpath [lindex $h 1] $ctx]
}

# ---------------------------------------------------------------------------
# WHAT A BLOCK WAS ABOUT (issue 1322).
#
# ⚠ A BLOCK USED TO BE A RENDERING WITH NO IDENTITY, AND THAT IS THE DEFECT
# THAT REVERTED ITEM B5-2.  `rdw::header` joins an instance name to a cadence
# path, and `rdw::push` stored the rendered lines and nothing else -- so the
# only surviving trace of WHICH DEVICE a block was about was the header
# STRING, whose NAME half a later button re-resolved against WHATEVER SHEET IS
# OPEN.  Nothing in this tree clears the store on a schematic load, and nothing
# should: reviewing two sheets' dumps side by side is what this window is for.
#
# MEASURED at HEAD with two TOP-LEVEL sheets each holding an `M1` -- the
# default `template="name=M1 ..."` of every device symbol in this tree, which
# makes this the ORDINARY case and not a contrivance:
#     the block on screen was about   ncls / vn.sym
#     the re-resolved subject said    type vpdev class pcls cellname vp.sym
#     Delete's verdict                ok
#     ncls kept its row; pcls lost one -- a device nobody was looking at.
#
# ⚠ AND THE OBVIOUS GUARD IS ALREADY REFUTED BY THAT SAME MEASUREMENT.
# Comparing the header's PATH half catches nothing: `xschem get sch_path` is
# `.` on both sheets, `rdw::_cadence_path` renders `/` for both, and the two
# headers are BYTE-IDENTICAL.  THE AXIS IS SHEET IDENTITY, NOT HIERARCHY PATH,
# and `xschem get schname` is the accessor that separates them.
#
# So the subject is captured AT DUMP TIME, while the sheet it came from is
# still the sheet on screen, and it rides inside the block's OWN HEADER ENTRY
# as a THIRD element.  The block therefore stays ONE FLAT LIST OF ENTRIES:
# `llength $b` is still the block's LINE COUNT, `rdw::block_text` reads
# `lindex $e 1` and is byte-identical, and `rdw::render_pane` paints exactly
# the same number of lines.
#
# ⚠ WHY NOT A PARALLEL SUBJECT LIST.  It would be two structures to keep
# aligned across THREE writers, not two -- `rdw::push`, `rdw::keep_latest`,
# and the suites, which assign the store directly -- and a desynced parallel
# list answers about the wrong block while every existing row stays green.
# That is invariant I1's failure shape, and this batch's own recurring one.
#
# ⚠ AND WHY NOT A NEW BLOCK ENTRY.  An extra entry changes `llength $b`, which
# the pane's line arithmetic uses as a LINE COUNT, and `rdw::block_text` would
# put it straight into the user's paste.
#
# ⚠ THE CLASS IS DELIBERATELY NOT CAPTURED.  `op_param_lists::class` is a pure
# classmap lookup with no sheet dependence, so it already has exactly one home
# (invariant I1); only the `type=` token is sheet-dependent.  A consumer
# derives the class from the captured type.
#
# Suite: tests/headless/test_rdw_window_1245.tcl section BS (both arms) and
# tests/headless/test_rdw_keys_1245.tcl row KS1, which drives the capture
# through the real keybinding rather than through a hand-called push.

# The exact inverse of rdw::header's join.  An instance name may itself carry
# a colon, so the split is on the LAST colon that is followed by the path half
# -- which `rdw::_cadence_path` guarantees always begins with `/`, at the top
# sheet included (`M1:/`).  A line that is not a header at all answers {}.
proc rdw::_hdr_instname {line} {
    if {[regexp {^(.*):(/.*)$} $line -> nm path]} { return $nm }
    return {}
}

# May this `type=` token be recorded as a subject at all?
#
# ⚠ `missing` IS NOT A TYPE.  It is xschem's own placeholder for a symbol the
# editor could not find (systemlib/missing.sym, save.c:7281) -- the same token
# `descend_missing_sym` (actions.c:6049-6063) guards by name.  It matters here
# because `op_param_lists::class` returns the TOKEN for a type nobody mapped,
# BY CONTRACT, so a consumer's "class is empty" guard would wave the
# placeholder straight through and the user would read a sentence naming a
# class no PDK ever declared.  Recording nothing is the honest answer, and
# blank is available HERE and is not available later.
#
# STATED COST: a user-authored symbol that really exists on disk and really
# declares `type=missing` gets no captured subject either.  actions.c's own
# comment records that this is a different fact wearing the same token, and no
# shipped symbol in this tree carries it.
proc rdw::_subject_resolved {type} {
    if {$type eq {}} { return 0 }
    if {$type eq {missing}} { return 0 }
    return 1
}

# Does this block already carry a subject?  One that does is never
# re-captured: it is the record of a dump that already happened, and reading
# the live editor for it again is the very defect the stamp exists to remove.
proc rdw::_stamped {block} {
    set e {}
    if {[catch {lindex $block 0} e]} { return 0 }
    set n 0
    if {[catch {llength $e} n]} { return 0 }
    return [expr {$n >= 3 ? 1 : 0}]
}

# {type cellname} read RIGHT NOW off the live editor for one instance name, or
# {} when the type cannot be trusted (`rdw::_subject_resolved`'s two refusals).
#
# ⚠ IT EXISTS BECAUSE THERE ARE NOW TWO READERS OF THAT PAIR AND ONLY ONE OF
# THEM IS THE BLOCK STAMP (issue 1300).  `rdw::_capture_subject` reads it to
# stamp a block at push time; `rdw::_list_ctx` reads it BEFORE the seam is
# asked, so the renderer knows which class's list narrows this dump.  Two
# inline copies of the same three catches is invariant I1's two-builders drift
# in miniature, and the half that would rot is the `missing` refusal -- which
# is not a courtesy: `op_param_lists::class` answers the TOKEN for a type
# nobody mapped, by contract, so a caller that let xschem's own
# symbol-not-found placeholder through would narrow a pane by a class named
# `missing` and say so on screen.
proc rdw::_type_cell {inst} {
    if {$inst eq {}} { return {} }
    set type {}
    catch {set type [::op_annot::type $inst]}
    if {![rdw::_subject_resolved $type]} { return {} }
    set cell {}
    catch {set cell [xschem getprop instance $inst cell::name]}
    return [list $type $cell]
}

# {instname type cellname schname} read RIGHT NOW -- from the block's own
# header text and the sheet that is still open -- or {} when nothing can be
# trusted.  Every read is caught: a dump must never fail because an instance
# went away between the seam's answer and the push.
proc rdw::_capture_subject {block} {
    set line {}
    catch {set line [lindex [lindex $block 0] 1]}
    set inst [rdw::_hdr_instname $line]
    if {$inst eq {}} { return {} }
    set tc [rdw::_type_cell $inst]
    if {$tc eq {}} { return {} }
    set type [lindex $tc 0]
    set cell [lindex $tc 1]
    set sch {}
    catch {set sch [xschem get schname]}
    ## ⚠ AND THE LIST THIS DUMP WAS TAKEN UNDER.  A rebuild (item: blocks
    ## follow a list edit) has to re-render the block the user is looking at,
    ## and that block's membership was decided by the list in force AT DUMP
    ## TIME -- ruling DD-1's key 1/2/3 identity, carried into the block by
    ## `rdw::_list_ctx`.  Rebuilding a list-2 block under list 1 because list 1
    ## is what the window happens to be showing now would silently rewrite a
    ## dump into a different question's answer.  The store is session-only
    ## (`_do_save` writes the parameter lists, never the blocks), so there is
    ## no stamped-without-it block to migrate.
    variable listkind
    set lk {}
    catch {set lk $listkind}
    return [dict create instname $inst type $type cellname $cell schname $sch \
                        list $lk]
}

# THE ONE READER OF WHERE THE STAMP LIVES, AND A PURE FUNCTION OF ITS
# ARGUMENT.  It reads no namespace state whatever, so a caller that assigns the
# store directly -- three suites do -- cannot desync it, and a block passed
# around by value carries its own answer with it.  {} when the block carries
# no subject, which is the honest answer for every block whose device could
# not be resolved at dump time.
proc rdw::block_subject {block} {
    set e {}
    if {[catch {lindex $block 0} e]} { return {} }
    if {[catch {llength $e} n]} { return {} }
    if {$n < 3} { return {} }
    return [lindex $e 2]
}

# ---------------------------------------------------------------------------
# BRING THE WINDOW TO THE FRONT WHEN SOMETHING IS SENT TO IT (issue 1340).
#
# The user's words: "When user sends info to the Results Display Window (RDW),
# the RDW needs to be raised (no need to focus, just raise), just as the
# Library Manager is raised when one does Ctrl-Alt-S."
#
# ⚠ IT IS THE LIBRARY MANAGER'S OWN RAISE, REUSED AND NOT RE-DERIVED.  A plain
# `raise` is an INERT NO-OP on the window manager the user reported from --
# that WM applies stacking only at map time -- so `raise_toplevel`
# (xschem.tcl) re-MAPs instead, and carries issue 0843's deferred
# `_remap_verify` for the case that WM drops the re-map and loses the window
# outright.  Re-deriving either would re-ship a known defect.  Ruling DD-6
# also says which half of that helper is NOT wanted here: its sibling's last
# line asks the window manager to make this window ACTIVE, and the user said
# no need to focus, so this calls the split-off half.
#
# ⚠ AND THE RE-MAP TAKES THE KEYBOARD IF NOTHING CATCHES IT.  Measured on :99
# under openbox, keyboard parked on the canvas first, nothing else changed:
#     plain raise            no re-map          keyboard stays on .drw
#     withdraw + deiconify   really re-mapped   KEYBOARD MOVES TO .rdw
# and it stays there through every later event pump, because a window manager
# grants focus to a newly MAPPED toplevel.
#     ⚠ THAT MEASUREMENT IS OF A BARE RE-MAP, AND THE DUMP PATH IS NOT ONE
# (issue 1369).  Measured on the same display: the same re-map followed at once
# by the client's own `focus -force` -- which is what rdw::show's
# rdw::_focus_canvas does -- leaves the keyboard where it was and NO FocusIn
# ever arrives at all.  So on :99 the grant this window's hand-back exists for
# never lands, the end-to-end symptom cannot be reproduced here, and a fixture
# that waits for the grant passes while the defect is live.  The user's own
# server is a different one (vendor HC-Consult, no EWMH window manager client
# at all) and there the grant does land, which is the whole of issue 1369.
# The keyboard in this window is the one thing the user
# forbade in the same sentence as the request, and it is worse here than
# elsewhere: the grammar that fills this window -- bare 1/2/3/4 and the
# command mode's Escape -- lives on the design CANVAS, so a stolen focus
# leaves a mode the user cannot leave.
#     rdw::_arm_focus_handback is the one-shot that already catches exactly
# that grant, and it declines to arm for an ALREADY-MAPPED window -- correctly,
# until now: no map was coming, and a flag left lying around is a bounce
# waiting to happen (issue 1306).  A dump now re-maps a mapped window, so a
# map IS coming, and the arm is told so.  That is a second caller of the
# EXISTING hand-back, not a second focus path; rdw::show's synchronous
# `_focus_canvas` is not enough on its own because the grant arrives later.
#
# ⚠ IT CONSTRUCTS NOTHING.  `rdw::open` is this window's one constructor (row
# N1 of the window suite) and the dumps deliberately survive a close, so a
# push into a closed window stays a store push and raises nothing.  Calling
# rdw::open from here is the cheap implementation and would conjure a window
# the user closed on the next dump; rows RA4 and RH1 are the fence.
#
# The raise is caught: by the time it runs the block is already stored and
# already on screen, and a window manager that refuses a re-map is not a
# reason to fail the dump the user asked for.  Rows RA1-RA4 are what say the
# raise really happens, so the catch cannot hide a regression from the suite.
proc rdw::_raise {} {
    if {![rdw::have_tk]} { return 0 }
    if {![winfo exists .rdw]} { return 0 }
    rdw::_arm_focus_handback 1
    catch {raise_toplevel .rdw}
    return 1
}

# Add a block to the store and repaint.  The store is namespace state and
# works headless; the pane is only its projection.
#
# ⚠ IT STAMPS THE SUBJECT (issue 1322), AND ITS SIGNATURE DOES NOT MOVE.
# The capture is here rather than in a new argument for two reasons: every
# fixture in three suites already pushes while the sheet the block came from is
# the sheet that is open, so they all capture the right subject with no edit at
# all; and an optional argument a caller forgets silently restores the defect.
# A block that already carries a subject is stored exactly as it is.
proc rdw::push {block} {
    variable blocks
    if {![rdw::_stamped $block]} {
        set subj [rdw::_capture_subject $block]
        if {$subj ne {}} {
            set e [lindex $block 0]
            set block [lreplace $block 0 0 \
                [list [lindex $e 0] [lindex $e 1] $subj]]
        }
    }
    if {[rdw::_insert_index] eq {1.0}} {
        set blocks [linsert $blocks 0 $block]
    } else {
        lappend blocks $block
    }
    # ⚠ AND IT CLEARS THE CURSOR -- RULING DD-1 (item R1, issue 1337).  This
    # proc PREPENDS, so the line the user clicked now holds a different
    # block's text.  A cursor that stayed at the same line number would point
    # at data the user never chose and the button column would edit it without
    # a word; a cursor that tracked the row to its new number would be a
    # cursor the user did not put there either, one screenful further down.
    # Clearing costs one click after a new dump and is the only reading that
    # cannot act on the wrong device.  Row CU5 (headless) and row CU13 (on
    # screen) are the fence.
    rdw::set_row 0
    rdw::render_pane
    ## ⚠ AND IT RAISES THE WINDOW -- ISSUE 1340, RULING DD-6.  This proc is the
    ## SINGLE DOOR every dump goes through -- keys 1/2/3 and every pick-mode
    ## click reach it through rdw::dump_devpath -- which is why the raise is
    ## here and not in the key handlers: a raise wired into rdw::show alone
    ## would do nothing for a dump that arrived by any other route.  AFTER the
    ## repaint, so what comes to the front is the block that was just sent and
    ## never the previous one.
    rdw::_raise
    return $block
}

# THE STATUS SURFACE, AND WHY IT WRAPS (issue 1362).
#
# ⚠ THE ONE-LINE ENTRY SILENTLY AMPUTATED SENTENCES, AND THE HALF IT TOOK
# WAS THE ANSWER.  `.rdw.s.msg` used to be a one-line `entry` driven by
# -textvariable.  MEASURED at HEAD 2004f5e6 on :99 by three independent
# passes: 887 px wide at the window's own default 893x498, -xscrollcommand
# empty, no scrollbar, `xview` parked at 0.0-0.85, and issue 1356's verdict --
# 147 characters, 1045 px of TkTextFont -- arriving as
#   "Delete: removed id from the summary list for class mos. Selecting lines
#    does not choose them for editing - the buttons act on"
# with " the shaded row alone." off the right-hand edge.  The clause exists
# BECAUSE the user asked what it answers; the reader got a sentence that stops
# mid-clause, which reads as a second bug rather than as an answer.
#
# ⚠ AND IT WAS NEVER ONE STRING.  Two more shipped sentences overflowed the
# same entry (the `$notin` refusal at 1082 px, "no row is marked ..." at
# 893 px), this proc has 34 call sites, and three of them paste an unbounded
# parameter name or filesystem path into the sentence.  Shortening the clause
# would have moved the cliff by one sentence.  So the SURFACE changed: a
# wrapping text widget that takes as many lines as its message needs, borrowed
# from the pane and given back.  Section SL of test_rdw_window_1245.tcl fences
# the general property -- for ANY message, all of it is displayed.
#
# ⚠ AND NOT ONE PIXEL CONSTANT, DELIBERATELY.  The measurement above is a
# font metric as Xvfb resolves TkTextFont; the user's own server ($DISPLAY
# 172.20.160.1:0, vendor HC-Consult) may substitute a different font, so a fix
# that widened the window to the 1051 px this one sentence needs would be
# wrong on their machine by construction, and wrong for the next sentence on
# any machine.  `rdw::_status_show` asks the WIDGET how many display lines it
# needs, in whatever font the server actually resolved.  Look debt
# `rdw_1362_status_wrap` is what remains: their eyes, not a number.
#
# THE THREE ALTERNATIVES, COSTED AND REJECTED, so nobody re-derives them:
#   * shorten the sentence -- cheapest, but the clause answers a question the
#     user asked, and it fixes exactly one of the sentences that overflow;
#   * widen the window's default to 1051 px -- a per-sentence answer to a
#     general problem, and a window manager is free to refuse the size;
#   * move the clause off the status line into the pane or the chrome -- the
#     pane is the artifact the user pastes into a design review (row LX10 is
#     the fence that keeps chrome OUT of it) and the chrome is per-identity,
#     not per-verdict, so neither can carry a verdict about one press.
#
# THE CAP IS A HEIGHT AND NEVER A LENGTH -- ISSUE 1365.
#
# ⚠ THE FIRST ANSWER HERE WAS AN ELISION, AND IT PUT ISSUE 1344's DEFECT BACK.
# Issue 1362 capped the surface at `rdw::status_max_lines` DISPLAY LINES and,
# past the cap, replaced the tail of the sentence with "..." in the widget --
# keeping the whole sentence in `::rdw::statusmsg` and arguing that the painter
# "may shorten what it DRAWS and never what it HOLDS".  The argument was
# false about this window, in three measured ways, and its adversary landed
# all three:
#
#   * THE COPY HANDS OVER WHAT IS DRAWN, NOT WHAT IS HELD.  `rdw::copy`'s
#     second leg is `rdw::_sibling_selection`, which asks the X PRIMARY
#     selection; `::rdw::statusmsg` is never consulted on that path and could
#     not be -- the user selected a RANGE of the widget, and only the widget
#     knows which characters those are.  MEASURED on a 618-character composed
#     verdict at 893x498: before 1362 the clipboard came back 618 characters
#     ending "the shaded row alone."; after it, 474 ending in a literal "...".
#     That is issue 1344's own defect -- this window handing over text the user
#     did not select -- returning through the door 1344 was fixed for, in the
#     window whose stated purpose is select-and-paste.
#   * THE ELISION MADE THE PAINTED STRING DEPEND ON THE WIDTH, so every resize
#     repainted and every repaint destroyed the `sel` tag.  MEASURED: a
#     selection standing in a 618-character verdict died on THREE PIXELS of
#     drag; the pre-1362 entry survived the identical gesture.
#   * AND IT STILL AMPUTATED SHIPPED VERDICTS.  The cliff MEASURED at 492
#     characters at the window's own default width, against composed verdicts
#     of 618-778 -- `rdw::_edit`'s sentence already carries `_sheet_note`,
#     `_drawn_note` and `_shadow_why`, and `rdw::_bstatus` appends
#     `_selection_note` on top.  A path-free composition reaches 449.  So the
#     cliff moved from 122 characters to 492 and the sentence that answers the
#     user's question still did not arrive whole.
#
# ⚠ SO THE CAP IS A HEIGHT NOW AND THE TEXT IS NEVER CUT.  The surface holds
# every character of the model at every length; it takes at most
# `rdw::status_max_lines` lines of the window; and when the sentence needs more
# than that a SCROLLBAR appears beside it.  All three defects close by
# construction rather than by three guards: the clipboard is whole because the
# widget is whole, the no-repaint guard fires because the painted string no
# longer depends on the width, and nothing is amputated at any length.
#
# ⚠ AND A SCROLLBAR IS THE AFFORDANCE "..." ONLY LOOKED LIKE.  Both say "there
# is more"; only one of them can be used to read it, and only one of them
# leaves the text where a selection, a copy and a middle-click paste can reach
# it.  `cadence::_annot_fit` (utils/annot_mode.tcl:724) elides the C status bar
# because that bar is a fixed-size drawing with no widget behind it and nothing
# can be selected in it; this surface is a Tk text the user copies from, and
# ruling DD-5 is what makes that difference load-bearing rather than stylistic.
#
# THE ALTERNATIVES, COSTED AND REJECTED, so nobody re-derives them:
#   * go back to the one-line entry -- it held the sentence whole, which is why
#     the pre-1362 copy was correct, but it showed 122 characters of 618 with
#     no scrollbar and no marker, which is issue 1362 itself;
#   * keep the elision and teach `rdw::copy` to hand over the model -- the user
#     selected a RANGE; there is no honest map from a range of the elided
#     picture back to a range of the sentence, and it fixes neither the resize
#     nor the amputation;
#   * raise the cap until today's longest verdict fits -- a per-sentence answer
#     to a general problem, and the three sentences that interpolate a
#     filesystem path have no longest;
#   * widen the window -- costed and rejected by 1362 for reasons that still
#     hold: a window manager is free to refuse the size.
#
# WHAT IS STILL THE USER'S: the cap itself (rule debt 1362) -- four lines shows
# about 474 characters at 893 px, so a 618-character verdict is four lines read
# and two lines scrolled.  Nothing is lost either way; how much of the window a
# status line may take is theirs to say, and the number is a proc so that
# changing it is a one-line change with a row that notices.
proc rdw::status_max_lines {} { return 4 }

# The clamp, split out so it can be driven with no Tk at all (row SL1).  A
# widget that has never been mapped answers a nonsense display-line count, and
# a status write is the last place in this file that may raise -- every button
# verdict ends in one.
proc rdw::_status_height {want} {
    if {![string is integer -strict $want] || $want < 1} { return 1 }
    set cap [rdw::status_max_lines]
    if {$want > $cap} { return $cap }
    return $want
}

# PAINT THE MODEL ONTO THE SURFACE AND FIT THE SURFACE TO IT.
#
# ⚠ THE STRING PAINTED IS THE MODEL, ALWAYS AND WHATEVER THE WIDTH, and that
# is the whole of issue 1365.  It is what makes `rdw::_status_put`'s guard able
# to fire on a resize, it is what makes the X PRIMARY selection this surface
# publishes a real substring of the sentence, and it is what stops any verdict
# being cut at any width.  The only thing the measurement below decides is how
# many lines of the WINDOW the surface takes.
#
# ⚠ THE WIDGET IS ASKED, NOT A FONT TABLE.  `count -displaylines` is the real
# wrap, at the real width, in the real font -- so no pixel constant appears
# here or in section SL, and the same code is right on a server whose font
# substitution differs from this one's.
#
# ⚠ AND IT REFUSES TO MEASURE AN UNMAPPED WIDGET.  Before the first map
# `winfo width` is 1 and every message needs hundreds of lines.  The
# <Configure> bind in rdw::build re-fits the moment there is a real width, and
# again on every user resize -- which is the case a fit computed once would get
# wrong the first time the window is made narrower.
proc rdw::_status_show {} {
    variable statusmsg
    if {![rdw::have_tk]} { return 0 }
    if {![winfo exists .rdw.s.msg]} { return 0 }
    rdw::_status_put $statusmsg
    if {[winfo width .rdw.s.msg] < 20} {
        if {[.rdw.s.msg cget -height] != 1} { .rdw.s.msg configure -height 1 }
        rdw::_status_scroll_sync 1 1
        return 1
    }
    set n [rdw::_status_lines]
    set h [rdw::_status_height $n]
    if {[.rdw.s.msg cget -height] != $h} { .rdw.s.msg configure -height $h }
    rdw::_status_scroll_sync $n $h
    return $h
}

# ⚠ AND IT DOES NOT REPAINT WHAT IS ALREADY THERE.  A repaint destroys the
# `sel` tag, and the <Configure> refit runs on every user resize -- so without
# this guard, dragging the window's edge while the settings-file path is
# selected in the status line would put that selection down under the user's
# hand, which is issue 1344 defect c reached by a different gesture.  Since
# 1365 the painted string does not depend on the width at all, so on a resize
# this guard always fires; before 1365 it could never fire on a capped message
# and rows SL10 and SL8 disagree about nothing else.
proc rdw::_status_put {txt} {
    set now {}
    if {![catch {.rdw.s.msg get 1.0 {end - 1c}} now] && $now eq $txt} { return {} }
    .rdw.s.msg configure -state normal
    .rdw.s.msg delete 1.0 end
    .rdw.s.msg insert 1.0 $txt
    .rdw.s.msg configure -state disabled
    ## A NEW verdict is read from its beginning.  Only on the path that really
    ## repainted, so a refit never scrolls a sentence the user was reading.
    catch {.rdw.s.msg yview moveto 0}
    return {}
}

proc rdw::_status_lines {} {
    set n 1
    catch {set n [.rdw.s.msg count -displaylines 1.0 end]}
    if {![string is integer -strict $n] || $n < 1} { return 1 }
    return $n
}

# THE SCROLLBAR APPEARS ONLY WHEN THERE IS SOMETHING TO SCROLL TO, and it is
# the ONE thing on this surface that says a tail exists.
#
# ⚠ IT CANNOT OSCILLATE, AND THAT IS BY CONSTRUCTION RATHER THAN BY LUCK.
# Packing it makes the text NARROWER, so the number of display lines the
# sentence needs can only go up -- a packed scrollbar can never make itself
# unnecessary.  Forgetting it makes the text wider, so the count can only go
# down.  Both transitions are therefore one-way and the <Configure> the pack
# fires settles on the second pass.  A `-yscrollcommand` that packed and
# unpacked from inside the scroll callback -- the usual auto-scrollbar idiom --
# has no such argument available to it, which is why the decision is taken here
# and the callback below only moves the thumb.
#
# The DECISION is split out from the PACKING for `rdw::_status_height`'s own
# reason (row SL1): it is the half that can be driven with no Tk at all, and a
# status write is the last place in this file that may raise.
proc rdw::_status_scroll_wanted {need h} {
    if {![string is integer -strict $need]} { return 0 }
    if {![string is integer -strict $h]} { return 0 }
    return [expr {$need > $h ? 1 : 0}]
}

proc rdw::_status_scroll_sync {need h} {
    if {![rdw::have_tk]} { return 0 }
    if {![winfo exists .rdw.s.sb]} { return 0 }
    set want [rdw::_status_scroll_wanted $need $h]
    set now 0
    catch {set now [expr {[winfo manager .rdw.s.sb] eq {pack} ? 1 : 0}]}
    if {$want == $now} { return $want }
    if {$want} {
        catch {pack .rdw.s.sb -side right -fill y -padx {0 3} -pady 3 \
                   -before .rdw.s.msg}
    } else {
        catch {pack forget .rdw.s.sb}
    }
    return $want
}

proc rdw::_status_scrollset {first last} {
    catch {.rdw.s.sb set $first $last}
    return {}
}

# ⚠ THE SURFACE NEVER OWNS ITS OWN MANDATORY TRAILING NEWLINE (issue 1362).
# A Tk text always holds one final "\n" that no editing can remove, and a drag
# that runs past the end of the sentence -- which is what dragging to the
# right-hand edge of a one-line field IS -- lands on index 2.0 and selects it.
# MEASURED by row CP14 the moment the class changed: PRIMARY came back as the
# settings-file path with a newline glued on, so the path the user copied would
# not have pasted as a path, and neither Ctrl-C here nor a middle-click in
# another application would have got it right.  The readonly `entry` this
# replaced could not do that, so it is a defect the widget swap introduced and
# the swap has to answer for.
#
# ⚠ FIXED AT THE SELECTION, NOT AT THE COPY, AND THAT IS THE WHOLE POINT.
# Clamping inside rdw::copy would leave the X PRIMARY selection wrong for every
# other consumer on the display; clamping the `sel` tag means the window never
# publishes a selection it did not mean.  Row CP15 states the same rule for the
# pane in its own words: what reaches the clipboard is the widget's text and
# never the Tk text widget's mandatory trailing newline.
#
# The recursion terminates by construction: removing the tag from that one
# character fires <<Selection>> again, and the second pass finds nothing past
# `end - 1c` to remove.
proc rdw::_status_clamp_sel {} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.s.msg]} { return {} }
    set rng {}
    if {[catch {.rdw.s.msg tag ranges sel} rng]} { return {} }
    if {[llength $rng] < 2} { return {} }
    set over 0
    if {[catch {.rdw.s.msg compare [lindex $rng end] > {end - 1c}} over]} { return {} }
    if {!$over} { return {} }
    catch {.rdw.s.msg tag remove sel {end - 1c} end}
    return {}
}

# THE ONE RE-FIT DOOR.  Bound to the surface's own <Configure> (rdw::build), so
# the first map and every user resize re-ask the same question.  The guard in
# `_status_show` -- only reconfigure when the height really changes -- is what
# stops a Configure that a height change caused from causing another.
proc rdw::_status_refit {} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.s.msg]} { return {} }
    rdw::_status_show
    return {}
}

# The window's own status line.  The variable is always settable, so the inert
# buttons are drivable under --nogui too; `rdw::_status_show` is what puts it
# on screen.  An empty message clears the field.
# ⚠ AND IT ONE-LINES, ITEM B5.  `::rdw::statusmsg` is a STATUS LINE and item
# B5 is the first thing that puts the LIST STORE's own prose in it:
# `op_param_lists::said`'s reports interpolate caught errors (write_conf's
# `$err`), which are multi-line by nature.  A newline would turn a one-line
# verdict into an arbitrary block, and the wrap this surface does is the
# window's decision about width, not the message's.  rdw::_line has carried the
# same rule for every BLOCK line since B3; this was the one emit point outside
# it.  Collapsed at the emit point, not at the ten call sites, for _line's own
# reason: the eleventh call site is the one the next author forgets.
# ⚠ AND A REWRITE PUTS DOWN ANY SELECTION IT INVALIDATES (issue 1351).  When
# the surface was an entry its selection was a pair of INDICES, not a hold on
# the characters, so replacing the -textvariable left the range standing over
# text the user never selected.  MEASURED by issue 1344's adversary, in two
# presses of the chord that item added: the line reads `alpha    beta`, the
# user selects the four spaces (a double-click on the gap does exactly this),
# Ctrl-C is refused -- and the refusal is not routed through rdw::_copy_report,
# so it REPLACES the line.  The range 5-9 survived the rewrite verbatim and now
# covered ` is ` of the refusal sentence, so a second Ctrl-C copied ` is ` onto
# the clipboard SILENTLY, because the source was still that widget.  That is
# item R3's own quoted defect -- "silently handed you the wrong text" --
# reached in two presses.
#
# ⚠ THE TEXT WIDGET DOES NOT MAKE THAT LINE UNNECESSARY, IT MAKES IT CHEAP.
# A `sel` tag IS a hold on the characters and is destroyed by the repaint, so
# the invalidated range cannot survive -- but ONLY because the repaint happens,
# and the repaint happens only when the text really changed.  Row CP16's last
# leg is the other half: a line rewritten to the string it already held has
# invalidated nothing, so a selection standing in it must SURVIVE, which is why
# the guard below is on the change and not on every call.
proc rdw::status {msg} {
    variable statusmsg
    set new [rdw::_oneline $msg]
    set changed [expr {$new ne $statusmsg}]
    set statusmsg $new
    if {$changed && [rdw::have_tk] && [winfo exists .rdw.s.msg]} {
        catch {rdw::_status_show}
    }
    return {}
}

# ===========================================================================
# THE TEXT SIZE -- ISSUE 1368, THE `aA` CONTROL
# ===========================================================================
# THE USER'S OWN WORDS: "add a button to allow user to manipulate font size in
# RDW.  it can be the 'aa' button you see in e-readers - 2nd a bigger.  Key
# part, as soon as user hovers over it, tooltip should be displayed : click to
# increase font one unit.  Ctrl+click to decrease font one unit".
#
# ⚠ THE ONE-LINER IS THE TRAP, AND IT IS MEASURED.  `font configure TkFixedFont
# -size N` looks perfect in this window and is a GLOBAL font control wearing a
# window-local label: on this binary a bare `text` widget's DEFAULT -font IS
# TkFixedFont, so the same click also resizes the attribute editor
# (xschem.tcl:10674 and :10839), the symbol-property editor (:11692), the
# text-input dialog (:13190), editpaths (:9454), the graph dialog (:6365), the
# notify popup (ciw.tcl:155) and the calculator buffer (calculator.tcl:1503) --
# in one click, with nothing on screen saying so, and no suite in the tree
# watching any of those fonts.  This window owns PRIVATE named fonts instead,
# exactly as `ciw_font` / `ciw_set_font_size` (ciw.tcl:391,406) already do for
# the CIW.  Row FZ5 of tests/headless/test_rdw_window_1245.tcl is that fence.
#
# ⚠ THE MODEL IS THE INTEGER, NEVER THE FONT.  MEASURED: `font configure X
# -size -14` -- a PIXEL spelling -- answers `font actual X -size` = 10, in
# POINTS.  An implementation that increments what it reads back therefore turns
# a user's pixel size into points and moves it by an unrelated amount on the
# very first click.  Every step below reads `rdw::font_size` and nothing else.
#
# ⚠ AND `-size 0` IS A LIVE VALUE, NOT A NEUTRAL ONE: measured, it resolves to
# 12 here.  `0` is safe as the "not chosen yet" sentinel in `::rdw_font_size`
# ONLY because `rdw::_accept_size` can never answer it and `rdw::font_step` can
# never reach it.  Do not remove that guard.

# THE BAND, ONCE, SO OVERRULING IT COSTS ONE LINE AND ONE GOLDEN (row FZ1).
# MEASURED on this binary at 1920x1080: size 4 is linespace 8, and 96 columns
# at size 72 want 5760 px -- three screens.  The CIW's own band is 4..72
# (ciw.tcl:406) and a consistency argument for widening exists; this control
# exists for READABILITY, so it ships narrower.  Which band is the USER's to
# say -- rule debt 1368.
proc rdw::font_limits {} { return {6 32} }

# THE ONE ADMISSION TEST.  It REFUSES; it does not clamp.  Silently "fixing" an
# out-of-band value hides which size the caller actually asked for, which is
# `ciw_set_font_size`'s own recorded reason for refusing too.  Answers the
# accepted integer, or the empty string.
#
# ⚠ IT IS DELIBERATELY NOT CALLED `_clamp_size`.  A name that says clamp over a
# proc that refuses is this file's own documented defect -- a comment naming a
# fence that does not fence -- one layer down.
proc rdw::_accept_size {n} {
    if {![string is integer -strict $n]} { return {} }
    lassign [rdw::font_limits] lo hi
    if {$n < $lo || $n > $hi} { return {} }
    return $n
}

# WHAT THE USER HAS CHOSEN, OR THE EMPTY STRING IF THEY HAVE NOT.  Split out
# because the two consumers differ: `rdw::font_size` needs a number to do
# arithmetic with, and `rdw::_font` must leave the private font a BYTE-FOR-BYTE
# copy of TkFixedFont until there is a choice to impose -- including a pixel
# spelling, which the points model cannot represent.
proc rdw::_chosen_size {} {
    if {![info exists ::rdw_font_size]} { return {} }
    return [rdw::_accept_size $::rdw_font_size]
}

# THE SHARED FONT'S OWN SIZE, RAW AND UNCLAMPED, OR THE EMPTY STRING.  Split
# out of `rdw::_base_size` because `rdw::_font` needs to know whether the band
# actually MOVED it: when it did not, the private font keeps TkFixedFont's own
# spelling verbatim (a pixel size included); when it did, the private font has
# to say the number the MODEL says, or the pane renders a size no accessor
# reports.  With no Tk there is no `font` command AT ALL (measured: `--nogui`
# dies with `invalid command name "font"` at line 1).
proc rdw::_shared_size {} {
    if {![llength [info commands font]]} { return {} }
    set n {}
    if {[catch {font actual TkFixedFont -size} n]} { return {} }
    if {![string is integer -strict $n]} { return {} }
    return $n
}

# WHAT THE WINDOW IS AT WHEN THE USER HAS NOT CHOSEN: the SHARED font's own
# size, so an ~/.xschem/xschemrc that re-sizes or re-families TkFixedFont before
# this window is built is honoured.  CLAMPED into the band rather than refused
# -- this is a value the user did not choose, so there is nobody to tell.
#
# ⚠ AND THE CLAMP OBLIGES `rdw::_font` TO IMPOSE IT.  MEASURED with
# `font configure TkFixedFont -size 40` and no choice made: this proc answered
# 32, `rdw::font_size` answered 32, the pane rendered 40, the plain click
# refused with "already the largest (32)" while the text stood at 40 and the
# Ctrl arm stepped 40 -> 31 in one click.  A number the model reports and the
# screen contradicts is worse than either bound.  Row FZ15 fences it
# behaviourally and row FZ13 structurally, on the arm that has no font at all.
proc rdw::_base_size {} {
    lassign [rdw::font_limits] lo hi
    set n [rdw::_shared_size]
    if {$n eq {}} { set n 10 }
    if {$n < $lo} { return $lo }
    if {$n > $hi} { return $hi }
    return $n
}

# THE EFFECTIVE SIZE, AS AN INTEGER.  `::rdw_font_size` is `set_ne`'d to 0 in
# xschem.tcl beside `ciw_font_size`; 0 -- or anything out of band -- means
# "follow TkFixedFont", which is what lets an xschemrc or a --script rc pick the
# starting size without knowing this proc exists.
proc rdw::font_size {} {
    set n [rdw::_chosen_size]
    if {$n ne {}} { return $n }
    return [rdw::_base_size]
}

# THE ONE SETTER.  Order-independent exactly as `ciw_set_font_size` is: an rc
# may call it BEFORE or AFTER the window is built, because it records the model
# and `rdw::_apply_font` is a no-op without a window.  1 accepted, 0 refused.
proc rdw::set_font_size {n} {
    set ok [rdw::_accept_size $n]
    if {$ok eq {}} { return 0 }
    set ::rdw_font_size $ok
    rdw::_apply_font
    return 1
}

# THE ONE ARITHMETIC DOOR: the button's plain click is +1, its Ctrl+click -1.
#
# ⚠ IT WRITES NOTHING ON THE ACCEPTED PATH.  The pane visibly changing IS the
# confirmation, and a status write per click would evict the button column's
# real verdicts -- the calculator's own rule (calculator.tcl:1985), and this
# window's status line is the one surface issue 1362 exists about.
#
# ⚠ AND IT MUST SPEAK AT THE LIMITS.  A visible, enabled control that does
# nothing and says nothing is indistinguishable from a broken one, which is
# `rdw::inert`'s standing obligation ("THE BUTTON COLUMN", foot of this file).
# The cost is real and is recorded in the issue file: a refusal overwrites
# whatever verdict the button column had just written.  It happens only at the
# two ends.
proc rdw::font_step {dir} {
    if {$dir ne {1} && $dir ne {-1}} { return 0 }
    if {[rdw::set_font_size [expr {[rdw::font_size] + $dir}]]} { return 1 }
    lassign [rdw::font_limits] lo hi
    if {$dir < 0} {
        rdw::status "Text size: already the smallest ($lo)."
    } else {
        rdw::status "Text size: already the largest ($hi)."
    }
    return 0
}

# THE TOOLTIP'S STRING, ONCE.  The user's own words, verbatim.
proc rdw::_font_tip {} {
    return {click to increase font one unit. Ctrl+click to decrease font one unit}
}

# ---------------------------------------------------------------------------
# THE Tk LAYER.  Every command below sits behind rdw::have_tk.

# Colours, resolved on EVERY call and never cached (the calculator's own rule,
# calculator.tcl:368-405): a cached palette can be wrong for the whole life of
# the process with no way to re-resolve.  The one source that is not
# ase::palette is `disabledForeground`, the tree-wide convention for greyed
# text, which is what the dimmer second header line uses.
#
# ⚠ ase::palette, never the other one: the sibling proc creates named fonts
# and does a global `option add`, a one-way side effect a suite exists to
# police.  A role that does not resolve falls back rather than raising -- a
# missing option-database entry must not be able to kill the window.
proc rdw::color_sources {} {
    return {
        panel      {ase::palette panel}
        field      {ase::palette table}
        fieldfg    {ase::palette fieldfg}
        selectbg   {ase::palette selectbg}
        selectfg   {ase::palette selectfg}
        accent     {ase::palette accent}
        disabledfg {option get . disabledForeground DisabledForeground}
        notefg     {rdw::_notefg}
        cursor     {rdw::_cursor_shade}
    }
}

# The CIW's own convention for "a result the user must NOTICE without it being
# an error" (ciw.tcl:453).  The incompleteness sentence and the five silences
# are exactly that: not errors, and not to be skimmed past.
#
# ⚠ IT WAS `dark orange` AND IT WAS UNREADABLE, in BOTH windows.  A user reading
# a real CIW notice reported it ("practically unreadable"), and this pane is the
# worse of the two because it is WHITE, not grey80.  MEASURED 2026-09-08 against
# `rdw::color field` as the running window reports it:
#
#     dark orange on #ffffff   contrast  2.33
#     dark red    on #ffffff   contrast 10.01     (fieldfg, black, is 21.00)
#
# THIS MOVED BECAUSE THE CIW's DID.  The header above is not decoration: this
# colour is defined as the CIW's convention, so leaving it behind would make
# that sentence false and put one decision in two places disagreeing -- which is
# invariant I1, one window out.  The pair is `ciw.tcl`'s `note` tag, whose own
# comment carries the full contrast table and the reason a single red cannot
# serve both colour schemes.
proc rdw::_notefg {} { return {dark red} }

# ---------------------------------------------------------------------------
# ITEM R1, ISSUE 1337 -- THE LINE CURSOR'S SHADE, DERIVED FROM THE PANE.
# The user's words: "clicking on any line makes the entire line a shade darker
# (noticeably)."  Ruling DD-2: the shade is DERIVED, never written down.  A
# literal grey is the obvious thing and it is wrong in one of the two themes --
# #d0d0d0 on a near-black pane is not a shade, it is a stripe.
#
# ⚠ `ase::palette table` DIRECTLY, AND NOT `rdw::color field`.  rdw::palette
# iterates every role in rdw::color_sources and CALLS each source, so a source
# that asked rdw::color for another role would re-enter rdw::palette and
# recurse until the interpreter gave out.  The one thing this proc may read is
# the theme itself; the fallback pane is `rdw::_color_fallback field`'s job,
# below, and it derives from that field the same way.

# A colour to {r g b}, each 0-255, or {} when it cannot be read.  Hex of 1, 2,
# 3 or 4 digits per channel is parsed HERE, in pure Tcl, because half this
# window's suite runs on the --nogui arm where there is no `winfo` at all; a
# colour NAME is resolved through Tk when there is a Tk, and answers {} when
# there is not -- which makes the shade fall back rather than raise.
proc rdw::_rgb255 {c} {
    if {[regexp {^#([0-9a-fA-F]+)$} $c -> h]} {
        set n [string length $h]
        if {$n % 3 != 0} { return {} }
        set w [expr {$n / 3}]
        if {$w < 1 || $w > 4} { return {} }
        set max [expr {(1 << (4 * $w)) - 1}]
        set out {}
        for {set i 0} {$i < 3} {incr i} {
            set part [string range $h [expr {$i * $w}] [expr {$i * $w + $w - 1}]]
            set v 0
            if {[scan $part %x v] != 1} { return {} }
            lappend out [expr {int(double($v) * 255.0 / $max + 0.5)}]
        }
        return $out
    }
    if {[llength [info commands winfo]]} {
        set r {}
        if {![catch {winfo rgb . $c} r] && [llength $r] == 3} {
            set out {}
            foreach v $r { lappend out [expr {int($v / 257.0 + 0.5)}] }
            return $out
        }
    }
    return {}
}

# One step AWAY from `c`, as `#rrggbb`, or {} when `c` cannot be read.
#
# ⚠ AN ABSOLUTE STEP, NOT A MULTIPLY, AND THE DIRECTION FLIPS ON A DARK
# BACKGROUND.  The obvious derivation is `background * 0.88`, and it is
# invisible in exactly the theme this proc exists for: 0.88 of #202020 is
# #1c1c1c, four parts in 255 -- a difference no eye finds and no screenshot
# shows.  A fixed ±40 of 255 is a step the user can see on either ground
# (#ffffff -> #d7d7d7, #202020 -> #484848), and on an already dark pane the
# only direction with room left is LIGHTER.  "Noticeably" is the user's own
# word, so the window suite's section CU gives it a number -- 20 of 255 -- and
# fences both halves: a literal fails because it does not move with the theme,
# a multiply fails because it does not move far enough.
#
# The 0.30/0.59/0.11 weights are the standard luminance mix; the threshold is
# the midpoint of the range they produce, so `dark` means "darker than a mid
# grey" and nothing subtler.
proc rdw::_shade_step {c} {
    set rgb [rdw::_rgb255 $c]
    if {[llength $rgb] != 3} { return {} }
    set r [lindex $rgb 0]
    set g [lindex $rgb 1]
    set b [lindex $rgb 2]
    set lum [expr {0.30 * $r + 0.59 * $g + 0.11 * $b}]
    set d [expr {$lum > 96 ? -40 : 40}]
    set out {}
    foreach v [list $r $g $b] {
        set n [expr {$v + $d}]
        if {$n < 0} { set n 0 }
        if {$n > 255} { set n 255 }
        lappend out $n
    }
    return [format {#%02x%02x%02x} [lindex $out 0] [lindex $out 1] [lindex $out 2]]
}

proc rdw::_cursor_shade {} {
    set bg {}
    catch {set bg [ase::palette table]}
    if {$bg eq {}} { return {} }
    return [rdw::_shade_step $bg]
}

proc rdw::_color_fallback {role} {
    switch -exact -- $role {
        panel      { return #f2f2f2 }
        field      { return #ffffff }
        fieldfg    { return #000000 }
        selectbg   { return #4a6984 }
        selectfg   { return #ffffff }
        accent     { return #8b0000 }
        disabledfg { return grey50 }
        notefg     { return {dark red} }
        cursor     { return [rdw::_shade_step [rdw::_color_fallback field]] }
    }
    return black
}

proc rdw::palette {} {
    set out {}
    foreach {role src} [rdw::color_sources] {
        set v {}
        catch {set v [uplevel #0 $src]}
        if {$v eq {}} { set v [rdw::_color_fallback $role] }
        lappend out $role $v
    }
    return $out
}

proc rdw::color {role} {
    set pal [rdw::palette]
    if {[dict exists $pal $role]} { return [dict get $pal $role] }
    return [rdw::_color_fallback $role]
}

# ---------------------------------------------------------------------------
# THE TEXT SIZE, Tk HALF -- ISSUE 1368.  Nothing below may be reached without a
# display: `--nogui` has no `font` command AT ALL, measured, which is the same
# trap the head of this file records for every other Tk command.

# THE TWO PRIVATE NAMED FONTS, CREATED ON FIRST USE AND NEVER TkFixedFont.
#
# ⚠ DERIVED FROM `font configure TkFixedFont`, NOT FROM `font actual`.
# `configure` answers the spelling AS CONFIGURED, so a TkFixedFont spelled in
# PIXELS (a negative -size) is copied verbatim; `font actual` would have
# converted it to points behind the user's back (measured: -14 -> 10).  With no
# choice recorded the size is RE-COPIED from that spelling on every call, so an
# untouched window is byte-for-byte the window that shipped.
#
# ⚠ AND THE SIZE IS SET ON EVERY CALL, NOT ONLY WHILE A CHOICE STANDS.  These
# fonts outlive the widget and the window; a version that imposed a size only
# while `rdw::_chosen_size` answered something could never PUT ONE BACK.
# MEASURED with that version: `rdw::set_font_size 20` then withdrawing the
# choice (`set ::rdw_font_size 0`) left the model answering 10 while the pane
# still rendered 20, and the next PLAIN click -- the `+` arm -- shrank the text
# from 20 to 11.  The same hole ran the other way through the clamp in
# `rdw::_base_size`.  So: a choice wins; with none, the band's own answer wins
# when the band moved the shared size, and TkFixedFont's verbatim spelling wins
# when it did not.  Rows FZ15 (behaviour) and FZ13 (structure).
#
# ⚠ MONOSPACE, BECAUSE THE DUMPS ARE COLUMN-ALIGNED WITH SPACES.  Inheriting
# TkFixedFont's FAMILY is what keeps `    %-*s : %s` lined up and what honours
# an rc that re-families it before this window opens.  A proportional font
# would destroy every block in the pane.  Row FZ16 asserts it directly --
# `font metrics -fixed` and four glyphs advancing the same width -- because a
# substituted family whose `0` advance happened to match would otherwise be
# caught by nothing but FZ4's character count, and only by luck.
#
# ⚠ `font create` RAISES ON A NAME THAT ALREADY EXISTS, so the lsearch guard is
# load-bearing rather than tidy (`ciw_font`, ciw.tcl:391, is the shape).  The
# fallback answers TkFixedFont -- a window in the stock size beats no window --
# and on that path it configures NOTHING, which is what keeps the shared font
# out of reach even when everything else has gone wrong.
proc rdw::_font {which} {
    set name [expr {$which eq {hdr} ? {RdwHdrFont} : {RdwPaneFont}}]
    if {![llength [info commands font]]} { return TkFixedFont }
    ## A READ of the shared font, never a write -- and spelled without a
    ## trailing option so row FZ4's write-needle stays exact.
    set spec {}
    if {[catch {font configure TkFixedFont} spec]} { set spec {} }
    if {[lsearch -exact [font names] $name] < 0} {
        if {[catch {font create $name {*}$spec}]} { return TkFixedFont }
        if {$which eq {hdr}} { catch {font configure $name -weight bold} }
    }
    set want [rdw::_chosen_size]
    if {$want eq {}} {
        set raw [rdw::_shared_size]
        set eff [rdw::_base_size]
        if {$raw ne {} && $raw == $eff && [dict exists $spec -size]} {
            set want [dict get $spec -size]
        } else {
            set want $eff
        }
    }
    catch {font configure $name -size $want}
    return $name
}

# THE METRIC REFERENCE THE PANE'S CHARACTER SHAPE IS SCALED AGAINST: the
# SHARED font as it stands, EXCEPT when `rdw::font_limits` has refused its size
# -- in which case it is the shared font at the band's own answer, because that
# is the size this window actually renders.  Answered as a font DESCRIPTION
# (an option/value list), never as a third named font: `font measure` and
# `font metrics` both take one, and a third entry in `font names` would be a
# second thing to keep in step.
#
# ⚠ THE `!=` ARM IS THE ONLY ONE THAT SUBSTITUTES, AND THAT IS DELIBERATE.
# TkFixedFont may be spelled in PIXELS; `rdw::_base_size` is in POINTS, so
# rewriting the size unconditionally would silently re-metric a pixel-spelled
# font the band never objected to.  Same rule, and the same two accessors, as
# `rdw::_font` uses one layer up.
proc rdw::_ref_font {} {
    set spec {}
    if {[catch {font configure TkFixedFont} spec]} { return TkFixedFont }
    if {![dict exists $spec -size]} { return TkFixedFont }
    set raw [rdw::_shared_size]
    set eff [rdw::_base_size]
    if {$raw eq {} || $raw == $eff} { return TkFixedFont }
    dict set spec -size $eff
    return $spec
}

# THE GEOMETRY DEFENCE, AND IT IS NOT A REFINEMENT.
#
# The pane is sized in CHARACTER units, so a bigger font re-requests the
# toplevel's size.  MEASURED, unmitigated: one step to size 20 took this window
# from 893x498+1025+557 to 1757x914+161+141 -- nearly the whole 1920x1080
# screen, and the window manager re-placed it across the desktop.  That is the
# failure a user reports as "the button broke my window", and on a size the
# window is BUILT at it happens at open time with no click at all.
#
# Scaling the 96x26 design shape by the ratio of the SHARED font's metrics to
# the private font's holds the toplevel inside a couple of lines of 893x498
# across the whole band -- measured 885..895 x 485..504 over sizes 6..24, with
# the position unmoved, returning to EXACTLY 96x26 / 893x498 at the base size.
#
# ⚠ RECOMPUTED FROM THE CONSTANTS EVERY TIME, never stepped from the last
# answer, so a hundred clicks accumulate no drift.
#
# ⚠ AND NO PIXEL CONSTANT APPEARS HERE.  Both metrics are ASKED of the real
# fonts, exactly as `rdw::_status_show` asks the real widget (issue 1362): the
# user's own X server is a different one from the dev display and is free to
# substitute a family with different metrics.
#
# ⚠ THE REFERENCE IS THE BAND'S OWN ANSWER, NOT THE RAW SHARED FONT -- see
# rdw::_ref_font.  Anchoring on a TkFixedFont the band had already refused
# would have made the clamp buy nothing: MEASURED at
# `font configure TkFixedFont -size 40`, a reference of 96 raw cells asked for
# a 3284x1752 toplevel on a 1920x1080 screen while the pane itself rendered the
# clamped 32.  Row FZ15.
proc rdw::_pane_chars {} {
    set W 96 ; set H 26
    if {![llength [info commands font]]} { return [list $W $H] }
    set f [rdw::_font pane]
    set r [rdw::_ref_font]
    set bw 0 ; set bh 0 ; set cw 0 ; set ch 0
    catch {set bw [font measure $r 0]}
    catch {set bh [font metrics $r -linespace]}
    catch {set cw [font measure $f 0]}
    catch {set ch [font metrics $f -linespace]}
    if {[string is integer -strict $bw] && [string is integer -strict $cw] \
        && $bw > 0 && $cw > 0} { set W [expr {round(96.0 * $bw / $cw)}] }
    if {[string is integer -strict $bh] && [string is integer -strict $ch] \
        && $bh > 0 && $ch > 0} { set H [expr {round(26.0 * $bh / $ch)}] }
    if {$W < 20} { set W 20 }
    if {$H < 4}  { set H 4 }
    return [list $W $H]
}

# THE ONE PAINTER: both fonts, the pane's character shape, and the status
# line's re-fit.  `rdw::build` calls it on its way out and `rdw::set_font_size`
# calls it on every accepted step, so a window BUILT at a size chosen in an
# earlier open opens at the right PIXEL size instead of at 1757x914.
#
# ⚠ THE `hdr` TAG IS SET HERE AND NOWHERE ELSE, AND THAT IS THE LOAD-BEARING
# HALF.  It used to be `set hf [font actual TkFixedFont] ; dict set hf -weight
# bold`, which captures a font DESCRIPTION, not a NAME -- a FROZEN SNAPSHOT.
# MEASURED: after a size change the pane reported linespace 27 while the `hdr`
# tag was still at linespace 17, so every block's own header line stayed small
# while its body grew.  A named font is the only spelling that follows.  Row
# FZ6 asserts both halves move together.
#
# ⚠ AND IT IS THE ONE PLACE THE PANE'S -width/-height ARE SET.  A copy of them
# on the widget line in `build` would be a second setter for the same fact --
# this file's own two-builders drift -- and would leave `_apply_font` unfenced.
proc rdw::_apply_font {} {
    if {![rdw::have_tk]} { return 0 }
    if {![winfo exists .rdw.p.t]} { return 0 }
    set pf [rdw::_font pane]
    set hf [rdw::_font hdr]
    lassign [rdw::_pane_chars] W H
    catch {.rdw.p.t configure -font $pf -width $W -height $H}
    catch {.rdw.p.t tag configure hdr -font $hf}
    rdw::_status_show
    return 1
}

# Raise-or-open, the calculator's singleton shape (calculator.tcl:412) plus the
# live-Tk guard calc::open does not need and this one does: item B4 reaches
# rdw::open from a key binding, and this window's own suite calls it under
# --nogui.
#
# ⚠ IT TAKES THE KEYBOARD NOWHERE, AND THAT IS THE FIX FOR A MEASURED
# DEFECT.  This window is a read-only record; the grammar that fills it -- bare
# 1/2/3/4 and the command mode's Escape -- lives on the design CANVAS, so a
# raise that moved keyboard focus here left a mode the user could not leave.
# Raising is not focusing, and the window manager's own map-time grant is
# caught by rdw::_focus_handback (see rdw::_arm_focus_handback below).
proc rdw::open {} {
    if {![rdw::have_tk]} { return {} }
    if {[winfo exists .rdw]} {
        wm deiconify .rdw
        raise .rdw
        return .rdw
    }
    return [rdw::build]
}

# THE ONE TEARDOWN, AND SINCE ISSUE 1382 IT HAS TWO DOORS: the window
# manager's X (`wm protocol WM_DELETE_WINDOW`, set in `rdw::build`) and the
# column's own Close button, whose -command is this proc's bare name.  Escape
# is NOT one of them -- ruling DD-12 has it end a running pick and do nothing
# otherwise, argued at that binding in `rdw::build`.
#
# ⚠ THE DUMPS SURVIVE A CLOSE.  ::rdw::blocks is namespace state, not window
# state, and this proc touches it not at all.  The calculator clears its
# message history on close because those are transient notices; these blocks
# ARE the artifact the feature exists to produce -- the user's words: paste
# them into design-review documents -- and losing an hour of them to a stray
# click on the window's X is the worse failure.  Every block is self-labelling
# (its own header, its own incompleteness line), so a stale one cannot be
# mistaken for a fresh one.  Rule debt 1245_B3_dumps_survive_close.
proc rdw::close {} {
    if {![rdw::have_tk]} { return {} }
    # Item R3: the remembered selection is a pair of indices into a buffer that
    # is about to stop existing.  Forgetting it here rather than on the next
    # open keeps `rdw::copy` from ever answering with the previous window's
    # text -- the pane is rebuilt by rdw::render_pane, but ::rdw::selspan is
    # namespace state and would otherwise outlive the widget.
    rdw::_forget_selection
    catch {destroy .rdw}
    return {}
}

# ---------------------------------------------------------------------------
# THE TOPLEVEL'S MINIMUM SIZE, DERIVED FROM THE COLUMN -- ISSUE 1382.
#
# ⚠ A HAND-PINNED MINIMUM CANNOT FOLLOW A COLUMN THAT GROWS, AND THIS ONE
# STOPPED FOLLOWING TWICE.  `wm minsize .rdw 520 260` was written for item B3's
# five-button column and never re-judged.  MEASURED on this Tk (:99, 1920x1080,
# openbox), the column's `winfo reqheight .rdw.b` against the 208 px the 260 px
# minimum leaves it once the header (21 + 4 pad) and the status strip (27) are
# taken off:
#     five buttons                 165   fits, 43 px of slack
#     + `aA`      (issue 1368)     204   fits, 4 px of slack -- unnoticed
#     + `Close`   (issue 1382)     243   35 px SHORT
# At 243 the packer starves the widget it allocated LAST, which `-side bottom`
# makes `aA`: measured at exactly 520x260, `winfo ismapped .rdw.b.fontsize` is
# 0 -- the text-size control the user asked for by name is GONE -- and for the
# ~30 px above that it is a 2-to-24 px sliver.  An ordinary drag of the bottom
# edge reaches it, so this was a live regression on signed-off work and the
# default 893x498 geometry every earlier measurement was taken at could not
# see it.
#
# So the pair below is a FLOOR and `rdw::apply_minsize` raises it to what the
# column really asks for -- the shape `calc::min_floor` / `calc::apply_minsize`
# already uses in this tree, for the same defect (a 614 px selector grid
# overflowing a minimum written against empty panes).  The next control added
# to this column carries the minimum with it instead of evicting a neighbour.
#
# ⚠ THE HEIGHT ARITHMETIC IS THE TOPLEVEL'S OWN REQUEST WITH THE PANE SWAPPED
# FOR THE COLUMN, AND NOT A SECOND MODEL OF THE PACKER.  `.rdw.b` and `.rdw.p`
# share one row, so `reqheight .rdw` already carries the header, the status
# strip and every pad exactly once, plus the TALLER of the two -- which is
# always the pane (446 against 243).  Subtracting the pane and adding the
# column therefore answers "the same chrome, sized to the column": MEASURED
# 498 - 446 + 243 = 295, and 295 is to the pixel the first height at which
# `winfo height .rdw.b` reaches its own request and `aA` is whole again
# (294 -> 28 px and clipped).  Row CB7 golds the one setter and the two call
# sites; row CB9 drives the real window down to whatever they produced and
# reads every widget in the column back -- including the leg that reds a
# derivation which is wrong by being too BIG, which CB7 cannot see.
proc rdw::min_floor {} { return {520 260} }

# ⚠ IT PUMPS THE IDLE QUEUE, WHICH IS WHY IT IS CALLED TWICE AND NOT ONCE.
# `winfo reqheight` on a frame is set by the packer in an idle handler --
# MEASURED: immediately after packing seven buttons the frame still answers 1,
# and 243 only after `update idletasks`.  So the call at the head of
# `rdw::build` sets the FLOOR while `.rdw.b` does not yet exist (no pump, and
# nothing to measure), and the call at the FOOT -- after `rdw::_apply_font`,
# which is the one setter of the pane's character shape -- is the one that
# measures.  Pumping before `_apply_font` would map the pane at TkFixedFont
# size 10 first, which is the trap that proc's own comment records.
proc rdw::apply_minsize {} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw]} { return {} }
    foreach {w h} [rdw::min_floor] break
    if {[winfo exists .rdw.b] && [winfo exists .rdw.p]} {
        update idletasks
        set need {}
        catch {set need [expr {[winfo reqheight .rdw] - [winfo reqheight .rdw.p]
                               + [winfo reqheight .rdw.b]}]}
        if {[string is integer -strict $need] && $need > $h} { set h $need }
    }
    wm minsize .rdw $w $h
    return [list $w $h]
}

proc rdw::build {} {
    toplevel .rdw
    ## ⚠ THE TITLE AND THE CHROME ARE NOT SET HERE.  `rdw::apply_list_state` --
    ## the ONE refresher `rdw::set_list` calls (invariant I1) -- is the last
    ## thing this proc does, and it sets both from `listkind`.  An earlier
    ## revision ALSO set them here and left a comment claiming row LX7/LX8's
    ## close-and-reopen leg as the fence for that read; it is not, and an
    ## adversary proved it by gutting both lines and watching every suite stay
    ## green -- because the leg was really fencing `apply_list_state`.  Two
    ## setters for one fact is this file's own two-builders drift, and a
    ## comment naming a fence that does not fence is row LX4's defect one layer
    ## down.  Row LX16 asserts there is exactly one setter and that build does
    ## not read `listkind` at all.
    wm protocol .rdw WM_DELETE_WINDOW rdw::close
    ## The FLOOR now; raised to what the button column really requests
    ## once that column exists, at the foot of this proc (issue 1382).
    rdw::apply_minsize
    ## The window manager grants keyboard focus to a newly mapped toplevel
    ## asynchronously, after every synchronous hand-back has already run.
    ## rdw::_focus_handback catches that one grant and gives the keyboard back
    ## to the canvas; it is inert unless a dump path armed it.
    bind .rdw <FocusIn> {rdw::_focus_handback %W}
    ## ⚠ AND THE PRESS THAT SAYS THE USER CAME HERE ON PURPOSE -- ISSUE 1369.
    ## The hand-back's landing test asks whether the keyboard is IN this
    ## window, which a grant re-routed to `.rdw.p.t` and a click on
    ## `.rdw.p.t` both satisfy; this is the discriminator that tells them
    ## apart.  It fires for every descendant (the toplevel's name is in every
    ## child's bindtags, the same mechanism the FocusIn comment describes) and
    ## it neither breaks nor moves the focus -- see rdw::_focus_click.
    bind .rdw <ButtonPress> {rdw::_focus_click %W}
    ## ⚠ ESCAPE HAS TO LIVE HERE TOO -- ISSUE 1308, RULING DD-12.
    ## The command mode's `1`/`2`/`3`/`4` and `<Key-Escape>` are bound on the
    ## CANVAS. Issue 1306's fix let this window keep the keyboard when the user
    ## clicks the text pane -- which is the whole point of the feature, since
    ## the dumps exist to be selected and pasted into a design-review document
    ## -- and the consequence measured immediately after was that the mode's
    ## documented exit became unreachable: the canvas no longer had the
    ## keyboard, and nothing on `.rdw` ended the mode.
    ##
    ## ⚠ IT ENDS THE MODE AND DOES NOT CLOSE THE WINDOW, and that asymmetry is
    ## deliberate. Escape closes a dialog in many applications, but this is not
    ## a dialog: it holds an hour of dumps that are the artifact the feature
    ## exists to produce, and rdw::close's own comment records that losing them
    ## to a stray click is the worse failure. A stray Escape is the same
    ## accident with a different finger. So Escape ends a mode when one is
    ## running and does NOTHING otherwise -- never a destructive default.
    ##
    ## The binding is on the toplevel, so it fires wherever focus sits inside
    ## the window, including the text pane, which is the case that matters.
    bind .rdw <Key-Escape> {
        if {[::rdw::pick_running]} { ::rdw::pick_end ; break }
    }
    ## ⚠ AND THE DIGITS HAVE TO LIVE HERE FOR THE SAME REASON -- ISSUE 1358.
    ## The Escape comment three lines up names "the command mode's `1`/`2`/`3`/
    ## `4` and `<Key-Escape>`" in one breath and then takes only the Escape.
    ## The digits are the half that was left behind, and the user found it:
    ## "The delete did not have an effect ... I tried deleting one at a time.
    ## That also did not have an effect next time I printed summary."
    ##
    ## ⚠ MEASURED, and the edit was never the problem.  Press 2 on the canvas,
    ## click a parameter row -- which the status line INSTRUCTS the user to do,
    ## because the buttons act on the shaded row -- press Delete, accept the
    ## defaults: `op_param_lists::effective` really moves and the status line
    ## really says so.  Then press 2 to look, and NOTHING happens.  The click
    ## parked the keyboard on `.rdw.p.t`; the digits are bound on the CANVAS
    ## only (src/cadence_style_rc:181-184); `.rdw`, `.rdw.p`, `.rdw.p.t` and the
    ## Text class carried no `<Key-2>` at all, so Tk delivered the key to the
    ## focus widget, found nothing, and the user got no block, no error and no
    ## status line.  The store had changed and the window could not be made to
    ## show it.
    ##
    ## ⚠ AND THE OBVIOUS RECOVERY IS A TRAP, WHICH IS WHY THE OTHER FIX WAS
    ## NOT TAKEN.  Clicking blank canvas to get the keyboard back DESELECTS the
    ## device, so the next 2 arms the pick mode instead of dumping and the
    ## status line still carries the OLD verdict -- no new feedback either.  The
    ## rejected alternative was to hand the keyboard back to the canvas from
    ## `rdw::button`'s arms: it fixes only the gesture that goes through a
    ## BUTTON (a click on a row followed by a bare 2 is still swallowed), and it
    ## re-creates ruling DD-5's own defect -- on the seven refusal arms nothing
    ## repaints, the pane's selection survives, and a Ctrl-C after a refused
    ## press would then reach `.drw` and copy SCHEMATIC OBJECTS instead of the
    ## block the user selected.  This window exists to have its text pasted into
    ## a design review; a fix that moves the keyboard cannot be the one.
    ##
    ## ⚠ THE MASK IS THE PROFILE'S, NOT A NEW ONE.  0x4c is
    ## Control|Mod1(Alt)|Mod4(Super) with Lock and NumLock deliberately outside
    ## it, exactly as cadence_style_rc:181-184 discriminates, so a Ctrl-2 typed
    ## in this window is as much not-a-dump as a Ctrl-2 typed on the canvas, and
    ## a plain digit with a lock light on is still a plain digit.  This window
    ## has nothing to forward a chord TO, so it simply declines and lets the
    ## event fall through.
    ##
    ## THE MAP IS DUPLICATED ON PURPOSE AND THE DUPLICATE IS FENCED.  The
    ## profile's binding is about the CANVAS -- it must discriminate modifiers
    ## the canvas already spends and `break` to beat the C dispatcher -- and
    ## this one is about this window, which owes neither.  What COULD drift is
    ## which digit means which list, so `rdw::_digit_map` is the one place this
    ## file says it and row KB1 of test_rdw_window_1245.tcl parses both files
    ## and compares them.  A digit that stops meaning the same list in the two
    ## places is a red, not a window that answers a key with the wrong list.
    foreach {_rdw_d _rdw_k} [rdw::_digit_map] {
        bind .rdw <Key-$_rdw_d> "if {\[rdw::_digit $_rdw_k %s]} break"
    }
    unset -nocomplain _rdw_d _rdw_k
    ## ⚠ THE COPY CHORD LIVES ON THE TOPLEVEL TAG TOO, AND FOR THE SAME REASON
    ## AS ESCAPE -- ITEM R3, ISSUE 1339, RULING DD-5.
    ## Tk sends a key event to the FOCUS window, and the only copy this window
    ## had was `bind Text <<Copy>>`, which therefore existed only while
    ## .rdw.p.t itself held the keyboard.  MEASURED on this binary: with the
    ## keyboard on this window's own `Up` button a real Ctrl-C copies nothing
    ## at all -- the CLIPBOARD does not even come into existence -- and the
    ## same with it on .rdw.  Both are one click away, and worse:
    ## rdw::_arm_focus_handback deliberately hands the keyboard to the CANVAS
    ## after every dump, so "press a button, then copy" is the ORDINARY path
    ## and "select, then copy" is the rare one.  That is the user's first
    ## sentence, and no amount of re-binding the pane would have reached it.
    ##
    ## The toplevel tag is in the bindtag chain of every widget in this window
    ## (measured: .rdw.p.t -> `.rdw.p.t Text .rdw all`, .rdw.b.up ->
    ## `.rdw.b.up Button .rdw all`, .rdw itself -> `.rdw Toplevel all`), so one
    ## binding covers the pane, EVERY control in the column -- the five list
    ## actions, `aA` (issue 1368) and Close (issue 1382) -- the status surface
    ## and the toplevel.  (It said "all five buttons, the status entry" until
    ## issue 1382: the column grew twice and `.rdw.s.msg` stopped being an
    ## `entry` at item 1355.  An enumeration that names widgets has to be
    ## re-read every time one is added, which is the price of naming them; the
    ## REACH does not change, because the tag is in every child's chain.)
    ##
    ## ⚠ AND NOT `bind all`, WHICH IS THE CHEAP WAY TO GET THE SAME REACH.
    ## `all` reaches .drw, where Ctrl-C is the schematic's own copy-selected-
    ## objects; row CP11 of the keys suite is that fence, the same shape as the
    ## bare-digit fences B3/B4/B5 already in that file.
    ##
    ## THREE SEQUENCES, PER DD-5, AND THE VIRTUAL ONE IS NOT REDUNDANT.
    ## `event info <<Copy>>` on this build answers <Control-Key-c>, <Key-F16>,
    ## <Control-Lock-Key-C>, <Meta-Key-w>, <Lock-Meta-Key-W> and
    ## <Control-Key-Insert>; the two physical binds are what DD-5 names and are
    ## what a reader looks for, and <<Copy>> is what carries the other four and
    ## whatever a future Tk maps.  Tk prefers a physical binding over a virtual
    ## one on the SAME tag, so exactly one of the three fires per keystroke.
    ##
    ## The `break` stops the `all` tag.  Measured empty for all three sequences
    ## on this build, so it is defence in depth rather than the mechanism --
    ## kept, and named, the way wave_viewer.tcl:9187 keeps its own.
    bind .rdw <<Copy>>             {rdw::copy ; break}
    bind .rdw <Control-Key-c>      {rdw::copy ; break}
    bind .rdw <Control-Key-Insert> {rdw::copy ; break}
    catch {.rdw configure -background [rdw::color panel]}

    # The status line owns the bottom edge: it is where the five inert buttons
    # say why they did nothing, and where item B5's Save will name the exact
    # settings-file path it wrote.  A button that does nothing AND says
    # nothing cannot be told from a broken one.
    frame .rdw.s -background [rdw::color panel]
    ## ⚠ A WRAPPING `text`, NOT AN `entry`, AND ISSUE 1362 IS THE WHOLE REASON.
    ## An entry cannot wrap and has no scrollbar here, so a sentence wider than
    ## the window was silently amputated -- measured at 147 characters against
    ## an 887 px field, with the clause that answered the user's question in the
    ## missing half.  `rdw::status` is unchanged as a door; what changed is the
    ## surface underneath it.  See rdw::_status_show for the costed alternatives.
    ##
    ## ⚠ `-state disabled`, WHICH IS THE `text` SPELLING OF `readonly` FOR
    ## ISSUE 1308's PURPOSE: nothing typed here can reach a record of a
    ## simulation, and the Text class bindings still select on a drag, which is
    ## what ruling DD-5 and rows CP14/CP16 need -- the settings-file path item
    ## B5 writes here is the most copy-worthy string in the window.
    ##
    ## ⚠ AND IT DOES NOT KEEP THE KEYBOARD OUT, WHICH THIS COMMENT USED TO
    ## CLAIM IT DID (issue 1369).  `tk::TextButton1` calls `focus $w`
    ## UNCONDITIONALLY (/usr/share/tcltk/tk8.6/text.tcl:579); only
    ## `tk::EntryButton1` checks for `disabled` (entry.tcl:356), and that is
    ## the readonly ENTRY this surface replaced.  So one Button-1 here really
    ## does take the keyboard, `-takefocus 0` and all, and it writes Tk's
    ## per-toplevel focus record -- which is what broke the dump's hand-back
    ## until the landing test was widened.  See rdw::_focus_handback.
    ##
    ## ⚠ AND NO -textvariable, BECAUSE A `text` HAS NONE AND BECAUSE IT WOULD BE
    ## A SECOND WRITER.  `rdw::_status_show` is the one painter (row SL2); the
    ## model stays `::rdw::statusmsg`, which is what the --nogui arm and every
    ## other row in this file assert against.
    ##
    ## -height 1 is the resting size: at rest this surface costs exactly what
    ## the entry did.  -wrap word is the fix.
    ##
    ## ⚠ AND IT SCROLLS, WHICH IS ISSUE 1365.  The cap on the height is a cap
    ## on how much of the WINDOW a verdict may take; it was briefly a cap on
    ## how much of the SENTENCE the widget held, and that put issue 1344's
    ## defect back -- `rdw::copy` hands over the X selection, which is what the
    ## widget holds, so an elided widget was an elided clipboard.  See
    ## rdw::_status_show for the three measurements and the costed alternatives.
    text .rdw.s.msg -height 1 -wrap word -state disabled \
        -relief sunken -borderwidth 1 -takefocus 0 -exportselection 1 \
        -font TkTextFont -padx 2 -pady 1 -highlightthickness 0 \
        -yscrollcommand rdw::_status_scrollset \
        -background [rdw::color field] \
        -foreground [rdw::color fieldfg] \
        -selectbackground [rdw::color selectbg] \
        -selectforeground [rdw::color selectfg]
    ## Created here and PACKED ONLY WHEN THERE IS A TAIL (rdw::_status_scroll_sync),
    ## so a one-line verdict -- which is nearly all of them -- costs no width.
    scrollbar .rdw.s.sb -command {.rdw.s.msg yview} -takefocus 0
    ## THE ONE RE-FIT DOOR: the first map, and every user resize.  A fit
    ## computed once at build time would be computed against `winfo width` 1.
    bind .rdw.s.msg <Configure> {rdw::_status_refit}
    ## And the surface never publishes the one character it is forced to hold.
    bind .rdw.s.msg <<Selection>> {rdw::_status_clamp_sel}
    pack .rdw.s.msg -side left -fill x -expand 1 -padx 3 -pady 3
    pack .rdw.s -side bottom -fill x
    ## The window may be built with a verdict already standing (rdw::open is
    ## reachable from a button that has just spoken), so paint what the model
    ## already holds rather than waiting for the next write.
    rdw::_status_show

    # The button column, greyed per spec 4.2 B7 and WIRED by item B5.
    #
    # ⚠ ONE COMMAND FOR ALL FIVE, AND IT IS NOT A CONVENIENCE.  `rdw::button`
    # consults rdw::button_state itself, so the greying table is the COMMAND
    # PATH's fence as well as the widget's: a key, a menu or a later item that
    # reaches the proc directly gets the same answer the widget would have
    # given.  Five separate callbacks would have put that decision in the
    # widget layer, where the --nogui arm cannot see it.
    #
    # ⚠ AND NO WIDGET HERE MAY TAKE FOCUS (issue 1308).  Tk buttons do not on
    # X, which is the only reason the column hands the keyboard back; an entry,
    # a listbox or a -takefocus 1 button would change that into 1308's stuck
    # state.  The scope dialog is a separate TOPLEVEL for exactly that reason.
    #
    # ⚠ `::button`, WITH THE GLOBAL QUALIFIER, AND IT IS NOT STYLE.  This proc
    # runs inside `namespace eval rdw`-scoped code and item B5 named its
    # command sink `rdw::button`, which SHADOWS Tk's own `button` for every
    # unqualified call in this namespace.  Measured the moment it landed: the
    # widget line raised `wrong # args: should be "button id"`, from inside a
    # Button-1 handler, so Tk sent it to `bgerror` -- which pops a MODAL error
    # dialog nobody clicks, and the whole suite HUNG instead of failing (issue
    # 0803's shape, arriving through a name collision rather than a dialog).
    # Every widget command below is qualified for the same reason.
    # ITEM (b), ISSUE 1355 -- THE CHROME LINE, AND WHY IT IS A LABEL.
    #
    # ⚠ NO WIDGET IN THIS WINDOW MAY TAKE THE KEYBOARD (issue 1308), which is
    # the same reason the button column below is buttons and the scope dialog
    # is a separate toplevel.  A `label` does not take focus on X, and -- the
    # second reason, which an `entry` would have broken -- a label can never
    # own PRIMARY, so this line can never join a selection and can never be
    # dragged into the clipboard beside a dump (item R3, ruling DD-5).
    #
    # ⚠ IT SPANS THE WHOLE WIDTH, ABOVE BOTH THE PANE AND THE BUTTONS, because
    # what it says is true of the WINDOW and not of the pane: the buttons obey
    # `::rdw::listkind`, and the pane may be showing a dump taken on a
    # different one.
    #
    # ⚠ AND IT DOES NOT TRAVEL WITH A PASTE, WHICH IS DELIBERATE.  Row NW10
    # put the narrowing sentence IN the block for exactly the opposite reason
    # -- the block is what the user pastes into a design review.  Chrome is
    # STATE and would be stamped onto a record it does not describe; row LX10
    # is that fence.
    ##
    ## ⚠ AND IT IS CREATED WITHOUT ITS TEXT.  `rdw::apply_list_state` at the
    ## foot of this proc fills it, and nothing between here and there pumps the
    ## event loop, so the label is never painted empty.  See the note at the
    ## head of `build` for why a second setter was removed rather than kept.
    ::label .rdw.hdr -anchor w -justify left \
        -background [rdw::color panel]
    pack .rdw.hdr -side top -fill x -padx 4 -pady {3 1}

    frame .rdw.b -background [rdw::color panel]
    foreach {id label} [rdw::_buttons] {
        ::button .rdw.b.$id -text $label -width 8 -command [list rdw::button $id]
        pack .rdw.b.$id -side top -fill x -padx 4 -pady 2
    }
    # ITEM A, ISSUE 1382 -- CLOSE, THE COLUMN'S OWN DISMISS CONTROL.
    #
    # ⚠ RULING DD-12 PROMISED THIS BUTTON AND THE COLUMN DID NOT CARRY IT.
    # That ruling's own stated cost, verbatim: "a user who expects Escape to
    # dismiss the window will press it and see nothing happen. THE WINDOW HAS
    # ITS OWN CLOSE CONTROL, and the dumps are worth more than the keystroke."
    # The only close control the window had was the window MANAGER's X, which
    # is chrome and not part of this window at all -- so the consolation for a
    # keystroke that deliberately does nothing was a control this file had
    # never built.  It builds it now.  DD-12 itself is untouched.
    #
    # ⚠ IT CALLS `rdw::close` AND NOTHING ELSE, WHICH IS THE WHOLE POINT.  The
    # `wm protocol .rdw WM_DELETE_WINDOW` at the head of this proc names the
    # SAME proc, so the X and this button are two DOORS on one rule rather than
    # two teardowns -- invariant I1, in the one place where a second answer
    # costs the user their dumps.  `rdw::close` is a WITHDRAW, not a discard:
    # `::rdw::blocks` is namespace state and that proc touches it not at all,
    # so press Close, press 1 again, and the hour of dumps is still there.
    # Rows CB2 and CB3 fence the one rule and the survival.
    #
    # ⚠ AND ESCAPE IS NOT A THIRD DOOR ON IT.  `<Key-Escape>` on this toplevel
    # ends a running pick and does NOTHING otherwise, which is DD-12's ruled
    # asymmetry and is argued in that binding's own comment above.  A dismiss
    # control in the column is what makes that asymmetry affordable; it does
    # not license Escape to reach here.  Row CB2's last leg reds a future
    # "while we are at it, make Escape close it too".
    #
    # ⚠ IT IS NOT IN `rdw::_buttons`, FOR THE `aA` CONTROL'S OWN REASON.  That
    # table feeds `rdw::button_state`, `rdw::_active_buttons`,
    # `rdw::_active_phrase` and -- since this item -- `rdw::apply_list_state`'s
    # greying loop, so an entry would put "Close" into the chrome sentence
    # "only Up, Down, Delete, Add and Save do anything": a list-action claim
    # about a window action that acts on no list.  (That sentence is a claim
    # about the LIST ACTIONS and never was one about the column -- it has been
    # read over a column with a non-list control in it since issue 1368, and
    # there are two such controls now.  `rdw::_active_phrase`'s own header
    # says so; the wording is the user's to judge, not this item's to change.)
    # Staying out of the table is
    # also WHY it is `normal` on all three identities -- nothing ever
    # configures its -state -- which is a stronger fence than a
    # `rdw::button_state` row would have been, because that proc's default arm
    # already answers `normal` for every id nobody asks about.  Row CB1.
    #
    # ⚠ AND THERE IS NO `rdw::button close`.  `rdw::button` is the door for the
    # five buttons that need the greying table and the status line; this one
    # needs neither, and its command path is `rdw::close` itself -- a public
    # name that predates the button and that the WM protocol already uses.  A
    # `rdw::button close` would be a second NAME for one rule with no gesture
    # behind it, and it could not keep that proc's stated obligation, "every
    # path out of here ends in a status line that names the button it came
    # from", because it destroys the widget the status line lives in.  `aA` is
    # the precedent and not an exception: every button's command is a named
    # `rdw::` proc, and only the LIST ACTIONS go through `rdw::button`.  What
    # `rdw::button close` does instead is REFUSE, and issue 1382 corrected that
    # refusal's wording -- see the foot of this file.  Row CB4.
    #
    # ⚠ PACKED BEFORE `aA` AND THEREFORE BELOW IT ON SCREEN.  `-side bottom`
    # fills the cavity from the bottom UP, so the FIRST widget packed on that
    # side is the lowest one -- do not "restore" source order to match reading
    # order.  The column reads by widening scope: the five edits act on a row
    # of a list, `aA` on how this window renders, Close on the window.  Close
    # is last because that is where a column's dismiss control is looked for,
    # and because it puts the entire column between Close and Save -- the other
    # press whose consequence outlives the click.  A misclick here costs no
    # DUMPS, which is the survival rule doing its second job -- and that is the
    # whole of the claim, not "costs nothing at all", which an earlier spelling
    # of this comment said and which is false in one measured case: see the
    # note on the running pick below.  Row CB1's order leg, and row CB5 on the
    # live widget.
    #
    # ⚠ AND IT DOES NOT END A RUNNING PICK, WHICH IS DELIBERATE AND MEASURED.
    # The pick mode is seized on the CANVAS (`rdw::_pick_seize`), so after a
    # real `.rdw.b.close invoke` with a pick live: `.rdw` gone, `pick_running`
    # still 1, `bind .drw <ButtonPress-1>` still `rdw::pick_click; break`,
    # `bind .drw <Key-Escape>` still `rdw::pick_end; break`.  The mode is
    # recoverable by its own documented exit and the next click reopens this
    # window through `rdw::show`, so nothing is stranded.  Teaching Close to
    # end the mode was REJECTED for two reasons: it is ruling DD-12's asymmetry
    # read the other way round (Escape ends the MODE and never closes the
    # window, so Close closes the WINDOW and never ends the mode -- one
    # gesture, one job), and it could only be done inside `rdw::close`, where
    # it would change what the window manager's X does too.  The two doors have
    # to agree, which is why this is not a one-line addition to the button.
    # Rows CB8 (source) and CB10 (a real pick and a real press) state the
    # contract so it is no longer an accident of where the seize lives.
    ::button .rdw.b.close -text {Close} -width 8 -command rdw::close
    pack .rdw.b.close -side bottom -fill x -padx 4 -pady {8 2}
    # ITEM 1368 -- THE TEXT SIZE CONTROL, IN THE USER'S OWN WORDS: "the 'aa'
    # button you see in e-readers - 2nd a bigger".
    #
    # ⚠ `aA` AND NOT TWO RENDERED SIZES.  A Tk button has exactly ONE font, so
    # the "2nd a bigger" is the capital's CAP HEIGHT against the lowercase
    # x-height.  The two widgets that could really render two sizes -- a canvas
    # and a text -- can both take the keyboard, which issue 1308 forbids for
    # every widget in this window.
    #
    # ⚠ IT IS NOT IN `rdw::_buttons`, AND THAT IS NOT AN OVERSIGHT.  That table
    # feeds `rdw::button_state`, `rdw::_active_buttons` and
    # `rdw::_active_phrase`, so an entry there would put "aA" into the chrome
    # sentence "only Up, Down, Delete, Add and Save do anything".  A font
    # control is not a list action; it is never greyed and never refuses on a
    # list identity.  `-side bottom` with a gap says the same thing visually.
    #
    # ⚠ AND THE Ctrl ARM ENDS IN `break`.  MEASURED: the `break` stops the
    # Button class <Button-1>, so `tk::ButtonUp` never invokes -command and
    # exactly one of the two arms fires -- under Control, Control+NumLock and
    # Control+CapsLock alike.  WITHOUT it a Ctrl+click steps DOWN and then
    # straight back UP, which reads on screen as a button that ignores Ctrl.
    # The 0x4c modifier mask `rdw::_digit` uses is deliberately NOT copied
    # here: that mask exists so a chord the CANVAS spends is not swallowed, and
    # a button press has no such conflict -- Shift+click and Alt+click read as
    # plain clicks, which is Tk's own modifier matching.
    #
    # ⚠ AND THE `break` COSTS THE TOPLEVEL'S OWN <ButtonPress> BINDING, SO THIS
    # SCRIPT PAYS IT BACK BY HAND.  `bindtags .rdw.b.fontsize` is
    # `.rdw.b.fontsize Button .rdw all`: a `break` in the WIDGET tag's script
    # stops `Button` -- which is what it is for -- and stops `.rdw` and `all`
    # with it.  MEASURED on :99 with issue 1369's disarm live: after a real
    # plain click on this button `rdw::focus_pending` is 0, after a click on
    # `.rdw.b.up` 0, after a click in `.rdw.p.t` 0, and after a real Ctrl+click
    # on this button 1 -- the ONE gesture in the window that left the one-shot
    # armed, so the next focus grant handed the keyboard to the CANVAS while
    # the plain arm of the same button leaves it here.  `rdw::_focus_click`
    # neither breaks nor moves the focus (see its own comment), so calling it
    # first restores exactly what the toplevel binding would have done.  Row
    # FZ14 fences the behaviour and row FZ12 the script; without them FZ7 sees
    # only the size delta and the two arms differ in nothing it looks at.
    ::button .rdw.b.fontsize -text {aA} -width 8 -command {rdw::font_step 1}
    bind .rdw.b.fontsize <Control-Button-1> \
        {rdw::_focus_click %W ; rdw::font_step -1 ; break}
    ## THE TREE HAS EXACTLY ONE TOOLTIP MECHANISM -- `balloon` (xschem.tcl:14826)
    ## -- and it bakes a FIXED string into <Enter>, which is precisely the shape
    ## this fixed tip needs.  No second mechanism is warranted and none is
    ## written.  ⚠ `balloon` RE-BINDS <Enter>/<Leave> on every call
    ## (calculator.tcl:1119 records this), so it is called ONCE, here.
    ## ⚠ AND IT STILL IS, even though issue 1384 added `balloon_clipped` /
    ## `balloon_off` beside `balloon`.  Those two are for a tip whose STRING
    ## CHANGES and whose widget belongs to someone else; this label's text and
    ## width never move, so arming once is right and re-deciding it on a timer
    ## would be a cost for nothing.
    ## ⚠ THE 300 ms IS A DEPARTURE from the 1000 ms every other call site in the
    ## tree takes, on the user's own words "as soon as user hovers over it".
    ## Unratified -- rule debt 1368.
    catch {::balloon .rdw.b.fontsize [rdw::_font_tip] 1 0 300}
    pack .rdw.b.fontsize -side bottom -fill x -padx 4 -pady {8 2}
    pack .rdw.b -side right -fill y

    # The pane.  Read-only, selectable, exporting the X selection.
    frame .rdw.p -background [rdw::color panel]
    ## ⚠ NO -width / -height AND NO TkFixedFont HERE -- ISSUE 1368.
    ## The pane's character shape and both its fonts are `rdw::_apply_font`'s,
    ## called at the foot of this proc: ONE setter, so a size the user chose in
    ## an earlier open cannot be honoured by the font and contradicted by the
    ## widget's 96x26.  Nothing between here and there pumps the event loop, so
    ## the pane is never MAPPED at the wrong shape.
    ##
    ## ⚠ AND THE FONT IS PRIVATE.  `-font TkFixedFont` is the SHARED named font
    ## every bare `text` widget in the tree defaults to (measured), so a size
    ## control over it would resize eight other windows on the same click.
    text .rdw.p.t -font [rdw::_font pane] -wrap word \
        -state [rdw::_pane_state] -exportselection [rdw::_exportsel] \
        -borderwidth 1 -relief sunken \
        -background [rdw::color field] \
        -foreground [rdw::color fieldfg] \
        -selectbackground [rdw::color selectbg] \
        -selectforeground [rdw::color selectfg] \
        -yscrollcommand {.rdw.p.ys set}
    scrollbar .rdw.p.ys -command {.rdw.p.t yview}
    # `-wrap word` rather than a horizontal scrollbar: the five silences are
    # long (RW_NOTOP is ~250 characters), and a sentence clipped off the right
    # edge is a sentence the user does not read.  Wrapping is a DISPLAY
    # property -- a copied selection still carries the original lines, so the
    # paste shape is unaffected.
    # (ISSUE 1374: the incompleteness sentence used to be named here too.  At
    # 57 characters it no longer wraps at this width; the silences still do,
    # and they are what this line is for.)
    ## ⚠ THE `hdr` TAG'S FONT IS SET BY `rdw::_apply_font`, NOT HERE -- ISSUE
    ## 1368.  This line used to be `set hf [font actual TkFixedFont] ; dict set
    ## hf -weight bold`, which captures a font DESCRIPTION and not a NAME: a
    ## FROZEN SNAPSHOT that follows nothing.  MEASURED after a size change --
    ## pane linespace 27, `hdr` tag still 17 -- so every block header stayed
    ## small while its body grew.
    .rdw.p.t tag configure dim  -foreground [rdw::color disabledfg]
    .rdw.p.t tag configure dev  -foreground [rdw::color accent]
    .rdw.p.t tag configure note -foreground [rdw::color notefg]
    # ITEM R1, ISSUE 1337 -- THE LINE CURSOR.  The other four tags colour TEXT;
    # this one colours the whole row, so that the row Delete / Add / Up / Down
    # act on is a row the user can SEE.  It shades the target rdw::set_row
    # already moved -- there is exactly one cursor here, and rdw::_paint_cursor
    # is its only painter.
    #
    # ⚠ AND IT IS LOWERED BELOW `sel`.  MEASURED on this binary: `tag names`
    # answers `sel hdr dim dev note`, so `sel` is the LOWEST-priority tag in
    # the pane and a tag created now lands ABOVE it -- and a full-width
    # background above `sel` hides the selection outright.  This window exists
    # to be selected and pasted into a design-review document (item R3, issue
    # 1339), so the cursor gives way to the selection and never the other way
    # round.  Row CU10 of tests/headless/test_rdw_keys_1245.tcl is that fence.
    .rdw.p.t tag configure cursor -background [rdw::color cursor]
    .rdw.p.t tag lower cursor sel
    # ITEM R3, ISSUE 1339 -- THE HIGHLIGHT THAT SURVIVES A PRIMARY THEFT.
    # `keepsel` wears the selection's own colours because it IS the selection,
    # still standing after the X server handed PRIMARY to somebody else; see
    # rdw::_selection_changed for the mechanism and for what was measured.
    #
    # ⚠ ITS PRIORITY IS PINNED BETWEEN THE OTHER TWO, and neither neighbour is
    # arbitrary.  A tag created now lands ABOVE everything, and a full-width
    # selection colour above `sel` would hide the real selection whenever both
    # cover the same span.  Below `cursor` it would be hidden BY the line
    # cursor, which is a full-width background of its own.  Raising it just
    # above `cursor` leaves the order cursor / keepsel / sel, which is what row
    # CP8 of the keys suite reads back.
    .rdw.p.t tag configure keepsel -background [rdw::color selectbg] \
        -foreground [rdw::color selectfg]
    .rdw.p.t tag raise keepsel cursor
    bind .rdw.p.t <<Selection>> {rdw::_selection_changed}
    # ⚠ NO `break`.  A <Button-1> binding that ends in `break` stops the Text
    # CLASS binding, which is where the drag anchor a selection extends from is
    # set -- so the cursor would cost the window the one thing it is for.  The
    # widget binding runs BEFORE the class binding (bindtags MEASURED on this
    # binary are `.rdw.p.t Text .rdw all` -- item R1 wrote `.` for the third
    # tag, and item R3 depends on it really being `.rdw`), so both happen, in
    # that order.
    bind .rdw.p.t <Button-1> {rdw::pane_click %x %y}
    # ITEM R3 -- THE EXTEND, AND WHY IT IS ON THE TOPLEVEL TAG.
    # The fix-up has to run AFTER Tk's own <B1-Motion> has recomputed `sel`,
    # and the widget tag runs BEFORE the class tag.  `.rdw` is the next tag
    # after `Text` in the chain above, so this is the first place a binding can
    # see what the class binding decided.  rdw::pane_drag ignores every widget
    # but the pane -- the scrollbar shares this tag.
    bind .rdw <B1-Motion> {rdw::pane_drag %W}
    # ITEM R3, RULING DD-5 -- A COPY THAT NEEDS NO KEYBOARD AT ALL.
    # "A keyboard binding that a window manager or X server eats can never
    # leave the user with no way to get the text out -- which is the whole
    # point of the window."  MEASURED before this line existed: `bind
    # .rdw.p.t <Button-3>`, `bind Text <Button-3>` and `bind all <Button-3>`
    # were all the empty string, so a right-click in this pane did nothing.
    # %X %Y are ROOT pixels, which is what tk_popup wants -- the spelling
    # library_manager.tcl:144 already uses.  The `break` is defence in depth
    # against a future toplevel- or all-level Button-3, not the mechanism.
    bind .rdw.p.t <Button-3> {rdw::popup_menu %X %Y ; break}
    ## ⚠ AND THE CHORD IS BOUND ON THE PANE AS WELL, WHICH IS THE ONLY WAY
    ## rdw::copy CAN BE THE ONE COPY IT SAYS IT IS (issue 1344).
    ## The bindtag chain here is `.rdw.p.t Text .rdw all`, so `bind Text
    ## <<Copy>>` -- Tk's own tk_textCopy -- runs BEFORE the toplevel binding
    ## above it.  While the pane holds the keyboard that class binding is a
    ## SECOND door on to the clipboard, and it obeys none of rdw::copy's
    ## guards: MEASURED while writing row CP13, a selection covering nothing
    ## but a blank line put a bare newline on the clipboard through it, and the
    ## refusal rdw::copy then printed was true of everything except what had
    ## already happened.
    ##
    ## The widget tag runs FIRST, so this binding is the first thing the event
    ## meets, and the `break` is load-bearing here rather than defence in
    ## depth: it stops `Text` and it stops `.rdw`, so exactly one copy runs and
    ## it is this one.  Breaking THIS class binding costs nothing -- rdw::copy
    ## does everything tk_textCopy does and refuses the cases it should --
    ## unlike <Button-1>, whose class binding sets the drag anchor and is why
    ## the comment above it forbids a `break` there.
    bind .rdw.p.t <<Copy>>             {rdw::copy ; break}
    bind .rdw.p.t <Control-Key-c>      {rdw::copy ; break}
    bind .rdw.p.t <Control-Key-Insert> {rdw::copy ; break}
    pack .rdw.p.ys -side right -fill y
    pack .rdw.p.t -side left -fill both -expand 1
    pack .rdw.p -side left -fill both -expand 1

    ## ITEM 1368.  The ONE painter for both fonts and for the pane's character
    ## shape.  MEASURED: without it a reopen comes back at TkFixedFont size 10
    ## with the user's chosen size still standing in the model, and the `hdr`
    ## tag carries no font at all.
    rdw::_apply_font
    rdw::apply_list_state
    rdw::render_pane
    ## ...and NOW the column exists and the pane has been given its real
    ## character shape, so the minimum can be raised from the floor to what
    ## this column asks for.  Deliberately LAST: it is the only thing in
    ## this proc that pumps the idle queue, and everything above it is a
    ## setter that must have run before the window is mapped (issue 1382).
    rdw::apply_minsize
    return .rdw
}

# Repaint the pane from the store.  The store is newest-first and the blocks
# are laid out in that order, so the newest dump is on top and older ones are
# pushed below it.
proc rdw::render_pane {} {
    variable blocks
    variable targetrow
    # ⚠ A CURSOR MAY NOT OUTLIVE THE LINE IT POINTS AT (item R1, issue 1337),
    # AND THE SWEEP RUNS ABOVE THE Tk GUARD ON PURPOSE.  Every repaint is a
    # chance for the target's line to have gone: `4` (rdw::keep_latest) throws
    # the older dumps away, and a later item's reorder rewrites the rows in
    # place.  `rdw::_locate` is already the exact predicate for "a line some
    # block still owns", so a target it can no longer resolve is cleared HERE,
    # once, rather than at each of the callers that can strand one.
    #
    # The store works headless and the pane is only its projection (rdw::push's
    # own words), so a sweep behind the Tk guard would leave the two ARMS
    # disagreeing about the same store: with a display the buttons would say
    # "no row is marked", without one they would still refuse a line that no
    # longer exists BY ITS NUMBER.  This suite's majority runs --nogui and
    # would never have seen it.
    #
    # Clearing is the least-destructive reading: the buttons say there is no
    # row rather than editing whatever slid under the old line number.
    if {[info exists targetrow] && $targetrow > 0 \
        && [rdw::_locate $targetrow] eq {}} { set targetrow 0 }
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    .rdw.p.t configure -state normal
    .rdw.p.t delete 1.0 end
    # ITEM R3, ISSUE 1339.  ::rdw::selspan and ::rdw::dragfrom are pairs of
    # TEXT INDICES, and every line they name has just ceased to exist.  A text
    # index never fails to resolve -- Tk clamps it -- so a span left standing
    # here would go on copying, silently and plausibly, whatever slid under
    # those line numbers.  That is issue 1324's shape (a mark left to drift
    # while a variable still named the old row) pointed at the clipboard.
    rdw::_forget_selection
    foreach b $blocks {
        foreach e $b {
            .rdw.p.t insert end "[lindex $e 1]\n" [lindex $e 0]
        }
    }
    .rdw.p.t configure -state [rdw::_pane_state]
    rdw::_paint_cursor
    catch {.rdw.p.t see [rdw::_insert_index]}
    return {}
}

# THE CURSOR'S ONLY PAINTER (item R1, issue 1337).  It draws ::rdw::targetrow
# and reads no other state, so the shading cannot disagree with the row the
# button column acts on -- a second variable of its own would have given this
# window TWO cursors, a visible one and the one Delete obeys.
#
# ⚠ `$n.0` TO `[expr {$n + 1}].0`, NOT `lineend`.  The user's words are "the
# ENTIRE line"; a tag that stops at `lineend` stops at the last character, and
# on a 96-column pane holding a 12-character parameter row that is a stub of
# colour rather than a line.  Ending at the START of the next line is what
# paints past the last character to the right edge.  A WRAPPED line (the pane
# is -wrap word and the five silences really do wrap -- the incompleteness
# sentence did too until issue 1374 cut it to 57 characters) is one logical
# line and is shaded whole by the same span.
#
# The `insert` mark follows, so anything that reads the widget agrees with the
# variable -- issue 1324's measured disagreement (insert 9, targetrow 3) is
# what a mark left to drift on its own looks like.
proc rdw::_paint_cursor {} {
    variable targetrow
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    catch {.rdw.p.t tag remove cursor 1.0 end}
    if {![info exists targetrow]} { return {} }
    if {![string is integer -strict $targetrow] || $targetrow <= 0} { return {} }
    catch {.rdw.p.t mark set insert $targetrow.0}
    catch {.rdw.p.t tag add cursor $targetrow.0 [expr {$targetrow + 1}].0}
    return {}
}

# A click in the pane cursors the line under the pointer (item R1, issue 1337).
#
# ⚠ IT REFUSES A LINE NO BLOCK OWNS, AND `rdw::_locate` IS THE WHOLE GUARD.
# MEASURED: `index @x,y` CLAMPS -- a click in the empty lower half of a pane
# holding a 12-line render answers line 13, the widget's own trailing artifact.
# Shading that would put the cursor on a row the user cannot see and the
# buttons cannot use.  `_locate` already answers {} for exactly those lines
# (and for every line of an empty pane), so the refusal needs no new
# machinery.  A refused click leaves the cursor WHERE THE USER PUT IT: the
# least-destructive reading, and the one that does not punish a missed click.
proc rdw::pane_click {x y} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    # ITEM R3, ISSUE 1339.  This runs BEFORE the Text class binding throws the
    # standing selection away, which is the only moment the press can still be
    # compared against it.  It arms or disarms unconditionally, above every
    # early return below: a click this proc REFUSES for the cursor's sake is
    # still a click, and leaving the previous gesture's anchor armed would let
    # it extend a selection the user has since walked away from.
    rdw::_arm_extend $x $y
    set ix {}
    if {[catch {.rdw.p.t index @$x,$y} ix]} { return {} }
    set l [lindex [split $ix .] 0]
    if {![string is integer -strict $l]} { return {} }
    if {[rdw::_locate $l] eq {}} { return {} }
    rdw::set_row $l
    return {}
}

# ===========================================================================
# ITEM R3, ISSUE 1339 -- SELECT, AND COPY WHAT YOU SELECTED
# ===========================================================================
# The user's words: "Select and then press CTRL-C doesn't work. (Using VcXsrv
# for now). Double-click to start selection and then extend selection with
# press-and-drag seemed to work once, but not reliably. It's only worked one
# time."
#
# Pasting a dump into a design-review document is the whole stated reason this
# window is a Text widget and not a CIW dump, so this is the item that decides
# whether the feature is usable at all.
#
# ⚠ THE LITERAL READING OF RULING DD-5 IS A NO-OP HERE, AND SHIPPING IT WOULD
# HAVE BEEN GREEN AND WRONG.  DD-5 spells the repair as "bind <Control-c>,
# <Control-Insert> and <<Copy>> to a proc that does clipboard clear + clipboard
# append".  MEASURED on this binary, Tk 8.6.17, :99, 2026-09-05:
# `event info <<Copy>>` ALREADY answers <Control-Key-c>, <Key-F16>,
# <Control-Lock-Key-C>, <Meta-Key-w>, <Lock-Meta-Key-W> and
# <Control-Key-Insert>, and with the keyboard in the pane a real Ctrl-C ALREADY
# copies, through Tk's own Text class binding.  A row that selected a line,
# pressed Ctrl-C at the pane and asserted the clipboard passes on the
# UNMODIFIED tree.  Three different things are broken, and the literal reading
# of DD-5 fixes none of them:
#
#   1. THE KEYBOARD IS USUALLY NOT IN THE PANE.  Fixed by binding the chord on
#      the TOPLEVEL tag -- see rdw::build, where the measurement is recorded.
#
#   2. ANOTHER X CLIENT TAKES PRIMARY AND THE SELECTION VANISHES.  Fixed by
#      the mirror below -- see rdw::_selection_changed.
#
#   3. DOUBLE-CLICK, LET GO, THEN PRESS AND DRAG THROWS THE WORD AWAY.  Fixed
#      by rdw::pane_drag below.
#
# AND THE INPUT MOST LIKELY TO BREAK THE FIX, WHICH IS DD-5's OWN SPELLING:
# `clipboard clear` followed by `clipboard append` with nothing to append
# DESTROYS whatever the user had on the clipboard -- very likely the thing they
# were about to paste this dump next to.  rdw::copy therefore decides FIRST and
# writes second, and says out loud that it copied nothing: a copy that quietly
# does nothing cannot be told from the broken one this item exists to fix, and
# "doesn't work" is the entire bug report.  Same obligation as calc::inert's
# and rdw::button's -- a real control that does something and says nothing.
#
# WHAT WAS REJECTED, AND WHAT IT WOULD HAVE COST.  `-exportselection 0` (flip
# rdw::_exportsel) makes 2 impossible in ONE LINE, because a pane that exports
# nothing can never lose PRIMARY.  It also ends select-then-middle-click-paste,
# which rdw::_exportsel's own comment calls the user's stated reason the window
# exists at all.  Row CP10 of the keys suite is the receipt for not paying it.
#
# Suite: tests/headless/test_rdw_keys_1245.tcl section CP.  ⚠ RULING DD-8: a
# green :99 run is necessary and NOT sufficient for this item -- $DISPLAY is
# the VcXsrv / HC-Consult server the user actually looks at, `:0` is WSLg's
# Xwayland and `:99` is Xvfb (CLAUDE.md's three-server table), and selection
# and clipboard are precisely where the three differ.

namespace eval rdw {
    # THE REMEMBERED SELECTION, {first last} or {} -- the mirror that keeps the
    # user's selection alive across a PRIMARY theft.  rdw::_selection_changed
    # is its only writer.
    variable selspan
    if {![info exists selspan]} { set selspan {} }

    # The standing selection a <Button-1> press landed INSIDE of, {first last}
    # or {}, armed by rdw::_arm_extend and spent by rdw::pane_drag.  It is not
    # the same thing as `selspan`: this one answers "should the drag now
    # starting GROW what is already selected", and it is empty for the far more
    # common press that lands outside.
    variable dragfrom
    if {![info exists dragfrom]} { set dragfrom {} }
}

# THE MIRROR'S ONLY WRITER, and the one place this window decides whether a
# selection went away because the USER dropped it or because SOMEBODY TOOK IT.
#
# ⚠ THE MECHANISM, MEASURED RATHER THAN ASSUMED.  A Tk text widget with
# -exportselection 1 answers the loss of the X PRIMARY selection by DELETING
# ITS OWN `sel` TAG.  Driven on this binary: with a line selected,
# `selection own -selection PRIMARY .` leaves `tag ranges sel` EMPTY, `get
# sel.first sel.last` raising "text doesn't contain any characters tagged with
# sel", and the following Ctrl-C writing NOTHING AT ALL -- tk_textCopy's catch
# swallows it, so the user's clipboard silently keeps whatever it had.  That is
# BOTH halves of the user's report in one mechanism, and VcXsrv is exactly
# where it bites: its Windows clipboard bridge takes PRIMARY on its own
# schedule, which is why the gesture "worked one time".
#
# ⚠ AND THE DISCRIMINATOR IS THE OWNER, WHICH IS THE ONLY HONEST ONE.  Both a
# theft and a deliberate deselect arrive here as one <<Selection>> event with
# `tag ranges sel` empty, so the event alone cannot tell them apart.  MEASURED,
# reading `selection own` INSIDE the handler:
#     user clicks elsewhere in the pane   -> owner is .rdw.p.t
#     a script does `tag remove sel`      -> owner is .rdw.p.t
#     another client takes PRIMARY        -> owner is that client, or empty
# Tk does not release the selection when the tag is merely emptied, so "the
# pane still owns PRIMARY" means the user gave the selection up and the mirror
# must go with it; "the pane has lost PRIMARY" means it was taken, and the
# highlight the user is looking at must NOT vanish under them.  The query is
# local -- `selection own` names a window in THIS application or nothing, and
# never makes an X round trip to a foreign owner, which inside an event handler
# could block for the selection timeout.
#
# The mirror is NOT re-asserted as `sel`, deliberately: re-adding the tag would
# take PRIMARY straight back off the client that just asked for it, and two
# applications fighting over the selection is worse than the bug.
proc rdw::_selection_changed {} {
    variable selspan
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    set r {}
    if {[catch {.rdw.p.t tag ranges sel} r]} { return {} }
    if {[llength $r] >= 2} {
        set selspan [list [lindex $r 0] [lindex $r end]]
        rdw::_paint_keepsel
        return {}
    }
    set own {}
    catch {set own [selection own -displayof .rdw.p.t -selection PRIMARY]}
    # ⚠ A SELECTION IN ANY WIDGET OF THIS TOPLEVEL IS THE USER'S SELECTION,
    # AND THE MIRROR MUST GIVE WAY TO IT (issue 1344, defect b).  This test used
    # to be `$own eq {.rdw.p.t}` and nothing else, so the status entry -- which
    # is a readonly `entry` with -exportselection 1, and which item B5 fills
    # with the settings-file path, the single most copy-worthy string in the
    # window -- was scored a FOREIGN theft the moment the user dragged across
    # it.  The stale mirror was kept and the next Ctrl-C copied the PANE.
    # MEASURED before this line: PRIMARY holding
    # `/home/analog/.xschem/op_param_lists.tcl`, Ctrl-C, clipboard `MCU:/`.
    #
    # A theft is somebody ELSE taking the selection.  A sibling of this window
    # taking it is the user putting the selection somewhere else on purpose,
    # which is the same event as putting it down in the pane.
    if {[rdw::_in_window $own]} {
        set selspan {}
        rdw::_paint_keepsel
    }
    return {}
}

# Is $w this window or something inside it?  Pure, so the --nogui suite can
# fence it; `.rdw.` with the dot is deliberate -- a future toplevel named
# `.rdwx` is not this window and `string match {.rdw*}` would claim it.
proc rdw::_in_window {w} {
    if {$w eq {}} { return 0 }
    if {$w eq {.rdw}} { return 1 }
    if {[string match {.rdw.*} $w]} { return 1 }
    return 0
}

# The mirror's only painter, ::rdw::selspan and nothing else -- the same rule
# rdw::_paint_cursor follows, and for the same reason: a highlight drawn from a
# second opinion is a highlight that can disagree with what Ctrl-C copies.
proc rdw::_paint_keepsel {} {
    variable selspan
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    catch {.rdw.p.t tag remove keepsel 1.0 end}
    if {[llength $selspan] == 2} {
        catch {.rdw.p.t tag add keepsel [lindex $selspan 0] [lindex $selspan 1]}
    }
    return {}
}

# Drop both spans and the highlight that draws one.  Called wherever the buffer
# they index into stops being the buffer they were taken from.
proc rdw::_forget_selection {} {
    variable selspan
    variable dragfrom
    set selspan {}
    set dragfrom {}
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    catch {.rdw.p.t tag remove keepsel 1.0 end}
    return {}
}

# The span a copy acts on: {first last}, or {} when there is nothing to copy.
#
# ⚠ `sel` FIRST AND THE MIRROR SECOND, NEVER THE OTHER WAY ROUND.  While the
# pane still owns PRIMARY the widget's own tag is the truth -- the user may
# have moved it with the mouse a microsecond ago, and the mirror is only ever
# as fresh as the last <<Selection>>.  The mirror is consulted only when `sel`
# is gone, which in this window means one thing: somebody took PRIMARY.
#
# first..last rather than the individual ranges, because that is exactly what
# Tk's own tk_textCopy copies (`$w get sel.first sel.last`).  The two doors on
# to the clipboard must not disagree about a discontiguous selection, and this
# window has no way to make one anyway.
proc rdw::_selection_span {} {
    variable selspan
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    set r {}
    if {![catch {.rdw.p.t tag ranges sel} r] && [llength $r] >= 2} {
        return [list [lindex $r 0] [lindex $r end]]
    }
    if {[llength $selspan] != 2} { return {} }
    # ⚠ AND THE MIRROR IS STALE THE MOMENT ANOTHER WIDGET OF THIS WINDOW
    # HOLDS THE SELECTION (issue 1344, defect b).  rdw::_selection_changed
    # already drops it when it sees the hand-over, but it only sees one it is
    # told about: the pane fires <<Selection>> when its OWN `sel` tag changes,
    # and after a foreign theft that tag is already empty, so a later drag in
    # the status entry changes nothing the pane can hear.  Without this leg the
    # mirror outlives the theft AND the hand-over and Ctrl-C copies the pane.
    if {[llength [rdw::_sibling_selection]] == 2} { return {} }
    set ok 0
    if {[catch {.rdw.p.t compare [lindex $selspan 0] < [lindex $selspan 1]} ok]} {
        return {}
    }
    if {!$ok} { return {} }
    return $selspan
}

# ---------------------------------------------------------------------------
# HOW MANY PANE LINES THE SELECTION COVERS -- ISSUE 1356
# ---------------------------------------------------------------------------
# THE USER'S WORDS: "I select a bunch of lines - sa, sb, up to scc - and press
# Delete ... The delete did not have an effect."
#
# MEASURED on their own design: `tag ranges sel` answered `8.4 13.4` -- SIX
# rows highlighted -- while `::rdw::targetrow` was 8, and the one press
# produced one verdict about one parameter.  A MULTI-ROW DELETE IS NOT A THING
# THIS WINDOW DOES: `rdw::button` reads `rdw::_target_line`, whose only setter
# is `rdw::set_row` from the <Button-1> click, while every reader of the text
# selection in this file (`copy`, `select_all`, `_selection_changed`,
# `_selection_span`, `_sibling_selection`, `_arm_extend`, `pane_drag`,
# `popup_menu`) is on the CLIPBOARD path.  The two gestures look identical and
# the window said nothing about the difference.
#
# ⚠ THE CLAUSE WAS THE ANSWER; IT IS NOT THE ANSWER ANY MORE.  Saying so was
# the right size of fix while a multi-row press was a RULING and not a patch,
# and issue 1356 was filed with the one-row answer proposed.  The user has
# since ruled the other way, in these words: "When multiple lines of parameters
# are selected and user presses Add or Delete, those should get processed the
# same way that a single line would get processed."  So the three problems that
# comment names are now SOLVED rather than declared, each in one place:
#
#   * ONE DIALOG for N rows -- `rdw::scope_dialog` is raised once, outside the
#     loop, which is why the batch is confined to a single BLOCK: the dialog
#     names one instance, one cell and one class, and a question that named one
#     device while writing for another would be a false statement on a screen
#     the user is reading.  Row BT9 golds the count of exactly one.
#   * ONE SENTENCE reporting N outcomes -- `rdw::_batch_say`, which names every
#     row that changed and every row that did not, with the store's own reason
#     for each.
#   * RULING DD-10 ASKED OF THE BATCH -- `rdw::_batch_last_row_why`, before the
#     first write, so the five-deleted-then-refused-on-the-sixth outcome that
#     comment warns about cannot happen.  There is no undo in this window and
#     that was the whole reason the feature was a ruling.
#
# What survives is the LINE COUNT, because Up and Down still act on the shaded
# row alone -- spec 4.2 B7 gives them no dialog and therefore no answer to obey
# for a batch -- so the clause is still owed, narrowed to those two buttons.
proc rdw::_selection_span_lines {} {
    set sp [rdw::_selection_span]
    if {[llength $sp] != 2} { return {} }
    set a [lindex [split [lindex $sp 0] .] 0]
    set b [lindex [split [lindex $sp 1] .] 0]
    set c [lindex [split [lindex $sp 1] .] 1]
    if {![string is integer -strict $a]} { return {} }
    if {![string is integer -strict $b]} { return {} }
    ## A span ending at column 0 stops at the START of that line, so the line
    ## itself is not covered.  `tag add sel 5.0 11.0` is six lines, not seven.
    if {[string is integer -strict $c] && $c == 0} { incr b -1 }
    if {$b < $a} { return {} }
    return [list $a $b]
}

proc rdw::_selection_lines {} {
    set sp [rdw::_selection_span_lines]
    if {[llength $sp] != 2} { return 0 }
    return [expr {[lindex $sp 1] - [lindex $sp 0] + 1}]
}

# ---------------------------------------------------------------------------
# THE ROWS A PRESS ACTS ON WHEN A SELECTION IS STANDING (the user's ruling)
# ---------------------------------------------------------------------------
# The PARAMETER rows the selection covers, in pane order, deduped by parameter
# name, as a dict {blocks {..} params {..} locs {..} lines {..}}; `{}` when no
# selection is standing or when it covers no parameter row at all.
#
# ⚠ IT IS DEDUPED BY NAME, NOT BY LINE, AND THE TWO DIFFER.  One drag can cover
# the same parameter in two different blocks -- the window keeps its dumps, so
# two dumps of the same device are the ordinary case -- and the second Delete
# of `gm` would be refused as "not in the list" by a store that had already
# removed it, turning a successful batch into one that reports a failure it
# caused itself.
#
# ⚠ AND `rdw::_locate` IS THE ONLY LINE->ROW CONVERTER, here as everywhere
# else.  It is pure in `::rdw::blocks` because `rdw::render_pane` paints one
# line per stored entry in store order; a second walk with its own arithmetic
# would be a second definition of "which row is line N" and would drift the
# first time a block gained a line.
#
# ⚠ NOTHING HERE IS SAFE TO CALL AFTER AN EDIT.  Every success arm repaints,
# and `rdw::render_pane` deletes the pane's text and with it the `sel` tag, so
# the batch is taken ONCE at the top of `rdw::button` alongside the selection
# note and for the same measured reason (issue 1356).
proc rdw::_selection_rows {} {
    variable blocks
    set sp [rdw::_selection_span_lines]
    if {[llength $sp] != 2} { return {} }
    set bis {} ; set params {} ; set locs {} ; set lines {}
    for {set L [lindex $sp 0]} {$L <= [lindex $sp 1]} {incr L} {
        set loc [rdw::_locate $L]
        if {[llength $loc] != 2} { continue }
        set e {}
        catch {set e [lindex [lindex $blocks [lindex $loc 0]] [lindex $loc 1]]}
        set p [rdw::_row_param $e]
        if {$p eq {}} { continue }
        if {[lsearch -exact $bis [lindex $loc 0]] < 0} {
            lappend bis [lindex $loc 0]
        }
        if {[lsearch -exact $params $p] >= 0} { continue }
        lappend params $p ; lappend locs $loc ; lappend lines $L
    }
    if {![llength $params]} { return {} }
    return [dict create blocks $bis params $params locs $locs lines $lines]
}

# A prose list: `a`, `a and b`, `a, b and c`.  ONE builder, because a batch
# sentence names parameters in three different clauses and three hand-rolled
# joins would punctuate the same fact three ways.
proc rdw::_and_list {items} {
    set n [llength $items]
    if {$n == 0} { return {} }
    if {$n == 1} { return [lindex $items 0] }
    if {$n == 2} { return "[lindex $items 0] and [lindex $items 1]" }
    return "[join [lrange $items 0 end-1] {, }] and [lindex $items end]"
}

# THE ONE-BLOCK REFUSAL, WORDED FROM WHAT IS ACTUALLY DIFFERENT.
#
# A selection that crosses a block boundary is refused, because the scope
# dialog raised for it would name one instance while the write reached another.
# The sentence has to earn that refusal, so it names the CLASSES when they
# differ -- two classes are two different lists and one dialog answer cannot
# cover both -- and says "the same device dumped twice" when they do not, which
# is the ordinary case in a window that deliberately keeps its dumps.
proc rdw::_batch_spread_why {bis} {
    set names {}
    foreach bi $bis {
        set s [rdw::_subject $bi]
        set c {}
        catch {set c [dict get $s class]}
        if {$c eq {}} { continue }
        set d $c
        catch {set d [::op_param_lists::class_label $c]}
        if {[lsearch -exact $names $d] < 0} { lappend names $d }
    }
    if {[llength $names] > 1} {
        return "the selected rows span [rdw::_and_list $names], which are different lists, and one answer to \"which devices?\" cannot cover both. Select rows from one dump at a time."
    }
    return "the selected rows span [llength $bis] dumps in this window. The scope question names one device, so select rows from one dump at a time."
}

# RULING DD-10, ASKED OF THE WHOLE BATCH AND BEFORE THE FIRST WRITE.
#
# `rdw::_last_row_why` refuses a Delete that would empty a list, and asking it
# per row over a batch would delete N-1 rows and refuse the last -- with no
# undo in this window, and with the user having pressed once.  So count the
# batch's rows that are actually IN the base first, and refuse the whole press
# if removing them all would leave nothing.
#
# ⚠ THE SENTENCE IS DD-10's OWN, EXTENDED, NOT A SECOND WORDING FOR IT.  A
# batch of ONE falls straight through to `rdw::_last_row_why`, so the single-row
# press keeps the sentence rows CL7 and BE-series gold, byte for byte.
proc rdw::_batch_last_row_why {base listname params} {
    if {[llength $params] < 2} {
        return [rdw::_last_row_why $base $listname [lindex $params 0]]
    }
    set n 0
    foreach p $params { if {[rdw::_index_of $base $p] >= 0} { incr n } }
    if {$n == 0} { return {} }
    if {[expr {[llength $base] - $n}] >= 1} { return {} }
    set what [rdw::_and_list $params]
    if {$listname eq {annotation}} {
        return "removing $what would empty the annotation list, and at least one parameter must stay. To stop showing operating-point values on this device, turn the annotation off instead."
    }
    return "removing $what would empty the summary list, and at least one parameter must stay. Add another before removing these."
}

# ⚠ THE BOUNDARY IS SPLIT OUT SO IT CAN BE DRIVEN AT ITS OWN VALUES.  The
# clause's whole claim is that it fires at two lines and NOT at one -- one line
# is the select-a-value-to-copy-it gesture this window exists for -- and with
# the test only reachable through a live `sel` tag, the two rows that asserted
# it drove 0 lines and "two or more".  MEASURED: changing `< 2` to `< 1` kept
# test_rdw_window_1245 and test_rdw_keys_1245 fully green while appending the
# whole lecture to every ordinary one-row copy.  Row LX15 drives 0, 1, 2 and 16
# on both arms.
proc rdw::_selection_note {id} {
    return [rdw::_selection_note_for [rdw::_selection_lines] $id]
}

# ⚠ THE CLAUSE IS NOW PER BUTTON, BECAUSE THE FACT IT STATES IS.  It used to
# say "the buttons act on the shaded row alone", which was true of all four and
# is now true of two: the user's ruling made Add and Delete act on the selected
# rows, and Up and Down still cannot, because spec 4.2 B7 gives them no dialog
# and a reorder has no batch meaning -- N rows cannot each move up one without
# the answer depending on the order they are asked in.  A clause that kept the
# old wording would be a false statement on a screen the user is reading, which
# is the defect it was written to remove, pointed the other way.
#
# ⚠ AND IT IS STILL CONDITIONAL, which is why it is an answer and not noise:
# it fires only when a selection is actually standing across two or more lines,
# i.e. only when the user made the gesture it is about.  One line is the
# select-a-value-to-copy-it gesture this window exists for.  Row BT31 asserts
# both halves and row LX15 drives the boundary at 0, 1, 2 and 16.
#
# Add and Delete need no clause at all now: their own sentence names every row
# they changed and every row they did not, which is a better answer than a
# standing lecture.
proc rdw::_selection_note_for {n id} {
    if {$n < 2} { return {} }
    if {$id ne {up} && $id ne {down}} { return {} }
    return {Selecting lines does not choose them for Up and Down - those act on the shaded row alone.}
}

# THE SELECTION STANDING IN SOME OTHER WIDGET OF THIS WINDOW: {widget text},
# or {} when no widget of .rdw except the pane holds one.
#
# ⚠ THE STATUS SURFACE IS NOT A CURIOSITY, IT IS THE POINT.  `.rdw.s.msg` is a
# disabled `text` with -exportselection 1 and a real drag selects in it (issue
# 1362 changed the class from a readonly `entry`; the Text class bindings
# select on a drag exactly as the Entry class ones did); item B5 writes the
# settings-file path there, and a path is exactly the sort of string a user
# copies.  Ruling DD-5 gave this window a copy that works from
# anywhere in it -- so "anywhere in it" has to include the one widget whose
# contents the user most wants.
#
# ⚠ THE OWNER IS ASKED FIRST AND `selection get` ONLY AFTER.  `selection own`
# names a window in THIS application or nothing and never makes an X round
# trip; `selection get` against a LOCALLY owned selection is served in-process
# by the owner's own handler, so neither call can block inside a key handler
# for the selection timeout.  Reading it from X rather than from the widget
# keeps this proc honest for a widget class that is not an entry.
proc rdw::_sibling_selection {} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw]} { return {} }
    set own {}
    if {[catch {selection own -displayof .rdw -selection PRIMARY} own]} { return {} }
    if {$own eq {.rdw.p.t}} { return {} }
    if {![rdw::_in_window $own]} { return {} }
    set txt {}
    if {[catch {selection get -displayof .rdw -selection PRIMARY} txt]} { return {} }
    return [list $own $txt]
}

# ⚠ THE GUARD THAT MATTERS IS NOT "IS THE STRING EMPTY" (issue 1344,
# defect a).  `rdw::copy` used to ask `$txt eq {}`, which CANNOT be true of any
# span this window can produce -- `get first last` with first < last always
# yields at least one character -- so the guard was dead and the real case went
# through it.  The reachable instance is the EMPTY WINDOW: a Tk text widget
# always holds one mandatory trailing newline, `tag add sel 1.0 end` on it is
# the range {1.0 2.0}, and the user's clipboard was replaced by "\n".
#
# Whitespace, so a span of spaces or blank separator lines is refused too.  The
# cost is that a user who genuinely wanted to copy blank space is told no; the
# alternative is destroying the document they were about to paste into.
proc rdw::_worth_copying {txt} {
    return [expr {[string trim $txt] eq {} ? 0 : 1}]
}

# ONE COUNTER, AND BOTH DOORS COUNT THE SAME STRING WITH IT (issue 1344,
# defect d).  The window used to say "Selected the whole window, 1 line" and
# then "Copied 2 lines, 1 characters" about one and the same content, because
# rdw::select_all counted the LINE NUMBER of `end - 1c` and rdw::copy counted
# the elements of `split $txt \n`.  Both were wrong and they were wrong by
# different amounts.
#
# What the user is promised is the shape that lands in their document, so a
# trailing newline ends the last line rather than starting a new empty one --
# "a\nb\n" is two lines, and so is "a\nb".
proc rdw::_copy_lines {txt} {
    if {$txt eq {}} { return 0 }
    set n [llength [split $txt "\n"]]
    if {[string index $txt end] eq "\n"} { incr n -1 }
    return $n
}

# SAY WHAT THE COPY DID -- UNLESS THE STATUS LINE IS THE THING BEING COPIED
# (issue 1344, defect c).  rdw::status writes ::rdw::statusmsg, which is the
# model behind `.rdw.s.msg`; writing it REPAINTS that surface and with it
# destroys the user's live selection.  MEASURED before this proc existed: the
# user selects the settings-file path in the status line, presses Ctrl-C, and
# the path vanishes under their own selection.
#
# So when the copy's source IS that entry the window says nothing and leaves
# the line alone.  A receipt is worth less than the text it is a receipt for,
# and the still-standing highlight is the receipt: the selection survives, a
# second Ctrl-C works, and the path is still on screen to be read.  Driver
# decision, filed as a rule debt so the user can overturn it.
#
# Refusals are NOT routed through here and speak unconditionally: a refusal
# from that entry means it held nothing but blank space, so there is nothing
# left to destroy, and a silent refusal is CP5's own defect.
proc rdw::_copy_report {from msg} {
    if {$from eq {.rdw.s.msg}} { return {} }
    rdw::status $msg
    return {}
}

# THE ONE COPY, AND IT SERVES BOTH DOORS.  The chord (rdw::build) and the
# right-click menu (rdw::popup_menu) call this proc and nothing else, so the
# guard below cannot be true of one door and false of the other -- two
# implementations of "copy the selection" is exactly how a window ends up
# wiping the clipboard through the menu after the keyboard path was fixed.
proc rdw::copy {} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    # THREE PLACES A SELECTION CAN BE, AND THE ORDER IS THE WHOLE DECISION.
    #
    #   1. the pane's own live `sel` -- the freshest answer there is, and the
    #      one the user may have moved with the mouse a microsecond ago;
    #   2. ANOTHER WIDGET OF THIS TOPLEVEL, which today means the status entry
    #      and the settings-file path item B5 writes into it.  Issue 1344,
    #      defect b: a selection made there used to be scored a foreign theft,
    #      so the stale mirror was kept and Ctrl-C handed the user the pane's
    #      first line instead of the path they had highlighted;
    #   3. the mirror, which is what survives a genuine theft by another X
    #      client (rdw::_selection_changed) and is therefore the STALEST of the
    #      three -- it must come last, and rdw::_selection_span refuses it
    #      outright while a sibling holds the selection.
    #
    # Legs 1 and 3 are rdw::_selection_span, which is why leg 2 is asked in
    # between rather than after: a span from the mirror is not evidence about a
    # selection that is standing somewhere else right now.
    #
    # ⚠ AND ONE TAIL, NOT A SECOND COPY FOR THE SECOND SOURCE.  Every leg below
    # only decides `from` and `txt`; the guard, the clipboard write and the
    # sentence are written once, underneath.  A `_copy_sibling` proc of its own
    # would be the second implementation this comment block opens by warning
    # about, with the whitespace guard on one side of it only.
    set from .rdw.p.t
    set txt {}
    set span [rdw::_selection_span]
    if {[llength $span] == 2} {
        if {[catch {.rdw.p.t get [lindex $span 0] [lindex $span 1]} txt]} {
            rdw::status "The selection could not be read ([rdw::_oneline $txt]), so the clipboard was left alone."
            return {}
        }
    } else {
        set sib [rdw::_sibling_selection]
        if {[llength $sib] != 2} {
            # ⚠ DECIDE FIRST, WRITE SECOND.  `clipboard clear` here -- DD-5's
            # own order -- would destroy the clipboard of a user who pressed
            # Ctrl-C in the wrong window, and they would never learn why.
            rdw::status {Nothing is selected, so the clipboard was left alone. Drag over the lines you want (or right-click for Select All) and press Ctrl-C again.}
            return {}
        }
        set from [lindex $sib 0]
        set txt  [lindex $sib 1]
    }
    if {![rdw::_worth_copying $txt]} {
        rdw::status {There is nothing but blank space in the selection, so the clipboard was left alone.}
        return {}
    }
    catch {clipboard clear -displayof .rdw.p.t}
    if {[catch {clipboard append -displayof .rdw.p.t -- $txt} e]} {
        rdw::status "The clipboard refused the selection ([rdw::_oneline $e])."
        return {}
    }
    # The pane is -wrap word and the long sentences really do wrap, so the
    # count the user is told is the count of LOGICAL lines -- which is the
    # shape that will land in their document.  Saying "3 lines" for a paste
    # that arrives as 5 display rows would be the window lying about its one
    # deliverable.
    set n [rdw::_copy_lines $txt]
    rdw::_copy_report $from "Copied $n [expr {$n == 1 ? {line} : {lines}}], [string length $txt] characters, to the clipboard."
    return {}
}

# Select the whole window.  The other half of DD-5's keyboard-free door: a user
# who wants the entire dump should not have to drag across a scrolling pane.
proc rdw::select_all {} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    # ⚠ `end - 1c`, NEVER `end`, AND THAT ONE CHARACTER IS ISSUE 1344 DEFECT a.
    # A Tk text widget always holds a mandatory trailing newline, so on an
    # EMPTY pane `tag add sel 1.0 end` is the range {1.0 2.0} -- a real,
    # two-element range over a character the user never put there.  The
    # `llength $r < 2` guard below therefore never fired on the one window it
    # exists for, rdw::copy found a one-character span that its own `$txt eq
    # {}` test could not refuse, and three clicks in a freshly opened, empty
    # Results Display Window replaced the user's clipboard with a newline.
    # MEASURED identically on :99 and on the user's VcXsrv before this line.
    #
    # `end - 1c` collapses that range to nothing on an empty pane, so the guard
    # fires, and on a populated one it drops the same phantom newline off the
    # end of the copy -- which is also what makes the two sentences agree about
    # how many lines there are.
    catch {.rdw.p.t tag add sel 1.0 {end - 1c}}
    set r {}
    catch {.rdw.p.t tag ranges sel} r
    set txt {}
    if {[llength $r] >= 2} {
        catch {.rdw.p.t get [lindex $r 0] [lindex $r end]} txt
    }
    # AND THE SAME "WORTH COPYING" TEST rdw::copy USES, for the same reason and
    # from the same proc: a pane holding nothing but blank space is a pane with
    # nothing in it to select, whatever the index arithmetic says.
    if {![rdw::_worth_copying $txt]} {
        catch {.rdw.p.t tag remove sel 1.0 end}
        rdw::status {There is nothing in the window to select yet.}
        return {}
    }
    # ONE COUNTER, THE SAME STRING (issue 1344 defect d).  This used to be the
    # LINE NUMBER of `end - 1c` while rdw::copy counted `split $txt` elements,
    # so the window said "Selected the whole window, 1 line" and then "Copied 2
    # lines, 1 characters" about one and the same content.
    set n [rdw::_copy_lines $txt]
    rdw::status "Selected the whole window, $n [expr {$n == 1 ? {line} : {lines}}]. Press Ctrl-C, or right-click Copy, to put it on the clipboard."
    return {}
}

# RULING DD-5's KEYBOARD-FREE DOOR.  Built once and kept: it is a child of
# .rdw, so rdw::close destroys it with the window and a reopened window builds
# a fresh one.
#
# ⚠ `::menu`, WITH THE GLOBAL QUALIFIER, for rdw::build's own reason -- an
# unqualified widget command inside this namespace is one same-named proc away
# from a `wrong # args` raised inside a Button-3 handler, which Tk sends to
# bgerror, which pops a modal dialog nobody clicks.
#
# ⚠ `Copy` IS THE FIRST ENTRY AND NOTHING ELSE MAY MATCH `*copy*` ABOVE IT --
# row CP4 finds the entry by label, and so will the next reader.  The
# accelerator names the chord that really exists; `Select All` deliberately
# carries none, because Tk's Text class already spends <Control-Key-a> on
# beginning-of-line and an accelerator that does nothing is a lie on screen.
proc rdw::popup_menu {rootx rooty} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw]} { return {} }
    if {![winfo exists .rdw.pop]} {
        if {[catch {::menu .rdw.pop -tearoff 0 -takefocus 0}]} { return {} }
        .rdw.pop add command -label {Copy} -accelerator {Ctrl+C} -command rdw::copy
        .rdw.pop add command -label {Select All} -command rdw::select_all
        catch {
            .rdw.pop configure -background [rdw::color panel] \
                -foreground [rdw::color fieldfg] \
                -activebackground [rdw::color selectbg] \
                -activeforeground [rdw::color selectfg]
        }
    }
    catch {tk_popup .rdw.pop $rootx $rooty}
    return {}
}

# ARM THE EXTEND.  Called from rdw::pane_click, which the widget tag runs
# BEFORE the Text class binding -- the one moment at which the press can still
# be compared against the selection the class binding is about to delete.
#
# ⚠ THE PRESS MUST LAND INSIDE THE STANDING SELECTION, AND THAT TEST IS THE
# WHOLE FENCE.  An extend that extends unconditionally is the obvious over-fix
# and it is worse than the bug: the second selection would grow out of the
# first for ever and the user could never make a small one again.  Row CP7 of
# the keys suite presses OUTSIDE and requires a FRESH selection; rows CP6 and
# CP7 together are what pins this to "inside".
proc rdw::_arm_extend {x y} {
    variable dragfrom
    set dragfrom {}
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    set r {}
    if {[catch {.rdw.p.t tag ranges sel} r]} { return {} }
    if {[llength $r] < 2} { return {} }
    set first [lindex $r 0]
    set last [lindex $r end]
    set ix {}
    if {[catch {.rdw.p.t index @$x,$y} ix]} { return {} }
    set inside 0
    if {[catch {expr {[.rdw.p.t compare $ix >= $first] \
                      && [.rdw.p.t compare $ix <= $last]}} inside]} { return {} }
    if {$inside} { set dragfrom [list $first $last] }
    return {}
}

# THE USER'S SECOND SENTENCE: double-click a word, LET GO, then press and drag.
#
# ⚠ WHAT TK DOES, MEASURED 5/5 ON THE FIXTURE.  `bind Text <1>` ends in
# `%W tag remove sel 0.0 end` and tk::TextButton1 re-anchors on the press, so
# the second gesture starts a FRESH character run from wherever it landed: a
# double-click on `complete` at 3.6-3.14 followed by a press at 3.10 and a drag
# to 3.40 answers 3.10-3.40 -- the word the user double-clicked, cut in half.
# The gesture that DOES work is holding the second click down (Tk's own
# word-wise extension), and so does a shift-click, which is exactly why the
# user saw it work "one time": their hand sometimes held the second click.
#
# ⚠ AND THE REPAIR IS A UNION AFTER THE FACT, NOT A `break` BEFORE IT.  The
# alternative is to stop the class binding on the press and re-anchor by hand,
# which means writing `tk::Priv(selectMode)` and the widget's private anchor
# mark from this file -- Tk internals, re-derived, in the one binding whose
# comment in rdw::build already records what breaking that class binding costs.
# Unioning the drag's own answer with the span the press landed in needs no
# internals at all, keeps every gesture Tk already gets right (row CP7 legs 1-3
# are unchanged code paths), and degrades correctly: with `dragfrom` empty this
# proc is a no-op and the pane behaves exactly as it does today.
#
# It restores the span even when the drag has not yet moved far enough for
# tk::TextSelectTo to re-tag anything, which is what keeps a press-and-tiny-
# drag inside a selection from silently emptying it.
proc rdw::pane_drag {w} {
    variable dragfrom
    if {$w ne {.rdw.p.t}} { return {} }
    if {[llength $dragfrom] != 2} { return {} }
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    set first [lindex $dragfrom 0]
    set last [lindex $dragfrom 1]
    set r {}
    if {![catch {.rdw.p.t tag ranges sel} r] && [llength $r] >= 2} {
        catch {
            if {[.rdw.p.t compare [lindex $r 0] < $first]} { set first [lindex $r 0] }
            if {[.rdw.p.t compare [lindex $r end] > $last]} { set last [lindex $r end] }
        }
    }
    # ONE range, always: the press landed inside {first last}, so the drag's own
    # answer and the remembered span overlap and their union is contiguous.
    catch {.rdw.p.t tag add sel $first $last}
    return {}
}

# The list identity the greying keys on.  Item B4 owns the keys that select a
# list and MUST drive this setter; a second state variable would be exactly
# the two-builders drift invariant I1 forbids.
proc rdw::set_list {kind} {
    variable listkind
    if {[lsearch -exact {annotation summary all} $kind] < 0} {
        return -code error \
            "rdw::set_list: unknown list '$kind' (annotation, summary or all)"
    }
    set listkind $kind
    rdw::apply_list_state
    return $kind
}

# ⚠ IT WAS `rdw::apply_button_states` AND IT DOES MORE THAN BUTTONS NOW (issue
# 1355).  The name is the point: `rdw::set_list` calls exactly ONE refresher,
# so a key press cannot move the buttons without moving the words -- invariant
# I1, one setter.  A second proc called from `set_list` beside this one would
# be the two-builders drift this file keeps paying for, and a chrome line
# refreshed from anywhere else could disagree with the greying it stands over.
# Row LX5 golds that `set_list` names this proc once and that this proc reaches
# both `rdw::_chrome_line` and `rdw::_title`.
proc rdw::apply_list_state {} {
    variable listkind
    if {![rdw::have_tk]} { return {} }
    if {[winfo exists .rdw]} { catch {wm title .rdw [rdw::_title $listkind]} }
    if {[winfo exists .rdw.hdr]} {
        catch {.rdw.hdr configure -text [rdw::_chrome_line $listkind]}
    }
    ## ⚠ THE ONE TABLE, NOT A SECOND SPELLING OF IT -- ISSUE 1382, invariant
    ## I1.  This loop carried the five ids as LITERALS, three procs away from
    ## `rdw::_buttons`, which is the same two-tables drift `rdw::_buttons`'
    ## own comment was written about; `rdw::_active_buttons` already walks the
    ## table and ignores the label exactly like this.  It is also the proc that
    ## decides the column's two NON-list controls -- `aA` and Close -- are
    ## never re-stated, so both are `normal` on all three identities BY
    ## CONSTRUCTION rather than by a `rdw::button_state` row no caller reads.
    ## Row CB1.
    foreach {id label} [rdw::_buttons] {
        if {![winfo exists .rdw.b.$id]} { continue }
        .rdw.b.$id configure -state [rdw::button_state $id $listkind]
    }
    return {}
}

# ⚠ `rdw::inert` USED TO LIVE HERE AND ITEM B5 DELETED IT.  It said "the
# button column is built but not wired yet (item B5 wires it)", which after B5
# wired it is a lie -- and rows W4b and Q9 golded that lie.  Its OBLIGATION,
# copied from calc::inert (calculator.tcl:607), does not lapse with the
# inertness; it sharpens.  A real, visible, enabled control that DOES something
# and says nothing is exactly as indistinguishable from a broken one, so every
# path out of rdw::button ends in a status line that names the button it came
# from.  See "THE BUTTON COLUMN" at the foot of this file.

# ===========================================================================
# ITEM B4 -- THE KEYS AND THE TWO GRAMMARS
# ===========================================================================
# Ruling D-2, the user's own choice: this window takes bare 1 / 2 / 3 / 4 IN
# THE CADENCE PROFILE ONLY.  Stock xschem keeps `logic_set`.  The four binds
# live in src/cadence_style_rc; everything they do once the event has arrived
# lives here, so the grammar is testable with no Tk at all.
#
#   1 -> annotation list   2 -> summary list   3 -> everything
#   4 -> refresh: keep only the most recent dump
#
# TWO GRAMMARS, THE USER'S OWN WORDS FOR BOTH.
#   NOUN-VERB  exactly one instance selected, press a key, dump it.
#   VERB-NOUN  nothing selected, press a key: enter a COMMAND MODE and click
#              devices.  "This is a command mode, so clicking will not change
#              selected set."  So the click is resolved with the READ-ONLY
#              `xschem instance_at` (findnet.c:553, override_lock=1), which
#              writes neither `.sel` nor `sel_array`.  Its mutating twin was
#              measured at one instance's bbox centre answering `poly 0 2 698`
#              and setting lastsel 1 -- it does not merely select, it selects a
#              DIFFERENT OBJECT than the instance under the cursor.  Do not
#              reach for it here, and row K10 is the structural fence that says
#              so.
#   REFUSE     more than one selected, or a selection that is not an instance:
#              ONE short CIW line, no block, and the selection untouched.
#
# WHERE EACH REFUSAL GOES, AND WHY THE TWO CHANNELS ARE NOT DOUBLE-BOOKED.
# Item B3 already minted five window sentences for "there is nothing to say
# about this device", and PLAN forbids rewording them ad hoc.  The user asked
# for "a short message in CIW if more than one selected or nothing is
# available".  Echoing both says the same fact twice, so the split is:
#   a DEVICE was resolved  -> the WINDOW answers, in B3's locked sentence, and
#                             the CIW stays silent (this includes a device with
#                             no descriptor and a run with no raw);
#   NO device was resolved -> ONE CIW line, no block, no window.
# That is the second half of the user's sentence landing in the window rather
# than the CIW, and it is this item's E question: see the ledger row.
#
# WHAT THE KEYS DO.  Keys 1, 2 and 3 select a list IDENTITY through
# rdw::set_list -- B3's ONE setter -- and, SINCE ISSUE 1300 WAS FIXED (issue
# 1353), keys 1 and 2 also narrow the block's CONTENT to that list through
# `rdw::_narrow_spec` -> `rdw::_list_params` -> `::op_param_lists::effective`,
# which is the tree's one definition of a list.  Key 3 is untouched: it is
# ruling D-5's escape hatch and prints everything the run published.
#
# ⚠ THE PARAGRAPH THAT USED TO STAND HERE SAID THE KEYS "narrow no CONTENT"
# AND THAT ROW S1 FORBIDS NAMING `op_param_lists::` IN THIS FILE.  Both were
# true when B4 wrote them and both are false now -- the fence moved to row BT22
# when item B5 wired the store, and this file names the store's published verbs
# throughout.  A comment that says the opposite of the code beneath it is the
# same defect as a status line citing a fixed issue, one layer down.
#
# ⚠ AND SINCE ISSUE 1355 THE WINDOW SAYS WHICH IDENTITY THE KEYS CHOSE, in
# chrome above the pane and in the title, both refreshed by the ONE proc
# `rdw::set_list` calls.  That is a different fact from the block's own
# past-tense narrowing sentence and it is worded as one; see rdw::_list_name.
#
# Suite: tests/headless/test_rdw_window_1245.tcl section K (both arms) and
# tests/headless/test_rdw_keys_1245.tcl (the binds, the mode, the pick and the
# descend; :99 only, because src/cadence_style_rc cannot be sourced under
# --nogui -- it dies at its first `bind`).

namespace eval rdw {
    # THE COMMAND MODE'S WHOLE STATE.  One array, not a per-session dict:
    # there is one canvas pick mode at a time, exactly as ASE Direct Plot has
    # one `sod(active)`.
    #   canvas     the widget the seize is currently on
    #   prevpress prevrel prevesc prevmotion   the FOUR predecessors, handed
    #              back verbatim.  The fourth is issue 1304: see rdw::_pick_seize.
    #   suspended  set only between cmdmode's suspend and resume arms
    variable pick
    if {![info exists pick]} { array set pick {} }

    # The one-shot flag rdw::_arm_focus_handback sets and rdw::_focus_handback
    # clears.  Namespace state rather than a proc-local, because the arming and
    # the firing are two different events.
    variable focus_pending
    if {![info exists focus_pending]} { set focus_pending 0 }

    # THE HINT'S OWN STATE, ISSUE 1384, and deliberately NOT a field of `pick`:
    # `rdw::pick_end` does `array unset pick`, so a slot recorded in there
    # would be destroyed one statement before the proc that has to blank it.
    #   slot   the `.statusbar.10` we last WROTE, so we can blank that one and
    #          no other
    #   armed  the {sentence width} pair the tooltip decision was last taken on
    #   after  the pump's timer id
    variable hint
    if {![info exists hint]} { array set hint {} }
}

# ---------------------------------------------------------------------------
# THE ONE REFUSAL CHANNEL.  Every "there is no device to ask about" line in
# this item goes through here, so the wording cannot drift between the two
# grammars and a suite can observe the channel by stubbing one command.
# `ciw_echo` (ciw.tcl:502) is defined under --nogui and silently returns when
# there is no CIW widget, so this is safe on every arm.
proc rdw::_ciw {msg} {
    catch {ciw_echo $msg}
    return {}
}

# ---------------------------------------------------------------------------
# WHAT IS SELECTED, IN THE FOUR ANSWERS THE KEYS HAVE TO TELL APART:
#   {none {}}  {one <instname>}  {many {}}  {notinst {}}
#
# ⚠ THE MEASUREMENT IS COPIED FROM cadence::one_instance_selected
# (utils/cadence_nav.tcl:38), NOT ITS CALL.  This file is installed and is
# sourced by stock xschem; utils/cadence_nav.tcl is neither, so calling across
# would make an installed helper depend on a profile file that may not be
# there.  The measurement itself is `xschem get lastsel` and then the row's
# TYPE -- never `llength [xschem selected_set]`, which throws on an instance
# name holding an unbalanced brace (issue 0388) and which filters wires away
# entirely, so a single selected WIRE would read as "nothing selected" and the
# key would arm the pick mode over a live selection.
proc rdw::_selected_instance {} {
    set n 0
    catch {set n [xschem get lastsel]}
    if {![string is integer -strict $n] || $n <= 0} { return [list none {}] }
    if {$n != 1} { return [list many {}] }
    set rows {}
    catch {set rows [xschem selection]}
    set row [lindex $rows 0]
    if {[lindex $row 0] ne {instance}} { return [list notinst {}] }
    set name {}
    catch {set name [xschem getprop instance [lindex $row 1] name]}
    if {[string trim $name] eq {}} { return [list notinst {}] }
    return [list one $name]
}

# ---------------------------------------------------------------------------
# Hand the keyboard back to the design canvas.
#
# ⚠ `-force`, AND THE REASON IS MEASURED IN ASE.  The command mode's Escape
# binding lives on the CANVAS, so a dump that leaves keyboard focus on the
# results toplevel leaves a mode the user cannot escape --
# ase_window.tcl:1905-1911 records the same failure from the other side.  A
# plain `focus $cv` only moves the focus WITHIN a toplevel, so it cannot undo a
# focus that has already crossed to another one; `-force` can.  This is a
# hand-back, not a steal: the key that started this was pressed on the canvas.
#
# It arms nothing itself.  Arming here would re-arm on every hand-back and the
# handler would then chase its own tail.
proc rdw::_focus_canvas {} {
    if {![rdw::have_tk]} { return {} }
    set cv {}
    catch {set cv [xschem get current_win_path]}
    if {$cv eq {} || ![winfo exists $cv]} { return {} }
    catch {focus -force $cv}
    return $cv
}

# ---------------------------------------------------------------------------
# THE HAND-BACK IS EVENT DRIVEN, BECAUSE A SYNCHRONOUS ONE CANNOT WIN THE RACE.
#
# ⚠ MEASURED, :99 under openbox, FIRST open of a session: immediately after
# rdw::_focus_canvas has run, and again after `update idletasks`, the keyboard
# is on the canvas; ONE `update` later it is on .rdw and it stays there.  The
# window manager grants focus to a newly MAPPED toplevel on a MapNotify round
# trip, which arrives after every synchronous call in the dump path has
# returned.  On the SECOND open the same hand-back sticks, because a WM grants
# map-time focus once.  So the first dump of a session -- and only the first --
# used to leave a command mode whose Escape the keyboard could not reach.
#
# ⚠ AND THIS IS WHY B4's OWN ROW V8 PASSED WITH THE RACE LIVE: every row before
# it had already mapped .rdw.  Ordering inside a suite is part of the fixture.
#
# THREE NARROWINGS, EACH ONE A CASE THAT MUST NOT BOUNCE:
#   * ONE SHOT.  The flag is cleared by the first grant it catches, so the
#     user's next click on the window keeps the keyboard.
#   * ONLY WHEN A MAP IS ACTUALLY COMING.  A dump into an already-mapped window
#     arms nothing: there is no grant to catch, and an armed flag left lying
#     around is a bounce waiting to happen.
#   * ONLY WHEN THE KEYBOARD LANDED IN THIS WINDOW.  The decision is WHERE
#     THE KEYBOARD ENDED UP -- `[focus]` -- and not which window named the
#     event.  Issue 1306: deciding on `%W` alone shipped a hand-back that
#     BOUNCED the user's deliberate click into the text pane, which is the one
#     focus this window is entitled to keep and the whole reason the window
#     exists (select a block, copy it into a design-review document).
#
#     ⚠ TWO REAL MECHANISMS PUT `.rdw` IN `%W`, AND ONLY ONE OF THEM IS THE
#     BINDTAGS ONE.  Both measured:
#       - INFERIOR crossing (focus already inside .rdw, moving to .rdw.p.t):
#         Tk delivers FocusIn to .rdw.p and .rdw.p.t only, and this binding
#         fires for them because the toplevel's name is in every child's
#         BINDTAGS.  That is the mechanism the pre-fix comment named, and it
#         is correct as far as it goes.
#       - Crossing from OUTSIDE (.drw -> .rdw.p.t, the WM-less arm): X ALSO
#         delivers a separate FocusIn to `.rdw` ITSELF, detail
#         NotifyNonlinearVirtual, along the ANCESTOR chain.  `%W` is then
#         literally `.rdw` for a click on the pane, so no `%W` test whatever
#         can tell that click from the window manager's map-time grant.
#
#     ⚠ AND THE LANDING TEST USED TO BE `[focus] eq .rdw`, WHICH IS TRUE ONLY
#     UNTIL THE USER'S FIRST CLICK IN THIS WINDOW -- ISSUE 1369, IN THE USER'S
#     OWN WORDS: "another click to look at another device's OP info does not
#     have intended effect - it just focuses the schematic window and doesn't
#     send the OP info for that device to RDW".  TK KEEPS A FOCUS RECORD PER
#     TOPLEVEL: once any window INSIDE `.rdw` has held the Tk focus, every
#     later grant to this toplevel is resolved by Tk to THAT CHILD, and the
#     toplevel sees the grant as a FocusIn with detail NotifyVirtual while
#     `[focus]` already reads the child.  MEASURED on :99 under openbox, one
#     toplevel with one `-state disabled` text pane in it, the keyboard parked
#     in another window before each re-map:
#         record clean           re-map -> FocusIn .t d=NotifyAncestor, [focus] .t
#         after one pane click   re-map -> FocusIn .t d=NotifyVirtual,  [focus] .t.p
#     ONE ORDINARY GESTURE WRITES THAT RECORD, and it is a gesture this window
#     asks for: `tk::TextButton1` calls `focus $w` UNCONDITIONALLY
#     (/usr/share/tcltk/tk8.6/text.tcl:579), unlike `tk::EntryButton1`, which
#     skips a `disabled` widget (entry.tcl:356).  So one Button-1 in
#     `.rdw.p.t` -- or in `.rdw.s.msg`, `-takefocus 0` and all -- is enough,
#     and from that click on the equality never fired again: the one-shot
#     stayed armed for ever and this window kept the keyboard after every
#     dump.  The record is freed only by `rdw::close`'s `destroy`, which is
#     why closing and reopening the window used to "fix" it for one click.
#     The question is therefore not "did the keyboard land ON the toplevel"
#     but "did it land IN this window", and `winfo toplevel` is what asks it.
#
#     ⚠ AND THE OBVIOUS GLOB IS STILL WRONG.  `[string match .rdw* [focus]]`
#     -- the line issue 1306's own recommended fix prints -- was refuted there
#     because it matches the DESCENDANT `.rdw.p.t` (measured 3/3 under a WM and
#     3/3 WM-less), and it stays refuted here for a second reason: it also
#     matches a SIBLING toplevel named `.rdwfoo`, because it asks a question
#     about a STRING where this one is about the widget tree.  Row K16 of the
#     window suite keeps `string match` out of this proc so nobody
#     reintroduces it as a simplification.
#
# THE DELIBERATE CLICK IS NOT DECIDED BY THE LANDING AT ALL ANY MORE -- IT IS
# DISARMED BEFORE IT LANDS.  Once the landing test asks "in this window", a
# grant re-routed to `.rdw.p.t` and the user's own click into `.rdw.p.t` look
# identical at the FocusIn, so the discriminator moves to the gesture:
# `rdw::_focus_click`, bound to `<ButtonPress>` on the toplevel tag in
# rdw::build, spends the one-shot the moment a press arrives anywhere in this
# window.  BOTH ORDERS MEASURED, and they are not the same order:
#   * TK'S OWN PATH -- a `focus` call, which is what `event generate` produces
#     and what a WM-less server leaves Tk to do: the press bindings run
#     SYNCHRONOUSLY inside the press and the FocusIn Tk queues for `.rdw` is
#     processed after them, so the disarm wins and the pane keeps the keyboard.
#     Rows F3 and F4 of the keys suite are that fence.
#   * A REAL CLICK-TO-FOCUS WINDOW MANAGER -- openbox on :99, driven through
#     XTEST so the WM's own passive grab is really involved: the WM sets the
#     input focus FIRST and REPLAYS the press, so the FocusIn arrives BEFORE
#     the ButtonPress and the hand-back does fire.  The click still wins,
#     because `tk::TextButton1`'s own `focus $w` then takes the keyboard
#     straight back -- measured with the one-shot armed, deliberate click on
#     the pane: `[focus]` ends on the pane, with the press disarm and without
#     it.  So the disarm is what protects the Tk-side order, and the class
#     binding is what protects the WM-side one.
# That also deletes the wart the previous revision recorded here: a flag left
# armed because no grant ever came no longer bounces the user's next click.
#
# ⚠ `remapping` IS THE SECOND NARROWING'S ESCAPE HATCH, NOT A HOLE IN IT
# (issue 1340).  "Only when a map is actually coming" is a statement about the
# window, and item R4 made it false: a dump into an ALREADY-MAPPED window now
# re-maps it (rdw::_raise), so a grant IS coming and declining to arm would
# leave the keyboard in this window -- the one thing the user forbade.  The
# caller says so explicitly rather than this proc guessing, because every
# other caller's window really is either absent or unmapped and their
# behaviour must not move.
proc rdw::_arm_focus_handback {{remapping 0}} {
    variable focus_pending
    if {![rdw::have_tk]} { return 0 }
    if {!$remapping && [winfo exists .rdw] && [winfo ismapped .rdw]} { return 0 }
    set focus_pending 1
    return 1
}

proc rdw::_focus_handback {{w {}}} {
    variable focus_pending
    if {![info exists focus_pending] || !$focus_pending} { return 0 }
    ## %W is a cheap NECESSARY-but-not-sufficient first cut: it rejects the two
    ## inferior child events without paying for a `focus` call.  It is NOT the
    ## decision -- see the ancestor chain above.
    if {$w ne {} && $w ne {.rdw}} { return 0 }
    ## THE DECISION.  Strictly BELOW the focus_pending early return, because
    ## --nogui has no `focus` command at all and this proc survives headless
    ## only by returning before it gets here.
    ##
    ## ⚠ `winfo toplevel`, AND NEITHER AN EQUALITY NOR A GLOB (issue 1369):
    ## after one click anywhere in this window Tk resolves every later grant to
    ## the child that click focused, so the keyboard lands IN the window
    ## without ever landing ON it.  `winfo exists` first, because `[focus]` is
    ## the empty string when no window of this application has the keyboard and
    ## `winfo toplevel` raises on it.
    set land {} ; catch {set land [focus]}
    if {$land eq {} || ![winfo exists $land]} { return 0 }
    set top {} ; catch {set top [winfo toplevel $land]}
    if {$top ne {.rdw}} { return 0 }
    set focus_pending 0
    rdw::_focus_canvas
    return 1
}

# THE GESTURE THE LANDING TEST CAN NO LONGER TELL FROM THE WINDOW MANAGER'S
# GRANT -- AND THE REASON IT NO LONGER HAS TO.  A press anywhere in this window
# means the user came here on purpose, so it spends the pending hand-back
# without moving the keyboard.  Bound to `<ButtonPress>` on the TOPLEVEL tag,
# which is in every child's bindtags, so one binding covers the pane, the
# status surface, the five list actions, the `aA` button, the Close button
# (issue 1382) and the frame.
#
# ⚠ WITH EXACTLY ONE EXCEPTION, AND IT CALLS THIS PROC BY NAME.  The `aA`
# button's `<Control-Button-1>` script ends in `break` -- it has to, or
# `tk::ButtonUp` fires the plain arm on top of the Ctrl one -- and a `break` in
# a WIDGET tag's script stops the `.rdw` tag as well as `Button`.  MEASURED
# before it was repaired: a real Ctrl+click on `aA` was the one gesture in this
# window that left `rdw::focus_pending` at 1.  That binding therefore calls
# `rdw::_focus_click %W` itself (rdw::build, issue 1368); row FZ14 asserts the
# two arms of that button leave the one-shot in the same state.
#
# ⚠ IT MUST NOT `break` AND MUST NOT MOVE THE FOCUS.  The Text class binding
# that runs after it sets the insert mark and the selection anchor that item
# R3 (issues 1339 and 1344) depends on: the record pollution above is cured by
# deciding correctly, never by disarming Tk.
proc rdw::_focus_click {{w {}}} {
    variable focus_pending
    set focus_pending 0
    return 0
}

# ---------------------------------------------------------------------------
# NOUN-VERB.  Open the window FIRST and dump second: rdw::render_pane no-ops
# when .rdw.p.t does not exist, so a key that dumped without opening would put
# the block in the store and NOTHING on screen.
#
# ⚠ AND THAT ORDER WAS UNFENCED UNTIL NOW.  Deleting the open reds no row that
# reads ::rdw::blocks, which is every dump row in both suites -- the store is
# filled either way and only the SCREEN is empty.  Row F2 of the keys suite
# reads `.rdw.p.t get 1.0 end` for exactly that reason, and row K15 of the
# window suite fences the order structurally on both arms.
proc rdw::show {instname} {
    rdw::_arm_focus_handback
    rdw::open
    set blk [rdw::dump $instname]
    rdw::_focus_canvas
    return $blk
}

# ---------------------------------------------------------------------------
# KEY 4.  Trim the store to the most recent block.
#
# ⚠ WHICH END IS NEWEST IS ASKED OF rdw::_insert_index, THE SAME ACCESSOR
# rdw::push BRANCHES ON.  A hard-coded `lrange $blocks 0 0` is right today and
# silently keeps the OLDEST block the day the accessor is flipped -- exactly
# the gap issue 1283 filed against row Q1b.  Invariant I1: one definition of
# "newest", several consumers.
#
# It always NAMES what it did in the status line, empty store included: a
# control that silently does nothing cannot be told from a broken one
# (calc::inert's own reason, calculator.tcl:607).
proc rdw::keep_latest {} {
    variable blocks
    set n [llength $blocks]
    if {$n > 1} {
        if {[rdw::_insert_index] eq {1.0}} {
            set blocks [lrange $blocks 0 0]
        } else {
            set blocks [lrange $blocks end end]
        }
    }
    rdw::render_pane
    if {$n > 1} {
        rdw::status "Refresh: kept the most recent dump and cleared [expr {$n - 1}] earlier one(s)."
    } elseif {$n == 1} {
        rdw::status {Refresh: the window already shows one dump - there was nothing to clear.}
    } else {
        rdw::status {Refresh: the window is already empty - there was nothing to clear.}
    }
    return {}
}

# ---------------------------------------------------------------------------
# THE DIGIT MAP, IN ONE PLACE (issue 1358).  Two consumers -- `rdw::build`'s
# four toplevel bindings and row KB1's cross-file comparison -- so a reader who
# changes what a digit means changes it here and the suite tells the profile.
proc rdw::_digit_map {} { return {1 annotation 2 summary 3 all 4 refresh} }

# ---------------------------------------------------------------------------
# A DIGIT TYPED INSIDE THE RESULTS WINDOW.  Answers 1 when it acted, 0 when it
# declined, and the binding turns that answer into the `break`, so a declined
# chord is not also swallowed.  See rdw::build for what was measured and which
# alternative was rejected.
proc rdw::_digit {kind state} {
    if {[expr {$state & 0x4c}]} { return 0 }
    rdw::key $kind
    return 1
}

# ---------------------------------------------------------------------------
# THE KEY ITSELF.  `kind` is annotation | summary | all | refresh.
proc rdw::key {kind} {
    if {$kind eq {refresh}} {
        rdw::_arm_focus_handback
        rdw::open
        rdw::keep_latest
        rdw::_focus_canvas
        return {}
    }
    ## ⚠ THE SELECTION IS RESOLVED BEFORE ANY STATE MOVES, AND THAT ORDER IS
    ## THE FIX.  B4 set the list identity first and refused second, so a
    ## refused key still re-labelled the window and re-greyed the whole button
    ## column with a list the user never got -- a visible state change reporting
    ## a command that did not happen.  A refusal must change nothing: no list,
    ## no buttons, no block, no selection.  Row K12 of the window suite holds
    ## it on both arms.
    lassign [rdw::_selected_instance] what name
    if {$what eq {many}} {
        return [rdw::_ciw {Results window: more than one object is selected - select exactly one device instance, or select nothing at all and press the key again to pick devices by clicking.}]
    }
    if {$what ne {one} && $what ne {none}} {
        return [rdw::_ciw {Results window: the selected object is not a device instance - select one instance, or select nothing at all and press the key again to pick devices by clicking.}]
    }
    ## B3's ONE list-identity setter.  A second state variable here would be
    ## the drift invariant I1 forbids, and the button greying reads this one.
    ## An unknown list name is therefore reported by the setter that owns the
    ## names, not by a second validator living here.
    if {[catch {rdw::set_list $kind} e]} {
        return [rdw::_ciw "Results window: $e"]
    }
    if {$what eq {one}} {
        rdw::show $name
    } else {
        rdw::pick_start
    }
    return {}
}

# ---------------------------------------------------------------------------
# THE PICK'S TWO NAMED READERS.  Both exist as named callees rather than
# inline calls so that a sabotage variant has something to neutralise and so
# that row K10 can fence WHICH verb the canvas is read through.

# ⚠ THE CLICK BOX IS A CACHE, AND THREE MEASURED OPERATIONS MOVE IT WITHOUT
# REFRESHING IT.  find_closest_element() gates candidates on the CACHED
# inst[i].x1..y2 (findnet.c:461) and nothing recomputes that cache except a
# symbol_bbox() call.  Item A6 closed every symbol_bbox() door from inside the
# callee (select.c:723), which does not help when nothing calls it:
#   * issue 1266 -- `xschem annotate_op` and `xschem raw clear` move the gate's
#     answer while calling symbol_bbox() NOT AT ALL.  Driven both directions: a
#     click lands on blank canvas one way and misses visible text the other.
#   * issue 1260 -- `xschem setprop instance` and `xschem move_instance
#     ... nodraw` still write the click box from a stale gate.
#   * item A3 -- with the declutter on, a device's with-text box SHRINKS to
#     what is still drawn, so a fixture written against pre-A3 coordinates
#     misses.
# So the gate is refreshed before EVERY pick, not once at mode entry: the mode
# seizes Button-1, the lone release, Escape and the Button-1 drag and nothing
# else, so 6 / Ctrl-6 / Ctrl-Alt-6 and any annotate_op still move the gate
# WHILE the mode is live, and a first-pick-only refresh is stale by the second
# click.  Rows P1 and P2 are those two cases.
proc rdw::_refresh_pick_gate {} {
    catch {xschem update_all_sym_bboxes}
    return {}
}

# THE READ-ONLY COORDINATE PICK.  Answers an instance name or the empty string
# and changes nothing at all -- no selection, no highlight, no modify flag.
proc rdw::_pick_at {x y} {
    set r {}
    catch {set r [xschem instance_at $x $y]}
    return $r
}

# ===========================================================================
# THE SHEET'S OWN HINT FOR THE PICK MODE -- ISSUE 1384
# ===========================================================================
# THE USER'S OWN WORDS: "Add status message in status bar of schematic window
# for the three RDW print modes 1,2,3 key ... status bar should suggest 'Click
# on instance for annotation/summary/all OP info in Results Display Window'".
#
# ⚠ THE GATE IS COMMAND-MODE ENTRY, AND IT IS THE USER'S OWN RESTATEMENT
# (2026-09-07, when they were asked whether to gate on the verb-noun
# interface and declined both options): "If an instance is selected and user
# presses 1/2/3, only the selected instance is processed.  One does not enter
# command mode in this case.  If more than one selected, issue a warning in the
# CIW and refuse."  So the hint belongs to `rdw::key`'s `none` branch and to
# nothing else, and it does NOT read `intuitive_interface` -- the pick mode is
# identical in both grammars and a hint appearing in only one would itself be
# the surprise.  DRIVEN AT HEAD before a line of this was written, on
# cmos_inv.sch (probe, 2026-09-08), and all three branches already behaved
# exactly as the sentence describes:
#     one     M1 selected  -> pick_running 0, canvas NOT seized, one block
#                             headed `M1:/`, `xschem get lastsel` still 1,
#                             CIW silent
#     many    M1+M2        -> CIW warns, and NOTHING moved: no block, no
#                             window, `::rdw::listkind` still `summary`
#     notinst a wire       -> its own CIW line, same nothing
#     none    empty        -> pick_running 1, canvas seized, CIW prompt
# No defect; the hint is an addition, not a repair.
#
# ---------------------------------------------------------------------------
# WHICH SLOT, AND THE MEASUREMENT THAT DECIDED IT
# ---------------------------------------------------------------------------
# `.statusbar.10`, xschem's own mode-prompt label -- the one that already says
# `DRAW WIRE!` and `HIGHLIGHT NET! (click a net or label, ESC to end)`
# (callback.c:9902-9914).  The same shape of message, in the same slot.
#
# ⚠ `.statusbar.1`, THE WIDE ONE, WAS MEASURED AND REFUSED.  It is C's
# `statusmsg()` field (scheduler.c:65) and it has a writer that runs on EVERY
# event -- callback.c:10177's `mouse = ... - selected: N path: ...` readout,
# which is guarded only by an 8-pixel test and not by `ui_state`.  MEASURED on
# :99 with a pick live and `ui_state` 0: the sentence written into
# `.statusbar.1` was gone after ONE hover motion, replaced by the readout, and
# a selection change replaced it with select.c's `n= x= y= w= h=` info line.
# That is exactly what actions.c:5985 documents, and its remedy --
# `statusmsg_hold()` -- buys only STATUSMSG_HOLD_MS = 5000 ms
# (scheduler.c:70), a fixed deadline that says nothing about how long the user
# takes to find the device.  A pick mode outlives it, and the field it would
# be evicting is the coordinate readout the user is using to aim.
#
# ⚠ AND `.statusbar.10` IS BLANKED, NOT FOUGHT OVER, WHICH IS THE DIFFERENCE.
# `update_statusbar()` (callback.c:9860) resets it to `{ }` whenever no C
# ui_state draw/hilight bit is set, on every canvas event -- and this mode is
# pure Tcl, so no bit is ever set.  MEASURED: one hover blanked it too.
#
# ⚠ AND A PERIODIC RE-ASSERT IS NOT AN ANSWER TO THAT, WHICH IS WHAT THE FIRST
# SPELLING OF THIS FEATURE GOT WRONG.  `ase::ui::sod_prompt_pump`
# (ase_window.tcl:1880) ships an 80 ms timer for the same class of Tcl-level
# canvas mode and claims it costs "at most a sub-frame flicker"; this file
# copied the number AND the claim.  DRIVEN: the sentence was on screen 16-40%
# of the time while the pointer moved -- see `rdw::hint_period` for the table.
# The answer that works is a private BINDING TAG on the canvas
# (`rdw::_hint_attach`), which re-asserts inside the same binding invocation C
# blanked in, before the geometry manager has run; the 80 ms timer stays as the
# backstop for the sequences the seize `break`s and for an exit nobody added a
# door to.
# COST, STATED: a C draw mode armed DURING a pick (`w` still reaches C, only
# the click is seized) would have its own `DRAW WIRE!` overwritten -- now
# immediately rather than within 80 ms.  Unreachable by any useful gesture --
# the press that would draw the wire is the press the seize eats -- and the
# alternative, a C ui_state bit, is a change to the engine for a Tcl-only mode.
#
# ⚠ AND THERE IS A SECOND Tcl WRITER OF THIS SLOT, WHICH THIS MODE NOW BEATS.
# `ase::ui::sod_prompt_pump` writes the SAME `.statusbar.10` on its own 80 ms
# timer whenever select-on-design is armed, and neither pump reads the other.
# Both modes also seize `<ButtonPress-1>` on the same canvas, last arm winning
# -- so arming select-on-design and then pressing 1/2/3 with nothing selected
# leaves ASE's prompt on the label while an RDW click is what a press will
# actually do.  The label was LYING about the mode.  With the synchronous door
# this hint wins the label as decisively as the seize wins the click, so the
# two now agree.  That is an improvement and not an arbitration: the real
# defect is two Tcl command modes seizing one canvas with nobody deciding, and
# it is filed as issue 1387 against the seize, not against this label.
#
# ⚠ THE COST THAT IS REAL, AND IT CHANGES SHAPE WITH THE WINDOW'S WIDTH.  The
# sentence wants 471 px (467 of text plus the label's 4 px of trim).  MEASURED
# on :99, `.statusbar`'s children packed `-side left`:
#     main window 1110 px  the slot gets all 471, and `.statusbar.1` -- the
#                          coordinate readout -- pays for it, 266 -> 218 px
#     main window  700 px  the slot is CLIPPED to 356 and `.statusbar.1` keeps
#                          its 266: Tk shrinks the over-wide label rather than
#                          starving the one packed `-fill x` after it
# `HIGHLIGHT NET! (click a net or label, ESC to end) ` wants 350 px and does the
# same thing three quarters as hard.  Either way the cost lasts exactly as long
# as the mode.
#
# ⚠ THAT COST IS A STEP, AND IT USED TO BE A 12 Hz OSCILLATION.  Because the
# label is packed with no `-fill x` its width follows its TEXT, so while the
# periodic re-assert was the only door the slot swung 8 <-> 471 px and dragged
# `.statusbar.1` with it, 218 <-> 275, for as long as the pointer moved.  The
# synchronous door removes that: the blank never survives to a relayout, so the
# eviction is paid once when the mode arms and given back once when it ends.
#
# ⚠ AND "THE SHIPPED WIDTH" IS NOT A CONSTANT -- IT COMES OUT OF THE USER'S
# `~/.xschem/geometry`, PER SCHEMATIC FILE (`set_geom`, xschem.tcl:16108), and
# EVERY xschem exit writes it back (`Tcl_CreateExitHandler` -> `xwin_exit` ->
# `store_geom`, xinit.c:3199 and :1194).  So no row about this label may spell a
# pixel constant: it must set the geometry it needs and assert it.  Issue 1385
# is what that coupling already costs a row of the keys suite.
#
# ---------------------------------------------------------------------------
# THE TOOLTIP FOR THE OVERFLOW -- the second half of the user's request
# ---------------------------------------------------------------------------
# "if since *that* much space may not be available on the status bar, if user
# hovers on the visible portion of the message in the status bar, can we do a
# tooltip that displays the rest?"  Doable, through `balloon` (xschem.tcl) and
# the two helpers issue 1384 added beside it -- `balloon_clipped` arms a tip
# ONLY when `font measure` overflows the label's own width, and `balloon_off`
# takes it back.  MEASURED on :99 at 1920x1080, sweeping the main window's width
# with the annotation sentence (467 px) on the label: at 1400 / 1110 / 1000 /
# 900 / 850 / 820 / 815 px the slot stays 471 px and NO tip is armed; at 800 it
# is 456, at 750 406, at 700 356, at 600 256, and from 800 px down the tip is
# armed.  The threshold is between 800 and 815 px of main window.  At the
# 700x761 this machine restores for `cmos_inv.sch` the tip IS armed, and the
# user really does read the rest of their own sentence in a tooltip -- which is
# the case they anticipated when they asked for one.
#
# ⚠ THE TIP CARRIES THE WHOLE SENTENCE, NOT "THE REST".  Rendering only the
# clipped tail needs the exact clip column, which is a font metric the label
# does not publish, and a tail read out of context ("...OP info in Results
# Display Window") is worse than the sentence.  Unratified -- rule debt 1384.
#
# ⚠ AND ARMING IT IS NOT SHOWING IT.  THE FIRST SPELLING OF THIS FEATURE ARMED
# A TIP THAT COULD NOT BE REACHED BY THE ONLY GESTURE THAT REACHES IT, and
# every row was green: the arm, the string, the disarm and the predicate were
# all fenced, and the one row that claimed to render "through the real <Enter>
# and the real balloon_show" called `balloon_show` directly.  MEASURED, 3/3, at
# 700x761 with the mode live: 25 canvas motions, then the pointer warped on to
# the label, then 1.65 s -- `winfo containing` said `.statusbar.10`, the
# binding was correct, the sentence was on the label, and NO balloon was ever
# created.  Two causes, both now fixed and both stated where they live:
#   * the slot COLLAPSED to 8 px whenever C blanked it, so the pointer arrived
#     at a label that was 8 px wide and the crossing churn cancelled the
#     pending show (`rdw::hint_period`, and the synchronous door that ends it);
#   * the arm was cached on `winfo width`, so the regrow 8 -> 471 re-armed and
#     `balloon_clipped`'s own `balloon_off` cancelled the `after 1000
#     balloon_show` the <Enter> had queued -- with the pointer already inside,
#     no second <Enter> ever came (`rdw::_hint_sync`, the cache key).
# The lesson is the row's, not the code's: a tooltip row that does not generate
# a real <Enter>, wait the real delay and assert `winfo exists $w.balloon` is a
# row about a BINDING, and a binding is not a tooltip.  Row HT12 drives the
# whole gesture, canvas sweep included, and would have caught both.
#
# ---------------------------------------------------------------------------
# ONE PROC ANSWERS "WHAT DOES THE SLOT SAY" -- invariant I1
# ---------------------------------------------------------------------------
# `rdw::_hint_sync` reads the mode and makes the slot agree; everything else is
# a DOOR on it -- `pick_start` (both of its success paths), `pick_end`,
# `pick_resume` (its rehome and its drop path), the canvas binding tag and the
# backstop timer.  A second proc that decided the text would be this file's
# most-repeated defect.  The mode's exits are therefore covered TWICE on
# purpose: the transition blanks the slot synchronously, and the timer notices
# a mode that vanished by some route nobody added a door to and stops itself
# within 80 ms.  A stale `Click on instance` after the mode has ended is worse
# than no hint at all.
#
# Suite: tests/headless/test_rdw_window_1245.tcl section HT (the sentence and
# the arithmetic on both arms, the slot, the tab, the duty cycle and the whole
# tooltip gesture on :99) and tests/headless/test_rdw_keys_1245.tcl section HP
# (a real key, a real ESC and a real pick, :99 only).

# THE SENTENCE, ONE PER LIST IDENTITY, IN THE USER'S OWN WORDS.
#
# ⚠ THE IDENTITY TOKEN *IS* THE ADJECTIVE, WHICH IS WHY THIS IS A TEMPLATE AND
# NOT A THREE-ARM SWITCH.  `annotation` / `summary` / `all` read correctly in
# the slot the user's own three sentences differ in, and one template cannot
# ship two of the three reworded.  The fence on an unknown identity is
# `rdw::_list_name` -- the proc that already owns which names exist -- so a
# fourth list whose token is not an English adjective fails here loudly (empty
# sentence, no hint) instead of printing `Click on instance for refresh OP
# info`.  `OP` stays uppercase: it is an acronym.
proc rdw::_hint_text {kind} {
    if {[rdw::_list_name $kind] eq {}} { return {} }
    return "Click on instance for $kind OP info in Results Display Window"
}

# HOW OFTEN THE BACKSTOP RUNS.  80 ms is ASE's number (ase_window.tcl:1884),
# taken unchanged so the two Tcl-level canvas modes cannot drift.  A named
# accessor so the two consumers -- the timer and the row that waits for it --
# cannot disagree about the period.
#
# ⚠ BUT ASE'S REASON FOR THAT NUMBER IS FALSE, AND WAS MEASURED FALSE HERE.
# ase_window.tcl:1884 says "~80 ms => a blanking event shows at most a
# sub-frame flicker before the prompt returns", and the first spelling of this
# file quoted it as precedent.  DRIVEN on :99 with a motion timer on `.drw`,
# the slot sampled every 10 ms, 200 samples per cell, hint live throughout:
#     main window   motion every 16 ms    33 ms    50 ms
#     1110x761          18% visible        16%      40%
#     1400x800          17% visible        16%      37%
# It is the PROMPT that shows for a sub-frame, not the blank: C blanks on every
# canvas event and a re-assert three to five times slower than the motion
# stream loses.  Worse, `.statusbar.10` is packed `-side left` with NO `-fill x`
# (xschem.tcl:16834), so its width follows its text -- 8 px blank against
# 471 px with the sentence -- and it was swinging between the two at ~12 Hz,
# dragging `.statusbar.1`, the coordinate readout the user is aiming with,
# between 218 and 275 px.  The whole cost of that is paid while the pointer
# moves over the canvas, which is precisely what the sentence is asking the
# user to do.
#
# SO THE RE-ASSERT IS SYNCHRONOUS (`rdw::_hint_attach`) AND THIS TIMER IS ONLY
# THE BACKSTOP.  It still earns its place -- it covers the seized sequences,
# which `break` before any later binding tag is reached, a canvas event this
# file did not enumerate, and above all a mode that ended by a route nobody
# added a door to -- but it is no longer what puts the sentence on the screen.
proc rdw::hint_period {} { return 80 }

# THE SLOT FOR A CANVAS.  The status bar is built per TOP-LEVEL by
# `build_widgets` (xschem.tcl:18736) and packed by `pack_widgets` (:16834), so
# the slot is the one belonging to the canvas's own top-level: `.drw` ->
# `.statusbar.10`, `.x1.drw` -> `.x1.statusbar.10`.  It ASKS the widget
# hierarchy, and the string arithmetic is only the fallback for the two cases
# that have no widget to ask -- see below.
#
# ⚠ THE FIRST SPELLING OF THIS COMMENT SAID "the tabbed interface shares one
# [status bar], so this is right for a tab too".  THAT IS BACKWARDS: sharing the
# bar is exactly what makes the arithmetic wrong, because the CANVAS path is not
# shared with it.  MEASURED on :99 with the shipped `tabbed_interface 1` and one
# `xschem schematic_in_new_window force`:
#     xschem get current_win_path    .x1.drw
#     winfo exists .x1.drw           0     <- tabs share the ONE real `.drw`
#     xschem get top_path            {}    <- so C writes `.statusbar.10`
#     the string arithmetic          .x1.statusbar.10   <- does not exist
#
# ⚠ AND `tabbed_interface` IS NOT THE DISCRIMINATOR EITHER.  `xschem
# new_schematic create_window .x1 <sch>` forces a REAL top-level while
# `tabbed_interface` is still 1 (test_multi_window.tcl MW2/MW1b measure exactly
# that, and a forced window and a tab coexist there).  The one fact that
# separates them is whether the canvas path is a Tk widget at all, which is what
# this asks.
#
# ⚠ AND `xschem get top_path` -- what C itself prefixes its own writes with -- IS
# NOT USABLE HERE, THOUGH IT IS THE OBVIOUS FIX.  It is by its own definition
# the CURRENT window's ("get top hier path of current window",
# scheduler.c:5468), not the one this mode was seized on, so a pick live on
# `.x1` while the user works in the main window would have its sentence written
# on the main window's bar.  This proc is called with `pick(canvas)` precisely
# so the hint stays anchored to the mode -- MEASURED end to end with a forced
# `.x1` top-level: `pick(canvas)` `.x1.drw`, slot `.x1.statusbar.10`, the
# sentence on `.x1`'s bar, the main window's bar `{ }` throughout, the binding
# tag on `.x1.drw` only, and both put back by `pick_end`.
#
# ⚠ THE FALLBACK IS FOR TWO CASES AND IS DELIBERATELY NOT CLEVER.  With no Tk at
# all (`--nogui`, where the answer is decorative and the row still checks the
# arithmetic) and with a canvas path that is not a widget, it returns the
# arithmetic answer -- which `rdw::_hint_sync`'s own `winfo exists $slot` then
# drops.  A tab's `.x1.drw` and a DESTROYED window's `.x9.drw` are the same
# shape, so no rule could map the first to the shared bar without also
# redirecting the second there, which would put a live sentence on the wrong
# window.  Refusing both is the only answer that is right twice.
#
# ⚠ AND THE TAB CASE IS UNREACHABLE TODAY FOR A REASON THAT IS ITS OWN DEFECT.
# `rdw::pick_start` asks `winfo exists [xschem get current_win_path]`, gets 0 in
# a tab, and returns 0 -- so 1/2/3 with nothing selected does NOTHING in a tab
# and says nothing, not even in the CIW.  Measured in the same run and filed as
# issue 1387.  Its fix is for the seize to hold the REAL canvas widget rather
# than the logical path, and if it is fixed that way `pick(canvas)` is always a
# widget and this proc is already right with no tab arm at all -- which is the
# reason there is not one.
#
# The computation was `ase::ui::sod_statusbar`'s (ase_window.tcl:1856) and is
# NOT called across to it: that file is a peer this one must load without,
# exactly as `rdw::_selected_instance` refuses to call
# `cadence::one_instance_selected`.  ⚠ THAT PROC STILL HAS THE UNCORRECTED
# ARITHMETIC and is recorded on issue 1387; copying a proc copies its bugs,
# which is the cost this file accepted when it refused the dependency.
proc rdw::_hint_slot {cv} {
    if {$cv eq {}} { return {} }
    if {[rdw::have_tk] && [winfo exists $cv]} {
        set top [winfo toplevel $cv]
        if {$top eq {.}} { set top {} }
        return "$top.statusbar.10"
    }
    regsub {\.drw$} $cv {} top
    return "$top.statusbar.10"
}

# ---------------------------------------------------------------------------
# THE SYNCHRONOUS RE-ASSERT -- A PRIVATE BINDING TAG ON THE CANVAS
# ---------------------------------------------------------------------------
# C blanks the slot at the TOP of `callback()` (callback.c:10093), before it has
# looked at the event, and `.drw`'s own bindings are what call `xschem
# callback`.  A binding tag inserted immediately AFTER the widget's own tag runs
# in the SAME binding invocation, so the blank is undone before control returns
# to the event loop -- and Tk's geometry manager runs at idle, so the blank
# never survives to a relayout at all.  MEASURED with the same probe as the one
# above: 100% visible at every motion rate and every sample, `.statusbar.10` a
# constant 471 px at both window widths, and `.statusbar.1` a constant 218 px at
# 1110x761 and a constant 275 at 1400x800 -- one width each, where before there
# were two.
#
# ⚠ A BINDTAG, NOT `bind $cv <Motion> +...`.  `rdw::_pick_seize` latches four of
# this canvas's own binding scripts VERBATIM and hands them back byte-identical;
# a `+` append is not removable without rewriting a script the seize is holding,
# and row V6 exists precisely to catch a restore that is not byte-identical.  A
# tag is added and removed with ONE `bindtags` write and cannot touch what the
# seize latched.  `bindtags` is per WIDGET, so a second window's canvas gets the
# tag and the main window's does not.
#
# ⚠ THE SEIZED SEQUENCES NEVER REACH THE TAG, AND THAT IS RIGHT.  All four of
# `_pick_seize`'s scripts end in `break`, which stops the remaining binding tags
# for that event -- so a press, a release and a B1-drag are the backstop timer's
# and not this door's.  A press ends in `rdw::show`, which builds a window and
# pumps its own events; re-asserting in the middle of that is the timer's job.
#
# THE EVENT LIST is the high-rate and geometry-changing half of what `.drw`
# actually binds (MEASURED on this tree: `<Button> <ButtonRelease> <Configure>
# <Double-Button-1..3> <Enter> <Expose> <Key> <KeyRelease> <Leave> <Motion>
# <Unmap> <Visibility>`).  The one-at-a-time ones are left to the timer, where
# 80 ms really is the flicker ASE claims it is.
proc rdw::_hint_tag {} { return RdwHintReassert }

proc rdw::_hint_events {} {
    return {<Motion> <Enter> <Leave> <Configure> <Expose> <Visibility> <Key> <KeyRelease>}
}

proc rdw::_hint_attach {cv} {
    if {![rdw::have_tk]} { return 0 }
    if {$cv eq {} || ![winfo exists $cv]} { return 0 }
    set tag [rdw::_hint_tag]
    foreach ev [rdw::_hint_events] {
        if {[bind $tag $ev] eq {}} { bind $tag $ev {rdw::_hint_sync} }
    }
    set tags [bindtags $cv]
    if {[lsearch -exact $tags $tag] >= 0} { return 1 }
    ## AFTER the widget's own tag and before `Frame`/`.`/`all`: C's write has to
    ## have happened already, and nothing further down the list writes this slot.
    set j [lsearch -exact $tags $cv]
    if {$j < 0} { set j 0 }
    bindtags $cv [linsert $tags [expr {$j + 1}] $tag]
    return 1
}

proc rdw::_hint_detach {cv} {
    if {![rdw::have_tk]} { return 0 }
    if {$cv eq {} || ![winfo exists $cv]} { return 0 }
    set tag [rdw::_hint_tag]
    set tags [bindtags $cv]
    set i [lsearch -exact $tags $tag]
    if {$i < 0} { return 0 }
    bindtags $cv [lreplace $tags $i $i]
    return 1
}

# PUT A SLOT BACK EXACTLY AS C LEAVES IT (callback.c:9916), and take the tip
# with it.  The tip goes first: a slot whose text is already blank must not be
# hoverable for one instant longer.
proc rdw::_hint_blank {slot} {
    if {$slot eq {}} { return {} }
    catch {::balloon_off $slot}
    catch {$slot configure -state normal -text { }}
    return {}
}

proc rdw::_hint_stop {} {
    variable hint
    if {[info exists hint(after)]} { catch {after cancel $hint(after)} }
    unset -nocomplain hint(after)
    return {}
}

# THE ONE DEFINITION.  Answers 1 when a hint is owed and is now on the slot,
# 0 when none is owed and nothing of ours is left on screen.
#
# ⚠ IT BLANKS WHAT *WE* LAST WROTE AND NOTHING ELSE.  `hint(slot)` is the
# record, so a mode that was rehomed onto another canvas by a descend
# (`rdw::pick_resume`) does not leave its sentence on the window it came from,
# and a slot we never wrote is never touched -- C owns that label the rest of
# the time.  `hint(cv)` is the same record for the synchronous door: the tag
# comes off the canvas it was put on, whatever the mode did afterwards.
#
# ⚠ THE IDENTITY IS READ FROM `::rdw::listkind`, WHICH IS THIS FILE'S ONE
# ANSWER TO "WHICH LIST IS IN FORCE" (`rdw::apply_list_state` reads it the same
# way for the title and the chrome line).  `rdw::key` sets it through
# `rdw::set_list` BEFORE it branches, so the sentence names the list the press
# actually selected.
proc rdw::_hint_sync {} {
    variable pick
    variable hint
    variable listkind
    if {![rdw::have_tk]} { return 0 }
    set slot {} ; set txt {} ; set cv {}
    if {[rdw::pick_running]} {
        catch {set cv $pick(canvas)}
        catch {set slot [rdw::_hint_slot $cv]}
        set txt [rdw::_hint_text $listkind]
    }
    if {$slot ne {} && ![winfo exists $slot]} { set slot {} }
    if {$slot eq {} || $txt eq {}} { set cv {} }
    if {[info exists hint(cv)] && $hint(cv) ne $cv} {
        rdw::_hint_detach $hint(cv)
        unset -nocomplain hint(cv)
    }
    if {[info exists hint(slot)] && $hint(slot) ne $slot} {
        rdw::_hint_blank $hint(slot)
        unset -nocomplain hint(slot) hint(armed)
    }
    if {$slot eq {} || $txt eq {}} {
        ## ⚠ THIS CLEAR IS REACHED BY A STATE, NOT BY AN EXIT, AND THE ROW THAT
        ## FENCES IT SAYS SO.  On an exit `$slot` is {} and the branch above has
        ## already blanked; the case only this line covers is a LIVE mode whose
        ## `::rdw::listkind` names a list `rdw::_list_name` has no words for --
        ## `hint(slot)` still equals `$slot`, so nothing above fires and without
        ## this the previous list's sentence would stand on the sheet for ever.
        ## An earlier audit neutered this line and the whole suite stayed green;
        ## row HT11 is what makes it a fence.
        if {[info exists hint(slot)]} { rdw::_hint_blank $hint(slot) }
        unset -nocomplain hint(slot) hint(armed)
        rdw::_hint_stop
        return 0
    }
    set hint(slot) $slot
    ## ⚠ ATTACHED UNCONDITIONALLY, NOT ONCE.  `_hint_attach` is idempotent (it
    ## returns early when the tag is already in `bindtags`), and re-asking every
    ## time is the same argument as the `bound` term of the tip cache below: a
    ## tag taken off the canvas by another hand is PUT BACK rather than believed
    ## away, so this proc's contract stays "make the canvas and the slot agree"
    ## and not "remember what I once did".  COST, MEASURED on :99: this whole
    ## proc is ~20 us a call, and a synthetic `.drw` <Motion> delivered
    ## `-when now` costs 73-97 us without the tag and 93-155 us with it -- so a
    ## 60 Hz motion stream buys the synchronous re-assert for about 1.3 ms per
    ## second of moving the mouse.
    if {[rdw::_hint_attach $cv]} { set hint(cv) $cv }
    catch {$slot configure -state active -text $txt}
    ## THE TIP IS RE-DECIDED ONLY WHEN THE ANSWER COULD HAVE MOVED, AND THE KEY
    ## IS THE ANSWER, NOT THE PIXELS.  Three terms and each earns its place:
    ##   the SENTENCE -- `balloon` bakes it into <Enter> at bind time
    ##   the VERDICT  -- `label_clipped`, and NOT `winfo width`.  A re-arm goes
    ##                   through `balloon_clipped`, which begins with
    ##                   `balloon_off`, which CANCELS the
    ##                   `after 1000 balloon_show` a pointer already on the
    ##                   label has queued -- and that pointer never left, so no
    ##                   second <Enter> comes to re-queue it.  A re-decision
    ##                   that changes nothing must therefore not be taken.
    ##                   ⚠ THIS WAS HALF OF WHY THE TOOLTIP WAS UNREACHABLE:
    ##                   the pointer can only arrive at the status bar FROM the
    ##                   canvas, the last canvas event blanked the label to
    ##                   8 px, the re-assert grew it back to 471, the width term
    ##                   moved and the tip died -- identical gesture, 3/3, no
    ##                   balloon.  The synchronous door above removes that
    ##                   particular width change, so EITHER fix alone makes the
    ##                   gesture work (measured, by sabotaging each in turn);
    ##                   this one is kept because a real resize with the pointer
    ##                   resting on a clipped sentence still moves the width
    ##                   without moving the answer.  Row HT15 is its own fence
    ##                   and drives it with the label's `-width` rather than a
    ##                   window manager, which is not obliged to honour a
    ##                   resize.
    ##   whether a tip is ACTUALLY BOUND -- so a binding removed by another hand
    ##                   is put back rather than believed away.  Without it the
    ##                   cache holds a belief the widget contradicts; with it
    ##                   this proc's contract is simply "make the slot agree",
    ##                   which is what every other line of it already says.
    ## ⚠ THE FIRST TICK CAN STILL ARM A TIP THAT THE SECOND TAKES BACK: `winfo
    ## width` reports the geometry pass that has already run, and a slot that
    ## has never held the sentence measures 8 px.  Harmless -- `balloon`'s delay
    ## is 1000 ms and `balloon_off` cancels a pending show -- and it is the
    ## reason no `update` is called from inside a key handler here.
    set bound 0
    catch {set bound [expr {[bind $slot <Enter>] ne {} ? 1 : 0}]}
    set want 0
    catch {set want [::label_clipped $slot $txt]}
    set state [list $txt $want $bound]
    if {![info exists hint(armed)] || $hint(armed) ne $state} {
        set hint(armed) $state
        catch {::balloon_clipped $slot $txt 1}
    }
    return 1
}

# THE BACKSTOP.  Self-cancelling: the instant `_hint_sync` says no hint is
# owed it has already blanked the slot, taken the tag off the canvas and
# stopped the timer, so no exit from the mode can leave this running.
proc rdw::_hint_pump {} {
    variable hint
    unset -nocomplain hint(after)
    if {![rdw::_hint_sync]} { return 0 }
    set hint(after) [after [rdw::hint_period] rdw::_hint_pump]
    return 1
}

proc rdw::_hint_start {} {
    rdw::_hint_stop
    return [rdw::_hint_pump]
}

# ---------------------------------------------------------------------------
# THE SEIZE.  The shape is ase::ui::select_on_design's (ase_window.tcl:1877,
# the latch at :1897-1899):
# latch the predecessors, take Button-1 and Escape, take the lone RELEASE too
# (the press it pairs with was swallowed, so it must not reach C on its own),
# and give the canvas keyboard focus or a real ESC never arrives.
#
# ⚠ IT TAKES A FOURTH SEQUENCE THAT ASE'S DOES NOT, AND THAT IS ISSUE 1304.
# Copying the three-sequence shape leaves C's rubber band with a start and no
# end: a motion with Button1Mask calls select_rect(START,1) + unselect_all(1)
# and sets STARTSELECT (callback.c:7250-7260), and the ONLY thing that
# terminates it is ButtonRelease's select_rect(...,END,-1) (callback.c:9748) --
# which the seized release eats.  Measured on the shipped cmos_inv.sch, an
# 8-step drag from empty canvas with the three-sequence seize live: ui_state
# 24, lastsel 20, twenty objects in `xschem selection`, and all three unchanged
# after the release AND after a real Escape.  The same gesture with no mode
# armed terminates at ui_state 0 with nothing selected.  That is a direct
# violation of the user's own requirement -- "This is a command mode, so
# clicking will not change selected set" -- reached by a one-pixel drift of the
# hand.  So <B1-Motion> is seized too.
#
# ⚠ IT BLINDS C ONLY WHILE BUTTON 1 IS HELD.  C's motion handler also drives
# the crosshair, the hover highlight, the fly-lines and the status line
# (callback.c:7169); those all run on plain <Motion>, which is untouched, so
# the mode still tracks the pointer.  Row V2b's hover leg is that measurement.
# The seize is on the design canvas only and never on `.` -- xschem.tcl's
# tab-swap <B1-Motion> starts on `.tabs.x*` and is unreachable from here.
#
# ⚠ Measured on this tree: `.drw` is a FRAME whose shipped bindings are the
# GENERIC <Button> and <Key>, so all four predecessors are the EMPTY STRING.
# `bind w seq {}` DESTROYS a binding, which is what makes the restore
# byte-identical -- a restore that writes an empty script back would leave an
# empty-but-PRESENT binding that passes a string comparison and fails the
# sequence-list one.  Row V6 holds both legs, and it reads the <B1-Motion> slot
# while the mode is still LIVE, because after the release it is back at its
# predecessor whether the seize ever took it or not.
proc rdw::_pick_seize {cv} {
    variable pick
    set pick(canvas)     $cv
    set pick(prevpress)  [bind $cv <ButtonPress-1>]
    set pick(prevrel)    [bind $cv <ButtonRelease-1>]
    set pick(prevesc)    [bind $cv <Key-Escape>]
    set pick(prevmotion) [bind $cv <B1-Motion>]
    bind $cv <ButtonPress-1>   "[list rdw::pick_click]; break"
    bind $cv <ButtonRelease-1> {break}
    bind $cv <Key-Escape>      "[list rdw::pick_end]; break"
    bind $cv <B1-Motion>       {break}
    catch {focus -force $cv}
    return $cv
}

# Arm the mode.  1 when it is armed (or already was), 0 when it could not be.
#
# ⚠ AN ALREADY-LIVE MODE RE-ARMS IN PLACE AND DOES NOT RELEASE AND RETAKE.
# ASE's select_on_design self-serialises by ENDING the previous mode first
# (ase_window.tcl:1879); copying that here would drop the pick every time the
# user pressed a different list key, releasing and retaking the same seize for
# nothing.  ESC is the only exit -- that is what "this is a command mode"
# means, and it is the user's own phrase.
#
# ⚠ THAT ARGUMENT IS RIGHT FOR A LIVE MODE AND WAS WRONG FOR A SUSPENDED ONE.
# ISSUE 1305, MEASURED: a descend suspends the mode (cmdmode::suspend_all ->
# rdw::pick_suspend, which releases the canvas and sets pick(suspended)); the
# user then presses 1-4 during hi_descend_pick_arm's event-loop wait; pick_start
# falls through the guard above -- correctly, the mode is not live -- and seizes
# the canvas again WITHOUT clearing the flag.  The later cmdmode::resume_all
# then calls rdw::pick_resume, which seizes an ALREADY-SEIZED canvas and latches
# the seize's OWN scripts as the predecessors.  ESC restores them.  Measured
# after ESC: P='rdw::pick_click; break' R='break' E='rdw::pick_end; break'
# M='break' -- a PERMANENT seize, unrecoverable inside the session, in which
# every click dumps and nothing can be selected again.  That is the exact
# inverse of the user's ruling that a command mode must not change the selected
# set.
#
# THE FIX is the one cmdmode ruling D6 already describes -- "exactly the first
# one to arrive wins" (cmdmode.tcl:36-42).  pick_start arriving first
# legitimately wins the latch, so clearing the suspend is PART OF TAKING THE
# CANVAS BACK: the later resume finds nothing suspended and pick_resume's own
# guard returns 0.  The unset sits BELOW the canvas guard on purpose -- a re-arm
# that could not take a canvas must leave the suspend intact for the real
# resume -- and it is the same idiom pick_resume uses twelve lines further down,
# and the one ase::ui::sod_resume uses (ase_window.tcl:2047).
#
# COST, STATED: this re-seizes on the canvas CURRENT AT KEY-PRESS TIME, which
# during a descend's wait is still the PARENT.  Because resume_all's
# pick_resume now returns 0, a descend that lands on a DIFFERENT canvas (new
# window, new tab) leaves the mode live on the OLD one and never rehomes it.
# The rejected alternative that preserved the rehome -- have the suspended arm
# return 1 without seizing -- makes a 1-4 press during the wait silently do
# nothing, which contradicts ruling D-2's premise that those keys are always
# live.  The un-rehomed residue is recorded on issue 1307, whose own subject is
# a command-mode seize arriving on a canvas nobody armed it on.
proc rdw::pick_start {} {
    variable pick
    if {![rdw::have_tk]} { return 0 }
    if {[info exists pick(canvas)] && ![info exists pick(suspended)]} {
        ## ISSUE 1384: AN ALREADY-LIVE MODE STILL RE-STATES THE HINT.  A `2`
        ## pressed while a `1` pick is live re-arms in place (the paragraph
        ## above), and the sentence NAMES the list -- so a re-arm that skipped
        ## this would leave the previous list's sentence on the sheet while
        ## every other surface said `summary`.
        rdw::_hint_start
        return 1
    }
    set cv {}
    catch {set cv [xschem get current_win_path]}
    if {$cv eq {} || ![winfo exists $cv]} { return 0 }
    ## ISSUE 1305: clear the outstanding suspend as part of taking the canvas
    ## back, so resume_all finds nothing to resume.  BELOW the guard above.
    unset -nocomplain pick(suspended)
    rdw::_pick_seize $cv
    rdw::_ciw {Results window: click a device to show its operating-point columns; ESC ends. Clicking does not change the selection.}
    ## ISSUE 1384 -- THE SHEET SAYS IT TOO.  The CIW line above is a different
    ## window; this is the one that is under the user's eyes.
    rdw::_hint_start
    return 1
}

# ONE CLICK.  Coordinates default to the UN-SNAPPED mouse position --
# `xschem get mousex` / `mousey`, scheduler.c:5047 and :5051 -- which is the
# point the cursor is actually on and the pair every C click path reads.
# Defaulting rather than requiring them is what lets a suite drive this proc
# with exact coordinates AND through real events; issue 1303's own acceptance
# is that the DEFAULT path is the one exercised, because that is where the
# defect lived.
#
# ⚠ ISSUE 1303, MEASURED, AND WHY THERE IS NO FALLBACK TO THE GRID PAIR.
# Resolving the click from the grid-snapped position instead names a DIFFERENT
# DEVICE.  On the shipped xschem_library/examples/cmos_inv.sch, one pixel
# apart:
#       175.175 -199.612  ->  M1     the point under the cursor
#       180     -200      ->  R1     that same point snapped to the grid
# Lattice sweep over every instance bbox on that sheet: 23725 points, 1513
# (6.4%) miss the device entirely and 129 (0.5%) resolve to a different device
# -- silently, with nothing on screen saying which happened.  That is invariant
# I3's plausible-wrong-answer failure one object out: a results window headed
# R1 for a click on M1.  So when the un-snapped readers cannot be read this
# proc REFUSES through the one CIW channel and names what it could not read.
# It does NOT fall back to the grid position, because that fallback IS the
# defect, one binary mismatch away.  The grid position remains the right pair
# for PLACING geometry and is used nowhere in this file.
#
# ⚠ AND THE PAIR READ HERE IS THE LAST MOTION'S POINT, NOT THE PRESS'S.  The
# seize `break`s the press before C sees it, and C updates both mouse pairs on
# every event it does see (callback.c:10145).  A real hand always moves the
# pointer onto the device before pressing, so it reads the right point; a
# caller that presses with no preceding motion reads a stale one.  The keys
# suite generates the motion first for exactly this reason.
#
# A MISS IS NOT THE END OF THE COMMAND.  Empty canvas and a wire are the same
# answer here (the reader resolves instances only), and both keep the mode
# live: a mode that ended on a mis-click would be unusable.
proc rdw::pick_click {{x {}} {y {}}} {
    if {$x eq {}} { catch {set x [xschem get mousex]} }
    if {$y eq {}} { catch {set y [xschem get mousey]} }
    if {$x eq {} || $y eq {}} {
        return [rdw::_ciw {Results window: this build cannot report the un-snapped mouse position, so a click cannot be resolved to the device under the cursor - press ESC to leave.}]
    }
    rdw::_refresh_pick_gate
    set inst [rdw::_pick_at $x $y]
    if {[string trim $inst] eq {}} {
        return [rdw::_ciw {Results window: no device under the click - click on a device body, or press ESC to leave.}]
    }
    rdw::show $inst
    return $inst
}

# Hand all FOUR bindings back, verbatim and under catch (the canvas may be
# dead).  ONE proc shared by the end path and the suspend path, exactly as
# ase::ui::sod_release (ase_window.tcl:1948) is, so the two cannot drift --
# which is the whole reason issue 1304's fourth sequence is added here and in
# rdw::_pick_seize and nowhere else.  Row K14 fences the two against each
# other.  Returns 1 only if it released a live mode.
proc rdw::pick_release {} {
    variable pick
    if {![info exists pick(canvas)]} { return 0 }
    set cv $pick(canvas)
    catch {bind $cv <ButtonPress-1>   $pick(prevpress)}
    catch {bind $cv <ButtonRelease-1> $pick(prevrel)}
    catch {bind $cv <Key-Escape>      $pick(prevesc)}
    catch {bind $cv <B1-Motion>       $pick(prevmotion)}
    return 1
}

# Leave the mode.  Safe to call when nothing is live, on every arm.
## Is a pick mode live on some canvas right now?  ⚠ SUSPENDED COUNTS AS
## RUNNING (issue 1308): a mode paused by a descend is still a mode the user
## has to be able to leave, and `pick(canvas)` is what `pick_end` releases.
proc rdw::pick_running {} {
    variable pick
    return [expr {[info exists pick(canvas)] ? 1 : 0}]
}

proc rdw::pick_end {} {
    variable pick
    set r [rdw::pick_release]
    array unset pick
    ## ISSUE 1384, AND STRICTLY AFTER THE UNSET: `rdw::_hint_sync` asks
    ## `rdw::pick_running`, so it can only decide to blank the slot once the
    ## record is gone.  This is the synchronous door -- ESC, `.rdw`'s own
    ## Escape (ruling DD-12) and every command path reach it -- and the pump is
    ## the second one, for an exit nobody added a door to.
    rdw::_hint_sync
    return $r
}

# ---------------------------------------------------------------------------
# THE SUSPEND/RESUME CONTRACT (src/cmdmode.tcl, issue 0201).  A descend
# mid-mode must pause the seize and put it back on the canvas it LANDS on.
#
# ⚠ THE SUSPEND ARM NOW RUNS ON EVERY DESCEND IN EVERY PROFILE FOREVER, so
# "0 and no damage when there is nothing to release" is a permanent obligation,
# not a convenience.
proc rdw::pick_suspend {} {
    variable pick
    if {![info exists pick(canvas)]} { return 0 }
    if {[info exists pick(suspended)]} { return 0 }
    if {![rdw::pick_release]} { return 0 }
    set pick(suspended) 1
    return 1
}

# ⚠ ALL FOUR PREDECESSORS ARE RE-LATCHED FROM THE CANVAS WE ARE LANDING ON,
# not carried over from the one the mode was seized on: a new window or tab has
# its own binding set (set_bindings + clone_canvas_bindings), and the
# predecessors latched on the parent do not describe it.
# ase::ui::sod_resume (ase_window.tcl:2039-2046) records the same, and it is
# the load-bearing half of ruling D2 of issue 0201.  It re-latches by calling
# rdw::_pick_seize, so the count follows that proc and cannot drift from it.
proc rdw::pick_resume {{canvas {}}} {
    variable pick
    if {![info exists pick(suspended)]} { return 0 }
    if {$canvas eq {} || ![winfo exists $canvas]} {
        set canvas {}
        catch {set canvas $pick(canvas)}
    }
    if {$canvas eq {} || ![winfo exists $canvas]} {
        ## Nowhere left to come back to -- the window was closed while the mode
        ## was paused.  Drop it rather than leave an unreachable record behind.
        array unset pick
        ## ISSUE 1384: this is an exit, and the only one that is not a
        ## `pick_end`.  Without it the sentence outlives the mode on a window
        ## that is still open.
        rdw::_hint_sync
        return 0
    }
    unset -nocomplain pick(suspended)
    rdw::_pick_seize $canvas
    ## ISSUE 1384: REHOME THE HINT WITH THE MODE.  `_hint_sync` blanks the slot
    ## it last wrote before writing the new one, so a descend that lands in
    ## another window leaves no sentence behind in the one it came from.  The
    ## pump would do it within 80 ms; doing it here makes it a contract.
    rdw::_hint_sync
    return 1
}

# ⚠ AT SOURCE TIME, AND THAT IS SAFE.  cmdmode.tcl is pure Tcl and is sourced
# at xschem.tcl:16760, BEFORE this file at :16790; ase_window.tcl:2055 already
# registers the same way.  Nothing here touches Tk, so --nogui is unaffected --
# and the registration being source-time is what lets the headless arm prove it
# happened at all.
#
# ⚠ BUT IT IS GUARDED, AND NOT FOR TIDINESS.  Row N2 of this file's own suite
# sources rdw.tcl into a BARE `interp create` slave -- an interpreter with
# neither `winfo` nor `xschem` -- as the non-brittle proof that nothing here
# runs at source time.  That slave has no cmdmode either, so an unguarded
# `cmdmode::register` would fail the very row that polices this file's --nogui
# survival.  The guard is therefore a statement about WHERE this file can be
# loaded, not a silent fallback: it returns 0 when the contract is absent, and
# the caller can say so.  Inside xschem the contract is always there, which is
# what the headless arm of row K9 measures.
proc rdw::_register_cmdmode {} {
    if {![llength [info commands ::cmdmode::register]]} { return 0 }
    ::cmdmode::register rdw_pick rdw::pick_suspend rdw::pick_resume
    return 1
}
rdw::_register_cmdmode

# ===========================================================================
# ITEM B5 -- THE BUTTON COLUMN AND THE TWO SCOPE DIALOGS
# ===========================================================================
# Spec 4.2 B7's table, wired.  Rulings DD-2, DD-6, DD-7, DD-8, DD-9 and DD-10.
#
#   button        annotation (1)   summary (2)      all (3)
#   Up / Down     reorder          reorder          reorder
#   Delete        remove           remove           GREYED
#   Add           GREYED           add to list 1    the dialog asks which
#   Save          write the settings file, all three
#
# Every Delete and every Add first raises a SCOPE DIALOG -- this device flavor
# only, versus every device of this broad class.  Narrow writes a `flavor`
# entry keyed on the cell name; broad writes the `class` entry, which ruling
# DD-2 makes the primary key.
#
# ⚠ WHERE THE NARROWING IS DEFINED, AND WHERE IT IS NOT.  This file computes
# no list of its own.  `op_param_lists::effective` is the ONE definition of
# "the annotation list for this device" (flavor in file order, then the class
# entry, then the PDK seed), and every list this column reads or writes comes
# from it.  Re-deriving one here from op_annot::descriptor is issue 1300's
# rejected option (a) and invariant I1's exact failure shape.
#
# ⚠ AND THE KEYS STILL NARROW NOTHING.  Item B4's 1/2/3 select a list
# IDENTITY; that is unchanged and issue 1300 stays the user's question.  What
# B5 adds is the first CALLER of the store's editing path, which is why rows
# S1 and K11 handed their `op_param_lists:: == 0` term to row BT22.
#
# ---------------------------------------------------------------------------
# THE THREE THINGS THE COLUMN NEEDED AND B3 DID NOT HAVE
# ---------------------------------------------------------------------------
# 1. A TARGET.  nhse's own rule (xschem.tcl:1314) -- "the row your cursor is
#    in" -- with no new focusable widget, because a focusable widget in this
#    column is issue 1308's stuck state (Tk buttons do not take focus on X and
#    that is the only reason the keyboard goes back to the canvas).  MEASURED
#    on :99: a `-state disabled` text still moves `insert` on a real Button-1,
#    so a plain click was enough to aim the buttons from the day they landed.
#    ⚠ AND FOR THREE ITEMS IT AIMED THEM INVISIBLY.  A disabled text draws no
#    insertion cursor, so the user clicked, watched a new dump arrive and was
#    told the line they could plainly see was not a parameter row (issue
#    1324).  ITEM R1 (issue 1337) SHADES THAT ROW: `::rdw::targetrow` is the
#    cursor, `rdw::set_row` its one setter, `rdw::_paint_cursor` its one
#    painter, and `rdw::pane_click` the binding that moves it.
#
# 2. A SUBJECT.  `rdw::push` RECORDS what a block was about at DUMP TIME
#    (issue 1322, item B5-a) -- instance, `type=` token, cell and sheet -- and
#    `rdw::block_subject` reads it back out of the block itself.  This section
#    derives nothing from the live editor: the earlier attempt split the
#    header back into a bare name and re-resolved it, which answers about
#    whatever sheet is open NOW and is the defect that reverted item B5-2.  A
#    window-global "last device dumped" would be wrong the same way, one block
#    over: it would edit a different device's list than the block the cursor
#    is sitting in, with nothing on screen saying so.
#
# 3. A ROW NAME.  ⚠ THE PANE PRINTS THE RAW PARAMETER, NOT THE LABEL.  IHP's
#    first triple is `{id ids 0}` and the block line is `    ids : 1.2e-05`, so
#    every lookup into a list is BY THE PARAM FIELD.  Matching by label
#    round-trips sky130 and gf180 perfectly and silently misses IHP -- the one
#    PDK in this tree that distinguishes them.
#
# ---------------------------------------------------------------------------
# WHY THE DIALOG IS A CHILD TOPLEVEL WITH A BUILD/DONE/WRAPPER SPLIT
# ---------------------------------------------------------------------------
# ⚠ ISSUE 0803: a modal a suite cannot click does not FAIL, it HANGS, and takes
# the audit with it.  So the shape is `ase::ui::bus_dialog`'s
# (ase_window.tcl:1320/1392/1406), copied deliberately:
#   * `scope_dialog_build` builds and returns the window and touches no event
#     loop, so the widget tree is inspectable with no `tkwait` anywhere;
#   * `scope_dialog_done` sets the result and destroys, so a test can invoke a
#     radiobutton and the OK button from an `after` timer;
#   * `scope_dialog` is the thin wrapper, and its `tkwait` is GUARDED -- the
#     build-time `update` can let a timer destroy the window first;
#   * with NO Tk at all it answers Cancel and RETURNS.  A dialog that is only
#     safe when a display is present is not safe.
# MEASURED while planning: `.rdw.scope`'s bindtags are {.rdw.scope Toplevel
# all}, so a child toplevel does NOT inherit `.rdw`'s ruling DD-12 Escape and
# can bind its own Cancel with no collision -- a dialog that inherited it would
# silently end the canvas command mode the user is in the middle of.
#
# ⚠ AND IT REFUSES TO OPEN WHILE A CANVAS PICK MODE IS LIVE.  MEASURED: `grab
# set .rdw.scope` really does take `grab current`, so a modal opened over a
# live verb-noun pick swallows the canvas click the mode is waiting for and the
# mode looks dead.  Adjacent to issue 1309 without being it: this item adds no
# key and calls no `pick_start`.
#
# ---------------------------------------------------------------------------
# WHAT A SUCCESSFUL EDIT DOES *AFTER* THE STORE, AND THE ONE EXCEPTION
# ---------------------------------------------------------------------------
# Delete and Add call `op_param_lists::apply` -- once with the subject's own
# `type=` token, because a token the class map does not name is unreachable
# from the bare call (issue 1279), and once bare, because the class's mapped
# SIBLINGS must follow: `apply nmos` alone leaves every pmos on the sheet
# drawing the old list.  Ruling DD-6 then writes the UNION into `params` (what
# the run computes, so `_cards_for` keeps emitting the card) and the annotation
# list into the display key (what the sheet draws).  Delete is a DISPLAY
# decision and never a SAVE decision.
#
# ⚠ A REORDER APPLIES TOO, AND THAT REVERSES THE PRESERVED PATCH ON PURPOSE
# (item B5-2).  The patch deferred it and said so on screen, because
# `op_param_lists::_save_set` builds the union ANNOTATION-FIRST, `apply` writes
# it into the descriptor's `params`, and `op_param_lists::seed` read that same
# field back as "the PDK's own list" -- so reordering list 1 silently reordered
# list 2's answer, which nobody owns.  Ruling DD-13 (item B2e) split the
# descriptor into THREE lists: `seed` now reads the DECLARATION, which nothing
# but `op_annot::register` can write, and `_show_set` filters the union
# annotation-first into the display key.  The leak is structurally gone -- issue
# 1312 is FIXED, store row N4 fences the opposite -- so a status line citing it
# as a reason to defer would be a false statement on a screen the user is
# reading.  Up and Down redraw like Delete and Add.
#
# Suite: tests/headless/test_rdw_window_1245.tcl section BT (both arms),
# tests/headless/test_op_param_store_1245.tcl section BE (the file half) and
# tests/headless/test_rdw_keys_1245.tcl section SD (the real modal, :99).

namespace eval rdw {
    # The target row, as a 1-BASED PANE LINE, and 0 for "no row".  IT IS THE
    # CURSOR -- the one item R1 (issue 1337) made visible, not a headless
    # shadow of a second one.  `rdw::set_row` is its only setter and moves the
    # variable, the pane's `insert` mark and the `cursor` shading together;
    # `rdw::_target_line` reads it back.  A cursor with a variable of its own
    # would let Delete edit a line the user is not looking at while every row
    # of this feature's suite still passed.
    variable targetrow
    if {![info exists targetrow]} { set targetrow 0 }

    # The scope dialog's three variables.  Namespace state rather than
    # proc-locals because the build, the radiobuttons and the wrapper are three
    # different scopes; `scope_result` is pre-set to Cancel BEFORE the build,
    # so a window that never reaches `scope_dialog_done` -- a deadman timer, a
    # window-manager close -- answers Cancel rather than the previous answer.
    variable scope_result {}
    variable scope_choice broad
    variable list_choice annotation
}

# ---------------------------------------------------------------------------
# THE TARGET.  Pure enough to drive with no Tk at all, which is where the
# majority of this feature's suite lives.

# THE ONE TARGET SETTER.  `n` is a 1-based pane line; 0 is "no row".
# It moves the SHADING too (item R1, issue 1337), because the target and the
# thing the user sees are one cursor -- see rdw::_paint_cursor.
proc rdw::set_row {n} {
    variable targetrow
    if {![string is integer -strict $n]} { return $targetrow }
    if {$n < 0} { set n 0 }
    set targetrow $n
    rdw::_paint_cursor
    return $n
}

# The cursored line, or 0 when no row is cursored.
#
# ⚠ IT NO LONGER READS THE PANE'S `insert` MARK, AND THE COMMENT THAT USED TO
# STAND HERE ARGUED THE OPPOSITE (item R1, issue 1337).  "The pane WINS when it
# exists" was right while the target was INVISIBLE: a real click moved `insert`
# and nothing else, so the widget was the only place the user's click was
# recorded.  Now the click goes through `rdw::pane_click` -> `rdw::set_row`,
# which moves the variable, the mark and the shading together, and reading the
# mark back would be a second opinion about the same thing -- one that can
# never say "no row", because an `insert` mark ALWAYS has a line.  That is the
# whole difficulty: DD-1 requires the window to answer "there is no cursor"
# after a new dump, and issue 1324 measured the mark drifting to line 9 on its
# own while this variable still said 3.  The variable is the answer; the
# widget follows it.
proc rdw::_target_line {} {
    variable targetrow
    if {![info exists targetrow]} { return 0 }
    return $targetrow
}

# A flat pane line -> {blockindex entryindex}, or {} past either end.  PURE: a
# function of ::rdw::blocks alone, because rdw::render_pane paints one entry
# per line in store order and nothing else.
proc rdw::_locate {line} {
    variable blocks
    if {![string is integer -strict $line]} { return {} }
    if {$line < 1} { return {} }
    set n 0
    set bi 0
    foreach b $blocks {
        set len 0
        catch {set len [llength $b]}
        if {$line <= $n + $len} { return [list $bi [expr {$line - $n - 1}]] }
        incr n $len
        incr bi
    }
    return {}
}

# The RAW parameter name of one block entry, or {} when the entry is not a
# parameter row.  A tagged entry (hdr / dim / dev / note) never is, and neither
# is the separator; what is left is `rdw::format_answer`'s own
# "    %-*s : %s" row, whose first field is the parameter the seam published.
proc rdw::_row_param {entry} {
    if {[catch {llength $entry} n]} { return {} }
    if {$n != 2} { return {} }
    if {[lindex $entry 0] ne {}} { return {} }
    set t [lindex $entry 1]
    if {[string trim $t] eq {}} { return {} }
    if {![regexp {^[ ]+(\S+)[ ]+:} $t -> p]} { return {} }
    return $p
}

# ---------------------------------------------------------------------------
# THE SUBJECT.

# ⚠ `rdw::_hdr_instname` IS NOT DEFINED HERE ANY MORE, AND ITS ABSENCE IS THE
# FIX (issue 1322, item B5-a).  It used to be defined twice -- once at the top
# of this file and once in this section -- and the LAST definition silently
# won.  It now has exactly one home, beside `rdw::header`, whose join it
# inverts; `rdw::push` is its other caller.
#
# {instname type class cellname schname} for the block the cursor is in, or {}.
# ⚠ THE BLOCK INDEX IS AN ARGUMENT AND NOT `[lindex $blocks 0]`.  The newest
# dump is on top and the user's cursor is very often in an OLDER one; a subject
# read from the newest block would edit a different device's list than the
# block on screen, and every single-block row ever written would still pass.
#
# ⚠ AND IT RE-RESOLVES NOTHING (issue 1322, item B5-a).  THIS PROC IS THE
# DEFECT THAT REVERTED ITEM B5-2.  It used to split the block's header back
# into a bare instance NAME and ask the LIVE EDITOR what that name meant --
# which answers about whatever sheet is open now, not about the sheet the block
# was dumped from.  MEASURED with two top-level sheets each holding an `M1`,
# which is the default template name of every device symbol in this tree:
#     the block on screen was about   ncls / vn.sym
#     this proc answered              type vpdev class pcls cellname vp.sym
#     Delete's verdict                ok, and it edited pcls
# ⚠ COMPARING THE HEADER'S PATH HALF DOES NOT CATCH IT and no reviewer should
# spend a pass rediscovering that: both sheets are top-level, so both headers
# are byte-identical.  THE AXIS IS SHEET IDENTITY, NOT HIERARCHY PATH.
# `rdw::push` now records the subject AT DUMP TIME and `rdw::block_subject`
# reads it back, so this proc reads a RECORD and asks the editor nothing.
#
# The CLASS is still resolved here, and only here: `op_param_lists::class` is
# a pure classmap lookup with no sheet dependence, so it has one home already
# (invariant I1) and is the one field that is still true whenever it is asked.
# A block whose device could not be resolved at dump time -- a symbol xschem
# could not find, an instance that had already gone -- carries no subject at
# all, and `{}` here is what makes rdw::button's existing guard fire with no
# new sentence.
proc rdw::_subject {blockindex} {
    variable blocks
    set subj [rdw::block_subject [lindex $blocks $blockindex]]
    if {$subj eq {}} { return {} }
    set type {}
    catch {set type [dict get $subj type]}
    if {$type eq {}} { return {} }
    set cls {}
    catch {set cls [::op_param_lists::class $type]}
    set inst {} ; set cell {} ; set sch {}
    catch {set inst [dict get $subj instname]}
    catch {set cell [dict get $subj cellname]}
    catch {set sch  [dict get $subj schname]}
    return [dict create instname $inst type $type class $cls cellname $cell \
                        schname $sch]
}

# ---------------------------------------------------------------------------
# THE WINDOW FOLLOWS THE STORE (item R2, issue 1338).
#
# The user's words: "Promote/demote using Up/Down arrow should be reflected in
# the Results Display Window as well as the schematic annotation."  The sheet
# half already worked -- `rdw::_apply_now` rewrites the descriptors and
# redraws, MEASURED at HEAD 27122ca4 as a `xschem get annot_overlay_flushes`
# of +1 per accepted press -- and the WINDOW half is what was missing: the
# store moved, `::rdw::blocks` came back byte-identical, and the pane kept
# showing the order the user had just changed until they pressed 1 or 2 again.
#
# ⚠ THE PANE'S ROW ORDER IS NOT THE LIST'S ROW ORDER, so "swap the two adjacent
# display lines" is the obvious implementation and it is WRONG.
# `rdw::format_answer` emits, per primitive, the `devices` pairs FIRST, then
# the `nonfinite` ones, then the `absent` ones.  So a list holding
# {id ids 0} {gm gm 1} {gds gds 1} whose `gm` came back non-finite renders as
#       ids : 1.2e-05      gds : 5.6e-06      gm  : (did not converge)
# and an Up on `gds` swaps LIST entries 2 and 1 while leaving the DISPLAY
# exactly as it was.  MEASURED on the IHP-shaped seed row RE0 builds -- label
# != param, which is a shipped PDK shape and not a synthetic one.  A blind
# display swap would put `gds` above `ids` and the window would then be showing
# an order the store does not hold, which is the one thing this item exists to
# prevent.
#
# So a block is RE-SLOTTED, never swapped: the rows the list DECLARES are
# re-filled, in the list's order, into the slots those declared rows already
# occupied, and every other row keeps its own slot.

# The RAW param names the store's list holds for this class and cell, in store
# order, deduped.
#
# ⚠ `::op_param_lists::effective` IS THE ORDER AND NOTHING HERE RE-DERIVES ONE.
# A second opinion about what the sheet draws is invariant I1's two-builders
# drift, and this window's whole promise in R2 is that the two agree.
#
# ⚠ THE CELL IS PASSED, so each block is re-slotted into the order that governs
# IT.  A device-flavor entry legitimately governs one block and not another
# (`rdw::_scope_for` asks exactly this question before the write).  With no
# flavor entry in the settings file -- the ordinary case -- `effective` falls
# through to the class entry and then to the PDK seed, so the extra argument
# changes nothing at all.
#
# ⚠ WHICH BLOCK GETS RE-SLOTTED AT ALL IS DECIDED ONE LAYER OUT, and it is not
# this proc's question.  A block a write did not reach is skipped by
# `rdw::_reorder_shown`'s `wkey` test (issue 1348) rather than re-slotted into
# whatever order happens to govern it -- an earlier revision did the latter and
# reordered a sibling cell's block on a press whose own sentence named a
# different cell file.
#
# Deduped because `order` is used as a fill sequence below: a list carrying two
# triples with the same RAW param would otherwise place that row twice and drop
# another.  (`op_annot::register` refuses two triples sharing a LABEL as of
# ruling DD-15, but nothing refuses two sharing a param.)
proc rdw::_list_params {cls listname cell} {
    set l {}
    catch {set l [::op_param_lists::effective $cls $listname $cell]}
    set out {}
    foreach t $l {
        set p {}
        if {[catch {lindex $t 1} p]} { continue }
        if {$p eq {}} { continue }
        if {[lsearch -exact $out $p] >= 0} { continue }
        lappend out $p
    }
    return $out
}

# Re-fill one block's declared parameter rows into `order`.  Returns
# {newblock map}, where `map` is a dict from the entry index a row HAD to the
# entry index it now HAS -- the cursor is moved with it, so a second press
# moves the same parameter again instead of whatever slid under the old line
# number.  That is ruling DD-1's own argument, one item later.
#
# ⚠ A MAXIMAL RUN OF PARAMETER ROWS IS ONE PRIMITIVE, AND THAT IS WHAT KEEPS A
# NUMBER UNDER THE DEVICE THAT PUBLISHED IT (ruling D-3).  One XR1 resolves to
# several primitives; `rdw::format_answer` emits a "  <rawdev>" sub-header and
# then that primitive's rows, contiguously, so a permutation confined to one
# run can never cross a sub-header.  An implementation that collected the
# block's parameter rows and re-laid them all in list order moves a value under
# a device that never published it -- a plausible wrong NUMBER in the block a
# designer pastes into a review document, which is invariant I3 exactly.
# Row RE4 is the fence.
#
# ⚠ AND A ROW NO LIST DECLARES KEEPS ITS OWN SLOT.  The `absent` bucket renders
# after the computed pairs, so a parameter the run published and no list
# declares can sit BETWEEN two rows that a list does declare.  Permuting every
# row of the run would move it; the button column already refuses to reorder it
# by name (row BT6), and somebody else's reorder must not do it either.
#
# The block's FIRST entry carries the subject stamp as a third element (issue
# 1322, `rdw::push`), and it is never a parameter row, so it is never rewritten
# here -- row RE1's last leg is the fence on that.
proc rdw::_reslot_block {block order} {
    set map [dict create]
    set n 0
    if {[catch {llength $block} n]} { return [list $block $map] }
    set out $block
    set i 0
    while {$i < $n} {
        if {[rdw::_row_param [lindex $block $i]] eq {}} { incr i ; continue }
        set j $i
        while {$j < $n && [rdw::_row_param [lindex $block $j]] ne {}} { incr j }
        ## [$i, $j-1] is one primitive's rows.
        set slots {}
        for {set k $i} {$k < $j} {incr k} {
            if {[lsearch -exact $order \
                    [rdw::_row_param [lindex $block $k]]] < 0} { continue }
            lappend slots $k
        }
        ## The declared rows of this run, in the LIST's order.  Walked
        ## list-first rather than sorted by rank so that the result does not
        ## depend on `lsort`'s stability, and so two rows of one run spelled
        ## the same way keep their run order.
        set filled {}
        foreach p $order {
            foreach k $slots {
                if {[rdw::_row_param [lindex $block $k]] eq $p} {
                    lappend filled $k
                }
            }
        }
        ## A re-slot is a PERMUTATION: same rows, same slots.  If the two
        ## disagree the block is left exactly as it was rather than half
        ## rewritten -- the least-destructive reading, and the same one
        ## `rdw::pane_click` takes for a refused click.
        if {[llength $filled] == [llength $slots]} {
            set x 0
            foreach k $slots {
                set src [lindex $filled $x]
                lset out $k [lindex $block $src]
                dict set map $src $k
                incr x
            }
        }
        set i $j
    }
    return [list $out $map]
}

# Re-slot EVERY stored block that draws the list just edited, and answer the
# pane line the cursor should move to.  `loc` is the {blockindex entryindex}
# the cursor was at and `line` its flat pane line.
#
# ⚠ EVERY BLOCK THE WRITE REACHED, NOT JUST THE ONE THE CURSOR IS IN.  The
# store's entries are class- and flavor-wide, so a window that reordered only
# the cursored block would show the SAME list in two different orders at once
# -- a statement the store cannot support, and one the user would have to
# reconcile by hand.  This is an E question neither DD-3 nor DD-4 answers; it
# is on the owed ledger as rule debt 1338_R2_every_block_of_the_class_follows
# for the user to overrule, and row RE5 is what an overrule would delete.
#
# ⚠ BUT "THE WRITE REACHED IT" IS A NARROWER TEST THAN "SAME CLASS", AND THE
# DIFFERENCE IS ISSUE 1348.  `wkey` is the {<scope> <key>} the edit actually
# wrote at, built by the ONE builder `rdw::_write_key`; a block is re-slotted
# only when the entry that GOVERNS its own cell is that same entry.  Without
# that test a device-flavor press -- whose own sentence reads "for cells
# matching <glob> of class <cls>" -- visibly reordered a block of a cell the
# glob does not match, re-slotting it into a class list the press had not
# touched.  MEASURED: M2's block went `gm ids` -> `ids gm` on a press that
# named M1's cell file and left the class list byte-identical.  The same test
# is what makes a BROAD write agree with `rdw::_shadow_why`'s own broad
# sentence -- "this device's own rows did not change" -- instead of silently
# reordering the very block that sentence is about.
# `wkey` {} disables the guard, which is what a caller with no key to name
# would need; no shipped caller passes one.
#
# ⚠ A BLOCK WITH NO SUBJECT IS NOT TOUCHED, and neither is one of another
# class.  A block whose device could not be resolved at dump time carries no
# subject at all (`rdw::_capture_subject` refuses), so nothing says which of
# its rows the edited list declares; a block of a different class carries a
# list nobody edited.  Row RE5's other two blocks are spelled in the order a
# class-wide reorder WOULD produce, so "left alone" and "reordered" are
# distinguishable on them.
# ============================================================================
# REBUILDING A BLOCK THAT IS ALREADY ON SCREEN
# ============================================================================
# THE USER'S WORDS: "Delete is not affecting the current display. Only future
# items sent to the RDW are conforming to the new list."  Both halves were
# true, and the reason is structural rather than an oversight: a block holds
# PRE-RENDERED TEXT, and the rows the list did not declare were discarded at
# dump time by `rdw::_narrow_answer` inside `rdw::format_answer` -- they are
# not merely unrendered.  So the pane cannot be FILTERED into agreement with an
# edited list: there is nothing to filter back in, and `rdw::_locate` (a pure
# function of `::rdw::blocks`, one pane line per stored entry) would resolve
# every later button press to the wrong row.
#
# The only mechanism that can make a standing block agree with an edited list
# is to BUILD IT AGAIN, through `rdw::_make_block` -- the same builder a fresh
# dump uses, so the rebuilt block is exactly the block a fresh dump would have
# produced, narrowing footnote, column widths, analysis sentence and all.
#
# ⚠ THE USER RULED FOR THIS, AND IT SETTLES THE OPEN HALF OF ISSUE 1338.  The
# cost was put to them in those words and accepted: a block is no longer a
# frozen record of one moment, and an OLDER dump on screen changes under the
# reader without their pressing anything on it.  The alternative offered --
# leave the blocks alone and mark them stale -- was declined because it does
# not do what was asked.  Rule debt `1338_R2_every_block_of_the_class_follows`
# is answered by that ruling.
#
# ⚠ WHAT A REBUILD DELIBERATELY WILL NOT DO.  Three states leave the block
# exactly as it was, because rebuilding it would be a guess:
#   * no subject stamp (a block pushed before issue 1322's stamp, or one whose
#     header carried no instance name),
#   * a block dumped from a DIFFERENT schematic than the one now loaded -- the
#     instance name would resolve against the wrong design,
#   * an instance whose devpath no longer resolves, or a raw that is gone.
# Each is counted and the caller says so, because a block that silently did
# not follow is the defect this change exists to remove, pointed the other way.
# The flat pane line a parameter occupies in block `bi`, or 0 if that block no
# longer draws it.  A rebuild can change a block's LENGTH, so the cursor cannot
# be carried across one by line arithmetic the way `rdw::_reorder_shown`'s
# permutation allows -- it has to be found again by name.
# How many parameter rows a block draws.  The predicate a rebuild is judged by.
proc rdw::_param_count {block} {
    set n 0
    if {[catch {llength $block}]} { return 0 }
    foreach e $block {
        if {[rdw::_row_param $e] ne {}} { incr n }
    }
    return $n
}

proc rdw::_line_of_param {bi param} {
    variable blocks
    if {$param eq {}} { return 0 }
    if {$bi < 0 || $bi >= [llength $blocks]} { return 0 }
    set n 0
    for {set i 0} {$i < $bi} {incr i} {
        set len 0
        catch {set len [llength [lindex $blocks $i]]}
        incr n $len
    }
    set b [lindex $blocks $bi]
    for {set e 0} {$e < [llength $b]} {incr e} {
        if {[rdw::_row_param [lindex $b $e]] eq $param} {
            return [expr {$n + $e + 1}]
        }
    }
    return 0
}

proc rdw::_rebuild_block {bi} {
    variable blocks
    set blk [lindex $blocks $bi]
    set stamp [rdw::block_subject $blk]
    if {$stamp eq {}} { return 0 }
    set inst {}
    catch {set inst [dict get $stamp instname]}
    if {$inst eq {}} { return 0 }
    ## The stamp records the schematic the dump was taken from; an instance
    ## name is only meaningful against that design.
    set sch {}
    catch {set sch [xschem get schname]}
    set was {}
    catch {set was [dict get $stamp schname]}
    if {$was ne $sch} { return 0 }
    set dp {}
    if {[catch {::op_annot::devpath $inst} dp]} { return 0 }
    if {$dp eq {}} { return 0 }
    ## The header is the block's own first line -- one builder for the name
    ## (invariant I1), so it is not recomposed here.
    set hdr {}
    catch {set hdr [lindex [lindex $blk 0] 1]}
    set lk {}
    catch {set lk [dict get $stamp list]}
    set ctx [dict create header $hdr devpath $dp instname $inst]
    ## An explicit `list` wins in `rdw::_list_ctx`, which is the point: the
    ## block rebuilds under the list it was DUMPED under, not under whichever
    ## list the window is showing now.
    if {$lk ne {}} { catch {dict set ctx list $lk} }
    set new {}
    if {[catch {rdw::_make_block $dp $ctx} new]} { return 0 }
    if {[catch {llength $new} n] || $n < 1} { return 0 }
    ## ⚠ A REBUILD MAY NOT TRADE DATA FOR A REFUSAL, and this is the sharp
    ## edge of the whole change.  `rdw::_make_block` answers with whatever the
    ## backend says NOW: with the raw unloaded, the device gone, or the
    ## simulator deregistered it returns a perfectly well-formed REFUSAL block
    ## carrying no parameter rows.  Replacing with it would wipe the numbers
    ## the user is reading off the screen as a side effect of editing a list --
    ## the worst possible reading of "the display follows the edit", and the
    ## exact failure MEASURED against rows RE10 and RE11, whose fixture has no
    ## live raw and whose blocks came back empty.
    ##
    ## So: a block that HAD parameter rows keeps them unless the rebuild has
    ## parameter rows too.  The caller counts this as stuck and says so.  A
    ## block that was a refusal to begin with may be replaced freely -- there
    ## is nothing to lose and the new refusal is the more current one.
    if {[rdw::_param_count $blk] > 0 && [rdw::_param_count $new] == 0} { return 0 }
    ## ⚠ THE ORIGINAL STAMP IS CARRIED OVER, NOT RE-DERIVED.  `rdw::push` is
    ## the only other stamper and it is not on this path; re-deriving here
    ## would ask `rdw::_type_cell` about the instance a second time and a block
    ## whose device has since been renamed would come back stamped as a
    ## different device than the one the user dumped.
    set e [lindex $new 0]
    set new [lreplace $new 0 0 [list [lindex $e 0] [lindex $e 1] $stamp]]
    lset blocks $bi $new
    return 1
}

# The sentence for the blocks that did NOT follow.  One clause, appended to the
# verdict the press already produced -- a second status line would overwrite the
# first, and this window's status surface holds one message (issues 1362, 1365).
proc rdw::_stuck_note {n} {
    if {$n <= 0} { return {} }
    if {$n == 1} {
        return {One older dump could not be rebuilt and still shows the list it was taken under.}
    }
    return "$n older dumps could not be rebuilt and still show the lists they were taken under."
}

# Rebuild every block the write ACTUALLY REACHED.  Returns {rebuilt stuck}: how
# many followed the edit, and how many were reached but could not be rebuilt
# and were left untouched.
#
# ⚠ THE THREE SKIPS ARE `rdw::_reorder_shown`'S OWN, AND NOT ONE OF THEM IS
# COSMETIC.  A rebuild is a bigger hammer than a re-slot -- it replaces the
# block rather than permuting it -- so a block this write did not reach must
# not be rebuilt "harmlessly": it would come back in the LIST's order and throw
# away a permutation an earlier Up or Down put there, which is a silent edit to
# a block nobody touched.
#   * another class            -- carries a list nobody edited
#   * another LIST             -- a block dumped under list 2 does not change
#                                 because list 1 was edited; its membership was
#                                 decided by a list this press did not write
#   * a shadowed flavor entry  -- `rdw::_scope_for` resolves which entry
#                                 GOVERNS this cell, and a broad write over a
#                                 device a flavor entry shadows changed nothing
#                                 for that device.  Row RE11 is the fence and
#                                 `rdw::_shadow_why` is the sentence.
proc rdw::_rebuild_class {cls listname wkey} {
    variable blocks
    set done 0
    set stuck 0
    if {$cls eq {}} { return [list 0 0] }
    for {set bi 0} {$bi < [llength $blocks]} {incr bi} {
        set subj [rdw::_subject $bi]
        if {$subj eq {}} { continue }
        set c {}
        catch {set c [dict get $subj class]}
        if {$c eq {} || $c ne $cls} { continue }
        set stamp [rdw::block_subject [lindex $blocks $bi]]
        set blist {}
        catch {set blist [dict get $stamp list]}
        if {$listname ne {} && $blist ne {} && $blist ne $listname} { continue }
        set cell {}
        catch {set cell [dict get $subj cellname]}
        if {$wkey ne {} && [rdw::_scope_for $cls $listname $cell] ne $wkey} { continue }
        if {[rdw::_rebuild_block $bi]} { incr done } else { incr stuck }
    }
    return [list $done $stuck]
}

proc rdw::_reorder_shown {cls listname wkey loc line} {
    variable blocks
    set out {}
    set bi 0
    set newline $line
    foreach b $blocks {
        set s [rdw::_subject $bi]
        set c {}
        catch {set c [dict get $s class]}
        if {$s eq {} || $c eq {} || $c ne $cls} {
            lappend out $b ; incr bi ; continue
        }
        set cell {}
        catch {set cell [dict get $s cellname]}
        if {$wkey ne {} && [rdw::_scope_for $cls $listname $cell] ne $wkey} {
            lappend out $b ; incr bi ; continue
        }
        set ord [rdw::_list_params $cls $listname $cell]
        if {[llength $ord] == 0} { lappend out $b ; incr bi ; continue }
        lassign [rdw::_reslot_block $b $ord] nb map
        lappend out $nb
        if {[llength $loc] == 2 && [lindex $loc 0] == $bi} {
            set ei [lindex $loc 1]
            ## A re-slot is length-preserving and confined to ONE block, so
            ## every line above this block is unchanged and the flat pane line
            ## moves by exactly the entry-index delta.  That also means
            ## `rdw::render_pane`'s stale-target sweep (item R1) cannot fire on
            ## a reorder: `rdw::_locate` still resolves the same line count.
            if {[dict exists $map $ei]} {
                set newline [expr {$line + [dict get $map $ei] - $ei}]
            }
        }
        incr bi
    }
    set blocks $out
    return $newline
}

# ---------------------------------------------------------------------------
# THE LIST HELPERS.  Every one of them reads a list the STORE handed over;
# none builds one.

# The index of a triple by its RAW PARAM field, never by its label.
proc rdw::_index_of {lst param} {
    if {[catch {llength $lst}]} { return -1 }
    set i 0
    foreach t $lst {
        if {[catch {lindex $t 1} p]} { return -1 }
        if {$p eq $param} { return $i }
        incr i
    }
    return -1
}

proc rdw::_triple_in {lst param} {
    set i [rdw::_index_of $lst $param]
    if {$i < 0} { return {} }
    return [lindex $lst $i]
}

# ⚠ ADD GUESSES NO `kind`, EVER (invariant I1, measured rule R3) -- AND
# THIS PARAGRAPH USED TO SAY "MINTS NO `kind`, EVER" AND TO GIVE A REASON THAT
# IS NOT TRUE OF THIS TREE (issue 1372).  It said: the kind is the raw-name
# SHAPE, "so a guessed one writes a `.save` card that matches nothing, and one
# bogus card destroys the whole operating point".  MEASURED on the user's own
# M18, both halves: `op_annot::_cards_for` (op_annot.tcl) emits
# `.save ${dev}[${param}]` and NEVER READS THE KIND, so a kind-0 row and a
# kind-1 row produce BYTE-IDENTICAL cards and no kind can make a card bogus.
# The kind is read at READ time only, by `op_annot::_wrap` / `_wrap_alts`, and
# `_wrap_alts` already falls back to the bare spelling.  An invariant whose
# stated reason is refuted is worse than no invariant: the next reader either
# obeys a rule nobody can justify or deletes it along with the real hazard it
# was standing in front of.
#
# THE REAL HAZARD IS THE PARAM NAME, NOT THE KIND, AND IT IS STILL HERE.  An
# accepted row joins `op_param_lists::_save_set`'s annotation+summary UNION,
# `apply` writes that union into the descriptor's `params`, and `_cards_for`
# turns `params` into the NEXT deck's `.save` cards -- MEASURED: an accepted
# summary Add of `cgs` grew `_cards_for M18` from six cards to seven.  Spec
# op_param_lists.md §3.2 / rule R5 records that `show`'s catalogue is a
# SUPERSET of the savable set (`ib` is the named example), that good cards plus
# ONE bogus card give a silent zero column, and that an all-bogus set makes
# ngspice write no raw at all.  So the name a user adds from list 3 on a
# dump-tier simulator can still poison a run on a per-device-card one.  That
# trade is on the owed ledger as rule debt 1372.
#
# WHAT THE THREE LOOKUPS BELOW ARE, IN ORDER.  A DECLARED triple always wins,
# and all three lookups are byte-for-byte the ones that were here: the two
# effective lists, then the PDK's declaration.  Only when all three are silent
# does `devpath` get its turn -- and then the kind is READ OFF THE RAW VECTOR
# THIS RUN PUBLISHED (`rdw::_run_triple`), never picked.  A run that names no
# such column for this device still answers {}, and the button still refuses by
# name.  `devpath` is optional so that no existing caller's arity moves: a
# caller that passes none -- the store suite's reduced copy of this model, and
# any future one with no sheet to stand on -- gets exactly the three declared
# lookups it got before, which is why no row of this feature's suite moves
# except the one whose verdict this item reverses.
proc rdw::_find_triple {cls cell param {devpath {}}} {
    foreach ln {annotation summary} {
        set t [rdw::_triple_in [::op_param_lists::effective $cls $ln $cell] $param]
        if {$t ne {}} { return $t }
    }
    set t [rdw::_triple_in [::op_param_lists::seed $cls] $param]
    if {$t ne {}} { return $t }
    return [rdw::_run_triple $devpath $param]
}

# THE LAST RESORT, AND EVERY FIELD OF IT IS MEASURED (issue 1372).
#
# The user's complaint: "I put cursor on cgs and the clicked Add button and
# said add to all mos ... for summary list, but, later, when I send summary
# list with 2 key, it never shows up."  MEASURED end to end on their own bench:
# nothing downstream dropped it, because nothing was ever written.  List 3
# offers 88 rows for M18 and the sky130 declaration names six, so Add was
# refused for 82 of the 88 on BOTH target lists and accepted for 0 -- the user
# did not hit an edge case, they hit the only behaviour.
#
# `xschem raw list` is the run's own catalogue, so the spelling it holds is a
# MEASUREMENT of the shape and not an inference about it: for M18 every merged
# column comes back BARE (`@m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt[cgs]`),
# kind 1 by _wrap's own table, because `op_annot::opdump_read` injects the
# sidecar dump with `xschem raw add`.
#
# ⚠ THE LABEL IS THE PARAM, AND THAT IS NOT A GUESS EITHER.  A DISPLAY LABEL
# that differs from the raw name (`{id ids 0}`, IHP's shipped shape) is a PDK
# decision, and the only honest label for a column no PDK has named is the
# column's own name.  `op_param_lists::set_list` keeps one entry per label, so
# a mint whose label collided with a declared row would silently replace it
# (issue 1288) -- the store says so, in its own words, through `_store_tail`.
#
# ⚠ THREE `catch`es AND NO RAISE.  This runs inside a button's decision core,
# which must answer even with no raw loaded, no seam registered and no ase.tcl
# at all -- the --nogui arm of this feature's suite is exactly that.  Every
# failure is the same fact, "this run does not tell me", and the caller refuses
# by name.
#
# STATED COST, and it is the one direction this can be wrong in: if a raw
# carries the column ONLY as `i(@dev[p])` while some OTHER spelling was written
# first, the minted kind reads that other column.  `ase::op_vector_for` answers
# first-in-raw-order for exactly this reason and says so; the residual is a
# blank row, which is an error in the EMPTY direction and never a wrong number.
proc rdw::_run_triple {devpath param} {
    if {$devpath eq {} || $param eq {}} { return {} }
    set v {}
    catch {set v [::ase::op_vector_for $devpath $param]}
    if {$v eq {}} { return {} }
    set k {}
    catch {set k [::op_annot::_kind_of_vector $v]}
    if {$k eq {}} { return {} }
    return [list $param $param $k]
}

# THE DEVICE PATH AN ADD MAY READ THE RUN WITH, OR {} -- GUARDED ON SHEET
# IDENTITY (issue 1372, on issue 1322's own axis).
#
# ⚠ A BLOCK OUTLIVES THE RAW AND THE SHEET IT CAME FROM, ON PURPOSE.
# `rdw::close` keeps the dumps so they can be worked with later, and issue 1322
# is explicit that reviewing two sheets side by side is what this window is
# for.  So "the live raw" and "the run this row was read out of" are two
# different things the moment the user loads another sheet, and reading the
# first while claiming the second is how a number gets attributed to the wrong
# device -- 1322's own defect, one door along.
#
# The stamp is the axis: `rdw::_capture_subject` records `schname` AT DUMP TIME
# and this proc mints nothing unless the sheet then open is still that one.  A
# stale block therefore gets the three declared lookups and today's refusal,
# and the refusal SAYS SO (`rdw::_add_why`) -- otherwise the user reads it as
# the same bug coming back.
#
# ⚠ IT DOES NOT REFUSE THE EDIT.  Ruling DD-16 rules the cross-sheet edit
# ALLOWED and `rdw::_sheet_note` says so on the success arm; this guard narrows
# only what may be MEASURED, which is a different question with a different
# answer.  A plain string compare, for `_sheet_note`'s own three reasons
# (issues 1327, 1329, row BT22) -- and its cost is the same one: a sheet opened
# through a symlink mints nothing and is refused.  Empty in the empty
# direction.
proc rdw::_subject_devpath {subject} {
    set src {}
    catch {set src [dict get $subject schname]}
    if {$src eq {}} { return {} }
    set now {}
    catch {set now [xschem get schname]}
    if {$now eq {} || $src ne $now} { return {} }
    set inst {}
    catch {set inst [dict get $subject instname]}
    if {$inst eq {}} { return {} }
    set dp {}
    catch {set dp [::op_annot::devpath $inst]}
    return $dp
}

# CAN AN ADD OF THIS PARAMETER BE WRITTEN AT ALL?  {} when it can, the refusal
# sentence when it cannot (issue 1372).
#
# ⚠ IT EXISTS SO THE USER IS NOT CHARGED A MODAL FOR A REFUSAL.  MEASURED on
# their own bench: `rdw::button` raised `rdw::scope_dialog` FIRST and reached
# `rdw::_edit` only after it, so the user answered a two-part modal question --
# which devices, which list -- and was THEN told the whole thing was
# impossible, once, into a four-line status pane.  That is why the report reads
# "it never shows up" and not "it refused".
#
# ⚠ ONE RULE, TWO DOORS, WHICH IS `op_param_lists::reduce_why`'s AND
# `governs`' OWN SHAPE.  The rule is `rdw::_find_triple` returning {} and it is
# asked in exactly one place; this proc only words it, and `rdw::_edit` keeps
# its own call unchanged, so a caller reaching the decision core directly -- a
# key, a menu, a suite row -- gets the same verdict with the same sentence.
#
# ⚠ AND IT ANSWERS ONLY THE LIST-INDEPENDENT HALF.  "Already in the list" is
# the other way an Add is refused, and WHICH list is precisely what the dialog
# is being raised to ask -- so that one still costs a dialog, correctly: the
# answer determined it.
proc rdw::_add_why {subject param} {
    set cls {}
    catch {set cls [dict get $subject class]}
    if {$cls eq {} || $param eq {}} { return {} }
    set cell {}
    catch {set cell [dict get $subject cellname]}
    set dp [rdw::_subject_devpath $subject]
    if {[rdw::_find_triple $cls $cell $param $dp] ne {}} { return {} }
    if {$dp eq {}} {
        return "$param is in no list and no PDK descriptor declares it, and this block was dumped from another sheet, so this run cannot be asked what it calls the column. Press 3 over the device on the sheet it lives on, then Add."
    }
    return "$param is in no list, no PDK descriptor declares it, and this run published no column called $param for this device - so this window cannot tell which raw-name shape it has, and it will not guess one. A PDK declares it with op_annot::register."
}

# The STORE KEY a REORDER writes at: the flavor entry that actually GOVERNS
# this device, else the class entry, which ruling DD-2 makes the primary key.
# Up and Down raise NO dialog -- spec 4.2 B7 gives it to Delete and Add only,
# and a dialog per click makes reordering unusable -- so they have no answer to
# obey and must find the entry themselves.
#
# ⚠ IT ASKS `op_param_lists::governs`, AND THE QUESTION IT USED TO ASK WAS A
# DIFFERENT ONE (item B5-2, defect A6).  This proc used to ask exact-key
# `owns flavor {<cls> <cellname>}` while every READ of the same list goes
# through `effective`, which matches a cell-name GLOB.  MEASURED at HEAD with a
# flavor entry `{b5cls *b5n*}` governing cell `devices/b5n`:
#     effective b5cls annotation devices/b5n     -> the FLAVOR list
#     owns flavor {b5cls devices/b5n} annotation -> 0
# so the reorder answered "no flavor entry", wrote the CLASS entry, and left
# the user looking at a pane whose order did not move while the status line
# said it had.  ONE narrowing with TWO lookalike definitions is invariant I1's
# exact failure shape, so the scan now has one home in the store and this file
# is a consumer of it.  Fenced by window row BT25 and store rows BG1/BG2.
proc rdw::_scope_for {cls listname cell} {
    set g {}
    catch {set g [::op_param_lists::governs $cls $listname $cell]}
    if {[llength $g] == 2 && [lindex $g 0] eq {flavor}} {
        return [list flavor [lindex $g 1]]
    }
    return [list class $cls]
}

# THE ONE BUILDER OF THE STORE KEY AN EDIT WRITES AT -- {<scope> <key>}, the
# two arguments `op_param_lists::set_list` takes, or {} when this scope cannot
# name one for this device.
#
# ⚠ IT EXISTS BECAUSE TWO CALLERS NOW NEED THE SAME ANSWER, AND A SECOND
# DERIVATION OF IT IS INVARIANT I1's TWO-BUILDERS DRIFT.  `rdw::_edit` needs
# the key to WRITE at; `rdw::_reorder_shown` needs it to decide which stored
# blocks the write actually REACHED.  Before issue 1348 only the first existed
# and the second re-slotted every block of the class -- so a press whose own
# sentence said "for cells matching <glob>" visibly reordered a block of a
# DIFFERENT cell, one the flavor entry does not match and the write never
# touched.  MEASURED, three blocks, a flavor entry on M1's cell only:
#     class annotation list   ids gm gds  ->  ids gm gds   (unmoved, correctly)
#     flavor list             ids gm gds  ->  ids gds gm
#     M1's block              ids gds gm  ->  ids gds gm   (its own list)
#     M2's block              gm  ids     ->  ids gm       <- NOBODY ASKED
#
# ⚠ AND `broad` IS NOT `class` BY ACCIDENT ON THE OTHER SIDE EITHER.  A broad
# write over a device a flavor entry governs really does change the class list
# and really does NOT reach that device -- which is the sentence
# `rdw::_shadow_why`'s broad arm already says out loud.  Comparing this key
# against each block's own `_scope_for` is what makes the pane agree with that
# sentence instead of contradicting it.
proc rdw::_write_key {cls cell listname scope} {
    if {$scope eq {narrow}} {
        if {$cell eq {}} { return {} }
        return [list flavor [list $cls $cell]]
    }
    if {$scope eq {broad}} { return [list class $cls] }
    ## `governing` -- Up and Down, which raise no dialog and so have no answer
    ## to obey.
    return [rdw::_scope_for $cls $listname $cell]
}

# WHAT A REORDER OF THIS LIST DOES **NOT** DO TO THE SHEET (issue 1347).
#
# ⚠ THE SUMMARY LIST HAS NO ORDER ON THE SHEET, AND THAT IS STRUCTURAL, NOT A
# BUG IN THIS WINDOW.  `op_annot::text` (src/op_annot.tcl) draws the
# descriptor's `shown` key; `op_param_lists::_show_set` builds `shown` by
# filtering `params` -- the annotation+summary UNION -- by the labels of
# `effective $cls ANNOTATION`, in union order, and `_save_set` lays the union
# out annotation-first.  So every drawn row takes its position from the
# ANNOTATION list, and a row the summary list alone carries is not drawn at
# all.  MEASURED, two accepted Up presses on the summary list:
#     store summary   ids gm gds  ->  gds ids gm
#     the pane        ids gds gm  ->  gds ids gm
#     op_annot::text  "id =\ngm =\ngds =\n"  BYTE-IDENTICAL
# while `xschem get annot_overlay_flushes` moved +2, because
# `op_annot::register` bumps the epoch on any re-register.
#
# ⚠ SO THE COUNTER IS NOT THE SHEET, AND ROW RE7 GOLDS THE COUNTER.  RE7's own
# title is true -- the schematic IS asked to re-render -- but it cannot see
# that the answer came back the same, and DD-4's "lists 1 and 2 re-render the
# schematic" was read as though it could.  Row RE8 golds `op_annot::text`'s
# STRING for both legs and is the fence that would have caught this.
#
# ⚠ THE EDIT IS NOT REFUSED AND THE PANE STILL FOLLOWS IT.  The user's words
# for item R2 are "reflected in the Results Display Window as well as the
# schematic annotation - if applied to annotation params (1 key) or summary
# list (2 key)", so the WINDOW half is owed for list 2 and is delivered; what
# cannot be delivered without deciding what the SHEET draws is the other half,
# and a window that quietly showed one order while the sheet drew another is
# the contradiction this clause removes.  Whether list 2 should reach the sheet
# at all is an E question the user has not answered -- issue 1347, rule debt
# `1347_R2_summary_order_on_the_sheet`.
#
# ONE CLAUSE, ON THE REORDER ARM ONLY.  Delete and Add on the summary list
# promise nothing about drawn ORDER, so their sentences are already complete
# and true; R2 is the item that promises the schematic follows, which is the
# same argument row RE6 makes for issue 1330.
# WHERE THE TRIPLE CAME FROM, SAID ONCE, ON THE MINT ARM ONLY (issue 1372).
#
# ONE CLAUSE, ON AN ADD THAT MINTED, and `rdw::_drawn_note`'s discipline
# exactly.  A triple taken from a DECLARATION carries the PDK's own label and
# kind and needs no clause -- that is the ordinary case and a sentence on every
# press is noise.  A MINTED one carries the shape THIS RUN published, which is
# a different fact, is the whole of what issue 1372 changed, and is the one
# thing the user would otherwise have to take on trust.
#
# ⚠ IT RE-ASKS THE RULE RATHER THAN BEING TOLD.  `rdw::_find_triple` with no
# devpath is the three DECLARED lookups and nothing else, so "all three were
# silent" is asked here in the same words it is asked in the decision -- a
# boolean threaded down from the add arm would be a second statement of the
# same rule, and it is the kind that rots without a row noticing.
#
# ⚠ AND IT MUST THEREFORE BE ASKED BEFORE THE WRITE, WHICH IS WHY THE CALL SITE
# IS THE ADD ARM AND NOT THE PLACE THE CLAUSE IS APPENDED.  `set_list` puts the
# minted triple INTO the very list `effective` reads, so the same question
# asked one line after the store call answers "declared" for every accepted Add
# and this clause would be dead on every press -- vacuous, and green.
proc rdw::_mint_note {op cls cell param} {
    if {$op ne {add}} { return {} }
    if {[rdw::_find_triple $cls $cell $param] ne {}} { return {} }
    return {No list and no PDK descriptor declares it, so the raw-name shape was read from what this run published.}
}

proc rdw::_drawn_note {op listname} {
    if {$op ne {up} && $op ne {down}} { return {} }
    if {$listname ne {summary}} { return {} }
    return {The schematic draws the annotation list, so what it draws did not move - press 1 and reorder there to change the sheet.}
}

# ---------------------------------------------------------------------------
# DID THE WRITE ACTUALLY REACH THE DEVICE THE USER IS LOOKING AT?
#
# ⚠ ONE CHECK, THREE ARMS, THREE SENTENCES (item B5-2, defect A6's second
# half).  The preserved patch ran ruling DD-8's shadow warning on the NARROW
# arm only, so a BROAD write over a device a flavor glob governs reported a
# bare success about rows that did not move -- the user presses Delete, the
# class list really does change, and the row stays on the sheet with nothing
# said.  The comparison is `get_list` of the key just written against
# `effective` for this cell, NOT against the list we asked for: the store
# legitimately reduces a list by label (issue 1288), and comparing against the
# request would fire this warning on a write that landed perfectly.
#
# ⚠ AND THE BROAD BASE IS STILL THE CLASS LIST.  Taking the base from
# `effective $cls $listname $cell` -- which is the obvious way to give the
# broad arm the cell -- would write the FLAVOR list's rows into the CLASS key
# and destroy every class row the flavor entry does not carry.  That is ruling
# DD-7's failure, the one that reverted item B2a twice.  So the cell reaches
# the broad arm HERE, after the write, and never as its base.
proc rdw::_shadow_why {scope cls listname cell skey key} {
    if {$cell eq {}} { return {} }
    set now {}
    set mine {}
    catch {set now  [::op_param_lists::effective $cls $listname $cell]}
    catch {set mine [::op_param_lists::get_list $skey $key $listname]}
    if {$now eq $mine} { return {} }
    set glob {}
    set g {}
    catch {set g [::op_param_lists::governs $cls $listname $cell]}
    if {[llength $g] == 2 && [lindex $g 0] eq {flavor}} {
        set glob [lindex [lindex $g 1] 1]
    }
    set which [expr {$glob eq {} ? {an entry} : "the device-flavor entry $glob"}]
    if {$scope eq {broad}} {
        return "The [::op_param_lists::class_label $cls] class list moved, but $which in the settings file also matches this cell and wins for it, so this device's own rows did not change - precedence is file order."
    }
    if {$scope eq {narrow}} {
        # RULING DD-8: PRECEDENCE IS FILE ORDER AND NOTHING IS RANKED.  A
        # narrow write is a NEW row, so an entry declared EARLIER whose glob
        # also matches this cell still wins -- and the honest answer is to say
        # which order to fix, not to let the button look dead.  Filed as issue
        # 1311: the pane shows parameter rows, not flavor entries, so this
        # window's own Up/Down cannot reorder the entries whose precedence
        # this is.
        return "But $which declared earlier in the settings file also matches this cell and still wins - precedence is file order, so move this entry above it."
    }
    return "But $which in the settings file wins for this cell - precedence is file order, so move this entry above it."
}

# RULING DD-10, AND IT IS THE USER'S OWN SENTENCE.  Both alternatives the
# question offered are bad: an emptied annotation list makes the whole OP block
# vanish, which drops the device out of the declutter (ruling D-6 gates on
# "instances that got OP numbers"), so every W/L and pin label the declutter was
# hiding comes back at once -- the user pressed Delete to see less and got more;
# and treating an empty list as "no narrowing" makes Delete a silent no-op.
#
# ⚠ IT APPLIES TO BOTH LISTS, WITH TWO DIFFERENT SENTENCES.  The ruling's text
# is unqualified so the refusal is unqualified, but its ARGUMENT is
# annotation-specific -- an emptied summary list breaks no declutter -- so one
# sentence for both would be false about the summary case, and this feature's
# own obligation is that different facts get different sentences.
proc rdw::_last_row_why {base listname param} {
    if {[catch {llength $base} n]} { return {} }
    if {$n > 1} { return {} }
    if {$listname eq {annotation}} {
        return {at least one parameter must stay. To stop showing operating-point values on this device, turn the annotation off instead.}
    }
    return "$param is the only row left in the summary list, and at least one parameter must stay. Add another before removing this one."
}

# What the STORE said about the call just made, or a fallback.  Read as the
# TAIL of `said` rather than the whole of it, so a report from earlier in the
# session is not repeated and a `said_clear` from anywhere destroys nothing.
# ⚠ THE STORE'S OWN WORDING, NEVER A SECOND ONE FOR THE SAME FACT: two
# wordings for one failure is how a user learns to distrust both.
proc rdw::_store_tail {before fallback} {
    set tail {}
    catch {set tail [lrange [::op_param_lists::said] $before end]}
    if {[llength $tail]} { return [join $tail { }] }
    return $fallback
}

# RULING DD-16 -- THE SOURCE SHEET, NAMED ONLY WHEN IT IS NOT THE OPEN ONE.
#
# A block carries the sheet it was dumped from (item B5-a, issue 1322:
# `rdw::_capture_subject` stamps `schname` at DUMP time and `rdw::block_subject`
# reads it back).  The user can therefore edit, an hour later and on a different
# sheet, a block dumped from a device that is no longer on screen.
#
# ⚠ THE EDIT IS NOT REFUSED, AND THAT IS THE RULING'S OWN ARGUMENT.  The three
# lists are CLASS- and FLAVOR-level settings, not sheet state -- a block says
# "this dump was about an nfet of class mos", and editing the mos list is a
# global action that is correct regardless of which sheet happens to be in
# front.  The window deliberately keeps its dumps across a close (`rdw::close`'s
# own comment) precisely so they can be worked with later, so refusing here
# would block a legitimate edit for a reason the user would find arbitrary.
#
# ⚠ AND THE SENTENCE IS CONDITIONAL, NOT UNCONDITIONAL.  In the common case the
# source sheet IS the open one, and saying so is noise on every press.  The
# clause earns its place exactly when the two differ -- which is the case a user
# could otherwise misread, and which, before issue 1322 was fixed, silently
# edited the wrong device.
#
# ⚠ AN ABSENT OR EMPTY `schname` MEANS DO NOT NAME THE SHEET.  A block whose
# device could not be resolved at dump time is never stamped (`_capture_subject`
# refuses {} and `missing`), and a hand-built subject dict -- which is what the
# suites' own fixtures pass -- carries no `schname` key at all.  MEASURED:
# `dict get` on such a dict RAISES, so an unguarded read here would raise from
# inside the decision core and refuse an edit that was working.  Invariant I3's
# spirit one layer out: a missing datum renders blank, never a wrong assertion.
#
# ⚠ THE COMPARISON IS A PLAIN STRING COMPARE.  NOT `file normalize`: issue
# 1327 established it does not resolve a path's final component, so it
# establishes no file identity anyway, and it puts a filesystem call in a status
# path.  NOT `op_param_lists::_fid`: that is a PRIVATE store verb and row BT22
# golds that this file names no private one.  Both values come from the same
# `xschem get schname` accessor, which is why no existing row moves.
#
# ⚠ AND A STRING COMPARE IS NOT FILE IDENTITY -- ISSUE 1329.  An earlier draft
# of this comment claimed the two values "are byte-identical whenever they name
# the same sheet -- measured directly".  THAT IS FALSE, and item B5-3's
# adversary measured the counter-example: one sheet opened through a SYMLINK
# yields two different strings, so this proc emits the clause for a sheet that
# IS the open one.  The choice stands because both alternatives above are worse
# from THIS file; the fix is a PUBLIC `op_param_lists::same_file` wrapping
# `_fid`, added to BT22's allow-list.  Blast radius is one wrong advisory
# sentence and never a wrong write -- DD-16 rules the cross-sheet edit ALLOWED,
# so this clause is advice, not a gate.
#
# A named callee rather than three lines inline, following `rdw::_tier_note`
# just below and for the same reason: a reviewer can neutralise exactly this
# sentence and watch one row say so.
proc rdw::_sheet_note {subject} {
    set src {}
    catch {set src [dict get $subject schname]}
    if {$src eq {}} { return {} }
    set now {}
    catch {set now [xschem get schname]}
    if {$now eq {}} { return {} }
    if {$src eq $now} { return {} }
    return "That dump was taken on $src, which is not the sheet now open - these are class and device-flavor settings, not sheet state, so the edit applies wherever you are standing."
}

# THE ENTRY ONE PRESS WILL WRITE, WHAT IS IN IT NOW, AND HOW TO NAME IT.
#
# Factored out of `rdw::_edit`, whose head this used to be, so that a multi-row
# press can ask it ONCE for the whole batch (item: multi-row Add and Delete).
# The batch needs all three answers before it touches anything: `base` is what
# ruling DD-10's last-row question is asked of -- and asked of the BATCH, not
# of each row in turn, or the user deletes five rows and is refused on the
# sixth with five already gone -- and `where` is the scope phrase its one
# sentence ends in.
#
# ⚠ IT IS NOT A SECOND DEFINITION OF THE KEY.  Every branch here calls
# `rdw::_write_key`, the same builder `rdw::_edit` wrote at before this split
# and the same one `rdw::_reorder_shown` and `rdw::_rebuild_class` compare
# against, so the pane cannot follow an entry the press did not touch.  The
# `governing` arm is Up and Down's, which raise no dialog and so have no answer
# to obey: they write at whatever entry governs this device today, because a
# reorder whose only effect is invisible is a broken button.
#
# The two NARROW refusals stay in `rdw::_edit`.  They are refusals of an edit,
# not properties of a target, and a batch has to be able to report them per row.
proc rdw::_edit_target {cls cell listname scope} {
    set dcls [::op_param_lists::class_label $cls]
    if {$scope eq {governing}} {
        set g [rdw::_write_key $cls $cell $listname governing]
        if {[lindex $g 0] eq {flavor}} {
            return [list [lindex $g 0] [lindex $g 1] \
                [::op_param_lists::effective $cls $listname $cell] \
                "for cells matching [lindex [lindex $g 1] 1] of class $dcls"]
        }
        return [list [lindex $g 0] [lindex $g 1] \
            [::op_param_lists::effective $cls $listname] "for class $dcls"]
    }
    if {$scope eq {narrow}} {
        set g [rdw::_write_key $cls $cell $listname narrow]
        return [list [lindex $g 0] [lindex $g 1] \
            [::op_param_lists::effective $cls $listname $cell] \
            "for cell $cell only"]
    }
    set g [rdw::_write_key $cls $cell $listname broad]
    return [list [lindex $g 0] [lindex $g 1] \
        [::op_param_lists::effective $cls $listname] "for class $dcls"]
}

# ---------------------------------------------------------------------------
# THE MULTI-ROW PRESS (the user's ruling, issue 1356 answered the other way)
# ---------------------------------------------------------------------------
# THE USER'S WORDS: "When multiple lines of parameters are selected and user
# presses Add or Delete, those should get processed the same way that a single
# line would get processed."
#
# So this proc runs the batch through `rdw::_edit`, N times, unchanged -- it
# does NOT reimplement the edit.  Everything it adds is a property of the BATCH
# that no single row can answer for:
#
#   1. RULING DD-10 IS ASKED UP FRONT.  `_last_row_why` refuses a Delete that
#      would empty a list, and asking it per row would delete N-1 and refuse
#      the last, with no undo in this window.  `rdw::_batch_last_row_why` asks
#      it of the whole batch against the base as it stands BEFORE the first
#      write.
#   2. ONE SENTENCE FOR N OUTCOMES.  Every row that changed is named, and so is
#      every row that did not, with the core's OWN refusal for each -- so a
#      partial batch is legible rather than a silent count.
#   3. THE TAIL CLAUSES ARE COMPUTED ONCE, through the same named callees
#      `rdw::_edit` uses (`_sheet_note`, `_shadow_why`, `_percell_note`,
#      `_store_tail`), because they are properties of the scope and the list
#      and not of a row -- and because two wordings for one fact teach the
#      reader to distrust both.
#
# ⚠ A BATCH OF ONE NEVER REACHES HERE.  `rdw::button` calls `rdw::_edit`
# directly for a single row, so every sentence the suites gold byte-for-byte is
# produced by exactly the code that produced it before this item.
proc rdw::_batch_edit {op subject listname scope params} {
    ## ⚠ EVERY REFUSAL IN THIS FILE CARRIES A SENTENCE.  `rdw::button` never
    ## reaches here with an empty batch -- it routes 0 and 1 rows to the core --
    ## but a key, a menu or a suite row calling this directly must not be able
    ## to produce `{refused {}}`, which the status line would print as a bare
    ## label and the user would read as the window failing silently.
    if {![llength $params]} {
        return [list refused "no parameter row was selected, so there is nothing to [expr {$op eq {delete} ? {remove} : {add}}]."]
    }
    set cls  [dict get $subject class]
    set cell [dict get $subject cellname]
    ## THE TARGET ONCE.  `_edit` asks for it again per row, which is correct --
    ## the base moves under a batch as rows are removed -- but the key, the
    ## scope phrase and the base DD-10 is asked of are all read here, before
    ## anything is written.
    lassign [rdw::_edit_target $cls $cell $listname $scope] skey key base where
    if {$op eq {delete}} {
        set why [rdw::_batch_last_row_why $base $listname $params]
        if {$why ne {}} { return [list refused $why] }
    }
    ## ⚠ WHICH ROWS HAD TO BE READ OFF THE RUN, TAKEN BEFORE THE FIRST WRITE.
    ## `rdw::_mint_note` asks `_find_triple`, which reads the very lists this
    ## loop is about to change -- so asked after row 1 was added, row 2 would
    ## be reported as declared by a list that had just been given the answer.
    set minted {}
    if {$op eq {add}} {
        foreach p $params {
            if {[rdw::_mint_note $op $cls $cell $p] ne {}} { lappend minted $p }
        }
    }
    set before 0
    catch {set before [llength [::op_param_lists::said]]}
    set done {} ; set skipped {} ; set reasons {}
    foreach p $params {
        lassign [rdw::_edit $op $subject $listname $scope $p] v sent
        if {$v eq {ok}} {
            lappend done $p
        } else {
            lappend skipped $p ; lappend reasons $sent
        }
    }
    ## NOTHING CHANGED IS A REFUSAL, not a success with an empty list -- the
    ## caller must not repaint, must not apply and must not claim an edit.
    if {![llength $done]} {
        if {[llength $skipped] == 1} { return [list refused [lindex $reasons 0]] }
        return [list refused [rdw::_batch_skipped_say \
            "nothing was [expr {$op eq {delete} ? {removed} : {added}}]" \
            $skipped $reasons]]
    }
    if {$op eq {delete}} {
        set say "removed [rdw::_and_list $done] from the $listname list $where."
    } else {
        set say "added [rdw::_and_list $done] to the $listname list $where."
    }
    ## The STORE's own report for the whole batch, read as the tail of `said`
    ## exactly as `rdw::_edit` reads its own -- issue 1288's ruling, told once.
    set told [rdw::_store_tail $before {}]
    if {$told ne {}} { append say " $told" }
    set sheet [rdw::_sheet_note $subject]
    if {$sheet ne {}} { append say " $sheet" }
    set mint [rdw::_batch_mint_note $minted $done]
    if {$mint ne {}} { append say " $mint" }
    if {[llength $skipped]} {
        set n [llength $skipped]
        append say " [rdw::_batch_skipped_say \
            [expr {$n == 1 ? {One row was not changed} : "$n rows were not changed"}] \
            $skipped $reasons]"
    }
    set shadow [rdw::_shadow_why $scope $cls $listname $cell $skey $key]
    if {$shadow ne {}} { append say " $shadow" }
    set percell [rdw::_percell_note $scope $cls]
    if {$percell ne {}} { append say " $percell" }
    return [list ok $say]
}

# ISSUE 1372's CLAUSE, FOR A BATCH.  Only the rows that were actually added
# count -- a row the store refused was not given a raw-name shape by anything.
# One row keeps `rdw::_mint_note`'s own sentence, byte for byte.
proc rdw::_batch_mint_note {minted done} {
    set m {}
    foreach p $minted { if {[lsearch -exact $done $p] >= 0} { lappend m $p } }
    if {![llength $m]} { return {} }
    if {[llength $m] == 1} { return [rdw::_mint_note add {} {} {}] }
    return "No list and no PDK descriptor declares [rdw::_and_list $m], so their raw-name shapes were read from what this run published."
}

# THE ROWS THAT DID NOT CHANGE, WITH THE CORE'S OWN REASON FOR EACH.
#
# ⚠ A COUNT WOULD BE THE DEFECT THIS ITEM REMOVES.  "3 rows were not changed"
# tells the user that something silently did not happen and gives them no way
# to find out what -- which is the shape of the report the user filed as
# "Delete is not affecting the current display".  The reasons come from
# `rdw::_edit`, so there is no second wording of any of them.
#
# The pane is four lines, so the reasons are capped: two are quoted in full and
# the rest are named without one, which still tells the reader exactly WHICH
# rows to press again one at a time to see why.
proc rdw::_batch_skipped_say {lead skipped reasons} {
    if {![llength $skipped]} { return {} }
    set n [llength $skipped]
    set head [lrange $skipped 0 1]
    set out {}
    foreach p $head r [lrange $reasons 0 1] { lappend out "$p: $r" }
    set say "$lead - [join $out { }]"
    if {$n <= 2} { return $say }
    set rest [lrange $skipped 2 end]
    set verb [expr {[llength $rest] == 1 ? {was} : {were}}]
    set which [expr {[llength $rest] == 1 ? {it} : {one of them}}]
    return "$say [rdw::_and_list $rest] $verb not changed either; press $which alone to see why."
}

# ---------------------------------------------------------------------------
# THE DECISION CORE.  It performs the store call and returns
# {ok|refused <sentence>}, and it touches no Tk -- so every sentence and every
# refusal in this feature is asserted on the --nogui arm.  Copied in shape from
# `nhse_save_announce` (xschem.tcl:1409), which factors the branch and the
# exact sentence out of the widget call for the same reason.
proc rdw::_edit {op subject listname scope param} {
    set cls  [dict get $subject class]
    set cell [dict get $subject cellname]
    ## ⚠ `$cls` IS THE STORE KEY AND `$dcls` IS THE PROSE, AND THEY ARE NOT
    ## INTERCHANGEABLE (issue 1373).  Every `::op_param_lists::` call below
    ## keeps taking `$cls`; every sentence takes `$dcls`.  The key is what the
    ## user types into a settings file and is compared with `eq`, so writing
    ## the display name into a key would mint a dead entry.
    set dcls [::op_param_lists::class_label $cls]
    if {$scope eq {narrow}} {
        ## ⚠ THE TWO REFUSALS BELOW POINT AT A BUTTON, so their class wording
        ## must be BYTE-IDENTICAL to `rdw::scope_dialog_build`'s `.sc.broad`
        ## -text (issue 1373).  Both sides call `class_label`; a literal on
        ## either side names a radiobutton that does not exist by that name.
        ## Row CL8 is the fence.
        if {$cell eq {}} {
            return [list refused "this device's symbol has no cell name, so there is no device-flavor entry to write. Choose every device of class $dcls instead."]
        }
        ## ⚠ A NARROW KEY IS A GLOB, AND NOT EVERY CELL NAME IS A GLOB THAT
        ## MATCHES ITSELF (item B5-2).  The flavor key is stored verbatim and
        ## later matched with `string match -nocase`, so MEASURED: `a[bc].sym`
        ## and `a\b.sym` do NOT match themselves.  Written anyway, the entry
        ## would answer nothing for the very device it was minted for -- and
        ## `rdw::_shadow_why` would then fire ruling DD-8's sentence, blaming
        ## "an entry declared earlier in the settings file" that does not
        ## exist.  One wrong sentence produced by the code written to remove
        ## another.  Refuse up front, name the class-wide alternative, and
        ## store nothing.  `a*b.sym` and `a?b.sym` DO self-match but also match
        ## siblings; that residual is filed as issue 1321, not fixed here --
        ## this guard cannot tell a deliberate glob from a literal, and
        ## refusing every cell name containing `*` would refuse a legal
        ## filename for a case nobody has hit.
        if {![string match -nocase $cell $cell]} {
            return [list refused "the cell name $cell contains glob characters, and a device-flavor entry is matched as a glob - a key written from it would never match this device again. Choose every device of class $dcls instead."]
        }
    }
    ## ⚠ THE KEY, THE BASE AND THE `where` PHRASE COME FROM ONE PLACE (item:
    ## multi-row Add and Delete).  A BATCH has to ask the identical question
    ## once -- which entry will be written, what is in it now, and how to name
    ## the scope in its own sentence -- and a second copy of this arithmetic
    ## here would be two definitions of "which entry does this press write",
    ## which is invariant I1's exact failure shape and the defect
    ## `rdw::_scope_for` was written to remove.  The two narrow refusals above
    ## stay HERE, because they are refusals of an EDIT, not properties of a
    ## target: a batch reports them per row, through this same door.
    lassign [rdw::_edit_target $cls $cell $listname $scope] skey key base where
    set mint {}
    set i [rdw::_index_of $base $param]
    set notin "$param is not in the $dcls $listname list. The pane also shows rows this run published that no list declares, and only the list's own rows can be edited here."
    ## ⚠ AND ON THE BROAD ARM IT IS NOT ALWAYS TRUE.  The broad base is the
    ## CLASS list, which for a device a flavor entry governs is NOT the list
    ## the pane's rows came from -- so a row the user can plainly see would be
    ## reported "not in the list".  Name the flavor entry and the narrow choice
    ## instead: the fact is different, so the sentence is different.
    if {$i < 0 && $scope eq {broad} && $cell ne {}} {
        set seen {}
        catch {set seen [::op_param_lists::effective $cls $listname $cell]}
        if {[rdw::_index_of $seen $param] >= 0} {
            set notin "$param is in this device's own $listname list but not in the $dcls class list, so a class-wide change cannot reach it. Choose this device flavor only instead."
        }
    }
    switch -exact -- $op {
        up -
        down {
            if {$i < 0} { return [list refused $notin] }
            if {$op eq {up} && $i == 0} {
                return [list refused "$param is already the first row of the $dcls $listname list."]
            }
            if {$op eq {down} && $i == [expr {[llength $base] - 1}]} {
                return [list refused "$param is already the last row of the $dcls $listname list."]
            }
            set j [expr {$op eq {up} ? $i - 1 : $i + 1}]
            set new [lreplace $base $i $i [lindex $base $j]]
            set new [lreplace $new $j $j [lindex $base $i]]
            ## ⚠ A REORDER MUST NOT BECOME A DELETION (issue 1323, rulings
            ## DD-4 and DD-6).  `op_annot::register` accepts a declaration
            ## carrying two triples that share a LABEL; `seed` returns it
            ## undeduped and `effective` hands it out as the base above -- but
            ## `set_list` keeps ONE entry per label, so the list comes back
            ## SHORTER than it went in and `op_annot::_cards_for` stops
            ## emitting a `.save` card the deck was asking for.  MEASURED at
            ## HEAD with no button code at all: an UP press turned
            ##     {id ids 0} {id vgs 2} {gm gm 1}  into  {id ids 0} {gm gm 1}
            ## and `m1[vgs]` vanished from the deck.  DD-4/DD-6 say a display
            ## decision NEVER changes what the simulator is asked to save, and
            ## an Up press is not even a Delete.
            ##
            ## ⚠ IT GUARDS THE REORDER AND NOTHING ELSE, AND THAT IS A
            ## MEASUREMENT, NOT A PREFERENCE.  A reorder is DEFINITIONALLY
            ## length-preserving, so a shortening one is unambiguously a
            ## defect.  Delete and Add are not: ruling DD-10 governs Delete's
            ## last row, and issue 1288 RULED that an Add whose triple collides
            ## by label is ACCEPTED, replaces the earlier row in place and
            ## tells the user once -- which row BT27 golds by name.  Refusing
            ## them here would be a THIRD door with a THIRD rule, which is the
            ## disagreement issue 1288 exists to remove.  The residual -- a
            ## Delete on a duplicate-label DECLARATION drops two display rows
            ## -- was filed as issue 1326 and is now FIXED, one door further
            ## back: ruling DD-15 makes `op_annot::register` refuse a
            ## declaration carrying two triples that share a display label, so
            ## the ambiguity is rejected where it is created and never reaches
            ## a button.  This guard stays as the SECOND door, because DD-15
            ## cannot shut `::op_annot::desc` against a fixture or an older
            ## session's stored state -- one rule, two doors, which is the
            ## principle DD-15 itself names.
            ##
            ## ⚠ AND IT RUNS BEFORE THE WRITE.  Issue 1323's own recommended
            ## wording was to check afterwards and restore the base; that
            ## cannot restore, because a `set_list` of the base dedupes it
            ## identically -- storing a THIRD value neither the user nor the
            ## PDK chose -- and a base that came from the SEED left the key
            ## UNOWNED, which no verb in this store can undo.
            ##
            ## The STORE owns the sentence (`op_param_lists::reduce_why`, the
            ## `governs` precedent: one rule, a second reader); this file mints
            ## no second wording for a fact the store already words.
            set drop {}
            catch {set drop \
                [::op_param_lists::reduce_why $skey $key $listname $new]}
            if {$drop ne {}} { return [list refused $drop] }
            set did "moved $param $op in the $listname list"
        }
        delete {
            if {$i < 0} { return [list refused $notin] }
            set why [rdw::_last_row_why $base $listname $param]
            if {$why ne {}} { return [list refused $why] }
            set new [lreplace $base $i $i]
            set did "removed $param from the $listname list"
        }
        add {
            if {$i >= 0} {
                return [list refused "$param is already in the $dcls $listname list."]
            }
            ## ⚠ THE DECLARED LOOKUPS FIRST, THE RUN ONLY WHEN THEY ARE ALL
            ## SILENT (issue 1372).  `rdw::_subject_devpath` is what decides
            ## whether the run may be read at all -- it refuses a block dumped
            ## from another sheet -- and `rdw::_find_triple` is the one rule
            ## `rdw::_add_why` words for the pre-dialog door.  This check is
            ## NOT removed in favour of that one: a key, a menu or a suite row
            ## reaching this core directly must get the same verdict with the
            ## same sentence, which is `op_param_lists::governs`' own
            ## one-rule-two-doors shape.
            set t [rdw::_find_triple $cls $cell $param \
                        [rdw::_subject_devpath $subject]]
            if {$t eq {}} {
                return [list refused [rdw::_add_why $subject $param]]
            }
            ## ⚠ BEFORE THE STORE CALL.  `rdw::_mint_note`'s own comment
            ## says why: the write lands in the list `effective` reads.
            set mint [rdw::_mint_note $op $cls $cell $param]
            set new [linsert $base end $t]
            set did "added $param to the $listname list"
        }
        default { return [list refused "there is no such edit."] }
    }
    set before 0
    catch {set before [llength [::op_param_lists::said]]}
    if {![::op_param_lists::set_list $skey $key $listname $new]} {
        return [list refused [rdw::_store_tail $before \
            "the list store refused that change and said nothing about why."]]
    }
    set say "$did $where."
    ## ⚠ THE STORE'S OWN REPORT IS READ ON THE SUCCESS ARM TOO (item B5-2,
    ## defect A7).  `set_list` returns 1 WITH A REPORT when it REDUCED the list
    ## by LABEL -- issue 1288's ruling, "the two doors reach the same verdict
    ## with the same sentence and the user is told once".  MEASURED at HEAD:
    ## adding `{id vgs 2}` to `{{id ids 0} {gds gds 1}}` returns 1, reports
    ## `the later one replaces it in place`, and the untouched `ids` row is
    ## GONE.  IHP's shipped `{id ids 0}` is exactly that label != param shape,
    ## so this is not a synthetic case.  The preserved patch read the report
    ## only on the rc=0 arm, which told the user zero times in the one case the
    ## ruling exists for.  ⚠ AND THE ADD IS NOT REFUSED: a third door with a
    ## third rule is the disagreement issue 1288 is about.
    set told [rdw::_store_tail $before {}]
    if {$told ne {}} { append say " $told" }
    ## RULING DD-16, ON THE SUCCESS ARM ONLY, AND AT EXACTLY ONE PLACE so all
    ## three `ok` returns below carry it and no refusal arm does.  A refusal
    ## changed nothing, so the false belief this clause corrects never forms --
    ## the same argument `rdw::_do_save` makes for `_tier_note`, and the nine
    ## refusal sentences above are already complete and true without it.
    set sheet [rdw::_sheet_note $subject]
    if {$sheet ne {}} { append say " $sheet" }
    ## ISSUE 1347, AND IT SITS HERE FOR RULING DD-16's OWN REASON: the success
    ## arm only, at exactly one place, so all three `ok` returns below carry it
    ## and no refusal arm does.  A refusal moved nothing, so the false belief
    ## it corrects never forms.
    set drawn [rdw::_drawn_note $op $listname]
    if {$drawn ne {}} { append say " $drawn" }
    ## ISSUE 1372, APPENDED HERE FOR THE SAME REASON THE TWO CLAUSES ABOVE
    ## ARE: the success arm only, at exactly one place, so all three `ok`
    ## returns carry it and no refusal arm does.  It is COMPUTED in the add
    ## arm, before the store call -- see `rdw::_mint_note`.
    if {$mint ne {}} { append say " $mint" }
    set shadow [rdw::_shadow_why $scope $cls $listname $cell $skey $key]
    if {$shadow ne {}} { return [list ok "$say $shadow"] }
    set percell [rdw::_percell_note $scope $cls]
    if {$percell eq {}} { return [list ok $say] }
    return [list ok "$say $percell"]
}

# ISSUE 1310, STATED RATHER THAN DISCOVERED.  `apply` is per `type=` token and
# passes no cell name, and op_annot holds ONE descriptor per type, so a per-cell
# display list cannot be expressed at all without editing op_annot.tcl, which
# item B5 may not.  The entry is stored, written and honoured by `effective`;
# it does not reach the drawn sheet.
#
# A named callee, so the multi-row press can end in the SAME sentence rather
# than a second wording of it -- the rule this file follows everywhere: two
# wordings for one fact teach the reader to distrust both.
proc rdw::_percell_note {scope cls} {
    if {$scope ne {narrow}} { return {} }
    return "The sheet still draws the [::op_param_lists::class_label $cls] class list - a per-cell display list cannot be expressed yet (issue 1310)."
}

# Ruling DD-6, both halves, and the sibling types with it.
proc rdw::_apply_now {subject} {
    set t {}
    catch {set t [dict get $subject type]}
    ## ⚠ THE ORDER IS HARMLESS AND ITS OLD REASON IS DEAD (item B5-2).  This
    ## comment used to say the bare call MUST come first, because an
    ## explicit-token-first order would leave the subject's type carrying the
    ## union while its class SIBLINGS still carried the PDK's list, so the bare
    ## call that followed would reach `seed`, see two types of one class
    ## disagree, and report a divergence the caller had just created.  Ruling
    ## DD-13 (item B2e) made `seed` read the DECLARATION, which nothing but
    ## `op_annot::register` can write, so that route no longer exists:
    ## RE-MEASURED both orders on this tree, zero reports either way and
    ## `params` byte-identical on both type tokens.  The order is kept because
    ## it is not worth churning; the reason is gone, and a stale reason invites
    ## the next reader to "fix" the order on a false premise.
    ##
    ## WHAT DOES STILL HOLD is why there are two calls at all: a `type=` token
    ## the class map does not name is unreachable from the bare call (issue
    ## 1279), and the class's mapped SIBLINGS must follow, or `apply nmos`
    ## alone leaves every pmos on the sheet drawing the old list.
    ##
    ## ⚠ AND IT ANSWERS NOW, WHICH IS ISSUE 1330 (item R2).  This proc used to
    ## be three bare `catch`es and a bare `return {}`, so an `apply` that
    ## FAILED was invisible and both call sites reported the full success
    ## sentence.  MEASURED at HEAD 27122ca4 with `op_param_lists::apply`
    ## renamed to a proc that raises: an Up press still said "Up: moved gm up
    ## in the annotation list for class ...", with no hint that the sheet had
    ## not followed.
    ##
    ## That was harmless while nobody had been promised anything: until item R2
    ## this channel carried no claim about the schematic.  R2 is the item whose
    ## whole promise is that the annotation follows the reorder, so a swallowed
    ## failure is now a FALSE STATEMENT on a screen the user is reading -- the
    ## same class of defect as a refusal that repainted.  The caller decides
    ## what to do with the answer; this proc only stops eating it.
    ##
    ## TWO WAYS TO FAIL AND BOTH ARE REPORTED.  A RAISE is an exception and is
    ## quoted; a `_say` is the store's own worded report and is read as the
    ## TAIL of `said`, `rdw::_store_tail`'s rule exactly -- the store's wording
    ## and never a second one for the same fact.  MEASURED: an ordinary
    ## accepted press adds NOTHING to `said` across both applies, so the
    ## success sentence is byte-identical to the one this file emitted before
    ## (row RE6's third leg golds that it is not negated).
    set before 0
    catch {set before [llength [::op_param_lists::said]]}
    set err {}
    if {[catch {::op_param_lists::apply} err]} {
        return "The schematic annotation was not updated: $err"
    }
    if {$t ne {} && [catch {::op_param_lists::apply $t} err]} {
        return "The schematic annotation was not updated: $err"
    }
    set told [rdw::_store_tail $before {}]
    if {$told ne {}} {
        return "The schematic annotation was not updated: $told"
    }
    if {[catch {xschem redraw} err]} {
        return "The schematic annotation was not redrawn: $err"
    }
    return {}
}

# ---------------------------------------------------------------------------
# THE SCOPE DIALOG.

proc rdw::scope_dialog_build {op subject listname} {
    variable scope_choice
    variable list_choice
    catch {destroy .rdw.scope}
    set w [::toplevel .rdw.scope]
    wm title $w {Which devices?}
    wm transient $w .rdw
    catch {$w configure -background [rdw::color panel]}
    set inst {}
    catch {set inst [dict get $subject instname]}
    set cls {}
    catch {set cls [dict get $subject class]}
    set cell {}
    catch {set cell [dict get $subject cellname]}
    ::label $w.q -anchor w -justify left -background [rdw::color panel] \
        -text "[string totitle $op] on $inst: which devices should this change?"
    pack $w.q -side top -fill x -padx 8 -pady {8 4}
    ::frame $w.sc -background [rdw::color panel]
    ::radiobutton $w.sc.narrow -anchor w -variable ::rdw::scope_choice \
        -value narrow -background [rdw::color panel] \
        -text "this device flavor only ([expr {$cell eq {} ? {no cell name} : $cell}])"
    ::radiobutton $w.sc.broad -anchor w -variable ::rdw::scope_choice \
        -value broad -background [rdw::color panel] \
        -text "every device of class [::op_param_lists::class_label $cls]"
    pack $w.sc.narrow $w.sc.broad -side top -fill x
    pack $w.sc -side top -fill x -padx 16
    # THE SECOND LINE, AND IT IS NOW PRESENT IN ALL THREE STATES -- ISSUE 1355.
    #
    # ⚠ THE COMMENT THAT USED TO STAND HERE SAID "Lists 1 and 2 already name
    # it", AND THAT WAS THE DEFECT.  Nothing named it.  MEASURED on the user's
    # own M18: on annotation and on summary this dialog is BYTE-IDENTICAL and
    # the word `summary` appears nowhere in it -- which is their own sentence,
    # "it doesn't say 'summary list' - which would be good for the user to
    # know".  List 3 was the only state that named a list, and only because it
    # had to ASK.
    #
    # So list 3 keeps its QUESTION and lists 1 and 2 gain a STATEMENT in the
    # same slot, at the same widget path, with the same padding: the dialog
    # names a list in every state, and a reader who learns where to look on one
    # list finds it on the others.
    #
    # ⚠ THE STATEMENT NAMES THE LIST THE EDIT WILL WRITE, WHICH ON AN Add FROM
    # LIST 2 IS NOT THE LIST IN FORCE (spec 4.2 B7; see rdw::_edit_list).
    # Naming the identity would have printed "the summary list" over a write
    # into the annotation one.
    #
    # ⚠ AND BOTH GLOSSES COME FROM `rdw::_list_phrase`, THE SAME ACCESSOR THE
    # STATEMENT, THE CHROME LINE AND THE TITLE READ.  They were two literals
    # here; two wordings for one fact teach the reader to distrust both.
    set q2 [rdw::_scope_statement $op $listname]
    if {$listname eq {all}} { set q2 {And which list should it go into?} }
    if {$q2 ne {}} {
        ::label $w.q2 -anchor w -justify left -background [rdw::color panel] \
            -wraplength 520 -text $q2
        pack $w.q2 -side top -fill x -padx 8 -pady {8 4}
    }
    if {$listname eq {all}} {
        ::frame $w.li -background [rdw::color panel]
        ::radiobutton $w.li.annotation -anchor w -variable ::rdw::list_choice \
            -value annotation -background [rdw::color panel] \
            -text [rdw::_list_phrase annotation]
        ::radiobutton $w.li.summary -anchor w -variable ::rdw::list_choice \
            -value summary -background [rdw::color panel] \
            -text [rdw::_list_phrase summary]
        pack $w.li.annotation $w.li.summary -side top -fill x
        pack $w.li -side top -fill x -padx 16
    }
    ::frame $w.btns -background [rdw::color panel]
    ::button $w.btns.ok -text OK -width 8 \
        -command [list rdw::scope_dialog_done $w ok]
    ::button $w.btns.cancel -text Cancel -width 8 \
        -command [list rdw::scope_dialog_done $w cancel]
    pack $w.btns.cancel $w.btns.ok -side right -padx 4
    pack $w.btns -side bottom -fill x -pady 6 -padx 6
    # ase::ui::bind_dialog_esc's one line (ase_window.tcl:1580), and MEASURED
    # safe here: a child toplevel's bindtags are {.rdw.scope Toplevel all}, so
    # this cannot reach `.rdw`'s ruling DD-12 Escape and cannot end the canvas
    # command mode by accident.
    bind $w <Key-Escape> [list rdw::scope_dialog_done $w cancel]
    wm protocol $w WM_DELETE_WINDOW [list rdw::scope_dialog_done $w cancel]
    return $w
}

proc rdw::scope_dialog_done {w how} {
    variable scope_result
    variable scope_choice
    variable list_choice
    if {$how eq {ok}} {
        set scope_result [dict create scope $scope_choice list $list_choice]
    } else {
        set scope_result {}
    }
    catch {grab release $w}
    catch {destroy $w}
    return {}
}

# -> {scope narrow|broad list annotation|summary}, or {} for Cancel.
proc rdw::scope_dialog {op subject listname} {
    variable scope_result
    variable scope_choice
    variable list_choice
    # PRE-SET TO CANCEL, BEFORE THE BUILD.  A window destroyed by a deadman
    # timer or by a window manager never reaches scope_dialog_done, and a stale
    # result would then be read as an answer the user never gave.
    set scope_result {}
    set scope_choice broad
    ## ⚠ THROUGH THE ONE ACCESSOR (issue 1355).  This line used to read
    ## `[expr {$listname eq {all} ? {annotation} : $listname}]`, which answers
    ## `summary` for an Add made on the summary list -- a value that
    ## contradicts what `rdw::button` then writes, and which was inert only
    ## because the radio group exists on list 3 alone.  An inert wrong answer
    ## is one refactor away from a live one.
    set list_choice [rdw::_edit_list $op $listname]
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw]} { return {} }
    set prevfocus {}
    catch {set prevfocus [focus]}
    set w {}
    if {[catch {rdw::scope_dialog_build $op $subject $listname} w]} { return {} }
    catch {update}
    catch {raise $w}
    catch {grab set $w}
    ## ⚠ THE DIALOG TAKES THE KEYBOARD, AND A GRAB ALONE IS NOT ENOUGH.
    ## MEASURED: Tk REDIRECTS a keyboard event to the DISPLAY's focus window,
    ## not to the window the event names -- so with the canvas still holding
    ## the keyboard (rdw::_pick_seize ends in `focus -force $cv`), an Escape
    ## aimed at this dialog was delivered to the CANVAS instead and silently
    ## ENDED the user's command mode, while the dialog sat there waiting.  A
    ## grab stops the pointer reaching other windows; it does not move the
    ## keyboard.  `-force`, because the focus we are taking it from was itself
    ## taken with `-force` and a plain `focus` cannot cross toplevels.
    ##
    ## ⚠ AND IT IS HANDED STRAIGHT BACK.  This is the one place in this file
    ## that takes the keyboard, so it is the one place that must give it back:
    ## the canvas is where the command mode's own Escape lives (issue 1308),
    ## and a dialog that kept the keyboard would leave a mode the user cannot
    ## leave -- the exact defect DD-12 was ruled about, one window further out.
    catch {focus -force $w}
    # GUARDED, for ase::ui::bus_dialog's own reason (ase_window.tcl:1414): the
    # build-time `update` can let a timer destroy the window before we get
    # here, and `tkwait window` on a dead path never returns.
    if {[winfo exists $w]} { catch {tkwait window $w} }
    catch {grab release $w}
    if {$prevfocus ne {} && [winfo exists $prevfocus]} {
        catch {focus -force $prevfocus}
    }
    return $scope_result
}

# ---------------------------------------------------------------------------
# SAVE.

# Ruling DD-7's read-modify-write is the STORE's, not this file's: `write_conf`
# reads the tier it is about to write, changes only the keys this session
# changed and preserves every other row verbatim, rows this build cannot parse
# included.  This proc chooses the tier, names the file it wrote, and repeats
# the store's own sentence when it refuses.
# ⚠ THE TWO TIERS CAN BE ONE FILE, AND AT THE ORDINARY LAUNCH CWD THEY ARE
# (issue 1325, item B5-a).  `op_param_lists::conf_path project` is
# `[pwd]/.xschem/op_param_lists.conf`, so a session started in `$HOME` -- which
# is how xschem is normally started -- resolves the PROJECT tier onto the
# USER-GLOBAL file.  MEASURED: both answer
# `/home/analog/.xschem/op_param_lists.conf`, and a Save taken there is read
# back by every other design on the machine.  Ruling DD-7's whole subject is
# that a write touches ONE TIER'S OWN FILE, so a Save that cannot say the two
# are the same file is that ruling failing where the user cannot see it.
#
# THE FIX IS TO MAKE THE REPORT HONEST, NOT TO CHANGE WHICH TIER SAVE WRITES.
# Issue 1273 -- "which directory IS the project" -- is a live rule debt on the
# owed ledger and is the USER's to settle; this note names the collision and
# points at it.  A named callee rather than three lines inline, so a reviewer
# can neutralise exactly this sentence and watch a row say so.
proc rdw::_tier_note {path} {
    set tiers {}
    catch {set tiers [::op_param_lists::conf_tiers $path]}
    if {[llength $tiers] < 2} { return {} }
    return "That file is both tiers here - this project directory and your user configuration directory are the same directory - so every design on this machine reads it back (issue 1273 asks which directory is the project)."
}

proc rdw::_do_save {label} {
    set path {}
    catch {set path [::op_param_lists::conf_path project]}
    if {$path eq {}} {
        return [rdw::status "$label: there is no project settings-file path to write to."]
    }
    set before 0
    catch {set before [llength [::op_param_lists::said]]}
    set ok 0
    catch {set ok [::op_param_lists::write_conf $path]}
    if {$ok} {
        ## ON THE SUCCESS ARM ONLY.  A refused Save changed nothing, so the
        ## false belief this sentence corrects never forms -- and the refusal
        ## arm already carries the STORE's own wording, which must not be
        ## diluted by a second sentence about a file that was not written.
        set note [rdw::_tier_note $path]
        if {$note ne {}} {
            return [rdw::status \
                "$label: wrote the operating-point parameter lists to $path $note"]
        }
        return [rdw::status "$label: wrote the operating-point parameter lists to $path"]
    }
    return [rdw::status "$label: [rdw::_store_tail $before \
        "could not write the parameter lists to $path."]"]
}

# ---------------------------------------------------------------------------
# THE ONE COMMAND EVERY WIDGET CARRIES.
#
# ⚠ EVERY PATH OUT OF HERE ENDS IN A STATUS LINE THAT NAMES THE BUTTON IT CAME
# FROM.  That is rdw::inert's obligation surviving the wiring: the status line
# is shared by all five buttons, so a message that does not identify itself is
# the same failure as a silent one, one step further in.
## THE BUTTON COLUMN'S OWN REPORTER (issue 1356).  It exists so the clause
## about the selection is appended at ONE place per verdict rather than being
## re-typed at each of the seven returns that carry one, and so a reviewer can
## neutralise the whole clause in one line and watch row BT31 say so.
proc rdw::_bstatus {msg note} {
    if {$note eq {}} { return [rdw::status $msg] }
    return [rdw::status "$msg $note"]
}

proc rdw::button {id} {
    variable listkind
    variable blocks
    set label [rdw::_button_label $id]
    ## ⚠ "NOT ONE OF THE LIST BUTTONS", NOT "THERE IS NO BUTTON CALLED" --
    ## ISSUE 1382.  The column carries two controls this proc is deliberately
    ## NOT the door for: `aA` (issue 1368) and Close (issue 1382).  The old
    ## sentence denied the existence of a button the user is looking at, which
    ## is the same class of defect as a status line citing a fixed issue -- it
    ## was already false for `fontsize` the day 1368 landed, and Close is what
    ## made it worth correcting rather than merely noticing.  It still names
    ## the id, so a real typo is still legible.  Row CB4.
    if {$label eq {}} {
        return [rdw::status "'$id' is not one of this window's list buttons."]
    }
    # THE GREYING TABLE IS THE COMMAND PATH'S FENCE TOO.  A key, a menu or a
    # later item that reaches this proc directly gets the same answer the
    # disabled widget would have given.
    if {[rdw::button_state $id $listkind] ne {normal}} {
        return [rdw::status "$label: this button is greyed on the $listkind list, so there is nothing here for it to do."]
    }
    if {$id eq {save}} { return [rdw::_do_save $label] }
    if {($id eq {delete} || $id eq {add}) && [rdw::pick_running]} {
        return [rdw::status "$label: a device pick is running on the canvas - click a device, or press Escape to end the mode, then press $label again. A dialog opened now would swallow the click the mode is waiting for."]
    }
    if {[llength $blocks] == 0} {
        return [rdw::status "$label: nothing has been dumped into this window yet - press 1, 2 or 3 over a device first."]
    }
    set line [rdw::_target_line]
    ## ⚠ TAKEN HERE, BEFORE ANYTHING CAN REPAINT (issue 1356).  Every success
    ## arm below ends in `rdw::render_pane`, and a repaint deletes the pane's
    ## text and with it the `sel` tag -- so a note computed after the edit
    ## would be silent in exactly the case it exists for.  See
    ## rdw::_selection_note for what was measured and why the clause is
    ## conditional.
    set snote [rdw::_selection_note $id]
    ## ⚠ AND SO IS THE BATCH, FOR EXACTLY THE SAME MEASURED REASON.  The rows a
    ## multi-row press acts on are the rows the `sel` tag covers, and the first
    ## repaint destroys that tag -- so they are read here, ONCE, before
    ## anything can change, and carried through the rest of this proc BY
    ## PARAMETER NAME rather than by line number, because `_reorder_shown` and
    ## the rebuild both move rows to other lines.
    ##
    ## ⚠ ADD AND DELETE ONLY (the user's ruling names those two).  Up and Down
    ## keep the shaded row: they raise no dialog, so a batch would have no
    ## answer to obey, and N rows each moving up one has no meaning independent
    ## of the order the rows are asked in.  `rdw::_selection_note_for` says so
    ## on screen when a selection is standing across those two buttons.
    set batch {}
    if {$id eq {delete} || $id eq {add}} { set batch [rdw::_selection_rows] }
    ## ⚠ ONE BLOCK, AND THE REFUSAL IS NOT PEDANTRY.  `rdw::scope_dialog` names
    ## ONE instance in its question, ONE cell on its narrow radiobutton and ONE
    ## class on its broad one; a press that answered that question and then
    ## wrote for a second device would make the dialog a false statement.  Two
    ## dumps of the same device are the ordinary case in this window, so the
    ## sentence says which blocks and, when they differ, which classes.
    set bparams {}
    if {$batch ne {}} {
        set bbi {}
        catch {set bbi [dict get $batch blocks]}
        if {[llength $bbi] > 1} {
            return [rdw::_bstatus \
                "$label: [rdw::_batch_spread_why $bbi]" $snote]
        }
        ## The batch supplies the target.  Its first row is what the cursor
        ## follows and what every single-row sentence below is about, so a
        ## batch of ONE is byte-for-byte today's press.
        set bparams [dict get $batch params]
        set loc     [lindex [dict get $batch locs] 0]
        set line    [lindex [dict get $batch lines] 0]
    } else {
        set loc [rdw::_locate $line]
    }
    set param {}
    if {$loc ne {}} {
        set param [rdw::_row_param \
            [lindex [lindex $blocks [lindex $loc 0]] [lindex $loc 1]]]
    }
    # ⚠ TWO SENTENCES, BECAUSE THERE ARE NOW TWO WAYS TO HAVE NO ROW (item R1,
    # issue 1337).  Before the cursor was visible `_target_line` read the
    # pane's `insert` mark, which always has a line, so "no row at all" could
    # not be said and did not need saying.  It can now: ruling DD-1 clears the
    # cursor on every new dump, and "line 0 is not a parameter row" would be a
    # sentence about a line that does not exist, on a screen the user is
    # reading.
    if {$line <= 0} {
        return [rdw::status "$label: no row is marked in this window - click a parameter row, which shades to show it is the target, then press $label again."]
    }
    if {$param eq {}} {
        return [rdw::_bstatus "$label: line $line is not a parameter row - click a parameter row in the pane, then press $label again." $snote]
    }
    set subj [rdw::_subject [lindex $loc 0]]
    if {$subj eq {} || [dict get $subj type] eq {} || [dict get $subj class] eq {}} {
        return [rdw::status "$label: the device this block was dumped from has no operating-point descriptor in this design any more, so there is no list to edit."]
    }
    if {$id eq {up} || $id eq {down}} {
        # List 3 is what this run's raw actually holds (ruling DD-1), which is
        # why the store refuses to persist it at all: there is no stored order
        # to move.  The greying stays keyed on list IDENTITY -- a
        # position-dependent grey would have to re-grey on every cursor move,
        # which needs a new binding on the pane and is issue 1306/1308 ground.
        if {$listkind eq {all}} {
            return [rdw::status "$label: list 3 is live from the simulator and has no stored order to change. Press 1 or 2 first."]
        }
        set ln $listkind
        # `governing`, not narrow-or-broad: Up and Down raise no dialog, so
        # rdw::_edit resolves the key itself through op_param_lists::governs.
        lassign [rdw::_edit $id $subj $ln governing $param] verdict sentence
        if {$verdict ne {ok}} { return [rdw::_bstatus "$label: $sentence" $snote] }
        # ⚠ AND IT APPLIES, LIKE DELETE AND ADD (item B5-2).  The preserved
        # patch deferred the redraw here and SAID SO on screen -- "The drawn
        # order follows on the next Add, Delete or reload (issue 1312)" --
        # because `op_param_lists::seed` read back the very field `apply`
        # writes, so an apply after the user owned an annotation list reordered
        # the seed, and the SUMMARY list, which nobody owns, then answered in
        # the annotation list's order.  Ruling DD-13 (item B2e) killed that:
        # `seed` reads the DECLARATION now, `_show_set` filters the union
        # annotation-first, and store row N4 fences the opposite.  The
        # deferral's stated cost no longer exists, and a status line citing a
        # FIXED issue as its reason is a false statement on a screen the user
        # is reading.  Rows BT8 and BE7 assert the display key moves now, for
        # every type token of the class.
        #
        # ⚠ AND THE WINDOW FOLLOWS TOO, WHICH IS ITEM R2 (issue 1338).  The
        # SHEET half already worked -- MEASURED at HEAD 27122ca4 as a
        # `xschem get annot_overlay_flushes` of +1 per accepted press -- but
        # `::rdw::blocks` came back byte-identical, so the pane kept showing
        # the order the user had just changed until they pressed 1 or 2 again.
        # `rdw::_reorder_shown` re-slots every block that draws this class's
        # list and answers the pane line the cursored ROW moved to.
        #
        # ⚠ THE CURSOR IS RE-POINTED BEFORE THE REPAINT, NOT AFTER.
        # `rdw::render_pane` paints the shading from `::rdw::targetrow` on its
        # way out (`rdw::_paint_cursor`), so setting the row afterwards would
        # paint twice and, in between, shade the line the parameter has LEFT.
        # Row RD1 reads the `cursor` tag's own ranges off the live widget and
        # is the fence.
        #
        # ⚠ AND IT RUNS BEFORE `_apply_now`, so a sheet that cannot be
        # re-rendered still leaves the WINDOW agreeing with the store the user
        # just changed -- the edit stood, and the sentence below says which
        # half did not follow (issue 1330).
        #
        # ⚠ AND ONLY THE BLOCKS THE WRITE REACHED (issue 1348).  The key is
        # built by `rdw::_write_key`, the same builder `rdw::_edit` writes at,
        # so the pane cannot follow an entry the press did not touch.
        set line [rdw::_reorder_shown [dict get $subj class] $ln \
                    [rdw::_write_key [dict get $subj class] \
                                     [dict get $subj cellname] $ln governing] \
                    $loc $line]
        rdw::set_row $line
        rdw::render_pane
        set why [rdw::_apply_now $subj]
        if {$why ne {}} { return [rdw::_bstatus "$label: $sentence $why" $snote] }
        return [rdw::_bstatus "$label: $sentence" $snote]
    }
    ## ⚠ THROUGH THE ONE ACCESSOR (issue 1355), so the dialog's statement, the
    ## dialog's pre-set choice and this write cannot give three answers to
    ## "which list".  Spec 4.2 B7: an Add from list 2 writes the ANNOTATION
    ## list, which the dialog now says out loud.
    set deflist [rdw::_edit_list $id $listkind]
    ## ⚠ THE DIALOG IS NOT RAISED IN FRONT OF A REFUSAL (issue 1372).  MEASURED
    ## on the user's own M18: list 3 offers 88 rows, the sky130 declaration
    ## names six, and every one of the other 82 answered a two-part modal
    ## question -- which devices, which list -- and was THEN told, once, into a
    ## four-line status pane, that the whole thing was impossible.  That is why
    ## the report reads "it never shows up" rather than "it refused".
    ##
    ## ⚠ IT IS THE SAME RULE, NOT A SECOND ONE.  `rdw::_add_why` is
    ## `rdw::_find_triple` returning {}, worded once, and `rdw::_edit` asks it
    ## again for itself -- one rule, two doors, exactly the shape
    ## `op_param_lists::reduce_why` and `governs` set.  A second door with a
    ## second rule is the disagreement issue 1288 exists to remove.
    ##
    ## ⚠ AND ONLY THE LIST-INDEPENDENT HALF.  "Already in the list" is the
    ## other refusal, and WHICH list is what the dialog is being raised to ask,
    ## so that one still costs a dialog: the answer determined it.
    ## ⚠ FOR A BATCH THE DOOR SHUTS ONLY WHEN EVERY ROW IS REFUSED.  The door
    ## exists so the dialog is not raised in front of a refusal; a batch where
    ## some rows CAN be added has a real question to ask, and the rows that
    ## cannot are reported by name in the one sentence that follows.  A batch
    ## of one is today's press exactly.
    if {$id eq {add}} {
        if {[llength $bparams] < 2} {
            set why [rdw::_add_why $subj $param]
            if {$why ne {}} { return [rdw::_bstatus "$label: $why" $snote] }
        } else {
            set whys {} ; set anyok 0
            foreach p $bparams {
                set w [rdw::_add_why $subj $p]
                if {$w eq {}} { set anyok 1 } else { lappend whys $p $w }
            }
            if {!$anyok} {
                set names {} ; set rs {}
                foreach {p w} $whys { lappend names $p ; lappend rs $w }
                return [rdw::_bstatus \
                    "$label: [rdw::_batch_skipped_say {nothing can be added} $names $rs]" \
                    $snote]
            }
        }
    }
    set ans [rdw::scope_dialog $id $subj $listkind]
    if {$ans eq {}} {
        return [rdw::status "$label: cancelled - nothing was changed."]
    }
    set scope broad
    catch {set scope [dict get $ans scope]}
    if {$scope ne {narrow} && $scope ne {broad}} { set scope broad }
    set ln $deflist
    if {$listkind eq {all}} { catch {set ln [dict get $ans list]} }
    if {$ln ne {annotation} && $ln ne {summary}} { set ln $deflist }
    ## ⚠ ONE ROW GOES THROUGH THE CORE DIRECTLY AND A BATCH GOES THROUGH IT N
    ## TIMES.  `rdw::_batch_edit` adds only what a single row cannot answer for
    ## -- ruling DD-10 over the whole batch, one sentence for N outcomes, the
    ## tail clauses computed once -- and a batch of ONE never reaches it, so
    ## every byte-for-byte sentence this feature's suites gold is still
    ## produced by the code that produced it before this item.
    if {[llength $bparams] < 2} {
        lassign [rdw::_edit $id $subj $ln $scope $param] verdict sentence
    } else {
        lassign [rdw::_batch_edit $id $subj $ln $scope $bparams] verdict sentence
    }
    if {$verdict ne {ok}} { return [rdw::_bstatus "$label: $sentence" $snote] }
    ## ISSUE 1330 REACHES THIS DOOR TOO.  Delete and Add have always relied on
    ## `_apply_now` to put the change on the sheet, so a swallowed failure was
    ## just as false here; it was only never fenced because no row asked.
    ##
    ## ⚠ AND THE BLOCKS ARE RE-SLOTTED ON THIS ARM TOO, WHICH REVERSES WHAT
    ## THIS COMMENT USED TO SAY (issue 1349).  It argued that a re-slot "could
    ## neither add the new row (no run published it) nor remove the deleted one
    ## (the run still did)".  Both halves are TRUE and neither is an argument
    ## about ORDER: `rdw::_reslot_block` is a strict PERMUTATION of the rows
    ## already in the block, over exactly the rows the run published AND the
    ## list declares, so it adds nothing, removes nothing, and leaves every
    ## undeclared row in its own slot.  Membership and order are different
    ## questions and the old reason answered only the first.
    ##
    ## MEASURED at the shipped state: an Up left pane and store agreeing on
    ## `ids gds gm`; a broad Delete of `gds` and an Add of it back left the
    ## store at `ids gm gds` against a pane still reading `ids gds gm`, with no
    ## sentence about the difference.  So the very property item R2 had just
    ## taught the user to rely on -- the window shows the order the store holds
    ## -- was maintained by Up and Down alone and quietly abandoned by the two
    ## buttons either side of them.
    ##
    ## The key is the ONE builder's again, so a NARROW write re-slots only the
    ## blocks that flavor entry governs and a BROAD one skips the blocks a
    ## flavor entry shadows -- which is `rdw::_shadow_why`'s own sentence, kept
    ## true in the pane as well as in the status line.
    ## ⚠ AND THE BLOCKS ALREADY ON SCREEN ARE BUILT AGAIN, WHICH IS THE USER'S
    ## RULING (item: blocks follow a list edit; the open half of issue 1338).
    ## `rdw::_reorder_shown` is a strict PERMUTATION and answers only the
    ## ORDER question -- it cannot add or remove a row, which is exactly why
    ## "Delete is not affecting the current display" was true.  A rebuild goes
    ## back through `rdw::_make_block`, so membership, the narrowing footnote
    ## and the column widths all come out as a fresh dump would have them.
    ## Blocks that cannot be rebuilt (no stamp, another schematic, a devpath
    ## that no longer resolves) are left exactly as they were and COUNTED, and
    ## the ones that stayed still get the permutation so their order follows.
    set cls [dict get $subj class]
    set wkey [rdw::_write_key $cls [dict get $subj cellname] $ln $scope]
    lassign [rdw::_rebuild_class $cls $ln $wkey] nre nstuck
    if {$nre > 0} {
        ## The cursor is found again BY NAME: a rebuild can change a block's
        ## length, so the entry-index arithmetic `_reorder_shown` relies on
        ## does not survive one.  A parameter the Delete removed has no line
        ## to point at, and `rdw::set_row 0` is then the same least-destructive
        ## reading `rdw::render_pane`'s stale-target sweep takes.
        set line [rdw::_line_of_param [lindex $loc 0] $param]
    } else {
        set line [rdw::_reorder_shown $cls $ln $wkey $loc $line]
    }
    ## ⚠ A MULTI-ROW PRESS LEAVES NO CURSOR, WHICH IS RULING DD-1's OWN
    ## ARGUMENT ONE CASE FURTHER ON.  The press acted on N rows; shading any
    ## ONE of them afterwards would be a cursor the user did not put there,
    ## sitting on a row chosen by nothing but list order -- and the next press
    ## would act on it without a word.  Clearing costs one click and is the
    ## only reading that cannot act on a row the user never chose.  The
    ## selection itself is gone either way: `rdw::render_pane` below deletes
    ## the pane's text and with it the `sel` tag.
    if {[llength $bparams] > 1} { set line 0 }
    rdw::set_row $line
    rdw::render_pane
    set why [rdw::_apply_now $subj]
    ## A block that did not follow is said out loud.  Silence here would be the
    ## defect this change removes, pointed the other way.
    set stucknote {}
    if {$nstuck > 0} {
        set stucknote " [rdw::_stuck_note $nstuck]"
    }
    if {$why ne {}} { return [rdw::_bstatus "$label: $sentence $why$stucknote" $snote] }
    return [rdw::_bstatus "$label: $sentence$stucknote" $snote]
}
