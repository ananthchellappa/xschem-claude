# tests/headless/test_rdw_window_1245.tcl — item B3 of
# doc/claude/op_param_batch/PLAN.md (feature 1245, the Results Display Window).
# Spec: doc/claude/specs/op_param_lists.md §4.2 B1/B2/B3/B7 and §5.1 Q6/Q10.
# Rulings: doc/claude/op_param_batch/DECISIONS.md — D-3, D-4, D-5 and driver
# decision DD-1, whose corollary ("a caller that renders the pairs silently
# reads as a COMPLETE list") is this item's central rendering obligation.
#
# ============================================================================
# WHAT IS UNDER TEST
# ============================================================================
# B3 adds THE WINDOW and nothing else — no keys, no button behaviour, no C:
#
#   src/rdw.tcl, namespace rdw::, three layers so the RENDERER is testable
#   with no Tk at all:
#     pure     rdw::_cadence_path  rdw::format_answer  rdw::block_text
#              rdw::button_state   rdw::_rowdevs
#     context  rdw::header  rdw::sim  rdw::dump_devpath  rdw::dump  rdw::status
#     Tk       rdw::have_tk  open  close  build  push  render_pane  set_list
#              rdw::inert   rdw::palette  rdw::color
#   src/Makefile.in — rdw.tcl in /local/install_shares (ONE list, TWO generated
#              lines: the issue 0424 receipt, `grep -c rdw.tcl src/Makefile` 0->2)
#   src/xschem.tcl — the bare `source $XSCHEM_SHAREDIR/rdw.tcl` and the ONE
#              main-menubar Tools entry "Results Display Window".
#
# ⚠ THE BUTTONS ARE INERT IN THIS ITEM. The column, the greying and a
# test-drivable path to each button are B3's; reorder / delete / add / save
# behaviour and the two scope dialogs are B5's. No row below asserts a
# behaviour, and rows W4/S1 fence the boundary from the other side.
#
# ============================================================================
# THE ONE SENTENCE EACH
# ============================================================================
# WHAT THE WINDOW SAYS: what THIS run's currently selected raw slot actually
# holds and actually computed for exactly this device path, which primitive
# each number belongs to, which columns the simulator did not compute, which
# ones came back non-finite, that the list is not everything the device has,
# and — when there is nothing — WHICH of the five silences this is.
# WHAT IT DOES NOT SAY: that the run converged (an empty `nonfinite` bucket is
# not proof: the same NaN in an ASCII raw arrives as a finite 0 and lands in
# `devices` — src/save.c, deliberate, issue 1272 still open), what parameters
# the device HAS, or anything at all about a slot that is not the current one.
#
# ============================================================================
# THE THREE RENDERING OBLIGATIONS, ALL RULED, NONE OPTIONAL
# ============================================================================
# 1. `complete` 0 MUST BE VISIBLE (DD-1's corollary)          rows F2 F3 F11 Q1
# 2. `nonfinite` renders "(did not converge)", NEVER a blank
#    and NEVER the raw `nan`/`inf` text (rule debt
#    1245_B1_nonfinite_render option (b); invariant I3)       rows F4 F5 Q3
# 3. the four non-`ok` states are FOUR DIFFERENT SENTENCES,
#    and `ok`-with-nothing is a FIFTH                         rows F9 F10 F11 Q2
#
# ============================================================================
# THE UNION IS THIS ITEM'S SHARPEST TRAP, AND IT IS MEASURED
# ============================================================================
# Driven against the landed seam on this binary, 2026-09-03:
#   an all-`dims=0` device  -> devices {} absent {{@m.x1.m9 id} {@m.x1.m9 vth}}
#                              nonfinite {} complete 0 state ok
#   a binary NaN/Inf device -> devices {} absent {}
#                              nonfinite {{@m.x1.m8 id nan} {@m.x1.m8 vth inf}}
#                              complete 0 state ok
# A renderer that walks `dict keys [dict get $ans devices]` prints an EMPTY
# block for a real, named, non-converged device. So the row set is the UNION of
# the rawdev names in all THREE buckets, first-appearance order across
# devices -> absent -> nonfinite. Rows F6 and Q3 are the fence.
#
# ============================================================================
# THE BLOCK FORMAT THIS SUITE LOCKS (goldens, not eyeballing)
# ============================================================================
#   line 1   <inst>:<sch_path trimmed of dots, dots -> slashes, leading />
#            i.e. Q6's already-taken default: M2B:/xdut/xbg/xamp1
#   line 2   op_annot::devpath's OWN string, verbatim — the one a user pastes
#            into ngspice.  OMITTED when it is empty (state no_devpath).
#   line 3   the incompleteness sentence — ONLY in state ok, complete 0, with a
#            non-empty union — or, in every other case, the ONE state sentence.
#   then     per primitive of the union, a sub-header "  <rawdev>", SUPPRESSED
#            only when there is exactly one primitive and its name equals line 2
#   then     "    %-*s : %s", the width being the longest param name in the
#            block capped at 24, RIGHT-TRIMMED so a blank value leaves no
#            trailing space.  Rows are devices pairs first (raw-file order),
#            then nonfinite, then absent.
#   then     the blank-value footnote, ONLY when `absent` is non-empty
#   then     ONE empty separator line.
# Data NEVER becomes a format spec and nothing is subst'ed or eval'ed, so a `%`
# or a `[` in a device path or a parameter name passes through verbatim (H4).
#
# ============================================================================
# BOTH ARMS ARE REAL. A SUITE THAT ONLY EVER RUNS --nogui PASSES WHILE THE
# WINDOW IS BROKEN.
# ============================================================================
# Sections M N H F Q S run on BOTH arms and are the majority of the checks;
# only section W (the widgets) is guarded and self-skips headless. The headless
# arm is therefore NOT a vacuous skip — it proves the file loads, defines its
# procs, constructs nothing, and renders every one of the five seam keys.
#   headless:  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_rdw_window_1245.tcl
#   display :  GUI_GATE=0 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_rdw_window_1245.tcl
# ⚠ Never a bare `./src/xschem --script` (it inherits $DISPLAY, the user's real
# Windows X server) and never a bare `xschem` on PATH (3.4.6, issue 0924).
# full_audit.sh selects by GLOB (:393); this file joins NONE of its three named
# lists and full_audit.sh is NOT edited — row M3 says so. The denominator moves
# 380 -> 381; diff the baseline by NAME AND STATUS, never by count.
#
# ============================================================================
# WHICH ROWS ARE RED BEFORE B3 LANDS
# ============================================================================
# Measured against the unmodified tree (HEAD fdae015b, src/xschem built
# 2026-09-03 12:09): `src/rdw.tcl` does not exist, `::rdw` is not a namespace,
# `grep -c rdw.tcl src/Makefile` is 0, and no menubar carries "Results Display
# Window". Every row that names a rdw:: proc therefore answers NOPROC and every
# row that reads the file answers NOFILE.
#   GREEN BEFORE THE CHANGE — controls, fences and hygiene, NONE of them
#   evidence for B3; each says only that B3 broke nothing:
#     S0    the machinery B3 builds on is live (the seam, the ONE name builder)
#     M3    registration is by glob and full_audit.sh is not edited
#     W0    the synthesised-keystroke mechanism itself works (so W2 cannot pass
#           vacuously by delivering nothing)  [display arm only]
#     S2    HYGIENE, no untitled* created
#   EVERYTHING ELSE IS RED, for exactly one reason each: the namespace, the
#   file, the Makefile lines and the menu entry do not exist yet.
#
# MEASURED BEFORE THE CHANGE, 2026-09-03, both arms, exit 1 both times:
#     --nogui                     29 FAILED (3 passed)
#     dev display :99, openbox    37 FAILED (5 passed)
# The extra eight on the display arm are section W, which the headless arm
# skips; the extra green is W0.
#
# ⚠ EVERY GOLDEN WAS RUN AGAINST A SCRATCH PROTOTYPE of rdw.tcl (the plan's own
# algorithm, outside the repo) BEFORE THIS FILE WAS FINISHED. The prototype
# scores 28 passed / 4 failed headless and 38 passed / 4 failed on :99, and the
# four are exactly the rows a prototype outside the repo CANNOT reach — M1 and
# M2 (they read src/Makefile and src/xschem.tcl), N2 and S1 (they read
# src/rdw.tcl itself). All four were hand-verified against the prototype file
# instead: it sources cleanly into a bare interp and defines rdw::open there,
# and it names none of the forbidden tokens. So a red row here is a statement
# about the tree, not about an unreachable golden.
#
# NINE SABOTAGE VARIANTS WERE RUN AGAINST THAT PROTOTYPE AND EVERY ONE WAS
# CAUGHT (rows beyond the four above):
#   row set built from `devices` alone, not the union   -> F6 Q3
#   the incompleteness line thrown away                 -> H4 F1 F2 F4 F5 F6
#                                                          F7 F8 Q1 Q3 Q4
#   the incompleteness line printed unconditionally     -> F3 F9 F10 F11 Q2
#   nonfinite rendered as a blank, like absent          -> F4 F5 F6 Q3
#   one "Nothing found for this device." for all states -> F9 F10 Q2
#   the pane built -state normal                        -> W2
#   -exportselection 0                                  -> W2b
#   newest dump appended BELOW instead of on top        -> W3 W3b
#   button_state flattened to `normal` for every pair   -> F13 W4
# ⚠ TWO PREDICTIONS THE MEASUREMENT REFUTED, recorded rather than quietly
# dropped: the union sabotage does NOT red F5 (F5's device is present in
# `devices` too, so it never needs the union — F6 and Q3 are the union's only
# fence), and the newest-on-top sabotage does NOT red W1b (its reopen leg only
# asks that the stored dumps came back, not in which order).
#
# ⚠ EVERY GOLDEN BELOW WAS MEASURED, NOT GUESSED, in two ways: the five-key
# answer dicts were driven out of the LANDED seam on this binary (see the union
# block above), and the expected block text was run against a scratch prototype
# of rdw.tcl (the plan's own algorithm, outside the repo) which scores ALL PASS.
# A red row here is a statement about the tree, not about an unreachable golden.

# ============================================================================
# ITEM B2a — THE ROWS ADDED AFTER B3's ADVERSARY FOUND THREE DEFECTS IN B3's OWN
# CODE AND SUITE, AND WHICH OF THEM ARE RED BEFORE B2a LANDS
# ============================================================================
# ⚠ ALL THREE ARE LATENT TODAY. Nothing sets `::rdw::sim` (item B5 is the first
# thing that will), no third-party backend exists, and a `dc` slot needs a raw
# nobody has loaded. So `make` and a green suite prove NOTHING here — every
# behavioural row below was written to RED on the code as B3 shipped it, run
# red, and only then fixed.
#   1282  F14 Q6   a DC sweep, and a THREE-POINT operating point that save.c
#                  itself renames `dc`, rendered as operating points with the
#                  word `dc` nowhere on screen (ruling DD-5, option (a))
#         Q7 Q8    "no such simulator" and "registered with no op_param_set
#                  hook" collapsed into ONE sentence
#   1284  F17      a malformed `devices` value rendered the FIFTH SILENCE — a
#                  statement about the RAW, and false
#         F18      a malformed VALUE, a malformed `absent` bucket and a
#                  malformed `nonfinite` bucket each RAISED out of the pure
#                  renderer (the last two measured while planning B2a and NOT
#                  in the issue)
#         F19      a value-less pair and an empty-string value rendered
#                  byte-identically to an absent column, and inherited a
#                  footnote that was false about them
#         F20      a newline in a value made one pair into two lines, the
#                  second unindented and untagged
#
# ⚠ THREE ROWS BELOW ARE **GREEN BEFORE B2a**, AND SAYING SO IS THE POINT.
# Issue 1283 is filed against THIS SUITE, which was ALL PASS 32/42 with eight
# of eight sabotage variants caught. These are the gaps BEHIND that number, and
# each one's red-before proof is a SABOTAGE RUN, never the shipped tree:
#   Q1b  REWRITTEN. It was titled "newest first" and pushed exactly ONE block,
#        then asserted it was at index 0 — true under either ordering. Reversing
#        `rdw::_insert_index` to `end` passed ALL 32 headless checks and red
#        only W3/W3b on `:99`, so "newest dump on top" had NO HEADLESS WITNESS.
#   F16  the union's cross-bucket order, which rdw.tcl's own comment promises
#        and no row held: reversing `rdw::_rowdevs` passed all 32 headless AND
#        all 42 display checks.
#   Q9   the inert-button message: making `rdw::status` a no-op passed the full
#        32-check headless run, because only W4b — inside the Tk-guarded
#        section — asserted it.
# A green count is a statement about the FENCE, not about the code. That is now
# three items old on this branch, and this block is where it is written down.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locations (cwd-independent) --------------------------------------------
set here [file normalize [file dirname [info script]]]      ;# tests/headless
set repo [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch rdw_window]
set RW_AUDIT [file join $here full_audit.sh]
set RW_MK    [file join $repo src Makefile]
set RW_MKIN  [file join $repo src Makefile.in]
set RW_XTCL  [file join $repo src xschem.tcl]
## The file under test. Kept in ONE variable so the RED agent's prototype run
## can point the structural rows at a scratch copy; the shipped value is the
## tree's own.
set RW_FILE  [file join $repo src rdw.tcl]

## Anything this session might be tempted to write goes to the scratch dir.
set ::netlist_dir $scratch

## Taken BEFORE anything below can write a file (hygiene row S2).
set S2_ROOT0 [lsort [glob -nocomplain -directory $repo -tails untitled*]]

