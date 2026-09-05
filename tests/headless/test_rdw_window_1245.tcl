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

## ⚠ `inert` BECAME `button`, BY ITEM B5, AND THE COUNT IS UNCHANGED. This row
## is the fifth golden B5's own deliverable falsifies (S1, K11, W4b and Q9 are
## the others): `rdw::inert` said "the button column is built but not wired yet
## (item B5 wires it)", and B5 wired it. `rdw::button` is the proc that replaced
## it - THE one command all five widgets carry - so the list still names the
## button column's command sink and the section still counts sixteen.
set N_PROCS {}
foreach p {have_tk open close build push render_pane set_list button status
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
## ⚠ TWO TERMS OF THIS ROW MOVED FOR ITEM B5-a (issue 1322), AND THE GOLDEN
## DID NOT. `rdw::push` now stamps the block's SUBJECT into the header entry as
## a third element, so `[lindex [lindex $blocks 0] 0]` is `{hdr MQ1B:/ <dict>}`
## for a resolvable instance. This row passed at HEAD only because its fixture
## happens to hold no instance named MQ1B — green by accident — so it now
## compares the header entry's TAG and TEXT, which is what it was ever about.
## ⚠ AND THE `eq $Q1_BLK` TERM IS A CONSTRAINT ON THE FIX, not a detail:
## `rdw::dump_devpath` (rdw.tcl:749-750) pushes `$blk` and returns `$blk`, not
## push's answer. Once push stamps, it must return `[rdw::push $blk]` or the
## value handed back is not the value stored and this term reds.
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
        [lrange [lindex [lindex $::rdw::blocks 0] 0] 0 1]] \
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
## ⚠ REWRITTEN BY ITEM B5, THE HEADLESS TWIN OF W4b. It used to drive
## `rdw::inert`, which B5 DELETES - a proc that says "item B5 wires it" after
## item B5 wired it is a lie, and this row would have kept that lie golden. The
## point of the row is unchanged and is issue 1283 gap C's: the "the button
## said something" obligation must have a witness with NO WIDGET ANYWHERE, or
## making rdw::status a no-op passes the whole headless run.
## The two presses below are both REFUSALS - no dump has been pushed at this
## point in the file, and Delete is greyed on list 3 - which is deliberate:
## a refusal is the case where a silent button is most damaging, and neither
## press can reach the store or write a file.
## ⚠ IT MUST NOT TOUCH ::rdw::blocks. Row W1b, further down the display arm,
## asserts that the stored dumps SURVIVE a close and are repainted, and it reads
## a device name out of them; a row that emptied the store here would red W1b
## from three hundred lines away. Both presses below are GREYING refusals, which
## depend on the list identity alone - no target row, no subject, no store, no
## file - so they say what they say whatever is in the pane.
## ⚠ NOT `expr {[info exists v] ? $v : annotation}` - the list identity is a
## WORD and expr evaluates a bare word as an operand, raising "invalid
## bareword". The same trap is recorded at k_listkind and in the keys suite.
set Q9_LK0 annotation
if {[info exists ::rdw::listkind]} { set Q9_LK0 $::rdw::listkind }
set Q9_NB0 [expr {[info exists ::rdw::blocks] ? [llength $::rdw::blocks] : -1}]
rw_ans ::rdw::set_list all
rw_ans ::rdw::status {}
rw_ans ::rdw::button delete
set Q9_M1 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::button add
set Q9_M2 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
rw_ans ::rdw::set_list $Q9_LK0
## ⚠ AND TWO OF ITS TERMS ARE POSITIVE CLAIMS ABOUT THE REASON (item B5-a).
## MEASURED: with `rdw::button_state` forced to return `normal` - the greying
## deleted - EVERY term of the row as this patch first wrote it still passed.
## Both presses fall through to the ordinary "nothing has been dumped into this
## window yet" refusal, which is non-empty, names its own button, differs from
## its sibling, touches no store and clears; and `not wired yet` appears in
## neither, because the string it was written to exclude is gone from the file.
## A fence built entirely out of NEGATIVES cannot tell the sentence it is about
## from any other sentence. HEAD's own Q9 carried a positive claim about the
## reason - `[rw_has $Q9_M1 {B5}]` - and this rewrite dropped it; the two terms
## below put that kind of claim back, over the sentence `rdw::button` actually
## emits for a greyed press, and they name the LIST each button was greyed on
## so the two are not the same assertion twice. The `not wired yet` negatives
## are kept beside them: they fence a different fact.
check {Q9 a greyed button that is invoked anyway SAYS SO in the window's own status line with no widget anywhere: Delete on list 3 names itself AND says it is greyed on the `all` list, Add on list 1 says it is greyed on the `annotation` list, neither claims the column is unwired, the two sentences differ, the store is untouched, the variable is clearable - and rdw::inert is gone} \
  [list [expr {$Q9_M1 ne {} && $Q9_M1 ne {NOVAR} ? 1 : 0}] \
        [rw_has $Q9_M1 {Delete}] \
        [rw_has $Q9_M1 {greyed on the all list}] \
        [expr {[string first {not wired yet} $Q9_M1] < 0 ? 1 : 0}] \
        [expr {$Q9_M2 ne {} && $Q9_M2 ne {NOVAR} ? 1 : 0}] \
        [rw_has $Q9_M2 {Add}] \
        [rw_has $Q9_M2 {greyed on the annotation list}] \
        [expr {[string first {not wired yet} $Q9_M2] < 0 ? 1 : 0}] \
        [expr {$Q9_M1 ne $Q9_M2 ? 1 : 0}] \
        [expr {[info exists ::rdw::blocks] ? [llength $::rdw::blocks] : -1}] \
        [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}] \
        [llength [info commands ::rdw::inert]]] \
  [list 1 1 1 1 1 1 1 1 1 $Q9_NB0 {} 0]

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
               && [lrange [lindex [lindex $::rdw::blocks 0] 0] 0 1] eq {hdr MB:/} ? 1 : 0}] \
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

## ⚠ REWRITTEN BY ITEM B5. This row used to assert that every enabled button was
## INERT and said so, naming the literal `B5`. B5 is the item that wires them,
## so the golden it locked is now a statement B5's own deliverable must falsify.
## THE OBLIGATION DOES NOT LAPSE WITH THE INERTNESS - it sharpens: an enabled
## button that DOES something and says nothing is exactly as indistinguishable
## from a broken one as an inert one was (calc::inert's own reason,
## calculator.tcl:607). So the row now asserts the same three things about a
## WIRED column: each enabled button routes to rdw::button and nothing else,
## each one still writes a status line, and it no longer claims it is unwired.
## ⚠ IT PRESSES Up AND Delete, NEVER Save. `conf_path project` is
## `[pwd]/.xschem/...` and this suite runs at the repo root; a Save here would
## drop a settings file on the developer's tree (hard rule 6). Section BT owns
## the Save press and `cd`s first.
## ⚠ THE TWO PRESSES ARE BOTH REFUSALS, AND THE TARGET IS PINNED TO LINE 1 SO
## THEY STAY THAT WAY. Section W runs BEFORE section BT, so the scope dialog
## here is the REAL one; a Delete or an Add that reached a valid parameter row
## would raise a modal with nobody to click it and HANG the suite - issue 0803,
## the item's single largest risk. Line 1 is a block header, so both buttons
## refuse before any dialog, any store call or any file. They are told apart by
## the rule this row exists to hold: EVERY message rdw::button writes NAMES THE
## BUTTON IT CAME FROM, which is rdw::inert's own obligation surviving the
## wiring.
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 1
catch {update idletasks}
set W4_CMDS {}
foreach id {up down delete add save} {
  lappend W4_CMDS [rw_has [rw_w .rdw.b.$id cget -command] "rdw::button $id"]
}
rw_ans ::rdw::status {}
rw_w .rdw.b.up invoke
set W4_MSG1 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
rw_w .rdw.b.add invoke
set W4_MSG2 [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}]
rw_ans ::rdw::status {}
check {W4b every ENABLED button routes to rdw::button and SAYS what happened in the window's own status line, each message NAMES ITS OWN BUTTON so two of them are never the same sentence, no button still claims it is not wired yet, and no scope dialog was raised - a modal nobody can click is issue 0803} \
  [list $W4_CMDS \
        [expr {$W4_MSG1 ne {} && $W4_MSG1 ne {NOVAR} ? 1 : 0}] \
        [rw_has $W4_MSG1 {Up}] \
        [expr {$W4_MSG2 ne {} && $W4_MSG2 ne {NOVAR} ? 1 : 0}] \
        [rw_has $W4_MSG2 {Add}] \
        [expr {[string first {not wired yet} $W4_MSG1] < 0 ? 1 : 0}] \
        [expr {[string first {not wired yet} $W4_MSG2] < 0 ? 1 : 0}] \
        [expr {$W4_MSG1 ne $W4_MSG2 ? 1 : 0}] \
        [rw_w winfo exists .rdw.scope] \
        [llength [info commands ::rdw::inert]]] \
  {{1 1 1 1 1} 1 1 1 1 1 1 1 0 0}

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
# SECTION P — ISSUE 1303: THE UNSNAPPED MOUSE PAIR EXISTS
# ============================================================================
# Until 2026-09-04 `scheduler.c` exposed ONLY `mousex_snap`/`mousey_snap`, while
# every C click path reads the UNSNAPPED `xctx->mousex`/`mousey`. So a Tcl
# canvas pick had no way to resolve the point the user's own click resolved: it
# had to snap, and snapping moves the point up to half a grid step in each axis
# -- exactly the distance that crosses an instance boundary, because instance
# bbox edges are not on grid.
#
# MEASURED on the shipped cmos_inv.sch, one pixel apart:
#     exact   175.175 -199.612  ->  M1
#     snapped 180     -200      ->  R1
# Swept over every instance bbox on that sheet: 23725 points, 1513 (6.4%) miss
# the device entirely, 129 (0.5%) resolve to a DIFFERENT device -- silently.
# That is invariant I3's failure one object out: a results window headed `R1`
# for a click on `M1`, with nothing on screen saying which happened.
#
# ⚠ THE SNAPPED PAIR IS NOT REPLACED AND MUST NOT BE. It is correct for
# everything that PLACES or MOVES geometry -- that is what snapping is for.
# "What is under the pointer" is a different question. P2 holds both.
# RED before the accessor landed: P1, P2.

check {P1 the UNSNAPPED mouse pair is askable from Tcl at all, which it was not before issue 1303} \
  [list [catch {xschem get mousex} p_x] [catch {xschem get mousey} p_y] \
        [expr {[string is double -strict $p_x] ? 1 : 0}] \
        [expr {[string is double -strict $p_y] ? 1 : 0}]] \
  {0 0 1 1}

check {P2 and the SNAPPED pair still answers too, because placing geometry still wants it} \
  [list [catch {xschem get mousex_snap} p_sx] [catch {xschem get mousey_snap} p_sy] \
        [expr {[string is double -strict $p_sx] ? 1 : 0}] \
        [expr {[string is double -strict $p_sy] ? 1 : 0}]] \
  {0 0 1 1}

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
# SECTION K — ITEM B4: THE KEYS. THE HALF THAT NEEDS NO Tk, ON BOTH ARMS.
# ============================================================================
# ⚠ Never `git checkout --` / `git restore` / `git stash` / `git clean` this
# file to make some patch apply: rows K12..K15 are in no patch, and destroying
# uncommitted work that way cost an earlier agent in this batch ~99 verified
# lines. The sibling suite tests/headless/test_rdw_keys_1245.tcl says the same.
# B4 makes this window reachable from the keyboard: bare 1 / 2 / 3 / 4 in the
# cadence profile only (ruling D-2; stock xschem keeps logic_set). The BINDINGS
# and the verb-noun COMMAND MODE cannot live here — src/cadence_style_rc dies
# at its first `bind` under --nogui — so they are in the sibling suite
# tests/headless/test_rdw_keys_1245.tcl, :99 only. What CAN and MUST run on
# both arms is everything the keys do once the event has arrived: the list
# identity, the noun-verb grammar, the refusals, the store trim, and the
# structural fences over the pick.
#
# Measured on this binary 2026-09-04: `xschem select instance`, `xschem select
# wire`, `xschem selection`, `xschem getprop instance <index> name`, `xschem
# instance_at` and `xschem update_all_sym_bboxes` ALL work under --nogui, so
# none of these rows needs a display and none of them is a display row in
# disguise.
#
# THE CONTRACT (the sibling suite's header carries it in full):
#   rdw::key <annotation|summary|all|refresh>   rdw::_selected_instance
#   rdw::show <inst>   rdw::keep_latest   rdw::_ciw <msg>
#   rdw::pick_start / pick_click / pick_release / pick_end
#   rdw::pick_suspend / pick_resume   rdw::_refresh_pick_gate / rdw::_pick_at
#   cmdmode::register rdw_pick rdw::pick_suspend rdw::pick_resume, at SOURCE
#   time (safe: cmdmode.tcl is pure Tcl and is sourced BEFORE rdw.tcl)
#
# ⚠ THE REFUSAL WORDING IS NOT LOCKED BYTE-FOR-BYTE HERE, AND THAT IS
# DELIBERATE. B3 minted seven user-visible sentences and they are on rule debt
# 1245_B3_window_wording, unratified; B4 mints two more (more than one selected,
# and a selection that is not an instance) and PLAN forbids rewording B3's ad
# hoc. So rows K6/K7/K8 fence the SHAPE the user asked for — "refuse with short
# message in CIW" — one line, pairwise distinct, naming the action to take, and
# NOT double-booked against the window's own sentence. The prose itself goes on
# the same rule debt for the user to rule on.
#
# RED BEFORE B4: K1 K2 K3 K4 K5 K6 K7 K8 K9 K10 K11 — every one for the same
# single reason, that none of the procs above exists. GREEN BEFORE B4: K0, the
# fixture's own control.

## The fixture. A PRIVATE symbol type so no shipped symbol and no PDK
## registration is disturbed, one device that HAS numbers, one that has no
## descriptor at all, and a wire — the four answers rdw::_selected_instance
## has to tell apart.
##
## ⚠ THE DEVPATH TEMPLATE IS ESCAPED AND THAT IS NOT A TYPO. `devpath
## {@m.@path@name}` looks healthy and is measurably wrong: `xschem translate`
## swallows the leading `@m.` and yields `m1`, so ase::op_param_split returns
## the empty list and the seam answers `state ok` with an EMPTY union — the
## fifth silence over a device that has numbers. `{\@m.@path@name}` yields
## `@m.m1` and is gf180_procs.tcl:129's own spelling.
## test_annot_declutter_1244.tcl:1560 registers the UNESCAPED form; do not copy
## that line.
set K_SYM [file join $scratch b4k.sym]
set fd [open $K_SYM w]
puts $fd {v {xschem version=3.4.5 file_version=1.2}
G {}
K {type=b4kdev
format="@spiceprefix@name @pinlist @model"
template="name=M1 model=b4kn spiceprefix=X"
}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}
B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}
T {@name} 0 -40 0 0 0.2 0.2 {}}
close $fd

set K_SCH [file join $scratch b4k.sch]
set fd [open $K_SCH w]
puts $fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
N 600 -400 800 -400 {}
C \{$K_SYM\} 300 -300 0 0 \{name=M1\}
C \{$K_SYM\} 300 -120 0 0 \{name=M2\}
C \{devices/res\} 700 -100 0 0 \{name=R1
value=10\}"
close $fd

set fd [open [file join $scratch library.defs] w]
puts $fd "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $fd
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

catch {xschem raw clear}
xschem load $K_SCH
catch {update idletasks}
catch {op_annot::register b4kdev \
  [list devpath {\@m.@path@name} params {{zid zid 0} {zgm zgm 1}}]}
set K_PAIRS {}
foreach d {M1 M2} vi {1.11e-05 2.22e-05} vg {3.33e-04 4.44e-04} {
  catch {lappend K_PAIRS [::op_annot::vector $d zid] $vi [::op_annot::vector $d zgm] $vg}
}
set K_RAW [file join $scratch b4k.raw]
rw_mkraw $K_RAW [list [list {Operating Point} $K_PAIRS {}]]
rw_annot $K_RAW
catch {xschem update_all_sym_bboxes}

