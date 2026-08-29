# tests/headless/test_annot_blank_cause_0909.tcl -- ISSUE 0909: PRESS 6, GET SIX
# BLANK ROWS, AND HEAR NOTHING ABOUT WHY.
#
# ============================================================================
# WHAT THE USER SEES, IN THEIR OWN WORDS
# ============================================================================
# Verbatim, 2026-08-28, from their own bench on tb_bandgap:
#   "I JUST AGAIN ran tb_bandgap WITHOUT that checkbox checked, only OP
#    analysis, and then, when I do 6 key, I DON'T GET THE MESSAGE IN CIW
#    TELLING ME WHY! I thought we fixed this a couple days ago."
#   "User intent with 6 key press is to get OP device info annotated. If we
#    annotate param = <blank> we need to tell the user why."
#
# Every transistor gets its block. Every value in it is blank. The status line
# reports success. The CIW says nothing at all.
#
# ============================================================================
# THE MECHANISM, MEASURED AT HEAD e89731b5 AND NOT RE-DERIVED HERE
# ============================================================================
# The explanation the user remembers is real and was never removed -- it is
# minted by ase::op_cards_capture at NETLIST time and stands behind a one-turn
# suppression latch keyed on the design cellview. It fires on the first
# Netlist-and-Run of a cellview in a session and is correctly silent after.
#
# THE PRESS HAS NO SENTENCE OF ITS OWN. cadence::annot_mode's state set --
# off, live, notlive, noop, loaded, failed, noraw, nopath, stale, staleraw,
# viewerdiff -- describes the results FILE. Not one member describes what is
# INSIDE it. Measured: grep -c for noparams / nosave / save_op / missing param
# in utils/annot_mode.tcl answers 0.
#
# AND THE SILENCE IS STRUCTURAL, NOT LATCHED. cadence::_annot_say -- the only
# renderer that writes BOTH the CIW and the held status line -- is called from
# the operating-point path at exactly two sites, and both are notop refusal
# returns. Every success path ends at a bare `xschem statusmsg -hold`: the
# status line and nothing else. So "unlatched" costs nothing to build; the work
# is giving the success path a CIW leg at all.
#
# THE DESIGN RULE THIS FILE EXISTS TO HOLD: a suppression latch is right for a
# NAG and wrong for an ANSWER. A nag is the tool volunteering something while
# the user is busy, and suppressing a repeat is courteous. A key press is the
# user asking a direct question, and a question asked twice is answered twice.
# Row BC4 is the whole point of the file; without it a future latch can be
# reintroduced and every single-press row stays green.
#
# ============================================================================
# THE TEST GAP THIS FILE CLOSES
# ============================================================================
# Every assertion in tests/headless/test_op_annot.tcl reads
# `xschem get statusmsg`, the 256-byte C status buffer -- 61 of them. The
# notice the user is asking about goes to the CIW PANE through the notify
# channel. The suites have been asserting a different sink from the one the
# user reads: at HEAD test_op_annot passes RESULT ALL PASS with 472 checks
# while this defect is fully live. So the rows below spy on ::ciw_echo, which
# is the pane's own entry point and is route-independent -- it catches both
# ase::echo, which reaches it through xschem::notify_safe, and a DIRECT
# xschem::notify, which is the only route that renders the -menu and -command
# remedy fields at all.
#
# ============================================================================
# THE FOUR CAUSES, AND WHY ONE SENTENCE CANNOT SERVE THEM
# ============================================================================
#   1. the save-cards gate is off -- the user's case. Remedy: the tick, or the
#      pasteable CIW command.
#   2. the results file has no per-device numbers and no session claims the
#      sheet -- the menu path is still true, but naming a session key nobody is
#      under is issue 0679 verbatim, measured on this very bench.
#   3. the file HAS device numbers, but not for this device. Not attributable,
#      so no remedy is guessed -- src/ase.tcl:765's own rule, "a wrong direction
#      printed with authority is worse than printing none".
#   4. the symbol type has no descriptor at all, because only sky130A,
#      gf180mcuD and ihp-sg13g2 call op_annot::register (issue 0906). Measured:
#      this one draws NO BLOCK, not a blank one, so a sentence saying "the
#      values are blank" is wrong for it. It gets the already-minted
#      "These symbol types have no operating-point values to show" clause and
#      NO remedy, because there is nothing today the user can do about it.
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE -- READ BEFORE TRUSTING IT
# ============================================================================
# * NO PIXELS. The CIW is read at ::ciw_echo, the pane's own entry point, not
#   off a Tk text widget. A green run here is not proof the pane shows it; that
#   owes the user's eyes and is recorded as a look debt.
# * NO SIMULATOR. The sky130 rows run the REAL committed cell through the REAL
#   ase::netlist with the tick box in its shipped unticked state, and the deck
#   is asserted to carry zero `.save @` cards -- that is the supply-chain
#   evidence. The results file itself is then written at the exact path the
#   session's own backend hook names, which is where ngspice would put it and
#   where the chord's candidate search looks. Nothing is hand-attached: every
#   press below finds its own file.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_annot_blank_cause_0909.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_annot_blank_cause_0909.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locations -cwd-independent- --------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch annot_blank_0909]

# ============================================================================
# THE ANSWER DISCIPLINE -- an absent proc must never satisfy a golden
# ============================================================================
# Every helper answers NOPROC when the command it calls does not exist and
# RAISED:<text> when it blows up. A bare catch-and-discard would let
# "invalid command name cadence::_annot_cause_msg" satisfy a row that expects
# an empty string -- i.e. the file would go green against the very tree it was
# written to redden.
proc b_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}

## THE CIW PANE, SPIED AT ITS OWN ENTRY POINT. ::ciw_echo is where BOTH routes
## land -- ase::echo goes through xschem::notify_safe into xschem::notify, and a
## direct xschem::notify calls it as sink 1 -- so this records the RENDERED
## line, remedy fields and all. The same park/restore engine
## tests/headless/test_ase_final.tcl uses. Returns a list of tag/line pairs.
proc b_ciw {script} {
  set ::b_echo {}
  set had [expr {[info commands ::ciw_echo] ne {}}]
  if {$had} { rename ::ciw_echo ::b_saved_ciw_echo }
  proc ::ciw_echo {line {tag {}}} { lappend ::b_echo [list $tag $line] ; return 1 }
  catch {uplevel 1 $script}
  catch {rename ::ciw_echo {}}
  if {$had} { rename ::b_saved_ciw_echo ::ciw_echo }
  return $::b_echo
}

## One press of the 6 chord with the pane recorded. Returns
## {ciw-pairs statusmsg statusmsg-hold}, so a row can assert the two sinks
## together and neither can cover for the other.
proc b_press {{mode op}} {
  catch {xschem statusmsg -hold ZZ0909SENTINEL}
  set c [b_ciw [list cadence::annot_mode $mode]]
  set s NOSTATUS ; set h NOHOLD
  catch {set s [xschem get statusmsg]}
  catch {set h [xschem get statusmsg_hold]}
  return [list $c $s $h]
}
proc b_c {p} { return [lindex $p 0] }
proc b_s {p} { return [lindex $p 1] }
proc b_h {p} { return [lindex $p 2] }

## The block the overlay draws, collapsed to one line the way the eye reads it.
proc b_rows {inst} {
  set r NOPROC
  if {[llength [info commands ::op_annot::text]]} {
    set r {}
    catch {set r [::op_annot::text $inst]}
    set r [string map [list "\n" { | }] [string trim $r]]
    regsub -all { +} $r { } r
  }
  return $r
}

## Does the block carry at least one row whose value is BLANK. op_annot.tcl
## emits a blank row as the label padded to width then " =" and nothing after,
## so a blank row is a line ending in the literal `=`.
proc b_hasblank {inst} {
  set b {}
  if {[catch {::op_annot::text $inst} b]} { return RAISED }
  if {$b eq {}} { return 0 }
  foreach l [split [string trimright $b "\n"] "\n"] {
    if {[string match {*=} [string trimright $l]]} { return 1 }
  }
  return 0
}

