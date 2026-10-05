# Simulation > View last job data / View last job errors must SAY SOMETHING when
# there is nothing to show.
#
# THE DEFECT, MEASURED BEFORE IT WAS CHANGED. Both menu entries were registered
# with a body of the shape
#
#     if { [info exists execute(data,last)] } { viewdata $execute(data,last) }
#
# and no else arm. `execute(data,last)` / `execute(error,last)` are post-mortem
# slots written by execute_fileevent (src/xschem.tcl) when a sub-process it
# launched reaches EOF, so in a fresh session neither exists. Probed on the dev
# display in a fresh session: `info exists ::execute(data,last)` answered 0 for
# both slots while the two entries were present at .menubar.simulation. Picking
# either one therefore evaluated an `if` whose condition was false and did
# NOTHING -- no window, no message, no status line.
#
# ⚠ ONE HALF OF THE ORIGINAL REPORT WAS WRONG AND THE ROWS BELOW SPLIT THE TWO
# STATES APART BECAUSE OF IT. The report said nothing happens "in a fresh
# session, or after a run that produced no output". Only the first is silence.
# `execute_fileevent` sets `execute(error,last)` to the close error string,
# which is the EMPTY STRING after a clean run, and the slot then EXISTS -- so
# the old condition was TRUE, `viewdata {}` ran, and `viewdata` maps its
# toplevel unconditionally. That state produced a BLANK View-data window, not
# silence. Rows VJ1/VJ2 and VE1/VE2 drive the unset state; VJ4/VJ5 and VE4/VE5
# drive the empty state. They are separate rows because they were separate
# defects with different symptoms, and a single row over "nothing to show"
# would have been green on the empty one against the old code.
#
# THE ECHO IS NOT A NEW REPORTING PATH. `alert_` is what the Simulation menu
# already uses for exactly this class: the `Create device OP .save file` entry
# in .menubar.simulation.graph carries a comment saying its refusal and its
# empty result "must reach the user as text, not as a silent no-op" and routes
# both through `alert_`. Rows VJ1 and VE1 observe the call arriving there by
# name, so a future rewrite onto some other reporting path reddens them.
#
# METHOD, AND WHY IT IS THE INTERPRETER RATHER THAN THE FILE. Every behavioural
# row below reads the body back off the LIVE widget with `entrycget -command`
# and evaluates it at global level with `viewdata` and `alert_` renamed to
# recorders. Nothing here scans source text for a literal. That matters at this
# site twice over: the sentence a user reads is an argument inside a registered
# menu body, and a text scan would also match the prose in this very header
# (the defect row BM05 of test_wave_sigbrowser.tcl shipped, where a comment
# quoting a signature became the row's own evidence).
#
# NEEDS A DISPLAY. The subject is Tk menu entries; `build_widgets` builds no
# menubar under --nogui, so the whole file self-skips there and it is registered
# in `dcases` ALONE. Measured with banner_complete from tests/banner_rule.tcl on
# both captured arms before registering, per the rule that a suite's own green
# run says nothing about whether it can be registered.
#   tests/headless/run_suites.sh test_viewjob_silence

if {[catch {winfo exists .}] || ![winfo exists .]} {
  puts "RESULT: SKIP (needs Tk/X; the subject is a menu)"
  puts "OVERALL: ok (0 checks -- no X)"
  flush stdout
  exit 0
}

set fail 0
set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name ($got)" ; incr npass } \
  else { puts "FAIL: $name (got '$got' want '$want')" ; incr fail }
}

# The two sentences under ratification, written down ONCE here and compared
# against what the live menu body really passes to `alert_`. They are not
# grepped out of the product; VJ3/VE3 fail if the product's wording drifts.
set WANT_DATA  {No last job data: no job has run yet, or the last one wrote none.}
set WANT_ERROR {No last job errors: no job has run yet, or the last one reported none.}

set SIM .menubar.simulation

## ⚠ `$m index end` answers the WORD `none` for an empty menu, and
## `expr {$i <= none}` then RAISES. Measured while writing this file: the first
## spelling of the population walk below hit an empty menu in the live menubar
## tree, raised, and under --pipe the run produced NO output at all and had to
## be killed -- which reads exactly like a hang. Every loop over menu indices
## here goes through this guard.
proc menu_last {m} {
  if {![winfo exists $m]} { return -1 }
  if {[catch {$m index end} last]} { return -1 }
  if {![string is integer -strict $last]} { return -1 }
  return $last
}

