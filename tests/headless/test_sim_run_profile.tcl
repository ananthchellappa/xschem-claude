# test_sim_run_profile.tcl — THE PROFILE-AWARE RUN COMMAND AND B4's MISMATCH
# POLICY. Casemode batch item 8; PLAN.md section 3b item 8; DECISIONS.md B1 (the
# profile the command is built from), A2 (no `-n` by default; probe with the real
# argv and run in whatever mode came back) and B4 (requested != measured:
# `preserve` reports and continues, `distinguish` REFUSES). Spec:
# doc/claude/specs/simulator_profiles.md section 12.
#
# WHAT THIS ITEM IS. Item 6 built the profile MODEL and item 7 built the probes.
# Neither reached the run: `ase::backend::ngspice::run_cmd` was one hardcoded
# line, `ngspice -b <deck> 2>@1` — a bare `ngspice` off PATH — so ASE-L could not
# be pointed at a specific simulator at all. This item composes the command from
# the profile and puts B4's policy in front of the run.
#
# THE LOAD-BEARING CHECKS, and why:
#   CS175   THE COMPATIBILITY CONTRACT, against the LITERAL it replaced. With no
#           profile configured the composed command must be byte-identical to
#           `[list ngspice -b $deckpath 2>@1]`. Its other half composes a
#           CONFIGURED row in the same assertion, so it cannot pass by the
#           feature being absent.
#   CS177c  THE PROBE FILTER MUST NOT BE COPIED IN HERE. `sim_probe_safe_args`
#           drops `-r`/`--rawfile`/`--soa-log` because a PROBE may not overwrite
#           the user's previous outputs; a REAL RUN legitimately needs them —
#           `-r` is xschem's own shipped batch shape (`sim(spice,2,cmd)`). This
#           check reads both filters on the same words and fails if they ever
#           agree about an option.
#   CS186   ...but `-o`/`--output` IS dropped, and that is a measured carve-out,
#           not a return to the probe filter: `-o` sends the stdout ASE-L parses
#           to a file, so the run exits 0 with an empty log and no results.
#           `-r` measurably does not. CS186b pins that a drop is REPORTED.
#   CS187   A `stale` / `invalid` profile resolve is REPORTED. The index still
#           resolves, so the run may compose a DIFFERENT binary than the session
#           was configured with; item 6 delegated this decision here.
#   CS188   The advice must name a lever that EXISTS: on the global-floor path
#           (no profile row) "turn on the profile's -n" is nonsense.
#   CS189   THE PROBE IS ASKED FROM THE RUNDIR. That is the only reason a
#           `.spiceinit` beside the deck is detectable at all (A2). The stand-in
#           answers one mode with the marker in its cwd and another without.
#   CS190   The refusal does not destroy the PREVIOUS run's co-simulation
#           artefacts either — the gate sits before `cosim_save_map` (which
#           deletes the sidecar for an empty map) and `cosim_clear_artifacts`.
#   CS191   The composer guard is driven AT THE CALL SITE: a foreign backend
#           with its own `run_cmd` is not refused over a profile exe it never
#           runs.
#   CS177b  WHY THE RUN FILTER EXISTS AT ALL: `execute` does `open "|$args"`, so
#           a bare `>` in a profile's args EATS THE NEXT WORD — and `run_cmd`
#           appends the deck path last, so ngspice would run with no deck.
#   CS178b/d B4's REFUSAL, both shapes: measured-to-fold, and NOT MEASURED AT ALL
#           (timeout / unlocatable exe). "Confirmed to support it" is B4's phrase,
#           so "not known to fail" is not enough — and an unlocatable exe is
#           B4's own third route, the binary changing under the path.
#   CS179d  THE GATE IS ARMED ONLY BY A NON-`fold` REQUEST. A1: the warning
#           "never fires for a stock user". The stand-in records every launch, so
#           this reads the launches themselves rather than an absence of output.
#   CS180   A ROW NAMING AN EXE WE CANNOT LOCATE IS A REFUSAL, IN EVERY MODE.
#           Falling back to a bare `ngspice` would silently run a DIFFERENT
#           simulator than the one configured.
#   CS181   THE REFUSAL LEAVES NO HALF-WRITTEN ARTEFACT. `ase::run_deck` raises
#           before its first `open`: no deck, no log, no raw, and an earlier
#           run's files untouched. Item 10 is about a file that looks like a
#           result; this may not manufacture a new instance of it.
#   CS182   "REPORT IN THE LOG **AND** THE CIW" (section 3b), driven end to end
#           through a real `execute` + `ase::run_done`. Item 14 found a warning
#           that was correct and reached nobody; this reads it back out of the
#           run log the user opens.
#
# NOTHING HERE RUNS A REAL SIMULATOR. Every launch is a `/bin/sh` stand-in, so
# the file needs no ngspice at all and has no skip arm to mis-score. It IS
# Linux-flavoured (`/bin/sh`, `file attributes -permissions`), like item 7's.
#
# Run TRUE HEADLESS from the repo root (needs no display):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_sim_run_profile.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}
# ABORT-PROOFING (the LEDGER carry-forward from items 1, 2, 5b, 6 and 7): a proc
# that has been sabotaged away must FAIL a check, never abort the file with no
# RESULT line — under which every sabotage reads as "nothing went red".
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
proc dg {d k} {
  if {[catch {dict get $d $k} v]} { return "NO:$k" }
  return $v
}
proc readfile {p} {
  if {[catch {open $p r} f]} { return "NOFILE" }
  set t [read $f] ; close $f ; return $t
}
proc putfile {p txt} {
  set f [open $p w] ; puts -nonewline $f $txt ; close $f
}
# an executable /bin/sh stand-in simulator
proc fake {dir name body} {
  set p [file join $dir $name]
  set f [open $p w]
  puts $f "#!/bin/sh"
  puts $f $body
  close $f
  file attributes $p -permissions 0755
  return $p
}