# ============================================================================
# THE ANSWER DISCIPLINE — AN ABSENT WINDOW MUST NEVER SATISFY A GOLDEN
# ============================================================================
# Copied from rs_ans/rs_body (tests/headless/test_rdw_seam_1245.tcl:150-230),
# themselves from dc_ans (test_annot_declutter_1244.tcl:227). Two rules this
# batch has already paid for:
#   * a row must be able to FIRE in the RED state. A bare call to a proc that
#     does not exist raises, and a raise at global level under --pipe stops
#     Tcl_AppInit DEAD — the file dies mid-run with `ok` lines and NO verdict
#     (item A2's lesson 6). Every call below goes through a wrapper.
#   * "invalid command name ..." must not be able to satisfy a row expecting
#     the empty string.
proc rw_nocomment {t} {
  set out {}
  foreach l [split $t "\n"] { if {[regexp {^\s*#} $l]} continue ; lappend out $l }
  return [join $out "\n"]
}
proc rw_body {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  return [rw_nocomment $b]
}
proc rw_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set i [string first $needle $hay $i]] >= 0} { incr n ; incr i }
  return $n
}
proc rw_has {hay needle} { return [expr {[string first $needle $hay] >= 0 ? 1 : 0}] }
proc rw_slurp {path} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; set d [read $fd] ; close $fd ; return $d
}
## Call any proc without letting it abort the suite.
proc rw_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
## A widget/Tk expression that must not abort the suite either.
proc rw_w {args} {
  set rc [catch {uplevel #0 $args} r]
  if {$rc} { return "ERR:$r" }
  return $r
}
proc rw_bad {v} { return [expr {$v eq {NOPROC} || [string match {RAISED:*} $v]
                                || [string match {ERR:*} $v] ? 1 : 0}] }
## The block, and the paste shape, for one answer+context. ONE door, so a row
## that reds says which half is missing.
proc rw_block {ans ctx} { return [rw_ans ::rdw::format_answer $ans $ctx] }
proc rw_text  {ans ctx} {
  set b [rw_block $ans $ctx]
  if {[rw_bad $b]} { return $b }
  return [rw_ans ::rdw::block_text $b]
}
## Join golden lines. `{}` is an empty line; the block's own trailing separator
## makes the text end in a newline.
proc rw_lines {args} { return [join $args "\n"] }
## Just the tags of a block, in order — the shape row F12 and the tag rows use.
proc rw_tags {ans ctx} {
  set b [rw_block $ans $ctx]
  if {[rw_bad $b]} { return $b }
  set out {} ; foreach e $b { lappend out [lindex $e 0] } ; return $out
}

# ============================================================================
# THE SEVEN SENTENCES — SPELLED ONCE, ASSERTED EVERYWHERE
# ============================================================================
# All user-visible prose, all on rule debt 1245_B3_window_wording. They are
# literals here on purpose: this suite is where the wording is locked, and a
# drift of one character is a change to what a designer reads, not a typo.
set RW_INC  {Not a complete list: these are the operating-point columns this run saved for this device, not everything the device has.}
set RW_ABSN {A blank value means the raw names that column but the simulator did not compute it.}
set RW_NF   {(did not converge)}
set RW_NORAW    {No simulation results are loaded. Run a simulation, or load a raw file, then ask again.}
set RW_NOTANNOT {Operating-point results are loaded but nothing has been published from them yet. Annotate them first (Waves > Op Annotate, or key 6), then ask again.}
proc RW_OKEMPTY   {dp}   { return "This run's raw holds no operating-point columns for $dp. Only parameters the deck explicitly saved appear here." }
proc RW_NODEVPATH {inst} { return "$inst has no operating-point descriptor, so there is no device path to ask about. A PDK registers one with op_annot::register." }
proc RW_NOTOP     {sty}  { return "The loaded results are a $sty analysis, not an operating point. Nothing was read from them: load the operating-point results and ask again. (An OP+TRAN run writes both to one file, and reading the transient makes it the current one.)" }

# ============================================================================
# FIVE MORE SENTENCES, ALL ITEM B2a's, ALL ON THE SAME RULE DEBT
# ============================================================================
# ⚠ RW_ANALYSIS IS NOT DD-5's QUOTED SPECIMEN, AND THE MEASUREMENT THAT MOVED
# IT IS save.c's OWN. Ruling DD-5 proposes "these numbers come from the `dc`
# analysis at its first point, not from a standalone operating point". That
# asserts something FALSE for a case save.c creates itself: save.c:1073 and
# :1120 both rewrite a MULTI-POINT `Operating Point` plot's sim_type to `dc`,
# so a user who ran nothing but an operating point can be shown a sentence
# telling them they ran a sweep. MEASURED on this binary: a three-point
# `Plotname: Operating Point` raw answers `xschem raw sim_type` = dc (row Q6).
# DD-5's DECISION — render it, and name the analysis — is NOT refuted and is
# implemented; only its specimen wording is. The sentence below names what the
# LOADED RESULTS CALL THEMSELVES rather than what the user ran, which is true
# in both cases and asserts nothing stronger. The exact wording is on the owed
# ledger as a rule debt for the user.
proc RW_ANALYSIS {sty} { return "These numbers come from the first point of results xschem reports as a $sty analysis, not as a standalone operating point. A $sty sweep's first point is one sweep step, and xschem also reports a multi-point operating point as $sty." }

## Issue 1284: a backend's answer dict is not trusted input, it is whatever a
## backend hands over. A malformed one must not fall into the FIFTH SILENCE,
## which is a statement about the RAW and would be false — the run may have
## saved plenty; it is the answer that could not be read. So it gets its own
## sentence, and that sentence names the backend, because the remedy is there.
proc RW_FLAW {sim} { return "The $sim operating-point reader answered in a shape this window could not read, so nothing is shown for this device. This is a fault in that reader's answer, not a statement about the run." }

## Issue 1282 part 2: "not registered" and "registered but declaring no
## op_param_set hook" are DIFFERENT FACTS WITH DIFFERENT REMEDIES, and this
## feature's whole obligation 3 is that different silences get different
## sentences. ase::backend_hook already mints two distinct errors (ase.tcl:550
## "unknown simulator" and :553 "unknown hook", both re-read on this tree); the
## window collapsed them into one.
proc RW_NOSIM    {s} { return "No simulator named $s is registered, so there is nothing to ask for this device. Check the name, or register a backend for it with ase::register_backend." }
proc RW_NOREADER {s} { return "Simulator $s is registered but declares no operating-point reader - the op_param_set hook - so this window has nothing to show for it. A backend adds that hook to publish operating-point columns." }

## Issue 1284 (c) and section 3. A value-less pair and an empty-string value
## both rendered BYTE-IDENTICALLY to an absent column, so the one honest
## distinction the renderer makes — "the raw names this column but nothing was
## computed" — was lost, and the per-block blank footnote was then FALSE about
## them. Words, in the same family as `(did not converge)`, keep the blank
## glyph meaning exactly one thing.
set RW_NOVAL {(no value reported)}

# ============================================================================
# THE FIXTURE MINTERS — COPIED VERBATIM FROM THE SEAM'S SUITE
# ============================================================================
# rs_mkraw / rs_mkraw_bin / rs_annot, tests/headless/test_rdw_seam_1245.tcl:265,
# :302 and :325, renamed. NOTHING in the builders is changed; B3 adds only the
# renderer-shaped FIXTURES the seam suite had no reason to write.
#
# ⚠ NO SIMULATOR IS NEEDED OR WANTED. A suite that needs a simulator is a suite
# that will rot; every number below is a byte this file wrote.
## ⚠ THE OPTIONAL POINT COUNT IS ITEM B2a's, AND IT IS NOT A CONVENIENCE.
## src/save.c:1073 and :1120 both carry
##   if(raw->npoints[...] > 1 && !strcmp(sim_type, "op")) sim_type = "dc";
## so a MULTI-POINT `Operating Point` plot is renamed `dc` BY THE READER, and
## row Q6 needs a raw that reproduces it. Every existing call passes no count
## and still writes a one-point plot, byte for byte as before.
proc rw_mkraw {path plots {npoints 1}} {
  set f [open $path w]
  puts -nonewline $f "Title: B3 rdw window fixture\nDate: Mon Jan 1 00:00:00 2026\n"
  foreach spec $plots {
    set pname [lindex $spec 0] ; set pairs [lindex $spec 1] ; set types [lindex $spec 2]
    puts -nonewline $f "Plotname: $pname\nFlags: real\n"
    puts -nonewline $f "No. Variables: [expr {[llength $pairs]/2}]\nNo. Points: $npoints\nVariables:\n"
    set k 0
    foreach {v val} $pairs {
      set ty [lindex $types $k]
      if {$ty eq {}} { set ty voltage }
      puts -nonewline $f "\t$k\t$v\t$ty\n" ; incr k
    }
    puts -nonewline $f "Values:\n"
    for {set pt 0} {$pt < $npoints} {incr pt} {
      set k 0
      foreach {v val} $pairs {
        if {$k == 0} { puts -nonewline $f "$pt\t$val\n" } else { puts -nonewline $f "\t$val\n" }
        incr k
      }
    }
  }
  close $f
}
## ⚠ THE BINARY MINTER IS NOT A CONVENIENCE — IT IS THE ONLY FIXTURE THAT CAN
## CARRY A NON-FINITE. src/save.c's fast my_atof() path never parsed the words
## `nan`/`inf`, so an ASCII raw carrying either reads back as a confident 0 and
## the defect is INVISIBLE: the seam's own suite was green at 37/37 with a seam
## that returned `nan` as a VALUE. Row Q3 needs this one.
proc rw_mkraw_bin {path pairs types} {
  set f [open $path w]
  fconfigure $f -translation binary
  puts -nonewline $f "Title: B3 rdw window binary fixture\nDate: Mon Jan 1 00:00:00 2026\n"
  puts -nonewline $f "Plotname: Operating Point\nFlags: real\n"
  puts -nonewline $f "No. Variables: [expr {[llength $pairs]/2}]\nNo. Points: 1\nVariables:\n"
  set k 0
  foreach {v val} $pairs {
    set ty [lindex $types $k]
    if {$ty eq {}} { set ty voltage }
    puts -nonewline $f "\t$k\t$v\t$ty\n" ; incr k
  }
  puts -nonewline $f "Binary:\n"
  foreach {v val} $pairs {
    switch -exact -- $val {
      NAN     { puts -nonewline $f [binary format H* 000000000000f87f] }
      INF     { puts -nonewline $f [binary format H* 000000000000f07f] }
      default { puts -nonewline $f [binary format d $val] }
    }
  }
  close $f
}
proc rw_annot {f} {
  catch {xschem raw clear}
  catch {xschem annotate_op $f 0}
  catch {update idletasks}
}

# ============================================================================
# THE FIXTURES
# ============================================================================
# ⚠ EVERY ANSWER DICT BELOW WAS DRIVEN OUT OF THE LANDED SEAM ON THIS BINARY,
# 2026-09-03, against these very raws — they are transcripts, not inventions.
# The six F_SIX values round-trip byte-identically through the raw reader.
set F_SIX {
  v(in)              1.5
  i(@m.x1.m1[id])    1.11e-05
  i(@m.x1.m1[is])    0
  v(@m.x1.m1[vth])   0.75
  @m.x1.m1[gm]       0.001
  v(@m.x1.m1[vds])   1.25
  v(@m.x1.m1[vgs])   0.5
}
set T_SIX {voltage current current voltage notype voltage voltage}
set SIX_PAIRS {{id 1.11e-05} {is 0} {vth 0.75} {gm 0.001} {vds 1.25} {vgs 0.5}}

## THE ALL-ABSENT DEVICE: every column dims=0. Measured answer `devices {}`
## with a populated `absent`, in state ok — the union trap's first half.
set F_ALLABS {v(in) 1.5 i(@m.x1.m9[id]) 0 v(@m.x1.m9[vth]) 0}
set T_ALLABS {voltage {current dims=0} {voltage dims=0}}

## THE ALL-NON-FINITE DEVICE, binary because it must be. Measured answer
## `devices {}` with a populated `nonfinite` — the union trap's second half.
set F_ALLNF {v(in) 1.5 i(@m.x1.m8[id]) NAN v(@m.x1.m8[vth]) INF}
set T_ALLNF {voltage current voltage}

## THE MIXED DEVICE: a NaN, two finites and a genuinely computed zero on one
## device. The zero is not padding — a cut-off transistor has id = 0 and that
## is a measurement (issue 1259's other half, 1272's acceptance row 3).
set F_MIX {v(in) 1.5 i(@m.x1.m1[id]) NAN v(@m.x1.m1[vth]) 0.75 @m.x1.m1[gm] 0.001 i(@m.x1.m1[is]) 0}
set T_MIX {voltage current voltage notype current}

## RULING D-3, five primitives from one XR1, three element letters, two depths,
## and TWO of them publishing a parameter spelled `i` — the measurement that
## refuted the flat {param value} shape. @r.xr10... is the decoy.
set F_XR1 {
  v(net1)                1.5
  i(@r.xr1.x0.rend1[i])  1e-06
  i(@r.xr1.x0.rend2[i])  2e-06
  i(@c.xr1.x0.xc0.c0[c]) 1e-15
  i(@c.xr1.x0.xc1.c0[c]) 2e-15
  i(@b.xr1.x0.brbody[i]) 4e-06
  i(@r.xr10.x0.rend1[i]) 8e-06
}
set F_TRAN {time 0.0 v(in) 1.5 v(out) 0.5 i(v1) -0.001}

set R_SIX    [file join $scratch six.raw]
set R_ALLABS [file join $scratch allabs.raw]
set R_ALLNF  [file join $scratch allnf.raw]
set R_MIX    [file join $scratch mix.raw]
set R_XR1    [file join $scratch xr1.raw]
set R_TRAN   [file join $scratch tran.raw]
set R_TWO    [file join $scratch two.raw]

rw_mkraw     $R_SIX    [list [list {Operating Point} $F_SIX $T_SIX]]
rw_mkraw     $R_ALLABS [list [list {Operating Point} $F_ALLABS $T_ALLABS]]
rw_mkraw_bin $R_ALLNF  $F_ALLNF $T_ALLNF
rw_mkraw_bin $R_MIX    $F_MIX   $T_MIX
rw_mkraw     $R_XR1    [list [list {Operating Point} $F_XR1 {}]]
rw_mkraw     $R_TRAN   [list [list {Transient Analysis} $F_TRAN {}]]
## Q10's file: ONE raw holding an Operating Point plot and THEN a Transient
## Analysis plot, which is what an ordinary OP+TRAN run writes.
rw_mkraw     $R_TWO    [list [list {Operating Point} $F_SIX $T_SIX] \
                             [list {Transient Analysis} $F_TRAN {}]]

## A context dict is {header devpath simtype instname sim}. Spelled through one
## helper so twenty rows cannot drift into twenty shapes.
##
## ⚠ THE FIFTH KEY IS ITEM B2a's (issue 1284). A malformed answer gets a
## sentence that NAMES THE BACKEND that produced it, so the renderer has to be
## told which one that was; `rdw::dump_devpath` sets it for the live path and
## rows F17/F18 pass it explicitly. Defaulting it keeps every existing caller's
## arity, and no row below asserts the contents of a ctx, so nothing moves.
proc rw_ctx {hdr dp {sty op} {inst M1} {sim ngspice}} {
  return [dict create header $hdr devpath $dp simtype $sty instname $inst \
                      sim $sim]
}
## An answer dict, five keys, in the seam's own order.
proc rw_ansd {devices absent nonfinite complete state} {
  return [dict create devices $devices absent $absent nonfinite $nonfinite \
                      complete $complete state $state]
}

set live_tk [expr {[info exists ::has_x] && [info commands winfo] ne {}}]

# ============================================================================
# SECTION S — THE CONTROL, THE STRUCTURAL FENCES AND HYGIENE
# ============================================================================
# S0 is the ONLY row here that is green before B3, and it is evidence for
# nothing but "the seam and the one name builder are still live".

check {S0 CONTROL the machinery B3 builds on is live: the ONE dispatch, the ONE name builder, and the seam hook this window renders} \
  [list [expr {[llength [info commands ::ase::backend_hook]] ? 1 : 0}] \
        [expr {[llength [info commands ::op_annot::devpath]] ? 1 : 0}] \
        [expr {[llength [info commands ::ase::backend_names]] ? 1 : 0}] \
        [expr {![catch {ase::backend_hook ngspice op_param_set} p] && [llength [info commands $p]] ? 1 : 0}]] \
  {1 1 1 1}

# ============================================================================
# SECTION M — THE BUILD RECEIPT, THE MENU, THE REGISTRATION
# ============================================================================
# ⚠ ISSUE 0424 IS LIVE FOR THIS ITEM. src/Makefile and src/config.h are
# GENERATED, gitignored and have NO self-regeneration rule, so a tracked-correct
# Makefile.in sits beside a stale generated Makefile and `make` never notices.
# It is INVISIBLE in-tree (XSCHEM_SHAREDIR resolves to src/) and FATAL once
# installed: 0424 lost op_annot.tcl that way and the installed binary
# SEGFAULTED AT STARTUP with 275 in-tree checks green. M1 asserts the two
# generated lines BY NAME rather than as a count, so "2" cannot be reached by
# two install lines and no uninstall line.
# RED before B3: M1 M2.  GREEN before B3: M3.

set M_MK [rw_slurp $RW_MK]
set M_INST 0 ; set M_RM 0 ; set M_LINES 0
foreach l [split $M_MK "\n"] {
  if {[rw_has $l {install -f rdw.tcl}]} { incr M_INST }
  if {[rw_has $l {rm "$(XSHAREDIR)"/rdw.tcl}]} { incr M_RM }
  if {[rw_has $l {rdw.tcl}]} { incr M_LINES }
}
## ⚠ THE THIRD LEG COUNTS *LINES*, WHICH IS WHAT `grep -c` COUNTS, AND THIS
## ROW USED TO COUNT SUBSTRING OCCURRENCES AND WAS UNSATISFIABLE BY ANY
## CORRECT MAKEFILE. Measured 2026-09-03 on the generated src/Makefile:
##   $(SCCBOX) install -f rdw.tcl  "$(XSHAREDIR)"/rdw.tcl
##   $(SCCBOX) rm "$(XSHAREDIR)"/rdw.tcl
## scconfig's install template names the file on BOTH sides of the copy, so
## every shipped helper appears THREE times as a substring and on TWO lines --
## op_param_lists.tcl (B2's, landed) and results.tcl measure 3 and 2 likewise.
## `grep -c rdw.tcl src/Makefile` -- the receipt CLAUDE.md and the item brief
## both name -- is 2 because grep counts matching LINES. The first two legs
## already pin WHICH two lines, so "2" cannot be reached by two install lines
## and no uninstall line, which is the whole point of asserting by name.
check {M1 the 0424 receipt, by NAME not by count: src/Makefile carries exactly one generated install line for rdw.tcl and exactly one uninstall line, so grep -c is 2 for the right reason} \
  [list $M_INST $M_RM $M_LINES] \
  {1 1 2}

## The Tools entry is found BY LABEL, never by index — every suite in this tree
## that reads the main menubar does the same (test_lib_manager_launch:52,
## test_nh_editor_discover:55, test_create_instance:80), which is why one more
## entry disturbs none of them. ⚠ It must be the MAIN menubar: the ASE session
## window's Tools menu is golded as an exact two-item list by
## tests/headless/test_ase_window.tcl:464, a suite that already carries a
## baseline red where a second is easy to misread.
set M_MKIN [rw_slurp $RW_MKIN]
set M_XTCL [rw_slurp $RW_XTCL]
set M_MENU 0 ; set M_CMD {}
if {$live_tk && [rw_w winfo exists .menubar.tools] eq {1}} {
  set n [rw_w .menubar.tools index end]
  if {![rw_bad $n]} {
    for {set i 0} {$i <= $n} {incr i} {
      if {[rw_w .menubar.tools entrycget $i -label] eq {Results Display Window}} {
        set M_MENU 1 ; set M_CMD [rw_w .menubar.tools entrycget $i -command]
      }
    }
  }
} else {
  ## Under --nogui build_widgets{} never runs (xschem.tcl:19110/:19120 gate it
  ## on has_x), so the menubar cannot be inspected. The SOURCE is asserted
  ## instead, on both arms, and the live widget only where there is one.
  set M_MENU {no-Tk} ; set M_CMD {no-Tk}
}
check {M2 the two src/xschem.tcl edits: rdw.tcl is in Makefile.in's ONE install_shares list, xschem.tcl sources it, and the MAIN menubar Tools menu carries the entry wired to rdw::open} \
  [list [rw_has $M_MKIN {rdw.tcl}] \
        [rw_has $M_XTCL {source $XSCHEM_SHAREDIR/rdw.tcl}] \
        [rw_has $M_XTCL {-label "Results Display Window"}] \
        [rw_has $M_XTCL {rdw::open}] \
        [expr {$live_tk ? $M_MENU : 1}] \
        [expr {$live_tk ? [rw_has $M_CMD {rdw::open}] : 1}]] \
  {1 1 1 1 1 1}

set M_ME  [file rootname [file tail [info script]]]
set M_TXT [rw_slurp $RW_AUDIT]
check {M3 registered by glob, and full_audit.sh is NOT edited: this suite is in none of nogui_tests / logdir_tests / nolog_tests} \
  [list [string match {test_*} $M_ME] \
        [expr {[regexp {mapfile -t files < <\(ls "\$HERE"/test_\*\.tcl \| sort\)} $M_TXT] ? 1 : 0}] \
        [expr {[string first $M_ME $M_TXT] >= 0 ? 1 : 0}]] \
  {1 1 0}

# ============================================================================
# SECTION N — THE NAMESPACE, AND SURVIVING --nogui BY NOT BEING CONSTRUCTED
# ============================================================================
# Acceptance says the window must survive --nogui by CONSTRUCTING NOTHING. The
# 18th bare `source` at xschem.tcl:16749-16815 is UNGUARDED, so a single Tk
# command executed at source time in rdw.tcl aborts startup (issue 0663's
# mechanism, exit 1 with the guard and historically 139 without).
# RED before B3: N1 N2 N3.

set N_PROCS {}
foreach p {have_tk open close build push render_pane set_list inert status
           header sim dump dump_devpath format_answer block_text button_state} {
  lappend N_PROCS [expr {[llength [info procs ::rdw::$p]] ? 1 : 0}]
}
check {N1 the namespace and its sixteen procs exist, and NOTHING has been constructed: .rdw does not exist before the first rdw::open} \
  [list [namespace exists ::rdw] $N_PROCS \
        [expr {$live_tk ? [rw_w winfo exists .rdw] : {no-winfo}}]] \
  [list 1 {1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1} [expr {$live_tk ? 0 : {no-winfo}}]]

## THE NON-BRITTLE PROOF, AND IT RUNS ON BOTH ARMS. A fresh `interp create`
## slave has neither `winfo` nor `xschem` (measured on this binary), so a file
## that executes ANY Tk or any `xschem` command at source time cannot load into
## one. A grep for `toplevel` would be brittle; this is the behaviour itself.
set N2_I [interp create]
set N2_RC [catch {$N2_I eval [list source $RW_FILE]} N2_ERR]
set N2_NS 0 ; set N2_OPEN 0
if {!$N2_RC} {
  catch {set N2_NS   [$N2_I eval {namespace exists ::rdw}]}
  catch {set N2_OPEN [$N2_I eval {llength [info procs ::rdw::open]}]}
}
catch {interp delete $N2_I}
check {N2 src/rdw.tcl sources cleanly into a bare interp that has neither winfo nor xschem, and defines rdw::open there: no Tk and no xschem command runs at source time} \
  [list $N2_RC $N2_NS $N2_OPEN] {0 1 1}

## rdw::open must be safe to CALL headless too — B4 will reach it from a key
## binding, and this suite's own headless arm calls it.
set N3_OPEN [rw_ans ::rdw::open]
set N3_CLOSE [rw_ans ::rdw::close]
check {N3 have_tk answers the arm it is on, and under --nogui rdw::open returns {} and constructs nothing rather than raising} \
  [list [rw_ans ::rdw::have_tk] \
        [expr {$live_tk ? 1 : [expr {$N3_OPEN eq {} ? 1 : 0}]}] \
        [expr {$live_tk ? 1 : [expr {$N3_CLOSE eq {} ? 1 : 0}]}]] \
  [list [expr {$live_tk ? 1 : 0}] 1 1]
if {$live_tk} { rw_ans ::rdw::close }

# ============================================================================
# SECTION H — THE HEADER. SPEC QUESTION Q6's ALREADY-TAKEN DEFAULT.
# ============================================================================
# The user asked for `M2B:/xdut/xbg/xamp1`. THE TREE HAS THREE SPELLINGS AND
# NONE IS THAT ONE, measured on this binary:
#   xschem get sch_path      .xdut.xbg.xamp1.   (leading AND trailing dot)
#   xschem get sim_sch_path  xdut.xbg.xamp1.    (strips every level above the
#                                                raw's load point)
#   the raw's own            @m.x1.x1.xm2.msky130_fd_pr__nfet_01v8
# The default is already taken (spec §5.1 Q6, `look` debt open): mint the
# cadence spelling from sch_path, and put the raw's own path on a second,
# dimmer line, because that is the string a user pastes into ngspice.
# ⚠ AT THE TOP SHEET `sch_path` IS `.` AND THE TRIM YIELDS THE EMPTY STRING.
# The header degenerates to `M1:/` — an edge nobody has ruled, locked here so
# it cannot drift silently.
# RED before B3: H1 H2 H3 H4.

check {H1 the Q6 spelling: sch_path's leading AND trailing dots go, dots become slashes, the path stays rooted, and a % or a [ in a segment passes through verbatim} \
  [list [rw_ans ::rdw::_cadence_path {.xdut.xbg.xamp1.}] \
        [rw_ans ::rdw::_cadence_path {.}] \
        [rw_ans ::rdw::_cadence_path {}] \
        [rw_ans ::rdw::_cadence_path {.a%b.c[d].}] \
        [rw_ans ::rdw::_cadence_path {xdut.xbg.}]] \
  [list /xdut/xbg/xamp1 / / {/a%b/c[d]} /xdut/xbg]

## INVARIANT I1, BEHAVIOURALLY: line 2 is op_annot::devpath's OWN string, byte
## for byte, INCLUDING the empty string for an instance no descriptor claims.
## B3 builds no @-prefixed raw name of its own, ever. Measured consequence of
## building one by hand instead: a bare `xr1.` answers `devices {} state ok`,
## byte-identical to "unknown device" — the wrong-answer-wearing-a-healthy-state
## that returned item B1 [F].
check {H2 rdw::header is {cadence-line devpath-line}: at the top sheet it degenerates to M1:/ and line 2 is BYTE-EQUAL to op_annot::devpath, empty string included} \
  [list [rw_ans ::rdw::header M1] \
        [rw_ans ::rdw::header M2B]] \
  [list [list {M1:/} [rw_ans ::op_annot::devpath M1]] \
        [list {M2B:/} [rw_ans ::op_annot::devpath M2B]]]

## ⚠ WHOLE-LINE `#` COMMENTS ARE STRIPPED FIRST, so a raw name quoted in the
## prose above a proc is prose and not a second builder. A TRAILING `;# ...
## @m.x1.m1 ...` on a CODE line reds this row: say it in a comment line of its
## own, the way this file does.
set H3_B [rw_body ::rdw::header]
set H3_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
check {H3 STRUCTURAL invariant I1, one name builder: rdw::header calls op_annot::devpath, and rdw.tcl builds no raw device name of its own anywhere - no @m./@r./@c. literal and no i(/v( literal} \
  [list [rw_has $H3_B {op_annot::devpath}] \
        [rw_count $H3_F {@m.}] [rw_count $H3_F {@r.}] [rw_count $H3_F {@c.}] \
        [rw_count $H3_F {i(}] [rw_count $H3_F {v(}]] \
  {1 0 0 0 0 0}

set H4_ANS [rw_ansd [dict create {@m.x%1.m1} [list [list {v%s[x]} {2%3}]]] {} {} 0 ok]
set H4_CTX [rw_ctx {M%1:/a[0]/b} {@m.x%1.m1} op {M%1}]
check {H4 a % and a [ in the device path, the header and a parameter name all render VERBATIM: no data becomes a format spec and nothing is subst'ed or eval'ed} \
  [rw_text $H4_ANS $H4_CTX] \
  [rw_lines {M%1:/a[0]/b} {@m.x%1.m1} $RW_INC {    v%s[x] : 2%3} {}]

# ============================================================================
# SECTION F — THE RENDERER. THE PURE LAYER, DRIVEN WITH HAND-BUILT ANSWERS.
# ============================================================================
# Every answer dict here is a transcript of the landed seam (see the header),
# so a row that reds is a statement about the renderer and never about the
# seam. No Tk, no `xschem`, no raw: these rows run identically on both arms.
# RED before B3: every row in this section.

set F_CTX1 [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1]
set F_ANS1 [rw_ansd [dict create {@m.x1.m1} $SIX_PAIRS] {} {} 0 ok]

check {F1 THE PASTE SHAPE: header, dim devpath, the honesty line, then six aligned rows in raw-file order and one separator - the exact text a user copies into a design-review document} \
  [rw_text $F_ANS1 $F_CTX1] \
  [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
            {    id  : 1.11e-05} {    is  : 0} {    vth : 0.75} \
            {    gm  : 0.001} {    vds : 1.25} {    vgs : 0.5} {}]

check {F2 DD-1's corollary: complete 0 prints the incompleteness sentence, exactly ONCE per block, and it is a `note` line rather than a value row} \
  [list [rw_count [rw_text $F_ANS1 $F_CTX1] $RW_INC] \
        [rw_tags $F_ANS1 $F_CTX1]] \
  [list 1 {hdr dim note {} {} {} {} {} {} {}}]

## ⚠ THIS ROW IS A CONTROL AND MUST NOT BE VACUOUS. `[rw_count NOPROC ...]` is
## 0 too, so the count alone would be GREEN before B3 exists and would prove
## nothing at all. The whole block is asserted instead: the same six rows as F1,
## one line shorter.
set F3_T [rw_text [rw_ansd [dict create {@m.x1.m1} $SIX_PAIRS] {} {} 1 ok] $F_CTX1]
check {F3 CONTROL complete 1 prints NO incompleteness sentence - an unconditional honesty line would be indistinguishable from an honest one and would survive the wildcard ngspice} \
  [list [rw_count $F3_T $RW_INC] $F3_T] \
  [list 0 [rw_lines {M1:/xdut/xbg} {@m.x1.m1} \
                    {    id  : 1.11e-05} {    is  : 0} {    vth : 0.75} \
                    {    gm  : 0.001} {    vds : 1.25} {    vgs : 0.5} {}]]

## OBLIGATION 2. A non-converged operating point is a RESULT a designer wants
## told, not a gap and not a number. Driver default, rule debt
## 1245_B1_nonfinite_render option (b); invariant I3 forbids the raw text.
set F4_ANS [rw_ansd [dict create {@m.x1.m1} {{vth 0.75} {gm 0.001} {is 0}}] \
                    {} {{@m.x1.m1 id nan}} 0 ok]
set F4_T [rw_text $F4_ANS $F_CTX1]
check {F4 a nonfinite column renders `(did not converge)` and the block contains neither `nan` nor `inf` anywhere; the finite rows and the genuine zero are untouched} \
  [list $F4_T [rw_count $F4_T {nan}] [rw_count $F4_T {inf}]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    vth : 0.75} {    gm  : 0.001} {    is  : 0} \
                  {    id  : (did not converge)} {}] 0 0]

## INVARIANT I3 for the other bucket: a missing vector renders BLANK — not 0,
## not NaN, not the previous run's number. A bare blank after a colon reads as
## a bug, so the block carries ONE footnote saying what a blank means, and the
## footnote appears EXACTLY when `absent` is non-empty.
set F5_ANS [rw_ansd [dict create {@m.x1.m1} {{gm 0.001}}] \
                    {{@m.x1.m1 ib}} {{@m.x1.m1 vth nan}} 0 ok]
check {F5 an absent column renders a BLANK value with no trailing space, is textually distinct from a nonfinite one, and the blank-value footnote rides exactly once - while F1/F4, with no absent, carry none} \
  [list [rw_text $F5_ANS $F_CTX1] \
        [rw_count [rw_text $F_ANS1 $F_CTX1] $RW_ABSN] \
        [rw_count $F4_T $RW_ABSN]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    gm  : 0.001} {    vth : (did not converge)} {    ib  :} \
                  $RW_ABSN {}] 0 0]

## THE UNION RULE. Both halves measured against the landed seam: an all-dims=0
## device and a binary NaN device BOTH answer `devices {}` in state ok. A
## renderer that walks `dict keys [dict get $ans devices]` prints an EMPTY
## block for a real, named, non-converged device.
set F6_ABS [rw_ansd {} {{@m.x1.m9 id} {@m.x1.m9 vth}} {} 0 ok]
set F6_NF  [rw_ansd {} {} {{@m.x1.m8 id nan} {@m.x1.m8 vth inf}} 0 ok]
check {F6 THE UNION: a device present ONLY in `absent`, and a device present ONLY in `nonfinite`, each still get a full row set - the empty `devices` dict is not an empty answer} \
  [list [rw_text $F6_ABS [rw_ctx {M9:/} {@m.x1.m9} op M9]] \
        [rw_text $F6_NF  [rw_ctx {M8:/} {@m.x1.m8} op M8]]] \
  [list [rw_lines {M9:/} {@m.x1.m9} $RW_INC {    id  :} {    vth :} $RW_ABSN {}] \
        [rw_lines {M8:/} {@m.x1.m8} $RW_INC \
                  {    id  : (did not converge)} {    vth : (did not converge)} {}]]

## RULING D-3. Two of these five primitives BOTH publish a parameter spelled
## `i`; without the per-primitive sub-header the two numbers cannot be told
## apart, which is exactly why the seam's return shape was amended from a flat
## {param value} list to the five-key dict.
set F7_ANS [rw_ansd [dict create {@r.xr1.x0.rend1} {{i 1e-06}} \
                                 {@r.xr1.x0.rend2} {{i 2e-06}} \
                                 {@c.xr1.x0.xc0.c0} {{c 1e-15}} \
                                 {@c.xr1.x0.xc1.c0} {{c 2e-15}} \
                                 {@b.xr1.x0.brbody} {{i 4e-06}}] {} {} 0 ok]
check {F7 D-3: five primitives from one XR1 print five sub-headers in raw-file order, and the two columns both spelled `i` are attributed to DIFFERENT primitives} \
  [rw_text $F7_ANS [rw_ctx {XR1:/} {@r.xr1} op XR1]] \
  [rw_lines {XR1:/} {@r.xr1} $RW_INC \
            {  @r.xr1.x0.rend1} {    i : 1e-06} \
            {  @r.xr1.x0.rend2} {    i : 2e-06} \
            {  @c.xr1.x0.xc0.c0} {    c : 1e-15} \
            {  @c.xr1.x0.xc1.c0} {    c : 2e-15} \
            {  @b.xr1.x0.brbody} {    i : 4e-06} {}]

check {F8 the sub-header is suppressed ONLY when there is exactly one primitive whose name equals line 2; one primitive under a BROADER request still names itself} \
  [list [rw_count [rw_text $F_ANS1 $F_CTX1] {  @m.x1.m1}] \
        [rw_text [rw_ansd [dict create {@m.x1.m1} {{id 1.11e-05}}] {} {} 0 ok] \
                 [rw_ctx {M1:/} {@m.x1} op M1]]] \
  [list 0 [rw_lines {M1:/} {@m.x1} $RW_INC {  @m.x1.m1} {    id : 1.11e-05} {}]]

## THE FIFTH SILENCE. state ok with nothing in any bucket is the COMMON case
## under measured rule R1 (gm/gds/vth exist only if the deck saved them;
## `save all` does not include them), and it is neither an error nor a
## rendering bug. Saying nothing at all would be indistinguishable from one.
check {F9 state ok with an EMPTY union prints the fifth sentence, naming the devpath, and NOT the incompleteness line - which would say the same thing twice} \
  [rw_text [rw_ansd {} {} {} 0 ok] $F_CTX1] \
  [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_OKEMPTY {@m.x1.m1}] {}]

## OBLIGATION 3. The four non-ok states otherwise all arrive as the same empty
## list. `not_op` in particular means the user is looking at a TRANSIENT — say
## so and say what to do; none of the five may say "nothing found".
set F10_NORAW  [rw_text [rw_ansd {} {} {} 0 no_raw]        $F_CTX1]
set F10_NOTOP  [rw_text [rw_ansd {} {} {} 0 not_op]        [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} tran M1]]
set F10_NOTANN [rw_text [rw_ansd {} {} {} 0 not_annotated] $F_CTX1]
set F10_NODP   [rw_text [rw_ansd {} {} {} 0 no_devpath]    [rw_ctx {M1:/xdut/xbg} {} op M1]]
set F10_OKE    [rw_text [rw_ansd {} {} {} 0 ok]            $F_CTX1]
set F10_ALL [list $F10_NORAW $F10_NOTOP $F10_NOTANN $F10_NODP $F10_OKE]
check {F10 FIVE pairwise-distinct sentences: not_op names the loaded analysis AND the remedy, not_annotated names the annotate step, no_devpath explains the missing descriptor, and none of the five says "nothing found"} \
  [list $F10_NORAW $F10_NOTOP $F10_NOTANN $F10_NODP \
        [llength [lsort -unique $F10_ALL]] \
        [rw_count [join $F10_ALL "\n"] {nothing found}]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_NORAW {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_NOTOP tran] {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_NOTANNOT {}] \
        [rw_lines {M1:/xdut/xbg} [RW_NODEVPATH M1] {}] \
        5 0]

## ⚠ NON-VACUITY LEG, same trap as F3: two zero counts over five NOPROC strings
## are also {0 0}. The third leg says the five blocks were really rendered.
check {F11 no non-ok block carries the incompleteness sentence or the blank-value footnote - "this is what the run saved" under "no results are loaded" is nonsense} \
  [list [rw_count [join $F10_ALL "\n"] $RW_INC] \
        [rw_count [join $F10_ALL "\n"] $RW_ABSN] \
        [expr {[rw_bad $F10_NORAW] || [rw_bad $F10_NOTOP] || [rw_bad $F10_NOTANN]
               || [rw_bad $F10_NODP] || [rw_bad $F10_OKE] ? {NOT-RENDERED} : 1}]] \
  {0 0 1}

set F12_B [rw_body ::rdw::format_answer]
check {F12 a genuinely computed 0 renders as 0 and not as a blank (absence is not zero); and STRUCTURAL, format_answer touches no xschem, no winfo and no widget} \
  [list [rw_has [rw_text $F_ANS1 $F_CTX1] {    is  : 0}] \
        [rw_count $F12_B {xschem }] [rw_count $F12_B {winfo}] [rw_count $F12_B {.rdw}]] \
  {1 0 0 0}

check {F13 the button table IS spec 4.2 B7, as data: Add greyed on the annotation list, Delete greyed on `all`, everything else normal, and the default list is `annotation`} \
  [list [rw_ans ::rdw::button_state up annotation] [rw_ans ::rdw::button_state down annotation] \
        [rw_ans ::rdw::button_state delete annotation] [rw_ans ::rdw::button_state add annotation] \
        [rw_ans ::rdw::button_state save annotation] \
        [rw_ans ::rdw::button_state delete summary] [rw_ans ::rdw::button_state add summary] \
        [rw_ans ::rdw::button_state delete all] [rw_ans ::rdw::button_state add all] \
        [rw_ans ::rdw::button_state save all] \
        [expr {[info exists ::rdw::listkind] ? $::rdw::listkind : {NOVAR}}]] \
  {normal normal normal disabled normal normal normal disabled normal normal annotation}

# ============================================================================
# F14-F15 — THE SIXTH STATE: `ok` WITH NUMBERS, FROM AN ANALYSIS THAT IS NOT AN
# OPERATING POINT (issue 1282 part 1, ruling DD-5)
# ============================================================================
# The seam's allow-list is `{op dc}`, not `{op}` — ase.tcl:8803, copied
# DELIBERATELY from update_op()'s own guard in src/save.c so that the window
# and the on-sheet annotation agree about what counts as an operating point.
# So a raw whose current slot is a DC transfer characteristic answers `ok` with
# real point-0 numbers, and B3's window presented them as an operating point:
# MEASURED, sim_type = dc, state = ok, and the block said "operating-point"
# twice and `dc` ZERO TIMES. A DC sweep's point 0 is the first step of the
# sweep, not the circuit's quiescent point, and pasting that block into a
# design-review document under a heading that says "operating point" is exactly
# the plausible-wrong-number failure invariant I3 and ruling D5-1 exist to
# prevent. `ctx` already carried `simtype` and `_state_sentence` already read
# it; only the `not_op` arm used it.
#
# RULING DD-5, option (a) of the three issue 1282 lists: KEEP RENDERING IT AND
# NAME THE ANALYSIS. Option (c), refusing `dc`, is forbidden — it would
# contradict the allow-list B1 copied from the C on purpose, and it would red
# row G3b of tests/headless/test_rdw_seam_1245.tcl, a cross-language fence that
# counts save.c's own op/dc strcmps.
#
# ⚠ F15 IS THE CONTROL AND IT IS NOT OPTIONAL. The gate is
# `$sty ne {} && $sty ne "op"`: the empty half matters because a hand-built ctx
# and a failed `xschem raw sim_type` both produce {}, and an unconditional
# sentence would be indistinguishable from an honest one — the same trap F3
# carries for the incompleteness line. F15 asserts the WHOLE BLOCK, not a count
# of zero, because a count over a NOPROC string is zero too.
# RED BEFORE B2a: F14 and Q6. GREEN BEFORE B2a: F15.
set F14_CTX [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} dc M1]
set F14_T [rw_text $F_ANS1 $F14_CTX]
check {F14 a state-ok block whose analysis is NOT an operating point carries one extra sentence naming it, between the device path and the incompleteness line, as a `note` and not a value row - so the word `dc` is on screen instead of nowhere} \
  [list $F14_T [rw_tags $F_ANS1 $F14_CTX] \
        [expr {[rw_count $F14_T {dc}] >= 1 ? 1 : 0}]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_ANALYSIS dc] $RW_INC \
                  {    id  : 1.11e-05} {    is  : 0} {    vth : 0.75} \
                  {    gm  : 0.001} {    vds : 1.25} {    vgs : 0.5} {}] \
        {hdr dim note note {} {} {} {} {} {} {}} 1]

set F15_OPBLOCK [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                          {    id  : 1.11e-05} {    is  : 0} {    vth : 0.75} \
                          {    gm  : 0.001} {    vds : 1.25} {    vgs : 0.5} {}]
check {F15 CONTROL a state-ok block whose simtype IS `op`, and one whose simtype is EMPTY, carry no analysis sentence at all - asserted as the whole block, because a bare count of zero is also zero over a string that was never rendered} \
  [list [rw_text $F_ANS1 $F_CTX1] \
        [rw_text $F_ANS1 [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} {} M1]]] \
  [list $F15_OPBLOCK $F15_OPBLOCK]