## The refusal channel, observed. ciw_echo is DEFINED under --nogui and
## silently does nothing without the widget, so a row that did not stub it
## would assert nothing at all (the rename idiom is
## test_sod_pick_no_select_0204.tcl:139).
set ::K_CIW {}
if {[llength [info commands ciw_echo]]} { rename ciw_echo k_ciw_echo_real }
proc ciw_echo {msg args} { lappend ::K_CIW $msg }

proc k_reset {} { set ::rdw::blocks {} ; set ::K_CIW {} ; catch {xschem unselect_all} }
proc k_nblocks {} {
  if {![info exists ::rdw::blocks]} { return -1 }
  return [llength $::rdw::blocks]
}
proc k_top_hdr {} {
  if {![info exists ::rdw::blocks] || ![llength $::rdw::blocks]} { return NO-BLOCK }
  return [lindex [lindex [lindex $::rdw::blocks 0] 0] 1]
}
## ⚠ NOT `expr {[info exists v] ? $v : {NO-VAR}}`: the list identity is a WORD
## and expr evaluates a bare word as an operand — `annotation` raises "invalid
## bareword". Measured while writing this file.
proc k_listkind {} {
  if {![info exists ::rdw::listkind]} { return NO-VAR }
  return $::rdw::listkind
}
## A block with a known header, for the store rows.
proc k_blk {name} {
  set dp "@m.[string tolower $name]"
  return [rw_block [rw_ansd [dict create $dp {{id 1}}] {} {} 0 ok] \
                   [rw_ctx "$name:/" $dp op $name]]
}

check {K0 CONTROL the fixture is what section K says it is: two devices the ONE name builder resolves and annotates, one instance with no descriptor at all, and a wire - so every row below is about B4 and not about a fixture that missed} \
  [list [rw_ans ::op_annot::devpath M1] [rw_ans ::op_annot::devpath M2] \
        [rw_ans ::op_annot::devpath R1] \
        [expr {[llength $K_PAIRS] == 8 ? 1 : 0}] \
        [xschem instance_at 300 -300] \
        [lindex [rw_w xschem select_at 700 -400] 0]] \
  {@m.m1 @m.m2 {} 1 M1 wire}
xschem unselect_all