set tmp [test_scratch simrunprofile]
set ::USER_CONF_DIR [file join $tmp conf]
file mkdir $::USER_CONF_DIR

# --- the CIW spy. ase::echo resolves ::ciw_echo BY NAME at call time, which is
# the seam every ASE test uses. Item 14's finding is why the TAG is recorded and
# not only the text: a channel can be correct and still reach nobody.
set ::said {}
if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::ciw_echo_orig }
proc ::ciw_echo {line {tag {}}} { lappend ::said [list $tag $line] }
proc said_clear {} { set ::said {} }
proc said_tags {} {
  set t {}
  foreach e $::said { lappend t [lindex $e 0] }
  return $t
}
proc said_match {pat} {
  foreach e $::said { if {[string match $pat [lindex $e 1]]} { return 1 } }
  return 0
}
proc said_count {pat} {
  set n 0
  foreach e $::said { if {[string match $pat [lindex $e 1]]} { incr n } }
  return $n
}

# A private simulator configuration; nothing below reads or writes the user's own.
#
# ⚠ IT WAS A `sim()` PROFILE ROW UNTIL THE `annotate` MERGE, and almost every row
# in this suite is unchanged by that: what they assert is how ase::run_cmd
# COMPOSES a command and how the B4 gate decides, and both survived intact. Only
# these three fixture procs know where the exe, the args, the case mode and the
# `-n` flag come from, so re-pointing them is the whole migration. `add_row` now
# returns an entry NAME rather than a row index, and the rows below pass it to
# `mkstate` exactly as they passed the index.
proc reset_sim {} {
  ase::sim_clear
  set ::sim_case_mode fold
}
proc add_row {tool name exe {args_ {}} {casemode {}} {nsi 0}} {
  ase::sim_register $name $exe -args $args_ -backend ngspice \
                    -casemode $casemode -nospiceinit $nsi
  return $name
}
# A state with a real rundir and a design cell, run by simulator `$i`.
#
# ⚠ `$i` EMPTY MEANS "NOTHING CHOSEN", AND IT HAS TO SAY SO OUT LOUD. Registering
# the first simulator puts it in force (ase::sim_register), so after any add_row
# a state built with no simulator would silently inherit that one -- and CS175,
# whose whole subject is what a user with nothing configured gets, would be
# measuring the opposite of what it says. `ase::sim_select {}` is the gesture
# that hands control back to the program on PATH.
proc mkstate {rundir cell {tool spice} {i {}}} {
  set s [ase::state_default]
  dict set s design [dict create lib dlib cell $cell view schematic]
  dict set s rundir $rundir
  if {$i ne {}} { ase::sim_select $i } else { ase::sim_select {} }
  return $s
}
proc runcmd {state deck} {
  return [pcall ase::backend::ngspice::run_cmd $state $deck]
}

set rd [file join $tmp run]
file mkdir $rd
set DECK [file join $rd cell_ase.spice]

# ===========================================================================
# A — THE COMPATIBILITY CONTRACT, and the composition
# ===========================================================================

# ONE assertion, both halves: the untouched default must equal the literal this
# item replaced, AND a registered simulator must compose from its entry. The
# first half alone passes on a tree where this item does not exist yet.
#
# ⚠ EACH HALF IS COMPOSED WHILE ITS OWN CHOICE IS IN FORCE, and that is a real
# change from the profile store (the `annotate` merge). A profile row was STAMPED
# ON THE STATE, so a state built before any row existed stayed "no profile"
# forever; the registry's choice is one global in-force entry, so composing both
# halves at the end would have measured the second choice twice -- and the first
# half, whose whole subject is what a user with nothing configured gets, would
# have quietly become a second copy of the second half.
set exeA [fake $tmp ngspice_A {echo CCM=fold}]
reset_sim
set st0 [mkstate $rd cell]
set cmd_def [runcmd $st0 $DECK]
reset_sim
set iA [add_row spice {row A} $exeA]
set stA [mkstate $rd cell spice $iA]
set cmd_row [runcmd $stA $DECK]
eqcheck CS175-nothing-registered-is-the-literal-and-an-entry-composes \
  "def=<$cmd_def> row=<$cmd_row>" \
  "def=<[list ngspice -b $DECK 2>@1]> row=<[list $exeA -b $DECK 2>@1]>"

# args, `-n` and `-D` word order, all against one composed command
reset_sim
set iB [add_row spice {row B} $exeA {-r out.raw --soa-log soa.log} preserve 1]
set stB [mkstate $rd cell spice $iB]
eqcheck CS176-full-composition-word-order \
  [runcmd $stB $DECK] \
  [list $exeA -b -r out.raw --soa-log soa.log -n -D casemode=preserve $DECK 2>@1]

# A2: `-n` is OFF BY DEFAULT and only the profile field turns it on. Both
# directions, one assertion.
reset_sim
set iC [add_row spice {row C} $exeA {} preserve 0]
set iD [add_row spice {row D} $exeA {} preserve 1]
eqcheck CS176b-nospiceinit-off-by-default \
  "off=<[lsearch -exact [runcmd [mkstate $rd cell spice $iC] $DECK] -n]>\
 on=<[lsearch -exact [runcmd [mkstate $rd cell spice $iD] $DECK] -n]>" \
  {off=<-1> on=<2>}

# The `-D` ruling: emitted for a non-fold request, NOT for `fold`. Both
# directions, one assertion.
reset_sim
set iE [add_row spice {row E} $exeA {} fold]
set iF [add_row spice {row F} $exeA {} distinguish]
eqcheck CS176c-D-flag-only-for-a-non-fold-request \
  "fold=<[runcmd [mkstate $rd cell spice $iE] $DECK]>\
 dist=<[runcmd [mkstate $rd cell spice $iF] $DECK]>" \
  "fold=<[list $exeA -b $DECK 2>@1]>\
 dist=<[list $exeA -b -D casemode=distinguish $DECK 2>@1]>"