# ============================================================================
# F16 — THE UNION'S ORDER, AND THE COLUMN ORDER INSIDE ONE DEVICE
# (issue 1283 gap B — A FENCE THAT WAS MISSING, NOT A DEFECT)
# ============================================================================
# ⚠ THIS ROW IS GREEN BEFORE B2a AND PROVES NOTHING ABOUT TODAY'S CODE. It is
# here because src/rdw.tcl's own comment promises the row set is built in
# "first-appearance order across devices -> absent -> nonfinite" and NO ROW HELD
# THAT PROMISE: reversing `rdw::_rowdevs` so the absent/nonfinite devices come
# first passed ALL 32 headless AND ALL 42 display checks. Its red-before proof
# is therefore the SABOTAGE, not the shipped tree — B1's lesson one item on: a
# green count is a statement about the FENCE.
#
# The second half was measured while filing 1283 and is also unasserted
# anywhere: COLUMN ORDER WITHIN A DEVICE IS BUCKET ORDER, NOT RAW-FILE ORDER —
# measured values, then non-finite, then absent. That groups the blanks
# together, which reads better, but it is stated nowhere, so a later crew
# cannot tell the design from the accident. One mixed answer closes both halves:
# three devices, one in each bucket, and one device carrying all three kinds.
set F16_ANS [rw_ansd [dict create {@m.x1.mA} {{id 1} {gm 2}}] \
                     {{@m.x1.mB ib} {@m.x1.mA ib}} \
                     {{@m.x1.mC gds nan} {@m.x1.mA vth nan}} 0 ok]