## A missing entry must red ONE row, not abort the file: `$m entrycget -1` raises
## and under --pipe that stops the script dead, so a renamed label would read as
## a total collapse instead of one failure.
proc entry_index {m label} {
  set last [menu_last $m]
  for {set i 0} {$i <= $last} {incr i} {
    if {[catch {$m entrycget $i -label} l]} { continue }
    if {$l eq $label} { return $i }
  }
  return -1
}

# --- the recorders ------------------------------------------------------------
# `viewdata` and `::xschem::notify` are renamed, not shadowed, so the body cannot
# reach the real ones: the real `viewdata` would map a toplevel per row, and the
# real notice channel would open its popup sink.
#
# ⚠ THE SPY IS ON `::xschem::notify`, NOT ON `alert_`, AND THE REASON IS A
# REGRESSION THIS SUITE'S FIRST CUT SHIPPED. The entries originally reported
# through `alert_`, which builds a FIXED `.alert` toplevel with its `grab set`
# commented out -- so clicking these two ADJACENT entries in turn re-entered it
# and the second `toplevel .alert` threw `window name "alert" already exists in
# parent` out of a menu `-command`, i.e. Tk's background-error dialog instead of
# a message. Band VR below is the row that would have caught it, and it is kept
# deliberately: it asserts the entries use a channel that survives being called
# twice, by CALLING IT TWICE, rather than asserting the name of the channel.
## ⚠⚠ `alert_` IS RENAMED TOO, AND NOT BECAUSE ANY ROW SPIES ON IT. It is the
## channel these entries were FIXED AWAY FROM, and it ends in
## `tkwait window .alert` -- so if a future edit routes either entry back through
## it, the real `alert_` would BLOCK and this suite would HANG rather than fail.
## Measured: with `alert_` restored at both call sites and this rename removed,
## the display arm stopped producing any verdict at all and had to be killed by
## the driver's timeout. **A stall is a worse diagnostic than a red** -- it reads
## as a broken harness and sends the next reader to the wrong place -- so the
## recorder stays and row VJ2x/VE2x turns that regression into one named failing
## row. The original author of this file guarded the same way for the same
## reason; removing the guard when the spy moved was the mistake.
set ::vj_rec {}
rename viewdata vj_real_viewdata
rename ::xschem::notify ::vj_real_notify
rename alert_ vj_real_alert_
proc viewdata {args} { lappend ::vj_rec [linsert $args 0 viewdata] ; return }
proc ::xschem::notify {args} { lappend ::vj_rec [linsert $args 0 notify] ; return 1 }
proc alert_ {args} { lappend ::vj_rec [linsert $args 0 alert_] ; return 1 }

proc vj_restore {} {
  catch {rename viewdata {}}
  catch {rename ::xschem::notify {}}
  catch {rename alert_ {}}
  catch {rename vj_real_viewdata viewdata}
  catch {rename ::vj_real_notify ::xschem::notify}
  catch {rename vj_real_alert_ alert_}
}

## Evaluate the live menu body the way Tk evaluates it: at GLOBAL level. The
## registered bodies name `execute(data,last)` unqualified, so running them
## inside a proc's scope would reach a local array that does not exist and every
## row would observe the unset branch whatever the state.
proc fire {m i} {
  set ::vj_rec {}
  uplevel #0 [$m entrycget $i -command]
  return $::vj_rec
}
proc rec_count {rec what} {
  set n 0
  foreach c $rec { if {[lindex $c 0] eq $what} { incr n } }
  return $n
}
proc rec_arg {rec what k} {
  foreach c $rec { if {[lindex $c 0] eq $what} { return [lindex $c [expr {$k + 1}]] } }
  return {<no-such-call>}
}