# B1's global floor: no row mode at all, `sim_case_mode` set in an rc.
reset_sim
set iG [add_row spice {row G} $exeA]
set ::sim_case_mode preserve
set floorcmd [runcmd [mkstate $rd cell spice $iG] $DECK]
set ::sim_case_mode fold
eqcheck CS176d-global-floor-is-a-request \
  "floor=<$floorcmd> back=<[runcmd [mkstate $rd cell spice $iG] $DECK]>" \
  "floor=<[list $exeA -b -D casemode=preserve $DECK 2>@1]>\
 back=<[list $exeA -b $DECK 2>@1]>"

# the deck path is the LAST word before the stderr fold, whatever else is on
reset_sim
set iH [add_row spice {row H} $exeA {-r x.raw} distinguish 1]
set ch [runcmd [mkstate $rd cell spice $iH] $DECK]
eqcheck CS176e-deck-is-last-before-2>@1 \
  "tail=<[lrange $ch end-1 end]> len=<[llength $ch]>" "tail=<$DECK 2>@1> len=<9>"

# ===========================================================================
# B — THE RUN FILTER. It is NOT the probe's filter and must never become it.
# ===========================================================================

# Every option survives EXCEPT the `-o` family; every exec-syntax redirection
# and pipeline word goes. `&` is in the list because it is a word ngspice would
# otherwise be handed literally (it only backgrounds a Tcl pipeline as the LAST
# word, and run_cmd always appends the deck and 2>@1 after these).
eqcheck CS177-run-filter-keeps-options-drops-redirections \
  [pcall ase::run_safe_args \
     {-r out.raw --rawfile r2 --soa-log s -q > zap.txt 2>/dev/null \
      2> err.txt & -b | cat -n}] \
  {-r out.raw --rawfile r2 --soa-log s -q -b}

# THE REASON THE FILTER EXISTS: a bare `>` consumes the NEXT word, and `run_cmd`
# appends the deck last, so an unfiltered arg list runs ngspice with no deck.
reset_sim
set iI [add_row spice {row I} $exeA {-q >}]
set ci [runcmd [mkstate $rd cell spice $iI] $DECK]
eqcheck CS177b-a-bare-redirection-would-eat-the-deck \
  "cmd=<$ci>" "cmd=<[list $exeA -b -q $DECK 2>@1]>"

# THE ANTI-COPY CHECK. If someone routes run_cmd through sim_probe_safe_args,
# the two answers become equal on these words and this goes red. The words are
# the raw-writing options only: `-o` is now dropped by BOTH filters (for
# different reasons — see CS186), so it can no longer tell them apart.
set pw {-r out.raw --rawfile r2 --soa-log s}
eqcheck CS177c-run-filter-is-NOT-the-probe-filter \
  "run=<[pcall ase::run_safe_args $pw]> probe=<[pcall sim_probe_safe_args $pw]>" \
  "run=<-r out.raw --rawfile r2 --soa-log s> probe=<>"

# THE `-o` CARVE-OUT, all three spellings, and the control that `-r` is NOT
# affected — driven through the COMPOSED COMMAND, not only the filter, so a
# `-o` that slipped past into run_cmd would still be caught. MEASURED
# (2026-08-17, /usr/local/bin/ngspice on `v1 a 0 1 / r1 a 0 1k`): with `-o
# o.log` stdout carries only "Comments and warnings go to log-file: o.log" and
# the numbers go to o.log, so ase::last_result comes back EMPTY. `-r` and
# `--rawfile` measure harmless.
reset_sim
set iO1 [add_row spice {dash o}    $exeA {-o out.log}]
set iO2 [add_row spice {long o}    $exeA {--output=out.log}]
set iO3 [add_row spice {attached}  $exeA {-oout.log}]
set iO4 [add_row spice {two words} $exeA {--output out.log}]
set iO5 [add_row spice {control}   $exeA {-r out.raw --rawfile r2}]
set och {}
foreach i [list $iO1 $iO2 $iO3 $iO4 $iO5] {
  lappend och [lrange [runcmd [mkstate $rd cell spice $i] $DECK] 2 end-2]
}
eqcheck CS186-the-o-family-is-dropped-and-r-is-not \
  "o=<[lindex $och 0]> long=<[lindex $och 1]> att=<[lindex $och 2]>\
 two=<[lindex $och 3]> r=<[lindex $och 4]>" \
  {o=<> long=<> att=<> two=<> r=<-r out.raw --rawfile r2>}

# A DROPPED WORD IS REPORTED, never silent — the user typed it into a profile
# field and it is not reaching the simulator. It is NOT gated on the case mode
# (this row asks for `fold`), it reaches the CIW as a `note`, and it is returned
# for the head of the run log. The control half: the `-r` row says nothing.
reset_sim ; said_clear
set iO6 [add_row spice {drops} $exeA {-o out.log} fold]
set n6 [pcall ase::run_precheck [mkstate $rd cell spice $iO6]]
set said6 [said_tags]
set ciw6 [said_match {ase: profile args*-o out.log*}]
said_clear
set iO7 [add_row spice {keeps} $exeA {-r out.raw} fold]
set n7 [pcall ase::run_precheck [mkstate $rd cell spice $iO7]]
eqcheck CS186b-a-dropped-arg-is-reported \
  "note=<[string match {ase: profile args*-o out.log*} $n6]> tags=<$said6> ciw=<$ciw6>\
 clean-note=<$n7> clean-said=<[llength $::said]>" \
  {note=<1> tags=<note> ciw=<1> clean-note=<> clean-said=<0>}

# ===========================================================================
# C — B4's POLICY, as a pure function of a request and a measurement
# ===========================================================================