# --- K1 K2  key 4: the store trim, and which end is new ----------------------
k_reset
rw_ans ::rdw::status {}
set K1_EMPTY [rw_ans ::rdw::keep_latest]
set K1_N0 [k_nblocks]
set K1_S0 $::rdw::statusmsg
rw_ans ::rdw::status {}
set K1_B [k_blk KONE]
rw_ans ::rdw::push $K1_B
set K1_ONE [rw_ans ::rdw::keep_latest]
check {K1 key 4 on an EMPTY store and on a one-block store changes nothing, raises nothing, and NAMES WHAT IT DID in the window's own status line - a control that silently does nothing cannot be told from a broken one} \
  [list [rw_bad $K1_EMPTY] $K1_N0 [expr {$K1_S0 ne {} ? 1 : 0}] \
        [rw_bad $K1_ONE] [k_nblocks] [k_top_hdr] \
        [expr {$::rdw::statusmsg ne {} ? 1 : 0}]] \
  {0 0 1 0 1 KONE:/ 1}

k_reset
foreach n {KA KB KC} { rw_ans ::rdw::push [k_blk $n] }
set K2_N0 [k_nblocks]
set K2_TOP0 [k_top_hdr]
rw_ans ::rdw::keep_latest
check {K2 three distinct blocks, key 4 leaves exactly ONE and it is the NEWEST - asserted by that block's own header text, never by index alone - and STRUCTURAL its body reads rdw::_insert_index, the same accessor rdw::push uses, so the store and the pane cannot disagree about which end is new} \
  [list $K2_N0 $K2_TOP0 [k_nblocks] [k_top_hdr] \
        [rw_has [rw_body ::rdw::keep_latest] {_insert_index}]] \
  {3 KC:/ 1 KC:/ 1}

# --- K3  the four answers of the selection reader ----------------------------
## ⚠ COPIES cadence::one_instance_selected's MEASUREMENT, NOT ITS CALL.
## rdw.tcl is installed and sourced by stock xschem; utils/cadence_nav.tcl is
## neither, so a cross-call would make an installed helper depend on a profile
## file that may not be there. The measurement is `xschem get lastsel` then the
## row TYPE — never `llength [xschem selected_set]`, which throws on an
## instance name holding an unbalanced brace (issue 0388) and which filters
## wires away entirely, so a single selected WIRE would read as "nothing
## selected" and the key would arm the pick mode over a live selection.
xschem unselect_all
set K3_NONE [rw_ans ::rdw::_selected_instance]
xschem select instance M1
set K3_ONE [rw_ans ::rdw::_selected_instance]
xschem select instance M2
set K3_MANY [rw_ans ::rdw::_selected_instance]
xschem unselect_all
xschem select wire 0
set K3_WIRE [rw_ans ::rdw::_selected_instance]
set K3_LASTSEL [xschem get lastsel]
xschem unselect_all
check {K3 rdw::_selected_instance's four answers, including the trap a count-only test passes: ONE selected WIRE has lastsel 1 and is NOT an instance, and the name comes from getprop on the row's own index} \
  [list $K3_NONE $K3_ONE $K3_MANY $K3_WIRE $K3_LASTSEL] \
  [list {none {}} {one M1} {many {}} {notinst {}} 1]

# --- K4 K5  the list identity, and the one key that does not touch it --------
xschem unselect_all
xschem select instance M1
rw_ans ::rdw::set_list annotation
set K4 {}
foreach k {annotation summary all} {
  rw_ans ::rdw::key $k
  lappend K4 [k_listkind] [rw_ans ::rdw::button_state add [k_listkind]] \
             [rw_ans ::rdw::button_state delete [k_listkind]]
}
check {K4 keys 1/2/3 move the list identity through rdw::set_list - B3's ONE setter - and the button table follows in step across all three lists, so no second list-identity variable is minted} \
  [list $K4 [rw_has [rw_body ::rdw::key] {set_list}]] \
  [list {annotation disabled normal summary normal normal all normal disabled} 1]

k_reset
xschem select instance M1
rw_ans ::rdw::key summary
rw_ans ::rdw::key annotation
rw_ans ::rdw::key summary
set K5_N0 [k_nblocks]
rw_ans ::rdw::key refresh
xschem unselect_all
check {K5 key 4 is the ONLY one of the four that leaves the list identity alone: pressed straight after key 2 the list is still summary, and the store it just trimmed holds one block} \
  [list $K5_N0 [k_listkind] [k_nblocks]] \
  [list 3 summary 1]

# --- K6 K7 K8  the refusals, and the channel that must NOT be double-booked --
xschem unselect_all
xschem select instance M1
xschem select instance M2
set ::K_CIW {}
set K6_MANYR [rw_ans ::rdw::key annotation]
set K6_MANY [lindex $::K_CIW 0]
xschem unselect_all
xschem select wire 0
set ::K_CIW {}
set K6_NIR [rw_ans ::rdw::key annotation]
set K6_NI [lindex $::K_CIW 0]
xschem unselect_all
proc k_oneline {s} { return [expr {[string first "\n" $s] < 0 && [string trim $s] ne {} ? 1 : 0}] }
check {K6 the two key-level refusals - more than one selected, and a single selection that is not an instance - are pairwise distinct, ONE line each, name the action to take, and go to the CIW, which is where the user asked for them} \
  [list [rw_bad $K6_MANYR] [rw_bad $K6_NIR] \
        [k_oneline $K6_MANY] [k_oneline $K6_NI] \
        [expr {$K6_MANY ne $K6_NI ? 1 : 0}] \
        [string match -nocase {*select*} $K6_MANY] \
        [string match -nocase {*select*} $K6_NI]] \
  {0 0 1 1 1 1 1}

k_reset
xschem select instance M1
xschem select instance M2
set K7_SEL0 [xschem selection]
set ::K_CIW {}
rw_ans ::rdw::key annotation
set K7_SEL1 [xschem selection]
xschem unselect_all
check {K7 a key-level refusal pushes NO block and leaves xschem selection BYTE-IDENTICAL - the refusal path may touch neither the store nor the user's selection} \
  [list [expr {$K7_SEL0 ne {} ? 1 : 0}] [k_nblocks] \
        [expr {$K7_SEL1 eq $K7_SEL0 ? 1 : 0}] [llength $::K_CIW]] \
  {1 0 1 1}

k_reset
xschem select instance M1
rw_ans ::rdw::key annotation
set K8_N1 [k_nblocks]
set K8_H1 [k_top_hdr]
set K8_T1 [rw_ans ::rdw::block_text [lindex $::rdw::blocks 0]]
set K8_C1 [llength $::K_CIW]
k_reset
xschem select instance R1
rw_ans ::rdw::key annotation
set K8_N2 [k_nblocks]
set K8_T2 [rw_ans ::rdw::block_text [lindex $::rdw::blocks 0]]
set K8_C2 [llength $::K_CIW]
xschem unselect_all
check {K8 THE TWO CHANNELS ARE NOT DOUBLE-BOOKED: one instance selected pushes exactly ONE block whose header names it, with its numbers and ZERO CIW lines, and an instance with NO descriptor still pushes a BLOCK carrying B3's locked no_devpath sentence and ZERO CIW lines - the window speaks whenever a device resolved} \
  [list $K8_N1 $K8_H1 [rw_has $K8_T1 {zid : 1.11e-05}] $K8_C1 \
        $K8_N2 [k_top_hdr] [rw_has $K8_T2 [RW_NODEVPATH R1]] $K8_C2] \
  [list 1 {M1:/} 1 0 1 {R1:/} 1 0]

# --- K9  the headless safety, and the contract registration ------------------
## ⚠ THE pick_start LEG IS A CONSTANT ON THE DISPLAY ARM AND SAYS SO. On :99
## the mode really does arm, which is the sibling suite's whole section V; here
## the question is only that a key pressed with no Tk at all arms nothing and
## raises nothing. The suspend arm's leg runs on BOTH arms and matters on both:
## once registered it runs on EVERY descend in EVERY profile forever, so "0 and
## no damage when there is nothing to release" is a permanent obligation.
k_reset
set K9_KEY [rw_ans ::rdw::key annotation]
set K9_PS [expr {$live_tk ? 0 : [rw_ans ::rdw::pick_start]}]
rw_ans ::rdw::pick_end
set K9_SUS [rw_ans ::rdw::pick_suspend]
set K9_REG [expr {[lsearch -exact [rw_ans ::cmdmode::registered] rdw_pick] >= 0 ? 1 : 0}]
check {K9 the --nogui safety and the cmdmode registration in one row: key 1 with nothing selected raises nothing and arms no mode when have_tk is 0, the suspend arm returns 0 and damages nothing when no mode is live, and cmdmode carries rdw_pick beside ase_sod - green on the headless arm proving it was registered at SOURCE time with no Tk} \
  [list [rw_bad $K9_KEY] $K9_PS $K9_SUS $K9_REG] \
  {0 0 0 1}

# --- K10 K11  the structural fences over the pick ----------------------------
## `xschem instance_at` is READ-ONLY and `xschem select_at` is the mutating
## twin. Measured on this binary at one instance bbox centre: instance_at
## answers the instance and leaves `xschem selection` empty with lastsel 0,
## while select_at at the SAME point answers `poly 0 2 698` and sets lastsel 1
## — it does not merely select, it selects a DIFFERENT OBJECT. That is the
## sharpest argument there is for the brief's "do not use select_at".
set K10_PC [rw_body ::rdw::pick_click]
set K10_ORDER 0
if {![rw_bad $K10_PC]} {
  set _r [string first {_refresh_pick_gate} $K10_PC]
  set _p [string first {_pick_at} $K10_PC]
  set K10_ORDER [expr {$_r >= 0 && $_p >= 0 && $_r < $_p ? 1 : 0}]
}
set K10_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
check {K10 STRUCTURAL the pick reads the canvas ONLY through rdw::_pick_at -> xschem instance_at, names select_at / select_object / unselect_all nowhere in the file, and rdw::pick_click calls rdw::_refresh_pick_gate BEFORE it in its own body} \
  [list [rw_has [rw_body ::rdw::_pick_at] {instance_at}] \
        [rw_has [rw_body ::rdw::_refresh_pick_gate] {update_all_sym_bboxes}] \
        [rw_count $K10_F {select_at}] [rw_count $K10_F {select_object}] \
        [rw_count $K10_F {unselect_all}] $K10_ORDER] \
  {1 1 0 0 0 1}

set K11_N 0
foreach p {::rdw::key ::rdw::show ::rdw::keep_latest ::rdw::pick_start \
           ::rdw::pick_click ::rdw::pick_end} {
  if {[llength [info commands $p]]} { incr K11_N }
}
set K11_TAGS 0
foreach p {::rdw::key ::rdw::show ::rdw::keep_latest ::rdw::pick_start \
           ::rdw::pick_click ::rdw::pick_end ::rdw::_ciw} {
  set b [rw_body $p]
  if {[rw_bad $b]} continue
  foreach t {{[list hdr } {[list dim } {[list dev } {[list note }} {
    incr K11_TAGS [rw_count $b $t]
  }
}
## ⚠ THE `op_param_lists:: == 0` TERM MOVED TO ROW BT22 (item B5). Issue 1300's
## substance is unchanged and is fenced by the six KEY procs still existing and
## by BT22's allow-list: the KEYS still select a list IDENTITY and narrow no
## CONTENT. What is no longer true is that the FILE never names the store - B5's
## button column is the store's first caller, by design.
check {K11 STRUCTURAL row S1's fence re-run over the grown file: the six key procs are all still here so keys 1/2/3 select a list IDENTITY and narrow no CONTENT (issue 1300), and no new proc builds a block line by hand - every line still goes through rdw::_line, row F29's rule} \
  [list $K11_N $K11_TAGS \
        [rw_has $K10_F {ase::backend_hook}]] \
  {6 0 1}

# --- K12  A REFUSED KEY CHANGES NOTHING --------------------------------------
## THE HOLE B4 SHIPPED, AND NO ROW SAW IT. rdw::key called rdw::set_list BEFORE
## it resolved the selection, so a key the feature then REFUSED had already
## moved ::rdw::listkind and re-greyed the button column. Rows K4 and K6/K7/K8
## between them assert that the list moves on an accepted key and that a refusal
## pushes no block and touches no selection -- and none of them asks what the
## list identity is AFTER a refusal. A refusal must change nothing at all: the
## user pressed a key, was told why it did not apply, and the window is in the
## state they left it in.
k_reset
rw_ans ::rdw::set_list annotation
set K12_LK0 [k_listkind]
set K12_BS0 {}
foreach id {up down delete add save} {
  lappend K12_BS0 [rw_ans ::rdw::button_state $id [k_listkind]]
}
xschem select instance M1
xschem select instance M2
set ::K_CIW {}
set K12_MANYR [rw_ans ::rdw::key summary]
set K12_MANY [list [llength $::K_CIW] [k_listkind] [k_nblocks]]
set K12_BS1 {}
foreach id {up down delete add save} {
  lappend K12_BS1 [rw_ans ::rdw::button_state $id [k_listkind]]
}
xschem unselect_all
## and the other refusal shape, which reaches the same door by a different arm.
k_reset
rw_ans ::rdw::set_list annotation
xschem select wire 0
set ::K_CIW {}
set K12_NIR [rw_ans ::rdw::key all]
set K12_NI [list [llength $::K_CIW] [k_listkind] [k_nblocks]]
xschem unselect_all
check {K12 A REFUSED KEY CHANGES NOTHING: with two instances selected, and again with a single WIRE selected, the key emits its one CIW line and leaves the list identity, the button table and the store exactly where they were - B4 moved the list first and refused second, so a refusal re-labelled the window with a list the user never got} \
  [list $K12_LK0 [rw_bad $K12_MANYR] $K12_MANY \
        [expr {$K12_BS1 eq $K12_BS0 ? 1 : 0}] \
        [rw_bad $K12_NIR] $K12_NI] \
  [list annotation 0 {1 annotation 0} 1 0 {1 annotation 0}]

# --- K13  STRUCTURAL, ISSUE 1303: WHICH MOUSE PAIR THE PICK READS ------------
## `xschem get mousex` / `mousey` are the UNSNAPPED pair every C click path
## reads (scheduler.c:5047 and :5051, landed 2026-09-04); `mousex_snap` /
## `mousey_snap` (:5055, :5059) are the SNAPPED pair, which is correct for
## placing and moving geometry and wrong for "what is under the pointer".
## Measured on the shipped cmos_inv.sch, one pixel apart: the exact point
## answers M1 and the snapped point answers R1.
##
## ⚠ THE RAW BODY, NOT rw_body. rw_body strips whole-line comments, and the
## point of the second half of this row is that the proc's own PROSE must not
## still say it reads the snapped pair -- a file that argues against its own
## code is how this batch has repeatedly re-derived the same fact. So the
## comment says "the snapped pair" in words and the tokens appear nowhere.
set K13_RAW [rw_w info body ::rdw::pick_click]
check {K13 STRUCTURAL (issue 1303) rdw::pick_click defaults its coordinates from the UNSNAPPED mouse pair, and the snapped spellings appear nowhere in the proc - not in its code and not in its comment, which must describe the pair it does not use in words} \
  [list [rw_bad $K13_RAW] \
        [rw_has $K13_RAW {xschem get mousex]}] [rw_has $K13_RAW {xschem get mousey]}] \
        [rw_count $K13_RAW {mousex_snap}] [rw_count $K13_RAW {mousey_snap}]] \
  {0 1 1 0 0}

# --- K14  STRUCTURAL, ISSUE 1304: THE SEIZE AND THE HAND-BACK AGREE ----------
## The seize was copied from ase::ui::select_on_design, which takes the press,
## the release and Escape and NOT <B1-Motion> -- so C's rubber band starts on
## the first motion with Button 1 held (callback.c:7250-7260) and never
## terminates, because its only terminator is the ButtonRelease the seize eats
## (callback.c:9748). Measured: an 8-step drag left twenty objects selected and
## ui_state still carrying STARTSELECT after a real ESC, against the user's own
## "This is a command mode, so clicking will not change selected set."
##
## ⚠ HARDENED BY ITEM B4-3, BECAUSE THE ROW AS B4-2 WROTE IT PASSED FOR THE
## WRONG REASON. It asked only whether each SEQUENCE NAME appeared in both
## bodies, through rw_has, which is `string first`. MEASURED on a copy by this
## item's Measure agent: replacing the seize's fourth line with
## `bind $cv <B1-Motion> {}` -- which DESTROYS the binding, i.e. restores the
## pre-1304 hole exactly -- left this row GREEN and the whole suite result
## byte-identical on both arms. A fence that is green against a seizing bind
## AND against a destroying one fences nothing, and passing for the wrong
## reason is the failure this batch has now hit six times. So the row reads the
## SCRIPT, not the name, in three independent ways:
##   TAKE     the seize's own line-anchored `bind $cv <seq> <script>` exists
##            and its script is neither empty nor the two-character string {} .
##   GIVE     pick_release writes that sequence back from a stored pick(...)
##            element, never from a literal.
##   PAIRING  the element the seize LATCHED for a sequence is the element the
##            release GIVES BACK for that same sequence.
##
## ⚠ THE PAIRING LEG IS NOT DECORATION. Measured on this tree: all four of
## .drw's predecessors are the EMPTY STRING, so a crossed restore -- Escape
## handed back the motion's predecessor and vice versa -- is byte-invisible to
## every behavioural row in the sibling suite, which compares the restored
## slots against those same empty strings. This is the only fence that sees it.
##
## ⚠ COMMENT-STRIPPED BODIES (rw_body), so a comment quoting a bind line cannot
## satisfy a leg, and the empty-brace literal is built with `format %c%c`: an
## unbalanced brace written literally in this file would make the WHOLE file
## fail `info complete` and stop loading, with no test to say so.
set K14_SZ [rw_body ::rdw::_pick_seize]
set K14_RL [rw_body ::rdw::pick_release]
set K14_MT [format %c%c 123 125]
set K14_TAKE 0 ; set K14_GIVE 0 ; set K14_PAIR 0
foreach seq {<ButtonPress-1> <ButtonRelease-1> <Key-Escape> <B1-Motion>} {
  set re_latch [string map [list SEQ $seq] {set pick\((\w+)\)\s+\[bind \$cv SEQ\]}]
  set re_take  [string map [list SEQ $seq] {^[ \t]*bind \$cv SEQ[ \t]+(.*)$}]
  set re_give  [string map [list SEQ $seq] {bind \$cv SEQ\s+\$pick\((\w+)\)}]
  set lname {} ; set gname {} ; set script {}
  catch {regexp $re_latch $K14_SZ -> lname}
  catch {regexp -line $re_take $K14_SZ -> script}
  catch {regexp $re_give $K14_RL -> gname}
  set script [string trim $script]
  if {$script ne {} && $script ne $K14_MT} { incr K14_TAKE }
  if {$gname ne {}} { incr K14_GIVE }
  if {$lname ne {} && $lname eq $gname} { incr K14_PAIR }
}
check {K14 STRUCTURAL (issue 1304) the seize takes FOUR sequences with a REAL script - not an emptied one, which destroys the binding and is the pre-1304 hole - the ONE shared hand-back gives all four back from a stored predecessor, and the element latched for a sequence is the element given back for that same sequence. B4-2 asserted only that the sequence NAMES appeared in both bodies, and stayed green under `bind $cv <B1-Motion> {}`} \
  [list [rw_bad $K14_SZ] [rw_bad $K14_RL] $K14_TAKE $K14_GIVE $K14_PAIR] {0 0 4 4 4}

# --- K15  STRUCTURAL: THE DUMP OPENS FIRST, AND DOES NOT KEEP THE KEYBOARD ---
## TWO HOLES IN ONE ROW, both invisible to every behavioural row on this arm.
##  * `rdw::show` must open BEFORE it dumps: rdw::render_pane early-returns when
##    .rdw.p.t does not exist, so a dump without an open puts the block in the
##    store and NOTHING on screen. Every dump row in both suites reads the STORE,
##    which is why deleting the open reds nothing here. The sibling suite's row
##    F2 reads the PANE; this row reads the ORDER.
##  * rdw::open must not take the keyboard. The command mode's Escape lives on
##    the CANVAS, and on the FIRST map of a session the window manager's own
##    map-time focus grant beats a synchronous focus -force -- so the hand-back
##    has to be event driven, armed by the paths that map the window and fired
##    from .rdw's own <FocusIn>. B4's row V8 was written for this and passed,
##    because the row before it had already mapped the window.
set K15_SHOW [rw_body ::rdw::show]
set K15_ORDER 0
if {![rw_bad $K15_SHOW]} {
  set _o [string first {rdw::open} $K15_SHOW]
  set _d [string first {rdw::dump} $K15_SHOW]
  set K15_ORDER [expr {$_o >= 0 && $_d >= 0 && $_o < $_d ? 1 : 0}]
}
set K15_BUILD [rw_body ::rdw::build]
check {K15 STRUCTURAL rdw::show opens the window BEFORE it dumps, rdw::open takes the keyboard nowhere, and the hand-back is event driven - a named rdw::_focus_handback bound to .rdw's own FocusIn in rdw::build, because the window manager's map-time focus grant arrives after any synchronous focus -force} \
  [list $K15_ORDER [rw_count [rw_body ::rdw::open] {focus .rdw}] \
        [expr {[llength [info commands ::rdw::_focus_handback]] ? 1 : 0}] \
        [rw_has $K15_BUILD {<FocusIn>}] [rw_has $K15_BUILD {_focus_handback}]] \
  {1 0 1 1 1}

# --- K16  STRUCTURAL, ISSUE 1306: THE HAND-BACK DECIDES ON WHERE FOCUS LANDED
## B4-2's guard was `if {$w ne {} && $w ne {.rdw}} { return 0 }` and its
## comment argued from BINDTAGS: a toplevel's name is in every child's
## bindtags, so this binding also sees the pane's own FocusIn and %W tells the
## two apart. THAT IS HALF THE MECHANISM AND THE OTHER HALF IS THE DEFECT.
## When focus crosses in from OUTSIDE the window -- `.drw` -> `.rdw.p.t`, which
## is exactly the deliberate click a user makes to select and copy a dump -- X
## ALSO delivers a separate FocusIn to the ANCESTOR `.rdw` with detail
## NotifyNonlinearVirtual, so `%W` is literally `.rdw`, the guard passes, and
## the keyboard is taken off the text. MEASURED with the defect present, on
## :99 under openbox, with the one-shot re-armed by hand:
##     after real dump : focus='.drw'       pending=0
##     after text click: focus='.drw'       pending=0   -> BOUNCED
## against the fixed code, same fixture:
##     after text click: focus='.rdw.p.t'   pending=1   -> KEPT
## The pane is what the whole window exists for -- the user's own stated use is
## pasting these dumps into design-review documents -- so a window that takes
## the keyboard away from its own text at the moment you click into it is worse
## than one that never focuses at all. Rows F3 and F4 of the sibling suite are
## the behavioural half; this row is the headless one.
##
## ⚠ AND THE FIX LINE PRINTED IN ISSUE 1306 AND IN THE ITEM BRIEF DOES NOT
## WORK. Both print `[string match .rdw* [focus]]`. Applied verbatim to a copy
## and measured three times on each arm: STILL BOUNCED, because that glob
## matches the DESCENDANT `.rdw.p.t` exactly as readily as `.rdw`. The
## discriminator that does work is the one the window manager itself supplies:
## its map-time grant lands on the TOPLEVEL (`[focus]` reads `.rdw`) while
## every deliberate landing lands on a CHILD (`[focus]` reads `.rdw.p.t`). So
## the test is the EXACT toplevel, and leg 2 keeps the refuted glob out of the
## tree for good -- describe it in words on a comment LINE, which rw_body
## strips, rather than in code or in a trailing comment.
##
## ⚠ THE ORDER LEG IS NOT COSMETIC. `focus` and `winfo` do not exist under
## --nogui; this proc survives the headless arm only because the focus_pending
## early return fires first. A landing test written ABOVE it would raise on
## every headless dump, and row N2 -- which only SOURCES the file into a bare
## interp -- would not catch it.
set K16_FH [rw_body ::rdw::_focus_handback]
set K16_IP [string first {!$focus_pending} $K16_FH]
set K16_IF [string first {[focus]} $K16_FH]
check {K16 STRUCTURAL (issue 1306) the hand-back decides on WHERE THE KEYBOARD LANDED and not on which window named the event: it reads [focus], compares it against the EXACT toplevel, contains no `string match` glob - the refuted `.rdw*` candidate matches the pane itself - reads the landing strictly BELOW the focus_pending early return so --nogui never evaluates it, and still spends the one-shot} \
  [list [rw_bad $K16_FH] \
        [rw_has $K16_FH {[focus]}] \
        [rw_count $K16_FH {string match}] \
        [rw_has $K16_FH {ne {.rdw}}] \
        [expr {$K16_IP >= 0 && $K16_IF > $K16_IP ? 1 : 0}] \
        [rw_count $K16_FH {set focus_pending 0}]] \
  {0 1 0 1 1 1}

# --- K17  STRUCTURAL, ISSUE 1305: A SUSPENDED MODE IS NOT RE-ARMED IN PLACE --
## rdw::pick_start's "already armed" guard deliberately lets a SUSPENDED mode
## fall through and take the canvas back: pressing 1/2/3/4 during
## hi_descend_pick_arm's multi-frame event-loop wait (xschem.tcl:7707) is an
## ordinary thing to do, and ruling D-2's whole premise is that those keys are
## always live. B4-2 let it fall through WITHOUT clearing pick(suspended), so
## the descend's own cmdmode::resume_all still believed the mode was suspended,
## called rdw::pick_resume, and _pick_seize ran a SECOND time on a canvas that
## was already seized -- latching THE SEIZE'S OWN SCRIPTS as the predecessors.
## MEASURED with the defect present, :99/openbox, driving suspend_all, a real
## <Key-N> on the canvas, resume_all and then a real ESC:
##     after ESC   P='rdw::pick_click; break'  R='break'
##                 E='rdw::pick_end; break'    M='break'
##     second ESC returns 0
## -- a PERMANENT seize. Every click dumps, nothing can be selected by clicking
## again for the rest of the session, <B1-Motion> is `break` so the rubber band
## is dead too, and the mode's own "press ESC to leave" cannot work. That is
## the exact inverse of the user's ruling sentence that a command mode must not
## change the selected set. Row D3 of the sibling suite is the behavioural
## half -- and the keys suite self-SKIPS under --nogui, so this row is the only
## fence issue 1305 has on the headless arm.
##
## THE FIX IS THE ISSUE'S OWN OPTION a1, AND IT IS ALREADY WRITTEN TWELVE LINES
## BELOW ITS OWN BUG: rdw::pick_resume clears the flag with
## `unset -nocomplain pick(suspended)` immediately before ITS _pick_seize, and
## ase::ui::sod_resume (ase_window.tcl:2047) ends the same way. Clearing the
## flag AS PART OF taking the canvas back is the house style, not an invention,
## and it is exactly what cmdmode's ruling D6 latch -- "exactly the first one
## to arrive wins" -- is for: the later resume then finds nothing suspended and
## returns 0.
##
## ⚠ BOTH ORDER LEGS ARE THE ROW'S POINT. BELOW the `winfo exists $cv` guard,
## so a re-arm that could NOT take a canvas leaves the suspend intact for the
## real resume; ABOVE `_pick_seize`, so the flag is gone before the seize.
## ⚠ AND LEG 4 STOPS THE OTHER "FIX". Deleting `![info exists pick(suspended)]`
## from the early-return guard also stops the double seize -- by making a
## suspended mode return 1 and never re-arm at all, silently swallowing the key
## press ruling D-2 says is always live, and destroying the re-arm-in-place
## property row V7 of the sibling suite measures.
set K17_PS [rw_body ::rdw::pick_start]
set K17_IU [string first {unset -nocomplain pick(suspended)} $K17_PS]
set K17_IW [string first {winfo exists $cv} $K17_PS]
set K17_IZ [string first {rdw::_pick_seize} $K17_PS]
check {K17 STRUCTURAL (issue 1305) rdw::pick_start clears the outstanding suspend as part of taking the canvas back - the unset sits BELOW the canvas guard and ABOVE the seize, so a re-arm that could not take a canvas leaves the suspend for the real resume - and the suspended test is still in the early-return guard, so nobody greens 1305 by deleting the fall-through and swallowing the key press instead} \
  [list [rw_bad $K17_PS] \
        [expr {$K17_IU >= 0 ? 1 : 0}] \
        [expr {$K17_IW >= 0 && $K17_IZ >= 0 && $K17_IU > $K17_IW && $K17_IU < $K17_IZ ? 1 : 0}] \
        [rw_has $K17_PS {![info exists pick(suspended)]}]] \
  {0 1 1 1}

# ============================================================================
# SECTION BS — ISSUE 1322: A BLOCK MUST CARRY WHAT IT WAS ABOUT
# ============================================================================
# THIS IS THE DEFECT THAT REVERTED ITEM B5-2, AND IT REPRODUCES AT HEAD WITH NO
# BUTTON CODE AT ALL.
#
# `rdw::header` (rdw.tcl:654) builds a block header as
# "<instname>:<cadence path>" — a RENDERING, not an identity. `rdw::push`
# (:767) is handed ONLY that rendered block and stores nothing else. Nothing in
# the tree clears `::rdw::blocks` on a schematic load (measured:
# BLOCKS_SURVIVED_THE_LOAD = 1), and `keep_latest` is its only shortener. So
# the SOLE surviving trace of which device a block is about is the header
# STRING — and item B5-3's button column re-resolves the NAME half of that
# string against WHATEVER SHEET IS OPEN.
#
# MEASURED AT HEAD 9945ad43, through the reverted patch's OWN `rdw::_subject`
# and `rdw::_edit` sourced into a HEAD session (the repo was not modified):
#   two top-level sheets, each holding an `M1` — the default template name of
#   EVERY device symbol in this tree, i.e. the ORDINARY case —
#     the block on screen is about   ncls / vn.sym
#     _subject answers               type vpdev class pcls cellname vp.sym
#     Delete's verdict               ok
#     Delete says                    "removed gm from the annotation list for
#                                     class pcls."
#     ncls keeps gm; pcls loses it — a device nobody was looking at.
#
# ⚠ THE OBVIOUS GUARD IS ALREADY REFUTED BY MEASUREMENT. Comparing the header's
# PATH half does not catch this: both sheets are top-level, `xschem get
# sch_path` is `.` on both, `rdw::_cadence_path` renders `/` on both, and
# PATHS_EQUAL = 1. THE AXIS IS SHEET IDENTITY, NOT HIERARCHY PATH. Row BS1b is
# that refutation written down so a later reviewer cannot re-propose it.
#
# ⚠ AND THE ADJACENT HOLE IS REAL. `op_param_lists::class` returns the TOKEN
# for a type nobody mapped, BY CONTRACT (op_param_lists.tcl:399-403), and an
# instance whose symbol xschem cannot find answers `op_annot::type` =
# `missing` — the placeholder systemlib/missing.sym (save.c:7281), the same one
# `descend_missing_sym` (actions.c:6049-6063) guards by name. So a `class eq {}`
# guard waves it straight through and the user reads a sentence naming a class
# no PDK ever mapped. Row BS4 closes it AT CAPTURE TIME, which is the only
# place where blank is available as an honest answer.
#
# ============================================================================
# THE CONTRACT THIS SECTION PINS
# ============================================================================
#   rdw::block_subject <block>
#       -> a dict {instname type cellname schname}, or {} when the block
#          carries no subject.  A PURE FUNCTION OF ITS ARGUMENT: it never reads
#          ::rdw::blocks, so a suite that assigns `set ::rdw::blocks {}`
#          directly — three of them do — cannot desync it.
#   rdw::push
#       captures the subject AT PUSH TIME, from the block's OWN header text and
#       the live editor, and returns the STAMPED block.  Its signature does not
#       change: every existing fixture in three suites pushes while the right
#       schematic is loaded, so they all capture the right subject with no
#       edit.
#   the stamp rides INSIDE the header entry, as a THIRD element:
#       {hdr <header text> <subject dict>}
#       so the block stays ONE FLAT LIST OF ENTRIES.  `llength $b` — which
#       rdw::_locate and the patch's BE0/BT3 use as a LINE COUNT — does not
#       move, `block_text` is byte-identical, and render_pane paints the same
#       number of lines.
#   a subject that does NOT resolve is NOT recorded: the header entry keeps its
#       two elements, the block is byte-identical to the unstamped one, and
#       block_subject answers {}.
#
# ⚠ THE CLASS IS DELIBERATELY NOT CAPTURED, AND THAT IS A DECISION, NOT AN
# OVERSIGHT. `op_param_lists::class` is a pure classmap lookup with no sheet
# dependence, so it already has exactly one home (invariant I1); only `type` is
# sheet-dependent. Capturing the class here would also make src/rdw.tcl name
# the `op_param_lists::` namespace, which rows S1 (:2451) and K11 (:2170) gold
# at ZERO occurrences — and the preserved patch moves that same term to its own
# row, so editing it here would guarantee a conflict for item B5-3. B5-3's
# `_subject` derives the class from the captured type.
#
# RED BEFORE THE FIX: BS1 BS1b BS2 BS3 BS4 BS5 (BS6 on the display arm) — every
# one for the same single reason, that `rdw::block_subject` and the capture do
# not exist, so rw_ans answers NOPROC and the header entry has two elements
# instead of three. Nothing here is red for a fixture reason: row BS0 is the
# control that says so.

set BS_DIR [file join $scratch bs1322]
file mkdir $BS_DIR
## Two PRIVATE symbol types, so no shipped symbol and no PDK registration is
## disturbed — and BOTH carry `name=M1` in their template, which is not a
## contrivance: it is what every device symbol in this tree ships.
proc bs_mksym {path type} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.5 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {type=$type"
  puts $fd {format="@spiceprefix@name @pinlist @model"}
  puts $fd "template=\"name=M1 model=$type spiceprefix=X\""
  puts $fd "}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  puts $fd "L 4 -20 -20 20 -20 {}"
  puts $fd "B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}"
  puts $fd "T {@name} 0 -40 0 0 0.2 0.2 {}"
  close $fd
}
proc bs_mksch {path sym} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.5 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  puts $fd "C \{$sym\} 300 -300 0 0 \{name=M1\}"
  close $fd
}
set BS_VN [file join $BS_DIR vn.sym]
set BS_VP [file join $BS_DIR vp.sym]
bs_mksym $BS_VN bs_ndev
bs_mksym $BS_VP bs_pdev
set BS_A    [file join $BS_DIR a.sch]
set BS_B    [file join $BS_DIR b.sch]
set BS_MISS [file join $BS_DIR miss.sch]
bs_mksch $BS_A    $BS_VN
bs_mksch $BS_B    $BS_VP
bs_mksch $BS_MISS [file join $BS_DIR nosuch.sym]
## ⚠ THE DEVPATH TEMPLATE IS ESCAPED AND THAT IS NOT A TYPO — section K's own
## comment carries the measurement.
set BS_DESC [list devpath {\@m.@path@name} params {{id ids 0} {gm gm 1}}]
catch {op_annot::register bs_ndev $BS_DESC}
catch {op_annot::register bs_pdev $BS_DESC}

## The subject, read through the ONE public door and never by poking at the
## block's shape, so a change of storage inside the header entry moves one proc
## rather than seven rows.
proc bs_subj {blk} { return [rw_ans ::rdw::block_subject $blk] }
proc bs_key {blk k} {
  set s [bs_subj $blk]
  if {[rw_bad $s]} { return $s }
  if {$s eq {}} { return NOSUBJ }
  if {[catch {dict get $s $k} v]} { return "NOKEY:$k" }
  return $v
}
proc bs_tail {blk k} {
  set v [bs_key $blk $k]
  if {[rw_bad $v] || $v eq {NOSUBJ} || [string match {NOKEY:*} $v]} { return $v }
  return [file tail $v]
}
## A body count that CANNOT pass by the proc being absent.
proc bs_bodycount {cmd needle} {
  set b [rw_body $cmd]
  if {[rw_bad $b]} { return $b }
  return [rw_count $b $needle]
}
## One dump-shaped block for an instance name and device path.
proc bs_mkblk {inst dp} {
  return [rw_block [rw_ansd [dict create $dp {{ids 1.2e-05} {gm 3.4e-05}}] \
                            {} {} 0 ok] \
                   [rw_ctx "$inst:/" $dp op $inst]]
}

catch {xschem raw clear}
set ::rdw::blocks {}
rw_ans ::rdw::close

# --- BS0  THE CONTROL. Without it every row below could be about a fixture ---
xschem load $BS_A
catch {update idletasks}
set BS_ATYPE [rw_ans ::op_annot::type M1]
set BS_ACELL [file tail [rw_ans xschem getprop instance M1 cell::name]]
set BS_ASCH  [file tail [rw_ans xschem get schname]]
set BS_AHDR  [rw_ans ::rdw::header M1]
check {BS0 CONTROL the two-sheet fixture is what section BS says it is: sheet a holds ONE instance named M1, of a private type, whose symbol is vn.sym, and the ONE name builder resolves it - so no row below can be red for a fixture reason} \
  [list $BS_ATYPE $BS_ACELL $BS_ASCH $BS_AHDR \
        [rw_ans xschem get sch_path]] \
  [list bs_ndev vn.sym a.sch {M1:/ @m.m1} .]

# --- BS1  THE TWO-SHEET REPRO, REPRODUCED AND CLOSED -------------------------
set BS_ARAW  [bs_mkblk M1 [lindex $BS_AHDR 1]]
set BS_APUSH [rw_ans ::rdw::push $BS_ARAW]
xschem load $BS_B
catch {update idletasks}
set BS_BTYPE [rw_ans ::op_annot::type M1]
set BS_BSCH  [file tail [rw_ans xschem get schname]]
set BS_STORED [lindex $::rdw::blocks 0]
check {BS1 THE TWO-SHEET REPRO, CLOSED: with two top-level sheets each holding an M1, a block dumped from a.sch still names bs_ndev / vn.sym / a.sch after b.sch is loaded - while a LIVE re-resolution of that same bare name answers bs_pdev, which is the wrong answer item B5-2 shipped} \
  [list $BS_ATYPE $BS_BTYPE [llength $::rdw::blocks] \
        [bs_key $BS_STORED instname] [bs_key $BS_STORED type] \
        [bs_tail $BS_STORED cellname] [bs_tail $BS_STORED schname]] \
  [list bs_ndev bs_pdev 1 M1 bs_ndev vn.sym a.sch]

# --- BS1b  THE PATH GUARD STAYS REFUTED, IN THE SUITE ------------------------
## Written down so a later reviewer cannot spend a pass rediscovering that
## comparing the header's path half catches nothing. The two headers are
## byte-identical; only the captured sheet separates the sheets.
set BS1B_LIVE [lindex [rw_ans ::rdw::header M1] 0]
check {BS1b THE PATH GUARD IS REFUTED BY THE FIXTURE ITSELF: the block's header and the header the OTHER sheet builds for its own M1 are BYTE-IDENTICAL, so hierarchy path separates nothing - the captured sheet identity is the only thing that does, and it names a.sch while the editor is showing b.sch} \
  [list [lindex [lindex $BS_STORED 0] 1] $BS1B_LIVE \
        [expr {[lindex [lindex $BS_STORED 0] 1] eq $BS1B_LIVE ? 1 : 0}] \
        [bs_tail $BS_STORED schname] $BS_BSCH] \
  [list {M1:/} {M1:/} 1 a.sch b.sch]

# --- BS2  THE STAMP NEVER REACHES THE PASTE OR THE LINE COUNT ----------------
check {BS2 THE STAMP IS INVISIBLE TO EVERYTHING THAT ALREADY READS A BLOCK: block_text of the stamped block is byte-identical to block_text of the same block before the push, llength is unchanged so the pane's line count and rdw::_locate's arithmetic cannot move, the header entry is still tagged hdr with its header string unchanged - and it really did gain a third element, so this row is not a statement about a stamp that was never applied} \
  [list [expr {[rw_ans ::rdw::block_text $BS_APUSH] eq
               [rw_ans ::rdw::block_text $BS_ARAW] ? 1 : 0}] \
        [expr {[llength $BS_APUSH] == [llength $BS_ARAW] ? 1 : 0}] \
        [lindex [lindex $BS_APUSH 0] 0] [lindex [lindex $BS_APUSH 0] 1] \
        [llength [lindex $BS_ARAW 0]] [llength [lindex $BS_APUSH 0]]] \
  [list 1 1 hdr {M1:/} 2 3]

# --- BS3  A RE-PUSH DOES NOT RE-STAMP AND DOES NOT RE-RESOLVE ----------------
## b.sch is still the open sheet here, so a push that re-captured would answer
## bs_pdev / vp.sym and the block would silently change what it is about.
set BS3_N0 [llength $::rdw::blocks]
set BS3_AGAIN [rw_ans ::rdw::push $BS_STORED]
check {BS3 A RE-PUSH OF AN ALREADY-STAMPED BLOCK, WHILE A DIFFERENT SHEET IS OPEN, neither re-stamps nor re-resolves: the header entry is still exactly three elements, the subject is still the FIRST capture, and the store still grew by one so the guard did not swallow the push} \
  [list [llength [lindex $BS3_AGAIN 0]] [bs_key $BS3_AGAIN type] \
        [bs_tail $BS3_AGAIN cellname] [bs_tail $BS3_AGAIN schname] \
        [expr {[llength $::rdw::blocks] == $BS3_N0 + 1 ? 1 : 0}]] \
  [list 3 bs_ndev vn.sym a.sch 1]

# --- BS4  THE ADJACENT HOLE: NOTHING IS RECORDED THAT CANNOT BE TRUSTED ------
set ::rdw::blocks {}
xschem load $BS_MISS
catch {update idletasks}
set BS4_TYPE [rw_ans ::op_annot::type M1]
set BS4_RAW  [bs_mkblk M1 {@m.m1}]
set BS4_PUSH [rw_ans ::rdw::push $BS4_RAW]
set BS4_NRAW  [bs_mkblk MNOPE {@m.mnope}]
set BS4_NPUSH [rw_ans ::rdw::push $BS4_NRAW]
check {BS4 THE ADJACENT HOLE, CLOSED AT CAPTURE TIME: an instance whose symbol xschem cannot find answers the LITERAL token `missing` and records NO subject, and a header naming an instance that does not exist at all records none either - both blocks come back byte-identical to the unstamped ones, neither raises, and no caller can be handed a class token no PDK maps} \
  [list $BS4_TYPE [bs_subj $BS4_PUSH] [llength [lindex $BS4_PUSH 0]] \
        [expr {$BS4_PUSH eq $BS4_RAW ? 1 : 0}] \
        [bs_subj $BS4_NPUSH] [llength [lindex $BS4_NPUSH 0]] \
        [expr {$BS4_NPUSH eq $BS4_NRAW ? 1 : 0}] \
        [rw_bad $BS4_PUSH] [rw_bad $BS4_NPUSH]] \
  [list missing {} 2 1 {} 2 1 0 0]

# --- BS5  ONE STRUCTURE, NOT TWO --------------------------------------------
## A PARALLEL `::rdw::subjects` LIST WOULD HAVE THREE WRITERS TO KEEP ALIGNED,
## NOT TWO: rdw::push, rdw::keep_latest AND the suites, which assign
## `set ::rdw::blocks {}` DIRECTLY (this file at :1955 and :2420, the keys suite
## at :283). A desynced parallel list answers about the wrong block while every
## existing row stays green — which is this batch's own recurring failure. The
## first leg drives exactly that assignment.
## ⚠ `rw_body` STRIPS WHOLE-LINE `#` COMMENTS AND NOTHING ELSE (row H3's rule),
## so `rdw::block_subject` may and should EXPLAIN itself in prose ABOVE its
## code — what it may not do is name the store in a TRAILING comment, which
## this row cannot tell from a read.
xschem load $BS_A
catch {update idletasks}
set ::rdw::blocks {}
rw_ans ::rdw::push [bs_mkblk M1 {@m.m1}]
set BS5_AFTER_WIPE [bs_key [lindex $::rdw::blocks 0] type]
set BS5_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
check {BS5 STRUCTURAL ONE STRUCTURE, NOT TWO: after a direct `set ::rdw::blocks {}` - which three suites do - a fresh push still answers the right subject; rdw::block_subject is a PURE FUNCTION of the block it is handed, naming neither `blocks` nor `variable` in its body; the file declares no second store; and the four helpers the sabotage variants target all exist} \
  [list $BS5_AFTER_WIPE \
        [bs_bodycount ::rdw::block_subject {blocks}] \
        [bs_bodycount ::rdw::block_subject {variable}] \
        [expr {$BS5_F eq {NOFILE} ? {NOFILE} : [rw_count $BS5_F {variable subjects}]}] \
        [expr {[llength [info commands ::rdw::block_subject]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_capture_subject]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_stamped]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_subject_resolved]] ? 1 : 0}] \
        [expr {[llength [info commands ::rdw::_hdr_instname]] ? 1 : 0}]] \
  [list bs_ndev 0 0 0 1 1 1 1 1]

# --- BS6  THE DISPLAY ARM: THE STAMP IS INVISIBLE ON SCREEN TOO --------------
if {$live_tk} {
  set ::rdw::blocks {}
  rw_ans ::rdw::open
  set BS6_PUSH [rw_ans ::rdw::push [bs_mkblk M1 {@m.m1}]]
  catch {update idletasks}
  set BS6_TXT [rw_w .rdw.p.t get 1.0 end]
  set BS6_IDX [rw_w .rdw.p.t index end-1c]
  if {[string match {ERR:*} $BS6_IDX]} {
    set BS6_NLINES -1
  } else {
    set BS6_NLINES [expr {[lindex [split $BS6_IDX .] 0] - 1}]
  }
  check {BS6 THE DISPLAY ARM: render_pane paints exactly one line per block ENTRY for a stamped block - so the stamp adds no line and shifts no offset - the pane holds no brace-quoted dict and none of the subject's own words, and the pane text is byte-identical to the block's paste shape} \
    [list [llength [lindex $BS6_PUSH 0]] \
          [expr {$BS6_NLINES == [llength $BS6_PUSH] ? 1 : 0}] \
          [rw_count $BS6_TXT {instname}] [rw_count $BS6_TXT {schname}] \
          [rw_count $BS6_TXT {cellname}] [rw_count $BS6_TXT {bs_ndev}] \
          [expr {[string trimright $BS6_TXT "\n"] eq
                 [string trimright [rw_ans ::rdw::block_text $BS6_PUSH] "\n"] ? 1 : 0}]] \
    [list 3 1 0 0 0 0 1]
}

# --- section BS leaves nothing behind ----------------------------------------
rw_ans ::rdw::close
set ::rdw::blocks {}
catch {xschem raw clear}

# ============================================================================
# ROWS BT29 AND BT30 — RULING DD-16: THE CROSS-SHEET EDIT IS ALLOWED, AND THE
# STATUS LINE NAMES THE SOURCE SHEET ONLY WHEN IT DIFFERS FROM THE OPEN ONE
# ============================================================================
# ⚠ WRITTEN RED, BEFORE ANY PRODUCTION LINE OF THE CLAUSE EXISTED. Measured on
# this binary at HEAD 59ef24af: item B5-a's stamp WORKS — a block dumped on
# a.sch still answers `schname` = a.sch after b.sch is loaded, which is what
# rows BS1 and BS1b above already gold — and NOTHING READS IT. Grep the button
# column's own patch for `schname` and every hit is inside `rdw::_subject`,
# which copies the key into the dict it returns and hands it to nobody. So the
# datum DD-16 needs is present, correct, and unread.
#
# ⚠ THESE TWO ROWS BELONG TO SECTION BT AND THEY SIT HERE, IMMEDIATELY AFTER
# SECTION BS, ON PURPOSE. DD-16's subject IS the two-sheet, two-M1 repro, and
# section BS is where that fixture lives — a.sch and b.sch each holding one
# instance called M1, of two different private types. Rebuilding it a second
# time inside section BT would be two fixtures for one question, which is how
# two suites end up disagreeing about what they are measuring. The row NAMES
# stay BT29/BT30 because they are section BT's questions.
#
# WHAT DD-16 REQUIRES, IN THREE FACTS:
#   1. THE EDIT IS NOT REFUSED. The three lists are class- and flavor-level
#      settings, not sheet state, so editing the `mos` list is correct wherever
#      the user is standing.
#   2. WHEN THE STAMPED SHEET DIFFERS FROM THE OPEN ONE, THE SENTENCE SAYS SO.
#      One line, because `rdw::status` is one line (row BT20).
#   3. WHEN IT DOES NOT DIFFER — OR IS ABSENT — THE SENTENCE IS SILENT ABOUT
#      SHEETS. In the common case the source sheet IS the open one and saying so
#      is noise on every press.
#
# ⚠ FACT 3's SECOND HALF IS LOAD-BEARING AND IS NOT DECORATION. Row BT28 hands
# `rdw::_edit` a HAND-BUILT subject dict carrying instname / type / class /
# cellname AND NO `schname` KEY AT ALL, and the keys suite's SD fixtures do the
# same. Measured: `dict get $subj schname` RAISES on such a dict. A `_sheet_note`
# that reads it unguarded therefore raises from inside the decision core, which
# is a refusal the user never asked for on a path that was working — so ABSENT
# must mean DO NOT NAME THE SHEET, and BT30's second arm drives exactly that.
#
# ⚠ AND THE COMPARISON IS A PLAIN STRING COMPARE, NOT `file normalize` AND NOT
# A DEVICE+INODE IDENTITY. Both values come from the same `xschem get schname`
# accessor, so they are byte-identical whenever they name the same sheet — the
# fixture measures that directly, and it is why no BE/BT/SD row above moves.
# Issue 1327 established that `file normalize` does not resolve a path's final
# component and so establishes no file identity anyway, and `_fid` is a PRIVATE
# store verb that row BT22 golds this file must never name.
#
# BOTH ROWS ARE RED AT HEAD, AND FOR ONE REASON EACH:
#   BT29  the sentence does not name the source sheet (at HEAD, before item
#         B5's patch lands, `rdw::_subject` and `rdw::_edit` do not exist at
#         all and rw_ans answers NOPROC; after the patch and before DD-16 they
#         exist and the sentence simply carries no clause).
#   BT30  its FIRST arm is red for the same NOPROC reason today and is the
#         two-sided partner: it golds the successful sentence BYTE-FOR-BYTE
#         with no clause in it, so a `_sheet_note` that fires unconditionally
#         reds here while BT29 stays green.

set BT_DD16_OLDSCH [rw_ans xschem get schname]
proc bt_dd16_fixture {} {
  rw_ans ::op_param_lists::reset
  catch {op_annot::register bs_ndev $::BS_DESC}
  catch {op_annot::register bs_pdev $::BS_DESC}
  rw_ans ::op_param_lists::said_clear
  set ::rdw::blocks {}
  return {}
}

# --- BT29  THE CROSS-SHEET EDIT, THROUGH SECTION BS's OWN TWO-SHEET FIXTURE --
bt_dd16_fixture
xschem load $BS_A
catch {update idletasks}
rw_ans ::rdw::push [bs_mkblk M1 {@m.m1}]
set BT29_SRC  [bs_tail [lindex $::rdw::blocks 0] schname]
set BT29_SUBJ [rw_ans ::rdw::_subject 0]
xschem load $BS_B
catch {update idletasks}
set BT29_OPEN [file tail [rw_ans xschem get schname]]
set BT29_BASE [rw_ans ::op_param_lists::effective bs_ndev annotation]
set BT29_R    [rw_ans ::rdw::_edit up $BT29_SUBJ annotation governing gm]
set BT29_SAY  [lindex $BT29_R 1]
set BT29_GOT  [rw_ans ::op_param_lists::get_list class bs_ndev annotation]
## ⚠ THE SHEET IS ASSERTED BY TAIL AND BY EXCLUSION, NOT BY A WHOLE SENTENCE.
## `a.sch` is a substring of the tail and of the full path alike, so the row
## does not pre-decide how the clause spells the sheet; the SECOND term is what
## makes it sharp — the OPEN sheet's name must not appear, so a clause that
## named the wrong one of the two would red here and not merely somewhere else.
check {BT29 RULING DD-16 THROUGH THE REAL DECISION CORE: a block dumped on a.sch and edited while b.sch is open is ACCEPTED and not refused, the store really moves, and the ONE-LINE status names the SOURCE sheet a.sch and not the sheet the editor is showing} \
  [list $BT29_SRC $BT29_OPEN $BT29_BASE \
        [lindex $BT29_R 0] \
        [expr {[string first "\n" $BT29_SAY] >= 0 ? 0 : 1}] \
        [rw_has $BT29_SAY {a.sch}] [rw_has $BT29_SAY {b.sch}] \
        $BT29_GOT] \
  [list a.sch b.sch {{id ids 0} {gm gm 1}} ok 1 1 0 {{gm gm 1} {id ids 0}}]

# --- BT30  THE TWO SILENCES --------------------------------------------------
## ARM A — the sheets AGREE. The whole sentence is golded byte for byte, so a
## clause that fires unconditionally cannot hide inside a substring test.
bt_dd16_fixture
xschem load $BS_B
catch {update idletasks}
rw_ans ::rdw::push [bs_mkblk M1 {@m.m1}]
set BT30_SRC  [bs_tail [lindex $::rdw::blocks 0] schname]
set BT30_OPEN [file tail [rw_ans xschem get schname]]
set BT30_SUBJ [rw_ans ::rdw::_subject 0]
set BT30_R    [rw_ans ::rdw::_edit up $BT30_SUBJ annotation governing gm]
set BT30_SAY  [lindex $BT30_R 1]
## ARM B — NO `schname` KEY AT ALL, which is row BT28's own subject shape.
bt_dd16_fixture
set BT30_HB   [dict create instname M1 type bs_ndev class bs_ndev cellname vn.sym]
set BT30_R2   [rw_ans ::rdw::_edit up $BT30_HB annotation governing gm]
set BT30_SAY2 [lindex $BT30_R2 1]
check {BT30 THE TWO SILENCES, so DD-16's clause cannot pass by being unconditional: with the stamped sheet EQUAL to the open one an otherwise identical successful press carries no clause and its sentence is byte-identical to the plain one, and rdw::_edit handed a subject with NO schname key at all - which is exactly what row BT28 passes it - still answers ok, still says nothing about a sheet, and does not raise; the named callee rdw::_sheet_note exists, so a reviewer can neutralise this one sentence and watch one row say so} \
  [list $BT30_SRC $BT30_OPEN \
        [lindex $BT30_R 0] $BT30_SAY \
        [expr {[dict exists $BT30_HB schname] ? 1 : 0}] \
        [lindex $BT30_R2 0] $BT30_SAY2 [rw_bad $BT30_R2] \
        [expr {[llength [info commands ::rdw::_sheet_note]] ? 1 : 0}]] \
  [list b.sch b.sch \
        ok {moved gm up in the annotation list for class bs_pdev.} \
        0 \
        ok {moved gm up in the annotation list for class bs_ndev.} 0 \
        1]

# --- rows BT29/BT30 leave nothing behind -------------------------------------
bt_dd16_fixture
rw_ans ::rdw::close
if {$BT_DD16_OLDSCH ne {} && ![rw_bad $BT_DD16_OLDSCH]} {
  catch {xschem load $BT_DD16_OLDSCH}
} else {
  catch {xschem load $BS_A}
}
catch {update idletasks}
catch {xschem raw clear}

# --- section K leaves nothing behind -----------------------------------------
rw_ans ::rdw::pick_end
rw_ans ::rdw::close
set ::rdw::blocks {}
rw_ans ::rdw::set_list annotation
catch {xschem unselect_all}
catch {xschem raw clear}
catch {rename ciw_echo {}}
if {[llength [info commands k_ciw_echo_real]]} { rename k_ciw_echo_real ciw_echo }

# ============================================================================
# SECTION BT — ITEM B5: THE BUTTON COLUMN AND THE TWO SCOPE DIALOGS
# ============================================================================
# ⚠ WRITTEN RED, BEFORE ANY PRODUCTION LINE OF B5 EXISTED. Every row below was
# run against HEAD 79f163cb and every one of them failed for exactly one
# reason: the procs named in the contract do not exist, `rdw::button` is not a
# command, and `rdw::inert` still is. The ONE exception is BT0, the fixture's
# own control, which is GREEN before the change and is evidence of nothing
# except that no row below can pass vacuously.
#
# The row names are the PLAN's own (BT0 BT1 BT3 BT4 BT6 ... BT23), gaps
# included, so the sabotage table in the item's plan can name a row and mean
# this one. The gaps are not missing rows: they are numbers the plan spent on
# rows that were folded into their neighbours while writing.
#
# ============================================================================
# THE CONTRACT B5 ADDS TO src/rdw.tcl — SPELLED HERE BECAUSE THIS FILE IS
# WHERE IT IS LOCKED
# ============================================================================
#   rdw::set_row {n}          the ONE target setter. `n` is a 1-based PANE LINE
#                             number. It also moves the pane's `insert` mark
#                             when a pane exists, so the widget and the store
#                             cannot disagree about which row is targeted.
#   rdw::_target_line {}      the current target line: the pane's own `insert`
#                             line when a pane exists, the namespace variable
#                             otherwise. 0 when there is none.
#   rdw::_locate {line}       {blockindex entryindex} for a flat pane line, or
#                             {} past the end. PURE — a function of
#                             ::rdw::blocks alone, so it runs under --nogui.
#   rdw::_row_param {entry}   the RAW parameter name of a {}-tagged, non-empty
#                             block entry; {} for hdr / dim / dev / note and
#                             for the separator.
#   rdw::_hdr_instname {line} the exact inverse of rdw::header's join.
#   rdw::_subject {blockindex}  {instname type class cellname ...} for the block
#                             the cursor is in, or {}.
#   rdw::_last_row_why {...}  DD-10's predicate: {} when a Delete is allowed,
#                             else the refusal sentence.
#   rdw::_edit {...}          the pure decision core. Performs the store call
#                             and returns {ok|refused <sentence>}; touches no
#                             Tk, so every sentence is asserted on BOTH arms.
#   rdw::button {id}          THE ONE COMMAND EVERY WIDGET CARRIES. It replaces
#                             rdw::inert, which is DELETED.
#   rdw::scope_dialog {op subject listname}   -> a dict {scope narrow|broad
#                             list annotation|summary}, or {} for Cancel.
#   rdw::scope_dialog_build / rdw::scope_dialog_done   the ase::ui::bus_dialog
#                             split, so the modal never has to be reached to
#                             test the decision (issue 0803).
#   widget paths the suite drives: .rdw.scope , .rdw.scope.sc.narrow ,
#                             .rdw.scope.sc.broad , .rdw.scope.li.annotation ,
#                             .rdw.scope.li.summary , .rdw.scope.btns.ok ,
#                             .rdw.scope.btns.cancel
#
# ============================================================================
# THE SENTENCE CONTRACT — WHAT EACH REFUSAL MUST SAY, AND WHY THESE ARE
# PROPERTY ASSERTIONS AND NOT BYTE GOLDENS
# ============================================================================
# B3 minted seven user-visible sentences and B4 two more, and PLAN forbids
# rewording any of them ad hoc; all of them sit UNRATIFIED on rule debt
# 1245_B3_window_wording. B5 mints nine more. Locking nine unratified strings
# byte-for-byte would gold prose the user has never read, and the first thing
# the user's ruling would do is red nine rows that are about the CODE. So each
# row below fences the SHAPE the sentence must have — one line, non-empty,
# naming the thing the user must act on — plus the load-bearing NOUNS, and the
# prose goes on the same rule debt.
#
# THE ONE EXCEPTION IS DD-10, WHICH THE USER'S OWN RULING SPELLS. Row BT13
# asserts the ruling's clause VERBATIM as a substring, because DECISIONS.md
# writes it out and a ruling's own words are not this item's to reword.
#
# ⚠ AND ONE RULE OVER ALL OF THEM, INHERITED FROM rdw::inert AND FENCED BY ROWS
# W4b, Q9 AND BT15: EVERY MESSAGE rdw::button WRITES NAMES THE BUTTON IT CAME
# FROM. calc::inert (calculator.tcl:607) exists because a control that acts and
# says nothing cannot be told from a broken one; a control that says something
# which does not identify itself is the same failure one step further in, and
# the status line is shared by all five buttons.
#
#   no subject      contains `press 1`   (the user has not dumped anything yet)
#   no parameter row contains `parameter row`
#   Up at the top   contains `first`     Down at the bottom contains `last`
#   not in the list contains the PARAM, the CLASS and the LIST NAME
#   DD-10 annotation contains, verbatim:
#       at least one parameter must stay. To stop showing operating-point
#       values on this device, turn the annotation off instead.
#   DD-10 summary    a DIFFERENT string that does NOT carry the annotation half
#   Cancel          contains `ancel`
#   a live pick mode contains `Escape`
#   a greyed button  contains the button's own label and the list name
#
# ============================================================================
# THE FIXTURE, AND WHY IT IS BUILT RATHER THAN BORROWED
# ============================================================================
# MEASURED at HEAD 79f163cb: a bare headless launch has an EMPTY op_annot
# registry, so `op_param_lists::effective mos annotation` answers {} and every
# list row would be vacuous. Section K's b4kdev fixture has ONE symbol file for
# both of its devices, so a NARROW (cell-name) scope on M1 would also hit M2
# and BT10's "leaves its siblings alone" could not fail.
#
# So this section builds TWO symbol files with TWO type tokens mapped to ONE
# private class — the nmos/pmos shape, which is what makes a class-scope edit
# and a flavor-scope edit tell each other apart — and registers an IHP-SHAPED
# descriptor whose first triple has LABEL != PARAM ({id ids 0}).
#
# ⚠ THAT TRIPLE IS THE WHOLE POINT OF THE FIXTURE. MEASURED on this binary: the
# pane prints the RAW param, `    ids : 1.2e-05`, while the store's triple is
# `{id ids 0}`. A button column that looks its row up in the list BY LABEL
# round-trips sky130 and gf180 perfectly and silently misses IHP — the one PDK
# in the tree that distinguishes them, and this batch's own discriminator.
# Every row below therefore targets a pane row whose text says `ids`.
#
# ⚠ AND THE STACKING IS PART OF THE FIXTURE. Two blocks are pushed, M1 FIRST,
# so the M2 block is on top and every row that matters targets a line in the
# OLDER block. A button column that reads `[lindex $::rdw::blocks 0]` — the
# newest — passes every single-block row ever written.
#
# MEASURED PANE LAYOUT, driven out of rdw::format_answer on this binary:
#     1 hdr  M2:/            6 hdr  M1:/
#     2 dim  @m.m2           7 dim  @m.m1
#     3 note (incomplete)    8 note (incomplete)
#     4      ids : 9.9e-06   9      ids : 1.2e-05
#     5      (separator)    10      gm  : 3.4e-05
#                           11      gds : 5.6e-06
#                           12      vgs : 0.5
#                           13      (separator)
#
# ⚠ THIS SECTION NEVER PRESSES SAVE AT THE REPO ROOT. `conf_path project` is
# `[pwd]/.xschem/op_param_lists.conf`, and this suite runs with pwd at the repo
# root, so a Save taken here would drop a settings file on the developer's own
# tree (hard rule 6). The one row that presses Save `cd`s into the scratch tree
# first and `cd`s back; the tier behaviour itself is fenced in the STORE
# suite's section BE, which owns the isolation idiom.
# ============================================================================

set B5_SYMN [file join $scratch b5n.sym]
set B5_SYMP [file join $scratch b5p.sym]
proc b5_mksym {path type} {
  set fd [open $path w]
  puts $fd "v {xschem version=3.4.5 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {type=$type"
  puts $fd {format="@spiceprefix@name @pinlist @model"}
  puts $fd "template=\"name=M1 model=$type spiceprefix=X\""
  puts $fd "}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  puts $fd "L 4 -20 -20 20 -20 {}"
  puts $fd "B 5 -22.5 -12.5 -17.5 -7.5 {name=d dir=inout}"
  puts $fd "T {@name} 0 -40 0 0 0.2 0.2 {}"
  close $fd
}
b5_mksym $B5_SYMN b5ndev
b5_mksym $B5_SYMP b5pdev
set B5_SCH [file join $scratch b5.sch]
set fd [open $B5_SCH w]
puts $fd "v {xschem version=3.4.5 file_version=1.2}
G {}
V {}
S {}
E {}
C \{$B5_SYMN\} 300 -300 0 0 \{name=M1\}
C \{$B5_SYMP\} 300 -120 0 0 \{name=M2\}"
close $fd

catch {xschem raw clear}
set B5_LOAD [catch {xschem load $B5_SCH}]
catch {update idletasks}
## The IHP shape: label `id`, param `ids`, kind 0. `\@m.` is escaped for the
## reason section K's own comment gives — the unescaped form yields `m1` and
## the seam answers the fifth silence over a device that has numbers.
set B5_DESC [list devpath {\@m.@path@name} \
                  params {{id ids 0} {gm gm 1} {gds gds 1}}]
catch {op_annot::register b5ndev $B5_DESC}
catch {op_annot::register b5pdev $B5_DESC}
rw_ans ::op_param_lists::reset
rw_ans ::op_param_lists::set_class b5ndev b5cls
rw_ans ::op_param_lists::set_class b5pdev b5cls

proc b5_cell {n} {
  set c {} ; catch {set c [xschem getprop instance $n cell::name]}
  return $c
}
set B5_CELL1 [b5_cell M1]
set B5_CELL2 [b5_cell M2]
set B5_SEED  {{id ids 0} {gm gm 1} {gds gds 1}}

## The two blocks, built through the renderer so the pane layout above is the
## renderer's own and not this file's opinion of it.
proc b5_blk {inst dp pairs} {
  return [rw_block [rw_ansd [list $dp $pairs] {} {} 0 ok] \
                   [rw_ctx "$inst:/" $dp op $inst]]
}
proc b5_fixture_blocks {} {
  set ::rdw::blocks {}
  rw_ans ::rdw::push [b5_blk M1 @m.m1 {{ids 1.2e-05} {gm 3.4e-05} {gds 5.6e-06} {vgs 0.5}}]
  rw_ans ::rdw::push [b5_blk M2 @m.m2 {{ids 9.9e-06}}]
  return {}
}
## The pane as a flat list of entries, computed from the STORE and not from
## rdw::_locate — a row that read its own subject through the proc under test
## could not see that proc go wrong.
proc b5_flat {} {
  set out {}
  if {![info exists ::rdw::blocks]} { return {} }
  foreach b $::rdw::blocks { foreach e $b { lappend out $e } }
  return $out
}
proc b5_entry {ln} { return [lindex [b5_flat] [expr {$ln - 1}]] }
proc b5_say {} { return [expr {[info exists ::rdw::statusmsg] ? $::rdw::statusmsg : {NOVAR}}] }
## Press one button and hand back what the window SAID about it. The status is
## cleared first, so a button that says nothing is distinguishable from one
## that repeated the previous message.
proc b5_press {id} {
  rw_ans ::rdw::status {}
  rw_ans ::rdw::button $id
  return [b5_say]
}
## A message that is present, ONE LINE, and names <needle>.
proc b5_ok1 {m needle} {
  if {$m eq {} || $m eq {NOVAR} || [string match {NOPROC*} $m]} { return 0 }
  if {[string first "\n" $m] >= 0} { return 0 }
  return [expr {[string first $needle $m] >= 0 ? 1 : 0}]
}
proc b5_owns {scope key ln} { return [rw_ans ::op_param_lists::owns $scope $key $ln] }
proc b5_eff {ln {cell {}}} { return [rw_ans ::op_param_lists::effective b5cls $ln $cell] }
## one key of one descriptor, without a raise: NOPROC / RAISED:... / NOKEY.
## The twin of the store suite's ol_dkey, added by item B5-2 for row BT8.
proc b5_dkey {type key} {
  set d [rw_ans ::op_annot::descriptor $type]
  if {[rw_bad $d]} { return $d }
  if {[catch {dict exists $d $key} e]} { return BADDESC }
  if {!$e} { return NOKEY }
  if {[catch {dict get $d $key} v]} { return "RAISED:$v" }
  return $v
}
proc b5_nsaid {} {
  set s [rw_ans ::op_param_lists::said]
  if {[rw_bad $s]} { return $s }
  if {[catch {llength $s} n]} { return "BADSAID:$s" }
  return $n
}
## ⚠ IT RESETS THE REGISTRY TOO, AND THAT IS NOT TIDINESS. `op_param_lists::apply`
## writes the UNION into the descriptor's `params` (ruling DD-6), and
## `op_param_lists::seed` READS THAT SAME FIELD BACK as "the PDK's own list" -
## so the first successful Delete or Add in this section reorders the seed for
## every row after it, and rows BT18 and BT21, which assert `effective` answers
## the PDK seed EXACTLY, would be reading a value an earlier row wrote. The
## store suite's twin proc `be_reset` (test_op_param_store_1245.tcl) already
## re-registers for this reason; this one did not, which made the two suites
## disagree about what a per-row reset is. Filed as issue 1312.
proc b5_lists_reset {} {
  rw_ans ::op_param_lists::reset
  rw_ans ::op_param_lists::set_class b5ndev b5cls
  rw_ans ::op_param_lists::set_class b5pdev b5cls
  catch {op_annot::register b5ndev $::B5_DESC}
  catch {op_annot::register b5pdev $::B5_DESC}
  rw_ans ::op_param_lists::said_clear
  return {}
}

## THE DIALOG STUB — `rename`, NEVER `proc`. test_ase_bus_bits_0159.tcl:129-132
## records why: a bare `proc` overwrites the real one and the `rename ... {}`
## that puts it back then DELETES it. The rename is guarded because in the RED
## state there is nothing to rename.
set ::b5_dlg_calls 0
set ::b5_dlg_args {}
set ::b5_dlg_answer {}
if {[llength [info commands ::rdw::scope_dialog]]} {
  rename ::rdw::scope_dialog ::rdw::b5_real_scope_dialog
}
proc ::rdw::scope_dialog {args} {
  incr ::b5_dlg_calls
  set ::b5_dlg_args $args
  return $::b5_dlg_answer
}
proc b5_dlg {answer} { set ::b5_dlg_calls 0 ; set ::b5_dlg_args {} ; set ::b5_dlg_answer $answer }

b5_fixture_blocks

# --- BT0  THE CONTROL --------------------------------------------------------
## GREEN BEFORE THE CHANGE, and that is the point: it says the fixture is live
## so that no row below can pass by asserting something about nothing.
check {BT0 CONTROL the fixture is live: two devices of ONE private class from TWO different cell files, an IHP-shaped seed whose first triple has label != param, nothing owned yet, and a two-block pane whose older block carries four parameter rows} \
  [list $B5_LOAD [rw_ans ::op_annot::type M1] [rw_ans ::op_annot::type M2] \
        [rw_ans ::op_param_lists::class b5ndev] [rw_ans ::op_param_lists::class b5pdev] \
        [rw_ans ::op_param_lists::seed b5cls] [b5_eff annotation] \
        [b5_owns class b5cls annotation] \
        [expr {$B5_CELL1 ne {} && $B5_CELL1 ne $B5_CELL2 ? 1 : 0}] \
        [llength $::rdw::blocks] [llength [b5_flat]] \
        [lindex [b5_entry 9] 1]] \
  [list 0 b5ndev b5pdev b5cls b5cls $B5_SEED $B5_SEED 0 1 2 13 {    ids : 1.2e-05}]

# --- BT1  THE HEADER IS INVERTIBLE -------------------------------------------
## rdw::header joins the instance name and the cadence path with a `:`, and an
## instance name may itself contain one. The split must be GREEDY on the last
## `:` that is followed by the path half, which always begins with `/`. The
## row fences the split and the join AS ONE PAIR, so they cannot drift.
check {BT1 rdw::_hdr_instname is the exact inverse of rdw::header's join - for a deep path, for the empty path this fixture actually has, for an instance name that itself carries a colon, and for a line that is not a header at all} \
  [list [rw_ans ::rdw::_hdr_instname {M1:/xdut/xbg/xamp1}] \
        [rw_ans ::rdw::_hdr_instname {M1:/}] \
        [rw_ans ::rdw::_hdr_instname {A:B:/x}] \
        [rw_ans ::rdw::_hdr_instname [lindex [rw_ans ::rdw::header M1] 0]] \
        [rw_ans ::rdw::_hdr_instname {not a header at all}]] \
  {M1 M1 A:B M1 {}}

# --- BT3  THE TARGET IS PURE -------------------------------------------------
## No Tk anywhere in this row: _locate and _row_param are functions of
## ::rdw::blocks and of one block entry. That is what lets the whole button
## column be driven on the --nogui arm, which is where the majority of this
## suite lives.
## ⚠ THE PARAM IS THE RAW NAME. `ids`, never the label `id`.
check {BT3 rdw::_locate maps a flat pane line onto {blockindex entryindex} across TWO stacked blocks and answers {} past the end, and rdw::_row_param answers the RAW param for a parameter row and {} for the header, the device path, the note and the separator} \
  [list [rw_ans ::rdw::_locate 4] [rw_ans ::rdw::_locate 9] \
        [rw_ans ::rdw::_locate 11] [rw_ans ::rdw::_locate 13] \
        [rw_ans ::rdw::_locate 14] [rw_ans ::rdw::_locate 0] \
        [rw_ans ::rdw::_row_param [b5_entry 9]] \
        [rw_ans ::rdw::_row_param [b5_entry 11]] \
        [rw_ans ::rdw::_row_param [b5_entry 12]] \
        [rw_ans ::rdw::_row_param [b5_entry 6]] \
        [rw_ans ::rdw::_row_param [b5_entry 7]] \
        [rw_ans ::rdw::_row_param [b5_entry 8]] \
        [rw_ans ::rdw::_row_param [b5_entry 13]]] \
  {{0 3} {1 3} {1 5} {1 7} {} {} ids gds vgs {} {} {} {}}

# --- BT4  NO SUBJECT, AND NO ROW ---------------------------------------------
## Two different silences, two different sentences. An empty store is "you have
## not dumped anything yet"; a cursor on a header line is "click a parameter
## row". Neither may open a dialog and neither may touch the store.
b5_lists_reset
b5_dlg {scope broad list annotation}
set ::rdw::blocks {}
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 1
set BT4_NOSUBJ {}
foreach id {up down delete add} { lappend BT4_NOSUBJ [b5_ok1 [b5_press $id] {press 1}] }
set BT4_D1 $::b5_dlg_calls
b5_fixture_blocks
rw_ans ::rdw::set_list annotation
set BT4_NOROW {}
foreach ln {6 7 8 13} {
  rw_ans ::rdw::set_row $ln
  lappend BT4_NOROW [b5_ok1 [b5_press up] {parameter row}]
}
check {BT4 with nothing dumped every mutating button refuses and tells the user to press a list key over a device first, and with dumps present a cursor on the header, the device path, the note or the separator refuses and tells them to click a parameter row - neither silence opens a dialog and neither touches the store} \
  [list $BT4_NOSUBJ $BT4_D1 $BT4_NOROW $::b5_dlg_calls \
        [b5_owns class b5cls annotation] [b5_owns class b5cls summary]] \
  {{1 1 1 1} 0 {1 1 1 1} 0 0 0}

# --- BT6  THE PANE'S ROW SET AND THE LIST ARE NOT THE SAME SET ---------------
## `vgs` is published by the run and declared by no list, so it is DRAWN and
## not REORDERABLE. Refusing by name is the only honest answer: a silent no-op
## on a row the user can see is the failure rdw::inert existed to prevent.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 12
set BT6_M [b5_press up]
check {BT6 a parameter the run published but no list declares is refused BY NAME, naming the class and the list it is not in, and stores nothing - the pane's row set and the list are not the same set} \
  [list [b5_ok1 $BT6_M vgs] [b5_ok1 $BT6_M b5cls] [b5_ok1 $BT6_M annotation] \
        $::b5_dlg_calls [b5_owns class b5cls annotation] [b5_eff annotation]] \
  [list 1 1 1 0 0 $B5_SEED]

# --- BT7  THE BOUNDARY REFUSES, AND THE GREYING DOES NOT MOVE ----------------
## Ladder decision D4: the greying stays keyed on LIST IDENTITY alone. A
## position-dependent grey has to re-grey on every cursor move, which needs a
## new binding on the pane - issue 1306/1308 ground - so the boundary is a
## refusal with a sentence instead.
b5_lists_reset
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT7_UP [b5_press up]
rw_ans ::rdw::set_row 11
set BT7_DN [b5_press down]
check {BT7 Up on the first row and Down on the last refuse with a sentence naming the row and its end of the list, the list is byte-identical afterwards, and rdw::button_state has not moved - the greying stays keyed on list identity, never on position} \
  [list [b5_ok1 $BT7_UP ids] [b5_ok1 $BT7_UP first] \
        [b5_ok1 $BT7_DN gds] [b5_ok1 $BT7_DN last] \
        [b5_eff annotation] [b5_owns class b5cls annotation] \
        [rw_ans ::rdw::button_state up annotation] \
        [rw_ans ::rdw::button_state down annotation]] \
  [list 1 1 1 1 $B5_SEED 0 normal normal]

# --- BT8  THE REORDER, AND WHAT IT SAYS --------------------------------------
## With nothing owned the first reorder MATERIALISES the class entry, which is
## DD-2's primary key. Exactly two entries move; the other list is untouched.
b5_lists_reset
set BT8_OWN0 [b5_owns class b5cls annotation]
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 10
set BT8_M [b5_press up]
## ⚠ ITEM B5-2 ADDED THE LAST THREE LEGS, AND THEY CONTRADICT THE PRESERVED
## PATCH. The patch DEFERRED the redraw after a reorder and said so on screen -
## "The drawn order follows on the next Add, Delete or reload (issue 1312)".
## Issue 1312 is FIXED (ruling DD-13, item B2e): `seed` reads the declaration,
## so a reorder can no longer leak through the seed into the summary list nobody
## owns, and store row N4 fences the opposite. The deferral's stated cost is
## gone, and a status line citing a fixed issue as its reason is a false
## statement on a screen the user is reading. So the display key moves NOW, for
## every type token of the class, and the sentence stops citing 1312.
check {BT8 Up on the second row swaps exactly two entries and no more, materialises the class entry DD-2 makes the primary key, leaves the summary list alone, writes the display key for BOTH type tokens at once so the sheet follows immediately, and SAYS what moved - naming the parameter, the list and the scope, and no longer citing a fixed issue as a reason to defer} \
  [list $BT8_OWN0 [b5_owns class b5cls annotation] [b5_eff annotation] \
        [b5_owns class b5cls summary] [b5_eff summary] \
        [b5_ok1 $BT8_M gm] [b5_ok1 $BT8_M annotation] [b5_ok1 $BT8_M class] \
        [b5_dkey b5ndev shown] [b5_dkey b5pdev shown] \
        [expr {[b5_ok1 $BT8_M gm] && [string first {1312} $BT8_M] < 0 \
               && [string first {reload} $BT8_M] < 0 ? 1 : 0}]] \
  [list 0 1 {{gm gm 1} {id ids 0} {gds gds 1}} 0 $B5_SEED 1 1 1 \
        {{gm gm 1} {id ids 0} {gds gds 1}} {{gm gm 1} {id ids 0} {gds gds 1}} 1]

# --- BT9  WHO ASKS THE DIALOG, AND WHO MUST NOT ------------------------------
## The spec's B7 table gives the dialog to Delete and Add and to nothing else.
## A dialog on every reorder makes reordering unusable, and a Save that asks a
## scope question is asking about a decision it is not taking.
## ⚠ THE SAVE LEG `cd`s INTO THE SCRATCH TREE. See this section's header.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 10
rw_ans ::rdw::button up
set BT9_UP $::b5_dlg_calls
rw_ans ::rdw::button down
set BT9_DN $::b5_dlg_calls
rw_ans ::rdw::set_row 9
rw_ans ::rdw::button delete
set BT9_DEL $::b5_dlg_calls
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 9
rw_ans ::op_param_lists::set_list class b5cls annotation {{gm gm 1}}
rw_ans ::rdw::button add
set BT9_ADD $::b5_dlg_calls
set BT9_OLDPWD [pwd]
cd $scratch
set ::b5_dlg_calls 0
rw_ans ::rdw::button save
set BT9_SAVE $::b5_dlg_calls
cd $BT9_OLDPWD
## The REAL dialog, unstubbed, on the headless arm only: it must answer {} and
## return, not block. On :99 it would build a window and sit in tkwait, which
## is issue 0803 itself - SD1 of the keys suite drives it there, with a deadman.
set BT9_HEADLESS [expr {$live_tk ? {n/a} : \
  [expr {[llength [info commands ::rdw::b5_real_scope_dialog]] \
         ? [rw_ans ::rdw::b5_real_scope_dialog delete {} annotation] : {NOPROC}}]}]
check {BT9 the scope dialog is consulted EXACTLY ONCE per Delete and once per Add and NEVER for Up, Down or Save, no settings file is dropped on the repo root, and with no Tk at all the real dialog answers Cancel and returns instead of blocking (issue 0803, answered by construction)} \
  [list $BT9_UP $BT9_DN $BT9_DEL $BT9_ADD $BT9_SAVE \
        [expr {[file isdirectory [file join $repo .xschem]] ? 1 : 0}] \
        [expr {$live_tk ? {n/a} : $BT9_HEADLESS}]] \
  [list 0 0 1 1 0 0 [expr {$live_tk ? {n/a} : {}}]]

# --- BT10  NARROW TOUCHES ONE FLAVOR, BROAD MOVES THE CLASS ------------------
## The acceptance sentence, both halves, plus DD-8's shadow. A narrow write is
## a NEW row and file order is precedence, so a `*` entry declared earlier
## still wins - and the button must SAY so rather than looking broken.
b5_lists_reset
b5_dlg [list scope narrow list annotation]
rw_ans ::op_param_lists::set_list flavor [list b5cls $B5_CELL2] annotation {{id ids 0} {gm gm 1}}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT10_M1 [b5_press delete]
set BT10_NARROW [list [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
                      [b5_owns class b5cls annotation] \
                      [rw_ans ::op_param_lists::get_list flavor [list b5cls $B5_CELL2] annotation] \
                      [b5_eff annotation $B5_CELL1]]
b5_lists_reset
b5_dlg [list scope broad list annotation]
rw_ans ::rdw::set_row 9
set BT10_M2 [b5_press delete]
set BT10_BROAD [list [b5_owns class b5cls annotation] \
                     [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
                     [b5_eff annotation $B5_CELL2]]
b5_lists_reset
b5_dlg [list scope narrow list annotation]
rw_ans ::op_param_lists::set_list flavor [list b5cls *] annotation {{id ids 0} {gm gm 1}}
rw_ans ::rdw::set_row 9
set BT10_M3 [b5_press delete]
set BT10_SHADOW [list [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
                      [b5_eff annotation $B5_CELL1]]
check {BT10 narrow scope writes ONE flavor entry and leaves the sibling flavor and the class entry untouched; broad scope moves the CLASS and the sibling cell follows it; and a narrow write an earlier glob already shadows is REPORTED with the order to fix, never left looking like a dead button (DD-8, issue 1311)} \
  [list [b5_ok1 $BT10_M1 ids] $BT10_NARROW \
        [b5_ok1 $BT10_M2 ids] $BT10_BROAD \
        [b5_ok1 $BT10_M3 order] $BT10_SHADOW] \
  [list 1 [list 1 0 {{id ids 0} {gm gm 1}} {{gm gm 1} {gds gds 1}}] \
        1 [list 1 0 {{gm gm 1} {gds gds 1}}] \
        1 [list 1 {{id ids 0} {gm gm 1}}]]

# --- BT12  CANCEL CHANGES NOTHING AT ALL -------------------------------------
b5_lists_reset
b5_dlg {}
rw_ans ::op_param_lists::said_clear
set BT12_D0 [rw_ans ::op_annot::descriptor b5ndev]
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT12_M [b5_press delete]
check {BT12 Cancel on the scope dialog changes NOTHING: no key owned, no report added to the store's own log, the descriptor byte-identical, and the window SAYS it was cancelled rather than going silent} \
  [list $::b5_dlg_calls [b5_owns class b5cls annotation] \
        [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
        [b5_nsaid] \
        [expr {[rw_ans ::op_annot::descriptor b5ndev] eq $BT12_D0 ? 1 : 0}] \
        [b5_ok1 $BT12_M ancel]] \
  {1 0 0 0 1 1}

# --- BT13  DD-10: DELETE REFUSES THE LAST ROW --------------------------------
## ⚠ THE ONE BYTE-GOLDEN SENTENCE IN THIS SECTION, AND IT IS THE USER'S OWN.
## DECISIONS.md DD-10 writes it out; a ruling's words are not this item's to
## reword. The second half of the row is what keeps the first half honest: a
## Delete of a TWO-row list succeeds, so the refusal is about the LAST ROW and
## not about Delete.
set B5_DD10 {at least one parameter must stay. To stop showing operating-point values on this device, turn the annotation off instead.}
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::op_param_lists::set_list class b5cls annotation {{id ids 0}}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT13_M [b5_press delete]
set BT13_L1 [b5_eff annotation]
rw_ans ::op_param_lists::set_list class b5cls annotation {{id ids 0} {gm gm 1}}
set BT13_M2 [b5_press delete]
check {BT13 DD-10 Delete refuses to remove the LAST remaining row of the annotation list and says the ruling's own sentence verbatim, the row is still there - and a Delete of a two-row list then succeeds, so the refusal is about the last row and not about Delete} \
  [list [b5_ok1 $BT13_M $B5_DD10] $BT13_L1 \
        [b5_eff annotation] \
        [expr {$BT13_M2 ne $BT13_M ? 1 : 0}]] \
  [list 1 {{id ids 0}} {{gm gm 1}} 1]

# --- BT14  DD-10 ON THE SUMMARY LIST, WITH ITS OWN SENTENCE ------------------
## Ladder decision D5: the ruling's text is unqualified, so the refusal applies
## to BOTH lists - but DD-10's ARGUMENT is annotation-specific (an emptied
## `shown` blanks the block and drops the device out of the declutter), so one
## sentence for both lists would be FALSE about the summary case.
b5_lists_reset
b5_dlg {scope broad list summary}
rw_ans ::op_param_lists::set_list class b5cls summary {{id ids 0}}
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 9
set BT14_M [b5_press delete]
check {BT14 DD-10 on the summary list refuses too, with its OWN sentence - one line, naming the row, and NOT carrying the annotation half of the ruling's wording, which would be false about this list} \
  [list [b5_ok1 $BT14_M ids] \
        [expr {[string first "turn the annotation off" $BT14_M] < 0 ? 1 : 0}] \
        [expr {$BT14_M ne $B5_DD10 ? 1 : 0}] \
        [b5_eff summary] [b5_owns class b5cls summary]] \
  [list 1 1 1 {{id ids 0}} 1]

# --- BT15  THE GREYING IS ALSO A COMMAND-PATH FENCE --------------------------
## The disabled widget is not the only fence. rdw::button consults
## rdw::button_state itself, so a caller reaching the proc directly - a key, a
## menu, a later item - gets the same answer the widget would have given.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::rdw::set_list all
rw_ans ::rdw::set_row 9
set BT15_DEL [b5_press delete]
rw_ans ::rdw::set_list annotation
set BT15_ADD [b5_press add]
check {BT15 Delete on list 3 and Add on list 1 are refused through rdw::button even when it is invoked directly, quoting the same rdw::button_state table the widget greying reads - and neither opens a dialog nor touches the store} \
  [list [b5_ok1 $BT15_DEL Delete] [b5_ok1 $BT15_DEL all] \
        [b5_ok1 $BT15_ADD Add] [b5_ok1 $BT15_ADD annotation] \
        $::b5_dlg_calls [b5_owns class b5cls annotation]] \
  {1 1 1 1 0 0}

# --- BT16  ADD RE-ADDS THE TRIPLE, VERBATIM ----------------------------------
## Landmine 12 / invariant I1: the KIND is the raw-name SHAPE, and this file
## mints none. Add finds the existing {label param kind} triple by its PARAM
## and re-adds it whole - label `id`, param `ids`, kind 0.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::op_param_lists::set_list class b5cls annotation {{gm gm 1}}
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 9
set BT16_M [b5_press add]
set BT16_L [rw_ans ::op_param_lists::get_list class b5cls annotation]
check {BT16 Add from the summary list re-adds the triple VERBATIM into the annotation list - label id, param ids, kind 0, all three fields carried - with no label re-minted from the param and no kind invented} \
  [list $BT16_L [lsearch -exact $BT16_L {id ids 0}] \
        [b5_ok1 $BT16_M ids] [b5_ok1 $BT16_M annotation]] \
  [list {{gm gm 1} {id ids 0}} 1 1 1]

# --- BT17  ADD FROM LIST 3 ASKS WHICH LIST -----------------------------------
## The spec's own cell: "add to annotation or summary (the dialog asks which)".
## The stub records BOTH answers, and the row asserts the button honoured both
## - the scope AND the list it was told.
b5_lists_reset
b5_dlg [list scope narrow list summary]
rw_ans ::op_param_lists::set_list class b5cls summary {{gm gm 1}}
rw_ans ::rdw::set_list all
rw_ans ::rdw::set_row 9
set BT17_M [b5_press add]
check {BT17 Add from list 3 consults the dialog with the `all` identity - which is what makes it ask WHICH list - and writes into the list it was told at the scope it was told, leaving the class entry for that list alone} \
  [list $::b5_dlg_calls [lindex $::b5_dlg_args end] \
        [b5_owns flavor [list b5cls $B5_CELL1] summary] \
        [rw_ans ::op_param_lists::get_list flavor [list b5cls $B5_CELL1] summary] \
        [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
        [rw_ans ::op_param_lists::get_list class b5cls summary]] \
  [list 1 all 1 {{gm gm 1} {id ids 0}} 0 {{gm gm 1}}]

# --- BT18  ADD MINTS NO KIND -------------------------------------------------
## `vgs` is drawn by the run and declared in no list and in no PDK seed, so
## there is no triple to re-add and no honest way to guess its kind. Rule R3:
## the kind is the raw-name SHAPE, so a wrong one writes a `.save` card that
## matches nothing - and one bogus card destroys the whole operating point.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::rdw::set_list all
rw_ans ::rdw::set_row 12
set BT18_M [b5_press add]
check {BT18 Add from list 3 of a parameter declared in no list and in no PDK seed REFUSES by name, mints no kind and stores nothing - the kind is the raw-name shape and this file invents none} \
  [list [b5_ok1 $BT18_M vgs] \
        [b5_owns class b5cls annotation] [b5_owns class b5cls summary] \
        [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
        [b5_eff annotation]] \
  [list 1 0 0 0 $B5_SEED]

# --- BT19  A LIVE CANVAS PICK MODE BLOCKS THE DIALOG -------------------------
## MEASURED while planning this item: `grab set .rdw.scope` really does take
## `grab current`, so a modal opened while a verb-noun pick is live SWALLOWS
## the canvas click the mode is waiting for and the mode looks dead. Ladder
## decision D9: refuse to open one, and name the key that ends the mode. This
## is adjacent to issue 1309 without being it - B5 adds no key and calls no
## pick_start.
b5_lists_reset
b5_dlg {scope broad list annotation}
set ::rdw::pick(canvas) .drw
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT19_M [b5_press delete]
set BT19_RUN [rw_ans ::rdw::pick_running]
array unset ::rdw::pick
check {BT19 a Delete pressed while a canvas pick mode is live refuses and NAMES Escape, opens no dialog, creates no .rdw.scope toplevel, takes no grab and leaves the mode running} \
  [list [b5_ok1 $BT19_M Escape] $::b5_dlg_calls $BT19_RUN \
        [b5_owns class b5cls annotation] \
        [expr {$live_tk ? [rw_w winfo exists .rdw.scope] : 0}] \
        [expr {$live_tk ? [rw_w grab current] : {}}]] \
  {1 0 1 0 0 {}}

# --- BT20  THE STATUS LINE IS ONE-LINE-SAFE ----------------------------------
## `::rdw::statusmsg` is an `entry -textvariable` and the store's own sentences
## interpolate caught errors, which are multi-line by nature. rdw::_line has
## carried this rule for every BLOCK line since B3; the status line was the one
## emit point outside it, and B5 is the item that starts routing store prose
## through it.
rw_ans ::rdw::status "line1\nline2\tand3"
set BT20_M [b5_say]
rw_ans ::rdw::status {}
check {BT20 rdw::status collapses a multi-line message onto ONE line before it reaches the entry - the store's sentences interpolate caught errors and are multi-line by nature - and an empty message still clears the field} \
  [list $BT20_M [expr {[string first "\n" $BT20_M] < 0 ? 1 : 0}] [b5_say]] \
  [list {line1 line2 and3} 1 {}]

# --- BT21  A NARROW EDIT REPORTS HONESTLY (issue 1310) -----------------------
## MEASURED: `apply` is per `type=` token and passes no cellname, and op_annot
## holds ONE descriptor per type, so a per-cell display key cannot be expressed
## at all without editing op_annot.tcl - which this item may not. The flavor
## entry is stored, written and honoured by `effective`; it does not reach the
## drawn sheet. The button says so rather than looking broken. Filed as 1310.
b5_lists_reset
b5_dlg [list scope narrow list annotation]
set BT21_D0 [rw_ans ::op_annot::descriptor b5ndev]
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 9
set BT21_M [b5_press delete]
check {BT21 a NARROW edit is stored and honoured by `effective` for this cell and this cell only, the type's descriptor is byte-identical afterwards because a per-cell display key cannot be expressed at all, and the status SAYS the sheet still follows the class list (issue 1310, stated rather than discovered)} \
  [list [b5_owns flavor [list b5cls $B5_CELL1] annotation] \
        [b5_eff annotation $B5_CELL1] [b5_eff annotation $B5_CELL2] \
        [expr {[rw_ans ::op_annot::descriptor b5ndev] eq $BT21_D0 ? 1 : 0}] \
        [b5_ok1 $BT21_M class]] \
  [list 1 {{gm gm 1} {gds gds 1}} $B5_SEED 1 1]

# --- BT22  THE STRUCTURAL FENCE, REPLACING S1's AND K11's `== 0` -------------
## ⚠ ROWS S1 AND K11 GOLDED `op_param_lists:: == 0` IN src/rdw.tcl, AND B5's
## OWN DELIVERABLE FALSIFIES THAT GOLDEN. S1's own trailing comment already
## says so: "B5 is where the store is wired". The fence is not deleted, it is
## REPLACED BY A SHARPER ONE - the file may name the store only through its
## PUBLISHED verbs, never a `_private` one, and it still names none of the six
## forbidden doors S1 lists. S1 and K11 keep every other term they had.
set B5_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
set B5_STORE_ALL [rw_count $B5_F {op_param_lists::}]
set B5_STORE_OK 0
## ⚠ THE ALLOW-LIST GAINED `reduce_why` AND `conf_tiers` (item B5-a). Both are
## PUBLISHED verbs of the store, minted for issues 1323 and 1325, and the row's
## point is unchanged: this file may name the store only through verbs the
## store publishes, and the `op_param_lists::_` term below still golds ZERO.
foreach v {effective set_list get_list owns apply write_conf conf_path said class seed governs reduce_why conf_tiers} {
  incr B5_STORE_OK [rw_count $B5_F "op_param_lists::$v"]
}
set B5_HANDBUILT 0
foreach t {{[list hdr } {[list dim } {[list dev } {[list note }} {
  incr B5_HANDBUILT [rw_count $B5_F $t]
}
check {BT22 STRUCTURAL src/rdw.tcl reaches the list store ONLY through its published verbs and never a private one, still names none of the six forbidden doors, still reaches the seam only through ase::backend_hook, no longer defines rdw::inert - a proc that says `item B5 wires it` after B5 wired it is a lie - and still builds no block line by hand} \
  [list [expr {$B5_STORE_ALL > 0 ? 1 : 0}] \
        [expr {$B5_STORE_ALL == $B5_STORE_OK ? 1 : 0}] \
        [rw_count $B5_F {op_param_lists::_}] \
        [rw_count $B5_F {::ase::backend::ngspice::}] \
        [rw_count $B5_F {raw value}] \
        [rw_count $B5_F {sim_capabilities}] \
        [rw_count $B5_F {blanket_op_save}] \
        [rw_count $B5_F {ase::theme}] \
        [expr {$B5_F eq {NOFILE} ? {NOFILE} : [rw_has $B5_F {ase::backend_hook}]}] \
        [llength [info commands ::rdw::inert]] \
        $B5_HANDBUILT] \
  {1 1 0 0 0 0 0 0 1 0 0}

# ============================================================================
# BT25 .. BT28 — ITEM B5-2's OWN FOUR ROWS
# ============================================================================
# ⚠ THESE FOUR CONTRADICT THE PRESERVED PATCH, AND EACH ONE NAMES A MEASUREMENT
# TAKEN AT HEAD c940a5df RATHER THAN AN OPINION ABOUT IT.
#   BT25 / BT26  A6: the button asked exact-key `owns` where `effective` asks a
#                GLOB, so with `{b5cls *b5n*}` governing a device the column
#                edited a list that device does not read. Two write paths, two
#                different corrections.
#   BT27         A7: `set_list` returns 1 WITH A REPORT when it reduced the
#                list by LABEL, and `rdw::_edit` reads the store's report only
#                on the rc=0 arm - so the one case issue 1288's ruling exists
#                for ("the user is told once") is the case the button drops.
#   BT28         the narrow key is the cell name used as a `string match` GLOB,
#                and a cell name that is not a glob matching itself mints a key
#                that answers nothing.
# ============================================================================

# --- BT25  A6, THE Up/Down HALF: A REORDER MOVES WHAT THE DEVICE READS -------
## MEASURED at HEAD, and it is the reason op_param_lists::governs exists:
##     effective b5cls annotation <M1's cell>        = the FLAVOR list
##     owns flavor {b5cls <M1's cell>} annotation    = 0
## because the entry's key is the GLOB `*b5n*`, not the literal cell name. A
## reorder that asked the second question would answer "broad", write the CLASS
## entry, and leave the user looking at a pane whose order did not move - while
## the status line said it had.
b5_lists_reset
rw_ans ::op_param_lists::set_list flavor [list b5cls *b5n*] annotation $B5_SEED
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 10
set BT25_M [b5_press up]
check {BT25 with a flavor entry whose GLOB governs this cell, an Up press writes THAT entry - the class entry stays unowned, what `effective` answers for this cell really moves, the sibling cell is still on the PDK seed, and the status line NAMES the glob it wrote at rather than claiming a class-wide change it did not make} \
  [list [b5_owns flavor [list b5cls *b5n*] annotation] \
        [rw_ans ::op_param_lists::get_list flavor [list b5cls *b5n*] annotation] \
        [b5_owns class b5cls annotation] \
        [b5_eff annotation $B5_CELL1] [b5_eff annotation $B5_CELL2] \
        [b5_ok1 $BT25_M {*b5n*}] [b5_ok1 $BT25_M gm]] \
  [list 1 {{gm gm 1} {id ids 0} {gds gds 1}} 0 \
        {{gm gm 1} {id ids 0} {gds gds 1}} $B5_SEED 1 1]

# --- BT26  A6, THE BROAD HALF: THE CLASS MOVES AND THE DEVICE DOES NOT -------
## ⚠ AND THE BROAD BASE IS STILL THE CLASS LIST, NOT THIS CELL's. Taking the
## base from `effective $cls $listname $cell` - which the item's own plan asked
## for - would write the FLAVOR list's rows into the CLASS key and destroy every
## class row the flavor entry does not carry. That is ruling DD-7's failure, the
## one that reverted item B2a twice. So the cell goes into the POST-write check
## instead: the class really moved, this device did not, and the button SAYS SO
## instead of reporting a bare success the user cannot see.
b5_lists_reset
b5_dlg [list scope broad list annotation]
rw_ans ::op_param_lists::set_list flavor [list b5cls *b5n*] annotation $B5_SEED
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::set_row 10
set BT26_M [b5_press delete]
check {BT26 a BROAD Delete on a device a flavor glob governs moves the CLASS list and nothing else - the flavor entry is byte-identical afterwards, what this device reads is unchanged, and the status line says so by naming the glob that still wins for it, never a bare success about rows that did not move} \
  [list [b5_owns class b5cls annotation] \
        [rw_ans ::op_param_lists::get_list class b5cls annotation] \
        [rw_ans ::op_param_lists::get_list flavor [list b5cls *b5n*] annotation] \
        [b5_eff annotation $B5_CELL1] \
        [b5_ok1 $BT26_M {*b5n*}]] \
  [list 1 {{id ids 0} {gds gds 1}} $B5_SEED $B5_SEED 1]

# --- BT27  A7: THE STORE TELLS, AND THE BUTTON MUST NOT DROP IT -------------
## MEASURED at HEAD: `set_list class b5cls annotation {{id vgs 2} {gds gds 1}
## {id ids 0}}` returns **1** - success - with the report `a second entry for
## label "id" ... the later one replaces it in place`, and the stored list
## becomes `{id ids 0} {gds gds 1}`: the row the user never touched is GONE.
## IHP's shipped `{id ids 0}` is exactly this label != param shape, so this is
## not a synthetic case. Issue 1288's ruling is that the two doors reach the
## same verdict with the same sentence and the user is told ONCE; a button that
## reads the store's report only on the FAILURE arm tells them zero times.
##
## ⚠ RE-CHECKED UNDER RULING DD-15 BY ITEM B5-3, AND THIS ROW DOES NOT MOVE.
## Item B5-a's note warned that guarding the ADD arm the way the reorder is
## guarded would red this row, and asked whether DD-15 changed that. It does
## not: DD-15 shuts the DECLARATION door (`op_annot::register`), and the label
## collision HERE is minted by `set_list` from two triples the button itself
## assembles - issue 1288's ruled accept-and-report, which DD-15 moves nothing
## about. The refusal being at the declaration is precisely what makes
## extending the reorder guard to Add unnecessary, so the row's assertion
## stands unchanged and no leg is added.
b5_lists_reset
b5_dlg {scope broad list annotation}
rw_ans ::op_param_lists::set_list class b5cls annotation {{id vgs 2} {gds gds 1}}
rw_ans ::op_param_lists::said_clear
rw_ans ::rdw::set_list summary
rw_ans ::rdw::set_row 9
set BT27_M [b5_press add]
set BT27_L [rw_ans ::op_param_lists::get_list class b5cls annotation]
check {BT27 an Add whose triple collides BY LABEL with a row already in the list repeats the STORE's own sentence in the status line, one-lined, rather than reporting a plain success - the stored list is what get_list holds and what effective answers, and the user is told once that a row they did not touch was replaced} \
  [list $BT27_L [b5_eff annotation] \
        [b5_ok1 $BT27_M {replaces it in place}] \
        [b5_ok1 $BT27_M ids] \
        [b5_owns class b5cls annotation]] \
  [list {{id ids 0} {gds gds 1}} {{id ids 0} {gds gds 1}} 1 1 1]

# --- BT28  A NARROW KEY MUST BE A GLOB THAT MATCHES ITSELF ------------------
## The narrow key is the CELL NAME, stored and later matched with
## `string match -nocase`. MEASURED: `a[bc].sym` and `a\b.sym` do NOT match
## themselves, so the key would be written and then answer nothing - and the
## DD-8 shadow branch would fire, blaming "an entry declared earlier in the
## settings file" that does not exist. One wrong sentence produced by the code
## written to remove another. Refuse up front, name the broad alternative, and
## store nothing.
## ⚠ THE SECOND HALF IS THE CONTROL: an ordinary cell name goes through the
## SAME door and is accepted, so the guard is about self-matching and not about
## narrow scope.
b5_lists_reset
set BT28_BAD [dict create instname M1 type b5ndev class b5cls cellname {a[bc].sym}]
set BT28_R   [rw_ans ::rdw::_edit delete $BT28_BAD annotation narrow ids]
set BT28_OK  [dict create instname M1 type b5ndev class b5cls cellname b5plain.sym]
set BT28_R2  [rw_ans ::rdw::_edit delete $BT28_OK annotation narrow ids]
check {BT28 a narrow write whose cell name is not a glob matching itself is REFUSED with its own sentence naming the class-wide alternative, and stores no flavor key at all - while an ordinary cell name through the same door is accepted, so the guard is about the glob and not about narrow scope} \
  [list [lindex $BT28_R 0] \
        [b5_ok1 [lindex $BT28_R 1] {a[bc].sym}] \
        [b5_ok1 [lindex $BT28_R 1] b5cls] \
        [b5_owns flavor [list b5cls {a[bc].sym}] annotation] \
        [b5_owns class b5cls annotation] \
        [lindex $BT28_R2 0] \
        [b5_owns flavor [list b5cls b5plain.sym] annotation]] \
  [list refused 1 1 0 0 ok 1]

# --- BT23  THE REAL WIDGETS, DISPLAY ARM ONLY --------------------------------
## The twin of W4b, rewritten. B3's obligation - every enabled button SAYS what
## it did - does not lapse when the buttons stop being inert; it is exactly
## then that a silent button becomes indistinguishable from a broken one.
if {$live_tk} {
  b5_lists_reset
  b5_dlg {scope broad list annotation}
  b5_fixture_blocks
  rw_ans ::rdw::open
  catch {update idletasks}
  rw_ans ::rdw::set_list annotation
  catch {update idletasks}
  set BT23_CMD {}
  foreach id {up down delete add save} { lappend BT23_CMD [rw_has [rw_w .rdw.b.$id cget -command] "rdw::button $id"] }
  rw_ans ::rdw::set_row 10
  rw_ans ::rdw::status {}
  rw_w .rdw.b.up invoke
  catch {update idletasks}
  set BT23_M [b5_say]
  check {BT23 every enabled button carries rdw::button and nothing else, a real .rdw.b.up invoke really moves the store, and the window still SAYS what happened without ever claiming it is not wired yet} \
    [list $BT23_CMD [b5_owns class b5cls annotation] [b5_eff annotation] \
          [expr {$BT23_M ne {} && $BT23_M ne {NOVAR} ? 1 : 0}] \
          [expr {[string first {not wired yet} $BT23_M] < 0 ? 1 : 0}] \
          [b5_ok1 $BT23_M gm]] \
    [list {1 1 1 1 1} 1 {{gm gm 1} {id ids 0} {gds gds 1}} 1 1 1]
  catch {destroy .rdw.scope}
  rw_ans ::rdw::close
  catch {update idletasks}
}

# --- the section leaves the tree as it found it ------------------------------
catch {rename ::rdw::scope_dialog {}}
if {[llength [info commands ::rdw::b5_real_scope_dialog]]} {
  rename ::rdw::b5_real_scope_dialog ::rdw::scope_dialog
}
array unset ::rdw::pick
rw_ans ::op_param_lists::reset
catch {op_annot::register b5ndev {}}
catch {op_annot::register b5pdev {}}
set ::rdw::blocks {}
rw_ans ::rdw::set_list annotation
rw_ans ::rdw::status {}
catch {xschem raw clear}

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

## ⚠ THE SEVENTH TERM MOVED TO ROW BT22, BY ITEM B5, AND THE COMMENT ABOVE
## ANTICIPATED IT: "B5 is where the store is wired". `op_param_lists:: == 0`
## was true only while the button column was inert; B5's whole deliverable is
## the first real caller of `set_list`, `apply` and `write_conf`. The fence is
## not dropped, it is REPLACED BY A SHARPER ONE - BT22 asserts the file names
## the store ONLY through its published verbs and never a `_private` one, which
## is a stronger statement than a bare zero ever was. The other six tokens stay
## at zero here, unchanged.
set S1_F [expr {[file isfile $RW_FILE] ? [rw_nocomment [rw_slurp $RW_FILE]] : {NOFILE}}]
check {S1 STRUCTURAL the forbidden doors: rdw.tcl reaches the seam ONLY through ase::backend_hook, never by the backend proc's name, and names none of `xschem raw value` / ase::sim_capabilities / blanket_op_save / ase::theme (op_param_lists:: moved to row BT22 when item B5 wired the store)} \
  [list [expr {$S1_F eq {NOFILE} ? {NOFILE} : [rw_has $S1_F {ase::backend_hook}]}] \
        [rw_count $S1_F {::ase::backend::ngspice::}] \
        [rw_count $S1_F {raw value}] \
        [rw_count $S1_F {sim_capabilities}] \
        [rw_count $S1_F {blanket_op_save}] \
        [rw_count $S1_F {ase::theme}]] \
  {1 0 0 0 0 0}

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

# ============================================================================
# THE CHECK-COUNT FLOOR — TRAP 7, WHICH THIS SUITE HAD NO GUARD RAIL FOR
# ============================================================================
# Copied verbatim in shape from KX_FLOOR (test_rdw_keys_1245.tcl:1713), minted
# after a run of THAT suite silently executed fewer rows and still printed ALL
# PASS. Until item B5-3 only the keys suite carried a floor; this one gained a
# whole section of Tk-gated and dialog-gated rows with nothing watching the
# denominator, and a green count is a statement about the FENCE.
#
# ⚠ IT IS THE --nogui MINIMUM, NOT THE Tk NUMBER. The display arm runs the
# `live_tk` rows too (121 with item B5's rows in place), so an equality would
# red every headless run. The floor is the arm that runs FEWEST rows.
#
# ⚠ IT IS A FLOOR, NOT AN EQUALITY. Adding rows must not red the suite: RAISE
# it when you add them, and NEVER lower it to make a run pass, which is the one
# move that would put the skipped-row defect straight back.
#
# ⚠ IT IS AN `incr fail`, NOT A `check`. A `check` would add itself to $npass
# and inflate the very number it is guarding.
#
# 83 (HEAD 59ef24af, --nogui) + 24 (item B5's preserved section BT, of whose 25
# rows one is `live_tk`-gated) + 2 (item B5-3's BT29 and BT30) = 109.
set RW_FLOOR 109
set RW_RAN [expr {$npass + $fail}]
if {$RW_RAN < $RW_FLOOR} {
  puts "FAIL: RWFLOOR the suite ran only $RW_RAN checks, below its floor of\
$RW_FLOOR — rows were SKIPPED, and a skipped row is not a passing one : FAIL"
  incr fail
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
