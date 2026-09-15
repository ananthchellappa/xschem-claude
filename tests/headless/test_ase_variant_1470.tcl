# tests/headless/test_ase_variant_1470.tcl -- ISSUE 1470: A BUILD THAT CANNOT DO
# WHAT ASE-L OFFERS WAS NEVER NAMED, AND A COMMAND LINE THAT CRASHES IT GOT NO
# WARNING. PLAN.md Stage 16 ("the ngspice you actually have"), task 1 -- every
# half of the stage that is not a pixel. The Simulators-window row is task 2.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# * A pre-command reading `unset temp` on apt 45.2 -- what the current Ubuntu LTS
#   ships -- ends the run with SIGABRT, rc 134, and the abort does not flush
#   stdio: the log is destroyed and nothing anywhere says why. TRANSCRIBED from
#   evidence/fork-dependencies.md §4.3. ⚠ NO ROW HERE REPRODUCES IT: a deliberate
#   abort of a dpkg-owned binary is apport's reportable case, so section LN drives
#   the linter over STRINGS and starts no simulator.
# * ASE-L measured that apt 45.2 keeps no net name's case, has an unsound `show`
#   printer and misreads two kinds of command line -- and said none of it.
# * An ASE-L run's rawfile never said which case mode wrote it (debt M21): the
#   run sent `-D casemode=<m>` without `-D casemodewrite`, so the header parser's
#   SOURCE 2 could never fire on a file ASE-L caused.
# * A build on the per-device operating-point shape because its dump printer is
#   unsound was told the reason was an all-or-nothing risk (16d).
#
# ============================================================================
# SECTIONS
# ============================================================================
#   VS  the four sentence frames, from HAND-BUILT dicts -- no binary
#   LN  the five linter patterns, over strings -- no binary
#   CS  the two co-simulation file checks -- files only, no binary
#   OT  the `dumpunsound` reason token -- a primed answer, no binary
#   CF  the three conformance rows (D44, D48 twice) over the source text
#   M21 `-D casemodewrite` -- the fork is started ONCE (self-skips without it)
#   EX  the worked sentences from the REAL probe, per binary present
#   ST  the 104 committed .state files round-trip byte for byte
#
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP. NEW AT 57 with all three
# binaries present, both arms. EX1-EX3, M21b and CS4/apt, CS4/fork self-skip,
# uncounted, when their binary or installed tree is absent. The sabotage campaign is in
# doc/claude/ase_analyses_batch/receipts/46-stage-16-deck.md.
#
# Runs on BOTH arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_variant_1470.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_variant_1470.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch variant1470]
catch {test_sim_registry_isolate}