proc verdict {req delivers {status ok} {ms 0} {err {}}} {
  return [dg [pcall ase::run_casemode_verdict $req \
                [dict create delivers $delivers status $status ms $ms err $err]] action]
}
eqcheck CS178-preserve-mismatch-reports \
  "got=<[verdict preserve fold]> agree=<[verdict preserve preserve]>" \
  {got=<report> agree=<ok>}
eqcheck CS178b-distinguish-mismatch-refuses \
  "fold=<[verdict distinguish fold]> pres=<[verdict distinguish preserve]>\
 agree=<[verdict distinguish distinguish]>" \
  {fold=<refuse> pres=<refuse> agree=<ok>}
# "confirmed to support it" (B4), not "not known to fail": nothing measured is a
# refusal under distinguish and a report under preserve.
eqcheck CS178c-not-confirmed-is-a-refusal-under-distinguish \
  "tmo=<[verdict distinguish {} timeout 5000]> noexe=<[verdict distinguish {} noexe]>\
 err=<[verdict distinguish {} error 0 boom]>" \
  {tmo=<refuse> noexe=<refuse> err=<refuse>}
eqcheck CS178d-not-confirmed-only-reports-under-preserve \
  "tmo=<[verdict preserve {} timeout 5000]> noexe=<[verdict preserve {} noexe]>" \
  {tmo=<report> noexe=<report>}
# a `fold` request never refuses and never reports — A1's "never fires for a
# stock user", stated as behaviour
eqcheck CS178e-a-fold-request-is-always-ok \
  "fold=<[verdict fold preserve]> dist=<[verdict fold distinguish]> empty=<[verdict {} fold]>" \
  {fold=<ok> dist=<ok> empty=<ok>}
# the reason text distinguishes the three not-measured shapes from each other
set rs {}
foreach {s d} {ok fold timeout {} noexe {}} {
  lappend rs [dg [pcall ase::run_casemode_verdict distinguish \
      [dict create delivers $d status $s ms 5000 err {}]] reason]
}
eqcheck CS178f-the-reason-names-what-happened \
  "measured=<[string match {*deliver 'fold'*} [lindex $rs 0]]>\
 tmo=<[string match {*5000 ms*} [lindex $rs 1]]>\
 noexe=<[string match {*no executable*} [lindex $rs 2]]>" \
  {measured=<1> tmo=<1> noexe=<1>}

# ===========================================================================
# D — THE GATE, end to end against stand-in simulators
# ===========================================================================

# a stand-in that RECORDS every launch, so "the probe did not run" is read from
# the launches themselves, not from an absence of output
set LAUNCHLOG [file join $tmp launches]
proc launcher {dir name mode} {
  global LAUNCHLOG
  return [fake $dir $name "echo \"\$@\" >> $LAUNCHLOG\necho CCM=$mode"]
}
proc nlaunch {} {
  global LAUNCHLOG
  if {![file isfile $LAUNCHLOG]} { return 0 }
  return [llength [split [string trim [readfile $LAUNCHLOG]] "\n"]]
}
proc launch_clear {} { global LAUNCHLOG ; file delete -force -- $LAUNCHLOG }

set exeFold [launcher $tmp ng_fold fold]
set exeDist [launcher $tmp ng_dist distinguish]

# preserve requested, simulator folds -> REPORT: a note returned (for the log),
# a `note`-tagged CIW line, and NO raise.
reset_sim ; said_clear ; launch_clear
set iP [add_row spice {folds} $exeFold {} preserve]
set stP [mkstate $rd cell spice $iP]
set caught [catch {ase::run_precheck $stP} noteP]
eqcheck CS179-preserve-mismatch-reports-and-continues \
  "raised=<$caught> note=<[string match {ase: casemode*} $noteP]>\
 tags=<[said_tags]> ciw=<[said_match {*requested 'preserve'*}]>" \
  {raised=<0> note=<1> tags=<note> ciw=<1>}

# distinguish requested, same folding simulator -> REFUSE
reset_sim ; said_clear ; launch_clear
set iQ [add_row spice {folds} $exeFold {} distinguish]
set stQ [mkstate $rd cell spice $iQ]
set caught [catch {ase::run_precheck $stQ} errQ]
eqcheck CS179b-distinguish-mismatch-refuses \
  "raised=<$caught> msg=<[string match {ase: REFUSED*distinguish*} $errQ]>\
 tags=<[said_tags]> ciw=<[said_match {*REFUSED*}]>" \
  {raised=<1> msg=<1> tags=<error> ciw=<1>}

# distinguish requested and DELIVERED -> silence: no note, no CIW line, no raise
reset_sim ; said_clear ; launch_clear
set iR [add_row spice {distinguishes} $exeDist {} distinguish]
set caught [catch {ase::run_precheck [mkstate $rd cell spice $iR]} noteR]
eqcheck CS179c-a-confirmed-distinguish-runs-silently \
  "raised=<$caught> note=<$noteR> said=<[llength $::said]> probed=<[expr {[nlaunch] > 0}]>" \
  {raised=<0> note=<> said=<0> probed=<1>}

# THE ARMING RULING: a `fold` request probes NOTHING. Positive half in the same
# assertion — the identical row asking for `preserve` does probe.
reset_sim ; said_clear ; launch_clear
set iS [add_row spice {folds} $exeFold {} fold]
catch {ase::run_precheck [mkstate $rd cell spice $iS]}
set nfold [nlaunch]
launch_clear
set iT [add_row spice {folds} $exeFold {} preserve]
catch {ase::run_precheck [mkstate $rd cell spice $iT]}
set npres [nlaunch]
eqcheck CS179d-only-a-non-fold-request-arms-the-probe \
  "fold=<$nfold> preserve=<[expr {$npres > 0}]>" {fold=<0> preserve=<1>}

