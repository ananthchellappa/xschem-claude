# test_sim_dialog.tcl — THE SIMULATOR DIALOG. Casemode batch item 13;
# PLAN.md section 3b item 13; DECISIONS.md B1 (extend the existing simconf, no
# new registry), A1 (probe-driven pre-fill; nobody may select a mode their
# simulator will silently ignore), A2 (the per-profile -n checkbox), B3
# (auto-probe gated on the executable's NAME + the hard timeout).
# Spec: doc/claude/specs/simulator_profiles.md section 17.
#
# WHAT THIS ITEM IS. Item 6 built the field model and wrote no widget; item 7
# built the probe and wrote no widget. This is the widget, bolted onto the
# dialog xschem already has, and its payload is PIXELS -- so this file cannot
# be the whole evidence and the item is [E]. What a file CAN pin is the
# behaviour underneath: what commits to sim() and when, which modes the menu
# offers, when a process is launched, and that a pre-batch simrc still comes
# back out byte for byte.
#
# THE LOAD-BEARING CHECKS, and why:
#   SDG5    THE COMMIT POINT, and it is the check this item exists for. Measured
#           twice before this item (casemode 9 and 11, pinned by
#           test_ase_dialogs G13): `::set_sim_defaults` IS NOT A READ -- with
#           `.sim` open it slurps every `...r.$i.cmd` widget into sim(), so a
#           question asked from anywhere committed the user's half-typed edits
#           and Cancel could not take them back. SDG5 types into the cmd box,
#           edits a -textvariable field AND the new Exe box, forces the slurp,
#           asserts the slurp really happened (or the check would be vacuous),
#           then cancels and requires every one of them back.
#   SDG7    A1, as the menu. `sim_profile_selectable` is built from what the
#           probe MEASURED, so an unprobed row offers `fold` and nothing else, a
#           probed one offers exactly what came back, and a row measured to
#           deliver nothing offers nothing. A constant three-mode list passes
#           none of the three.
#   SDG7d   the other half of A1: a mode STORED on the row that was never
#           measured (a hand-edited simrc, or a binary that moved under the
#           path) is DISPLAYED with a warning and is NOT an entry in the menu.
#           Hiding it would lose a real setting; offering it would break A1.
#   SDG9    B3's gate, both ways, with two stand-ins that differ ONLY in their
#           filename. The `zzz`-named one must not be launched by an Add and
#           must still be measurable with Test -- that is B3's whole bargain
#           (no licence checkout for a typed path; a deliberate click instead).
#   SDG9c   the gate is `on Add` and nothing else: an EXISTING row is never
#           auto-probed, however it is named.
#   SDG11   the probe is called ONCE per click. The stand-in counts its own
#           invocations, so a retry loop -- the frozen-window shape B3's hard
#           timeout exists to prevent -- shows up as 6 legs instead of 3.
#   SDG12   the hard timeout survives the trip through the dialog, driven by
#           actually hanging it, and a timed-out probe records NOTHING (item 7's
#           ruling) while still SAYING so on the row.
#   SDG14   BACKWARD COMPATIBILITY. A pre-item-6 simrc opened in this dialog and
#           accepted-and-saved must come back byte-identical: a dialog that
#           rewrote rows on open, reordered them, or wrote a profile field
#           nobody set would break the property item 6 froze a fixture for.
#
# GUI LEGS. The dialog is Tk, so SDG4..SDG6, SDG13 and SDG14 need a display and
# self-skip with a `note:` line when there is none -- never a column-0 skip
# banner, which full_audit.sh scores as a skip for the WHOLE FILE, silently
# discarding every check that did run. The model legs run either way.
#
# NO REAL SIMULATOR IS NEEDED. Every probe here runs a /bin/sh stand-in, so this
# file does not depend on the private ver_50 build. The stand-ins `exec` what
# they run (item 7's lesson: a wrapper that does not exec orphans the child the
# probe's kill cannot reach).
#
# Run from the repo root, on a display:
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog \
#       --script tests/headless/test_sim_dialog.tcl
# or true headless (model legs only):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_sim_dialog.tcl

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
# every call goes through this: a proc that does not exist yet must FAIL a
# check, never abort the file with no RESULT line
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
proc dg {d k} {
  if {[catch {dict get $d $k} v]} { return "NO:$k" }
  return $v
}
# abort-proofing: a bare $::simconf_ui(...) raises when the staging area was
# never built (a sabotage, or a proc that does not exist yet), which ends the
# file with NO RESULT line -- under which every sabotage reads as "nothing went
# red". Every READ below goes through this.
proc ui {tool i f} {
  if {[info exists ::simconf_ui($tool,$i,$f)]} { return $::simconf_ui($tool,$i,$f) }
  return "NOUI"
}
proc uistatus {} {
  if {[info exists ::simconf_ui(status)]} { return $::simconf_ui(status) }
  return "NOUI"
}
# the labels of a real Tk menu, abort-proof: a sabotage that deletes the menu
# must redden a check, not end the file with no RESULT line
# ABORT-PROOFING (the batch carry-forward from items 1, 2, 5b and 6): arithmetic
# on a value a sabotaged proc could not produce raises, and a raise ends the file
# with NO RESULT line -- under which every sabotage reads as "nothing went red".
proc intof {v} {
  if {[string is integer -strict $v]} { return $v }
  return -1
}
proc menulabels {m} {
  if {![winfo exists $m]} { return NOMENU }
  set out {}
  for {set k 0} {$k <= [$m index end]} {incr k} { lappend out [$m entrycget $k -label] }
  return $out
}
proc slurp {p} {
  if {[catch {open $p rb} f]} { return "ERR:$f" }
  set d [read $f]; close $f; return $d
}
proc fake {dir name body} {
  set p [file join $dir $name]
  set f [open $p w]
  puts $f "#!/bin/sh"
  puts $f $body
  close $f
  file attributes $p -permissions 0755
  return $p
}

set here   [file normalize [file dirname [info script]]]
set fixdir [file join $here fixtures]
set tmp    [test_scratch simdialog]
set fdir   [file join $tmp bin] ; file mkdir $fdir

# an isolated USER_CONF_DIR: nothing here may touch the developer's ~/.xschem
set ::USER_CONF_DIR [file join $tmp conf]
file mkdir $::USER_CONF_DIR

# THE THIRD CHANNEL. Item 14's house rule: a report must reach somewhere a user
# reads. Two of this dialog's channels are widgets (the row note, the bottom
# status line) and are asserted directly; the CIW pane is the third, and nothing
# else in this file would notice if it went away. Recorded here, and the real
# ciw_echo still runs underneath.
set ::ciwlog {}
if {[info procs ciw_echo] ne {}} { rename ciw_echo sdg_real_ciw_echo }
proc ciw_echo {line {tag {}}} {
  lappend ::ciwlog [list $tag $line]
  if {[info procs sdg_real_ciw_echo] ne {}} { catch {sdg_real_ciw_echo $line $tag} }
}

set HASX [expr {[info exists ::has_x] ? 1 : 0}]
puts "note: Tk available = $HASX  (the dialog legs need a display)"