# --- the derivation -----------------------------------------------------------
## THE POPULATION, DERIVED FROM THE LIVE MENUBAR AND NOT FROM A LIST KEPT HERE.
## Members are menu entries whose WHOLE `-command` body parses as a three
## element Tcl list headed by `if` -- which is precisely "an `if` with no else
## that is the only command the entry runs": `if cond body` is three words,
## while `if cond body else body` is five and `if cond body elseif ...` is more.
## The walk is iterative with a visited dict because a cascade's `-menu` need
## not be a child of the menu that cascades to it, and following both links
## recursively re-visits.
proc vj_menus {} {
  set work [list .menubar]
  set seen [dict create]
  set ms {}
  while {[llength $work]} {
    set w [lindex $work 0]
    set work [lrange $work 1 end]
    if {[dict exists $seen $w]} continue
    dict set seen $w 1
    if {![winfo exists $w]} continue
    if {[winfo class $w] ne {Menu}} continue
    lappend ms $w
    foreach c [winfo children $w] { lappend work $c }
    set last [menu_last $w]
    for {set i 0} {$i <= $last} {incr i} {
      if {[catch {$w type $i} t]} continue
      if {$t ne {cascade}} continue
      if {[catch {$w entrycget $i -menu} sub]} continue
      if {$sub ne {}} { lappend work $sub }
    }
  }
  return [lsort $ms]
}

# Returns a dict: members -> list of {menu index label}, scanned -> entries that
# carried a non-blank -command, menus -> menu widgets reached.
proc vj_population {} {
  set ms [vj_menus]
  set members {}
  set scanned 0
  foreach m $ms {
    set last [menu_last $m]
    for {set i 0} {$i <= $last} {incr i} {
      if {[catch {$m entrycget $i -command} b]} continue
      if {[string trim $b] eq {}} continue
      incr scanned
      if {[catch {llength $b} L]} continue
      if {$L != 3} continue
      if {[lindex $b 0] ne {if}} continue
      set lbl {} ; catch {set lbl [$m entrycget $i -label]}
      lappend members [list $m $i $lbl]
    }
  }
  return [dict create members $members scanned $scanned menus [llength $ms]]
}

proc vj_has_label {members label} {
  foreach e $members { if {[lindex $e 2] eq $label} { return 1 } }
  return 0
}

# =============================================================================
# L1 -- the subjects exist
# =============================================================================
set iD [entry_index $SIM {View last job data}]
set iE [entry_index $SIM {View last job errors}]
check "L1a label scan of .menubar.simulation finds 'View last job data'" \
      [expr {$iD >= 0}] 1
check "L1b label scan of .menubar.simulation finds 'View last job errors'" \
      [expr {$iE >= 0}] 1

if {$iD < 0 || $iE < 0} {
  vj_restore
  puts "RESULT: $fail FAILED ($npass passed) -- entries not found, behavioural rows not run"
  puts "OVERALL: notok"
  flush stdout
  exit 1
}

# =============================================================================
# VJ / VE -- the three states of each slot, driven through the live body
# =============================================================================
# state 1: the slot does not exist (a fresh session)
unset -nocomplain ::execute(data,last)
unset -nocomplain ::execute(error,last)

set r [fire $SIM $iD]
check "VJ1 data entry, slot UNSET: live body calls the notice channel exactly once AND alert_ never -- the channel these entries were fixed away from, whose second call raises an 'already exists in parent' error on its fixed window name, out of a menu -command" \
      [list [rec_count $r notify] [rec_count $r alert_]] {1 0}
check "VJ2 data entry, slot UNSET: live body calls viewdata zero times" \
      [rec_count $r viewdata] 0
check "VJ3 data entry, slot UNSET: the notice's argument 0 is the ratified sentence" \
      [rec_arg $r notify 0] $WANT_DATA

set r [fire $SIM $iE]
check "VE1 errors entry, slot UNSET: live body calls the notice channel exactly once AND alert_ never -- the channel these entries were fixed away from, whose second call raises an 'already exists in parent' error on its fixed window name, out of a menu -command" \
      [list [rec_count $r notify] [rec_count $r alert_]] {1 0}
check "VE2 errors entry, slot UNSET: live body calls viewdata zero times" \
      [rec_count $r viewdata] 0
check "VE3 errors entry, slot UNSET: the notice's argument 0 is the ratified sentence" \
      [rec_arg $r notify 0] $WANT_ERROR

# state 2: the slot EXISTS and is EMPTY -- what execute_fileevent leaves behind
# after a clean run. The old body took this for a hit and opened a blank window.
set ::execute(data,last)  {}
set ::execute(error,last) {}

set r [fire $SIM $iD]
check "VJ4 data entry, slot EXISTS but EMPTY: live body calls the notice channel exactly once AND alert_ never -- the channel these entries were fixed away from, whose second call raises an 'already exists in parent' error on its fixed window name, out of a menu -command" \
      [list [rec_count $r notify] [rec_count $r alert_]] {1 0}