## ⚠ EVERY READER IS TOTAL AND ANSWERS A COMPARABLE VALUE. A row whose extractor
## raises cannot disagree with anything, and `--nogui --pipe` exits 0 on an
## uncaught mid-script error.
proc v_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
## A total wrapper for an extractor that is more than one command -- a `dict
## get` on an answer that may be NOPROC or RAISED must not kill the suite, or a
## sabotage reads as NORESULT instead of as reds by name (S00 and S36 of this
## suite's own campaign did exactly that before this helper existed).
proc v_total {script} {
  if {[catch {uplevel #0 $script} r]} { return "RAISED:$r" }
  return $r
}
proc v_slurp {p} {
  if {[catch {::open $p r} fh]} { return {} }
  set t [read $fh] ; ::close $fh
  return $t
}
proc v_wr {p text {mode {}}} {
  set fh [::open $p w] ; puts -nonewline $fh $text ; ::close $fh
  if {$mode ne {}} { file attributes $p -permissions $mode }
}
proc v_count {hay needle} {
  if {$needle eq {}} { return 0 }
  set n 0 ; set i 0
  while {[set j [string first $needle $hay $i]] >= 0} {
    incr n ; set i [expr {$j + [string length $needle]}]
  }
  return $n
}
## Everything ase::echo said during `script`, as {tag msg} pairs, beside the
## script's own answer. The recorder is intercepted, not the CIW.
proc v_capture {script} {
  set ::v_said {}
  if {![llength [info commands ::ase::echo]]} { return [list NOPROC {}] }
  rename ::ase::echo ::v_saved_echo
  proc ::ase::echo {msg {tag {}}} { lappend ::v_said [list $tag $msg] }
  set rc [catch {uplevel #0 $script} r]
  rename ::ase::echo {}
  rename ::v_saved_echo ::ase::echo
  if {$rc} { set r "RAISED:$r" }
  return [list $r $::v_said]
}
## Hand the capability store an answer for the program in force, WITHOUT
## launching anything. ⚠ The key is ASKED FOR (ase::cap_key), never spelled --
## issue 1371's re-key made a hand-spelled key silently invisible.
proc v_prime {caps} {
  set r [dict get [ase::sim_status ngspice] resolved]
  set ::ase::sim_caps [dict create [ase::cap_key $r {}] \
                        [list stamp [ase::cap_stamp $r] caps $caps]]
  return $r
}
proc ::v_noop {args} { return {} }
proc v_backend {name extra} {
  set h [dict create render_deck ::v_noop run_cmd ::v_noop log_file ::v_noop \
                     result_probe ::v_noop raw_file ::v_noop]
  foreach {k v} $extra { dict set h $k $v }
  return [v_ans ase::register_backend $name $h]
}

## A stand-in simulator that LEAVES A MARK if anything ever starts it.
set MARK [file join $scratch ran.marker]
set STUB [file join $scratch stub_ngspice]
v_wr $STUB "#!/bin/sh\necho ran >> '$MARK'\nexit 0\n" 0755

# ============================================================================
# THE DICT SHAPES -- each the shape the REAL probe answered on 2026-09-15
# (ase::sim_capabilities_path, receipt 46), and section EX re-takes them.
# ============================================================================
set P /zz/bin/ngspice
set AN_ALL   {op dc ac tran noise tf pz sens disto sp pss}
set AN_NOPSS {op dc ac tran noise tf pz sens disto sp}
set D_FORK [dict create known 1 usable 1 appendwrite 1 blanket_op_save 0 \
  hier_op_names 1 casemode_detected {fold preserve distinguish} \
  altshow_op_dump 1 analyses_available $AN_ALL analyses_probed $AN_ALL \
  one_vector_write 1 keyword_case 1 gnd_literal 1 \
  version_line ngspice-46+ build_date {Fri Sep 11 03:44:45 UTC 2026}]
set D_APT [dict merge $D_FORK [dict create casemode_detected fold \
  altshow_op_dump 0 one_vector_write 0 keyword_case 0 gnd_literal 0 \
  version_line ngspice-45.2 build_date {Fri Sep 12 11:58:13 UTC 2025}]]
set D_UP47 [dict merge $D_FORK [dict create casemode_detected fold \
  one_vector_write 0 keyword_case 0 gnd_literal 0 \
  analyses_available $AN_NOPSS build_date {Thu Sep 10 21:51:07 UTC 2026}]]

set W_OP {Its fast dump prints wrong numbers, so operating points are saved one device at a time; no ngspice release has the fix yet.}
set W_TWO {Two kinds of command line are misread by it; ASE-L warns before a run that uses one.}
set W_DOOR {Press Detect in the Simulators window to try again.}
set S_FORK "$P can do everything ASE-L offers."
set S_APT  "$P can do everything ASE-L offers except case-sensitive net names and the fast operating-point dump. $W_OP $W_TWO"
set S_UP47 "$P can do everything ASE-L offers except case-sensitive net names. $W_TWO"

proc v_frame {caps}  { return [v_ans ase::variant_frame ngspice $caps] }
proc v_sent {caps}   { global P ; return [v_ans ase::variant_sentence ngspice $P $caps] }
set VSALL {}
proc v_keep {s} { lappend ::VSALL $s ; return $s }

# ============================================================================
# SECTION VS -- THE FOUR FRAMES, FROM HAND-BUILT DICTS. NO BINARY.
# ============================================================================

check {VS1 nothing measured -- no answer, an empty one, a timed-out one -- is the first frame, which says so and names the door} \
  [list [v_frame {known 0}] [v_frame {}] [v_frame {known 0 unmeasured timeout secs 30}] \
        [v_keep [v_sent {known 0}]]] \
  [list unmeasured unmeasured unmeasured \
        "ASE-L has not measured $P yet. Press Detect in the Simulators window to find out what it can do."]

check {VS2 the fork's shape: measured and nothing missing -- the delta shrinks to nothing} \
  [list [v_frame $D_FORK] [v_keep [v_sent $D_FORK]]] [list complete $S_FORK]

check {VS3 apt 45.2's shape: case-sensitive names and the fast dump are named, the dump's reason and the command-line door follow} \
  [list [v_frame $D_APT] [v_keep [v_sent $D_APT]]] [list missing $S_APT]

check {VS3b stock 47's shape: only case-sensitive names are missing, and its absent PSS is not mentioned} \
  [list [v_frame $D_UP47] [v_keep [v_sent $D_UP47]] \
        [expr {[string first PSS [string toupper [v_sent $D_UP47]]] < 0}]] \
  [list missing $S_UP47 1]

## ⚠ THE FOURTH FRAME. Driven by the ABSENCE the probe reports -- the slow box
## whose budget killed one leg must not be told "can do everything".
set D_PART [dict remove $D_FORK altshow_op_dump]
dict set D_PART unmeasured_keys {altshow_op_dump timeout}
check {VS4 THE FOURTH FRAME: measured, but one measurement did not finish -- never "can do everything"} \
  [list [v_frame $D_PART] [v_keep [v_sent $D_PART]]] \
  [list partial "$P can do everything ASE-L offers, except that one measurement did not finish: the fast operating-point dump. $W_DOOR"]

set D_LEGD_F [dict remove $D_FORK one_vector_write keyword_case gnd_literal]
dict set D_LEGD_F unmeasured_keys {one_vector_write timeout keyword_case timeout gnd_literal timeout}
check {VS4b the slow box on the fork: leg D cut, Band 3 unmeasured, and the frame says which measurement} \
  [list [v_frame $D_LEGD_F] [v_keep [v_sent $D_LEGD_F]]] \
  [list partial "$P can do everything ASE-L offers, except that one measurement did not finish: how it reads two kinds of command line. $W_DOOR"]

## debt M20's slow-box half: the one binary whose leg D matters most, cut.
set D_LEGD_A [dict remove $D_APT one_vector_write keyword_case gnd_literal]
dict set D_LEGD_A unmeasured_keys {one_vector_write timeout keyword_case timeout gnd_literal timeout}
check {VS4c the slow box on apt 45.2: the measured gaps AND the unfinished measurement, in one sentence} \
  [list [v_frame $D_LEGD_A] [v_keep [v_sent $D_LEGD_A]]] \
  [list partial "$P can do everything ASE-L offers except case-sensitive net names and the fast operating-point dump, and one measurement did not finish: how it reads two kinds of command line. $W_OP $W_DOOR"]

set D_TWO [dict remove $D_FORK casemode_detected altshow_op_dump]
dict set D_TWO unmeasured_keys {casemode_detected timeout altshow_op_dump timeout}
check {VS4d two measurements that did not finish are counted and both named} \
  [list [v_frame $D_TWO] [v_keep [v_sent $D_TWO]]] \
  [list partial "$P can do everything ASE-L offers, except that 2 measurements did not finish: which spellings of a net name it keeps and the fast operating-point dump. $W_DOOR"]

## ⚠ A KEY THAT IS SIMPLY ABSENT -- no provenance token at all -- IS STILL NOT
## MEASURED. Reading it as "nothing missing" would be a claim nobody measured.
set D_NOTOK [dict remove $D_FORK casemode_detected]
check {VS4e a key absent with no provenance token is still the fourth frame, and no partial answer ever carries the "can do everything" sentence} \
  [list [v_frame $D_NOTOK] [expr {[v_sent $D_NOTOK] ne $S_FORK}] \
        [expr {[string first $S_FORK [v_sent $D_PART]] < 0}]] \
  {partial 1 1}

set D_NOSP [dict replace $D_FORK analyses_available {op dc ac tran noise tf pz sens disto pss}]
check {VS5 an analysis ASE-L offers and can emit, measured absent, is named -- the analysis clause can disagree} \
  [list [v_frame $D_NOSP] [v_keep [v_sent $D_NOSP]]] \
  [list missing "$P can do everything ASE-L offers except the SP analysis."]

set D_NOPSS [dict replace $D_FORK analyses_available $AN_NOPSS]
check {VS5b PSS is on no row: measured absent, ASE-L does not offer it, so the fork's shape without it still does everything} \
  [list [v_frame $D_NOPSS] [v_sent $D_NOPSS]] [list complete $S_FORK]

check {VS6 a build that keeps case but cannot tell nets apart by case alone is told exactly that} \
  [v_keep [v_sent [dict replace $D_FORK casemode_detected {fold preserve}]]] \
  "$P can do everything ASE-L offers except nets told apart by case alone."

check {VS7 one misread kind of command line is counted as one} \
  [v_keep [v_sent [dict replace $D_FORK keyword_case 0]]] \
  "$P can do everything ASE-L offers. One kind of command line is misread by it; ASE-L warns before a run that uses one."

check {VS8 three gaps join as "A, B and C", in the adapter's order} \
  [v_keep [v_sent [dict replace $D_FORK appendwrite 0 hier_op_names 0 casemode_detected fold]]] \
  "$P can do everything ASE-L offers except more than one analysis in a run, operating-point numbers for devices inside subcircuits and case-sensitive net names."

## ⚠ NO FALLBACK CONTENT (D34-D37). A backend that describes nothing is told
## nothing -- not "can do everything", not "has not been measured".
v_backend vx1470 {}
check {VS9 a backend with no variant_notes hook gets no frame, no sentence and nothing said} \
  [list [v_ans ase::variant_frame vx1470 $D_APT] [v_ans ase::variant_sentence vx1470 $P $D_APT] \
        [v_ans ase::variant_say vx1470 $P $D_APT]] {{} {} {}}

## ⚠ A PROGRAM MEASURED NOT TO BE A SIMULATOR HAS NO VARIANT: ase::cap_report
## says `cap_not_a_simulator` about it, and a list of what it "cannot do" would
## bury that. Found by test_sim_run_profile CS182b, whose stand-in's run log
## gained a fourth-frame sentence before the guard existed.
set D_NOTSIM {known 1 usable 0 appendwrite 0 blanket_op_save 0 hier_op_names 0}
check {VS9b a program measured not to be a simulator gets no frame, no sentence and nothing said} \
  [list [v_frame $D_NOTSIM] [v_sent $D_NOTSIM] [v_ans ase::variant_say ngspice $P $D_NOTSIM]] {{} {} {}}

proc ::v_badnotes {caps} {
  return [list {kind bogus text x} {kind missing text {}} {kind missing} notadict \
               {kind missing text {a gap}} {kind aside text {An aside.}}]
}
v_backend vy1470 {variant_notes ::v_badnotes}
check {VS10 a note of any other shape is dropped, never guessed at} \
  [v_ans ase::variant_sentence vy1470 $P $D_FORK] \
  "$P can do everything ASE-L offers except a gap. An aside."

proc ::v_raisenotes {caps} { error "zz notes broken" }
v_backend vz1470 {variant_notes ::v_raisenotes}
set VS10B [v_capture {list [ase::variant_frame vz1470 $::D_FORK] [ase::variant_sentence vz1470 $::P $::D_FORK]}]
check {VS10b a hook that raises gives NO sentence -- never "can do everything" -- and the defect reaches the CIW once} \
  [list [lindex $VS10B 0] [llength [lindex $VS10B 1]] \
        [string match {*raised: zz notes broken*} [lindex [lindex [lindex $VS10B 1] 0] 1]]] \
  {{{} {}} 2 1}

## D44, BEHAVIOURALLY: swap the one identity string that could tempt a
## comparison, and watch nothing move.
check {VS11 the sentence does not depend on the version string or the build date} \
  [list [expr {[v_sent [dict replace $D_APT version_line ngspice-46+ build_date x]] eq $S_APT}] \
        [expr {[v_sent [dict replace $D_FORK version_line ngspice-45.2]] eq $S_FORK}]] {1 1}

## ⚠ ONLY A REAL SENTENCE COUNTS: a tree without the composer answers NOPROC for
## every one of them, and a words check over NOPROC strings passes vacuously
## (this row did, on the pre-change tree, until the count below existed).
set VS12 {} ; set VSREAL 0
foreach s $VSALL {
  if {$s eq {} || $s eq {NOPROC} || [string match RAISED:* $s]} { continue }
  incr VSREAL
  foreach w {basic 47 46 45 version pss altshow keyword_case gnd_literal casemode appendwrite hier_op unmeasured known} {
    if {[string match -nocase "*$w*" $s]} { lappend VS12 [list $w $s] }
  }
}
check {VS12 not one sentence says "basic", a version number, PSS, or a word out of the code} \
  [list [expr {$VSREAL >= 12}] $VS12] {1 {}}

catch {ase::sim_caps_clear} ; catch {ase::sim_said_clear}
set a1 [v_ans ase::variant_say ngspice $P $D_APT]
set a2 [v_ans ase::variant_say ngspice $P $D_APT]
set a3 [v_ans ase::variant_say ngspice /zz/other/ngspice $D_APT]
set a7 [v_ans ase::variant_say ngspice $P $D_PART]
set said13 [v_ans ase::sim_said]
catch {ase::sim_caps_clear}
set a4 [v_ans ase::variant_say ngspice $P $D_APT]
set a5 [v_ans ase::variant_say ngspice $P $D_FORK]
set a6 [v_ans ase::variant_say ngspice $P {known 0}]
check {VS13 said once per binary per session: again is silent, another binary or a changed answer is said, a cleared cache says it again, and "everything" and "not measured" are never said here} \
  [list [expr {$a1 eq $S_APT}] $a2 [expr {$a3 ne {}}] [expr {$a7 ne {}}] \
        [v_count $said13 $S_APT] [expr {$a4 eq $S_APT}] $a5 $a6] \
  {1 {} 1 1 1 1 {} {}}

catch {test_sim_registry_isolate}
catch {file delete -- $MARK}
v_ans ase::sim_register vstub $STUB
v_ans ase::sim_select vstub
set r14a [v_ans ase::variant_report ngspice]
set m14a [file exists $MARK]
set R [v_prime $D_APT]
set r14b [v_ans ase::variant_report ngspice]
set m14b [file exists $MARK]
check {VS14 the run's door reads the peek: an empty cache says nothing and a primed one says the sentence, and the program is never started} \
  [list $r14a $m14a [expr {$r14b eq [string map [list $P $R] $S_APT]}] $m14b] {{} 0 1 0}

## ⚠ THE WIRING, THROUGH THE REAL RUN DOOR. A stand-in simulator, a primed
## answer, two runs: the sentence reaches the first run's log `notes` and not
## the second's; the linter's warning reaches both, because it is per run.
set VRUN [file join $scratch vrun]
file mkdir $VRUN
set VNL [file join $scratch zzv.spice]
v_wr $VNL "** sch_path: /zzv.sch\n**.subckt zzv\nV1 a 0 1\nR1 a 0 1k\n**.ends\n.end\n"
proc v_runstate {} {
  global VRUN
  set st [ase::state_default]
  dict set st design [dict create lib zzlib cell zzv view schematic]
  dict set st rundir $VRUN
  dict set st simulator ngspice
  dict set st analyses {{type op enabled 1}}
  dict set st pre_commands {{cmd {unset temp}}}
  return $st
}
proc v_dorun {state nl} {
  if {[catch {ase::run_deck $state $nl} id]} { return "RUNRAISED:$id" }
  if {[catch {ase::wait $id} rc]} { return "WAITRAISED:$rc" }
  return $rc
}
catch {ase::sim_caps_clear}
set R [v_prime $D_APT]
catch {ase::sim_said_clear}
set VST [v_runstate]
set LOGP [v_ans ase::backend::ngspice::log_file $VST]
set rc15a [v_dorun $VST $VNL]
set log15a [v_slurp $LOGP]
set rc15b [v_dorun $VST $VNL]
set log15b [v_slurp $LOGP]
set SENT15 [string map [list $P $R] $S_APT]
set LW15 "ase: warning — the pre-command 'unset temp' can crash some ngspice builds and lose the run's whole log. Fix: delete it, or give the variable another value instead."
check {VS15 through ase::run_deck: the first run's log carries the sentence and the second's does not; both carry the quoted line; the stand-in simulator ran twice} \
  [list $rc15a [v_count $log15a "ase: $SENT15"] [v_count $log15a $LW15] \
        $rc15b [v_count $log15b "ase: $SENT15"] [v_count $log15b $LW15] \
        [v_count [v_ans ase::sim_said] $SENT15] [llength [split [string trim [v_slurp $MARK]] "\n"]]] \
  {0 1 1 0 0 1 1 2}

# ============================================================================
# SECTION LN -- THE FIVE PATTERNS, OVER STRINGS. NO BINARY IS STARTED.
# ============================================================================
catch {test_sim_registry_isolate}
proc v_lint {lines caps} {
  set r [v_ans ::ase::backend::ngspice::lint_control_text $lines $caps]
  if {$r eq {NOPROC} || [string match RAISED:* $r]} { return $r }
  set o {}
  foreach n $r { lappend o "[dict get $n index]:[dict get $n pattern]" }
  return $o
}
set D_UNM {known 0}

check {LN1 pattern 1: a line whose command word is unset, in any case, and nothing else} \
  [v_lint {{unset temp} {Unset temp} {set temp=27} {unsetx}} $D_APT] {0:unset 1:unset}

check {LN2 pattern 2: define and undefine, a user's own function} \
  [v_lint {{define c(x) 5} {print c(2)} {undefine c} {DEFINE d(x,y) x}} $D_APT] \
  {0:define 2:define 3:define}

check {LN3 pattern 3: load} \
  [v_lint {{load old.raw} {loadx} {write out.raw all}} $D_APT] {0:load}

## ngspice's OWN delimiters (the pre-fix inp_fix_gnd_name): before gnd a space,
## `(` or `,`; after it a space, `)` or `,`; the first token skipped; lower case.
set G {{echo M7 my gnd rail} {echo v(gnd)} {shell echo "rail gnd here"} {echo x-gnd-y}
       {write /home/u/gnd/x.raw} {echo A7 gnd} {echo my Gnd rail} {print v(gnd)}
       {echo a,gnd,b} {echo tb_gnd_ase.raw}}
check {LN4 pattern 4: a bare gnd in a text argument -- warned when measured 0 AND when unmeasured, silent when measured sound; a path, a trailing gnd, Gnd and print v(gnd) are left alone} \
  [list [v_lint $G $D_APT] [v_lint $G $D_UNM] [v_lint $G $D_LEGD_F] [v_lint $G $D_FORK]] \
  {{0:gnd 1:gnd 2:gnd 8:gnd} {0:gnd 1:gnd 2:gnd 8:gnd} {0:gnd 1:gnd 2:gnd 8:gnd} {}}

set K {{write out.raw ALL} {write out.raw all} {write out.raw v(out) Alli} {echo ALL DONE}
       {print ALL} {wrdata f.txt ALLV} {write ALL.raw}}
check {LN5 pattern 5: a capitalised wildcard keyword on write or wrdata -- warned when measured 0 and unmeasured, silent when sound; echo, print and a file name are left alone} \
  [list [v_lint $K $D_APT] [v_lint $K $D_UNM] [v_lint $K $D_FORK]] \
  {{0:keyword 2:keyword 5:keyword} {0:keyword 2:keyword 5:keyword} {}}

set LN5A [v_ans ::ase::backend::ngspice::lint_control_text $K $D_APT]
set LN5U [v_ans ::ase::backend::ngspice::lint_control_text $K $D_UNM]
check {LN5b the clause says what was measured -- "this simulator" on a measured build, "some ngspice builds" on an unmeasured one -- and the remedy names the word} \
  [v_total {list [string match {*this simulator*} [dict get [lindex $::LN5A 0] clause]] \
        [string match {*some ngspice builds*} [dict get [lindex $::LN5U 0] clause]] \
        [dict get [lindex $::LN5A 1] remedy]}] {1 1 {write it as alli}}

set LN6 [v_ans ::ase::backend::ngspice::lint_control_text {{unset temp} {define c(x) 5} {load a.raw}} $D_FORK]
set LN6P {}
foreach n $LN6 { lappend LN6P [v_ans ase::preflight_policy $D_APT $n] }
check {LN6 patterns 1-3 warn on every binary, the measured-sound fork included, and carry nothing that could license a refusal} \
  [list [v_lint {{unset temp} {define c(x) 5} {load a.raw}} $D_FORK] $LN6P] \
  {{0:unset 1:define 2:load} {warn warn warn}}

set NL0 "** sch_path: /zzl.sch\n**.subckt zzl\nV1 a 0 1\nR1 a 0 1k\n**.ends\n.end\n"
set LST [ase::state_default]
dict set LST design [dict create lib zzlib cell zzl view schematic]
dict set LST rundir [file join $scratch lrun]
dict set LST simulator ngspice
dict set LST analyses {{type op enabled 1}}
dict set LST pre_commands {{cmd {unset temp}} {cmd {echo M7 my gnd rail}} {cmd {write out.raw ALL}}}
set LSTB $LST
set LN7C [v_capture {v_ans ase::preflight_notes $::LST $::NL0}]
set LN7D [v_ans ase::backend::ngspice::render_deck $LST $NL0]
set LN7H {}
foreach want {{unset temp} {echo M7 my gnd rail} {write out.raw ALL}} {
  set n 0
  foreach dl [split $LN7D "\n"] { if {[string trim $dl] eq $want} { incr n } }
  lappend LN7H $n
}
set LN7K [v_total {set k {} ; foreach n [::ase::backend::ngspice::lint_control_text {{unset temp}} $::D_APT] { lappend k [lsort [dict keys $n]] } ; set k}]
check {LN7 IT WARNS AND NEVER REWRITES: three warnings, the state untouched, every line in the rendered deck exactly as typed, and a note has no field a rewritten line could hide in} \
  [list [llength [lindex $LN7C 0]] [expr {$LST eq $LSTB}] $LN7H $LN7K] \
  {3 1 {1 1 1} {{clause index pattern remedy}}}

## ⚠ NON-VACUITY: a clean Commands box gives ZERO notes -- and the same box with
## one bad line added gives exactly one, which proves the clean lines were read.
set CLEAN [list {pre_osdi /pdk/psp103_nqs.osdi} \
  {pre_set auto_bridge_d_out = [ ".model auto_dac dac_bridge(out_low = 0.0 out_high = 1.2)" ]} \
  {set filetype=ascii} {print v(out) i(vdd)} {write out.raw all} \
  {echo done "quoted" \{brace} {* a comment that says unset temp and load x} \
  {setplot tran1} {let x = v(out)*2}]
set LN8S [ase::state_default]
dict set LN8S simulator ngspice
set pcs {} ; foreach c $CLEAN { lappend pcs [dict create cmd $c] }
dict set LN8S pre_commands $pcs
set LN8C [v_capture {v_ans ase::preflight_notes $::LN8S {}}]
check {LN8 NON-VACUITY: a clean Commands box gives zero notes and says nothing -- and one bad line added is the one note} \
  [list [v_lint $CLEAN $D_APT] [lindex $LN8C 0] [llength [lindex $LN8C 1]] \
        [v_lint [concat $CLEAN [list {unset temp}]] $D_APT]] \
  [list {} {} 0 "[llength $CLEAN]:unset"]

set S9 [ase::state_default]
dict set S9 simulator ngspice
dict set S9 pre_commands {{cmd {unset temp}}}
dict set S9 analyses [list {type op enabled 1} \
  [dict create type tran enabled 1 step 1n stop 1u x {{echo M7 my gnd rail}}] \
  [dict create type dc enabled 0 x {{load never.raw}}]]
set NL9 "* nl\nr1 a 0 1k\n.control\nload x.raw\n.endc\nload outside.raw\n.end\n"
set LN9C [v_capture {v_ans ase::preflight_notes $::S9 $::NL9}]
set LN9W [list \
  "ase: warning — the pre-command 'unset temp' can crash some ngspice builds and lose the run's whole log. Fix: delete it, or give the variable another value instead." \
  "ase: warning — the TRAN verbatim line 'echo M7 my gnd rail' has a bare gnd, which some ngspice builds turn into 0. Fix: write it as Gnd." \
  "ase: warning — the netlist .control line 'load x.raw' loads a results file, which can crash some ngspice builds or change how the rest of the run is read. Fix: open the results in the waveform viewer instead."]
set LN9T {}
foreach e [lindex $LN9C 1] { lappend LN9T [lindex $e 0] }
check {LN9 IT REPORTS THE LINE, NOT THE FILE: one quoted line per warning from each of the three sources, a disabled row and lines outside .control are not read, and each warning reached the CIW once} \
  [list [lindex $LN9C 0] $LN9T] [list $LN9W {note note note}]

set RB {}
foreach l [split [info body ::ase::run_deck] "\n"] {
  if {![regexp {^\s*#} $l]} { append RB $l "\n" }
}
set i_pre  [string first {ase::run_precheck $state} $RB]
set i_ln   [string first {ase::preflight_notes $state $netlist_text} $RB]
set i_pg   [string first {ase::preflight_gate $state $netlist_text} $RB]
set i_del  [string first {ase::cosim_clear_artifacts} $RB]
set i_cap  [string first {ase::cap_report $sim} $RB]
set i_vr   [string first {ase::variant_report $sim} $RB]
set i_meta [string first {casenote $casenote} $RB]
check {LN10 STRUCTURAL: the linter runs on the pre-flight pass -- after the precheck, before the gate and before the first delete -- and the sentence right after cap_report, before the record} \
  [list [expr {$i_pre >= 0 && $i_ln > $i_pre}] [expr {$i_pg > $i_ln}] [expr {$i_del > $i_ln}] \
        [expr {$i_cap >= 0 && $i_vr > $i_cap}] [expr {$i_meta > $i_vr}]] {1 1 1 1 1}

## THE L15 TRICK (test_ase_simreg_0931): the gate refuses deterministically, and
## the warning must already have been said with nothing written.
set LRD [file join $scratch lrefused]
set LST11 [ase::state_default]
dict set LST11 design [dict create lib zzlib cell zzr view schematic]
dict set LST11 rundir $LRD
dict set LST11 simulator ngspice
dict set LST11 analyses {{type op enabled 1}}
dict set LST11 pre_commands {{cmd {unset temp}}}
set LNL11 [file join $scratch zzr.spice]
v_wr $LNL11 $NL0
proc v_refused_run {state nl} {
  if {![llength [info commands ::ase::preflight_gate]]} { return NOPROC }
  rename ::ase::preflight_gate ::v_saved_pfg
  proc ::ase::preflight_gate {args} { return -code error "ase: v refuses this run" }
  set rc [catch {ase::run_deck $state $nl}]
  rename ::ase::preflight_gate {}
  rename ::v_saved_pfg ::ase::preflight_gate
  return $rc
}
set LN11C [v_capture {v_refused_run $::LST11 $::LNL11}]
set LN11N 0
foreach e [lindex $LN11C 1] { if {[string match {ase: warning — the pre-command 'unset temp'*} [lindex $e 1]]} { incr LN11N } }
check {LN11 a run the gate refuses has already been warned about the line, and nothing was written into its run folder} \
  [list [lindex $LN11C 0] $LN11N [llength [glob -nocomplain -directory $LRD *]]] {1 1 0}

set NOTE_R {index 0 pattern p clause {can do a thing} remedy {do another} refuse_key zkey}
set NOTE_W {index 0 pattern p clause {can do a thing} remedy {do another}}
check {LN12 D47 as a pure function: refuse only when the licensing key is MEASURED 0; unmeasured, measured 1, absent from a known answer, or no key named -- warn} \
  [list [v_ans ase::preflight_policy {known 1 zkey 0} $NOTE_R] [v_ans ase::preflight_policy {known 1 zkey 1} $NOTE_R] \
        [v_ans ase::preflight_policy {known 0} $NOTE_R] [v_ans ase::preflight_policy {known 1} $NOTE_R] \
        [v_ans ase::preflight_policy {known 1 zkey 0} $NOTE_W]] {refuse warn warn warn warn}

proc ::v_lintr {lines caps} { return [list {index 0 pattern p clause {can do a thing} remedy {do another} refuse_key zkey}] }
v_backend vr1470 {lint_control_text ::v_lintr}
set LST12 [ase::state_default]
dict set LST12 simulator vr1470
dict set LST12 pre_commands {{cmd anything}}
proc v_with_cached {caps script} {
  set ::v_cc $caps
  rename ::ase::sim_caps_cached ::v_saved_cc
  proc ::ase::sim_caps_cached {backend} { return $::v_cc }
  set out [v_capture $script]
  rename ::ase::sim_caps_cached {}
  rename ::v_saved_cc ::ase::sim_caps_cached
  return $out
}
set LN12R [v_with_cached {known 1 zkey 0} {ase::preflight_notes $::LST12 {}}]
set LN12W [v_with_cached {known 0} {ase::preflight_notes $::LST12 {}}]
check {LN12b the policy through the pass: a measured 0 refuses before anything is written, an unmeasured build is warned} \
  [list [lindex $LN12R 0] [lindex $LN12W 0]] \
  [list {RAISED:ase: REFUSED — the pre-command 'anything' can do a thing. Fix: do another. Nothing was generated: no deck, no raw, no log.} \
        [list {ase: warning — the pre-command 'anything' can do a thing. Fix: do another.}]]

set LST13 [ase::state_default]
dict set LST13 simulator vx1470
dict set LST13 pre_commands {{cmd {unset temp}}}
set LN13C [v_capture {v_ans ase::preflight_notes $::LST13 {}}]
check {LN13 a backend with no lint hook gets no linting and no fallback} \
  [list [lindex $LN13C 0] [llength [lindex $LN13C 1]]] {{} 0}

proc ::v_lintraise {lines caps} { error "zz lint broken" }
v_backend vw1470 {lint_control_text ::v_lintraise}
dict set LST13 simulator vw1470
set LN14C [v_capture {v_ans ase::preflight_notes $::LST13 {}}]
check {LN14 a lint hook that raises never stops the run: no warnings, and one defect line on the CIW} \
  [list [lindex $LN14C 0] [llength [lindex $LN14C 1]] [lindex [lindex [lindex $LN14C 1] 0] 0] \
        [string match {*raised: zz lint broken*} [lindex [lindex [lindex $LN14C 1] 0] 1]]] {{} 1 error 1}

# ============================================================================
# SECTION CS -- THE TWO CO-SIMULATION FILE CHECKS. FILES ONLY.
# ============================================================================
## The $sourcepath values are MEASURED (receipt 46): `echo "@@sourcepath=$sourcepath"`
## in a -b deck, fork and apt 45.2 -- quotes and all when read back from echo.
set SP_APT  {. /usr/share/ngspice/scripts /usr/share/ngspice/scripts .}
set SP_FORK {. /home/analog/dev/ngspice/build-ver_50/stage/share/ngspice/scripts}
proc v_sd {s} { return [v_ans ::ase::backend::ngspice::scripts_dir_of $s] }
check {CS1 the parse rule: the first ABSOLUTE element whose basename is scripts -- repeats, a leading dot, echoed quotes and a trailing slash survive it} \
  [list [v_sd $SP_APT] [v_sd $SP_FORK] [v_sd "\"$SP_APT\""] [v_sd "\"$SP_FORK\""] \
        [v_sd {. scripts /opt/lib /opt/ng/scripts/}] [v_sd {}] [v_sd {. /a/scriptsx ./scripts}]] \
  [list /usr/share/ngspice/scripts /home/analog/dev/ngspice/build-ver_50/stage/share/ngspice/scripts \
        /usr/share/ngspice/scripts /home/analog/dev/ngspice/build-ver_50/stage/share/ngspice/scripts \
        /opt/ng/scripts {} {}]

proc v_tree {name vl shim} {
  global scratch
  set d [file join $scratch trees $name]
  file mkdir $d
  if {$vl ne {-}} { v_wr [file join $d vlnggen] $vl }
  if {$shim ne {-}} { file mkdir [file join $d src] ; v_wr [file join $d src verilator_shim.cpp] $shim }
  return $d
}
proc v_cv {d} {
  set v [v_ans ::ase::backend::ngspice::cosim_shim_verdict $d]
  if {[string match RAISED:* $v] || $v eq {NOPROC}} { return $v }
  return [list [dict get $v vcd_link] [dict get $v ctx_lifetime] [llength [dict get $v notes]]]
}
set T_GOOD [v_tree good "set vcd_obj=\"\$objdir/verilated_vcd_c.o\"\n" "    contextp.release();\n"]
set T_BAD  [v_tree bad  "set v_objs=\"\$v_objs\"\n" "    const std::unique_ptr<VerilatedContext> contextp;\n"]
set T_HALF [v_tree half "set vcd_obj=\"\$objdir/verilated_vcd_c.o\"\n" -]
set T_NONE [v_tree none - -]
check {CS2 each check answers 1, 0 or unknown -- a fixed file, a broken file, a missing file -- and only a 0 carries a note} \
  [list [v_cv $T_GOOD] [v_cv $T_BAD] [v_cv $T_HALF] [v_cv $T_NONE] [v_cv {}]] \
  {{1 1 0} {0 0 2} {1 unknown 0} {unknown unknown 0} {unknown unknown 0}}

check {CS3 a broken installation is told the cause and handed the fix: each note has a clause, a remedy and the change itself} \
  [v_total {
    set ns [dict get [::ase::backend::ngspice::cosim_shim_verdict $::T_BAD] notes]
    set o {}
    foreach n $ns {
      lappend o [dict get $n check] [expr {[dict get $n clause] ne {}}] [expr {[dict get $n remedy] ne {}}]
    }
    list $o [string match {*verilated_vcd_c.o*} [dict get [lindex $ns 0] patch]] \
            [string match {*contextp.release();*} [dict get [lindex $ns 1] patch]]
  }] \
  {{vcd_link 1 1 ctx_lifetime 1 1} 1 1}

## ⚠ THE SKIP IS DECIDED ON THE LITERAL DIRECTORY, NEVER ON THE PARSER'S ANSWER:
## a tree whose parser is missing answers NOPROC, and a skip keyed on that would
## wave the absence through (it did, on the pre-change tree, until this was split).
foreach {cstag csp csdir csexp} [list \
    apt  $SP_APT  /usr/share/ngspice/scripts {0 0 2} \
    fork $SP_FORK /home/analog/dev/ngspice/build-ver_50/stage/share/ngspice/scripts {1 1 0}] {
  if {![file isdirectory $csdir]} {
    puts "ok:   CS4/$cstag SKIPPED -- no installed scripts directory at $csdir"
    continue
  }
  set csd [v_sd $csp]
  check "CS4/$cstag the installed tree this machine's $cstag binary names answers as measured, with no process started" \
    [list $csd [v_cv $csd]] [list $csdir $csexp]
}

set CS5 {}
foreach p {cosim_shim_verdict cosim_count scripts_dir_of} {
  ## a MISSING proc reads as a red, never as "starts nothing"
  if {[catch {info body ::ase::backend::ngspice::$p} b]} { set b "NOPROC exec" }
  ## `exec`, or an `open` of a command pipeline -- NOT a bare `|`, which the
  ## `||` of an ordinary condition also contains (the first cut of this row
  ## reddened on exactly that).
  lappend CS5 [regexp {\yexec\y|open\s+"?\|} $b]
}
check {CS5 STRUCTURAL: the three procs start no process -- no exec, no pipe} $CS5 {0 0 0}

# ============================================================================
# SECTION OT -- THE `dumpunsound` REASON TOKEN (16d). A PRIMED ANSWER.
# ============================================================================
proc v_tier {caps} {
  global STUB scratch
  catch {ase::sim_caps_clear} ; catch {ase::sim_clear}
  ase::sim_register vtier $STUB
  ase::sim_select vtier
  v_prime $caps
  set st [ase::state_default]
  dict set st design [dict create lib zzlib cell zzcell view schematic]
  dict set st rundir [file join $scratch orun]
  dict set st analyses {{type op enabled 1}}
  dict set st save_op_params 1
  set d [v_ans ase::op_save_tier $st]
  if {[string match RAISED:* $d] || $d eq {NOPROC}} { return $d }
  return [list [dict get $d tier] [dict get $d reason]]
}
check {OT1 a printer MEASURED unsound gives the per-device shape with its actual reason; unmeasured stays `unsafe`, sound takes the dump, nothing measured stays `unknown`, no subcircuit names stays `nocap`} \
  [list [v_tier $D_APT] [v_tier [dict remove $D_APT altshow_op_dump]] [v_tier $D_FORK] \
        [v_tier {known 0}] [v_tier [dict replace $D_APT hier_op_names 0]]] \
  {{c dumpunsound} {c unsafe} {d dump} {c unknown} {c nocap}}

set WU [v_ans ase::sim_why op_tier_perdevice ngspice /zz unsafe]
set WD [v_ans ase::sim_why op_tier_perdevice ngspice /zz dumpunsound]
set W0 [v_ans ase::sim_why op_tier_perdevice ngspice /zz zzNOSUCHREASON]
set HEAD {This run asked your simulator for each device's operating-point numbers one request at a time.}
set OT2 {}
foreach w {altshow appendwrite hier_op_names known tier dumpunsound 47 version release} {
  if {[string match -nocase "*$w*" $WD]} { lappend OT2 $w }
}
check {OT2 its sentence is its own tail off the shared head -- not unsafe's, not the default -- says what was measured, and uses no code word or version} \
  [list [expr {$WD ne $WU}] [expr {$WD ne $W0}] [expr {[string first $HEAD $WD] == 0}] \
        [string match {*wrong numbers*} $WD] $OT2] {1 1 1 1 {}}

# ============================================================================
# SECTION CF -- THE CONFORMANCE ROWS (shared with Stage 15), OVER THE SOURCE
# ============================================================================
## Code lines only: a line whose first non-blank character is `#` is a comment.
proc v_code {path} {
  set out {} ; set n 0
  foreach l [split [v_slurp $path] "\n"] {
    incr n
    set t [string trim $l]
    if {$t eq {} || [string index $t 0] eq "#"} { continue }
    lappend out [list $n $l]
  }
  return $out
}
## D44: a line that READS version_line's value and applies an ordering operator,
## a version compare or a pattern match to anything on it.
proc cf_d44 {code} {
  set bad {}
  foreach p $code {
    lassign $p n l
    if {![regexp {dict get \S+ version_line|\$\{?version_line\y|caps_get \S+ version_line} $l]} { continue }
    if {[regexp {<|>|\y(lt|gt|le|ge)\y|vcompare|vsatisfies|string compare|string match|lsort} $l]} {
      lappend bad $n
    }
  }
  return $bad
}
## D48: a bare `dict get|exists <dict> <capability key>` anywhere but ase::caps_get.
proc cf_d48 {code keys} {
  set bad {} ; set inget 0
  foreach p $code {
    lassign $p n l
    if {[regexp {^proc ase::caps_get } $l]} {
      set inget 1
    } elseif {$inget && [regexp {^proc } $l]} {
      set inget 0
    }
    if {$inget} { continue }
    foreach k $keys {
      if {[regexp "dict\\s+(get|exists)\\s+\\S+\\s+${k}(\\s|\\\]|\$)" $l]} { lappend bad [list $n $k] }
    }
  }
  return $bad
}
## D48: ase::caps_is under a `!`.
proc cf_notis {code} {
  set bad {}
  foreach p $code {
    lassign $p n l
    if {[regexp {!\s*\[\s*(::)?ase::caps_is\y} $l]} { lappend bad $n }
  }
  return $bad
}
set CAPKEYS [concat [v_ans ase::caps_keys capability] [v_ans ase::caps_keys defect]]
## ⚠ THE SCANNERS ARE FED BOTH THE PLANTED DEFECT AND THE EMPTY CASE FIRST. A
## scanner that finds nothing in a clean tree and nothing in a dirty one is not
## a check (CREW_BRIEF.md, "a guard against absence must itself be tested").
set PLANT [list \
  {1 {  if {[dict get $caps version_line] >= "ngspice-46"} { return 1 }}} \
  {2 {  if {[package vcompare $version_line 46] < 0} {}}} \
  {3 {  set v [dict get $c version_line]}} \
  {4 {  if {![dict exists $out version_line] && [string first {ngspice-} $l] >= 0} {}}} \
  {5 {  set u [dict get $caps keyword_case]}} \
  {6 {  if {![ase::caps_is $c altshow_op_dump 1]} {}}} \
  {7 {  if {! [::ase::caps_is $c usable 1]} {}}} \
  {8 {  set g [ase::caps_get $caps keyword_case]}}]
check {CF0 the three scanners find every planted defect, pass every planted innocent, and find nothing in nothing} \
  [list [cf_d44 $PLANT] [cf_d48 $PLANT $CAPKEYS] [cf_notis $PLANT] \
        [cf_d44 {}] [cf_d48 {} $CAPKEYS] [cf_notis {}]] \
  {{1 2} {{5 keyword_case}} {6 7} {} {} {}}

set ASE [v_code [file join $repo src ase.tcl]]
set WIN [v_code [file join $repo src ase_window.tcl]]
set VLMENTION 0
foreach p $ASE { if {[string first version_line [lindex $p 1]] >= 0} { incr VLMENTION } }
check {CF1 D44: no ordering operator takes version_line as an operand, in either file -- over a source that was really read and really names it} \
  [list [cf_d44 $ASE] [cf_d44 $WIN] [expr {[llength $ASE] > 10000}] [expr {$VLMENTION >= 2}]] \
  {{} {} 1 1}
check {CF2 D48: no bare dict get of a capability key outside ase::caps_get, in either file} \
  [list [cf_d48 $ASE $CAPKEYS] [cf_d48 $WIN $CAPKEYS] [expr {[llength $CAPKEYS] >= 12}]] {{} {} 1}
set CAPISN 0
foreach p $ASE { if {[string first ase::caps_is [lindex $p 1]] >= 0} { incr CAPISN } }
check {CF3 D48: no ase::caps_is under a `!`, in either file -- over a source that calls it} \
  [list [cf_notis $ASE] [cf_notis $WIN] [expr {$CAPISN >= 5}]] {{} {} 1}

# ============================================================================
# SECTION M21 -- `-D casemodewrite` RIDES WITH THE MODE
# ============================================================================
catch {test_sim_registry_isolate}
proc v_flag {mode} {
  global STUB
  catch {ase::sim_clear}
  v_ans ase::sim_register m21$mode $STUB -casemode $mode
  v_ans ase::sim_select m21$mode
  set st [ase::state_default]
  dict set st simulator ngspice
  return [v_ans ase::run_casemode_flag $st]
}
check {M21a a non-fold request carries -D casemodewrite beside the mode, as the classic path always has; fold carries nothing} \
  [list [v_flag preserve] [v_flag fold] [v_flag distinguish]] \
  {{-D casemode=preserve -D casemodewrite} {} {-D casemode=distinguish -D casemodewrite}}

## ⚠ ON THE FORK, THE ONLY BINARY THAT WRITES THE HEADER. Without -D
## casemodewrite this rawfile carries no `Option:` line and the reader answers
## from a weaker source -- measured 2026-09-15, receipt 46.
set FORK /home/analog/dev/ngspice/build-ver_50/src/ngspice
if {![file executable $FORK]} {
  puts "ok:   M21b SKIPPED -- no fork at $FORK"
} else {
  catch {test_sim_registry_isolate}
  v_ans ase::sim_register m21fork $FORK -casemode preserve
  v_ans ase::sim_select m21fork
  set MRD [file join $scratch m21run]
  file mkdir $MRD
  set MST [ase::state_default]
  dict set MST design [dict create lib zzlib cell m21cell view schematic]
  dict set MST rundir $MRD
  dict set MST simulator ngspice
  dict set MST analyses {{type op enabled 1}}
  dict set MST save_all_v 1
  dict set MST save_op_params 0
  set MNL "* m21\nv1 In 0 dc 1\nr1 In OuT 1k\nr2 OuT 0 1k\n.end\n"
  set MDECK [v_ans ase::backend::ngspice::render_deck $MST $MNL]
  set MDP [file join $MRD m21cell_ase.spice]
  v_wr $MDP $MDECK
  set MCMD [v_ans ase::backend::ngspice::run_cmd $MST $MDP]
  set MRAW [v_ans ase::backend::ngspice::raw_file $MST]
  catch {file delete -- $MRAW}
  set mhere [pwd]
  cd $MRD
  catch {exec timeout 60 {*}$MCMD} mout
  cd $mhere
  set MTXT [v_slurp $MRAW]
  set MCM NOREAD
  if {![catch {xschem raw read $MRAW op}]} {
    catch {set MCM [xschem raw casemode -all]}
    catch {xschem raw clear}
  }
  check {M21b on the fork, through ASE-L's own command and deck: the run asks for the header, the rawfile carries it, the names kept their case, and the reader answers from the header} \
    [list [v_count $MCMD casemodewrite] [v_count $MTXT {Option: casemode=preserve}] \
          [v_count $MTXT {v(In)}] $MCM] {1 1 1 {preserve header}}
}

# ============================================================================
# SECTION EX -- THE WORKED SENTENCES, FROM THE REAL PROBE, PER BINARY PRESENT
# ============================================================================
## ⚠ THE ORDINARY CAPABILITY PROBE, which Detect already runs: seven short -b
## decks, none of which crashes any of the three binaries. No linter pattern is
## ever run on a real binary.
set EXBINS [list \
  apt  /usr/bin/ngspice missing $S_APT \
  fork /home/analog/dev/ngspice/build-ver_50/src/ngspice complete $S_FORK \
  up47 /home/analog/.claude/projects/-home-analog-dev-ngspice/workpad/builds/upstream47/src/ngspice missing $S_UP47]
set exn 0
foreach {extag exbin exframe exsent} $EXBINS {
  incr exn
  if {![file executable $exbin]} {
    puts "ok:   EX$exn/$extag SKIPPED -- no binary at $exbin"
    continue
  }
  catch {test_sim_registry_isolate}
  set exc [v_ans ase::sim_capabilities_path ngspice $exbin]
  check "EX$exn/$extag the real probe of $exbin gives the worked sentence -- the same one the hand-built shape gives" \
    [list [v_ans ase::variant_frame ngspice $exc] [v_ans ase::variant_sentence ngspice $exbin $exc]] \
    [list $exframe [string map [list $P $exbin] $exsent]]
}
catch {test_sim_registry_isolate}

# ============================================================================
# SECTION ST -- THE 104 COMMITTED .state FILES, BYTE FOR BYTE
# ============================================================================
source [file join $here state_roundtrip.tcl]
set STR [ase_state_roundtrip $repo]
check {ST1 no state key was added: every committed .state file round-trips byte for byte, and both controls hold} \
  [list [dict get $STR tracked] [dict get $STR bad] [dict get $STR control_disagrees] [dict get $STR control_agrees]] \
  {104 {} 1 1}

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
# THE COMPLETION BANNER (issue 1456): a WHOLE-LINE `OVERALL:` that
# tests/banner_rule.tcl requires, and an explicit exit code as the last statement,
# because `--nogui --pipe` otherwise exits 0 whatever happened.
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
exit [expr {$fail ? 1 : 0}]