proc dlgopen {} {
  if {![info exists ::has_x]} { return 0 }
  return [expr {[winfo exists .sim] ? 1 : 0}]
}
proc load_builtin_defaults {} {
  global USER_CONF_DIR
  # a LEFT-OPEN dialog is fatal to the next reload and that is not a product
  # defect: set_sim_defaults' first loop walks sim(tool_list) to slurp the cmd
  # widgets, so `unset sim` with .sim alive makes it raise and the array is never
  # rebuilt. A sabotage that breaks the close path must not take the rest of this
  # file with it.
  if {[dlgopen]} { catch {destroy .sim} }
  file delete -force [file join $USER_CONF_DIR simrc]
  if {[info exists ::sim]} { unset ::sim }
  # pcall'd everywhere in this file: set_sim_defaults' own first loop reaches
  # `...r.$i.cmd` UNGUARDED when .sim exists, so a sabotage that renames or
  # removes that widget would abort the file with no RESULT line
  pcall set_sim_defaults
}
# append a configured row; returns its index
proc add_row {tool name exe} {
  set i $::sim($tool,n)
  set ::sim($tool,$i,cmd)  "$exe \"\$N\""
  set ::sim($tool,$i,name) $name
  set ::sim($tool,$i,exe)  $exe
  incr ::sim($tool,n)
  pcall set_sim_defaults
  return $i
}

# --- the stand-ins ---------------------------------------------------------
# echoes back the mode it was asked for: "supports all three"
set sh_echo {m=fold
for a in "$@"; do case "$a" in casemode=*) m=${a#casemode=};; esac; done
echo CCM=$m}
# a released-ngspice shape: no such variable + an empty CCM=
set sh_stock "echo 'Error: curcasemode: no such variable.'\necho CCM="
# never answers anything we recognise
set sh_mute {echo CCM=sideways}

set f_ng     [fake $fdir ngspice_echo   $sh_echo]
set f_zzz    [fake $fdir zzz_echo       $sh_echo]
set f_stock  [fake $fdir ngspice_stock  $sh_stock]
set f_none   [fake $fdir ngspice_none   $sh_mute]
set countf   [file join $tmp legs.txt]
set f_hang   [fake $fdir ngspice_hang   "echo leg >> $countf\nexec sleep 120"]
set f_count  [fake $fdir ngspice_count  "echo leg >> $countf\n$sh_echo"]
proc legs {} { 
  global countf
  if {![file exists $countf]} { return 0 }
  return [llength [split [string trim [slurp $countf]] \n]]
}

# ===========================================================================
# A — STAGING: the new fields do not reach sim() until a commit point
# ===========================================================================
load_builtin_defaults
eqcheck SDG1-staged-fields-are-the-four-editable-ones \
  [pcall simconf_stage_fields] {exe args casemode nospiceinit}
# `detected`/`probed` are deliberately NOT staged: they are a measurement, not
# an edit, and no widget can type them
check SDG1b-measurement-fields-are-not-staged \
  [expr {[lsearch -exact [pcall simconf_stage_fields] detected] < 0 &&
         [lsearch -exact [pcall simconf_stage_fields] probed] < 0}] {}

set i0 [add_row spice {Row under test} $f_ng]
pcall simconf_stage_all
eqcheck SDG2-staging-seeds-from-the-model \
  "exe=[expr {[ui spice $i0 exe] eq $f_ng}] cm=<[ui spice $i0 casemode]>\
 nsi=[ui spice $i0 nospiceinit]" {exe=1 cm=<> nsi=0}

# typing into a staged field must NOT be visible in sim() ...
set ::simconf_ui(spice,$i0,exe) /nowhere/typed-but-not-committed
set ::simconf_ui(spice,$i0,nospiceinit) 1
eqcheck SDG2b-a-staged-edit-does-not-reach-sim \
  "exe=[pcall sim_profile_get spice $i0 exe] nsi=[pcall sim_profile_get spice $i0 nospiceinit]" \
  "exe=$f_ng nsi=0"
# ... until the commit
eqcheck SDG2c-commit-writes-the-staged-values \
  "errs=[llength [pcall simconf_commit_row spice $i0]]\
 exe=[pcall sim_profile_get spice $i0 exe]\
 nsi=[pcall sim_profile_get spice $i0 nospiceinit]" \
  {errs=0 exe=/nowhere/typed-but-not-committed nsi=1}

# A2's -n is a real per-profile field and it reaches the probe's argv
eqcheck SDG3-A2s--n-checkbox-field-reaches-the-argv \
  [pcall sim_probe_argv {} preserve [pcall sim_profile_get spice $i0 nospiceinit]] \
  {-b -n -D casemode=preserve}

# a value the persister could not write back is REFUSED and REPORTED, and the
# stored value survives -- a typo must not destroy a working setting
set ::simconf_ui(spice,$i0,exe) "bad\}brace"
set errs [pcall simconf_commit_row spice $i0]
eqcheck SDG3b-an-unwritable-value-is-refused-and-the-old-one-survives \
  "n=[llength $errs] field=[lindex [lindex $errs 0] 2]\
 kept=[pcall sim_profile_get spice $i0 exe]" \
  {n=1 field=exe kept=/nowhere/typed-but-not-committed}
pcall simconf_report_errors $errs
check SDG3e-the-refusal-also-reaches-the-CIW-pane-at-tag-error \
  [expr {[lsearch -glob $::ciwlog {error *exe rejected*}] >= 0}] "(ciw='$::ciwlog')"
check SDG3c-the-refusal-is-reported-on-the-dialogs-status-line \
  [expr {[string match {*exe rejected*} [uistatus]] &&
         [string match {*INVALID exe*} [ui spice $i0 probenote]]}] \
  "(status='[uistatus]')"
# args must be a Tcl list, and that is the other refusal a user can type
set ::simconf_ui(spice,$i0,exe) $f_ng
set ::simconf_ui(spice,$i0,args) "\{unbalanced"
eqcheck SDG3d-an-unparsable-args-list-is-refused \
  [lindex [lindex [pcall simconf_commit_row spice $i0] 0] 2] {args}
set ::simconf_ui(spice,$i0,args) {}
pcall simconf_commit_row spice $i0

# ===========================================================================
# B — A1: THE CASE MENU IS BUILT FROM WHAT THE PROBE MEASURED
# ===========================================================================
proc menuvals {tool i} {
  set out {}
  foreach e [pcall simconf_mode_menu_items $tool $i] { lappend out [lindex $e 1] }
  return $out
}
# never probed: the floor entry and `fold`. NOT the three modes.
eqcheck SDG7-an-unprobed-row-offers-only-fold \
  [menuvals spice $i0] [list {} fold]
# measured to deliver all three: all three
pcall sim_profile_probe_record spice $i0 {fold preserve distinguish}
eqcheck SDG7b-a-measured-row-offers-exactly-what-was-measured \
  [menuvals spice $i0] [list {} fold preserve distinguish]
# measured to deliver only preserve: only preserve (and NOT fold, which is what
# a constant list or a "fold is always safe" shortcut would add back)
pcall sim_profile_probe_record spice $i0 {preserve}
eqcheck SDG7c-a-partial-binary-offers-only-its-own-modes \
  [menuvals spice $i0] [list {} preserve]
# measured and delivers nothing we recognise: nothing but the floor
pcall sim_profile_probe_record spice $i0 {}
eqcheck SDG7e-a-binary-measured-to-deliver-nothing-offers-nothing \
  [menuvals spice $i0] [list {}]