check "VJ5 data entry, slot EXISTS but EMPTY: live body calls viewdata zero times" \
      [rec_count $r viewdata] 0
check "VJ6 data entry, slot EXISTS but EMPTY: the notice's argument 0 is the ratified sentence" \
      [rec_arg $r notify 0] $WANT_DATA

set r [fire $SIM $iE]
check "VE4 errors entry, slot EXISTS but EMPTY: live body calls the notice channel exactly once AND alert_ never -- the channel these entries were fixed away from, whose second call raises an 'already exists in parent' error on its fixed window name, out of a menu -command" \
      [list [rec_count $r notify] [rec_count $r alert_]] {1 0}
check "VE5 errors entry, slot EXISTS but EMPTY: live body calls viewdata zero times" \
      [rec_count $r viewdata] 0
check "VE6 errors entry, slot EXISTS but EMPTY: the notice's argument 0 is the ratified sentence" \
      [rec_arg $r notify 0] $WANT_ERROR

# state 3: the slot carries real content -- the ONLY state that may open a
# window, and it must carry the slot's own value through unchanged. The two
# payloads differ from each other so a body reading the wrong slot reddens.
set ::execute(data,last)  "VJ-PAYLOAD-data\nsecond line"
set ::execute(error,last) "VE-PAYLOAD-error\nsecond line"

set r [fire $SIM $iD]
check "VJ7 data entry, slot NON-EMPTY: live body calls viewdata exactly once" \
      [rec_count $r viewdata] 1
check "VJ8 data entry, slot NON-EMPTY: live body calls the notice channel zero times and alert_ zero times" \
      [list [rec_count $r notify] [rec_count $r alert_]] {0 0}
check "VJ9 data entry, slot NON-EMPTY: viewdata argument 0 is execute(data,last) verbatim" \
      [rec_arg $r viewdata 0] $::execute(data,last)

set r [fire $SIM $iE]
check "VE7 errors entry, slot NON-EMPTY: live body calls viewdata exactly once" \
      [rec_count $r viewdata] 1
check "VE8 errors entry, slot NON-EMPTY: live body calls the notice channel zero times and alert_ zero times" \
      [list [rec_count $r notify] [rec_count $r alert_]] {0 0}
check "VE9 errors entry, slot NON-EMPTY: viewdata argument 0 is execute(error,last) verbatim" \
      [rec_arg $r viewdata 0] $::execute(error,last)

unset -nocomplain ::execute(data,last)
unset -nocomplain ::execute(error,last)

# =============================================================================
# P -- the derived population of if/no-else-only menu entries
# =============================================================================
set pop [vj_population]
set members [dict get $pop members]
puts "note: if/no-else-only population = [llength $members] of [dict get $pop scanned]\
 entries carrying a -command, across [dict get $pop menus] menus"
foreach e $members { puts "note:   member: [lindex $e 0] \[[lindex $e 1]\] |[lindex $e 2]|" }

check "P1 derived population (whole -command parses as a 3-list headed by if)\
 excludes 'View last job data'" [vj_has_label $members {View last job data}] 0
check "P2 derived population (whole -command parses as a 3-list headed by if)\
 excludes 'View last job errors'" [vj_has_label $members {View last job errors}] 0

## P3 -- NON-VACUITY, AND IT IS A BUILT CONTROL RATHER THAN A CLAIM. P1/P2 are
## absence claims, so a scan that found nothing at all would pass them both. The
## control plants an entry of exactly the shape being excluded and requires the
## SAME scan to find it, so the instrument cannot go quiet without reddening.
## It is planted on a throwaway menu under .menubar, which the walk reaches as a
## child, and torn down immediately.
catch {destroy .menubar.vj_control}
menu .menubar.vj_control -tearoff 0 -takefocus 0
.menubar.vj_control add command -label {VJ CONTROL} -command {
  if {[info exists ::vj_no_such_variable]} {
    set ::vj_unreachable 1
  }
}
set ctl [dict get [vj_population] members]
check "P3 non-vacuity: the same scan finds a planted if/no-else entry" \
      [vj_has_label $ctl {VJ CONTROL}] 1
destroy .menubar.vj_control
check "P3b the planted control is gone again after teardown" \
      [vj_has_label [dict get [vj_population] members] {VJ CONTROL}] 0