set F16_CTX [rw_ctx {MX:/} {@m.x1} op MX]
check {F16 the union is built devices -> absent -> nonfinite in first-appearance order, and within ONE device the columns are the measured ones, then the non-finite ones, then the absent ones - the promise rdw.tcl's own comment makes and no row held} \
  [list [rw_ans ::rdw::_rowdevs $F16_ANS] [rw_text $F16_ANS $F16_CTX]] \
  [list {@m.x1.mA @m.x1.mB @m.x1.mC} \
        [rw_lines {MX:/} {@m.x1} $RW_INC \
                  {  @m.x1.mA} {    id  : 1} {    gm  : 2} \
                  {    vth : (did not converge)} {    ib  :} \
                  {  @m.x1.mB} {    ib  :} \
                  {  @m.x1.mC} {    gds : (did not converge)} \
                  $RW_ABSN {}]]

# ============================================================================
# F17-F20 — A BACKEND'S ANSWER DICT MUST NOT MAKE THIS WINDOW LIE, BLANK OR
# RAISE (issue 1284)
# ============================================================================
# ⚠ THIS IS THE ONE OF THE NINE THE USER'S OWN FUTURE DEPENDS ON. It is
# UNREACHABLE through the shipped ngspice backend — that backend builds
# `devices` with `dict set` and gates every value through
# `op_annot::raw_class`'s `string is double -strict` — and REACHABLE by any
# third-party backend the D-5 seam exists to admit. Ruling D-5 records that the
# user IS BUILDING A CUSTOM NGSPICE that will supply a wildcard operating-point
# save, and the seam exists precisely to admit it, so the first backend to
# exercise these shapes will be the user's own. `rdw::format_answer` treated the
# five-key dict as TRUSTED INPUT; it is whatever a backend hands it.
#
# FOUR SHAPES MEASURED ON THIS BINARY, plus two more found while planning:
#   (a) F17  a malformed `devices` value -> `_rowdevs`'s dict-level catch
#            swallows it, the union comes back empty, and the window renders the
#            FIFTH SILENCE: "This run's raw holds no operating-point columns for
#            <dp>". That is a STATEMENT ABOUT THE RAW and it is FALSE — the
#            backend answered, and its answer was unreadable. This is the
#            wrong-answer-wearing-a-healthy-state shape that returned item B1
#            [F] (issue 1272), one layer out.
#   (b) F18  a malformed per-device VALUE -> UNCAUGHT RAISE out of the pure
#            renderer that every row of this suite and every widget path calls.
#            `_rowdevs` catches at the dict level; nothing caught the
#            `foreach {p v}` over a value. In the Tk path it surfaces as a
#            background error and the pane paints nothing.
#            ⚠ AND TWO MORE, MEASURED WHILE PLANNING B2a AND NOT IN THE ISSUE:
#            a malformed `absent` bucket and a malformed `nonfinite` bucket each
#            RAISE the same way, from the un-caught `foreach` inside _rowdevs
#            and from the two bucket walks in format_answer.
#   (c) F19  a value-less pair renders BYTE-IDENTICALLY to an absent column and
#            without the footnote that says what a blank means, so the
#            renderer's one honest distinction is lost. Section 3 of the issue
#            is the reachable twin: the footnote is per BLOCK, so an
#            empty-string value in a block that has any absent column inherits a
#            footnote that is FALSE about it. Rendering both as words closes
#            (c) and section 3 in one move and leaves F5's "the footnote rides
#            exactly once" golden where it is.
#   (d) F20  a newline inside a value makes ONE PAIR become TWO LINES, the
#            second unindented and carrying NO TAG, breaking the
#            one-pair-one-line model `block_text` and `render_pane` share. A
#            device NAME and a parameter NAME do it too.
# ALL FOUR RED BEFORE B2a: F17 renders the fifth silence, F18 RAISES three
# times, F19 renders two blanks indistinguishable from the absent one, F20
# renders nine lines for a seven-entry block.
set F1718_CTX [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1 zzsim]
## a well-formed dict whose `devices` VALUE is not a well-formed list
set F17_BADDEV "@m.x1.m1 \{\{id 1"
set F17_ANS [dict create devices $F17_BADDEV absent {} nonfinite {} \
                         complete 0 state ok]
set F17_T [rw_text $F17_ANS $F1718_CTX]
check {F17 a malformed `devices` value gets its OWN sentence, naming the backend that produced it, instead of falling into the fifth silence - which is a claim about the RAW and would be false} \
  [list [rw_bad $F17_T] $F17_T \
        [rw_count $F17_T [RW_OKEMPTY {@m.x1.m1}]] \
        [rw_tags $F17_ANS $F1718_CTX]] \
  [list 0 [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_FLAW zzsim] {}] 0 {hdr dim note {}}]