# A ROW NAMING AN EXE WE CANNOT LOCATE IS A REFUSAL IN EVERY MODE — falling back
# to a bare `ngspice` would silently run a different simulator. The `fold` leg is
# the load-bearing one: the mode gate must NOT reach this check.
reset_sim ; said_clear
set iU [add_row spice {gone} [file join $tmp no_such_ngspice] {} fold]
set c1 [catch {ase::run_precheck [mkstate $rd cell spice $iU]} e1]
set iV [add_row spice {gone} [file join $tmp no_such_ngspice] {} preserve]
set c2 [catch {ase::run_precheck [mkstate $rd cell spice $iV]} e2]
eqcheck CS180-an-unlocatable-profile-exe-refuses-in-every-mode \
  "fold=<$c1> pres=<$c2> names=<[string match "*no_such_ngspice*" $e1]>\
 refused=<[string match {ase: REFUSED*} $e1]>" \
  {fold=<1> pres=<1> names=<1> refused=<1>}

# ...and a row whose exe IS locatable does not refuse for a `fold` request
reset_sim ; said_clear
set iW [add_row spice {here} $exeFold {} fold]
eqcheck CS180b-a-locatable-exe-does-not-refuse \
  "raised=<[catch {ase::run_precheck [mkstate $rd cell spice $iW]} eW]> said=<[llength $::said]>" \
  {raised=<0> said=<0>}

# only the ngspice composer is subject to the policy: a backend with its own
# run_cmd hardcodes its own binary and reads no profile
eqcheck CS180c-policy-applies-only-to-the-registry-composer \
  "ngspice=<[pcall ase::run_composes_registry ngspice]>\
 unknown=<[pcall ase::run_composes_registry nosuchsim]>" \
  {ngspice=<1> unknown=<0>}

# A `stale` or `invalid` resolve is REPORTED (item 6 delegated the decision to
# item 8; spec 12.9). Rows are addressed by INDEX, so inserting or renaming one
# silently re-points every session that stored it — and the command would then
# name a DIFFERENT binary than the session was configured with. Not gated on the
# mode: both rows below request `fold`.
reset_sim ; said_clear
set exeS1 [fake $tmp ng_stale1 {echo CCM=fold}]
set exeS2 [fake $tmp ng_stale2 {echo CCM=fold}]
set iS1 [add_row spice {Ngspice ver_50} $exeS1 {} fold]
set stS [mkstate $rd cell spice $iS1]
# ...and now that index comes to hold a different row (renamed, or one inserted
# above): the state's stamped name no longer matches
set ::sim(spice,$iS1,name) {Ngspice 44}
set ::sim(spice,$iS1,exe)  $exeS2
set_sim_defaults
set nS [pcall ase::run_precheck $stS]
set saidS [said_tags]
said_clear
# ⚠ CS187 WAS HERE AND IS GONE, with its subject (the `annotate` merge). It
# asserted that a `stale` or `invalid` PROFILE ROW is reported: rows were
# addressed by INDEX, so inserting one above silently re-pointed every saved
# session that had stored an index, and ase::run_status_note existed to say so
# out loud rather than let the substitution happen quietly.
#
# A registry entry is addressed by NAME. Nothing re-points a saved session by
# being inserted above it, so there is no substitution left to report and no
# sentence left to assert. What replaced the concern is stronger and is asserted
# elsewhere: ase::sim_status RE-VALIDATES the program at every run instead of
# trusting what registration recorded, and CS180 below drives the case that
# remains -- an entry whose program has gone REFUSES rather than falling back to
# something else on PATH, which is the harm CS187's report was a consolation
# prize for.

# AN `ok` RESOLVE SAYS NOTHING AT ALL. Kept from CS187's pair as the standing
# control it always was: a precheck that reported on every run would be noise,
# and this is the row that reddens for it. It is worth more now that its partner
# is gone, not less -- it is the only thing asserting the precheck's silence.
reset_sim ; said_clear
set iS4 [add_row spice {fine} $exeS1 {} fold]
set nOK [pcall ase::run_precheck [mkstate $rd cell spice $iS4]]
eqcheck CS187b-an-ok-resolve-reports-nothing \
  "note=<$nOK> said=<[llength $::said]>" {note=<> said=<0>}

# THE ADVICE MUST NAME A LEVER THAT EXISTS. On the global-floor path there is no
# profile row to re-point and no -n checkbox to turn on; the user's lever is
# `sim_case_mode`. Both verdicts, and the configured-row control in the same
# assertion.
reset_sim ; said_clear
set ::sim_case_mode distinguish
set stFL [mkstate $rd cell]
# the floor path composes a bare `ngspice`, so point PATH at a folding stand-in
set pathsave $::env(PATH)
set ngdir [file join $tmp ngpath]
file mkdir $ngdir
fake $ngdir ngspice {echo CCM=fold}
set ::env(PATH) "$ngdir:$pathsave"
# auto_execok memoizes in ::auto_execs; drop the one entry (auto_reset would
# also delete every auto-loaded proc in this interpreter)
catch {unset ::auto_execs(ngspice)}
set cFL [catch {ase::run_precheck $stFL} eFL]
set ::sim_case_mode preserve
set cFL2 [catch {ase::run_precheck $stFL} eFL2]
set ::sim_case_mode fold
set ::env(PATH) $pathsave
catch {unset ::auto_execs(ngspice)}
reset_sim ; said_clear
set iFL [add_row spice {configured} $exeFold {} distinguish]
set cFL3 [catch {ase::run_precheck [mkstate $rd cell spice $iFL]} eFL3]
eqcheck CS188-the-advice-names-a-lever-that-exists \
  "refuse=<$cFL> floor-named=<[string match {*sim_case_mode*} $eFL]>\
 no-sim-n=<[string match {*simulator's -n*} $eFL]> report-raised=<$cFL2>\
 report-floor=<[string match {*sim_case_mode*} $eFL2]>\
 report-no-sim-n=<[string match {*simulator's -n*} $eFL2]>\
 row-refused=<$cFL3> row-keeps-n=<[string match {*simulator's -n*} $eFL3]>" \
  {refuse=<1> floor-named=<1> no-sim-n=<0> report-raised=<0> report-floor=<1>\
 report-no-sim-n=<0> row-refused=<1> row-keeps-n=<1>}

