# tests/headless/test_ase_simwin_variant_1471.tcl -- ISSUE 1471: THE SIMULATORS
# WINDOW NEVER SAID WHAT THE PROGRAM IN FRONT OF IT CAN DO, AND NO PAGE SAID WHAT
# WORKS ON WHICH NGSPICE. PLAN.md Stage 16 task 2 -- the pixel half of "the
# ngspice you actually have" (16a's Simulators-window line) and 16e's release note.
#
# ============================================================================
# WHAT GOES WRONG FOR THE USER
# ============================================================================
# * Issue 1470 composed one sentence per program -- what THIS build can and cannot
#   do -- and said it in a run's log only, once per session, and only when
#   something was missing. A user who registers /usr/bin/ngspice under Setup >
#   Simulators…, opens Edit… and presses Detect was told which spellings of a net
#   name it keeps, and nothing about the fast operating-point dump it lacks or the
#   two kinds of command line it misreads -- the window where the question is
#   actually asked had no answer in it.
# * A person deciding whether ASE-L works with the ngspice they already have had
#   no page to read (PLAN §16e).
#
# ============================================================================
# SECTIONS
# ============================================================================
#   WS  the two schema procs the window paints from -- no display, no binary
#   WR  the release note held to its rules -- the file only
#   ST  the 104 committed .state files round-trip byte for byte
#   WG  the row editor itself, on a display: the real menu, the real widgets.
#       WG7 starts the real binaries through Detect -- the ordinary
#       capability probe, which crashes nothing (receipt 46).  WG8 (issue
#       1724) takes the steps one sentence of the terminal-current cure names
#       -- select the entry under Setup > Simulators…, press Edit… and then
#       Detect -- finding each widget by the label the sentence gives it
#
# ⚠ NOTHING HERE STARTS A PROGRAM EXCEPT THROUGH DETECT. Every stand-in program
# writes a MARK file when started, and the backend's probe hook is wrapped with a
# counter for the whole run; rows WS1-WS6 and WG1-WG6 require both to stay at
# zero, and WG5 is the positive control that the counter really counts.
#
# THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP. NEW AT 12 on the headless arm and
# 21 on the display arm with both binaries present; issue 1724 added WG7/v53
# and WG8 to the display arm. Each WG7 row self-skips, uncounted, when its
# binary is absent. The sabotage campaign is in
# doc/claude/ase_analyses_batch/receipts/47-stage-16-gui.md.
#
# Arms:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_simwin_variant_1471.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_simwin_variant_1471.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch simwin1471]