set F18_V [dict create devices [dict create {@m.x1.m1} "\{\{id 1"] \
                       absent {} nonfinite {} complete 0 state ok]
set F18_A [rw_ansd [dict create {@m.x1.m1} {{id 1}}] "\{\{@m.x1.m1 ib" {} 0 ok]
set F18_N [rw_ansd [dict create {@m.x1.m1} {{id 1}}] {} "\{\{@m.x1.m1 gm nan" 0 ok]
set F18_TV [rw_text $F18_V $F1718_CTX]
set F18_TA [rw_text $F18_A $F1718_CTX]
set F18_TN [rw_text $F18_N $F1718_CTX]
set F18_FLAW [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_FLAW zzsim] {}]
check {F18 a malformed per-device VALUE, a malformed `absent` bucket and a malformed `nonfinite` bucket each return a block instead of RAISING out of the pure renderer every row and every widget path calls, and each carries the malformed-answer sentence} \
  [list [rw_bad $F18_TV] [rw_bad $F18_TA] [rw_bad $F18_TN] \
        $F18_TV $F18_TA $F18_TN] \
  [list 0 0 0 $F18_FLAW $F18_FLAW $F18_FLAW]

set F19_ANS [rw_ansd [dict create {@m.x1.m1} {{id} {gm {}} {vds 1.25}}] \
                     {{@m.x1.m1 ib}} {} 0 ok]
set F19_T [rw_text $F19_ANS $F1718_CTX]
check {F19 a value-less pair and an empty-string value both render as WORDS, textually distinct from the blank an absent column gets - so the blank keeps exactly one meaning and the per-block footnote, which rides exactly once, stays true of the only row it is about} \
  [list $F19_T [rw_count $F19_T $RW_ABSN]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  "    id  : $RW_NOVAL" "    gm  : $RW_NOVAL" \
                  {    vds : 1.25} {    ib  :} $RW_ABSN {}] 1]

set F20_ANS [rw_ansd [dict create "@m.x1.mA\nX" \
                       [list [list "id\ty" "1.5\nINJECTED"] [list gm "2\r3"]]] \
                     {} {} 0 ok]
set F20_CTX [rw_ctx {M1:/} {@m.x1} op M1 zzsim]
set F20_B [rw_block $F20_ANS $F20_CTX]
set F20_T [rw_text  $F20_ANS $F20_CTX]
check {F20 a newline, a carriage return and a tab inside a value, inside a parameter name and inside a DEVICE name all collapse to one space: the block has exactly one line per entry, and no unindented untagged line appears in the middle of it} \
  [list [expr {[rw_bad $F20_B] ? {NOT-RENDERED} : [llength $F20_B]}] \
        [expr {[rw_bad $F20_T] ? {NOT-RENDERED} : [llength [split $F20_T "\n"]]}] \
        [rw_count $F20_T "\n\n"] [rw_count $F20_T "\r"] [rw_count $F20_T "\t"] \
        $F20_T] \
  [list 7 7 0 0 0 \
        [rw_lines {M1:/} {@m.x1} $RW_INC {  @m.x1.mA X} \
                  {    id y : 1.5 INJECTED} {    gm   : 2 3} {}]]

# ============================================================================
# F21-F26 — ITEM B2a-2: A NON-`ok` STATE IS A COMPLETE AND LEGAL ANSWER ON ITS
# OWN, AND A MALFORMED-INPUT PATH MAY NEVER ACCUSE AN INNOCENT BACKEND
# (issue 1284, whose first fix was REFUTED)
# ============================================================================
# F17/F18 above are sound and stay: a PRESENT bucket that cannot be walked IS a
# flaw in the backend's answer and deserves a sentence naming the backend.
# What they could not see is what the SAME predicate does to an answer that is
# not malformed at all.
#
# THE ADVERSARY'S OWN MEASUREMENT, REPRODUCED HERE AS THE RED. A third-party
# backend's perfectly legal minimal refusal `{state no_raw}` renders:
#   HEAD    -> No simulation results are loaded. Run a simulation, or load a
#              raw file, then ask again.
#   PATCHED -> The zzsim operating-point reader answered in a shape this window
#              could not read ...
# and MEASURED WHILE WRITING THIS SUITE, the blast radius is WIDER than the
# issue says: `{state not_annotated}`, `{state not_op}` and `{state no_devpath}`
# do it too. All four correct, actionable sentences become one false accusation
# against a backend that did nothing wrong.
#
# TWO CAUSES, AND A FIX NEEDS BOTH:
#   ORDER    `_answer_flaw` runs at rdw.tcl:370, ELEVEN lines BEFORE the
#            `$state ne {ok}` branch at :381. Reordering alone still leaves a
#            legal `{state ok devices {...}}` unvalidated in the wrong
#            direction.
#   SHAPE    `_answer_flaw` opens
#              if {[catch {dict keys [dict get $ans devices]} devs]} { return 1 }
#            so an ABSENT `devices` key is malformed BY CONSTRUCTION. Narrowing
#            alone still lets `{state no_raw}` reach `_flaw_line`.
# So: check the state FIRST; validate shape ONLY for an answer whose state is
# `ok`, and there only for a bucket that is PRESENT. `devices`, `absent`,
# `nonfinite` and `complete` are required only when `state` is `ok`.
#
# ⚠ THIS IS EXACTLY THE CLASS RULING D-5 EXISTS TO ADMIT. The user is building
# a custom ngspice and it will be the first backend to occupy it; a window that
# greets a correct minimal answer with a complaint about the backend sends its
# author hunting a bug that is in this file.
#
# F21 F22 F23 F25 F26 ARE RED BEFORE B2a-2. F24 IS A FENCE and is GREEN BEFORE
# AND AFTER — it is the half of 1284 that F17/F18 got right, held still so the
# narrowing cannot quietly discard it.
## The sixth sentence, and the one HEAD renders for a state it does not know.
## Spelled here because a state name a backend invents must reach the screen.
proc RW_UNKSTATE {s} { return "The operating-point reader answered with a state this window does not know: '$s'." }
set F21_CTX [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} tran M1 zzsim]
set F21_TAB [list no_raw        $RW_NORAW \
                  not_annotated $RW_NOTANNOT \
                  not_op        [RW_NOTOP tran] \
                  no_devpath    [RW_NODEVPATH M1]]
set F21_GOT {} ; set F21_EXP {}
foreach {_s _sent} $F21_TAB {
  ## the MINIMAL legal refusal — one key, which is all a refusal has to carry
  set _min [rw_text [dict create state $_s] $F21_CTX]
  ## the SAME state delivered as the seam's full five-key dict
  set _ful [rw_text [rw_ansd {} {} {} 0 $_s] $F21_CTX]
  set _gold [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $_sent {}]
  lappend F21_GOT [list $_s $_min $_ful [rw_count $_min [RW_FLAW zzsim]]]
  lappend F21_EXP [list $_s $_gold $_gold 0]
}
check {F21 THE ADVERSARY'S OWN INPUT: each of the four non-`ok` states delivered as a MINIMAL one-key answer renders its OWN state sentence, byte-identical to the same state delivered as a full five-key dict, and not one of the four names the backend - a non-`ok` state is a complete and legal answer on its own} \
  $F21_GOT $F21_EXP

## A REFUSAL MAKES NO DATA CLAIM, so nothing may walk its data keys — even when
## one is present and garbage. The state is the whole answer.
set F22_ANS [dict create state no_raw devices "\{\{id 1"]
set F22_T [rw_text $F22_ANS $F21_CTX]
check {F22 a non-`ok` state is legal even when a data key IS present and malformed: `{state no_raw devices <garbage>}` still renders the no_raw sentence, because a refusal makes no claim about data and nothing may walk it} \
  [list [rw_bad $F22_T] $F22_T [rw_count $F22_T [RW_FLAW zzsim]]] \
  [list 0 [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_NORAW {}] 0]

## AN ABSENT BUCKET IS EMPTY, NOT MALFORMED. `{state ok}` is the legal minimum
## for an answer that found nothing, and it must reach the FIFTH SILENCE — the
## sentence naming the device path — not an accusation.
set F23_ANS [dict create state ok]
set F23_T [rw_text $F23_ANS $F21_CTX]
check {F23 `{state ok}` with every data key ABSENT renders the FIFTH SILENCE naming the device path, not the malformed-answer sentence - an absent bucket is EMPTY, and a backend answering the legal minimum is not a backend at fault} \
  [list [rw_bad $F23_T] $F23_T [rw_count $F23_T [RW_FLAW zzsim]]] \
  [list 0 [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_OKEMPTY {@m.x1.m1}] {}] 0]

## THE SHAPE HALF SURVIVES THE NARROWING. A bucket that is PRESENT and cannot
## be walked is still a flaw, in all three buckets, and so is the MIXED case —
## no `devices` key at all beside a malformed `absent`, where the narrowing
## must not let the absent key excuse the malformed one.
## FENCE — GREEN BEFORE AND AFTER.
set F24_D [dict create devices "@m.x1.m1 \{\{id 1" absent {} nonfinite {} \
                       complete 0 state ok]
set F24_A [dict create devices {} absent "\{\{@m.x1.m1 ib" nonfinite {} \
                       complete 0 state ok]
set F24_N [dict create devices {} absent {} nonfinite "\{\{@m.x1.m1 gm nan" \
                       complete 0 state ok]
set F24_MIX [dict create state ok absent "\{\{@m.x1.m1 ib"]
set F24_FLAW [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_FLAW zzsim] {}]
check {F24 FENCE under `state ok` a PRESENT but un-walkable `devices`, `absent` or `nonfinite` still gets the flaw sentence naming the backend, and so does the MIXED case of no `devices` key at all beside a malformed `absent` - the narrowing may not discard the half of 1284 that was right} \
  [list [rw_text $F24_D $F21_CTX] [rw_text $F24_A $F21_CTX] \
        [rw_text $F24_N $F21_CTX] [rw_text $F24_MIX $F21_CTX]] \
  [list $F24_FLAW $F24_FLAW $F24_FLAW $F24_FLAW]

## AN ANSWER WITH NO READABLE `state` IS ITSELF MALFORMED — including one that
## is not a dict at all — and gets the sentence naming the backend, because the
## remedy is there. HEAD instead defaults to `set state unknown`, inventing a
## state name the backend never sent and rendering a sentence that blames the
## window for the backend's omission. A state that IS present but unrecognised
## is a different fact and keeps its own sentence, naming the state.
set F25_NOSTATE [dict create devices {} absent {} nonfinite {} complete 0]
set F25_NOTDICT {a b c}
set F25_WEIRD   [dict create state sideways]
set F25_TN [rw_text $F25_NOSTATE $F21_CTX]
set F25_TD [rw_text $F25_NOTDICT $F21_CTX]
set F25_TW [rw_text $F25_WEIRD   $F21_CTX]
check {F25 an answer with NO `state` key, and one that is not a dict at all, each get the flaw sentence naming the backend - while an answer whose `state` is PRESENT but unrecognised gets the sentence naming THAT state, and the two are pairwise distinct} \
  [list $F25_TN $F25_TD $F25_TW \
        [expr {$F25_TN eq $F25_TW ? 1 : 0}]] \
  [list $F24_FLAW $F24_FLAW \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_UNKSTATE sideways] {}] 0]