# THE PROBE IS ASKED FROM THE RUNDIR. That is the ONLY reason a `.spiceinit`
# beside the deck is detectable at all (A2), and no other check in this file can
# see the cwd — every other stand-in answers the same mode from anywhere. This
# one answers `fold` when a `.spiceinit` is in ITS OWN cwd and `distinguish`
# when it is not, so the verdict flips on the cwd alone.
set exeCwd [fake $tmp ng_cwd \
  "if \[ -f .spiceinit \]; then echo CCM=fold; else echo CCM=distinguish; fi"]
set rdM [file join $tmp run_marker]
set rdN [file join $tmp run_nomarker]
file mkdir $rdM $rdN
putfile [file join $rdM .spiceinit] "set casemode=fold\n"
reset_sim ; said_clear
set iCw [add_row spice {cwd} $exeCwd {} distinguish]
set cM [catch {ase::run_precheck [mkstate $rdM cell spice $iCw]} eM]
set cN [catch {ase::run_precheck [mkstate $rdN cell spice $iCw]} eN]
eqcheck CS189-the-probe-is-asked-from-the-rundir \
  "marker=<$cM> refused=<[string match {ase: REFUSED*} $eM]> nomarker=<$cN>" \
  {marker=<1> refused=<1> nomarker=<0>}

# ===========================================================================
# E — ase::run_deck: a refusal leaves NOTHING, a report reaches the LOG
# ===========================================================================

set rd2 [file join $tmp run2]
file mkdir $rd2
putfile [file join $rd2 cell.spice] "* title\nv1 a 0 1\nr1 a 0 1k\n.end\n"
# an artefact from an EARLIER run, which a refusal must not touch and must not
# be able to hide behind
putfile [file join $rd2 cell_ase.raw] "PREVIOUS RUN\n"

reset_sim ; said_clear
set iX [add_row spice {folds} $exeFold {} distinguish]
set stX [mkstate $rd2 cell spice $iX]
set caught [catch {ase::run_deck $stX [file join $rd2 cell.spice]} errX]
eqcheck CS181-a-refusal-writes-no-artefact \
  "raised=<$caught> refused=<[string match {ase: REFUSED*} $errX]>\
 deck=<[file exists [file join $rd2 cell_ase.spice]]>\
 log=<[file exists [file join $rd2 cell_ase.log]]>\
 prev=<[string trim [readfile [file join $rd2 cell_ase.raw]]]>" \
  {raised=<1> refused=<1> deck=<0> log=<0> prev=<PREVIOUS RUN>}

# the same message says so, in the user's words: it names the rundir and says
# the files there are from an earlier run
eqcheck CS181b-the-refusal-says-what-is-on-disk \
  [string match "*$rd2*earlier run*" $errX] 1

# ...AND IT DOES NOT DESTROY THE PREVIOUS RUN'S CO-SIMULATION ARTEFACTS. CS181
# pins two ngspice files; the gate's contract is wider ("no VCD deleted, no .so
# rebuilt"), and the two procs that would break it sit a few lines below the
# gate: `cosim_save_map` DELETES the sidecar when the map is empty, and
# `cosim_clear_artifacts` deletes every VCD the deck promises. A netlist with a
# real d_cosim card is used so both are live, not skipped.
set rd5 [file join $tmp run5]
file mkdir $rd5
putfile [file join $rd5 cell.spice] \
  "* title\nv1 a 0 1\nr1 a 0 1k\na1 \[1\] dblk\n.model dblk d_cosim simulation=\"dblk.so\"\n.end\n"