# a mode STORED on the row that was never measured: shown with a warning,
# and NOT offered
pcall sim_profile_probe_record spice $i0 {fold}
pcall sim_profile_set spice $i0 casemode distinguish
set ::simconf_ui(spice,$i0,casemode) distinguish
eqcheck SDG7d-an-unmeasured-stored-mode-is-shown-marked-and-not-offered \
  "label='[pcall simconf_mode_label spice $i0 distinguish]'\
 offered=[expr {[lsearch -exact [menuvals spice $i0] distinguish] >= 0}]" \
  {label='distinguish (NOT measured)' offered=0}
# the floor entry names the floor it will actually use
set keepfloor $::sim_case_mode
pcall sim_profile_probe_record spice $i0 {fold preserve}
set ::sim_case_mode preserve
eqcheck SDG7f-the-floor-entry-names-the-floor \
  [pcall simconf_mode_label spice $i0 {}] {use global default (preserve)}
# A1'S ONE SEAM, and it is now SAID rather than left implicit. B1 mandates that
# the "use global default" entry exist -- an empty casemode is a real and
# different setting -- so it cannot be filtered out of the menu the way an
# unmeasured mode is. But with a non-fold floor it is a selectable route to
# REQUESTING a mode this row was measured not to deliver, which is the exception
# to A1's "nobody can select a mode their simulator will silently ignore".
# MEASURED before the fix: floor `distinguish` on a row measured to deliver
# {fold preserve} gave the entry `use global default (distinguish)` with no hint
# at all, while sim_profile_supports answered 0 for that very mode.
set ::sim_case_mode distinguish
eqcheck SDG7h-a-floor-this-row-cannot-deliver-is-marked-in-the-entry \
  "label='[pcall simconf_mode_label spice $i0 {}]'\
 entry0='[lindex [lindex [pcall simconf_mode_menu_items spice $i0] 0] 0]'\
 supports=[pcall sim_profile_supports spice $i0 distinguish]" \
  {label='use global default (distinguish - NOT measured)' entry0='use global default (distinguish - NOT measured)' supports=0}
# ...and a floor the row CAN deliver is not marked, or the mark would be noise
# on every row instead of a warning
set ::sim_case_mode fold
eqcheck SDG7i-a-floor-this-row-can-deliver-is-NOT-marked \
  [pcall simconf_mode_label spice $i0 {}] {use global default (fold)}
set ::sim_case_mode sideways
eqcheck SDG7g-a-garbage-floor-is-not-a-request \
  [pcall simconf_mode_label spice $i0 {}] {use global default (fold)}
set ::sim_case_mode $keepfloor
set ::simconf_ui(spice,$i0,casemode) {}
pcall sim_profile_set spice $i0 casemode {}

# ===========================================================================
# C — B3's AUTO-PROBE GATE, and the Test button
# ===========================================================================
load_builtin_defaults
pcall simconf_stage_all
# an EXISTING row is never auto-probed -- the arm is set by Add and by nothing
# else, whatever the executable is called
set iexist [add_row spice {existing ngspice row} $f_count]
pcall simconf_stage_row spice $iexist
set before [legs]
eqcheck SDG9c-an-existing-row-is-never-auto-probed \
  "reason=[dg [pcall simconf_row_register spice $iexist] reason] legs=[expr {[legs]-$before}]" \
  {reason=notarmed legs=0}

# ADD arms exactly one row
set iadd [intof [pcall simconf_add_gui spice]]
eqcheck SDG8-Add-appends-a-row-and-arms-it \
  "n=$::sim(spice,n) armed=[ui spice $iadd autoprobe]\
 shaped=[info exists ::sim(spice,$iadd,nospiceinit)]" \
  "n=[expr {$iadd+1}] armed=1 shaped=1"
# an armed row with no exe stays armed and probes nothing
set before [legs]
eqcheck SDG8b-an-armed-row-with-no-exe-stays-armed \
  "reason=[dg [pcall simconf_row_register spice $iadd] reason]\
 armed=[ui spice $iadd autoprobe] legs=[expr {[legs]-$before}]" \
  {reason=noexe armed=1 legs=0}

# B3's NAME GATE, both ways, with two stand-ins that differ ONLY in filename.
set izzz [intof [pcall simconf_add_gui spice]]
set ::simconf_ui(spice,$izzz,exe) $f_zzz
set before [legs]
set rz [pcall simconf_row_register spice $izzz]
eqcheck SDG9-a-non-ngspice-named-exe-is-NOT-auto-launched \
  "probed=[dg $rz probed] reason=[dg $rz reason] legs=[expr {[legs]-$before}]\
 detected=[pcall sim_profile_detected spice $izzz]" \
  {probed=0 reason=namegate legs=0 detected=}
check SDG9b-and-the-row-SAYS-why-and-points-at-Test \
  [string match {*not auto-probed*Test*} [ui spice $izzz probenote]] \
  "(note='[ui spice $izzz probenote]')"
# ... but Test measures it: B3 refuses to LAUNCH it, never to support it
set before [legs]
set rt [pcall simconf_test_row spice $izzz]
eqcheck SDG10-Test-measures-the-binary-B3-refused-to-auto-launch \
  "status=[dg $rt status] detected=[dg $rt detected] recorded=[dg $rt recorded]\
 stored=[pcall sim_profile_detected spice $izzz]" \
  {status=ok detected=fold preserve distinguish recorded=1 stored=fold preserve distinguish}
# and NOW the menu offers all three -- the same row that offered `fold` alone
eqcheck SDG10b-the-menu-grew-because-the-binary-was-measured \
  [menuvals spice $izzz] [list {} fold preserve distinguish]

# an ngspice-NAMED exe on an armed row IS auto-probed
set ing [intof [pcall simconf_add_gui spice]]
set ::simconf_ui(spice,$ing,exe) $f_ng
set rg [pcall simconf_row_register spice $ing]
eqcheck SDG9d-an-ngspice-named-exe-on-an-added-row-IS-auto-probed \
  "probed=[dg $rg probed] reason=[dg $rg reason] detected=[dg $rg detected]\
 armed=[ui spice $ing autoprobe]" \
  {probed=1 reason=ok detected=fold preserve distinguish armed=0}

# A1's PRE-FILL, probe-driven and staged
eqcheck SDG6-the-prefill-is-the-first-mode-the-probe-measured \
  "staged=[ui spice $ing casemode] stored=[pcall sim_profile_get spice $ing casemode]" \
  {staged=fold stored=}
# it never overwrites a mode the user chose
set ipre [intof [pcall simconf_add_gui spice]]
set ::simconf_ui(spice,$ipre,exe) $f_ng
set ::simconf_ui(spice,$ipre,casemode) distinguish
pcall simconf_row_register spice $ipre
eqcheck SDG6b-the-prefill-never-overwrites-a-users-choice \
  [ui spice $ipre casemode] {distinguish}
# a released ngspice: `no such variable` is an ANSWER, so the row is offered
# `fold` and pre-filled `fold` -- A1's "no case support" clause, not a constant
set istk [intof [pcall simconf_add_gui spice]]
set ::simconf_ui(spice,$istk,exe) $f_stock
pcall simconf_row_register spice $istk
eqcheck SDG6c-a-released-ngspice-prefills-fold-and-offers-only-fold \
  "staged=[ui spice $istk casemode] menu=[menuvals spice $istk]\
 note=[string match {Test: no casemode support - fold only*} [pcall simconf_status_line spice $istk]]" \
  {staged=fold menu={} fold note=1}