## STRUCTURAL, AND IT IS THE ONLY ROW THAT CAN STOP A LATER EDIT FROM REOPENING
## THIS. The ORDER is half the defect, and an order is not visible in any
## output once the shape check has been narrowed — a future `_answer_flaw` that
## quietly went back to treating an absent key as malformed would be caught by
## F21/F23, but one that merely moved back above the state branch would not, so
## long as the narrowing held. The call the state is read through comes FIRST.
set F26_B  [rw_body ::rdw::format_answer]
set F26_PS [string first {_answer_state} $F26_B]
set F26_PF [string first {_answer_flaw}  $F26_B]
check {F26 STRUCTURAL in `rdw::format_answer`'s own body the state is read through `_answer_state` BEFORE `_answer_flaw` is consulted, so a later edit cannot silently restore the ordering that caused the regression} \
  [list [expr {$F26_PS >= 0 ? 1 : 0}] [expr {$F26_PF >= 0 ? 1 : 0}] \
        [expr {($F26_PS >= 0 && $F26_PF >= 0 && $F26_PS < $F26_PF) ? 1 : 0}]] \
  {1 1 1}

# ============================================================================
# F27-F28 — ITEM B2d: THE TWO SHAPES ISSUE 1284 SECTION 5 LEFT OPEN, AND THEY
# ARE STILL OPEN IN THE PRESERVED FIX
# ============================================================================
# ⚠ THESE TWO ARE RED AGAINST **BOTH** SHIPPED STATES — against HEAD, which
# raises or lies about every shape F17-F20 name, AND against the preserved
# B2a-2 fix itself, which closes those four and leaves these two. Issue 1284's
# own ACCEPT row says "1284 FIXED", so lifting the preserved hunks and stopping
# there ships the issue half done. MEASURED on a scratch copy carrying the
# preserved fix and nothing else, 2026-09-04:
#     nonfinite {{@m.x1.m1 gm}}   (two fields, NO text)  ->  "    gm : (did not converge)"
#     devices   {{{} 1.5}}        (a nameless pair)      ->  "     : 1.5"
#
# WHY EACH IS A FLAW AND NOT A TOLERATED RENDER:
#   F27  `rdw::_nonfinite_text` DISCARDS its argument (src/rdw.tcl:177) and
#        returns the words unconditionally, so an entry carrying no evidence at
#        all still makes the window ASSERT that a column did not converge. That
#        is obligation 2 turned inside out: the words exist to say what the raw
#        actually holds, and here the raw was never quoted. The seam's contract
#        is a `{<rawdev> <param> <text>}` TRIPLE (item B1's re-do), so a
#        two-field entry is an answer that does not meet it, not a short form.
#        `_answer_flaw`'s shared `llength $e < 2` gate lets it through because
#        `absent` and `nonfinite` were checked at the same width; they are not
#        the same width. The bucket's own arity is the predicate the implement
#        agent must name (`rdw::_bucket_width`), so this row has a sabotage
#        handle of its own and does not have to borrow F17's.
#   F28  a pair whose parameter NAME is empty, or is nothing but whitespace,
#        renders a value under no name — "a blank row that means nothing", in
#        `_answer_flaw`'s OWN comment, which is the reason it rejects a
#        one-element absent entry. The predicate was arity, and arity is the
#        wrong question: F19's value-less `{id}` has arity 1 and a perfectly
#        good name, and must keep rendering `(no value reported)`. The question
#        is whether the entry NAMES a parameter (`rdw::_named`), asked of the
#        devices pair's own first field and of an absent/nonfinite entry's
#        SECOND field.
#
# ⚠ NEITHER IS REACHABLE THROUGH THE SHIPPED BACKEND, AND THAT IS THE POINT
# ruling D-5 makes: `ase::op_param_split` returns {} for an empty parameter and
# `ase::op_param_set` always emits a nonfinite TRIPLE, so no live path moves.
# The user is building a custom ngspice; the first backend to occupy these
# shapes will be their own, and a window that prints "(did not converge)" about
# a column nobody reported would send its author hunting a convergence problem
# that does not exist.
#
# Both rows carry their CONTROL in the same check, because a predicate that
# rejects everything would satisfy the red half alone.
set F27_BAD2 [rw_ansd [dict create {@m.x1.m1} {{id 1.5}}] {} \
                      [list [list {@m.x1.m1} gm]] 0 ok]
set F27_BAD1 [rw_ansd [dict create {@m.x1.m1} {{id 1.5}}] {} \
                      [list [list {@m.x1.m1}]] 0 ok]
set F27_GOOD [rw_ansd [dict create {@m.x1.m1} {{id 1.5}}] {} \
                      [list [list {@m.x1.m1} gm nan]] 0 ok]
set F27_T2 [rw_text $F27_BAD2 $F1718_CTX]
set F27_T1 [rw_text $F27_BAD1 $F1718_CTX]
set F27_TG [rw_text $F27_GOOD $F1718_CTX]
set F27_FLAW [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_FLAW zzsim] {}]
check {F27 a `nonfinite` entry that carries no text field gets the malformed-answer sentence instead of making the window assert non-convergence on no evidence - while a well-formed {rawdev param text} triple still renders the words, so the bucket's arity is the predicate and not the words} \
  [list [rw_bad $F27_T2] [rw_bad $F27_T1] [rw_bad $F27_TG] \
        $F27_T2 $F27_T1 \
        [rw_count $F27_T2 $RW_NF] [rw_count $F27_T1 $RW_NF] \
        $F27_TG] \
  [list 0 0 0 $F27_FLAW $F27_FLAW 0 0 \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    id : 1.5} "    gm : $RW_NF" {}]]

set F28_DEV [rw_ansd [dict create {@m.x1.m1} [list [list {} 1.5] [list id 2]]] \
                     {} {} 0 ok]
set F28_WS  [rw_ansd [dict create {@m.x1.m1} [list [list "\n\t " 1.5] [list id 2]]] \
                     {} {} 0 ok]
set F28_ABS [rw_ansd [dict create {@m.x1.m1} {{id 2}}] \
                     [list [list {@m.x1.m1} {}]] {} 0 ok]
set F28_NF  [rw_ansd [dict create {@m.x1.m1} {{id 2}}] {} \
                     [list [list {@m.x1.m1} {} nan]] 0 ok]
set F28_GOOD [rw_ansd [dict create {@m.x1.m1} [list [list vgs 1.5] [list id 2]]] \
                      {{@m.x1.m1 ib}} {{@m.x1.m1 gm nan}} 0 ok]
set F28_TD [rw_text $F28_DEV  $F1718_CTX]
set F28_TW [rw_text $F28_WS   $F1718_CTX]
set F28_TA [rw_text $F28_ABS  $F1718_CTX]
set F28_TN [rw_text $F28_NF   $F1718_CTX]
set F28_TG [rw_text $F28_GOOD $F1718_CTX]
check {F28 a parameter NAME that is empty or nothing but whitespace - in `devices`, in `absent` and in `nonfinite` - gets the malformed-answer sentence rather than a value belonging to no parameter, while the same three entries carrying real names render exactly as before: the question is whether the entry names a parameter, not how many fields it has} \
  [list [rw_bad $F28_TD] [rw_bad $F28_TW] [rw_bad $F28_TA] [rw_bad $F28_TN] \
        $F28_TD $F28_TW $F28_TA $F28_TN \
        [rw_count $F28_TD { : 1.5}] \
        [rw_bad $F28_TG] $F28_TG] \
  [list 0 0 0 0 \
        $F27_FLAW $F27_FLAW $F27_FLAW $F27_FLAW 0 0 \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    vgs : 1.5} {    id  : 2} "    gm  : $RW_NF" \
                  {    ib  :} $RW_ABSN {}]]

# ============================================================================
# F29 — ITEM B2d, THE ADVERSARY'S REFUTATION: THE FIFTH KEY IS A LINE INJECTOR
# ============================================================================
# ⚠ RED AGAINST HEAD **AND** AGAINST THE PRESERVED FIX, AND IT IS THE BATCH'S
# OWN RECURRING LESSON landing on this very section. F20 fences a newline, a CR
# and a tab inside a VALUE, a PARAMETER NAME and a DEVICE NAME — the three
# fragments `rdw::_oneline` was applied to. F25 fences the unrecognised-state
# arm, with the newline-free word `sideways`. The two rows cross the whole
# class except at their intersection, and the intersection is where the hole
# was: `_state_sentence`'s default arm echoes the backend's own `state`
# verbatim, so an answer as small as
#     devices {} absent {} nonfinite {} complete 0 state "weird\n    id : 1e-5"
# rendered FOUR block entries as FIVE lines of paste text — the extra line a
# correctly indented, correctly formatted operating-point row that NO BUCKET
# EVER CARRIED. MEASURED on the fixed tree 2026-09-04: 4 entries, 5 lines of
# `block_text`, 7 lines in the real Tk pane on :99. Three counts for one block,
# and the shipped comment at src/rdw.tcl:370 states the one-line rule as
# absolute. It is the LIE half of issue 1284's own title, reached through the
# answer dict AFTER the fix, and invariant I3's harm exactly: on the clipboard
# an injected row is indistinguishable from a measured one.
#
# THE SAME ESCAPE EXISTED AT FOUR MORE SITES, all fenced below because one row
# per site is what stops the next author reopening the one nobody wrote down:
# `_flaw_line`'s backend name, the `dim` device-path line and the fifth
# silence's `$dp`, and the `no_devpath` sentence's instance name. A fifth,
# dump_devpath's "could not answer: $ans", interpolates a CAUGHT TCL ERROR and
# so is multi-line by nature; it is covered by the same fix and reached through
# `rdw::_refusal`.
#
# ⚠ THE PREDICATE IS STRUCTURAL, NOT A GOLDEN. `block_text` joins the entries
# with a newline, so the block carries one line per entry IF AND ONLY IF
# `llength $blk` equals the split of its own text — which is the one-pair-one-
# line model `block_text` and `render_pane` share, asserted as an identity
# rather than as a count that would have to be updated whenever a row moves.
# The goldens ride alongside so a fix that flattened the block by DELETING the
# sentence could not pass.
proc rw_onelines {ans ctx} {
  set b [rw_block $ans $ctx]
  if {[rw_bad $b]} { return $b }
  set t [rw_ans ::rdw::block_text $b]
  if {[rw_bad $t]} { return $t }
  return [expr {[llength $b] == [llength [split $t "\n"]] ? 1 : 0}]
}

set F29_INJ  "weird\n    id  : 1.11e-05\r    vth : 0.45\tgm : 2"
set F29_FLAT {weird     id  : 1.11e-05     vth : 0.45 gm : 2}
set F29_CTX  [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1 zzsim]

## (a) the refutation itself: an unrecognised state whose text carries rows.
set F29_A  [rw_ansd {} {} {} 0 $F29_INJ]
## (b) the backend NAME the flaw sentence quotes, from ctx. No `state` key, so
##     the flaw arm is what fires.
set F29_BC [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1 "zz\n    id : 4.2e-3"]
set F29_B  [dict create devices {} absent {} nonfinite {} complete 0]
## (c) the device path, which is BOTH line 2 and the fifth silence's subject.
set F29_CC [rw_ctx {M1:/xdut/xbg} "@m.x1.m1\n    id : 9.9" op M1 zzsim]
set F29_C  [rw_ansd {} {} {} 0 ok]
## (d) the instance name, which is the schematic's and not the backend's.
set F29_DC [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op "M1\n    id : 7.7" zzsim]
set F29_D  [dict create state no_devpath]
## THE CONTROL, in the same check: a healthy answer keeps its bytes and its
## own entries-equal-lines identity, so a renderer that flattened everything
## could not satisfy the red half alone.
set F29_G  [rw_ansd [dict create {@m.x1.m1} {{id 1.5}}] {{@m.x1.m1 ib}} {} 0 ok]

check {F29 no fragment of a backend answer or of the context can put a SECOND line inside one block entry: the unrecognised-state echo, the flaw sentence's backend name, the device-path line and the no_devpath instance name each collapse to one line, so the block's entry count and its paste text's line count stay identical - an injected row would be indistinguishable from a measured one on the clipboard} \
  [list [rw_onelines $F29_A $F29_CTX] [rw_onelines $F29_B $F29_BC] \
        [rw_onelines $F29_C $F29_CC]  [rw_onelines $F29_D $F29_DC] \
        [rw_onelines $F29_G $F29_CTX] \
        [rw_text $F29_A $F29_CTX] [rw_text $F29_B $F29_BC] \
        [rw_text $F29_C $F29_CC]  [rw_text $F29_D $F29_DC] \
        [rw_text $F29_G $F29_CTX]] \
  [list 1 1 1 1 1 \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_UNKSTATE $F29_FLAT] {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_FLAW {zz     id : 4.2e-3}] {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1     id : 9.9} \
                  [RW_OKEMPTY {@m.x1.m1     id : 9.9}] {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} \
                  [RW_NODEVPATH {M1     id : 7.7}] {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    id : 1.5} {    ib :} $RW_ABSN {}]]

# ============================================================================
# SECTION Q — END TO END THROUGH THE SEAM, AND SPEC QUESTION Q10 AS AN ASSERTION
# ============================================================================
# ⚠ Q10 IS ANSWERED YES AND IS ASSERTED HERE, NOT ASKED. Item B1 measured it
# with a real ngspice: a deck with `.op` then `.tran` writes ONE file holding
# TWO plots, `xschem raw read` lands on the Operating Point and returns real
# device numbers. DECISIONS.md asks for it as the RDW suite's first check; this
# is that check, on a fixture so it cannot rot. Two caveats B1 measured and
# this suite does not depend on: on the `.control`+`write` writer the second
# `write` overwrites the first without `set appendwrite`, and once the tran
# slot is READ it becomes current, at which point `raw list` answers about the
# transient.
# RED before B3: Q1 Q2 Q3.

rw_annot $R_TWO
set Q1_ST {} ; catch {set Q1_ST [xschem raw sim_type]}
set Q1_CTX [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} $Q1_ST M1]
set Q1_BLK [rw_ans ::rdw::dump_devpath {@m.x1.m1} $Q1_CTX]
set Q1_TXT [expr {[rw_bad $Q1_BLK] ? $Q1_BLK : [rw_ans ::rdw::block_text $Q1_BLK]}]
check {Q1 Q10 ASSERTED: one raw holding an Operating Point plot AND a Transient plot lands on the OP, and the window renders its six real numbers with the honesty line - the RDW IS reachable after an ordinary OP+TRAN run} \
  [list $Q1_ST $Q1_TXT] \
  [list op [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
            {    id  : 1.11e-05} {    is  : 0} {    vth : 0.75} \
            {    gm  : 0.001} {    vds : 1.25} {    vgs : 0.5} {}]]

## The block is PUSHED, and the store is namespace state that works headless —
## the pane is a projection of it, never the other way round.
##
## ⚠ REWRITTEN BY ITEM B2a (issue 1283 gap A). AS B3 SHIPPED IT THIS ROW WAS
## TITLED "newest first" AND PUSHED EXACTLY ONE BLOCK, then asserted that block
## was at index 0 — which is TRUE UNDER EITHER ORDERING. Measured: sabotaging
## `rdw::_insert_index` from `1.0` to `end`, which flips both the pane insert
## and the prepend in `rdw::push`, passed ALL 32 HEADLESS CHECKS and reds only
## on `:99`, in the two widget rows W3 and W3b. So the accept row "newest dump
## on top" had NO HEADLESS WITNESS AT ALL, and every `--nogui` run and
## full_audit.sh's own nogui leg would have passed with the store reversed. A
## SECOND, DISTINCT block is what makes the assertion mean what its name says.
##
## ⚠ THIS ROW IS GREEN BEFORE B2a — it is a missing FENCE, not a defect — so
## its red-before proof is the SB-OLDEST-ON-TOP sabotage, which must now red
## the --nogui arm and not only the display one.
set Q1B_N0 [expr {[info exists ::rdw::blocks] ? [llength $::rdw::blocks] : -1}]
set Q1B_NEW [rw_ans ::rdw::push \
  [rw_block [rw_ansd [dict create {@m.x1.mq1b} {{id 42}}] {} {} 0 ok] \
            [rw_ctx {MQ1B:/} {@m.x1.mq1b} op MQ1B]]]
check {Q1b the dump is pushed onto ::rdw::blocks, NEWEST FIRST, on BOTH arms: a SECOND distinct push lands at index 0 and the first one is now at index 1 - the store is namespace state and the pane is only its projection} \
  [list [expr {[info exists ::rdw::blocks] ? 1 : 0}] \
        [expr {$Q1B_N0 == 1 ? 1 : $Q1B_N0}] \
        [expr {[rw_bad $Q1B_NEW] ? {NOT-PUSHED} : 1}] \
        [expr {[llength $::rdw::blocks] == $Q1B_N0 + 1 ? 1 : 0}] \
        [expr {[lindex $::rdw::blocks 0] eq $Q1B_NEW ? 1 : 0}] \
        [expr {[lindex $::rdw::blocks 1] eq $Q1_BLK ? 1 : 0}] \
        [lindex [lindex $::rdw::blocks 0] 0]] \
  {1 1 1 1 1 1 {hdr MQ1B:/}}