## Code lines of a file, whole-line Tcl comments dropped, so a sentence quoted
## in a header paragraph is never counted as a second mint.
proc b_codelines {path} {
  if {![file isfile $path]} { return {} }
  set fd [open $path r] ; set d [read $fd] ; close $fd
  set out {}
  foreach l [split $d \n] {
    if {[regexp {^\s*#} $l]} continue
    lappend out $l
  }
  return $out
}
proc b_ngrep_code {path re} {
  set n 0
  foreach l [b_codelines $path] { if {[regexp -- $re $l]} { incr n } }
  return $n
}
## The code lines of one proc's BODY, comments dropped. NOPROC when absent, so
## a structural row cannot pass against a proc that was deleted.
proc b_bodylines {name} {
  if {![llength [info commands $name]]} { return NOPROC }
  set out {}
  foreach l [split [info body $name] \n] {
    if {[regexp {^\s*#} $l]} continue
    lappend out $l
  }
  return $out
}
## 1-based index of the FIRST body code line matching <re>, or 0 when none.
proc b_bodyline {name re} {
  set ls [b_bodylines $name]
  if {$ls eq {NOPROC}} { return NOPROC }
  set i 0
  foreach l $ls {
    incr i
    if {[regexp -- $re $l]} { return $i }
  }
  return 0
}

# ============================================================================
# THE GOLDENS -- THE THREE SENTENCES THE PRESS MUST BE ABLE TO SAY
# ============================================================================
# ⚠ WORDING INVENTED BY THIS CREW AND NOT YET RATIFIED BY THE USER. It is
# recorded as an owed RULE against issue 0909; if the user re-words it, these
# three constants and the two in tests/headless/test_op_annot.tcl section A11
# are the only places that move.
#
# Each obeys the user's PLAIN ENGLISH ruling, verbatim 2026-08-27: "wording too
# cryptic. Give it in plain english with context, 9th grade level." So each one
# says WHAT HAPPENED, gives the CONTEXT that makes it make sense, and ends with
# WHAT TO DO -- the third leg is what row A11-13b in test_op_annot.tcl asserts
# as a property rather than as three separate readings.
#
# ⚠ THREE SENTENCES, NOT ONE, BECAUSE THE REMEDIES DIFFER. src/ase.tcl:765's
# own rule governs the split: "a wrong direction printed with authority is
# worse than printing none."
set BC_NOCARDS {Some values are blank because this simulation did not save the device operating-point numbers. The results file has node voltages, but no per-device values like gm, gds and vth. Turn on saving them, then run the simulation again.}
set BC_NOPARAMS {Some values are blank because the results file has no per-device operating-point numbers in it, such as gm, gds and vth. Run the simulation again with device parameter saving turned on.}
set BC_SOMEDEV {Some values are blank. The results file does have device operating-point numbers, but not for every device on this sheet. Run the simulation again, and check that these devices are included in what it saves.}

# AND THE SAME THREE, SHORT, FOR THE 255-BYTE STATUS LINE. The long forms do
# not fit: the save-cards one is 229 bytes against a 55-byte mask sentence, so
# the bar's elision landed inside the remedy and the line read "... Turn on
# saving..." without ever saying saving WHAT. The pane keeps the long form,
# which is why there are two and not one. Both are minted in the same proc.
set BC_NOCARDS_S {Some values are blank because this run did not save device values like gm and vth. Turn on saving them, then run again.}
set BC_NOPARAMS_S {Some values are blank because the results file has no device values like gm and vth in it. Run the simulation again with them saved.}
set BC_SOMEDEV_S {Some values are blank because the results file has no numbers for some of the devices here. Run the simulation again and save them.}

## The already-minted clause for a symbol type nobody registered a descriptor
## for. NOT a new sentence -- it is the shipped wording, and the only thing
## issue 0909 changes about it is that a MIXED sheet can finally reach it.
proc bc_types_clause {types} {
  return "These symbol types have no operating-point values to show: [join $types {, }]."
}

## Does this results file carry per-device operating-point vectors at all.
## ⚠ `string first`, NEVER `string match`. A left bracket is a glob
## metacharacter, so a pattern built to look for one is a live trap that
## answers plausibly and wrongly -- the discriminator between "the file has no
## device numbers" and "it has them, but not for this device" must not be built
## out of one.
proc bc_has_devvec {names} {
  foreach n [split [string trimright $names "\n"] "\n"] {
    if {[string first {@} $n] >= 0 && [string first {[} $n] >= 0} { return 1 }
  }
  return 0
}
## Does this results file carry a device OPERATING-POINT PARAMETER -- gm, gds,
## vth -- as opposed to a device TERMINAL CURRENT, which every real ngspice
## operating point carries whether or not one save card was emitted.
##
## ⚠ THE TWO ARE NOT THE SAME QUESTION AND THE WHOLE ITEM TURNED ON MISTAKING
## THEM. `.options savecurrents` is a different tickbox from "Save device OP
## parameters" and it is set in 35 of the committed ASE states, the user's own
## tb_bandgap_opamp included. Measured on ngspice 46, one deck, two runs:
##   savecurrents only ->  i(@m1[ib]) i(@m1[id]) i(@m1[ig]) i(@m1[is])
##   save cards too    ->  @m1[gds] @m1[gm] v(@m1[vth]) + the four above
## So `@` plus `[` is true of EVERY real operating point, and a probe built on
## that pair alone answers "this file has device numbers" on every bench.
## ngspice wraps a current in `i(` and leaves the rest bare or `v(`-wrapped;
## that wrapper is the separator, and it is ngspice's convention, not this
## file's invention.
proc bc_has_devparam {names} {
  foreach n [split [string trimright $names "\n"] "\n"] {
    set n [string trim $n]
    if {[string first {@} $n] < 0} continue
    if {[string first {[} $n] < 0} continue
    if {[string range $n 0 1] eq {i(}} continue
    return 1
  }
  return 0
}
## The attached database's analysis type, with a SPEAKING placeholder rather
## than a silent empty string when nothing is attached.
proc bc_simtype {} {
  set t {}
  if {[catch {xschem raw sim_type} t]} { return NORAW }
  return $t
}

# ============================================================================
# SECTION 1 -- THE THREE CAUSES THAT ARE NOT THE USER'S, ON A SYNTHETIC BENCH
# ============================================================================
# A hand-built library, because these three causes cannot all be produced from
# one committed PDK cell: one of them REQUIRES a symbol type no descriptor was
# ever registered for, and every shipped PDK in this tree registers its own.
set lib [file join $scratch lib]
set nd  [file join $scratch nd]
set ndempty [file join $scratch ndempty]
file mkdir $lib $nd $ndempty
## ⚠ UNQUALIFIED, AND IT IS NOT A STYLE CHOICE. The write trace armed at
## src/xschem.tcl:16527 compares `$varname eq {XSCHEM_LIBRARY_PATH}`, and a
## QUALIFIED `set ::XSCHEM_LIBRARY_PATH` delivers `::XSCHEM_LIBRARY_PATH` --
## so set_paths never runs, every symbol below resolves to "Symbol not found",
## and the sheets load EMPTY while every scan still answers plausibly.
## Recorded at tests/headless/test_op_annot.tcl:76 and measured again here.
set XSCHEM_LIBRARY_PATH ":[file join $repo xschem_library devices]:$lib"
source [file join $repo utils annot_mode.tcl]

## Two DISTINCT cells of the SAME registered type, plus one unregistered type.
## ⚠ THE TWO FETS ARE TWO SYMBOL FILES ON PURPOSE. cadence::_annot_scan walks
## the sheet deduped by cell::name, so two INSTANCES of one cell are one visit
## and the sibling whose vectors are missing is never looked at -- that is the
## accepted limitation filed as issue 0913. Row BC8's subject is the per-device
## cause, not that limitation, so its two devices are two cells.
foreach {sym typ nm} {zfeta zzs16fet MZZ1 zfetb zzs16fet MZZ2 nod zzs16unreg MUU1} {
  set f [open [file join $lib $sym.sym] w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "K \{type=$typ\nformat=\"@name @pinlist @model\"\ntemplate=\"name=$nm model=zzdev\"\}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  puts $f "L 4 0 0 0 10 {}"
  close $f
}
proc bc_devproc {instname model path spiceprefix} {
  return "@m.x[string tolower $instname].mzz"
}
op_annot::register zzs16fet \
  [list devproc bc_devproc params {{id id 0} {gm gm 1} {gds gds 1}}]

proc bc_sheet {name recs} {
  global lib
  set f [open [file join $lib $name.sch] w]
  puts $f "v {xschem version=3.4.6 file_version=1.2}"
  puts $f "G {}"
  puts $f "V {}"
  puts $f "S {}"
  puts $f "E {}"
  foreach r $recs { puts $f $r }
  close $f
}
bc_sheet bc_mixed [list "C \{zfeta.sym\} 0 0 0 0 \{name=MZZ1\}" \
                        "C \{nod.sym\} 0 200 0 0 \{name=MUU1\}"]
bc_sheet bc_two   [list "C \{zfeta.sym\} 0 0 0 0 \{name=MZZ1\}" \
                        "C \{zfetb.sym\} 0 100 0 0 \{name=MZZ2\}"]
bc_sheet bc_one   [list "C \{zfeta.sym\} 0 0 0 0 \{name=MZZ1\}"]
bc_sheet bc_blank [list "C \{zfeta.sym\} 0 0 0 0 \{name=MZZ1\}"]
bc_sheet bc_noraw [list "C \{zfeta.sym\} 0 0 0 0 \{name=MZZ1\}"]
set bc_big_recs {}
for {set i 1} {$i <= 200} {incr i} {
  lappend bc_big_recs "C \{zfeta.sym\} 0 [expr {$i * 40}] 0 0 \{name=MZZ$i\}"
}
bc_sheet bc_big $bc_big_recs

## An operating point that carries node voltages and NO device vectors -- what
## ngspice writes when the save-cards box is left unticked.
proc bc_raw_nodev {path} {
  set f [open $path w]
  puts -nonewline $f "Title: no device parameters
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\tv(d)\tvoltage
\t1\tv(g)\tvoltage
Values:
0\t7.5
\t1.25
"
  close $f
}
## An operating point that DOES carry device vectors -- for MZZ1 only.
proc bc_raw_mzz1 {path} {
  set f [open $path w]
  puts -nonewline $f "Title: device parameters for one device
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 4
No. Points: 1
Variables:
\t0\tv(d)\tvoltage
\t1\ti(@m.xmzz1.mzz\[id\])\tcurrent
\t2\t@m.xmzz1.mzz\[gm\]\tnotype
\t3\t@m.xmzz1.mzz\[gds\]\tnotype
Values:
0\t7.5
\t1.1e-05
\t2.2e-04
\t3.3e-06
"
  close $f
}
foreach c {bc_mixed bc_two bc_one bc_big} { bc_raw_mzz1 [file join $nd $c.raw] }
bc_raw_nodev [file join $nd bc_blank.raw]

## THE OPERATING POINT A REAL NGSPICE RUN WRITES FOR THE COMMITTED CELL WITH
## THE SAVE-CARDS BOX UNTICKED -- node voltages, the source current, and the
## FOUR TERMINAL CURRENTS `.options savecurrents` adds for free. It is the
## file shape the user is actually looking at when they press 6 and get blank
## rows, and it is the shape this suite used to hand-write ITSELF out of
## existence: the fixture wrote two node voltages and nothing else, so the one
## element that decides the whole outcome was assembled here rather than by the
## product, and the row passed over a defect that reaches the user on his first
## press.
##
## ⚠ THE VECTOR NAMES ARE BUILT BY op_annot's OWN NAME BUILDER, not typed. That
## is what makes the fixture a statement about the product: if the device path
## ever drifts, this file drifts with it instead of quietly describing a raw
## nobody writes. `id`, `ig`, `is` and `ib` are ngspice's four MOS terminal
## currents; only `id` is in the sky130 descriptor, so the block comes up with
## one row filled and five blank -- exactly the user's screen.
##
## ⚠ AND gm / gds / vth ARE DELIBERATELY ABSENT. They are what the tickbox adds,
## they are what is missing, and a fixture that included them would be
## describing the fixed case.
##
## <extra> adds real operating-point PARAMETERS on top, as {param kind} pairs,
## for the one row that needs a file holding both kinds at once.
proc bc_raw_savecurrents {path inst {extra {}}} {
  set vecs [list v(d) v(g) i(v1)]
  foreach term {id ig is ib} {
    lappend vecs [::op_annot::vector $inst $term 0]
  }
  foreach e $extra {
    lappend vecs [::op_annot::vector $inst [lindex $e 0] [lindex $e 1]]
  }
  set f [open $path w]
  puts $f "Title: save-cards box unticked, savecurrents on"
  puts $f "Date: Mon Jan 1 00:00:00 2026"
  puts $f "Plotname: Operating Point"
  puts $f "Flags: real"
  puts $f "No. Variables: [llength $vecs]"
  puts $f "No. Points: 1"
  puts $f "Variables:"
  set i 0
  foreach v $vecs { puts $f "\t$i\t$v\tnotype" ; incr i }
  puts $f "Values:"
  set i 0
  foreach v $vecs {
    if {$i == 0} { puts -nonewline $f "0\t" } else { puts -nonewline $f "\t" }
    puts $f [expr {1.1e-05 * ($i + 1)}]
    incr i
  }
  close $f
}

## Load a synthetic sheet with NOTHING attached, so the press below has to find
## its own results file through the chord's own candidate search.
proc bc_load {name {dir {}}} {
  global lib nd
  if {$dir eq {}} { set dir $nd }
  catch {xschem raw clear}
  catch {xschem set annot_show 0}
  xschem load [file join $lib $name.sch]
  uplevel #0 [list set netlist_dir $dir]
  return [b_ans ::cadence::_annot_raw_candidate]
}

# ---------------------------------------------------------------------------
# BC7 -- ACCEPTANCE 3: THE UNREGISTERED DESIGN KIT, ON A MIXED SHEET
# ---------------------------------------------------------------------------
# ⚠ THIS IS THE CAUSE WITH NO BLANK ROWS AT ALL, AND THAT IS THE POINT. A
# symbol type nobody registered a descriptor for draws NO BLOCK -- measured,
# op_annot::text answers the empty string -- so a sentence saying "the values
# are blank" would be describing something that is not on the screen.
# ⚠ AND IT IS SUPPRESSED EXACTLY WHERE IT MATTERS. utils/annot_mode.tcl gates
# the already-minted descriptor clause on "nothing here is annotatable", so on
# the realistic bench -- one registered FET plus one hand-drawn symbol -- the
# clause is dropped and the user is told nothing. Measured at HEAD: the scan
# answers `1 zzs16unreg` and the sentence never appears.
# The NEGATIVE half is the load-bearing one: this cause must NEVER carry the
# save-cards remedy, because ticking that box would not change it.
# ⚠ THE FIXTURE IS MEASURED AFTER THE PRESS, AND IT HAS TO BE -- true of BC8a
# and BC9a below as well. bc_load detaches whatever was attached so the chord
# has to find its own file, so BEFORE the press every row of every block is
# blank and a fixture asserted there would be describing an empty screen rather
# than the user's.
set bc7_cand [bc_load bc_mixed]
set bc7_scan [b_ans ::cadence::_annot_scan]
set bc7_p    [b_press op]
set bc7_line [lindex [lindex [b_c $bc7_p] 0] 1]
check {BC7a FIXTURE one registered FET with its numbers, one symbol type nobody registered} \
  [list [lindex $bc7_cand 2] [lrange $bc7_scan 0 1] [b_hasblank MZZ1] [b_rows MUU1]] \
  [list netlist_dir {1 zzs16unreg} 0 {}]
check {BC7 the unregistered symbol type gets its own clause on a MIXED sheet, and NEVER the save-cards remedy} \
  [list [llength [b_c $bc7_p]] [lindex [b_c $bc7_p] 0] \
        [string match {*Fix:*} $bc7_line] \
        [string match {*save_op_params_on*} $bc7_line] \
        [string match {*Some values are blank*} $bc7_line]] \
  [list 1 [list warn [bc_types_clause zzs16unreg]] 0 0 0]

# ---------------------------------------------------------------------------
# BC8 -- THE PER-DEVICE CAUSE, AND THE REMEDY THAT IS DELIBERATELY NOT PRINTED
# ---------------------------------------------------------------------------
# The results file demonstrably HAS device operating-point numbers -- it
# carries `@m.xmzz1.mzz[gm]` -- so telling this user to turn on device
# parameter saving would be a wrong direction printed with authority. The
# honest general sentence is said instead, and no remedy is guessed.
set bc8_cand [bc_load bc_two]
set bc8_scan [b_ans ::cadence::_annot_scan]
set bc8_p    [b_press op]
set bc8_line [lindex [lindex [b_c $bc8_p] 0] 1]
set bc8_list {}
catch {set bc8_list [xschem raw list]}
check {BC8a FIXTURE two registered devices, one with its vectors in the file and one without} \
  [list [lrange $bc8_scan 0 1] [bc_has_devvec $bc8_list] [b_hasblank MZZ1] [b_hasblank MZZ2]] \
  [list {2 {}} 1 0 1]
check {BC8 a file that HAS device numbers but not for this device says so, and guesses no remedy} \
  [list [llength [b_c $bc8_p]] [lindex [b_c $bc8_p] 0] \
        [string match {*Fix:*} $bc8_line] \
        [string match {*CIW command:*} $bc8_line]] \
  [list 1 [list warn $BC_SOMEDEV] 0 0]

# ---------------------------------------------------------------------------
# BC9 -- NO ASE-L SESSION OWNS THE SHEET: THE MENU PATH, AND NO PASTEABLE
#        COMMAND. ISSUE 0679's RULE, PINNED.
# ---------------------------------------------------------------------------
# The menu path is still true for anyone -- it is where the tick lives. The
# CIW command names a SESSION KEY, and 0679 is the measured case of one being
# printed that no session was ever registered under, on this very bench with
# tb_bandgap. So the command half is omitted rather than invented.
set bc_menu [b_ans ::ase::ui::remedy_op_params_menu]
set bc9_cand [bc_load bc_blank]
set bc9_scan [b_ans ::cadence::_annot_scan]
set bc9_p    [b_press op]
set bc9_line [lindex [lindex [b_c $bc9_p] 0] 1]
set bc9_list {}
catch {set bc9_list [xschem raw list]}
check {BC9a FIXTURE blank rows, an operating point with no device vectors at all, and no session claiming the sheet} \
  [list [b_ans ::ase::session_for_current] [lrange $bc9_scan 0 1] [b_hasblank MZZ1] \
        [bc_has_devvec $bc9_list] [bc_simtype]] \
  [list {} {1 {}} 1 0 op]
check {BC9 with no session to name, the sentence carries the menu path and NO pasteable command} \
  [list [llength [b_c $bc9_p]] [lindex [b_c $bc9_p] 0] \
        [string match {*CIW command:*} $bc9_line]] \
  [list 1 [list warn "$BC_NOPARAMS Fix: $bc_menu."] 0]

# ---------------------------------------------------------------------------
# BC10 -- THE MASK GATE: Alt-6 DRAWS NO DEVICE BLOCK, SO IT EXPLAINS NO BLANK
#         DEVICE ROWS
# ---------------------------------------------------------------------------
# Alt-6 shows DC node voltages. There is no device block on the screen for a
# blank row to be in, so the cause sentence would be an answer to a question
# nobody asked. The second leg proves the press really ran -- without it a
# fixture that never pressed anything would satisfy the silence claim.
set bc10_cand [bc_load bc_blank]
set bc10_p [b_press opvolt]
check {BC10 Alt-6 draws no device block, so it says nothing about blank device rows} \
  [list [llength [b_c $bc10_p]] \
        [string match {*Some values are blank*} [b_s $bc10_p]] \
        [string match {*DC node voltages*} [b_s $bc10_p]]] \
  [list 0 0 1]

# ---------------------------------------------------------------------------
# BC11 -- THE STATE GATE: A REFUSAL THAT ALREADY NAMED THE MISSING FILE IS NOT
#         ALSO TOLD ITS VALUES ARE BLANK
# ---------------------------------------------------------------------------
# There is no results file, so nothing was annotated and there are no values,
# blank or otherwise. Stacking "Some values are blank because..." on top of
# "There is no results file at ... yet" would be a second, wrong reason for the
# same press.
set bc11_cand [bc_load bc_noraw $ndempty]
set bc11_p [b_press op]
check {BC11 a press with no results file at all is not also told why its values are blank} \
  [list [llength [b_c $bc11_p]] \
        [string match {*There is no results file at*} [b_s $bc11_p]] \
        [string match {*Some values are blank*} [b_s $bc11_p]]] \
  [list 0 1 0]

# ---------------------------------------------------------------------------
# BC12 -- THE ANTI-NAG CONTROL: A FULLY POPULATED BLOCK SAYS NOTHING, THREE
#         TIMES
# ---------------------------------------------------------------------------
# ⚠ WITHOUT THIS ROW A DETECTOR THAT ALWAYS FIRES WOULD PASS BC2 AND BC4. The
# whole feature is a claim about blank values; a press that found every number
# it went looking for has no news, and a tool that volunteers an explanation
# anyway is the nag this issue is about, wearing the answer's clothes.
set bc12_cand [bc_load bc_one]
set bc12_1 [b_press op]
set bc12_2 [b_press op]
set bc12_3 [b_press op]
check {BC12 a fully populated block says nothing at all, on all three presses} \
  [list [b_hasblank MZZ1] [llength [b_c $bc12_1]] [llength [b_c $bc12_2]] \
        [llength [b_c $bc12_3]]] \
  [list 0 0 0 0]

# ---------------------------------------------------------------------------
# BC17 -- COST: ONE PRESS, ONE WALK OF THE SHEET
# ---------------------------------------------------------------------------
# ⚠ ISSUE 0904 IS THE RECORDED CASE OF A COST PUBLISHED ON THE AXIS IT DOES NOT
# SCALE ON, so this row measures the axis the blank-row probe actually grows on
# -- the number of instances the press walks -- and pins the SHAPE structurally
# as well as the clock. A second walk would be invisible to every behavioural
# row in this file and would double the price of the most-pressed key in the
# feature.
set bc17_cand [bc_load bc_big]
set bc17_ni 0
catch {set bc17_ni [xschem get instances]}
set bc17_t0 [clock milliseconds]
set bc17_p  [b_press op]
set bc17_ms [expr {[clock milliseconds] - $bc17_t0}]
set bc17_amb [b_bodylines ::cadence::annot_mode]
set bc17_scn [b_bodylines ::cadence::_annot_scan]
set bc17_nscan 0
if {$bc17_amb ne {NOPROC}} {
  foreach l $bc17_amb { if {[regexp {_annot_scan} $l]} { incr bc17_nscan } }
}
set bc17_ninst 0
if {$bc17_scn ne {NOPROC}} {
  foreach l $bc17_scn { if {[regexp {xschem get instances} $l]} { incr bc17_ninst } }
}
check {BC17 one press walks the sheet exactly once, and a 200-device sheet stays under the stated bound} \
  [list $bc17_ni $bc17_nscan $bc17_ninst [expr {$bc17_ms >= 0 && $bc17_ms < 5000 ? 1 : 0}]] \
  [list 200 1 1 1]

# ============================================================================
# SECTION 2 -- THE USER'S OWN CASE, THROUGH THE REAL SUPPLY CHAIN
# ============================================================================
# A REAL committed sky130 cell, the REAL ase::netlist, the REAL session
# registry, and the "Save device OP parameters (gm, gds, vth, ...)" box in its
# shipped UNTICKED state. Nothing here is hand-attached: the deck is written by
# the product, the results file is put where the session's own backend hook
# says ngspice would put it, and every press below finds that file through the
# chord's own candidate search.
#
# ⚠ WHY THE SIMULATOR IS NOT RUN. What is under test is what the tool SAYS
# about a results file that has no per-device numbers in it, and a run adds a
# dependency without adding evidence: the supply-chain fact that matters is
# that the REAL netlister, with the box unticked, wrote a deck carrying ZERO
# `.save @` cards -- which row BC1 asserts against the file the product just
# produced.
set BC_M1      {Showing device operating-point values on the schematic.}
set BC_LIVE    { These results were already loaded.}
set BC_LOADEDF { Loaded results from @P@.}
proc bc_bytes {s} {
  if {[catch {string bytelength $s} n]} {
    set n [string length [encoding convertto utf-8 $s]]
  }
  return $n
}
## One field of the ::xschem::notify_last witness, with a SPEAKING placeholder
## rather than an empty string, so an absent record can never satisfy a golden.
proc bc_notify_field {f} {
  if {![info exists ::xschem::notify_last]} { return NO-RECORD }
  if {[catch {dict get $::xschem::notify_last $f} v]} { return NO-FIELD-$f }
  return $v
}

set bc_cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set bc_statefile [file join $bc_cellroot ngspice_state1 test_nfet_final.state]
set bc_sch       [file join $bc_cellroot schematic test_nfet_final.sch]
set ::SKYWATER_MODELS [file join $repo sky130A models libs.tech combined]
set bc_defs [file join $scratch library.defs]
set f [open $bc_defs w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS $bc_defs
set ::library_registry_defs_only 1
catch {source [file join $repo sky130A sky130_procs.tcl]}

catch {xschem raw clear}
catch {xschem set annot_show 0}
xschem load $bc_sch
set bc_dsg {}
catch {set bc_dsg [ase::design_of_path [file normalize $bc_sch]]}
set bc_key {}
if {[llength $bc_dsg] == 3} {
  set bc_key [ase::session_key {*}$bc_dsg]
  catch {ase::session_open $bc_key $bc_statefile}
  set bc_rundir [file normalize [file join $scratch run]]
  file mkdir $bc_rundir
  set bc_st [ase::session_state $bc_key]
  catch {dict set bc_st rundir $bc_rundir}
  catch {ase::session_update $bc_key $bc_st}
}
set bc_nl {}
catch {set bc_nl [ase::netlist [ase::session_state $bc_key]]}
set bc_nsave -1
if {$bc_nl ne {} && [file isfile $bc_nl]} {
  set fd [open $bc_nl r] ; set bc_deck [read $fd] ; close $fd
  set bc_nsave 0
  foreach l [split $bc_deck \n] {
    if {[regexp {^\s*\.save\b.*@} $l]} { incr bc_nsave }
  }
}
## ⚠ THE RESULTS FILE IS WRITTEN IN THE SHAPE THE SIMULATOR REALLY WRITES IT,
## AND THAT IS THE CORRECTION THIS SUITE NEEDED MOST. The committed state for
## this cell carries `options {{name savecurrents value 1}}`, src/ase.tcl
## renders it as `.options savecurrents`, and ngspice 46 then writes a device
## vector per terminal even with every save card absent -- verified by running
## the real simulator on the real deck. The first version of this file wrote a
## two-variable raw holding v(d) and v(g) instead, and every row below it
## therefore measured a file the product never produces. The path is still the
## one the session's own backend hook names, so the press still has to find it.
set bc_raw {}
catch {set bc_raw [[ase::backend_hook ngspice raw_file] [ase::session_state $bc_key]]}
if {$bc_raw ne {}} { bc_raw_savecurrents $bc_raw M1 }

## ⚠ THE WITNESS IS RESET BEFORE THE PRESSES, AND WITHOUT THIS ROW BC3 PASSES
## AGAINST THE WRONG MESSAGE. `ase::netlist` above ran the NETLIST-TIME nag,
## which carries a `-command` field naming this very session key -- so
## ::xschem::notify_last already holds a pasteable command that BC3 would
## happily execute while the press it is supposed to be measuring said nothing.
catch {::xschem::notify_record ZZ0909RESET ZZ0909RESET ZZ0909RESET {} {} {} {}}

set bc_cand [b_ans ::cadence::_annot_raw_candidate]
set bc_scan [b_ans ::cadence::_annot_scan]
set bc_p1 [b_press op]
set bc_rawlist {}
catch {set bc_rawlist [xschem raw list]}
set bc_p2 [b_press op]
set bc_p3 [b_press op]

# ---------------------------------------------------------------------------
# BC1 -- FIXTURE: THE PRECONDITION THAT STOPS EVERY ROW BELOW PASSING VACUOUSLY
# ---------------------------------------------------------------------------
# A real registered session owns the sheet; its save-cards gate really reads
# off; the real netlister really produced a deck with no `.save @` cards; the
# device really renders a block with blank values; and the chord really reached
# that file through the ASE arm of its own candidate search.
#
# ⚠ THE TWO RAW LEGS ARE THE HEART OF THIS ROW AND THEY DISAGREE ON PURPOSE.
# `bc_has_devvec` is 1: the file DOES carry `@dev[...]` vectors, because
# `.options savecurrents` is in the committed state and ngspice writes a
# terminal current for every device whether or not a save card was emitted.
# `bc_has_devparam` is 0: not one of them is an operating-point PARAMETER.
# A probe that cannot tell those two apart answers "this file has device
# numbers" on every real bench, and the save-cards explanation -- the item's
# entire deliverable -- becomes unreachable in the field while every row here
# stays green. That is precisely what shipped, and this pair is what would have
# caught it.
#
# ⚠ AND `vsource` IS NO LONGER IN THE SCAN'S TYPE LIST. The voltage source is
# stimulus, not a device with an operating-point block, and once the descriptor
# clause stopped being suppressed on mixed sheets it was being named -- as a
# warning, on a completely successful annotation, on every press of every
# testbench in existence. It is skipped now; see cadence::_annot_skip_types.
check {BC1 FIXTURE the user's exact case, assembled by the product and not by this file} \
  [list [file isfile $bc_sch] [file isfile $bc_statefile] \
        [expr {[b_ans ::ase::session_for_current] ne {} ? 1 : 0}] \
        [b_ans ::ase::op_gate_on [b_ans ::ase::state_get [b_ans ::ase::session_state $bc_key] save_op_params {}]] \
        $bc_nsave [bc_has_devvec $bc_rawlist] [bc_has_devparam $bc_rawlist] [bc_simtype] \
        [b_hasblank M1] [lrange $bc_scan 0 1] [lindex $bc_cand 2]] \
  [list 1 1 1 0 0 1 0 op 1 {1 {}} ase]

# ---------------------------------------------------------------------------
# BC1b -- THE PROBE ITSELF, ON THE FILE THE SIMULATOR REALLY WROTE
# ---------------------------------------------------------------------------
# BC1 asserts what is in the file; this asserts what the PRODUCT makes of it.
# `cadence::_annot_devparams_present` must answer 0 here even though `@`-and-`[`
# vectors are sitting in the list, and `cadence::_annot_cause` must therefore
# reach the save-cards question at all. Without this row the terminal-current
# exclusion has no guard of its own and can be deleted silently.
check {BC1b the device-parameter probe tells a terminal current from an operating-point parameter} \
  [list [b_ans ::cadence::_annot_devparams_present] \
        [b_ans ::cadence::_annot_op_cards_off] \
        [b_ans ::cadence::_annot_cause [list 1 {} 1]]] \
  [list 0 1 nocards]

# ---------------------------------------------------------------------------
# BC2 -- ACCEPTANCE 1, AND THE REQUIRED CIW-CHANNEL ROW
# ---------------------------------------------------------------------------
# ⚠ THIS IS THE SINK THE WHOLE SUITE FAMILY HAS BEEN MISSING. 61 assertions in
# tests/headless/test_op_annot.tcl read `xschem get statusmsg`; the sentence the
# user is asking for goes to the CIW pane. This row reads the pane.
# ⚠ AND THE SPY IS ::ciw_echo, NOT ::ase::echo. The remedy fields only survive
# a DIRECT ::xschem::notify -- ase::echo goes through notify_safe, which drops
# -menu and -command -- so a spy renaming ase::echo would see nothing at all on
# the route that actually carries the answer.
# The MENU PATH IS READ FROM THE PRODUCT'S OWN MINT, never typed here: that is
# what makes this row able to tell a derived path from a hardcoded one that
# happens to be spelled right today.
set bc_menu2  [b_ans ::ase::ui::remedy_op_params_menu]
set BC2_LINE  "$BC_NOCARDS Fix: $bc_menu2. CIW command: [list ase::ui::save_op_params_on $bc_key]"
check {BC2 the user's exact case: one press, and the CIW says WHY the values are blank and HOW to fix it} \
  [list [llength [b_c $bc_p1]] [lindex [b_c $bc_p1] 0]] \
  [list 1 [list warn $BC2_LINE]]

# ---------------------------------------------------------------------------
# BC4 -- ACCEPTANCE 2, AND THE WHOLE POINT OF THE ITEM
# ---------------------------------------------------------------------------
# ⚠ A LATCHED MESSAGE PASSES BC2 AND FAILS THE USER. That is exactly what
# happened: the netlist-time nag is latched, correctly, and the user read its
# silence on the second run as the feature being broken. A nag may be
# suppressed. A reply to a direct question may not. Press, press, press -- the
# answer is the same each time, byte for byte.
# ⚠ AND THE THREE PRESSES ARE NOT IN THE SAME STATE, WHICH IS A CONSTRAINT ON
# THE FIX. Press 1 finds nothing attached and LOADS the file; presses 2 and 3
# find it already attached and live. The held status line says so and differs
# between them (row BC5). The CIW line must NOT: it answers "why are these
# values blank", a question about the file's CONTENTS, and the answer to that
# does not change because the file was already open. A cause clause that
# carried the state clause with it would make this row red for a reason that
# has nothing to do with a latch.
check {BC4 pressing 6 again asks the same question, so it gets the same answer -- three presses, three lines} \
  [list [llength [b_c $bc_p1]] [llength [b_c $bc_p2]] [llength [b_c $bc_p3]] \
        [expr {[b_c $bc_p1] eq [b_c $bc_p2] ? 1 : 0}] \
        [expr {[b_c $bc_p2] eq [b_c $bc_p3] ? 1 : 0}] \
        [lindex [b_c $bc_p3] 0]] \
  [list 1 1 1 1 1 [list warn $BC2_LINE]]

# ---------------------------------------------------------------------------
# BC5 -- THE OTHER SINK: A PLAIN XSCHEM USER WITH NO ASE-L WINDOW STILL HEARS IT
# ---------------------------------------------------------------------------
# RULING 0857's shape: the three operating-point chords have always spoken on
# the held status line, and a CIW-only sentence would be invisible to a user
# with no ASE-L window open. So the same cause clause is on the bar too --
# without the remedy fields, which only the pane can render.
# ⚠ THE CAUSE CLAUSE COMES SECOND, AHEAD OF THE RESULTS-FILE CLAUSE, AND THAT
# IS A DECISION. The bar holds 255 bytes and already elides on long paths
# (issue 0639). Putting the answer before "Loaded results from <path>." means a
# long path is what gets cut, not the answer to the question just asked.
# ⚠ AND THE BAR GETS THE SHORT FORM OF THE SENTENCE, WHICH IS THE REPAIR THIS
# ROW WAS FIRST WRITTEN AROUND. The long sentence is 229 bytes against a
# 55-byte mask sentence, so 285 arrived at a 255-byte wall before a file name
# was added at all and the elision landed inside the remedy -- the bar read
# "... Turn on saving..." and never said saving what. Both forms come out of
# `cadence::_annot_cause_msg`; the pane asks for the long one, the bar for the
# short one. This row still renders its expectation THROUGH
# `cadence::_annot_fit`, because the composition is the claim here and what the
# budget then does to it is BC5b's claim -- but press 2 and press 3 now fit
# whole, which is the point.
set bc5_full1 "$BC_M1 $BC_NOCARDS_S[string map [list @P@ $bc_raw] $BC_LOADEDF]"
set bc5_full2 "$BC_M1 $BC_NOCARDS_S$BC_LIVE"
check {BC5 the held status line carries the same answer, inside the 255-byte budget, on all three presses} \
  [list [b_s $bc_p1] [b_s $bc_p2] [b_s $bc_p3] [b_h $bc_p1] [b_h $bc_p3] \
        [expr {[bc_bytes [b_s $bc_p1]] <= 255 ? 1 : 0}] \
        [expr {[bc_bytes [b_s $bc_p3]] <= 255 ? 1 : 0}]] \
  [list [b_ans ::cadence::_annot_fit $bc5_full1] \
        [b_ans ::cadence::_annot_fit $bc5_full2] \
        [b_ans ::cadence::_annot_fit $bc5_full2] 1 1 1 1]

# ---------------------------------------------------------------------------
# BC5b -- THE REMEDY HAS TO SURVIVE THE 255-BYTE WALL, OR THE ONE USER WHO CAN
#         ONLY SEE THE STATUS LINE IS TOLD WHAT IS WRONG AND NOT WHAT TO DO
# ---------------------------------------------------------------------------
# ⚠ MEASURED WHILE WRITING THIS FILE, AND IT WAS A FINDING, NOT A FORMALITY.
# The mask sentence is 55 bytes and the save-cards cause sentence in its LONG
# form is 229, so the two together are 285 -- thirty over the wall before a
# results-file path or a symbol-type clause is added at all. cadence::_annot_fit
# then cut inside the cause and the last thing to go was the last thing
# written: "Turn on saving them, then run the simulation again."
#
# On the CIW that costs nothing, because the pane gets the sentence whole. It
# cost everything to the user RULING 0857 put the status line there for -- a
# plain xschem user with no ASE-L window, whose only sink is the bar. They were
# told their numbers are missing and not one word about the tick that would
# bring them back. That is row A11-13's standard failing on the one sink that
# matters most, and it is exactly the shape of the defect this item exists to
# close: a message that is locally correct and collectively useless.
#
# ⚠ THE WAY OUT TAKEN IS THE SHORT FORM, minted beside the long one in
# `cadence::_annot_cause_msg` the way `xschem::notify` already gives every
# notice a `-short`. The two rejected alternatives are recorded because they
# are what a later reader will reach for: shortening the LONG sentence makes
# the pane, which has room, pay for the bar's budget; putting the cause LAST
# lets the elision eat the answer to the question just asked, which reverses
# this section's own ordering decision.
#
# ⚠ THE ASSERTION IS DELIBERATELY STRONGER THAN "A REMEDY TOKEN SURVIVED".
# That is the standard the shipped line passed while reading "Turn on
# saving...", so it is not on its own a standard worth having. The whole
# sentence must arrive UNCUT -- no elision marker at the end of the line at all
# -- on the presses where nothing but the mask sentence and a state clause is
# competing for the budget.
#
# The remedy set is test_op_annot.tcl section A11's, quoted rather than
# imported because the two files do not share a runtime.
set BC_REMEDIES [list {Run } {Turn on } {Load } {Plot } {try again}]
set bc5b_hit 0
foreach _r $BC_REMEDIES { if {[string first $_r [b_s $bc_p3]] >= 0} { set bc5b_hit 1 } }
check {BC5b the status line still says WHAT TO DO after the 255-byte budget has had its cut} \
  [list [expr {[bc_bytes [b_s $bc_p3]] <= 255 ? 1 : 0}] $bc5b_hit \
        [string match {*...} [b_s $bc_p3]] \
        [expr {[string first $BC_NOCARDS_S [b_s $bc_p3]] >= 0 ? 1 : 0}]] \
  [list 1 1 0 1]

# ---------------------------------------------------------------------------
# BC1c -- THE ORDER OF THE TWO QUESTIONS INSIDE cadence::_annot_cause
# ---------------------------------------------------------------------------
# ⚠ THIS IS THE ONE STATE THAT CAN TELL THE TWO ORDERS APART, AND UNTIL IT
# EXISTED THE ORDER COULD BE FLIPPED EITHER WAY WITH EVERY ROW IN BOTH SUITES
# STILL GREEN. The tickbox says the run saved no device parameters; the file
# says it holds one anyway -- which happens the moment a user unticks the box
# after a run, or switches to a state that has it off while an older results
# file is still attached. Same sheet, same session, same blank rows; the two
# orders answer differently, and only one of them is right.
#
# THE TICKBOX WINS, because it is a MEASUREMENT of the run's own configuration
# and the file probe is an INFERENCE from vector names. A box that reads off
# means the NEXT run will have no device parameters either, so "turn it on and
# run again" is correct advice whatever an older file happens to hold.
#
# The fixture adds `gm` -- a real operating-point parameter, not a terminal
# current -- on top of the four savecurrents vectors, so `_annot_devparams_present`
# genuinely answers 1 here. gds, vgs, vth and vds stay missing, so the rows are
# still blank and the press still has a question to answer.
bc_raw_savecurrents $bc_raw M1 {{gm 1}}
set bc1c_p    [b_press op]
set bc1c_line [lindex [lindex [b_c $bc1c_p] 0] 1]
check {BC1c the save-cards tickbox is asked before the file, so an older file holding one parameter cannot hide it} \
  [list [b_ans ::cadence::_annot_devparams_present] \
        [b_ans ::cadence::_annot_op_cards_off] \
        [b_ans ::cadence::_annot_cause [list 1 {} 1]] \
        [b_hasblank M1] \
        [string first {Some values are blank because this simulation} $bc1c_line]] \
  [list 1 1 nocards 1 0]

# ---------------------------------------------------------------------------
# BC3 -- THE PRINTED COMMAND IS EXECUTABLE AND ADDRESSES THE REGISTERED KEY
# ---------------------------------------------------------------------------
# ⚠ ISSUE 0679 WAS MEASURED ON THIS VERY BENCH, WITH tb_bandgap: the printed
# command named the DESIGN cellview while every session is registered under its
# STATE view, so it addressed a key no session was ever under. It looked
# perfect and did nothing. So this row EXECUTES it -- `uplevel #0`, exactly as
# ciw_exec would -- and then asks the session whether the tick actually landed.
# A string comparison could not have caught 0679 and did not.
# ⚠ IT RUNS LAST OF THIS SECTION, because it turns the gate ON and every row
# above needs it off.
set bc3_msg  [bc_notify_field msg]
set bc3_cmd  [bc_notify_field command]
set bc3_rc   [catch {uplevel #0 $bc3_cmd} bc3_e]
set bc3_gate [b_ans ::ase::state_get [b_ans ::ase::session_state $bc_key] save_op_params {}]
check {BC3 the CIW command the press printed really turns the tick on, for the session the user is actually under} \
  [list $bc3_msg $bc3_cmd $bc3_rc $bc3_gate] \
  [list $BC_NOCARDS [list ase::ui::save_op_params_on $bc_key] 0 1]

# ---------------------------------------------------------------------------
# BC18 -- THE TICK IS ON, THE FILE STILL HAS NO DEVICE NUMBERS, AND THE
#         PASTEABLE COMMAND MUST NOT BE PRINTED
# ---------------------------------------------------------------------------
# ⚠ THE SPLIT BC9 IS NAMED FOR, MEASURED WHERE IT CAN ACTUALLY BE SEEN. BC9's
# sheet has no session at all, so its key is empty and the command branch
# cannot produce anything whatever the rule says -- it passes vacuously with
# respect to the guard it carries. Here a REGISTERED session owns the sheet and
# the key is a real one, so widening the remedy to hand `noparams` the command
# too would print something, and this row is what stops it.
#
# THE STATE IS REACHABLE AND IT IS THE ONE src/ase.tcl:765 CALLS WORSE THAN
# PRINTING NOTHING: BC3 has just turned the tick ON, and the results file still
# attached is the one written before it was. So the file has no device
# parameters, the box already reads on, and handing the user a command that
# turns on a tick that is already on is a wrong direction printed with
# authority. The menu path stays -- the tick exists for everyone and the path
# is true for everyone -- and only the session-addressed command goes.
bc_raw_savecurrents $bc_raw M1
set bc18_p    [b_press op]
set bc18_line [lindex [lindex [b_c $bc18_p] 0] 1]
check {BC18 with the tick already on, the blank-row answer keeps the menu path and drops the pasteable command} \
  [list [b_ans ::ase::op_gate_on [b_ans ::ase::state_get [b_ans ::ase::session_state $bc_key] save_op_params {}]] \
        [b_ans ::cadence::_annot_op_cards_off] \
        [expr {[b_ans ::cadence::_annot_session_key] ne {} ? 1 : 0}] \
        [b_ans ::cadence::_annot_cause [list 1 {} 1]] \
        [llength [b_c $bc18_p]] \
        [string match {*CIW command:*} $bc18_line] \
        [string match "*$bc_menu2*" $bc18_line] \
        [string first $BC_NOPARAMS $bc18_line]] \
  [list 1 0 1 noparams 1 0 1 0]

# ---------------------------------------------------------------------------
# BC19 -- THE POSITIVE TWIN: A RUN THAT WORKED SAYS NOTHING AT ALL
# ---------------------------------------------------------------------------
# ⚠ THE ANTI-NAG CONTROL ON A REAL BENCH, AND BC12 IS NOT IT. BC12's sheet is a
# synthetic one holding a single registered symbol and nothing else -- no
# voltage source, no unregistered type -- so its type list is empty for reasons
# that have nothing to do with the rule under test, and it stays green however
# noisy the surface becomes. EVERY REAL TESTBENCH HAS A VOLTAGE SOURCE. This
# row is the committed cell, the real session, every descriptor parameter
# present in the results file, every row on the schematic populated: the press
# succeeded completely and there is nothing to tell the user.
#
# It went red while this was being repaired. Deleting the gate that used to
# keep the descriptor clause off mixed sheets made `vsource` -- stimulus, never
# a device with an operating-point block -- reachable on every press of every
# testbench, as a WARNING, on a completely correct annotation. The clause is
# right to be reachable; naming stimulus and decoration in it was not. See
# cadence::_annot_skip_types.
#
# ⚠ AND THE ROW IS TWO-SIDED ON PURPOSE. Silence alone would also be satisfied
# by a surface that had stopped speaking altogether, so the second half asserts
# the press really did annotate: no blank rows, and a status line that says so.
bc_raw_savecurrents $bc_raw M1 {{gm 1} {gds 1} {vgs 2} {vth 2} {vds 2}}
set bc19_p [b_press op]
check {BC19 a press that worked says nothing in the CIW, on a bench with a voltage source on it} \
  [list [llength [b_c $bc19_p]] [b_hasblank M1] \
        [b_ans ::cadence::_annot_cause [list 1 {} 0]] \
        [lrange [b_ans ::cadence::_annot_scan 1] 1 2] \
        [string first $BC_M1 [b_s $bc19_p]]] \
  [list 0 0 {} {{} 0} 0]

# ---------------------------------------------------------------------------
# BC20 -- THE SYMBOL TYPES THAT ARE SKIPPED, NAMED ONE BY ONE
# ---------------------------------------------------------------------------
# ⚠ BC19 CAN ONLY SEE `vsource`, BECAUSE THAT IS ALL THE COMMITTED CELL CARRIES.
# The list was measured on the user's own two benches and each entry is there
# for its own reason, so each is asserted by name: dropping any one of them puts
# a decoration, a hierarchy block or an instrument back into a sentence that
# claims to be naming devices it could not find numbers for.
#
#   tb_bandgap_opamp        ->  capacitor isource logo subcircuit vsource
#   sky130_tests/tb_bandgap ->  ammeter logo probe subcircuit vsource
#
# ⚠ `missing` IS IN THE LIST FOR A DIFFERENT REASON AND IT IS THE SHARPER ONE.
# It is not a symbol type at all -- it is xschem's marker for a symbol it could
# not resolve, i.e. a broken library path. Naming it in a sentence about
# operating-point descriptors sends the user off to write one for a problem
# that is a library reference. That is part 2 of issue 0460, filed on
# 2026-08-19 and reachable on every press since the suppression gate went; the
# wrong direction is removed here, and reporting an unresolved symbol in its
# own words remains open.
#
# ⚠ AND THE NEGATIVE HALF IS THE LOAD-BEARING ONE. A skip list that grew until
# it swallowed the passive device types would make the clause unable to carry
# the issue-0906 news it exists for -- a design kit whose devices nobody
# registered a descriptor for. `capacitor` is the measured case: it is still
# named on the user's own tb_bandgap_opamp, and it should be.
set bc20_skip $::cadence::_annot_skip_types
set bc20_in  {}
set bc20_out {}
foreach _t {logo probe ammeter subcircuit vsource isource missing} {
  lappend bc20_in [expr {[lsearch -exact $bc20_skip $_t] >= 0 ? 1 : 0}]
}
foreach _t {nmos pmos vertical_npn resistor capacitor inductor diode npn pnp njfet pjfet} {
  lappend bc20_out [expr {[lsearch -exact $bc20_skip $_t] >= 0 ? 1 : 0}]
}
check {BC20 stimulus, instruments, hierarchy blocks, the logo and an unresolved symbol are skipped, and no device type ever is} \
  [list $bc20_in $bc20_out] \
  [list {1 1 1 1 1 1 1} {0 0 0 0 0 0 0 0 0 0 0}]

# ---------------------------------------------------------------------------
# BC21 -- THE "AND MORE" TRUNCATION IN THE DESCRIPTOR CLAUSE
# ---------------------------------------------------------------------------
# ⚠ AN UNTESTED BRANCH THAT THIS ITEM MADE LIVE. The truncation is older than
# issue 0909 and nothing could reach it: the clause only spoke when NOTHING on
# the sheet was annotatable, which is a state a real design does not reach, and
# a sheet that DID reach it rarely carried five distinct unregistered types.
# Removing that gate put the branch on every press of every real design, where
# five types is ordinary -- the user's own tb_bandgap_opamp scanned five before
# the skip list took four of them out. Measured: the truncation could be
# changed from four to two and both suites stayed green.
#
# Four types is the last whole list; five is the first truncated one; the tail
# is sorted, so the four named are the four the caller passed first.
check {BC21 the descriptor clause names at most four symbol types and says so when it stops} \
  [list [b_ans ::cadence::_annot_types_clause {}] \
        [b_ans ::cadence::_annot_types_clause {aa bb cc dd}] \
        [b_ans ::cadence::_annot_types_clause {aa bb cc dd ee}] \
        [b_ans ::cadence::_annot_types_clause {aa bb cc dd ee ff}]] \
  [list {} \
        {These symbol types have no operating-point values to show: aa, bb, cc, dd.} \
        {These symbol types have no operating-point values to show: aa, bb, cc, dd and more.} \
        {These symbol types have no operating-point values to show: aa, bb, cc, dd and more.}]

# ---------------------------------------------------------------------------
# BC14 -- ACCEPTANCE 4: THE NETLIST-TIME NAG KEEPS ITS LATCH
# ---------------------------------------------------------------------------
# ⚠ GREEN BEFORE AND AFTER, AND ASSERTED HERE RATHER THAN BY REFERENCE. The
# suppression this issue argues against is the one on the ANSWER. The one on
# the NAG is correct and must survive: it is the tool volunteering something
# while the user is busy netlisting, and three identical lines per session
# about one cell is the defect filed as 0636. Same cell, same session, no
# state change: it speaks once and then is quiet.
set bc14_st {}
catch {set bc14_st [ase::state_load $bc_statefile]}
catch {ase::op_cards_nudge_reset}
proc bc14_capture {st} {
  set hits 0
  foreach e [b_ciw [list ase::op_cards_capture $st /tmp/zz0909_nowhere.spice]] {
    if {[string match {*device operating-point parameters*} [lindex $e 1]]} { incr hits }
  }
  return $hits
}
set bc14_1 [bc14_capture $bc14_st]
set bc14_2 [bc14_capture $bc14_st]
set bc14_3 [bc14_capture $bc14_st]
check {BC14 the netlist-time nag still speaks once per cellview per session and is silent after} \
  [list [b_ans ::ase::op_gate_on [b_ans ::ase::state_get $bc14_st save_op_params {}]] \
        $bc14_1 $bc14_2 $bc14_3] \
  [list 0 1 0 0]

# ============================================================================
# SECTION 3 -- THE STRUCTURAL ROWS: WHAT NO BEHAVIOURAL ROW CAN SEE
# ============================================================================

# ---------------------------------------------------------------------------
# BC6 -- UNLATCHED, PINNED IN THE SOURCE
# ---------------------------------------------------------------------------
# ⚠ THIS IS THE ROW A FUTURE LATCH DIES ON, AND IT IS INVISIBLE TO BC4 ONLY IN
# THE SENSE THAT BC4 WOULD ALSO CATCH IT -- until someone latches on a key that
# happens to differ between two presses, or re-arms on a timer, or suppresses
# only in the GUI. The branch's own rule: a guard no behavioural row can see
# reliably needs a structural row. Comment lines are stripped first, so the
# reasoning may name the latch as freely as it likes; the code may not.
set bc6_body [b_bodylines ::cadence::annot_mode]
set bc6_hits {}
if {$bc6_body ne {NOPROC}} {
  foreach l $bc6_body {
    foreach tok {notify_latch -once latch} {
      if {[string first $tok $l] >= 0} { lappend bc6_hits [string trim $l] }
    }
  }
}
check {BC6 the press's own answer is not routed through any suppressor} \
  [list [expr {$bc6_body eq {NOPROC} ? {NOPROC} : 1}] [llength $bc6_hits] [lindex $bc6_hits 0]] \
  [list 1 0 {}]

# ---------------------------------------------------------------------------
# BC13 -- ORDERING: THE PANE IS WRITTEN BEFORE THE HELD STATUS LINE
# ---------------------------------------------------------------------------
# ⚠ WHY THE ORDER MATTERS AND WHY THIS LEG IS STRUCTURAL. When the CIW pane is
# not in front of the user, xschem::notify falls back to sink 3 and writes the
# drawing window's own status field with a SHORT form. Emitting after the
# annotation's `statusmsg -hold` tail would therefore leave notify's short form
# standing where the annotation sentence belongs -- on a real display, for the
# user, and nowhere a headless row can reach: `winfo` is absent under --nogui,
# so notify_statusbar returns 0 and the swap simply does not happen. That is
# exactly why the ordering is asserted in the SOURCE, on both arms, and not
# left to an environment to supply. cadence::_annot_say already uses this
# order; the emit site must too. The pixels themselves owe the user's eyes and
# are recorded as a look debt.
#
# ⚠ AND THIS LEG IS THE ONLY GUARD, ON BOTH ARMS -- MEASURED, not assumed. A
# faithful ordering-only sabotage reddens BC13 alone headless AND on the dev
# display with openbox live. Headless the reason is `winfo`; on a real display
# the reason is different and worth knowing, because it is a property of this
# FILE rather than of the environment: every row here installs a CIW spy that
# always accepts, so xschem::notify never falls through to sink 3 and the swap
# this ordering protects against cannot be provoked. Do not read "runs on both
# arms" as "has a behavioural companion on one of them". It has neither.
set bc13_emit [b_bodyline ::cadence::annot_mode {_annot_ciw}]
set bc13_hold [b_bodyline ::cadence::annot_mode {statusmsg\s+-hold}]
check {BC13 the CIW is written before the held status line, so notify's short form cannot land where the sentence belongs} \
  [list [expr {$bc13_emit ne {NOPROC} && $bc13_emit > 0 ? 1 : 0}] \
        [expr {$bc13_hold ne {NOPROC} && $bc13_hold > 0 ? 1 : 0}] \
        [expr {$bc13_emit ne {NOPROC} && $bc13_hold ne {NOPROC} \
               && $bc13_emit > 0 && $bc13_hold > 0 && $bc13_emit < $bc13_hold ? 1 : 0}]] \
  [list 1 1 1]

# ---------------------------------------------------------------------------
# BC15 -- NO SECOND CONSTRUCTION OF THE REMEDY (INVARIANT I1, RULING D5-4)
# ---------------------------------------------------------------------------
# ⚠ GREEN BEFORE AND AFTER, AND IT IS THE ROW THAT SURVIVES SOMEONE DELETING
# BC2. The menu path must come out of ase::ui::remedy_op_params_menu and the
# command name out of ase::ui::save_op_params_on. Issue 0661 is the measured
# example of a pasted path drifting one word from the menu it names, and 0679
# of a rebuilt key addressing nobody. A copy in this file would be plausible,
# spelled right today, and wrong the first time the label moves.
set bc15_src [file join $repo utils annot_mode.tcl]
check {BC15 the menu path and the pasteable command are read from their own mints, never spelled out here} \
  [list [b_ngrep_code $bc15_src {Save All}] \
        [b_ngrep_code $bc15_src {Save device OP parameters}] \
        [b_ngrep_code $bc15_src {Outputs >}]] \
  [list 0 0 0]

# ---------------------------------------------------------------------------
# BC16 -- THE REMEDY FIELDS TRAVEL AS FIELDS, AND THE FALLBACK CHAIN SURVIVES
# ---------------------------------------------------------------------------
# ⚠ R-0653-d: -menu and -command are DISTINCT FIELDS, not prose baked into the
# message, so a test can EXECUTE the command instead of parsing a sentence --
# which is what BC3 does. cadence::_annot_ciw is the ONE emitter (invariant
# I1), so it is where the fields have to be able to pass through.
# ⚠ LEG 2 IS THE ONE THAT KEEPS ROW V30 OF test_op_annot.tcl TRUE. With
# ::xschem::notify gone the emitter must still fall through to ase::echo, still
# answer 1, and still not raise at its caller -- issue 0857 is about a chord
# that says nothing when it cannot deliver, and an emitter that raises on the
# degraded path reproduces it exactly.
proc bc16_emit {mode} {
  set ::bc16_args NONE ; set ::bc16_echo NONE
  namespace eval ::ase {}
  namespace eval ::xschem {}
  set had_e [expr {[info commands ::ase::echo] ne {}}]
  set had_n [expr {[info commands ::xschem::notify] ne {}}]
  if {$had_e} { rename ::ase::echo ::bc16_sav_e }
  if {$had_n} { rename ::xschem::notify ::bc16_sav_n }
  proc ::ase::echo {msg {tag {}}} { set ::bc16_echo [list $tag $msg] ; return 1 }
  if {$mode eq {withnotify}} {
    proc ::xschem::notify {msg args} { set ::bc16_args [list $msg $args] ; return 1 }
  }
  set rc [catch {::cadence::_annot_ciw ZZ0909MSG warn -menu ZZMENU -command ZZCMD} r]
  catch {rename ::ase::echo {}}
  catch {rename ::xschem::notify {}}
  if {$had_e} { rename ::bc16_sav_e ::ase::echo }
  if {$had_n} { rename ::bc16_sav_n ::xschem::notify }
  return [list $rc $r $::bc16_args $::bc16_echo]
}
check {BC16 the emitter forwards -menu and -command as separate options, and still falls back when the channel is gone} \
  [list [bc16_emit withnotify] [bc16_emit nonotify]] \
  [list [list 0 1 [list ZZ0909MSG [list -tag warn -menu ZZMENU -command ZZCMD]] NONE] \
        [list 0 1 NONE [list warn ZZ0909MSG]]]

# --- teardown ----------------------------------------------------------------
catch {xschem raw clear}
catch {xschem set annot_show 0}

# --- verdict -----------------------------------------------------------------
# ⚠ THE DUAL BANNER IS REQUIRED BY tests/run_regression.tcl's hcases list, which
# this file is registered in. banner_complete needs a WHOLE-LINE "OVERALL: ok"
# as well as the RESULT line; registering a suite there without one reproduces
# the completion-sentinel false red filed four times as 0420 / 0492 / 0629 / 0689.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