# a binary measured to deliver nothing pre-fills NOTHING and offers nothing
set inone [intof [pcall simconf_add_gui spice]]
set ::simconf_ui(spice,$inone,exe) $f_none
pcall simconf_row_register spice $inone
eqcheck SDG6d-a-binary-that-delivers-nothing-prefills-nothing \
  "staged=<[ui spice $inone casemode]> menu=[menuvals spice $inone]\
 detected=<[pcall sim_profile_detected spice $inone]>" \
  {staged=<> menu={} detected=<>}

# ===========================================================================
# D — ONE PROBE PER CLICK, AND THE HARD TIMEOUT
# ===========================================================================
set icnt [intof [pcall simconf_add_gui spice]]
set ::simconf_ui(spice,$icnt,exe) $f_count
set before [legs]
pcall simconf_test_row spice $icnt
set one [expr {[legs]-$before}]
pcall simconf_test_row spice $icnt
set two [expr {[legs]-$before}]
# THREE legs per click (one per mode, item 7's ruling), and no retry loop
eqcheck SDG11-one-capability-probe-per-click-three-legs-no-retry \
  "click1=$one click2=$two" {click1=3 click2=6}

# THE HARD TIMEOUT, driven by hanging it. It bounds the WHOLE probe (item 7
# section 11.6: the first cut froze for 3x the budget), nothing is recorded,
# and the row SAYS so.
set keeptmo {}
if {[info exists ::sim_probe_timeout]} { set keeptmo $::sim_probe_timeout }
set ::sim_probe_timeout 700
set ihang [intof [pcall simconf_add_gui spice]]
set ::simconf_ui(spice,$ihang,exe) $f_hang
set t0 [clock milliseconds]
set before [legs]
pcall simconf_test_row spice $ihang
set el [expr {[clock milliseconds]-$t0}]
# ONE launch, not two: the whole-probe budget is spent by the first leg, the
# remaining legs are never started, and the dialog does NOT try again. A retry
# on a failed probe is the same frozen window per click, one layer up from the
# per-leg timeout item 7 removed.
eqcheck SDG12-a-hung-probe-is-bounded-records-nothing-and-says-so \
  "bounded=[expr {$el < 2100}] launches=[expr {[legs]-$before}]\
 probed=<[pcall sim_profile_get spice $ihang probed]> prefill=<[ui spice $ihang casemode]>\
 says=[string match {*TIMED OUT*} [ui spice $ihang probenote]]\
 offers=[menuvals spice $ihang]" \
  {bounded=1 launches=1 probed=<> prefill=<> says=1 offers={} fold}
puts "note: hung probe returned in ${el} ms with a 700 ms budget"
if {$keeptmo ne {}} { set ::sim_probe_timeout $keeptmo }

# every outcome item 7 can return has a sentence a human can read
set notes {}
foreach st {ok nocasemode partial timeout unknown error} {
  lappend notes [pcall simconf_probe_note [dict create status $st ms 12 detected {} recorded 0]]
}
# every one must be a real sentence starting `Test:`. An earlier version only
# asked that they were non-empty and free of `NO:` -- which the six
# `ERR:invalid command name` strings of a MASTER RED satisfied, i.e. the check
# passed with the proc deleted.
set legible 1
foreach n $notes { if {![string match {Test: ?*} $n]} { set legible 0 } }
check SDG12b-every-probe-outcome-has-a-legible-sentence \
  [expr {[llength $notes] == 6 && $legible}] "([join $notes { | }])"
# a THROW out of the probe must not leave the row saying `probing...`: a stuck
# progress message is indistinguishable from the frozen dialog B3's timeout
# exists to prevent
set ithrow [intof [pcall simconf_add_gui spice]]
set ::simconf_ui(spice,$ithrow,exe) $f_ng
if {[info procs sim_profile_probe_capability] ne {}} {
  rename sim_profile_probe_capability sdg_saved_cap
  proc sim_profile_probe_capability {args} { error {SDG-BOOM} }
}
pcall simconf_test_row spice $ithrow
if {[info procs sdg_saved_cap] ne {}} {
  rename sim_profile_probe_capability {}
  rename sdg_saved_cap sim_profile_probe_capability
}
check SDG12d-a-throw-out-of-the-probe-does-not-leave-the-row-probing \
  [expr {![string match {*probing*} [ui spice $ithrow note]] &&
         [string match {Test: *} [ui spice $ithrow note]]}] \
  "(note='[ui spice $ithrow note]')"

eqcheck SDG12c-a-recorded-measurement-names-the-modes \
  [pcall simconf_probe_note [dict create status ok ms 65 detected {fold preserve} recorded 1]] \
  {Test: delivers fold preserve (65 ms)}