## THE FOUR SILENCES, END TO END. Each is produced by driving the real seam
## into that state, so the row asserts the renderer AND the state plumbing.
proc rw_dumptext {devpath ctx} {
  set b [rw_ans ::rdw::dump_devpath $devpath $ctx]
  if {[rw_bad $b]} { return $b }
  return [rw_ans ::rdw::block_text $b]
}

catch {xschem raw clear}
set Q2_NORAW [rw_dumptext {@m.x1.m1} $F_CTX1]
catch {xschem raw clear}
catch {xschem raw read $R_SIX op}
set Q2_NOTANN [rw_dumptext {@m.x1.m1} $F_CTX1]
catch {xschem raw clear}
catch {xschem raw read $R_TRAN tran}
set Q2_STY {} ; catch {set Q2_STY [xschem raw sim_type]}
set Q2_NOTOP [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} $Q2_STY M1]]
set Q2_NODP [rw_dumptext {} [rw_ctx {M1:/xdut/xbg} {} $Q2_STY M1]]
check {Q2 THE FOUR SILENCES END TO END, each driven into the real seam: no raw at all, a raw read but never annotated, a TRANSIENT slot, and an instance with no descriptor - four different sentences and not one number} \
  [list $Q2_STY $Q2_NORAW $Q2_NOTANN $Q2_NOTOP $Q2_NODP] \
  [list tran \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_NORAW {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_NOTANNOT {}] \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_NOTOP tran] {}] \
        [rw_lines {M1:/xdut/xbg} [RW_NODEVPATH M1] {}]]

## THE UNION TRAP, THROUGH THE REAL SEAM RATHER THAN A HAND-BUILT DICT. The
## dims=0 raw and the BINARY NaN raw both make the seam answer `devices {}` in
## state ok, and both name a real device the user is looking at.
rw_annot $R_ALLABS
set Q3_ABS [rw_dumptext {@m.x1.m9} [rw_ctx {M9:/} {@m.x1.m9} op M9]]
rw_annot $R_ALLNF
set Q3_NF [rw_dumptext {@m.x1.m8} [rw_ctx {M8:/} {@m.x1.m8} op M8]]
rw_annot $R_MIX
set Q3_MIX [rw_dumptext {@m.x1.m1} $F_CTX1]
check {Q3 the two devices the seam answers with an EMPTY `devices` dict still render in full - the dims=0 one as blanks with the footnote, the BINARY NaN/Inf one as `(did not converge)` with no `nan` anywhere - and a mixed device keeps its genuine zero} \
  [list $Q3_ABS $Q3_NF [rw_count "$Q3_ABS$Q3_NF$Q3_MIX" {nan}] $Q3_MIX] \
  [list [rw_lines {M9:/} {@m.x1.m9} $RW_INC {    id  :} {    vth :} $RW_ABSN {}] \
        [rw_lines {M8:/} {@m.x1.m8} $RW_INC \
                  {    id  : (did not converge)} {    vth : (did not converge)} {}] \
        0 \
        [rw_lines {M1:/xdut/xbg} {@m.x1.m1} $RW_INC \
                  {    vth : 0.75} {    gm  : 0.001} {    is  : 0} \
                  {    id  : (did not converge)} {}]]

## D-3 end to end: ONE request, FIVE primitives out of the real seam, and the
## decoy @r.xr10... excluded by the segment-boundary rule.
rw_annot $R_XR1
set Q4_TXT [rw_dumptext {@r.xr1} [rw_ctx {XR1:/} {@r.xr1} op XR1]]
check {Q4 D-3 end to end: one XR1 request resolves through the seam to five primitives in raw-file order, each labelled, and the xr10 decoy is nowhere in the block} \
  [list $Q4_TXT [rw_count $Q4_TXT {xr10}]] \
  [list [rw_lines {XR1:/} {@r.xr1} $RW_INC \
                  {  @r.xr1.x0.rend1} {    i : 1e-06} \
                  {  @r.xr1.x0.rend2} {    i : 2e-06} \
                  {  @c.xr1.x0.xc0.c0} {    c : 1e-15} \
                  {  @c.xr1.x0.xc1.c0} {    c : 2e-15} \
                  {  @b.xr1.x0.brbody} {    i : 4e-06} {}] 0]

## rdw::sim resolves the BACKEND; the seam is never called by its proc name.
## Behaviourally identical today, which is precisely why row S1 is structural:
## the whole point of the seam is that nothing above it changes when the user's
## wildcard ngspice arrives.
check {Q5 rdw::sim resolves the one registered backend rather than naming a proc, and an explicit ::rdw::sim override wins - the door B4 and B5 drive} \
  [list [rw_ans ::rdw::sim] [ase::backend_names]] \
  [list ngspice ngspice]

# ============================================================================
# Q6 — RULING DD-5 END TO END, ON TWO RAWS THAT BOTH ANSWER `dc`
# ============================================================================
# The first is an ordinary DC transfer characteristic, which is what issue 1282
# is about. THE SECOND IS THE ONE THAT MOVED THE WORDING: save.c:1073 and :1120
# both carry `if(raw->npoints[...] > 1 && !strcmp(sim_type, "op")) sim_type =
# "dc";`, so a MULTI-POINT `Operating Point` plot is renamed `dc` by the reader
# and a user who ran nothing but an operating point lands in this arm too.
# MEASURED on this binary: a three-point `Plotname: Operating Point` raw answers
# `xschem raw sim_type` = dc. That is why RW_ANALYSIS names what the loaded
# results CALL THEMSELVES rather than what the user ran (see the wording block),
# and it is also why option (c) - refusing `dc` - would have been wrong on its
# own terms and not only forbidden by DD-5: it would refuse a real operating
# point. test_op_annot's row T26 is a three-point Operating Point that must keep
# publishing, so the C is not moving either.
# RED BEFORE B2a: measured sim_type=dc, block-mentions-dc=0, both raws.
set R_DC  [file join $scratch dcsweep.raw]
set R_OP3 [file join $scratch op3point.raw]
rw_mkraw $R_DC  [list [list {DC transfer characteristic} $F_SIX $T_SIX]]
rw_mkraw $R_OP3 [list [list {Operating Point} $F_SIX $T_SIX]] 3
rw_annot $R_DC
set Q6_STY1 {} ; catch {set Q6_STY1 [xschem raw sim_type]}
set Q6_T1 [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} $Q6_STY1 M1]]
rw_annot $R_OP3
set Q6_STY2 {} ; catch {set Q6_STY2 [xschem raw sim_type]}
set Q6_T2 [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} $Q6_STY2 M1]]
set Q6_WANT [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_ANALYSIS dc] $RW_INC \
                      {    id  : 1.11e-05} {    is  : 0} {    vth : 0.75} \
                      {    gm  : 0.001} {    vds : 1.25} {    vgs : 0.5} {}]
check {Q6 DD-5 end to end through the real seam: a DC transfer characteristic AND a three-point Operating Point (which save.c itself renames `dc`) both answer ok with real point-0 numbers, and both blocks now NAME the analysis instead of presenting it as an operating point} \
  [list $Q6_STY1 $Q6_STY2 $Q6_T1 $Q6_T2] \
  [list dc dc $Q6_WANT $Q6_WANT]

# ============================================================================
# Q7-Q8 — TWO DIFFERENT REFUSALS, TWO DIFFERENT SENTENCES (issue 1282 part 2)
# ============================================================================
# `rdw::dump_devpath` had ONE `catch {ase::backend_hook $s op_param_set}` arm
# producing ONE sentence - "Simulator X has no operating-point reader" - for TWO
# different facts with two different remedies: NO SUCH BACKEND, and a backend
# that registered without the (deliberately non-required) `op_param_set` hook.
# `ase::backend_hook` already mints two distinct errors for them (ase.tcl:550
# "unknown simulator" and :552 "unknown hook"), so no new information is needed,
# only a caller that asks which case it is. ITEM B5 IS THE FIRST THING THAT SETS
# `::rdw::sim`, so the split has to exist before B5, not after.
#
# ⚠ Q8 REGISTERS A SECOND BACKEND AND MUST RESTORE `::ase::backends`. Row Q5
# above asserts `ase::backend_names` is exactly {ngspice}, and `rdw::sim`
# returns the single registered backend when there is exactly one - so a second
# one left behind would change what Q5 and the seam suite assert. The
# save-and-restore and the five-hook registration are copied verbatim from
# tests/headless/test_rdw_seam_1245.tcl:505-514, whose row S3 exists to keep
# `op_param_set` OFF the required-hook list precisely so this case is reachable.
# BOTH RED BEFORE B2a: measured, an unregistered name produced
# "Simulator nosuchsim has no operating-point reader, so this window has nothing
# to show for it." - the registered-but-no-reader sentence, for the other fact.
set Q7_OLDSIM {} ; catch {set Q7_OLDSIM $::rdw::sim}
set ::rdw::sim zznosuchsim
set Q7_T [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1 zznosuchsim]]
set ::rdw::sim {}
check {Q7 a name no backend registered says exactly that, names it, and gives the remedy - it does NOT say the simulator has no operating-point reader, which is a different fact with a different fix} \
  [list $Q7_T [rw_count $Q7_T {has no operating-point reader}] \
        [rw_count $Q7_T {op_param_set}]] \
  [list [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_NOSIM zznosuchsim] {}] 0 0]

set Q8_SAVED {} ; catch {set Q8_SAVED $::ase::backends}
set Q8_REG [rw_ans ::ase::register_backend zzb2a5 [dict create \
  render_deck  [rw_ans ::ase::backend_hook ngspice render_deck] \
  run_cmd      [rw_ans ::ase::backend_hook ngspice run_cmd] \
  log_file     [rw_ans ::ase::backend_hook ngspice log_file] \
  result_probe [rw_ans ::ase::backend_hook ngspice result_probe] \
  raw_file     [rw_ans ::ase::backend_hook ngspice raw_file]]]