putfile [file join $rd5 cell_ase.cosim] "# earlier run's map\n"
putfile [file join $rd5 cell_dblk.vcd] "\$date EARLIER RUN \$end\n"
reset_sim ; said_clear
set iC5 [add_row spice {folds} $exeFold {} distinguish]
set st5 [mkstate $rd5 cell spice $iC5]
set c5 [catch {ase::run_deck $st5 [file join $rd5 cell.spice]} e5]
eqcheck CS190-a-refusal-keeps-the-previous-cosim-artefacts \
  "raised=<$c5> refused=<[string match {ase: REFUSED*} $e5]>\
 map=<[string trim [readfile [file join $rd5 cell_ase.cosim]]]>\
 vcd=<[string match {*EARLIER RUN*} [readfile [file join $rd5 cell_dblk.vcd]]]>\
 deck=<[file exists [file join $rd5 cell_ase.spice]]>" \
  {raised=<1> refused=<1> map=<# earlier run's map> vcd=<1> deck=<0>}

# THE COMPOSER GUARD, DRIVEN AT THE CALL SITE. CS180c tests the predicate; this
# drives `ase::run_deck` itself. A backend with its own run_cmd hardcodes its
# own binary and reads no profile, so a refusal about a profile exe it never
# runs would be a lie — and deleting the guard leaves CS180c green.
proc ase_test_r191_run_cmd {state deckpath} { return [list $::R191EXE 2>@1] }
set ::R191EXE [fake $tmp ng_r191 {echo R191-RAN}]
pcall ase::register_backend mysim191 [dict create \
  render_deck  [ase::backend_hook ngspice render_deck] \
  run_cmd      ase_test_r191_run_cmd \
  log_file     [ase::backend_hook ngspice log_file] \
  result_probe [ase::backend_hook ngspice result_probe] \
  raw_file     [ase::backend_hook ngspice raw_file]]
set rd6 [file join $tmp run6]
file mkdir $rd6
putfile [file join $rd6 cell.spice] "* title\nv1 a 0 1\nr1 a 0 1k\n.end\n"
reset_sim ; said_clear
# a spice profile row naming an exe that does not exist — the ngspice composer
# would REFUSE over it (CS180); this backend never touches it
set i191 [add_row spice {gone} [file join $tmp no_such_ngspice_191] {} distinguish]
set st6 [mkstate $rd6 cell spice $i191]
dict set st6 simulator mysim191
set c6 [catch {ase::run_deck $st6 [file join $rd6 cell.spice]} r6]
set ec6 {}
if {!$c6} { set ec6 [pcall ase::wait $r6] }
eqcheck CS191-a-foreign-backend-is-not-refused-over-the-ngspice-profile \
  "raised=<$c6> refused=<[string match {*REFUSED*} $r6]> exit=<$ec6>\
 ran=<[string match {*R191-RAN*} [readfile [file join $rd6 cell_ase.log]]]>\
 ciw-refused=<[said_match {*REFUSED*}]> ciw-casemode=<[said_match {ase: casemode*}]>\
 ciw-finished=<[said_match {ase: simulation finished*}]>" \
  {raised=<0> refused=<0> exit=<0> ran=<1> ciw-refused=<0> ciw-casemode=<0>\
 ciw-finished=<1>}

# THE REPORT REACHES THE RUN LOG. Driven all the way through `execute` and
# `ase::run_done` with a stand-in that both answers the probe and behaves as a
# batch simulator.
set rd3 [file join $tmp run3]
file mkdir $rd3
putfile [file join $rd3 cell.spice] "* title\nv1 a 0 1\nr1 a 0 1k\n.end\n"
set exeRun [fake $tmp ng_runfold "echo CCM=fold\necho SIMULATOR-OUTPUT-HERE"]
reset_sim ; said_clear
set iY [add_row spice {folds} $exeRun {} preserve]
set stY [mkstate $rd3 cell spice $iY]
set idY [pcall ase::run_deck $stY [file join $rd3 cell.spice]]
set ecY [pcall ase::wait $idY]
set logY [readfile [file join $rd3 cell_ase.log]]
# ⚠ WHERE "THE HEAD OF THE FILE" IS MOVED (the `annotate` merge). Item 8 asked
# for the note in "the head of the file, the one place a reader who scrolls
# nothing at all still sees", and prefixed the whole log with it. Issue 0618 then
# gave the log a real header -- which run, which command, which directory, which
# deck -- so the head of the file IS that block, and prefixing above it would put
# a run's most important sentence above the line saying which run it was. The
# note is the header's `notes :` field; `above-output` is what keeps the ruling's
# actual claim, that a reader sees it before the simulator's own bytes.
set cs182_hdr [string range $logY 0 [expr {[string first {--- simulator output ---} $logY] - 1}]]
eqcheck CS182-the-mismatch-is-reported-in-the-log-and-the-CIW \
  "exit=<$ecY> head=<[string match {*ase: casemode*} $cs182_hdr]>\
 above-output=<[expr {[string first {ase: casemode} $logY] <\
                      [string first {SIMULATOR-OUTPUT-HERE} $logY]}]>\
 sim=<[string match {*SIMULATOR-OUTPUT-HERE*} $logY]>\
 ciw=<[said_match {ase: casemode*}]>" \
  {exit=<0> head=<1> above-output=<1> sim=<1> ciw=<1>}

# ...and with NO mismatch the log is exactly the simulator's own output
set rd4 [file join $tmp run4]
file mkdir $rd4
putfile [file join $rd4 cell.spice] "* title\nv1 a 0 1\nr1 a 0 1k\n.end\n"
reset_sim ; said_clear
set iZ [add_row spice {folds} $exeRun {} fold]
set stZ [mkstate $rd4 cell spice $iZ]
set idZ [pcall ase::run_deck $stZ [file join $rd4 cell.spice]]
set ecZ [pcall ase::wait $idZ]
set logZ [readfile [file join $rd4 cell_ase.log]]
# ⚠ "UNTOUCHED" NOW MEANS "NO NOTES FIELD", NOT "NO FRAMING" (the `annotate`
# merge). Issue 0618 gives every run log a header and a footer, so the bytes this
# row used to compare against are the SIMULATOR'S REGION alone -- which is
# exactly what it always cared about, and is still asserted byte-for-byte here.
# What it adds is the claim that matters after 0618: a run with nothing to say
# writes no `notes` field, so the file is byte-identical to any other quiet run.
set cs182b_body $logZ
set cs182b_i [string first {--- simulator output ---} $cs182b_body]
if {$cs182b_i >= 0} {
  set cs182b_body [string range $cs182b_body \
    [expr {$cs182b_i + [string length {--- simulator output ---}] + 1}] end]
  set cs182b_j [string first {=== exit } $cs182b_body]
  if {$cs182b_j >= 0} { set cs182b_body [string range $cs182b_body 0 $cs182b_j-1] }
}
eqcheck CS182b-no-mismatch-writes-no-notes-and-leaves-the-output-untouched \
  "exit=<$ecZ> log=<[string map {\n |} [string trim $cs182b_body]]>\
 notes-field=<[string match {*notes *:*} $logZ]>\
 casemode-lines=<[said_count {ase: casemode*}]>" \
  {exit=<0> log=<CCM=fold|SIMULATOR-OUTPUT-HERE> notes-field=<0> casemode-lines=<0>}

# ase::run_done's fourth parameter is OPTIONAL: a 3-argument call (every caller
# before item 8, and any stale execute(callback,<id>)) still writes the log.
#
# ⚠ IT IS THE METADATA RECORD NOW, NOT THE NOTE (the `annotate` merge). Issue
# 0618 claimed argument four for the run's provenance, so the casemode note
# travels as a FIELD of that record rather than as a rival fourth argument --
# two callbacks disagreeing about what argument four means is the defect neither
# branch would have caught alone. With no record the file is the simulator's
# bytes and nothing else, which is what keeps a stale callback working.
set lp3 [file join $tmp done3.log]
set lp4 [file join $tmp done4.log]
set ::execute(data,last) "RAWDATA"
set ::execute(exitcode,last) 0
catch {ase::run_done $lp3 $stZ {}}
catch {ase::run_done $lp4 $stZ {} \
        [dict create cell c simulator ngspice casenote {ase: casemode — a note}]}
set cs183_four [readfile $lp4]
eqcheck CS183-run_done-metadata-is-optional-and-carries-the-note \
  "three=<[string trim [readfile $lp3]]>\
 note-in-header=<[string match {*ase: casemode — a note*} $cs183_four]>\
 above-output=<[expr {[string first {casemode — a note} $cs183_four] <\
                      [string first {RAWDATA} $cs183_four]}]>\
 data-untouched=<[string match {*RAWDATA*} $cs183_four]>" \
  "three=<RAWDATA> note-in-header=<1> above-output=<1> data-untouched=<1>"

# ===========================================================================
# F — no Tk (this file runs under --nogui, where Tk does not exist)
# ===========================================================================

proc strip_tcl_comments {body} {
  set out {}
  foreach l [split $body "\n"] {
    if {[regexp {^\s*#} $l]} continue
    lappend out $l
  }
  return [join $out "\n"]
}
# ⚠ THE LEADING CONTEXT IS A COMMAND POSITION, NOT MERELY A NON-WORD CHARACTER,
# and that is a repair, not a loosening (the `annotate` merge). Half these names
# are ordinary English -- `entry`, `label`, `place`, `bind` -- and the old
# `[^a-zA-Z0-9_:.]` context matched them ANYWHERE: `dict get $s entry` read as a
# Tk `entry` call and reddened this row for procs that have never touched Tk.
# A false positive here is not harmless, because the fix a reader reaches for is
# to rename the innocent variable, which is how a true detector gets turned off.
# Tk commands are CALLED, so they sit at the start of a line or straight after
# `[`, `{`, `;` or `|`. The `tk_blind` sentinel below still proves the detector
# sees all three of its shapes, so this is tested in both directions.
set tkre {(^|[\[\{;|]|^[ \t]*|[\[\{;|][ \t]*)(toplevel|frame|button|label|entry|canvas|winfo|wm|grid|pack|place|bind|tk_messageBox|ttk::[a-z]+)([^a-zA-Z0-9_]|$)}
# the detector's own blind-spot sentinel: it must SEE Tk when Tk is there
set tk_blind {}
foreach s {{ set w [toplevel .p] } { button .b -text x } { winfo exists .x }} {
  if {![regexp $tkre $s]} { lappend tk_blind $s }
}
set tk_hits {}
foreach p {ase::run_filter_args ase::run_safe_args ase::run_profile
           ase::run_casemode_flag ase::run_casemode_verdict
           ase::run_composes_registry ase::run_mode_advice
           ase::sim_casemode_requested ase::sim_nospiceinit
           ase::run_precheck ase::backend::ngspice::run_cmd} {
  if {[catch {info body $p} b]} { lappend tk_hits MISSING:$p ; continue }
  if {[regexp $tkre [strip_tcl_comments $b] -> _pre cmdname]} { lappend tk_hits $p:$cmdname }
}
eqcheck CS184-no-Tk-in-any-item8-proc-and-the-detector-can-see-Tk \
  "hits=<$tk_hits> blind=<$tk_blind>" "hits=<> blind=<>"

# ===========================================================================
# G — the profile dict the two halves share
# ===========================================================================

reset_sim
set iN [add_row spice {shared} $exeA {-r x.raw | cat} preserve 1]
set pN [pcall ase::run_profile [mkstate $rd cell spice $iN]]
eqcheck CS185-run_profile-is-one-answer-for-both-halves \
  "exe=<[dg $pN exe]> named=<[dg $pN exe_named]> args=<[dg $pN args]>\
 drop=<[dg $pN dropped]> nsi=<[dg $pN nospiceinit]> req=<[dg $pN requested]>\
 entry=<[dg $pN entry]> st=<[dg $pN status]>" \
  "exe=<$exeA> named=<1> args=<-r x.raw> drop=<| cat> nsi=<1> req=<preserve>\
 entry=<shared> st=<ok>"

# NOTHING REGISTERED: no entry is named, and the resolution is `ok` because the
# program on PATH is a perfectly good answer to "what runs".
#
# ⚠ THE TWO CHANGED TERMS ARE BOTH REAL (the `annotate` merge). `st` was
# `default`, a PROFILE resolve status distinguishing "the tool's own row" from a
# named one; the registry has no such state and answers `ok`, with `entry` empty
# saying the same thing more directly -- which is why `entry` is asserted here
# and is what stops this row passing on an answer that named something. And
# `exe` was `{}`: a profile that named no executable left run_cmd to supply a
# bare `ngspice` of its own, so run_profile could not say what would run. The
# registry resolves it here, once, so `exe` is the program that will actually
# start -- the single-resolution property issue 0931 was for.
reset_sim
set pD [pcall ase::run_profile [mkstate $rd cell]]
eqcheck CS185b-nothing-registered-names-no-entry-and-runs-the-PATH \
  "exe=<[dg $pD exe]> named=<[dg $pD exe_named]> args=<[dg $pD args]>\
 drop=<[dg $pD dropped]> nsi=<[dg $pD nospiceinit]> req=<[dg $pD requested]>\
 entry=<[dg $pD entry]> st=<[dg $pD status]>" \
  {exe=<ngspice> named=<0> args=<> drop=<> nsi=<0> req=<fold> entry=<> st=<ok>}

if {[info commands ::ciw_echo_orig] ne {}} {
  rename ::ciw_echo {}
  rename ::ciw_echo_orig ::ciw_echo
}
catch {test_scratch_drop $tmp}
puts "----"
puts "test_sim_run_profile: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