# ===========================================================================
# E — THE DIALOG ITSELF (needs Tk)
# ===========================================================================
if {$HASX} {
  load_builtin_defaults
  set irow [add_row spice {dialog row} $f_count]
  # taken BEFORE the window is built: a probe fired while BUILDING a row is
  # exactly the "nothing on a redraw path" rule, and a baseline taken after the
  # build cannot see it
  set before [legs]
  pcall simconf
  update
  set row [pcall simconf_rowpath spice 0]
  eqcheck SDG4-the-dialog-opens-and-keeps-the-pre-item13-widget-paths \
    "sim=[winfo exists .sim] cmd=[winfo exists $row.cmd] lab=[winfo exists $row.lab]\
 radio=[winfo exists $row.radio] fg=[winfo exists $row.fg] st=[winfo exists $row.st]" \
    {sim=1 cmd=1 lab=1 radio=1 fg=1 st=1}
  eqcheck SDG4b-and-grows-the-profile-line \
    "exe=[winfo exists $row.prof.exe] args=[winfo exists $row.prof.arg]\
 mode=[winfo exists $row.prof.mode] nsi=[winfo exists $row.prof.nsi]\
 test=[winfo exists $row.prof.test] note=[winfo exists $row.prof.st]\
 add=[winfo exists .sim.bottom.add]" \
    {exe=1 args=1 mode=1 nsi=1 test=1 note=1 add=1}
  # the menu really is the model's list, in the widget
  set mw [pcall simconf_rowpath spice $irow].prof.mode.m
  set lbls {}
  set lbls [pcall menulabels $mw]
  eqcheck SDG4c-the-widget-menu-carries-exactly-the-models-entries \
    $lbls {{use global default (fold)} fold}
  # BUILDING THE DIALOG LAUNCHES NOTHING, and neither does Add
  pcall simconf_add_gui spice
  update
  eqcheck SDG4d-opening-and-adding-launch-no-process \
    [expr {[legs]-$before}] 0

  # ---- SDG5: the commit point, and Cancel ---------------------------------
  pcall simconf_cancel
  update
  load_builtin_defaults
  set irow [add_row spice {cancel row} $f_ng]
  pcall simconf
  update
  set row [pcall simconf_rowpath spice $irow]
  set cmd0  $::sim(spice,$irow,cmd)
  set name0 $::sim(spice,$irow,name)
  set exe0  [pcall sim_profile_get spice $irow exe]
  pcall $row.cmd delete 1.0 end
  pcall $row.cmd insert 1.0 {SDG-USER-IS-STILL-TYPING}
  pcall $row.lab insert end {-EDITED}
  set args0 [pcall sim_profile_get spice $irow args]
  set nsi0  [pcall sim_profile_get spice $irow nospiceinit]
  set mode0 [pcall sim_profile_get spice $irow casemode]
  pcall $row.prof.exe delete 0 end
  pcall $row.prof.exe insert 0 {/typed/but/never/accepted}
  update
  # THE STAGING CONTRACT, at the widget: typing in the Exe box does not reach
  # sim() at all. If the entry were bound straight to sim($tool,$i,exe) -- the
  # obvious wiring, and the one item 6's normalizer comment anticipated -- this
  # would already have overwritten a working configuration.
  eqcheck SDG5d-typing-in-the-Exe-box-does-not-reach-sim \
    "stored=[pcall sim_profile_get spice $irow exe] staged=[ui spice $irow exe]" \
    "stored=$exe0 staged=/typed/but/never/accepted"
  # ...AND THE SAME FOR THE OTHER THREE, each driven at its own widget. Pinning
  # only `exe` left the Args entry free to be bound straight to
  # sim($tool,$i,args): measured, that mutation bypasses the staging area AND
  # item 6's validation (so the unbalanced-brace refusal can never fire from the
  # widget) with all 53 checks green. The Case menu entry and the -n checkbutton
  # get the same treatment.
  pcall $row.prof.arg delete 0 end
  pcall $row.prof.arg insert 0 {-r /typed/never/accepted.raw}
  pcall $row.prof.nsi invoke
  set mpick [pcall simconf_rowpath spice $irow].prof.mode.m
  set mi [lsearch -exact [pcall menulabels $mpick] fold]
  if {$mi >= 0} { pcall $mpick invoke $mi }
  update
  eqcheck SDG5e-typing-in-Args-the--n-box-and-the-Case-menu-does-not-reach-sim \
    "args_stored=<[pcall sim_profile_get spice $irow args]>\
 args_staged=<[ui spice $irow args]>\
 nsi_stored=<[pcall sim_profile_get spice $irow nospiceinit]>\
 nsi_staged=<[ui spice $irow nospiceinit]>\
 mode_stored=<[pcall sim_profile_get spice $irow casemode]>\
 mode_staged=<[ui spice $irow casemode]>" \
    "args_stored=<$args0> args_staged=<-r /typed/never/accepted.raw>\
 nsi_stored=<$nsi0> nsi_staged=<1> mode_stored=<$mode0> mode_staged=<fold>"
  # force the slurp the way any unrelated question still does. pcall'd: its own
  # loop reaches `...r.$i.cmd` UNGUARDED, so a sabotage that removes that widget
  # would abort this file with no RESULT line and read as "nothing went red".
  pcall ::set_sim_defaults
  # POSITIVE EVIDENCE first: without this the cancel check could pass vacuously
  eqcheck SDG5b-the-slurp-and-the-live-textvariables-really-did-write \
    "cmd=[expr {$::sim(spice,$irow,cmd) eq {SDG-USER-IS-STILL-TYPING}}]\
 name=[expr {$::sim(spice,$irow,name) ne $name0}]\
 exe_staged=[ui spice $irow exe]" \
    {cmd=1 name=1 exe_staged=/typed/but/never/accepted}
  pcall simconf_cancel
  update
  eqcheck SDG5-Cancel-restores-everything-the-dialog-found \
    "open=[winfo exists .sim] cmd=[expr {$::sim(spice,$irow,cmd) eq $cmd0}]\
 name=[expr {$::sim(spice,$irow,name) eq $name0}]\
 exe=[expr {[pcall sim_profile_get spice $irow exe] eq $exe0}]" \
    {open=0 cmd=1 name=1 exe=1}

  # a Test recorded inside the dialog is undone by Cancel too
  pcall simconf
  update
  set row [pcall simconf_rowpath spice $irow]
  pcall simconf_test_row spice $irow
  set mid [pcall sim_profile_detected spice $irow]
  pcall simconf_cancel
  update
  eqcheck SDG5c-Cancel-undoes-a-measurement-the-Test-button-recorded \
    "during=[expr {$mid ne {}}] after=<[pcall sim_profile_detected spice $irow]>" \
    {during=1 after=<>}

  # ---- Accept commits -----------------------------------------------------
  pcall simconf
  update
  set row [pcall simconf_rowpath spice $irow]
  pcall $row.cmd delete 1.0 end
  pcall $row.cmd insert 1.0 {SDG-ACCEPTED-CMD}
  pcall $row.prof.exe delete 0 end
  pcall $row.prof.exe insert 0 {/accepted/exe}
  pcall $row.prof.arg delete 0 end
  pcall $row.prof.arg insert 0 {-r /accepted.raw}
  pcall $row.prof.nsi invoke
  update
  # THROUGH THE BUTTON, not the proc behind it. Measured: emptying the -command
  # of BOTH `.sim.bottom.ok` and `.sim.bottom.close` -- the only gesture by
  # which a user commits anything in this dialog -- left this file and seven
  # others (836 checks) fully green, because every commit check called
  # `simconf_accept` directly. That is the same dead-control class SDG16 exists
  # to close, on the two most important controls in the window.
  pcall .sim.bottom.close invoke
  update
  eqcheck SDG13-the-Accept-no-Save-BUTTON-commits-the-cmd-box-and-the-staged-fields \
    "open=[winfo exists .sim]\
 cmd=$::sim(spice,$irow,cmd) exe=[pcall sim_profile_get spice $irow exe]\
 args=[pcall sim_profile_get spice $irow args]\
 nsi=[pcall sim_profile_get spice $irow nospiceinit]" \
    {open=0 cmd=SDG-ACCEPTED-CMD exe=/accepted/exe args=-r /accepted.raw nsi=1}

  # an invalid value KEEPS THE WINDOW OPEN: a report destroyed with the window
  # it was printed on is not a report
  pcall simconf
  update
  set row [pcall simconf_rowpath spice $irow]
  pcall $row.prof.exe delete 0 end
  pcall $row.prof.exe insert 0 "bad\}brace"
  update
  pcall .sim.bottom.close invoke
  update
  eqcheck SDG13b-an-invalid-value-blocks-the-close-and-is-reported \
    "open=[winfo exists .sim]\
 said=[string match {*exe rejected*} [uistatus]]\
 kept=[pcall sim_profile_get spice $irow exe]" \
    {open=1 said=1 kept=/accepted/exe}
  pcall simconf_cancel
  update

  # THE SAME REFUSAL FROM THE ARGS BOX. SDG3d proves the model refuses an
  # unparsable list; nothing proved a user could ever reach that refusal by
  # typing, and with the Args entry bound straight to sim() they could not.
  pcall simconf
  update
  set row [pcall simconf_rowpath spice $irow]
  set argkept [pcall sim_profile_get spice $irow args]
  pcall $row.prof.arg delete 0 end
  pcall $row.prof.arg insert 0 "\{unbalanced"
  update
  pcall .sim.bottom.close invoke
  update
  eqcheck SDG3f-an-unparsable-Args-typed-in-the-BOX-is-refused-at-the-button \
    "open=[winfo exists .sim]\
 said=[string match {*args rejected*} [uistatus]]\
 kept=[pcall sim_profile_get spice $irow args]" \
    "open=1 said=1 kept=$argkept"
  pcall simconf_cancel
  update

  # ---- SDG16: THE CONTROLS ARE REALLY WIRED -------------------------------
  # Item 5 of this batch shipped four radio buttons whose -command no check ever
  # drove: replacing it with a no-op left 113/113 green. Every control on this
  # line is therefore driven THROUGH THE WIDGET here -- `invoke` on the button
  # and on the menu entry, a real <Return> event on the entry -- and never only
  # through the proc behind it.
  load_builtin_defaults
  set iw [add_row spice {wired row} $f_count]
  pcall simconf
  update
  set nopen $::sim(spice,n)
  set row [pcall simconf_rowpath spice $iw]
  set before [legs]
  pcall $row.prof.test invoke
  update
  eqcheck SDG16-the-Test-BUTTON-is-wired \
    "legs=[expr {[legs]-$before}] detected=[pcall sim_profile_detected spice $iw]\
 labelbound=[expr {[pcall $row.prof.st cget -textvariable] eq "simconf_ui(spice,$iw,note)"}]" \
    {legs=3 detected=fold preserve distinguish labelbound=1}
  # ...and the answer reaches the LABEL the user is looking at, not just the
  # return value. The label is bound to simconf_ui(...,note); a refresh that
  # forgot to update it left the previous run's sentence on screen.
  check SDG16e-the-Test-answer-reaches-the-row-label \
    [string match {Test: delivers fold preserve distinguish*} [ui spice $iw note]] \
    "(note='[ui spice $iw note]')"
  # the Case MENU ENTRY, invoked in the widget
  set mw $row.prof.mode.m
  set pick [lsearch -exact [pcall menulabels $mw] preserve]
  if {$pick >= 0} { pcall $mw invoke $pick }
  update
  eqcheck SDG16b-the-Case-MENU-ENTRY-is-wired \
    "found=[expr {$pick >= 0}] staged=[ui spice $iw casemode]\
 shown=[ui spice $iw modelabel]" \
    {found=1 staged=preserve shown=preserve}
  # B3's registration gesture, as a real key event on a real entry
  set ia [intof [pcall simconf_add_gui spice]]
  update
  set arow [pcall simconf_rowpath spice $ia]
  pcall $arow.prof.exe delete 0 end
  pcall $arow.prof.exe insert 0 $f_count
  update
  set before [legs]
  pcall event generate $arow.prof.exe <Return>
  update
  eqcheck SDG16c-Return-in-an-ADDED-rows-Exe-box-registers-it \
    "legs=[expr {[legs]-$before}] armed=[ui spice $ia autoprobe]\
 detected=[pcall sim_profile_detected spice $ia]" \
    {legs=3 armed=0 detected=fold preserve distinguish}
  # the Add MENU ENTRY, and the Cancel BUTTON
  set n0 $::sim(spice,n)
  pcall .sim.bottom.add.m invoke 0
  update
  set n1 $::sim(spice,n)
  pcall .sim.bottom.cancel invoke
  update
  eqcheck SDG16d-the-Add-MENU-ENTRY-and-the-Cancel-BUTTON-are-wired \
    "added=[expr {$n1 == $n0+1}] closed=[expr {![winfo exists .sim]}]\
 rolledback=[expr {$::sim(spice,n) == $nopen}]\
 measurement_gone=<[pcall sim_profile_detected spice $iw]>" \
    {added=1 closed=1 rolledback=1 measurement_gone=<>}

  # BOTH ACCEPT BUTTONS, in the family where "is the control wired" lives.
  # `.sim.bottom.ok` and `.sim.bottom.close` are the only gesture by which a
  # user commits anything in this dialog, and emptying BOTH -commands left this
  # file and seven others -- 836 checks -- fully green, because every commit
  # check called `simconf_accept` as a proc.
  load_builtin_defaults
  set ib [add_row spice {button row} $f_ng]
  pcall simconf
  update
  set row [pcall simconf_rowpath spice $ib]
  pcall $row.prof.exe delete 0 end
  pcall $row.prof.exe insert 0 {/via/close/button}
  update
  pcall .sim.bottom.close invoke
  update
  set viaclose "closeopen=[winfo exists .sim] closeexe=[pcall sim_profile_get spice $ib exe]"
  file delete -force [file join $::USER_CONF_DIR simrc]
  pcall simconf
  update
  set row [pcall simconf_rowpath spice $ib]
  pcall $row.prof.exe delete 0 end
  pcall $row.prof.exe insert 0 {/via/ok/button}
  update
  pcall .sim.bottom.ok invoke
  update
  eqcheck SDG16f-BOTH-Accept-BUTTONS-are-wired-and-each-one-commits \
    "$viaclose okopen=[winfo exists .sim] okexe=[pcall sim_profile_get spice $ib exe]\
 wrote=[file isfile [file join $::USER_CONF_DIR simrc]]" \
    {closeopen=0 closeexe=/via/close/button okopen=0 okexe=/via/ok/button wrote=1}

  # THE TITLEBAR X. Before this fix round `wm protocol .sim WM_DELETE_WINDOW`
  # was `simconf_accept 0`, so the X COMMITTED while the Cancel button beside it
  # rolled back -- the one route by which a user loses an edit they meant to
  # abandon. It was also the only route that could go INERT, since simconf_accept
  # refuses to close on an invalid value.
  load_builtin_defaults
  set iwm [add_row spice {wm row} $f_ng]
  pcall simconf
  update
  set wrow [pcall simconf_rowpath spice $iwm]
  set nm0 $::sim(spice,$iwm,name)
  pcall $wrow.lab insert 0 {WM-EDITED-}
  pcall $wrow.prof.exe delete 0 end
  pcall $wrow.prof.exe insert 0 {/wm/never/accepted}
  update
  set proto [string trim [pcall wm protocol .sim WM_DELETE_WINDOW]]
  pcall uplevel #0 $proto
  update
  eqcheck SDG22-the-window-manager-close-button-is-Cancel-not-Accept \
    "proto='$proto' closed=[expr {![winfo exists .sim]}]\
 name=[expr {$::sim(spice,$iwm,name) eq $nm0}]\
 exe=[pcall sim_profile_get spice $iwm exe]" \
    "proto='simconf_cancel' closed=1 name=1 exe=$f_ng"

  # B3'S FALLBACK REGISTRATION: Add, type an ngspice path, press Accept without
  # ever pressing Return or Test. `simconf_accept` calls `simconf_register_armed`
  # for exactly that gesture; measured, deleting that call left all 53 checks
  # green because every armed-row check went through `simconf_row_register` or
  # the <Return> bind.
  load_builtin_defaults
  pcall simconf
  update
  set ir [intof [pcall simconf_add_gui spice]]
  set arow [pcall simconf_rowpath spice $ir]
  pcall $arow.prof.exe delete 0 end
  pcall $arow.prof.exe insert 0 $f_count
  update
  set before [legs]
  pcall .sim.bottom.close invoke
  update
  eqcheck SDG17-Accept-registers-an-armed-Add-that-never-pressed-Return \
    "open=[winfo exists .sim] legs=[expr {[legs]-$before}]\
 detected=[pcall sim_profile_detected spice $ir]" \
    {open=0 legs=3 detected=fold preserve distinguish}
  # ...and B3's name gate still holds on that path: the zzz-named exe is
  # COMMITTED but never launched
  load_builtin_defaults
  pcall simconf
  update
  set iz [intof [pcall simconf_add_gui spice]]
  set zrow [pcall simconf_rowpath spice $iz]
  pcall $zrow.prof.exe delete 0 end
  pcall $zrow.prof.exe insert 0 $f_zzz
  update
  set before [legs]
  pcall .sim.bottom.close invoke
  update
  eqcheck SDG17b-and-B3s-name-gate-still-refuses-to-launch-on-the-Accept-path \
    "open=[winfo exists .sim] legs=[expr {[legs]-$before}]\
 stored=[pcall sim_profile_get spice $iz exe]\
 detected=<[pcall sim_profile_detected spice $iz]>" \
    "open=0 legs=0 stored=$f_zzz detected=<>"

  # A DELIBERATE TEST IS A REGISTRATION, so it consumes B3's Add arm. Measured
  # before the fix: Add -> type an ngspice path -> Test (3 launches) -> Accept
  # and the arm had SURVIVED, so `simconf_register_armed` probed the same binary
  # again: six process launches for one configured row, and an Accept that blocks
  # for a second whole probe budget. Pressing <Return> instead of Test left the
  # total at 3, so the two registration gestures were asymmetric too.
  load_builtin_defaults
  pcall simconf
  update
  set it [intof [pcall simconf_add_gui spice]]
  set trow [pcall simconf_rowpath spice $it]
  pcall $trow.prof.exe delete 0 end
  pcall $trow.prof.exe insert 0 $f_count
  update
  set before [legs]
  pcall $trow.prof.test invoke
  update
  set aftertest [expr {[legs]-$before}]
  set armed [ui spice $it autoprobe]
  pcall .sim.bottom.close invoke
  update
  eqcheck SDG19-a-Test-consumes-B3s-Add-arm-so-Accept-does-not-re-probe \
    "afterTest=$aftertest armed=$armed afterAccept=[expr {[legs]-$before}]" \
    {afterTest=3 armed=0 afterAccept=3}
  # ...but a Test on a row that still names NO executable leaves the arm alone,
  # exactly as simconf_row_register's `noexe` outcome does: it measured nothing,
  # so it registered nothing
  pcall simconf
  update
  set ie [intof [pcall simconf_add_gui spice]]
  set before [legs]
  pcall [pcall simconf_rowpath spice $ie].prof.test invoke
  update
  eqcheck SDG19b-a-Test-on-an-empty-Exe-box-does-not-consume-the-arm \
    "armed=[ui spice $ie autoprobe] legs=[expr {[legs]-$before}]" \
    {armed=1 legs=0}
  pcall simconf_cancel
  update

  # A MEASUREMENT BELONGS TO THE BINARY AND ARGV IT WAS TAKEN WITH. Measured
  # before the fix: Test a row (detected fold preserve distinguish), then type a
  # DIFFERENT path into the Exe box and Accept -- the Case menu still offered all
  # three and `sim_profile_supports` answered 1 for a binary nobody had measured.
  # A1's sentence is that nobody may select a mode their simulator will silently
  # ignore, and changing the Exe is the one edit this dialog exists to make.
  load_builtin_defaults
  set isw [add_row spice {swap row} $f_count]
  pcall simconf
  update
  set srow [pcall simconf_rowpath spice $isw]
  pcall $srow.prof.test invoke
  update
  set measured [pcall sim_profile_detected spice $isw]
  pcall $srow.prof.exe delete 0 end
  pcall $srow.prof.exe insert 0 $f_stock
  update
  pcall .sim.bottom.close invoke
  update
  eqcheck SDG20-committing-a-new-Exe-DROPS-the-previous-binarys-measurement \
    "measured=<$measured> after=<[pcall sim_profile_detected spice $isw]>\
 probed=<[pcall sim_profile_get spice $isw probed]>\
 supports=[pcall sim_profile_supports spice $isw distinguish]\
 offers=[menuvals spice $isw] exe=[expr {[pcall sim_profile_get spice $isw exe] eq $f_stock}]" \
    {measured=<fold preserve distinguish> after=<> probed=<> supports=0 offers={} fold exe=1}
  # THE SAME-MTIME HOLE, which no staleness comparison can see: two files with
  # identical mtimes, so `sim_profile_probe_stale` answers 0 and the status
  # line's "(STALE - the binary moved)" caption never appears. Measured before
  # the fix: a folding binary was offered, and accepted as, `distinguish`.
  set f_twin [file join $fdir ngspice_twin]
  file copy -force $f_stock $f_twin
  file attributes $f_twin -permissions 0755
  file mtime $f_twin [file mtime $f_count]
  load_builtin_defaults
  set itw [add_row spice {twin row} $f_count]
  pcall simconf
  update
  set wrow2 [pcall simconf_rowpath spice $itw]
  pcall $wrow2.prof.test invoke
  update
  set stale_before [pcall sim_profile_probe_stale spice $itw]
  pcall $wrow2.prof.exe delete 0 end
  pcall $wrow2.prof.exe insert 0 $f_twin
  update
  pcall .sim.bottom.close invoke
  update
  eqcheck SDG20b-and-a-same-mtime-swap-that-no-staleness-check-can-see \
    "sametime=[expr {[file mtime $f_twin] == [file mtime $f_count]}]\
 freshbefore=[expr {!$stale_before}]\
 after=<[pcall sim_profile_detected spice $itw]>\
 supports=[pcall sim_profile_supports spice $itw distinguish]" \
    {sametime=1 freshbefore=1 after=<> supports=0}

  # A2's `-n` BOX AGAINST A HAND-WRITTEN BOOLEAN. `sim_profile_valid` accepts
  # every Tcl spelling and B1 blesses a hand-edited simrc, so `nospiceinit true`
  # reached a checkbutton that compares against the literal 1 and DISPLAYED
  # UNCHECKED while `-n` really was in the argv -- the box telling the user the
  # opposite of what the run does.
  load_builtin_defaults
  set inb [add_row spice {boolean row} $f_ng]
  set ::sim(spice,$inb,nospiceinit) true
  pcall simconf
  update
  set brow [pcall simconf_rowpath spice $inb]
  eqcheck SDG21-a-hand-written-boolean-shows-CHECKED-and-is-canonicalised \
    "staged=[ui spice $inb nospiceinit]\
 selected=[expr {[ui spice $inb nospiceinit] eq [pcall $brow.prof.nsi cget -onvalue]}]\
 on=[pcall $brow.prof.nsi cget -onvalue] off=[pcall $brow.prof.nsi cget -offvalue]\
 argv=[pcall sim_probe_argv {} fold [pcall sim_profile_get spice $inb nospiceinit]]" \
    {staged=1 selected=1 on=1 off=0 argv=-b -n -D casemode=fold}
  pcall simconf_cancel
  update
} else {
  puts "note: dialog legs need a display; SDG4* SDG5* SDG13* SDG16* SDG17*\
 SDG19* SDG20* SDG21 SDG22 not run here"
}