## ⚠ EVERY READER IS TOTAL AND ANSWERS A COMPARABLE VALUE. A row whose extractor
## raises cannot disagree with anything, and `--nogui --pipe` exits 0 on an
## uncaught mid-script error. A missing PROC answers NOPROC, a missing MINT
## NOMINT, a missing WIDGET NOWIDGET -- different words, so a row comparing what
## the window shows against what the mint says cannot go green where neither
## exists.
proc v_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {uplevel #0 [linsert $args 0 $cmd]} r]} { return "RAISED:$r" }
  return $r
}
proc mint {args} {
  if {![llength [info commands [lindex $args 0]]]} { return NOMINT }
  if {[catch {uplevel #0 $args} r]} { return "MINTRAISED:$r" }
  return $r
}
proc v_total {script} {
  if {[catch {uplevel #0 $script} r]} { return "RAISED:$r" }
  return $r
}
proc v_slurp {p} {
  if {[catch {::open $p r} fh]} { return ZZNOFILE }
  fconfigure $fh -encoding utf-8
  set t [read $fh] ; ::close $fh
  return $t
}
proc v_wr {p text {mode {}}} {
  file mkdir [file dirname $p]
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
proc v_nocomment {text} {
  set out {}
  foreach l [split $text "\n"] {
    if {[regexp {^\s*#} $l]} { continue }
    lappend out $l
  }
  return [join $out "\n"]
}
proc ::v_noop {args} { return {} }

# --- the widget side -----------------------------------------------------------
proc wex {w} {
  if {[catch {winfo exists $w} e]} { return 0 }
  return [expr {$e ? 1 : 0}]
}
proc wtext {w} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {$w cget -text} t]} { return NOTEXT }
  return $t
}
proc winv {w args} {
  if {![wex $w]} { return NOWIDGET }
  set rc [catch {$w invoke {*}$args} r]
  catch {update}
  if {$rc} { return "INVRAISED:$r" }
  return OK
}

# ============================================================================
# THE FIXTURE -- stand-in programs that leave a mark, a counted probe door, and
# nothing that reaches the developer's own files
# ============================================================================
set MARK [file join $scratch ran.marker]
proc v_stub {name} {
  global scratch MARK
  set p [file join $scratch bin $name]
  v_wr $p "#!/bin/sh\necho ran >> '$MARK'\nexit 0\n" 0755
  return $p
}
set STUB_M [v_stub ngm]   ;# never primed: nothing is known about it
set STUB_A [v_stub nga]   ;# primed with apt 45.2's measured shape
set STUB_F [v_stub ngf]   ;# primed with the fork's
set STUB_P [v_stub ngp]   ;# primed with an answer one leg short
set STUB_S [v_stub ngs]   ;# primed, then the file changes under it
set STUB_D [v_stub ngd]   ;# Detect's
set MISSING [file join $scratch bin there-is-no-such-file]
set ADIR [file join $scratch bin adir]
file mkdir $ADIR
file delete -force $MISSING

catch {test_sim_registry_isolate}
## THE PROBE'S SCRATCH AREA, AND THE SAVED LIST, GO TO THIS SUITE'S SCRATCH --
## test_ase_simdlg_0937's redirections, for the same two reasons.
set NDSAVE [expr {[info exists ::netlist_dir] ? $::netlist_dir : {ZZUNSET}}]
set LNDSAVE [expr {[info exists ::local_netlist_dir] ? $::local_netlist_dir : {ZZUNSET}}]
set ::local_netlist_dir 0
set ::netlist_dir [file join $scratch simdir]
file mkdir $::netlist_dir
set UCD_HAD [info exists ::USER_CONF_DIR]
set UCD_OLD {}
if {$UCD_HAD} { set UCD_OLD $::USER_CONF_DIR }
set ::USER_CONF_DIR [file join $scratch conf]
file mkdir $::USER_CONF_DIR

## THE ONE DOOR THROUGH WHICH A CAPABILITY PROBE STARTS A PROGRAM, counted for
## the whole run. Renamed, not redefined in place, so the real one comes back
## byte-identical; `HOOK_BODY`, when set, stands in for the probe for one gesture.
set ::HOOKN 0
set ::HOOK_BODY {}
## ⚠ THE REAL ONE IS PARKED INSIDE ITS OWN NAMESPACE. A proc runs in the
## namespace its name is in, so parking it at `::zz_…` made every unqualified
## call in its body resolve against the global namespace -- measured on this
## suite's first display run: the real probe was entered and answered `known 0`,
## and WG7 read an empty line on both binaries.
proc hook_install {} {
  if {![llength [info commands ::ase::backend::ngspice::capabilities]]} { return NOHOOK }
  if {[llength [info commands ::ase::backend::ngspice::zz_w1471_caps]]} { return ALREADY }
  rename ::ase::backend::ngspice::capabilities ::ase::backend::ngspice::zz_w1471_caps
  proc ::ase::backend::ngspice::capabilities {exe exeargs workdir} {
    incr ::HOOKN
    if {$::HOOK_BODY ne {}} { return [uplevel #0 $::HOOK_BODY] }
    return [::ase::backend::ngspice::zz_w1471_caps $exe $exeargs $workdir]
  }
  return OK
}
proc hook_remove {} {
  if {![llength [info commands ::ase::backend::ngspice::zz_w1471_caps]]} { return NOTINSTALLED }
  rename ::ase::backend::ngspice::capabilities {}
  rename ::ase::backend::ngspice::zz_w1471_caps ::ase::backend::ngspice::capabilities
  return OK
}
set HOOKINST [hook_install]
proc zero {} { set ::HOOKN 0 ; file delete -force $::MARK }

## Hand the capability store an answer for a program WITHOUT starting it. ⚠ The
## key and the stamp are ASKED FOR (ase::cap_key, ase::cap_stamp), never spelled.
proc prime {path caps} {
  set p [file normalize $path]
  dict set ::ase::sim_caps [ase::cap_key $p {}] \
    [list stamp [ase::cap_stamp $p] caps $caps]
  return $p
}

# ============================================================================
# THE DICT SHAPES -- test_ase_variant_1470's, each the shape the REAL probe
# answered on 2026-09-15 (receipt 46); WG7 re-takes two of them from the binaries.
# ============================================================================
set AN_ALL {op dc ac tran noise tf pz sens disto sp pss}
## `hier_probes` (issue 1724) is in both, as the real probe answered on
## 2026-11-20: 1 for the complete answer D_FORK stands for, 0 on apt 45.2.
set D_FORK [dict create known 1 usable 1 appendwrite 1 blanket_op_save 0 \
  hier_op_names 1 casemode_detected {fold preserve distinguish} \
  altshow_op_dump 1 hier_probes 1 analyses_available $AN_ALL analyses_probed $AN_ALL \
  one_vector_write 1 keyword_case 1 gnd_literal 1 version_line ngspice-46+]
set D_APT [dict merge $D_FORK [dict create casemode_detected fold \
  altshow_op_dump 0 hier_probes 0 one_vector_write 0 keyword_case 0 gnd_literal 0 \
  version_line ngspice-45.2]]
set D_PART [dict remove $D_FORK altshow_op_dump]

set W_OP {Its fast dump prints wrong numbers, so operating points are saved one device at a time; no ngspice release has the fix yet.}
set W_TWO {Two kinds of command line are misread by it; ASE-L warns before a run that uses one.}
set W_DOOR {Press Detect in the Simulators window to try again.}
proc s_fork {p} { return "$p can do everything ASE-L offers." }
proc s_apt {p} {
  return "$p can do everything ASE-L offers except case-sensitive net names, the fast operating-point dump and terminal currents of subcircuit pins or of devices inside subcircuits. $::W_OP $::W_TWO"
}
## The fork's older ver_50 build (issue 1724): complete but for terminal
## currents below the top level.
proc s_v50 {p} {
  return "$p can do everything ASE-L offers except terminal currents of subcircuit pins or of devices inside subcircuits."
}
proc s_part {p} {
  return "$p can do everything ASE-L offers, except that one measurement did not finish: the fast operating-point dump. $::W_DOOR"
}
proc s_unmeas {p} {
  return "ASE-L has not measured $p yet. Press Detect in the Simulators window to find out what it can do."
}

# ============================================================================
# SECTION WS -- WHAT THE WINDOW PAINTS, ASKED OF THE SCHEMA. NO DISPLAY, NO BINARY.
# ============================================================================

## Two stand-in backends: one that could describe itself but has no way to try a
## program, one that can try a program but describes nothing.
set BH [dict create render_deck ::v_noop run_cmd ::v_noop log_file ::v_noop \
                    result_probe ::v_noop raw_file ::v_noop]
v_ans ase::register_backend vnp1471 \
  [dict merge $BH [dict create variant_notes ::ase::backend::ngspice::variant_notes]]
v_ans ase::register_backend vnh1471 [dict merge $BH [dict create capabilities ::v_noop]]

zero
set WS1V [list [v_ans ase::variant_status ngspice {} {}] \
               [v_ans ase::variant_status ngspice $MISSING {}] \
               [v_ans ase::variant_status ngspice $ADIR {}] \
               [v_ans ase::variant_status vnp1471 $STUB_M {}] \
               [v_ans ase::variant_status vnh1471 $STUB_M {}]]
set WS1OWN 1
foreach s [list [v_ans ase::casemode_status ngspice {} {}] \
                [v_ans ase::casemode_status ngspice $MISSING {}] \
                [v_ans ase::casemode_status ngspice $ADIR {}] \
                [v_ans ase::casemode_status vnp1471 $STUB_M {}]] {
  if {$s eq {} || [string match NOPROC* $s] || [string match RAISED* $s]} { set WS1OWN 0 }
}
check {WS1 no location, no program at it, a folder, a simulator with no way to try a program, and one that describes nothing: the line says NOTHING -- and for the first four the status line above it has its own sentence already} \
  [list {*}$WS1V $WS1OWN $::HOOKN [file exists $MARK]] \
  [list {} {} {} {} {} 1 0 0]

zero
set WS2 [v_ans ase::variant_status ngspice $STUB_M {}]
check {WS2 a program nobody has measured gets the first frame, word for word the mint's, and asking starts nothing} \
  [list $WS2 [expr {$WS2 eq [mint ase::sim_why variant_unmeasured ngspice $STUB_M]}] \
        [v_ans ase::sim_caps_have_path ngspice $STUB_M {}] $::HOOKN [file exists $MARK]] \
  [list [s_unmeas $STUB_M] 1 0 0 0]

prime $STUB_A $D_APT
prime $STUB_F $D_FORK
prime $STUB_P $D_PART
zero
set WS3A [v_ans ase::variant_status ngspice $STUB_A {}]
set WS3F [v_ans ase::variant_status ngspice $STUB_F {}]
set WS3P [v_ans ase::variant_status ngspice $STUB_P {}]
check {WS3 with an answer in hand the line is ase::variant_sentence's: apt 45.2's shape names its gaps, the fork's shape reads the COMPLETE sentence (decision C2), a shape one leg short reads the fourth frame -- and nothing is started to say any of them} \
  [list $WS3A $WS3F $WS3P \
        [expr {$WS3P eq [mint ase::variant_sentence ngspice $STUB_P $D_PART]}] \
        $::HOOKN [file exists $MARK]] \
  [list [s_apt $STUB_A] [s_fork $STUB_F] [s_part $STUB_P] 1 0 0]

prime $STUB_S $D_FORK
zero
set WS4A [v_ans ase::variant_status ngspice $STUB_S {}]
v_wr $STUB_S "#!/bin/sh\necho ran >> '$MARK'\nexit 0\n# rebuilt\n" 0755
set WS4B [v_ans ase::variant_status ngspice $STUB_S {}]
check {WS4 an answer about the file as it WAS is not an answer about it now: once the program changes, the line goes back to "not measured" -- and still starts nothing} \
  [list $WS4A $WS4B $::HOOKN [file exists $MARK]] \
  [list [s_fork $STUB_S] [s_unmeas $STUB_S] 0 0]

## ⚠ THE AFTER-DETECT DOOR IS NOT THE PEEK. An answer that is not remembered
## (every `known 0`) reads back through the peek as "never measured" -- the last
## term shows the peek WOULD say the first frame -- and telling the user to press
## Detect just after they pressed it is issue 1371's refuted sentence.
zero
set WS5 [list \
  [v_ans ase::variant_detected ngspice $STUB_D {known 0}] \
  [v_ans ase::variant_detected ngspice $STUB_D {known 0 unmeasured timeout secs 30}] \
  [v_ans ase::variant_detected ngspice $STUB_D {known 0 unmeasured noplace}] \
  [v_ans ase::variant_detected ngspice $STUB_D [dict replace $D_FORK usable 0]] \
  [v_ans ase::variant_detected ngspice {} $D_FORK] \
  [v_ans ase::variant_detected ngspice $STUB_D $D_FORK] \
  [v_ans ase::variant_detected ngspice $STUB_D $D_APT] \
  [v_ans ase::variant_detected ngspice $STUB_D $D_PART] \
  [expr {[v_ans ase::variant_status ngspice $STUB_D {}] eq [s_unmeas $STUB_D]}] \
  $::HOOKN [file exists $MARK]]
check {WS5 after Detect the line describes the answer Detect got: nothing for a probe that did not answer, found nowhere to work or met a program that is not a simulator (the status line says which), the sentence for one that did -- never "press Detect" read back through the peek} \
  $WS5 [list {} {} {} {} {} [s_fork $STUB_D] [s_apt $STUB_D] [s_part $STUB_D] 1 0 0]

## ⚠ THE WINDOW MUST NOT SILENCE THE RUN LOG. ase::variant_say records what it
## said; a window that went through it would stop a run ever saying the sentence
## about a program the user had merely looked at. Last term: the record really
## is what this row reads.
catch {ase::sim_caps_clear}
prime $STUB_A $D_APT
## ⚠ AND THE FIRST TERM IS WHAT KEEPS IT FROM PASSING ON NOTHING: on a tree
## without the two procs neither can record anything either (measured -- the
## untouched tree left this row green until the term was added).
set WS6N0 [v_total {dict size $::ase::variant_said}]
set WS6ST [v_ans ase::variant_status ngspice $STUB_A {}]
set WS6DT [v_ans ase::variant_detected ngspice $STUB_A $D_APT]
set WS6N1 [v_total {dict size $::ase::variant_said}]
set WS6SAY [v_ans ase::variant_say ngspice $STUB_A $D_APT]
set WS6N2 [v_total {dict size $::ase::variant_said}]
check {WS6 looking at a program in the window records nothing as said, so the run log still says the sentence the first time a run meets that program} \
  [list [expr {$WS6ST eq [s_apt $STUB_A] && $WS6DT eq [s_apt $STUB_A]}] \
        $WS6N0 $WS6N1 [expr {$WS6SAY eq [s_apt $STUB_A]}] $WS6N2] {1 0 0 1 1}

## ONE COMPOSER, AND IT IS NOT IN THE WINDOW (D34-D37, ruling D5-4). Comments are
## stripped for the code terms; the two phrase terms read the raw file, so a
## frame's words cannot hide in the window even as a comment. First term: the
## scanner really read the file.
set WINF [file join $repo src ase_window.tcl]
set WRAW [v_slurp $WINF]
set WSRC [v_nocomment $WRAW]
check {WS7 STRUCTURAL the window paints the schema's answer and composes none: it asks ase::variant_status and ase::variant_detected, has one writer of the line, never touches the run log's door or the frames, and types none of the frames' words} \
  [list [expr {[v_count $WSRC {ase::casemode_status}] >= 1}] \
        [expr {[v_count $WSRC {ase::variant_status}] >= 2}] \
        [expr {[v_count $WSRC {ase::variant_detected}] >= 1}] \
        [v_count $WSRC {.variant configure}] \
        [v_count $WSRC variant_say] [v_count $WSRC variant_report] \
        [v_count $WSRC variant_sentence] [v_count $WSRC variant_notes] \
        [v_count $WSRC variant_frame] [v_count $WSRC {sim_why variant_}] \
        [v_count $WRAW {ASE-L offers}] [v_count $WRAW {has not measured}]] \
  {1 1 1 1 0 0 0 0 0 0 0 0}

# ============================================================================
# SECTION WR -- THE RELEASE NOTE, HELD TO ITS RULES. THE FILE ONLY.
# ============================================================================
## doc/claude/ase_analyses_batch/RELEASE_NOTE.md. Between `note:begin` and
## `note:end` is the text that would ship; every claim in it carries an [E<n>]
## tag, and the table after `note:end` is the evidence for each. These rows are
## the mechanical half of "states nothing unmeasured": a claim with no evidence
## row, an evidence row naming no file that exists, and the four sentences PLAN
## §16a and receipt 46 C8 forbid.
set NOTEF [file join $repo doc claude ase_analyses_batch RELEASE_NOTE.md]
set NOTE [v_slurp $NOTEF]
set NB [string first {<!-- note:begin -->} $NOTE]
set NE [string first {<!-- note:end -->} $NOTE]
set NOTEBODY {}
set EVID {}
if {$NB >= 0 && $NE > $NB} {
  set NOTEBODY [string range $NOTE $NB $NE]
  set EVID [string range $NOTE $NE end]
}
proc tags_in {text re} {
  set out {}
  foreach {all t} [regexp -all -inline $re $text] { lappend out $t }
  return [lsort -unique -dictionary $out]
}
set TN [tags_in $NOTEBODY {\[(E[0-9]+)\]}]
set TE [tags_in $EVID {\n\| (E[0-9]+) \|}]
set NROW 0 ; set NROWOK 0
foreach r [regexp -all -inline {\n\| E[0-9]+ \|[^\n]*} $EVID] {
  incr NROW
  set any 0
  foreach {all p} [regexp -all -inline {`([A-Za-z0-9_./-]+\.(?:md|tcl|png))`} $r] {
    foreach cand [list [file join $repo $p] \
                       [file join $repo doc claude ase_analyses_batch $p]] {
      if {[file isfile $cand]} { set any 1 }
    }
  }
  if {$any} { incr NROWOK }
}
check {WR1 the release note exists; every claim it makes carries a tag, every tag has an evidence row, every evidence row is cited, and every evidence row names a file that exists} \
  [list [expr {$NOTE ne {ZZNOFILE}}] [v_count $NOTE {<!-- note:begin -->}] \
        [v_count $NOTE {<!-- note:end -->}] [expr {$NOTEBODY ne {}}] \
        [expr {[llength $TN] >= 12}] [expr {$TN eq $TE}] \
        [expr {$NROW == [llength $TE]}] [expr {$NROW > 0 && $NROWOK == $NROW}]] \
  {1 1 1 1 1 1 1 1}

## ⚠ A SCANNER THAT CANNOT FIRE PROVES NOTHING. Each pattern is also run over a
## planted sentence that breaks it, and must match there.
set FORBID [list \
  basic     {(?i)\mbasic\M} \
  pss       {(?i)\mpss\M} \
  release   {(?i)ngspice[- ]?4[6-9]} \
  number    {\m4[6-9](\.[0-9]+)?\M} \
  future    {(?i)(\mfixe[sd]\M|will fix|gets? the [a-z -]+ back|upgrad|next release|future release|newer release)} \
  floor     {(?i)(>=|≥|\mor newer\M|\mor later\M|\mand newer\M|\mand later\M|at least ngspice|minimum version|version floor)}]
set PLANT [dict create \
  basic   {There is a basic mode for stock builds.} \
  pss     {PSS works on 45.2.} \
  release {ngspice 47 gets the fast path back.} \
  number  {That is fixed in 47.} \
  future  {Upgrading to a newer ngspice will make this faster.} \
  floor   {ASE-L needs ngspice 44 or newer.}]
set WR2HIT {} ; set WR2CTL {}
foreach {nm re} $FORBID {
  lappend WR2HIT $nm [regexp -all -- $re $NOTEBODY]
  lappend WR2CTL $nm [expr {[regexp -- $re [dict get $PLANT $nm]] ? 1 : 0}]
}
check {WR2 the note never says "basic", never mentions PSS, never names an ngspice newer than any release, never says a future version fixes anything, and states no version floor -- and each of those scanners fires on a planted sentence} \
  [list [expr {$NOTEBODY ne {}}] $WR2HIT $WR2CTL] \
  [list 1 {basic 0 pss 0 release 0 number 0 future 0 floor 0} \
          {basic 1 pss 1 release 1 number 1 future 1 floor 1}]

set SB [string first {<!-- support:begin -->} $NOTEBODY]
set SE [string first {<!-- support:end -->} $NOTEBODY]
set SUP {}
if {$SB >= 0 && $SE > $SB} { set SUP [string range $NOTEBODY $SB $SE] }
check {WR3 the support sentence (R11, Option C) is inside the note, once, and promises a TESTED SET named as binaries -- the distribution's, stock upstream, our own -- and refuses nothing for being old} \
  [list [v_count $NOTEBODY {<!-- support:begin -->}] [expr {$SUP ne {}}] \
        [expr {[string first {your distribution ships} $SUP] >= 0}] \
        [expr {[string first {stock upstream} $SUP] >= 0}] \
        [expr {[string first {our own build} $SUP] >= 0}] \
        [expr {[string first {not refused} $SUP] >= 0}]] \
  {1 1 1 1 1 1}

check {WR4 the dump's missing fix is said in the measured words the window and the run log use, and neither of the two sentences receipt 46 C8 forbids is in the note} \
  [list [expr {[string first {no ngspice release has the fix yet} $NOTEBODY] >= 0}] \
        [v_count $NOTEBODY {gets the fast path back}] \
        [v_count $NOTEBODY {upgrading to ngspice 47}]] \
  {1 0 0}

# ============================================================================
# SECTION ST -- THE 104 COMMITTED .state FILES, BYTE FOR BYTE
# ============================================================================
source [file join $here state_roundtrip.tcl]
set STR [v_total {ase_state_roundtrip $::repo}]
## ⚠ A FLOOR, NOT AN EQUALITY -- the same change, and the same measurement, as
## test_ase_variant_1470's ST1: with no `.git` the corpus comes from the
## filesystem (issue 1485) and includes the tester's own saved benches, so one
## copied `.state` reddened this row at `{105 {} 1 1}` while a clone stayed
## green. `bad` stays exactly empty, so nothing is weakened.
check {ST1 no state key was added: every committed .state file round-trips byte for byte, and both controls hold} \
  [v_total {list [expr {[dict get $::STR tracked] >= 104}] [dict get $::STR bad] \
                 [dict get $::STR control_disagrees] [dict get $::STR control_agrees]}] \
  {1 {} 1 1}

# ============================================================================
# SECTION WG -- THE ROW EDITOR, ON A DISPLAY
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set sch_text {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 420 -330 600 -330 {}
N 380 -300 380 -330 {}
N 380 -330 250 -330 {}
N 250 -270 600 -270 {}
N 420 -300 420 -270 {}
C {sky130_fd_pr/nfet_01v8} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1}
C {devices/vsource} 250 -300 0 0 {name=V2 value=1.8}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 500 -330 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -330 0 0 {name=lG lab=G}
}
  v_wr [file join $scratch aselib varcell schematic varcell.sch] $sch_text
  v_wr [file join $scratch library.defs] \
    "DEFINE aselib [file join $scratch aselib]\nDEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]\nDEFINE devices [file join $repo xschem_libs_newsym devices]\n"
  set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
  set ::library_registry_defs_only 1
  set ::XSCHEM_LIBRARY_PATH {}
  set FIXOK 1
  set top {}
  set key {}
  if {[catch {
    library_new_view aselib varcell ngspice_state1 ngspice_state1
    set spath [xschem cellview_path aselib/varcell ngspice_state1]
    if {$spath eq {}} { error "state view did not resolve" }
    set key [ase::session_key aselib varcell ngspice_state1]
    ase::session_open $key [file normalize $spath]
    set st [ase::session_state $key]
    dict set st rundir [file normalize [file join $scratch run]]
    ase::session_update $key $st
    ase::session_save $key
    ase::session_close $key
    if {[ase::open_state aselib varcell ngspice_state1] != 1} { error "the session window did not open" }
    update
    set top [ase::ui::window_for $key]
    if {$top eq {} || ![winfo exists $top]} { error "no session window" }
  } fixerr]} {
    set FIXOK 0
    puts "FIXTURE ERROR: $fixerr"
  }
  check {WG0 the fixture: a real library, cell and simulation-state view, and its session window is up} \
    [list $FIXOK $HOOKINST] {1 OK}

  if {$FIXOK} {
    ## THROUGH THE REAL MENU AND THE REAL BUTTON, the way a user gets there.
    proc open_editor {top row} {
      catch {destroy $top.simrow}
      catch {destroy $top.simdlg}
      winv $top.mb.setup "Simulators…"
      catch {$top.simdlg.tv selection set $row}
      catch {update}
      winv $top.simdlg.btns.edit
      return [wex $top.simrow]
    }
    ## Type into the Program field and leave it -- the gesture the status line
    ## (and now the line beneath it) is bound to.
    proc retype {w text} {
      if {![wex $w]} { return NOWIDGET }
      $w delete 0 end
      if {$text ne {}} { $w insert 0 $text }
      catch {update}
      event generate $w <FocusOut> -detail NotifyAncestor
      catch {update}
      return OK
    }

    # --- WG1 / WG2: WHERE THE LINE IS, AND OPENING STARTS NOTHING ----------
    catch {test_sim_registry_isolate}
    v_ans ase::sim_register wg1 $STUB_M
    zero
    set WG1OPEN [open_editor $top 0]
    set WG1 [v_total {
      set gs [grid info $::top.simrow.status]
      set gv [grid info $::top.simrow.variant]
      set gb [grid info $::top.simrow.btns]
      list [winfo class $::top.simrow.variant] \
           [expr {[dict get $gv -row] == [dict get $gs -row] + 1}] \
           [expr {[dict get $gv -column] == [dict get $gs -column]}] \
           [expr {[dict get $gv -columnspan] == [dict get $gs -columnspan]}] \
           [expr {[$::top.simrow.variant cget -wraplength] == [$::top.simrow.status cget -wraplength]}] \
           [expr {[dict get $gb -row] > [dict get $gv -row]}]
    }]
    check {WG1 the row editor has one new line, a label directly beneath the case-mode status line, spanning and wrapping as that line does, above the buttons} \
      [list $WG1OPEN $WG1] {1 {Label 1 1 1 1 1}}

    set WG2V [wtext $top.simrow.variant]
    set WG2S [wtext $top.simrow.status]
    check {WG2 opening Setup > Simulators… and Edit… on a program nobody has measured starts NOTHING -- the probe door is never entered and the program leaves no mark -- and the new line names the door, beneath a status line that is still casemode_status's} \
      [list $WG2V [expr {$WG2V eq [mint ase::variant_status ngspice $STUB_M {}]}] \
            [expr {$WG2S ne {} && $WG2S eq [mint ase::casemode_status ngspice $STUB_M {}]}] \
            [v_ans ase::sim_caps_have_path ngspice $STUB_M {}] $::HOOKN [file exists $MARK]] \
      [list [s_unmeas $STUB_M] 1 1 0 0 0]

    # --- WG3: TWO PROGRAMS, TWO SENTENCES --------------------------------------
    catch {test_sim_registry_isolate}
    v_ans ase::sim_register apt45 $STUB_A
    v_ans ase::sim_register fork $STUB_F
    prime $STUB_A $D_APT
    prime $STUB_F $D_FORK
    zero
    open_editor $top 0
    set WG3A [wtext $top.simrow.variant]
    open_editor $top 1
    set WG3F [wtext $top.simrow.variant]
    check {WG3 two registry entries: apt 45.2's shape names its two gaps and its two asides, the fork's shape reads the complete sentence and nothing else (decision C2) -- and neither editor started anything} \
      [list $WG3A $WG3F [expr {$WG3A eq [mint ase::variant_sentence ngspice $STUB_A $D_APT]}] \
            [expr {[string first except $WG3F] < 0}] $::HOOKN [file exists $MARK]] \
      [list [s_apt $STUB_A] [s_fork $STUB_F] 1 1 0 0]

    # --- WG4: THE FOURTH FRAME ---------------------------------------------
    catch {test_sim_registry_isolate}
    v_ans ase::sim_register part $STUB_P
    prime $STUB_P $D_PART
    zero
    open_editor $top 0
    set WG4 [wtext $top.simrow.variant]
    check {WG4 an answer with a measurement that did not come back shows the fourth frame, never "can do everything" -- and names Detect as the way to try again} \
      [list $WG4 [expr {$WG4 eq [mint ase::variant_sentence ngspice $STUB_P $D_PART]}] \
            [v_ans ase::variant_frame ngspice $D_PART] $::HOOKN] \
      [list [s_part $STUB_P] 1 partial 0]

    # --- WG5: DETECT -------------------------------------------------------
    ## The probe is stood in for (HOOK_BODY), so the answer is chosen; the stand-in
    ## reads the line at the instant it is entered, which is the only place "it
    ## was emptied before the launch" is a fact rather than a reading of the source.
    ## THE POSITIVE CONTROL for every zero above: Detect enters the counted door.
    catch {test_sim_registry_isolate}
    v_ans ase::sim_register det $STUB_D
    zero
    open_editor $top 0
    set WG5BEFORE [wtext $top.simrow.variant]
    set ::ZZ_VW $top.simrow.variant
    set ::ZZ_SEEN ZZNOTRUN
    set ::HOOK_BODY {set ::ZZ_SEEN ZZNOLABEL ; catch {set ::ZZ_SEEN [$::ZZ_VW cget -text]} ; set ::D_FORK}
    winv $top.simrow.detect
    set WG5N1 $::HOOKN
    set WG5SEEN $::ZZ_SEEN
    set WG5AFTER [wtext $top.simrow.variant]
    catch {ase::sim_caps_clear}
    set ::TO {known 0 unmeasured timeout secs 30}
    set ::HOOK_BODY {set ::TO}
    winv $top.simrow.detect
    set WG5N2 $::HOOKN
    set WG5TO [wtext $top.simrow.variant]
    set WG5TOS [wtext $top.simrow.status]
    set ::HOOK_BODY {}
    check {WG5 Detect enters the probe door once, empties the line BEFORE it does, and paints what came back: the complete sentence for an answer, NOTHING for a probe that ran out of time -- while the status line says so in casemode_report's words} \
      [list $WG5BEFORE $WG5N1 $WG5SEEN $WG5AFTER \
            [expr {$WG5AFTER eq [mint ase::variant_detected ngspice $STUB_D $::D_FORK]}] \
            $WG5N2 $WG5TO \
            [expr {$WG5TOS ne {} && $WG5TOS eq [mint ase::casemode_report ngspice $STUB_D $::TO]}] \
            [file exists $MARK]] \
      [list [s_unmeas $STUB_D] 1 {} [s_fork $STUB_D] 1 2 {} 1 0]

    # --- WG6: THE PROGRAM FIELD CHANGES ------------------------------------
    catch {test_sim_registry_isolate}
    v_ans ase::sim_register apt45b $STUB_A
    prime $STUB_A $D_APT
    prime $STUB_F $D_FORK
    zero
    open_editor $top 0
    set WG6A [wtext $top.simrow.variant]
    retype $top.simrow.path $STUB_F
    set WG6F [wtext $top.simrow.variant]
    ## EMPTIED STRAIGHT AFTER A SENTENCE, so a line that kept the last one shows:
    ## emptied after the missing file, whose line is already empty, it could not.
    retype $top.simrow.path {}
    set WG6E [wtext $top.simrow.variant]
    retype $top.simrow.path $MISSING
    set WG6M [wtext $top.simrow.variant]
    set WG6MS [wtext $top.simrow.status]
    ## DETECT ON A FIELD EMPTIED WITHOUT LEAVING IT: the line still carries the
    ## last program's sentence, so only Detect's own empty-field branch can clear
    ## it -- and it must, while starting nothing.
    retype $top.simrow.path $STUB_A
    set WG6BACK [wtext $top.simrow.variant]
    $top.simrow.path delete 0 end
    catch {update}
    winv $top.simrow.detect
    set WG6DV [wtext $top.simrow.variant]
    set WG6DS [wtext $top.simrow.status]
    check {WG6 leaving the Program field repaints the line for the program now named: another program's own sentence, nothing for a file that is not there (the status line says why), nothing for an emptied field, and nothing after Detect on an empty field -- never the last program's sentence, and nothing started} \
      [list $WG6A $WG6F $WG6M \
            [expr {$WG6MS ne {} && $WG6MS eq [mint ase::casemode_status ngspice $MISSING {}]}] \
            $WG6E $WG6BACK $WG6DV \
            [expr {$WG6DS ne {} && $WG6DS eq [mint ase::casemode_status ngspice {} {}]}] \
            $::HOOKN [file exists $MARK]] \
      [list [s_apt $STUB_A] [s_fork $STUB_F] {} 1 {} [s_apt $STUB_A] {} 1 0 0]

    # --- WG7: THE REAL BINARIES -----------------------------------------------
    ## ⚠ THE ORDINARY CAPABILITY PROBE, through the real Detect button: the same
    ## seven short -b decks test_ase_variant_1470's EX rows run, none of which
    ## crashes any of them. This is the look debt's fixture, as a row.
    ##
    ## ISSUE 1724 moved the fork's ver_50 row and added a third. ver_50 read the
    ## complete sentence until `hier_probes` was measured; it now names that one
    ## gap. The complete sentence is ver_53's, which is started from a COPY in
    ## this suite's scratch: that build tree is rebuilt under its own session.
    set WG7V53 [file join [test_real_home] dev ngspice-ver_53 build-ver_53 src ngspice]
    set WG7V53C [file join $scratch wg7_ngspice_v53]
    if {[file executable $WG7V53]} {
      ## `file normalize` follows every link of a path but one in its LAST
      ## component, so one more component is put behind it and taken off again.
      catch {file copy -force [file dirname [file normalize [file join $WG7V53 __wg7__]]] $WG7V53C}
    }
    set WG7BINS [list \
      apt  /usr/bin/ngspice apt \
      fork /home/analog/dev/ngspice/build-ver_50/src/ngspice v50 \
      v53  $WG7V53C fork]
    foreach {tag bin shape} $WG7BINS {
      if {![file executable $bin]} {
        puts "ok:   WG7/$tag SKIPPED -- no binary at $bin"
        continue
      }
      catch {test_sim_registry_isolate}
      set ::HOOK_BODY {}
      v_ans ase::sim_register real$tag $bin
      set n0 $::HOOKN
      open_editor $top 0
      set cold [wtext $top.simrow.variant]
      set n1 $::HOOKN
      winv $top.simrow.detect
      set det [wtext $top.simrow.variant]
      set n2 $::HOOKN
      open_editor $top 0
      set warm [wtext $top.simrow.variant]
      set n3 $::HOOKN
      switch -- $shape {
        apt     { set exp [s_apt $bin] }
        v50     { set exp [s_v50 $bin] }
        default { set exp [s_fork $bin] }
      }
      check "WG7/$tag the real $bin: opened cold the line says it is not measured and nothing starts; Detect probes it once and the line reads its worked sentence; reopened, the line reads it again from memory and nothing starts" \
        [list $cold [expr {$n1 - $n0}] [expr {$n2 - $n1 >= 1}] $det [expr {$n3 - $n2}] $warm] \
        [list [s_unmeas $bin] 0 1 $exp 0 $exp]
    }

    # --- WG8: THE WAY TO DETECT, TAKEN AS THE CURE'S SENTENCE SAYS IT (issue 1724) --
    ## When the simulator a session starts is known to save no terminal current
    ## below the top level and a registered entry has not been tried, a pick is
    ## told so, and how to find out without a run: select the entry under
    ## Setup > Simulators…, press Edit… and then Detect (ase::probe_cure).  The
    ## window that menu entry opens has no Detect button; Detect is in the row
    ## editor.  So the menu, its entry and the two buttons are READ OFF THE
    ## SENTENCE and each is looked up among the real widgets BY ITS LABEL: a
    ## word the sentence gets wrong finds no widget.  The probe is stood in for
    ## (HOOK_BODY), as in WG5; the session's own state is not edited -- it
    ## carries no choice, so what it starts is the first entry registered.
    proc wg8_menu_index {m label} {
      if {![wex $m]} { return -1 }
      if {[catch {$m index end} last] || $last eq {none}} { return -1 }
      for {set i 0} {$i <= $last} {incr i} {
        if {![catch {$m entrycget $i -label} l] && $l eq $label} { return $i }
      }
      return -1
    }
    ## every button at or below `w` whose label is `text`
    proc wg8_buttons {w text} {
      set out {}
      if {![wex $w]} { return $out }
      set todo [list $w]
      while {[llength $todo]} {
        set c [lindex $todo 0]
        set todo [lrange $todo 1 end]
        foreach k [winfo children $c] { lappend todo $k }
        if {[winfo class $c] in {Button TButton} && ![catch {$c cget -text} t] && $t eq $text} { lappend out $c }
      }
      return $out
    }
    ## `script` with ase::echo recording instead of speaking -> what was said,
    ## as {tag sentence} pairs.  The real one is parked inside its own
    ## namespace, for the reason hook_install gives.
    proc wg8_said {script} {
      set ::WG8ECHO {}
      if {![llength [info commands ::ase::echo]]} { return NOECHO }
      rename ::ase::echo ::ase::zz_w1471_echo
      proc ::ase::echo {msg {tag {}}} { lappend ::WG8ECHO [list $tag $msg] ; return 1 }
      catch {uplevel #0 $script}
      rename ::ase::echo {}
      rename ::ase::zz_w1471_echo ::ase::echo
      return $::WG8ECHO
    }
    set WG8LIMIT {it saves terminal currents only on top-level devices that are not subcircuit instances.}
    catch {test_sim_registry_isolate}
    set ::HOOK_BODY {}
    v_ans ase::sim_register wgin $STUB_A
    v_ans ase::sim_register wgnew $STUB_D
    prime $STUB_A $D_APT
    zero
    catch {destroy $top.simrow}
    catch {destroy $top.simdlg}
    set ::WG8ST [v_ans ase::session_state $key]
    set WG8FIX [v_total {
      set v [ase::probe_session_verdict $::WG8ST]
      list [dict get $v entry] [dict get $v verdict] [ase::probe_cure_entries ngspice peek]
    }]
    set WG8P0 [wg8_said {ase::probe_pick_report $::WG8ST {i(x1:a)}}]
    set WG8CURE [v_ans ase::probe_cure $::WG8ST peek before]
    foreach v {w8e w8m w8i w8b1 w8b2} { set $v ZZNOWORD }
    regexp {^(\S+) has not been tried yet — the next run finds out whether it can, or select it under (\S+) > (\S+), press (\S+) and then (\S+)\.$} $WG8CURE -> w8e w8m w8i w8b1 w8b2
    ## 1. the menu, and its entry
    set w8mi [wg8_menu_index $top.mb $w8m]
    set w8sub {}
    if {$w8mi >= 0} { catch {set w8sub [$top.mb entrycget $w8mi -menu]} }
    set w8ii [wg8_menu_index $w8sub $w8i]
    if {$w8ii >= 0} { winv $w8sub $w8ii }
    set WG8A [list [expr {$w8mi >= 0}] [expr {$w8ii >= 0}] [wex $top.simdlg]]
    ## 2. the window it opened: the entry's row, the first button -- and no
    ## button with the second one's label
    set w8row {}
    catch {
      foreach id [$top.simdlg.tv children {}] {
        if {[$top.simdlg.tv set $id name] eq $w8e} { lappend w8row $id }
      }
    }
    if {[llength $w8row] == 1} {
      catch {$top.simdlg.tv selection set [lindex $w8row 0]}
      catch {update}
    }
    set w8ed [wg8_buttons $top.simdlg $w8b1]
    set w8nodet [llength [wg8_buttons $top.simdlg $w8b2]]
    if {[llength $w8ed] == 1} { winv [lindex $w8ed 0] }
    set WG8B [list [llength $w8row] [llength $w8ed] $w8nodet [wex $top.simrow] \
                   [v_total {$::top.simrow.name get}]]
    ## 3. the row editor: the second button, pressed -- the one step that asks
    ## a program -- and then OK
    set w8det [wg8_buttons $top.simrow $w8b2]
    set w8n0 $::HOOKN
    set ::HOOK_BODY {set ::D_FORK}
    if {[llength $w8det] == 1} { winv [lindex $w8det 0] }
    set ::HOOK_BODY {}
    set w8n1 $::HOOKN
    set w8line [wtext $top.simrow.variant]
    set w8ok [winv $top.simrow.btns.proceed]
    set WG8C [list [llength $w8det] $w8n0 [expr {$w8n1 - $w8n0}] $w8line $w8ok [wex $top.simrow]]
    ## 4. the next pick
    set WG8P1 [wg8_said {ase::probe_pick_report [ase::session_state $::key] {i(x1:a)}}]
    set WG8D [list [v_ans ase::probe_cure_entries ngspice peek] $WG8P1 $::HOOKN [file exists $MARK]]
    set WG8WHO "wgin ([file normalize $STUB_A])"
    check {WG8 THE WAY TO DETECT, TAKEN AS THE SENTENCE SAYS IT: with the session's own simulator known to save no terminal current below the top level and one registered entry nobody has asked, a pick of a subcircuit instance's pin is told that entry has not been tried yet and to select it under Setup > Simulators…, press Edit… and then Detect; those five words are read off the sentence and looked up among the real widgets by label -- the menubar has that menu and the menu that entry, which opens the Simulators window; the window lists the entry, has exactly one button with the first label and NONE with the second; that button opens the row editor on the entry; the editor has exactly one button with the second label, nothing has asked a program until it is pressed, and pressing it asks once; OK closes the editor -- and the next pick names the entry as the one that can, with nothing further asked (fixture: the entry the session starts, what is known of it, what a click reads of the two entries; what the pick said, and its tag; the five words; the menu, its entry, the window up; the entry's rows, buttons with the first label, with the second, the editor up, the name in it; buttons with the second label in the editor, programs asked before it, by it, the editor's line, OK, the editor gone; what a click reads of the two entries afterwards, what the next pick said, programs asked in all, a stand-in started)} \
      [list $WG8FIX $WG8P0 [list $w8e $w8m $w8i $w8b1 $w8b2] $WG8A $WG8B $WG8C $WG8D] \
      [list {wgin cannot {{wgin cannot} {wgnew untried}}} \
            [list [list error "ase: $WG8WHO, the simulator this session starts, cannot save that current: $WG8LIMIT wgnew has not been tried yet — the next run finds out whether it can, or select it under Setup > Simulators…, press Edit… and then Detect."]] \
            [list wgnew Setup Simulators… Edit… Detect] \
            {1 1 1} {1 1 0 1 wgnew} [list 1 0 1 [s_fork $STUB_D] OK 0] \
            [list {{wgin cannot} {wgnew can}} \
                  [list [list error "ase: $WG8WHO, the simulator this session starts, cannot save that current: $WG8LIMIT wgnew can — pick it under Setup > Simulators… before you run."]] \
                  1 0]]

    catch {destroy $top.simrow}
    catch {destroy $top.simdlg}
    catch {ase::ui::close $key}
    catch {update}
  }
} else {
  puts "SKIP: only WS1-WS7, WR1-WR4 and ST1 run without a display. The WG rows need\
 one -- the row editor of Setup > Simulators… is their subject."
}

# --- teardown ----------------------------------------------------------------
set ::HOOK_BODY {}
hook_remove
catch {test_sim_registry_isolate}
catch {dict unset ::ase::backends vnp1471}
catch {dict unset ::ase::backends vnh1471}
if {$UCD_HAD} { set ::USER_CONF_DIR $UCD_OLD } else { catch {unset ::USER_CONF_DIR} }
if {$NDSAVE eq {ZZUNSET}} { catch {unset ::netlist_dir} } else { set ::netlist_dir $NDSAVE }
if {$LNDSAVE eq {ZZUNSET}} { catch {unset ::local_netlist_dir} } else { set ::local_netlist_dir $LNDSAVE }

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
# THE COMPLETION BANNER (issue 1456): a WHOLE-LINE `OVERALL:` that
# tests/banner_rule.tcl requires, and an explicit exit code as the last statement,
# because `--nogui --pipe` otherwise exits 0 whatever happened.
puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"
exit [expr {$fail ? 1 : 0}]