set ::rdw::sim zzb2a5
set Q8_T [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1 zzb2a5]]
set ::rdw::sim {}
if {$Q8_SAVED ne {}} { set ::ase::backends $Q8_SAVED }
if {$Q7_OLDSIM ne {}} { set ::rdw::sim $Q7_OLDSIM }
check {Q8 a backend registered with the five required hooks and NO op_param_set says THAT instead, names the hook a backend has to add, is a different sentence from Q7's - and the second backend is put back, so ase::backend_names is {ngspice} again} \
  [list $Q8_REG $Q8_T [rw_has $Q8_T {op_param_set}] \
        [expr {$Q7_T ne $Q8_T ? 1 : 0}] \
        [ase::backend_names]] \
  [list zzb2a5 [rw_lines {M1:/xdut/xbg} {@m.x1.m1} [RW_NOREADER zzb2a5] {}] 1 1 ngspice]

# ============================================================================
# Q9 — THE INERT-BUTTON MESSAGE, HEADLESS (issue 1283 gap C)
# ============================================================================
# ⚠ GREEN BEFORE B2a, AND THAT IS THE POINT. `rdw::status` was split precisely
# so the inert path is drivable with no widget (`::rdw::statusmsg` is set
# whether or not one exists), but the ONLY row asserting that an inert button
# SAYS anything is W4b, inside the Tk-guarded section. Measured: making
# `rdw::status` a no-op passes the FULL 32-check headless run. Its red-before
# proof is the sabotage, not the shipped tree. W4b on the display arm is the
# twin this row is copied from.
rw_ans ::rdw::status {}
rw_ans ::rdw::inert Delete
set Q9_M1 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
rw_ans ::rdw::inert Save
set Q9_M2 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
check {Q9 an inert button SAYS SO in the window's own status line with no widget anywhere: Delete names itself and names the item that wires it, Save says something different, and the variable is clearable - a disabled-but-silent button is the failure rdw::inert exists to prevent} \
  [list [expr {$Q9_M1 ne {} && $Q9_M1 ne {NOVAR} ? 1 : 0}] \
        [rw_has $Q9_M1 {Delete}] [rw_has $Q9_M1 {B5}] \
        [rw_has $Q9_M2 {Save}] [rw_has $Q9_M2 {B5}] \
        [expr {$Q9_M1 ne $Q9_M2 ? 1 : 0}] \
        [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]] \
  {1 1 1 1 1 1 {}}

# ============================================================================
# SECTION W — THE WIDGETS. DISPLAY ARM ONLY, AND IT IS NOT OPTIONAL.
# ============================================================================
# ⚠ A SUITE THAT ONLY EVER RUNS --nogui WILL PASS WHILE THE WINDOW IS BROKEN.
# These rows run under `GUI_GATE=0 tests/headless/devdisplay.sh exec ...` (:99,
# openbox live) and self-skip headless. `-exportselection 1` takes the X
# PRIMARY selection away from whatever held it (measured), so the window is
# CLOSED at the end of the section — test_calc_skeleton's own hygiene.
# RED before B3: W1 W2 W3 W4.  GREEN before B3: W0 (it measures Tk, not B3).

if {!$live_tk} {
  puts "W section skipped (no DISPLAY) -- sections M N H F Q S ran on this arm"
} elseif {[catch {

## W0 IS WHAT STOPS W2 PASSING VACUOUSLY. "Drive a keystroke and prove the
## buffer is unchanged" is satisfied perfectly by delivering no keystroke at
## all, and bare `event generate` key delivery is a known ~1-in-5 flake in this
## tree (test_calc_skeleton:1368). So the SAME delivery is aimed at an ordinary
## editable text first: if the control does not change, the mechanism is dead
## and this row says so instead of W2 quietly passing.
catch {destroy .rdwctl}
toplevel .rdwctl
text .rdwctl.t -width 24 -height 3
pack .rdwctl.t
update idletasks
set W0_TRIES 0
while {$W0_TRIES < 12 && [string trim [rw_w .rdwctl.t get 1.0 end]] eq {}} {
  incr W0_TRIES
  catch {focus -force .rdwctl.t}
  catch {event generate .rdwctl.t <Key-x> -when now}
  catch {update}
}
check {W0 CONTROL the synthesised-keystroke mechanism itself is live: the same delivery W2 uses really does put a character into an ordinary editable text} \
  [string trim [rw_w .rdwctl.t get 1.0 end]] x
set W0_N [expr {$W0_TRIES < 3 ? 3 : $W0_TRIES}]

# --- W1 the window's life ----------------------------------------------------
set W1_OPEN [rw_ans ::rdw::open]
catch {update idletasks}
set W1_KIDS [llength [rw_w winfo children .]]
set W1_OPEN2 [rw_ans ::rdw::open]
catch {update idletasks}
check {W1 singleton: open builds .rdw with the spec's title, a second open RAISES the same toplevel rather than building a second, and WM_DELETE_WINDOW is rdw::close} \
  [list $W1_OPEN [rw_w winfo exists .rdw] [rw_w winfo class .rdw] \
        [rw_w wm title .rdw] $W1_OPEN2 \
        [llength [rw_w winfo children .]] \
        [rw_w wm protocol .rdw WM_DELETE_WINDOW]] \
  [list .rdw 1 Toplevel {Results Display Window} .rdw $W1_KIDS rdw::close]

catch {wm iconify .rdw} ; catch {update}
rw_ans ::rdw::open
catch {update}
set W1_STATE [rw_w wm state .rdw]
rw_ans ::rdw::close
catch {update idletasks}
set W1_GONE [rw_w winfo exists .rdw]
## DECISION 6: the dumps are the artifact the feature exists to produce (the
## user's words: paste them into design-review documents). They are namespace
## state, not window state, and a stray click on the window's X must not cost
## an hour of them. Rule debt 1245_B3_dumps_survive_close.
set W1_NB [expr {[info exists ::rdw::blocks] ? [llength $::rdw::blocks] : -1}]
rw_ans ::rdw::open
catch {update idletasks}
set W1_PANE [rw_w .rdw.p.t get 1.0 end]
check {W1b iconify then open leaves it normal, close destroys it, the stored dumps SURVIVE the close, and a reopen paints them again} \
  [list $W1_STATE $W1_GONE [expr {$W1_NB > 0 ? 1 : 0}] \
        [expr {[info exists ::rdw::blocks] && [llength $::rdw::blocks] == $W1_NB ? 1 : 0}] \
        [rw_has $W1_PANE {@r.xr1.x0.rend1}]] \
  {normal 0 1 1 1}

# --- W2 read-only AND copyable: the reason this window exists ----------------
## The user's own framing: the text must be selectable and copyable so it can be
## pasted into design-review documents, and READ-ONLY because nobody may type
## into a record of a simulation.
set W2_BEFORE [rw_w .rdw.p.t get 1.0 end]
rw_w .rdw.p.t insert end {TYPED BY A TEST}
rw_w .rdw.p.t delete 1.0 1.5
set W2_AFTER_API [rw_w .rdw.p.t get 1.0 end]
foreach seq {<Key-x> <Key-Return> <Key-BackSpace> <Key-Delete> <<Paste>>} {
  for {set i 0} {$i < $W0_N} {incr i} {
    catch {focus -force .rdw.p.t}
    catch {event generate .rdw.p.t $seq -when now}
  }
  catch {update}
}
set W2_AFTER_KEY [rw_w .rdw.p.t get 1.0 end]
check {W2 READ-ONLY: the pane is -state disabled, and neither the widget API nor five real keystrokes (x Return BackSpace Delete Paste) change one byte of the buffer} \
  [list [rw_w .rdw.p.t cget -state] \
        [expr {$W2_AFTER_API eq $W2_BEFORE ? 1 : 0}] \
        [expr {$W2_AFTER_KEY eq $W2_BEFORE ? 1 : 0}]] \
  {disabled 1 1}

catch {event generate .rdw.p.t <<SelectAll>> -when now}
catch {update}
set W2_SEL {} ; catch {set W2_SEL [.rdw.p.t get sel.first sel.last]}
set W2_OWN [rw_w selection own -selection PRIMARY]
set W2_PRIM {} ; catch {set W2_PRIM [selection get -selection PRIMARY]}
catch {clipboard clear}
catch {event generate .rdw.p.t <<Copy>> -when now}
catch {update}
set W2_CLIP {} ; catch {set W2_CLIP [clipboard get]}
check {W2b COPYABLE: -exportselection is 1, a select-all really owns the X PRIMARY selection, `selection get` hands back the pane's own text, and Ctrl-C puts it on the clipboard - the whole reason this window is not a CIW dump} \
  [list [rw_w .rdw.p.t cget -exportselection] \
        [expr {[string length $W2_SEL] > 40 ? 1 : 0}] \
        [rw_has $W2_SEL {@r.xr1.x0.rend1}] \
        $W2_OWN \
        [expr {$W2_PRIM eq $W2_SEL ? 1 : 0}] \
        [expr {$W2_CLIP eq $W2_SEL ? 1 : 0}]] \
  [list 1 1 1 .rdw.p.t 1 1]

# --- W3 newest on top, and the pane really scrolls ---------------------------
rw_ans ::rdw::push [rw_block [rw_ansd [dict create {@m.x1.mA} {{id 1}}] {} {} 0 ok] \
                              [rw_ctx {MA:/} {@m.x1.mA} op MA]]
rw_ans ::rdw::push [rw_block [rw_ansd [dict create {@m.x1.mB} {{id 2}}] {} {} 0 ok] \
                              [rw_ctx {MB:/} {@m.x1.mB} op MB]]
catch {update idletasks}
set W3_FIRST [string trim [rw_w .rdw.p.t get 1.0 1.end]]
set W3_IDXA [string first {MA:/} [rw_w .rdw.p.t get 1.0 end]]
set W3_IDXB [string first {MB:/} [rw_w .rdw.p.t get 1.0 end]]
check {W3 NEWEST DUMP ON TOP: the second push is the FIRST block in the store and the FIRST line in the pane, and the older one is pushed below it} \
  [list $W3_FIRST \
        [expr {[info exists ::rdw::blocks] && [llength $::rdw::blocks] > 0
               && [lindex [lindex $::rdw::blocks 0] 0] eq {hdr MB:/} ? 1 : 0}] \
        [expr {$W3_IDXB >= 0 && $W3_IDXA > $W3_IDXB ? 1 : 0}]] \
  {MB:/ 1 1}

set W3_BIG {}
for {set i 0} {$i < 200} {incr i} { lappend W3_BIG [list p$i $i] }
rw_ans ::rdw::push [rw_block [rw_ansd [dict create {@m.x1.mbig} $W3_BIG] {} {} 0 ok] \
                              [rw_ctx {MBIG:/} {@m.x1.mbig} op MBIG]]
catch {update}
set W3_YV [rw_w .rdw.p.t yview]
check {W3b a dump longer than the pane really scrolls: the vertical view spans less than the whole buffer and the scrollbar is mapped} \
  [list [expr {[llength $W3_YV] == 2 && [lindex $W3_YV 1] < 0.9 ? 1 : 0}] \
        [rw_w winfo ismapped .rdw.p.ys]] \
  {1 1}

# --- W4 the button column, greyed per spec 4.2 B7, and INERT -----------------
## ⚠ B5 WIRES THESE. B3 builds the column, the greying and a test-drivable path
## to each button, and nothing else. Decision 1 (rule debt
## 1245_B3_add_greyed_on_list1): Add on the annotation list is GREYED, not
## absent — the column keeps a constant shape as the user switches lists, and
## an absent button moves the other four under the pointer.
set W4_MISS {}
foreach {id label} {up Up down Down delete Delete add Add save Save} {
  set w .rdw.b.$id
  if {[rw_w winfo exists $w] ne {1}} { lappend W4_MISS $id=MISSING ; continue }
  if {[rw_w winfo class $w] ne {Button}} { lappend W4_MISS $id=[rw_w winfo class $w] }
  if {[rw_w $w cget -text] ne $label} { lappend W4_MISS $id=[rw_w $w cget -text] }
}
set W4_STATES {}
foreach kind {annotation summary all} {
  rw_ans ::rdw::set_list $kind
  catch {update idletasks}
  set row {}
  foreach id {up down delete add save} {
    lappend row [rw_w .rdw.b.$id cget -state]
    if {[rw_w .rdw.b.$id cget -state] ne [rw_ans ::rdw::button_state $id $kind]} {
      lappend W4_MISS $kind/$id=WIDGET-DISAGREES-WITH-TABLE
    }
  }
  lappend W4_STATES $row
}
check {W4 the five buttons exist with the spec's labels, and the widget greying follows spec 4.2 B7 across all three lists AND agrees with the pure table: Add greyed on the annotation list, Delete greyed on `all`} \
  [list $W4_MISS $W4_STATES] \
  [list {} [list {normal normal normal disabled normal} \
                 {normal normal normal normal normal} \
                 {normal normal disabled normal normal}]]

rw_ans ::rdw::set_list summary
catch {update idletasks}
rw_ans ::rdw::status {}
rw_w .rdw.b.up invoke
set W4_MSG1 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
rw_w .rdw.b.save invoke
set W4_MSG2 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
check {W4b every ENABLED button is inert and SAYS SO in the window's own status line, naming itself and naming the item that wires it - a disabled-but-silent button is the failure calc::inert exists to prevent} \
  [list [expr {$W4_MSG1 ne {} && $W4_MSG1 ne {NOVAR} ? 1 : 0}] \
        [rw_has $W4_MSG1 {Up}] [rw_has $W4_MSG1 {B5}] \
        [rw_has $W4_MSG2 {Save}] [rw_has $W4_MSG2 {B5}] \
        [expr {$W4_MSG1 ne $W4_MSG2 ? 1 : 0}]] \
  {1 1 1 1 1 1}

## HYGIENE: hand the X PRIMARY selection back and leave no toplevel behind.
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::close
catch {destroy .rdwctl}
catch {update idletasks}
check {W5 the section leaves nothing behind: .rdw and the control toplevel are both destroyed, so the next suite's selection assertions are not looking at this one's PRIMARY} \
  [list [rw_w winfo exists .rdw] [rw_w winfo exists .rdwctl]] {0 0}

} wbig]} {
  check "W SECTION RAISED (a Tk error is a FAIL, not a silent exit-0 banner)" $wbig {}
}

# ============================================================================
# SECTION N — 1298 AND 1297: THE DOOR OWNS THE ANALYSIS, AND THE ARTICLE AGREES
# ============================================================================
# 1298. `rdw::dump_devpath` is THE SEAM'S ONLY DOOR and the entry point items B4
# and B5 call with contexts they build themselves. Ruling DD-5's "name the
# analysis" sentence was put into the ctx by `rdw::dump` ALONE, so any other
# caller got a DC sweep rendered as an operating point again -- the defect 1282
# was filed and fixed for, walking straight back in through the door the fix did
# not cover. The door now fills `simtype` in the same way it already fills
# `sim`, so DD-5 is a property of the SEAM rather than of one caller.
#
# ⚠ AN EXPLICIT `simtype` IN THE CTX STILL WINS, and `{}` still means "say
# nothing". Both matter: the suite hand-builds contexts, and `_analysis_line`
# deliberately stays silent for `{}` because a failed `xschem raw sim_type` and
# a hand-built ctx produce the same empty string -- a sentence that fired on
# those would be indistinguishable from an honest one.
#
# 1297. The analysis kind comes from the simulator, so `"a $sty analysis"` read
# **"a op analysis"** for the one kind this whole window exists to talk about.
# RED before the fix: ND1, ND3.

## ⚠ THE CONTEXT IS BUILT WITHOUT `simtype`, WHICH IS THE WHOLE ROW. Every
## other context in this file goes through `rw_ctx`, which supplies one -- so
## every existing row exercises the caller that already gets it right, and
## none of them could have seen 1298. Items B4 and B5 build their own.
rw_annot $R_DC
set ND_CTX [dict create header {M1:/xdut/xbg} devpath {@m.x1.m1} instname M1 \
                        sim ngspice]
set ND_T [rw_dumptext {@m.x1.m1} $ND_CTX]
check {ND1 the DOOR names the analysis, so a caller that builds its own context cannot lose ruling DD-5} \
  [expr {[string first [RW_ANALYSIS dc] $ND_T] >= 0 ? 1 : 0}] 1

## An explicit simtype must still win over the door's own read, or every
## hand-built context in this file changes meaning.
set ND_T2 [rw_dumptext {@m.x1.m1} [rw_ctx {M1:/xdut/xbg} {@m.x1.m1} op M1]]
check {ND2 an EXPLICIT simtype in the context still wins over the door's own read} \
  [expr {[string first [RW_ANALYSIS dc] $ND_T2] >= 0 ? 1 : 0}] 0

check {ND3 the article agrees with the analysis kind, so the one word this window exists for is not "a op"} \
  [list [rdw::_article op] [rdw::_article ac] [rdw::_article dc] \
        [rdw::_article tran] [rdw::_article noise]] \
  {an an a a a}

check {ND4 and the not_op refusal uses it, so the sentence reads "an op analysis" and never "a op analysis"} \
  [expr {[string match {*a op *} [rdw::format_answer [rw_ansd {} {} {} 0 not_op] \
            [dict create header H devpath D instname M1 simtype op]]] ? 1 : 0}] 0

# ============================================================================
# SECTION S — THE STRUCTURAL FENCES, AND HYGIENE
# ============================================================================
# S1 is the seam's whole point stated as a fence: "nothing above it changes
# when the wildcard arrives". Calling ::ase::backend::ngspice::op_param_set
# directly is behaviourally IDENTICAL today, which is exactly why this row is
# structural rather than behavioural. The other four tokens are the forbidden
# doors: `xschem raw value` is the second reader invariant I3 forbids (issue
# 1272's own defect), ase::sim_capabilities STARTS THE USER'S SIMULATOR on a
# cache miss (ase.tcl:1777, and :3813's comment forbids it on a path with no
# Run behind it), blanket_op_save answers B1's question the way DD-1 forbids,
# and ase::theme has a one-way global font side effect that
# test_calc_skeleton's S13 exists to police.
# ⚠ op_param_lists:: is on the list for a different reason: B3's buttons are
# INERT, so B3 calls neither `load` nor `write_conf`, and staying off that
# namespace keeps this item clear of all six of B2's open defects 1276-1281 -
# including 1278, whose unbounded-glob freeze would otherwise land on the
# redraw path. B2a repairs them; B5 is where the store is wired.
# ⚠ WHOLE-LINE `#` COMMENTS ARE STRIPPED FIRST (as in H3), so the file may and
# should EXPLAIN the seam in prose above its code; what it may not do is call
# through it.
# RED before B3: S1 (the file does not exist).  GREEN before B3: S2.

set S1_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
check {S1 STRUCTURAL the forbidden doors: rdw.tcl reaches the seam ONLY through ase::backend_hook, never by the backend proc's name, and names none of `xschem raw value` / ase::sim_capabilities / blanket_op_save / ase::theme / op_param_lists::} \
  [list [expr {$S1_F eq {NOFILE} ? {NOFILE} : [rw_has $S1_F {ase::backend_hook}]}] \
        [rw_count $S1_F {::ase::backend::ngspice::}] \
        [rw_count $S1_F {raw value}] \
        [rw_count $S1_F {sim_capabilities}] \
        [rw_count $S1_F {blanket_op_save}] \
        [rw_count $S1_F {ase::theme}] \
        [rw_count $S1_F {op_param_lists::}]] \
  {1 0 0 0 0 0 0}

## An untracked untitled*.sch in the repo root turns THREE tests red. ⚠ The
## repo root ALREADY holds untitled~.sch and untitled~.sym and they are
## DELIBERATELY LEFT THERE (the known cause of test_ase_core's C11 baseline
## red, a phantom nothing in this batch may "fix"), so the row compares the
## glob against itself rather than asserting it is empty.
check {S2 HYGIENE the suite creates no untitled* anywhere and leaves no toplevel of its own behind} \
  [list [expr {[lsort [glob -nocomplain -directory $repo -tails untitled*]] eq $S2_ROOT0 ? 1 : 0}] \
        [llength [glob -nocomplain -directory $scratch -tails untitled*]] \
        [llength [glob -nocomplain -directory $here -tails untitled*]] \
        [expr {$live_tk ? [rw_w winfo exists .rdw] : 0}]] \
  {1 0 0 0}

# --- clean up ---------------------------------------------------------------
catch {xschem raw clear}
if {$live_tk} { rw_ans ::rdw::close ; catch {destroy .rdwctl} }

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