## P4/P5 -- FLOORS, i.e. ratchets and not baselines. They exist so a walk that
## silently stops early (an added empty menu used to raise and kill the run
## outright; a cascade link that stops being followed would just shrink the
## reach) cannot make P1/P2 pass by inspecting almost nothing. Raise them when
## the tree grows; never lower them to clear a red.
check "P4 floor: the scan inspected at least 200 entries carrying a -command" \
      [expr {[dict get $pop scanned] >= 200}] 1
check "P5 floor: the walk reached at least 20 menu widgets" \
      [expr {[dict get $pop menus] >= 20}] 1

## =============================================================================
## BAND VR -- THE CHANNEL SURVIVES BEING CALLED TWICE, ASSERTED BY CALLING IT
## TWICE ON THE REAL ONE.
##
## This band exists because the first cut of this fix reported through `alert_`,
## and the two entries it serves are ADJACENT and both about the last job. So the
## ordinary gesture -- look at the data, then look at the errors -- re-entered a
## proc that builds a FIXED `.alert` toplevel and blocks in `tkwait window
## .alert` with its `grab set` commented out, and the second `toplevel .alert`
## threw `window name "alert" already exists in parent` out of a menu `-command`.
## The user got Tk's background-error dialog where the point of the change was to
## replace silence with a sentence.
##
## ⚠ IT ASSERTS THE PROPERTY, NOT THE NAME OF THE CHANNEL. A row reading "the
## body calls ::xschem::notify" would pass against any future channel with the
## same name and the same defect, and would redden on a rename that changed
## nothing. So VR restores the real channel, calls it TWICE with the two
## sentences the entries really pass, and requires no raise -- which is the thing
## the user experiences. VR3 is the control: it drives `alert_` the same way and
## requires the raise to STILL happen, so a tree where `alert_` had been made
## re-entrant for other reasons could not make VR1/VR2 vacuous.
## ⚠ THE RETURN CODE, NOT THE CATCH VARIABLE. `catch script var` writes the
## RESULT into `var` on success and the error message into it only on failure, so
## a row asserting `$var eq {}` reads a healthy channel's own sink account as a
## fault -- which is how the first draft of this band went red against correct
## code. The code is the only thing that distinguishes raise from return.
vj_restore
set vr_rc1 [catch {::xschem::notify $WANT_DATA}  vr_out1]
set vr_rc2 [catch {::xschem::notify $WANT_ERROR} vr_out2]
check "VR1 the real notice channel does not raise on the FIRST of the two sentences" \
      $vr_rc1 0
check "VR2 ...nor on the SECOND, called straight after it with no dismissal in between -- which is the adjacent-entry gesture that threw before" \
      $vr_rc2 0
check "VR2b ...and it leaves no fixed-name modal standing for the next caller to collide with, which is the property alert_ lacks" \
      [winfo exists .alert] 0

## VR3 -- the control. `alert_` is the channel this fix moved AWAY from, and the
## reason is that a second call raises. Driven with `nowait` so the first does not
## block the suite, then the second is required to raise and the box is torn down.
## If this ever stops raising, VR1/VR2 have stopped discriminating and this row is
## what says so.
set vr_a1 [catch {alert_ {VR CONTROL first}  +200+300 1} vr_ao1]
set vr_a2 [catch {alert_ {VR CONTROL second} +200+300 1} vr_ao2]
catch {destroy .alert}
check "VR3 control: the FIRST alert_ returns and the SECOND raises on the fixed window name, so VR1/VR2 are measuring a difference rather than a constant" \
      [list $vr_a1 $vr_a2 [string match {*already exists*} $vr_ao2]] {0 1 1}

## VR4 -- and the notice really reached a sink rather than being swallowed. The
## channel returns the sink account, so a non-empty answer is the evidence; a
## channel that caught everything internally and reported nothing would pass
## VR1/VR2 and fail here.
set vr_ret {}
set vr_rc4 [catch {::xschem::notify {VR SINK PROBE}} vr_ret]
check "VR4 the channel reports having delivered to at least one sink, so a channel that swallowed everything internally could not pass VR1/VR2 quietly" \
      [list $vr_rc4 [expr {$vr_ret ne {} && $vr_ret ne 0}]] {0 1}

# --- restore ------------------------------------------------------------------
vj_restore

if {$fail == 0} { puts "OVERALL: ok ($npass checks)" } else { puts "OVERALL: notok" }
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