# ===========================================================================
# F — BACKWARD COMPATIBILITY: the pre-item-6 simrc survives the dialog
# ===========================================================================
set pre [file join $fixdir simrc_pre_casemode]
if {![file isfile $pre]} {
  check SDG14-pre-batch-simrc-fixture-present 0 "($pre)"
} elseif {!$HASX} {
  puts "note: SDG14 needs a display (it opens the dialog); not run here"
} else {
  set pretxt [slurp $pre]
  if {[dlgopen]} { catch {destroy .sim} }
  file copy -force $pre [file join $::USER_CONF_DIR simrc]
  if {[info exists ::sim]} { unset ::sim }
  pcall set_sim_defaults
  pcall simconf
  update
  # ACCEPT AND SAVE, having changed nothing -- THROUGH THE BUTTON
  pcall .sim.bottom.ok invoke
  update
  eqcheck SDG14-the-dialog-round-trips-a-pre-item6-simrc-byte-identically \
    "closed=[expr {![winfo exists .sim]}]\
 identical=[expr {[slurp [file join $::USER_CONF_DIR simrc]] eq $pretxt}]\
 shaped=[info exists ::sim(spice,0,exe)]" \
    {closed=1 identical=1 shaped=1}

  # POSITIVE CONTROL FOR SDG14, and it is not a nicety. SDG14 compares the simrc
  # against the very bytes it copied onto disk a moment earlier, so "saved
  # byte-identically" and "NEVER SAVED AT ALL" are the same observation to it:
  # measured, wrapping `save_sim_defaults` in `if {0}` inside simconf_accept left
  # this file and seven others -- 836 checks -- fully green. This leg DELETES the
  # file first and edits exactly one field, so the save must really happen and
  # must move exactly the line the user touched and no other.
  if {[dlgopen]} { catch {destroy .sim} }
  file copy -force $pre [file join $::USER_CONF_DIR simrc]
  if {[info exists ::sim]} { unset ::sim }
  pcall set_sim_defaults
  pcall simconf
  update
  set r0 [pcall simconf_rowpath spice 0]
  pcall $r0.lab delete 0 end
  pcall $r0.lab insert 0 {SDG14C-NAME}
  update
  file delete -force [file join $::USER_CONF_DIR simrc]
  pcall .sim.bottom.ok invoke
  update
  set got [slurp [file join $::USER_CONF_DIR simrc]]
  set dl 0
  foreach a [split $pretxt \n] b [split $got \n] { if {$a ne $b} { incr dl } }
  eqcheck SDG14c-Accept-and-Save-really-WRITES-and-moves-only-the-edited-line \
    "reappeared=[file isfile [file join $::USER_CONF_DIR simrc]]\
 carries=[string match {*SDG14C-NAME*} $got] difflines=$dl" \
    {reappeared=1 carries=1 difflines=1}
  # and Cancel writes nothing at all
  if {[dlgopen]} { catch {destroy .sim} }
  file copy -force $pre [file join $::USER_CONF_DIR simrc]
  if {[info exists ::sim]} { unset ::sim }
  pcall set_sim_defaults
  pcall simconf
  update
  set r0 [pcall simconf_rowpath spice 0]
  pcall $r0.prof.exe insert 0 {/scribbled}
  # ...and a LIVE one, which reaches sim() the moment it is typed: without it a
  # cancel that wrongly saved would write the very bytes it started from and
  # this check could not fail
  pcall $r0.lab insert 0 {SCRIBBLED-}
  update
  pcall simconf_cancel
  update
  eqcheck SDG14b-Cancel-writes-no-simrc-at-all \
    [expr {[slurp [file join $::USER_CONF_DIR simrc]] eq $pretxt}] 1

  # RESET THEN CANCEL. `set_sim_defaults reset` DELETES $USER_CONF_DIR/simrc from
  # disk immediately. Before this fix round Cancel restored only the in-memory
  # array, so the session looked recovered and the user's configuration was gone
  # at the next xschem start -- while this dialog's own Help text and spec 17.11
  # both promised that Cancel undid it. MEASURED through the real buttons:
  # exists at open = 1, after Reset = 0, after Cancel = 0. tk_messageBox is
  # stubbed because the confirmation is modal and this file cannot answer it.
  if {[dlgopen]} { catch {destroy .sim} }
  file copy -force $pre [file join $::USER_CONF_DIR simrc]
  if {[info exists ::sim]} { unset ::sim }
  pcall set_sim_defaults
  pcall simconf
  update
  if {[info procs tk_messageBox] ne {}} { rename tk_messageBox sdg_saved_mbox }
  proc tk_messageBox {args} { return ok }
  pcall .sim.bottom.reset invoke
  update
  set midgone [expr {![file isfile [file join $::USER_CONF_DIR simrc]]}]
  set midopen [expr {[winfo exists .sim] ? 1 : 0}]
  pcall .sim.bottom.cancel invoke
  update
  rename tk_messageBox {}
  if {[info procs sdg_saved_mbox] ne {}} { rename sdg_saved_mbox tk_messageBox }
  eqcheck SDG18-Reset-then-Cancel-puts-the-simrc-back-ON-DISK \
    "resetdeleted=$midgone rebuilt=$midopen\
 exists=[file isfile [file join $::USER_CONF_DIR simrc]]\
 identical=[expr {[slurp [file join $::USER_CONF_DIR simrc]] eq $pretxt}]\
 closed=[expr {![winfo exists .sim]}]" \
    {resetdeleted=1 rebuilt=1 exists=1 identical=1 closed=1}

  # ...and a PLAIN Cancel does not touch the file at all. A restore that fired
  # unconditionally would rewrite the simrc on every Cancel, which SDG14b -- a
  # content comparison against the bytes it started from -- cannot see.
  if {[dlgopen]} { catch {destroy .sim} }
  file copy -force $pre [file join $::USER_CONF_DIR simrc]
  file mtime [file join $::USER_CONF_DIR simrc] 1000000000
  if {[info exists ::sim]} { unset ::sim }
  pcall set_sim_defaults
  pcall simconf
  update
  set r0 [pcall simconf_rowpath spice 0]
  pcall $r0.lab insert 0 {SCRIBBLED-}
  update
  pcall .sim.bottom.cancel invoke
  update
  eqcheck SDG18b-a-plain-Cancel-does-not-rewrite-the-simrc \
    [file mtime [file join $::USER_CONF_DIR simrc]] 1000000000
}

# ===========================================================================
# G — the model half stays callable with no Tk at all
# ===========================================================================
# item 6 put the model in xschem.tcl and kept it Tk-free; the dialog procs are
# allowed Tk, but the ones item 8/9/11 style callers might reach must not need
# a window to exist
if {[dlgopen]} { pcall simconf_cancel ; update }
eqcheck SDG15-the-model-procs-answer-with-no-dialog-open \
  "open=[dlgopen]\
 menu=[llength [pcall simconf_mode_menu_items spice 0]]\
 label='[pcall simconf_mode_label spice 0 {}]'\
 refresh=[pcall simconf_mode_refresh spice 0]" \
  {open=0 menu=2 label='use global default (fold)' refresh=0}
# and the snapshot refuses to restore under a live window, which is the Tk trap
# that would otherwise put every widget's string straight back
if {$HASX} {
  pcall simconf
  update
  set threw [catch {simconf_snapshot_restore}]
  eqcheck SDG15b-the-snapshot-refuses-to-restore-under-a-live-window $threw 1
  pcall simconf_cancel
  update
}

catch {test_scratch_drop $tmp}
puts "----"
puts "test_sim_dialog: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
