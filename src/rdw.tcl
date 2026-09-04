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
#   context   header  sim  dump  dump_devpath  push  status   (xschem/op_annot,
#             still no Tk)
#   Tk        have_tk  open  close  build  render_pane  set_list  inert
#             palette  color
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
proc rdw::_incomplete_line {ans} {
    set c 0
    catch {set c [dict get $ans complete]}
    if {[string is boolean -strict $c] && $c} { return {} }
    return {Not a complete list: these are the operating-point columns this run saved for this device, not everything the device has.}
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
proc rdw::_value_text {v} {
    if {[string trim $v] eq {}} { return {(no value reported)} }
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

proc rdw::dump_devpath {devpath ctx} {
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
    rdw::push $blk
    return $blk
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

# Add a block to the store and repaint.  The store is namespace state and
# works headless; the pane is only its projection.
proc rdw::push {block} {
    variable blocks
    if {[rdw::_insert_index] eq {1.0}} {
        set blocks [linsert $blocks 0 $block]
    } else {
        lappend blocks $block
    }
    rdw::render_pane
    return $block
}

# The window's own status line.  The variable is always settable, so the inert
# buttons are drivable under --nogui too; the entry is wired to it by
# -textvariable, so there is nothing to update by hand.  An empty message
# clears the field.
proc rdw::status {msg} {
    variable statusmsg
    set statusmsg $msg
    return {}
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
    }
}

# The CIW's own convention for "a result the user must NOTICE without it being
# an error" (ciw.tcl:453).  The incompleteness sentence and the five silences
# are exactly that: not errors, and not to be skimmed past.
proc rdw::_notefg {} { return {dark orange} }

proc rdw::_color_fallback {role} {
    switch -exact -- $role {
        panel      { return #f2f2f2 }
        field      { return #ffffff }
        fieldfg    { return #000000 }
        selectbg   { return #4a6984 }
        selectfg   { return #ffffff }
        accent     { return #8b0000 }
        disabledfg { return grey50 }
        notefg     { return {dark orange} }
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
    catch {destroy .rdw}
    return {}
}

proc rdw::build {} {
    variable listkind
    toplevel .rdw
    wm title .rdw {Results Display Window}
    wm protocol .rdw WM_DELETE_WINDOW rdw::close
    wm minsize .rdw 520 260
    ## The window manager grants keyboard focus to a newly mapped toplevel
    ## asynchronously, after every synchronous hand-back has already run.
    ## rdw::_focus_handback catches that one grant and gives the keyboard back
    ## to the canvas; it is inert unless a dump path armed it.
    bind .rdw <FocusIn> {rdw::_focus_handback %W}
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
    catch {.rdw configure -background [rdw::color panel]}

    # The status line owns the bottom edge: it is where the five inert buttons
    # say why they did nothing, and where item B5's Save will name the exact
    # settings-file path it wrote.  A button that does nothing AND says
    # nothing cannot be told from a broken one.
    frame .rdw.s -background [rdw::color panel]
    entry .rdw.s.msg -textvariable ::rdw::statusmsg -state readonly \
        -relief sunken -borderwidth 1 -takefocus 0 \
        -background [rdw::color field] \
        -readonlybackground [rdw::color field] \
        -foreground [rdw::color fieldfg] \
        -selectbackground [rdw::color selectbg] \
        -selectforeground [rdw::color selectfg]
    pack .rdw.s.msg -side left -fill x -expand 1 -padx 3 -pady 3
    pack .rdw.s -side bottom -fill x

    # The button column, greyed per spec 4.2 B7 and INERT until item B5.
    frame .rdw.b -background [rdw::color panel]
    foreach {id label} {up Up down Down delete Delete add Add save Save} {
        button .rdw.b.$id -text $label -width 8 -command [list rdw::inert $label]
        pack .rdw.b.$id -side top -fill x -padx 4 -pady 2
    }
    pack .rdw.b -side right -fill y

    # The pane.  Read-only, selectable, exporting the X selection.
    frame .rdw.p -background [rdw::color panel]
    text .rdw.p.t -width 96 -height 26 -font TkFixedFont -wrap word \
        -state [rdw::_pane_state] -exportselection [rdw::_exportsel] \
        -borderwidth 1 -relief sunken \
        -background [rdw::color field] \
        -foreground [rdw::color fieldfg] \
        -selectbackground [rdw::color selectbg] \
        -selectforeground [rdw::color selectfg] \
        -yscrollcommand {.rdw.p.ys set}
    scrollbar .rdw.p.ys -command {.rdw.p.t yview}
    # `-wrap word` rather than a horizontal scrollbar: the incompleteness
    # sentence and the five silences are long, and a sentence clipped off the
    # right edge is a sentence the user does not read.  Wrapping is a DISPLAY
    # property -- a copied selection still carries the original lines, so the
    # paste shape is unaffected.
    catch {
        set hf [font actual TkFixedFont]
        dict set hf -weight bold
        .rdw.p.t tag configure hdr -font $hf
    }
    .rdw.p.t tag configure dim  -foreground [rdw::color disabledfg]
    .rdw.p.t tag configure dev  -foreground [rdw::color accent]
    .rdw.p.t tag configure note -foreground [rdw::color notefg]
    pack .rdw.p.ys -side right -fill y
    pack .rdw.p.t -side left -fill both -expand 1
    pack .rdw.p -side left -fill both -expand 1

    rdw::apply_button_states
    rdw::render_pane
    return .rdw
}

# Repaint the pane from the store.  The store is newest-first and the blocks
# are laid out in that order, so the newest dump is on top and older ones are
# pushed below it.
proc rdw::render_pane {} {
    if {![rdw::have_tk]} { return {} }
    if {![winfo exists .rdw.p.t]} { return {} }
    variable blocks
    .rdw.p.t configure -state normal
    .rdw.p.t delete 1.0 end
    foreach b $blocks {
        foreach e $b {
            .rdw.p.t insert end "[lindex $e 1]\n" [lindex $e 0]
        }
    }
    .rdw.p.t configure -state [rdw::_pane_state]
    catch {.rdw.p.t see [rdw::_insert_index]}
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
    rdw::apply_button_states
    return $kind
}

proc rdw::apply_button_states {} {
    variable listkind
    if {![rdw::have_tk]} { return {} }
    foreach id {up down delete add save} {
        if {![winfo exists .rdw.b.$id]} { continue }
        .rdw.b.$id configure -state [rdw::button_state $id $listkind]
    }
    return {}
}

# Every enabled button in this item routes here, and it NAMES ITSELF and names
# the item that wires it.  Copied from calc::inert (calculator.tcl:607), which
# exists for exactly this failure: a real, visible, enabled control that does
# nothing and says nothing is indistinguishable from a broken one.
proc rdw::inert {what} {
    return [rdw::status \
        "$what: the button column is built but not wired yet (item B5 wires it)."]
}

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
# WHAT THE KEYS DELIBERATELY DO NOT DO.  Keys 1, 2 and 3 select a list
# IDENTITY through rdw::set_list -- B3's ONE setter -- and narrow no CONTENT.
# The narrowing has exactly one definition in this tree (the list store's
# `effective`, plus ruling DD-6's display key that item B2b built), and row S1
# of this file's own suite forbids naming op_param_lists:: here at all.  A
# second definition of "the annotation list" living in this file is precisely
# the two-builders drift invariant I1 exists to prevent, and a block LABELLED
# with a list whose content is identical for all three would imply a narrowing
# that did not happen -- the DD-1 failure shape.  Filed as issue 1300.
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
#   * ONLY WHEN THE KEYBOARD LANDED ON THE TOPLEVEL ITSELF.  The decision is
#     WHERE THE KEYBOARD ENDED UP -- `[focus]` -- and not which window named
#     the event.  Issue 1306: deciding on `%W` alone shipped a hand-back that
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
#     The discriminator that CAN is the one the WM itself supplies: the grant
#     lands on the TOPLEVEL (`[focus]` eq `.rdw`, detail NotifyAncestor), while
#     every deliberate landing lands on a CHILD (`[focus]` eq `.rdw.p.t`).
#
#     ⚠ AND THE OBVIOUS GLOB IS WRONG.  `[string match .rdw* [focus]]` -- the
#     line issue 1306's own recommended fix prints -- matches the DESCENDANT
#     `.rdw.p.t` exactly as readily as `.rdw`, so the click is still bounced.
#     Measured 3/3 under a WM and 3/3 WM-less.  The test is EXACT EQUALITY
#     against the toplevel, and row K16 of the window suite keeps `string
#     match` out of this proc so nobody reintroduces it as a simplification.
#
# COST, STATED (rejected alternatives are in the receipt), AND IT IS TRUE FOR
# THE FIRST TIME: a deliberate landing does NOT spend the one shot -- only a
# real grant does -- so if a window manager maps this window and never focuses
# it, the armed flag survives, and the user's next click on the window's FRAME
# or on its BUTTON COLUMN (Tk buttons do not take focus on X, so `[focus]`
# stays at `.rdw`) hands the keyboard back to the canvas exactly once.  A click
# on the TEXT never does.  A timer disarm would remove that wart and
# reintroduce the flakiness this fix exists to delete.
proc rdw::_arm_focus_handback {} {
    variable focus_pending
    if {![rdw::have_tk]} { return 0 }
    if {[winfo exists .rdw] && [winfo ismapped .rdw]} { return 0 }
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
    set land {} ; catch {set land [focus]}
    if {$land ne {.rdw}} { return 0 }
    set focus_pending 0
    rdw::_focus_canvas
    return 1
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
    if {[info exists pick(canvas)] && ![info exists pick(suspended)]} { return 1 }
    set cv {}
    catch {set cv [xschem get current_win_path]}
    if {$cv eq {} || ![winfo exists $cv]} { return 0 }
    ## ISSUE 1305: clear the outstanding suspend as part of taking the canvas
    ## back, so resume_all finds nothing to resume.  BELOW the guard above.
    unset -nocomplain pick(suspended)
    rdw::_pick_seize $cv
    rdw::_ciw {Results window: click a device to show its operating-point columns; ESC ends. Clicking does not change the selection.}
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
        return 0
    }
    unset -nocomplain pick(suspended)
    rdw::_pick_seize $canvas
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
