# tests/headless/test_ase_rundir_1665.tcl -- ISSUE 1665: ASE-L HAD NO DOOR FOR
# THE RUN DIRECTORY.
#
# The state has always carried a `rundir` key, and the engine reads it in
# many places (deck, raw, log, .meas, campaign shards, the results resolver,
# the viewer's stored rawfile). Nothing in the window wrote it: only a
# hand-edited .state file could, while two engine refusals told the user to
# "set a run directory". The door is Setup > Run Directory…, a modeless dialog
# over four pure engine procs:
#
#   ase::rundir_validate     text -> {clear|ok|refuse value notes}
#   ase::rundir_set          state path -> state, rawfile rebased
#   ase::rundir_busy         key -> run | campaign | {}
#   ase::rundir_default_preview  the shared fallback, read only
#
# and one scriptable window proc, ase::ui::set_rundir, which the dialog's OK
# calls. Choosing a directory is SESSION STATE (the 1395 rule): it dirties, the
# close and quit prompts follow, and Save State is what reaches disk.
#
# SECTIONS
#   RD1-RD9    the validator, headless
#   RD10-RD11  the setter and the viewer.rawfile rebase, headless
#   RD12-RD16  dirty, quit prompt, busy, log line, pane refresh, headless
#   RD-L       the engine's typed menu path equals the window's constant
#   RD17       the written menu tree names the entry
#   RD19-RD32  the dialog itself, display arm only (an UPPERCASE `SKIP:` line
#              names this headless; T1's `skips=` counts lowercase only)
#
# WHAT THIS FILE DOES NOT MEASURE
# * The directory chooser is modal: RD22 stubs `tk_chooseDirectory` and asserts
#   what the dialog does with each answer. The real click is uncovered (the
#   S14a precedent of test_ase_simdlg_0937).
# * No simulator is started. Busy is injected through the same records the
#   window's own predicates read.
#
# Arms (the armed spelling keeps your HOME and screen untouched):
#   tests/headless/run_suites.sh --nogui test_ase_rundir_1665
#   tests/headless/run_suites.sh test_ase_rundir_1665

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set no_recent_files 1

# --- the answer discipline (test_ase_simdlg_0937's) ---------------------------
proc pcall {args} {
  set cmd [lindex $args 0]
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {uplevel #0 $args} r]} { return "RAISED: $r" }
  return $r
}
proc wex {w} {
  if {[catch {winfo exists $w} e]} { return 0 }
  return $e
}
proc wtext {w} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {$w cget -text} t]} { return NOTEXT }
  return $t
}
proc wcget {w opt} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {$w cget $opt} v]} { return NOOPT }
  return $v
}
proc winv {w args} {
  if {![wex $w]} { return NOWIDGET }
  set rc [catch {uplevel #0 [linsert $args 0 $w invoke]} r]
  catch {update}
  if {$rc} { return "INVRAISED: $r" }
  return $r
}
proc went {w txt} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {$w delete 0 end}]} { return NOENTRY }
  if {[catch {$w insert 0 $txt}]} { return NOENTRY }
  return OK
}
proc wget {w} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {$w get} v]} { return NOENTRY }
  return $v
}
proc mlabels {m} {
  if {![wex $m]} { return NOWIDGET }
  set out {}
  if {[catch {$m index end} last]} { return NOINDEX }
  if {$last eq {none} || $last eq {}} { return {} }
  for {set i 0} {$i <= $last} {incr i} {
    set l {}
    catch {set l [$m entrycget $i -label]}
    lappend out $l
  }
  return $out
}
proc mcmd {m label} {
  if {![wex $m]} { return NOWIDGET }
  if {[catch {$m entrycget $label -command} c]} { return NOENTRY }
  return $c
}
proc wtitle {w} {
  if {![wex $w]} { return NOWIDGET }
  if {[catch {wm title $w} t]} { return NOTITLE }
  return $t
}
## deliver a REAL generated key, WSLg-robustly (test_ase_dialogs' idiom)
proc send_key {w ev done} {
  for {set i 0} {$i < 200} {incr i} {
    update
    if {[uplevel 1 [list expr $done]]} { return 1 }
    if {[winfo exists $w]} {
      focus -force $w
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[winfo exists $w] && [focus -displayof $w] eq $w} {
        event generate $w $ev
        update
        if {[uplevel 1 [list expr $done]]} { return 1 }
      }
    }
    after 50
  }
  return 0
}
proc slurp {path} {
  if {![file exists $path]} { return ZZNOFILE }
  set fp [open $path r] ; set t [read $fp] ; close $fp
  return $t
}
## the session's serialized state, or a sentinel: a byte-identity row must
## never compare two errors
proc ser {key} {
  if {[catch {ase::state_serialize [ase::session_state $key]} s]} { return "SERRAISED: $s" }
  return $s
}
## the dialog records left for KEY
proc rdrecs {key} {
  if {![array exists ::ase::ui::dlg]} { return {} }
  return [array names ::ase::ui::dlg "$key,rd*"]
}

# --- locations ---------------------------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_rundir]
test_sim_registry_isolate
set SPECMD [file join $repo doc claude specs ase_l.md]

## ::netlist_dir and ::USER_CONF_DIR into scratch: an empty rundir resolves
## through `set_netlist_dir 0`, which must never reach the developer's own
## simulations directory.
set NDSAVE [expr {[info exists ::netlist_dir] ? $::netlist_dir : {ZZUNSET}}]
set LNDSAVE [expr {[info exists ::local_netlist_dir] ? $::local_netlist_dir : {ZZUNSET}}]
set UCDSAVE [expr {[info exists ::USER_CONF_DIR] ? $::USER_CONF_DIR : {ZZUNSET}}]
set ::local_netlist_dir 0
set ::netlist_dir [file join $scratch simdir]
file mkdir $::netlist_dir
set ::USER_CONF_DIR [file join $scratch conf]
file mkdir $::USER_CONF_DIR

set ROOT 0
catch {set ROOT [expr {[exec id -u] == 0}]}

## A state file + a registered session on it. A design is set so the run-lock
## key can be derived (RD14).
proc mksession {key {rundir {}}} {
  set p [file join $::scratch [string map {/ _} $key].state]
  set st [ase::state_default]
  dict set st design [dict create lib L cell c1 view schematic]
  dict set st rundir $rundir
  ase::state_save $p $st
  ase::session_open $key $p
  return $p
}

# =============================================================================
# RD1-RD9 THE VALIDATOR
# =============================================================================
if {[catch {

check {RD1 empty and blank text is the shared default, cleared, never refused} \
  [list [pcall ase::rundir_validate {}] [pcall ase::rundir_validate "  \t "]] \
  [list {clear {} {}} {clear {} {}}]

## RD2: resolved once, against [pwd], and stored absolute
set rd2 [pcall ase::rundir_validate rd2_rel/sub]
check {RD2 a relative path is accepted and stored ABSOLUTE, under the process cwd} \
  [list [lindex $rd2 0] [lindex $rd2 1] [file pathtype [lindex $rd2 1]]] \
  [list ok [file normalize [file join [pwd] rd2_rel sub]] absolute]

## RD3: expansion precedes the `$` refusal
set rd3h [file normalize [file join $::env(HOME) rd3x]]
set rd3a [pcall ase::rundir_validate ~/rd3x]
set rd3b [pcall ase::rundir_validate "\$env(HOME)/rd3x"]
check {RD3 ~ and $env(HOME) expand to the same absolute path, before any character test} \
  [list [lindex $rd3a 0] [lindex $rd3a 1] [lindex $rd3b 0] [lindex $rd3b 1]] \
  [list ok $rd3h ok $rd3h]

## RD4: an existing file
set rd4 [file join $scratch rd4file]
set f [open $rd4 w] ; puts $f x ; close $f
set rd4v [pcall ase::rundir_validate $rd4]
check {RD4 an existing FILE is refused, and the reason names it} \
  [list [lindex $rd4v 0] [lindex $rd4v 1] \
        [expr {[string first $rd4 [lindex $rd4v 2]] >= 0}] \
        [expr {[string first {not a directory} [lindex $rd4v 2]] >= 0}]] \
  {refuse {} 1 1}
set rd4s [pcall ase::rundir_validate [file join $rd4 sub]]
check {RD4 a path UNDER an existing file is refused, naming that file as not a directory} \
  [list [lindex $rd4s 0] \
        [expr {[string first "`$rd4`" [lindex $rd4s 2]] >= 0}] \
        [expr {[string first {not a directory} [lindex $rd4s 2]] >= 0}]] \
  {refuse 1 1}

## RD5/RD6: permissions mean nothing to root
if {$ROOT} {
  puts "SKIP: RD5 RD6 need a directory this user cannot write to (running as root)"
} else {
  set rd5 [file join $scratch rd5ro]
  file mkdir $rd5
  file attributes $rd5 -permissions 0555
  set rd5v [pcall ase::rundir_validate $rd5]
  set rd6v [pcall ase::rundir_validate [file join $rd5 sub deeper]]
  file attributes $rd5 -permissions 0755
  check {RD5 an existing directory that is not writable is refused} \
    [list [lindex $rd5v 0] [expr {[string first {not writable} [lindex $rd5v 2]] >= 0}]] \
    {refuse 1}
  check {RD6 a path that would be created under an unwritable ancestor is refused, naming that ancestor} \
    [list [lindex $rd6v 0] [expr {[string first "`$rd5`" [lindex $rd6v 2]] >= 0}]] \
    {refuse 1}
}

## RD7: THE CHARACTER POPULATION IS DERIVED FROM THE BACKEND'S OWN PREDICATES.
## Each candidate's expected disposition is "a probe raised", measured here on
## the expanded path; the validator must agree with it member by member. The
## literal leg below is the comparand with a different mechanism: four
## characters whose answer is known by name.
proc rd7_raised {p} {
  if {[catch {ase::backend::ngspice::path_quoted $p}]} { return 1 }
  if {[catch {ase::backend::ngspice::shell_word $p rd}]} { return 1 }
  return 0
}
set rd7c [list "\n" "\t" "\r" "\x0b" "\x0c" "\$/" "`" "\{" "\}" "\"" "\\" "'" " " "Up"]
set rd7bad {} ; set rd7nraise 0 ; set rd7nok 0
foreach c $rd7c {
  set cand [file join $scratch rd7 "a${c}b"]
  set exp [rd7_raised [file normalize [ase::expand_path $cand]]]
  if {$exp} { incr rd7nraise } else { incr rd7nok }
  set got [lindex [pcall ase::rundir_validate $cand] 0]
  set gotr [expr {$got eq {refuse} ? 1 : 0}]
  if {$gotr != $exp} { lappend rd7bad [list [string map {\n \\n \t \\t \r \\r} $c] $got $exp] }
}
check {RD7 every candidate character is refused exactly when the backend's own probes raise on it} \
  [list $rd7bad [expr {$rd7nraise >= 1}] [expr {$rd7nok >= 1}] [llength $rd7c]] \
  [list {} 1 1 14]
check {RD7 by name: a backquote and a newline are refused; an apostrophe, a space and upper case are accepted} \
  [list [lindex [pcall ase::rundir_validate [file join $scratch rd7 "a`b"]] 0] \
        [lindex [pcall ase::rundir_validate [file join $scratch rd7 "a\nb"]] 0] \
        [lindex [pcall ase::rundir_validate [file join $scratch rd7 "a'b"]] 0] \
        [lindex [pcall ase::rundir_validate [file join $scratch rd7 "a b"]] 0] \
        [lindex [pcall ase::rundir_validate [file join $scratch rd7 Up]] 0]] \
  {refuse refuse ok ok ok}
check {RD7 a refusal is reworded for this door: it names no bench move and carries no ase: prefix} \
  [apply {{s} {
     set why [lindex [pcall ase::rundir_validate [file join $s rd7 "a`b"]] 2]
     list [expr {[string first {Choose another run directory.} $why] >= 0}] \
          [expr {[string first {Move the bench} $why] >= 0}] \
          [string match {ase: *} $why] }} $scratch] {1 0 0}

## RD8: an advisory, never a refusal (ADE-L is a floor)
set rd8plain [file join $scratch rd8plain]
set rd8up  [pcall ase::rundir_validate [file join $scratch Rd8Up]]
set rd8sp  [pcall ase::rundir_validate [file join $scratch "rd8 sp"]]
set rd8ok  [pcall ase::rundir_validate $rd8plain]
check {RD8 fixture: the plain scratch path is one the fast OP dump can reach} \
  [pcall ase::op_dump_reachable_dir $rd8plain] 1
check {RD8 upper case and a space are accepted WITH the OP advisory; a plain lower-case path has none} \
  [list [lindex $rd8up 0] [llength [lindex $rd8up 2]] \
        [expr {[string first {OP annotation} [lindex $rd8up 2]] >= 0}] \
        [lindex $rd8sp 0] [llength [lindex $rd8sp 2]] \
        [lindex $rd8ok 0] [lindex $rd8ok 2]] \
  {ok 1 1 ok 1 ok {}}
## and the relative-model note, from the state
set rd8st [ase::state_default]
dict set rd8st models [list [dict create file models/rel.lib section tt]]
set rd8rel [pcall ase::rundir_validate $rd8plain $rd8st]
dict set rd8st models [list [dict create file /abs/models.lib section tt]]
set rd8abs [pcall ase::rundir_validate $rd8plain $rd8st]
check {RD8 a relative model path in the state adds its own note; an absolute one does not} \
  [list [expr {[string first {Relative model} [lindex $rd8rel 2]] >= 0}] [lindex $rd8abs 2]] \
  {1 {}}
## includes, both stored shapes, with no relative model
set rd8i [ase::state_default]
dict set rd8i includes [list inc/plain.inc]
set rd8ia [pcall ase::rundir_validate $rd8plain $rd8i]
dict set rd8i includes [list [dict create file inc/dict.inc]]
set rd8ib [pcall ase::rundir_validate $rd8plain $rd8i]
dict set rd8i includes [list /abs/x.inc]
set rd8ic [pcall ase::rundir_validate $rd8plain $rd8i]
check {RD8 a relative include, plain or {file ...}, adds the note; an absolute one does not} \
  [list [expr {[string first {Relative model/include} [lindex $rd8ia 2]] >= 0}] \
        [expr {[string first {Relative model/include} [lindex $rd8ib 2]] >= 0}] \
        [lindex $rd8ic 2]] {1 1 {}}
## the note says "now resolve against the NEW directory": not for the same one
set rd8same [ase::state_default]
dict set rd8same models [list [dict create file models/rel.lib section tt]]
dict set rd8same rundir "$rd8plain/"
set rd8sv [pcall ase::rundir_validate $rd8plain $rd8same]
check {RD8 the relative-input note is absent when the directory is the one already stored, spelled differently} \
  [list [lindex $rd8sv 0] [lindex $rd8sv 2] [expr {"$rd8plain/" ne $rd8plain}]] {ok {} 1}

## RD1b: THE SHARED DEFAULT, TYPED OR BROWSED TO, IS A CLEAR, NOT A KEY. A key
## naming it would read as unshared and silence every shared-directory refusal.
set rd1p [ase::rundir_default_preview]
set rd1a [pcall ase::rundir_validate $rd1p]
set rd1b [pcall ase::rundir_validate "$rd1p/"]
set rd1c [pcall ase::rundir_validate [file join $rd1p sub]]
check {RD1b the shared default path, with or without a trailing slash, answers clear with a note; a directory under it is an ordinary ok} \
  [list [expr {$rd1p ne {}}] [lrange $rd1a 0 1] [llength [lindex $rd1a 2]] \
        [lrange $rd1b 0 1] [lindex $rd1c 0]] \
  {1 {clear {}} 1 {clear {}} ok}
set rd1st [ase::state_default]
dict set rd1st design [dict create cell rc lib $scratch]
dict set rd1st simulator ngspice
dict set rd1st analyses {{type op enabled 1}}
dict set rd1st sweep [dict create enabled 1 axes {{kind temp values {27}}}]
dict set rd1st rundir [lindex $rd1b 1]
set rd1ref {}
foreach e [ase::campaign_refusals ngspice $rd1st] { lappend rd1ref [lindex $e 0] }
check {RD1b the value stored for it keeps the bench shared, so the campaign still refuses sharedrundir} \
  [list [ase::rundir_is_shared $rd1st] [expr {[lsearch -exact $rd1ref sharedrundir] >= 0}]] {1 1}
check {RD1c ase::rundir_same_path: a trailing slash and a doubled separator are the same, a sibling with a suffix is not, empty equals only empty} \
  [list [pcall ase::rundir_same_path "$rd8plain/" $rd8plain] \
        [pcall ase::rundir_same_path [file dirname $rd8plain]//[file tail $rd8plain] $rd8plain] \
        [pcall ase::rundir_same_path ${rd8plain}bis $rd8plain] \
        [pcall ase::rundir_same_path {} $rd8plain] [pcall ase::rundir_same_path {} {}]] \
  {1 1 0 0 1}

## RD9: a query, not a mutation
set rd9t [file join $scratch rd9 never]
set rd9nd $::netlist_dir
set rd9v [pcall ase::rundir_validate $rd9t]
check {RD9 the validator creates no directory and leaves ::netlist_dir byte-identical} \
  [list [lindex $rd9v 0] [file exists $rd9t] [file exists [file dirname $rd9t]] \
        [expr {$::netlist_dir eq $rd9nd}]] \
  {ok 0 0 1}
## RD9b: the "Empty = shared" preview is read only too, even when the shared
## directory does not exist yet
set rd9nd2 [file join $scratch rd9b notyet]
set ::netlist_dir $rd9nd2
set rd9pv [pcall ase::rundir_default_preview]
set rd9pv2 [pcall ase::rundir_validate [file join $scratch rd9b other]]
set rd9after $::netlist_dir
set ::netlist_dir $rd9nd
check {RD9b the shared-default preview (and the validator's comparison with it) creates nothing and leaves ::netlist_dir byte-identical} \
  [list $rd9pv [file exists $rd9nd2] [file exists [file dirname $rd9nd2]] \
        [expr {$rd9after eq $rd9nd2}] [lindex $rd9pv2 0]] \
  [list $rd9nd2 0 0 1 ok]

} vaerr]} { check {RV0 section RD1-RD9 ran to the end} "RAISED:$vaerr" {} }

# =============================================================================
# RD10-RD11 THE SETTER AND THE REBASE
# =============================================================================
if {[catch {

set s10 [ase::state_default]
dict set s10 rundir [file join $scratch old]
set n10 [pcall ase::rundir_set $s10 [file join $scratch new]]
check {RD10 the setter moves ONLY the rundir key when no rawfile is stored} \
  [list [ase::state_get $n10 rundir] \
        [expr {[dict remove $n10 rundir] eq [dict remove $s10 rundir]}] \
        [ase::state_get $s10 rundir]] \
  [list [file join $scratch new] 1 [file join $scratch old]]

set OLD [file join $scratch old]
set NEW [file join $scratch new]
proc rd11 {old new rf} {
  set st [ase::state_default]
  dict set st rundir $old
  dict set st viewer [dict create open 1 rawfile $rf graphs {g}]
  set n [pcall ase::rundir_set $st $new]
  if {[string match {RAISED:*} $n] || $n eq {NOPROC}} { return $n }
  return [list [ase::state_get [ase::state_get $n viewer] rawfile] \
               [ase::state_get [ase::state_get $n viewer] graphs] \
               [ase::state_get $n rundir]]
}
set c1 [rd11 $OLD $NEW ../new/an.raw]
set c2 [rd11 $OLD $NEW an.raw]
set c3 [rd11 {} $NEW an.raw]
set c4 [rd11 $OLD $NEW [file join $NEW sub b.raw]]
set c4r [ase::state_get [pcall ase::ui::viewer_rawfile_relative \
           [dict create rawfile [file join $NEW sub b.raw]] \
           [dict create rundir $NEW]] rawfile]
check {RD11 a relative rawfile whose file sits under the NEW directory is re-relativised to it} \
  $c1 [list an.raw g $NEW]
check {RD11 a relative rawfile NOT under the new directory becomes absolute under the OLD one} \
  $c2 [list [file join $OLD an.raw] g $NEW]
check {RD11 a relative rawfile under an EMPTY old key is left alone} \
  $c3 [list an.raw g $NEW]
check {RD11 an absolute rawfile gets the R602e answer, the viewer's own relativiser's} \
  [list [lindex $c4 0] $c4r] [list [file join sub b.raw] [file join sub b.raw]]
set c5 [rd11 $OLD {} an.raw]
check {RD11 clearing to the shared default (new {}) makes a relative rawfile absolute under the OLD directory} \
  $c5 [list [file join $OLD an.raw] g {}]
## `<dir>bis` is a SIBLING, not a child: component-wise, never a string prefix
set c6 [rd11 $OLD $NEW [file join ${NEW}bis x.raw]]
check {RD11 an absolute rawfile under <new>bis stays absolute, and the shared predicate keeps <old>bis/x.raw absolute against <old>} \
  [list [lindex $c6 0] [pcall ase::rawfile_relative [file join ${OLD}bis x.raw] $OLD] \
        [pcall ase::rawfile_relative [file join $OLD x.raw] $OLD]] \
  [list [file join ${NEW}bis x.raw] [file join ${OLD}bis x.raw] x.raw]
## Distinctness, on the EXPECTED values: a setter that left the rawfile alone
## must fail cells 1 and 2, so each expectation must differ from its input.
check {RD11 distinctness: each rebase cell expects a value different from the one stored, so a no-op setter cannot pass it} \
  [list [expr {{an.raw} ne {../new/an.raw}}] \
        [expr {[file join $OLD an.raw] ne {an.raw}}] \
        [expr {[file join sub b.raw] ne [file join $NEW sub b.raw]}]] {1 1 1}

} rserr]} { check {RS0 section RD10-RD11 ran to the end} "RAISED:$rserr" {} }

# =============================================================================
# RD12-RD16 THE SESSION: DIRTY, QUIT, BUSY, LOG, REFRESH
# =============================================================================
if {[catch {

set K12 L/c1/rd12
set R12A [file join $scratch r12a]
set R12B [file join $scratch r12b]
mksession $K12
set d0 [ase::session_dirty $K12]
set sh0 [ase::rundir_is_shared [ase::session_state $K12]]
pcall ase::ui::set_rundir $K12 $R12A
set d1 [ase::session_dirty $K12]
set sh1 [ase::rundir_is_shared [ase::session_state $K12]]
ase::session_save $K12
set d2 [ase::session_dirty $K12]
pcall ase::ui::set_rundir $K12 $R12B
set d3 [ase::session_dirty $K12]
pcall ase::ui::set_rundir $K12 $R12A
set d4 [ase::session_dirty $K12]
pcall ase::ui::set_rundir $K12 $R12B
ase::session_revert $K12
set rv [ase::state_get [ase::session_state $K12] rundir]
check {RD12 choosing a directory dirties; Save State cleans; choosing the saved value back is clean; Revert restores the key} \
  [list $d0 $sh0 $d1 $sh1 $d2 $d3 $d4 $rv] [list 0 1 1 0 0 1 0 $R12A]
## and the saved file really holds it
check {RD12 Save State wrote the absolute value into the .state file} \
  [ase::state_get [ase::state_load [ase::session_path $K12]] rundir] $R12A
ase::session_close $K12

## RD13: the quit prompt, headless (test_ase_simchoice_1395's Q shape)
set RD13WINS $::ase::ui::wins
rename ase::ui::ask_save_close   rd13_o_ask
rename ase::ui::close            rd13_o_close
proc ase::ui::ask_save_close {key} { lappend ::q_asked $key ; return cancel }
proc ase::ui::close {key} {
  lappend ::q_closed $key
  catch {dict unset ::ase::ui::wins $key}
  return 1
}
set ::q_asked {} ; set ::q_closed {}
set ::ase::ui::wins [dict create]
set K13 L/c1/rd13
mksession $K13
dict set ::ase::ui::wins $K13 .rd13fake
pcall ase::ui::set_rundir $K13 [file join $scratch r13]
ase::ui::close_request $K13
set q1 [list $::q_asked $::q_closed]
set ::q_asked {}
set q2 [ase::ui::prompt_all_on_quit]
set q2a $::q_asked
rename ase::ui::ask_save_close {}
rename ase::ui::close {}
rename rd13_o_ask ase::ui::ask_save_close
rename rd13_o_close ase::ui::close
set ::ase::ui::wins $RD13WINS
check {RD13 a session dirty only by its run directory gets the close prompt and the quit prompt, and Cancel aborts both} \
  [list $q1 $q2 $q2a] [list [list $K13 {}] 0 $K13]
check {RD13 every shim restored} \
  [list [info procs rd13_o_ask] [info procs rd13_o_close] \
        [expr {[string first {ase::session_dirty} [info body ase::ui::close_request]] >= 0}]] \
  {{} {} 1}
ase::session_close $K13

## RD14: busy, by each of the three arms, and idle again
set K14 L/c1/rd14
mksession $K14 [file join $scratch r14]
set b0 [pcall ase::rundir_busy $K14]
set ::execute(pipe,9166501) fake
ase::session_setattr $K14 run_id 9166501
set b1 [pcall ase::rundir_busy $K14]
ase::session_setattr $K14 run_id {}
unset ::execute(pipe,9166501)
set lk [ase::run_lock_key [ase::session_state $K14]]
set ::execute(pipe,9166502) fake
ase::run_lock_set $lk 9166502
set b2 [pcall ase::rundir_busy $K14]
ase::run_lock_clear $lk
unset ::execute(pipe,9166502)
set ::ase::ui::dlg($K14,camp,running) 1
set b3 [pcall ase::rundir_busy $K14]
unset ::ase::ui::dlg($K14,camp,running)
set b4 [pcall ase::rundir_busy $K14]
check {RD14 busy by the run_id pipe, by the run lock, by a running campaign, and idle before and after} \
  [list $b0 $b1 [expr {$lk ne {}}] $b2 $b3 $b4] {{} run 1 run campaign {}}
set CS "[ase::ui::lbl_simulation] > [ase::ui::lbl_camp_menu] > [ase::ui::lbl_camp_stop]"
check {RD14 each busy refusal names its way out: Simulation > Stop for a run, the Campaign window's Stop for a campaign} \
  [list [expr {[string first [ase::ui::menu_path_stop] [ase::ui::rundir_busy_msg run]] >= 0}] \
        [expr {[string first $CS [ase::ui::rundir_busy_msg campaign]] >= 0}]] {1 1}
## the scriptable door does not refuse; the dialog's OK does (RD25)
set ::ase::ui::dlg($K14,camp,running) 1
set b5 [pcall ase::ui::set_rundir $K14 [file join $scratch r14b]]
unset ::ase::ui::dlg($K14,camp,running)
check {RD14 ase::ui::set_rundir itself is not refused while busy -- it is the scripting door} \
  [list $b5 [ase::state_get [ase::session_state $K14] rundir]] \
  [list [file join $scratch r14b] [file join $scratch r14b]]
ase::session_close $K14

## RD15/RD16: one log line and one refresh per CHANGE, none for a same value
set K15 L/c1/rd15
mksession $K15
rename ase::ui::log_action     rd15_o_log
rename ase::ui::results_refill rd15_o_refill
rename ase::ui::populate       rd15_o_pop
proc ase::ui::log_action {line} { lappend ::rd15_log $line }
proc ase::ui::results_refill {key} { lappend ::rd15_ref $key ; return {} }
proc ase::ui::populate {key} { lappend ::rd15_pop $key }
set ::rd15_log {} ; set ::rd15_ref {} ; set ::rd15_pop {}
set R15 [file join $scratch r15]
pcall ase::ui::set_rundir $K15 $R15
set l1 $::rd15_log ; set f1 [list $::rd15_ref $::rd15_pop]
pcall ase::ui::set_rundir $K15 $R15
set l2 $::rd15_log ; set f2 [list $::rd15_ref $::rd15_pop]
foreach {o n} {rd15_o_log ase::ui::log_action rd15_o_refill ase::ui::results_refill \
               rd15_o_pop ase::ui::populate} {
  rename $n {}
  rename $o $n
}
check {RD15 a change logs ONE replayable line; setting the same value again logs nothing} \
  [list $l1 [llength $l2]] [list [list [list ase::ui::set_rundir $K15 $R15]] 1]
check {RD16 a change re-reads results and repopulates once each; the same value again does neither} \
  [list $f1 $f2] [list [list $K15 $K15] [list $K15 $K15]]
check {RD15 every shim restored} \
  [list [info procs rd15_o_log] [info procs rd15_o_refill] [info procs rd15_o_pop]] {{} {} {}}
ase::session_close $K15

} sserr]} { check {SS0 section RD12-RD16 ran to the end} "RAISED:$sserr" {} }

# =============================================================================
# RD-L / RD17 THE WORDS
# =============================================================================
if {[catch {

set MP [pcall ase::ui::menu_path_run_dir]
set pst [dict create design [dict create lib L cell c1 view schematic] \
           simulator ngspice rundir {} options {} \
           analyses {{type op enabled 1}} outputs {} temperature 27]
set fwhy [dict get [ase::predeck_plan ngspice $pst] filewhy]
set cst [ase::state_default]
dict set cst design [dict create cell rc lib $scratch]
dict set cst rundir {}
dict set cst simulator ngspice
dict set cst analyses {{type op enabled 1}}
dict set cst sweep [dict create enabled 1 axes {{kind temp values {27}}}]
set crem ZZNOENTRY
foreach e [ase::campaign_refusals ngspice $cst] {
  if {[lindex $e 0] eq {sharedrundir}} { set crem [lindex $e 3] }
}
check {RD-L the engine's two typed menu paths equal the window's constant} \
  [list $MP [expr {[string first "($MP)" $fwhy] >= 0}] $crem] \
  [list "Setup > Run Directory…" 1 "set one in $MP"]

set SPEC [slurp $SPECMD]
set bul ZZNOBULLET
regexp {\n- \*\*Setup\*\*(.*?)\n- \*\*} $SPEC -> bul
check {RD17 the written menu tree's Setup bullet names Run Directory} \
  [list [expr {[string first {Simulators} $bul] >= 0}] \
        [expr {[string first {Run Directory} $bul] >= 0}]] {1 1}

} wderr]} { check {WD0 section RD-L/RD17 ran to the end} "RAISED:$wderr" {} }

# =============================================================================
# RD19-RD32 THE DIALOG -- display arm only
# =============================================================================
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

if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set FIXOK 1
  set rundir [file normalize [file join $scratch run]]
  if {[catch {
    file mkdir [file join $scratch aselib nfet_clean schematic]
    set f [open [file join $scratch aselib nfet_clean schematic nfet_clean.sch] w]
    puts -nonewline $f $sch_text
    close $f
    set f [open [file join $scratch library.defs] w]
    puts $f "DEFINE aselib [file join $scratch aselib]"
    puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
    puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
    close $f
    set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
    set ::library_registry_defs_only 1
    set ::XSCHEM_LIBRARY_PATH {}
    library_new_view aselib nfet_clean ngspice_state1 ngspice_state1
    set spath [xschem cellview_path aselib/nfet_clean ngspice_state1]
    if {$spath eq {}} { error "fixture: state view did not resolve" }
    set key [ase::session_key aselib nfet_clean ngspice_state1]
    ase::session_open $key [file normalize $spath]
    set st [ase::session_state $key]
    dict set st rundir $rundir
    ase::session_update $key $st
    ase::session_save $key
    ase::session_close $key
  } fixerr]} {
    set FIXOK 0
    puts "FIXTURE ERROR: $fixerr"
  }
  check {RD19 the fixture library, cell and state view were created} $FIXOK 1

  if {$FIXOK} {
  check {RD19 the session window opens} [ase::open_state aselib nfet_clean ngspice_state1] 1
  update
  set top [ase::ui::window_for $key]
  set W $top.rundir
  set LBL [ase::ui::lbl_run_dir_menu]

  # --- RD20: the entry, its place, its command, and the real pick ------------
  if {[catch {
    set labs [mlabels $top.mb.setup]
    set si [lsearch -exact $labs "Simulators…"]
    set cmd [mcmd $top.mb.setup $LBL]
    winv $top.mb.setup $LBL
    check {RD20 Setup lists Run Directory right after Simulators, wired to the dialog, and picking the real entry opens it} \
      [list [expr {$si >= 0}] [lindex $labs [expr {$si + 1}]] $cmd \
            [expr {[string first todo_stub $cmd] < 0}] [wex $W] [wtitle $W]] \
      [list 1 $LBL [list ase::ui::rundir_dialog $key] 1 1 {Run Directory}]
  } e]} { check {RD20 ran to the end} "RAISED:$e" {} }

  # --- RD21: prefill is the RAW key; the hint names the shared default -----
  if {[catch {
    set p1 [wget $W.path]
    set prev [ase::rundir_default_preview]
    set hint [wtext $W.hint]
    ase::ui::rundir_cancel $key
    set st [ase::session_state $key]
    dict set st rundir {}
    ase::session_update $key $st
    ase::ui::rundir_dialog $key
    update
    set p2 [wget $W.path]
    ase::ui::rundir_cancel $key
    set st [ase::session_state $key]
    dict set st rundir $rundir
    ase::session_update $key $st
    check {RD21 the entry holds the state's own key, set or empty, and the hint names the shared default} \
      [list $p1 $p2 [expr {$prev ne {}}] [expr {[string first $prev $hint] >= 0}] \
            [string match {Empty = shared: *} $hint]] \
      [list $rundir {} 1 1 1]
  } e]} { check {RD21 ran to the end} "RAISED:$e" {} }

  # --- RD22: Browse… with the modal chooser stood in for ------------------
  set had_tcd [llength [info commands ::tk_chooseDirectory]]
  if {[catch {
    if {$had_tcd} { rename ::tk_chooseDirectory ::rd22_real_tcd }
    proc ::tk_chooseDirectory {args} { lappend ::rd22_args $args ; return $::rd22_ans }
    set ::rd22_args {}
    ase::ui::rundir_dialog $key
    update
    set ::rd22_ans [file join $scratch picked]
    winv $W.browse
    set g1 [wget $W.path]
    set ::rd22_ans {}
    winv $W.browse
    set g2 [wget $W.path]
    set before [ser $key]
    check {RD22 a chosen directory fills the entry, a cancelled chooser leaves it, and nothing is committed} \
      [list $g1 $g2 [llength $::rd22_args] \
            [expr {[lsearch -exact [lindex $::rd22_args 0] -parent] >= 0}] \
            [ase::state_get [ase::session_state $key] rundir]] \
      [list [file join $scratch picked] [file join $scratch picked] 2 1 $rundir]
    ## with an empty entry the chooser must not START at the shared default
    went $W.path {}
    winv $W.browse
    set ia {}
    set a3 [lindex $::rd22_args 2]
    set ix [lsearch -exact $a3 -initialdir]
    if {$ix >= 0} { set ia [lindex $a3 [expr {$ix + 1}]] }
    check {RD22 with an empty entry Browse starts at HOME, never at the shared default} \
      [list [expr {$ia ne {}}] [ase::rundir_same_path $ia [ase::rundir_default_preview]] \
            [ase::rundir_same_path $ia ~]] {1 0 1}
    ## put text back, so RD23's Use Default has something to empty
    went $W.path [file join $scratch picked]
  } e]} { check {RD22 ran to the end} "RAISED:$e" {} }
  catch {rename ::tk_chooseDirectory {}}
  if {$had_tcd} { catch {rename ::rd22_real_tcd ::tk_chooseDirectory} }
  check {RD22 the real chooser is back} \
    [expr {[llength [info commands ::tk_chooseDirectory]] == $had_tcd \
           && [llength [info commands ::rd22_real_tcd]] == 0}] 1

  # --- RD23: Use Default empties the entry and commits nothing -------------
  if {[catch {
    set before [ser $key]
    winv $W.default
    check {RD23 Use Default empties the entry and leaves the state alone until OK} \
      [list [wget $W.path] [expr {[ser $key] eq $before}] [wex $W]] {{} 1 1}
    ase::ui::rundir_cancel $key
  } e]} { check {RD23 ran to the end} "RAISED:$e" {} }

  # --- RD24: OK, valid and invalid -----------------------------------------
  if {[catch {
    ase::session_save $key
    ase::ui::rundir_dialog $key
    update
    set R24 [file join $scratch r24new]
    went $W.path $R24
    winv $W.btns.proceed
    update
    check {RD24 OK on a valid path stores it absolute, dirties the session, marks the title and closes the dialog} \
      [list [ase::state_get [ase::session_state $key] rundir] [ase::session_dirty $key] \
            [string match {* \*} [wtitle $top]] [wex $W] [rdrecs $key]] \
      [list [file normalize $R24] 1 1 0 {}]
    set R24F [file join $scratch r24file]
    set f [open $R24F w] ; puts $f x ; close $f
    ase::ui::rundir_dialog $key
    update
    went $W.path $R24F
    set before [ser $key]
    winv $W.btns.proceed
    update
    set why [lindex [ase::rundir_validate $R24F] 2]
    check {RD24 OK on a file keeps the dialog up, says the validator's reason in it, writes nothing, and posts no alert} \
      [list [wex $W] [wtext $W.status] [expr {[ser $key] eq $before}] [wex .alert] \
            [expr {$why ne {}}]] \
      [list 1 $why 1 0 1]
    ## and the CIW half of the same refusal
    rename ::ase::echo ::rd24_real_echo
    proc ::ase::echo {msg {tag {}}} { lappend ::rd24_calls [list $msg $tag] }
    set ::rd24_calls {}
    winv $W.btns.proceed
    update
    rename ::ase::echo {}
    rename ::rd24_real_echo ::ase::echo
    check {RD24 the refusal is also said ONCE in the CIW, with the error tag and the validator's reason} \
      [list [llength $::rd24_calls] [lindex $::rd24_calls 0 1] \
            [expr {[string first $why [lindex $::rd24_calls 0 0]] >= 0}]] {1 error 1}
    ase::ui::rundir_cancel $key
    ## OK stores the VALIDATOR's absolute value, not the typed text: a relative
    ## path and a `~` path, each driven through the dialog. cwd and HOME are
    ## pointed into scratch, because the pane refresh after OK creates the dir.
    set pwd0 [pwd] ; set home0 $::env(HOME)
    set r24rel [file join $scratch r24cwd]
    set r24home [file join $scratch r24home]
    file mkdir $r24rel $r24home
    set legs {}
    foreach {setup txt} [list [list cd $r24rel] r24_rel/sub \
                              [list set ::env(HOME) $r24home] ~/r24x] {
      eval $setup
      set exp [lindex [ase::rundir_validate $txt] 1]
      ase::ui::rundir_dialog $key
      update
      went $W.path $txt
      winv $W.btns.proceed
      update
      set got [ase::state_get [ase::session_state $key] rundir]
      lappend legs [list [expr {$got eq $exp}] [file pathtype $got] \
                         [expr {$got ne $txt}] [wex $W]]
      cd $pwd0 ; set ::env(HOME) $home0
    }
    check {RD24 OK on a relative path and on a ~ path stores the validator's ABSOLUTE value, which differs from the typed text} \
      $legs {{1 absolute 1 0} {1 absolute 1 0}}
  } e]} { check {RD24 ran to the end} "RAISED:$e" {} }

  # --- RD25: refused while a run is live; OK works again once it ends ------
  if {[catch {
    ase::session_save $key
    set R25 [file join $scratch r25]
    set ::execute(pipe,9166525) fake
    ase::session_setattr $key run_id 9166525
    ase::ui::rundir_dialog $key
    update
    set s1 [wcget $W.btns.proceed -state]
    set t1 [wtext $W.status]
    went $W.path $R25
    set before [ser $key]
    winv $W.btns.proceed
    update
    set mid [list [wex $W] [expr {[ser $key] eq $before}] [wcget $W.btns.proceed -state]]
    ## the run ends with the dialog still open: the SAME OK now commits
    ase::session_setattr $key run_id {}
    unset ::execute(pipe,9166525)
    update
    winv $W.btns.proceed
    update
    set end [list [wex $W] [ase::state_get [ase::session_state $key] rundir] \
                  [ase::session_dirty $key]]
    ## busy only AFTER open: OK refuses and writes nothing
    ase::ui::rundir_dialog $key
    update
    went $W.path [file join $scratch r25b]
    set ::execute(pipe,9166526) fake
    ase::session_setattr $key run_id 9166526
    set before [ser $key]
    winv $W.btns.proceed
    update
    set t2 [wtext $W.status]
    set after [ser $key]
    set up [wex $W]
    ase::session_setattr $key run_id {}
    unset ::execute(pipe,9166526)
    ase::ui::rundir_cancel $key
    set MS [ase::ui::menu_path_stop]
    check {RD25 busy at open says the Stop path but leaves OK live; a press while busy refuses and writes nothing; the same OK commits once the run ends} \
      [list $s1 [expr {[string first $MS $t1] >= 0}] $mid $end] \
      [list normal 1 {1 1 normal} [list 0 [file normalize $R25] 1]]
    check {RD25 busy after open makes OK refuse, name the Stop path, and write nothing} \
      [list [expr {[string first $MS $t2] >= 0}] [expr {$before eq $after}] $up] {1 1 1}
  } e]} { check {RD25 ran to the end} "RAISED:$e" {} }

  # --- RD26: Cancel and ESC write nothing ----------------------------------
  if {[catch {
    set before [ser $key] ; set dbefore [ase::session_dirty $key]
    ase::ui::rundir_dialog $key
    update
    went $W.path [file join $scratch r26a]
    winv $W.btns.cancel
    set c [list [wex $W] [expr {[ser $key] eq $before}] \
              [expr {[ase::session_dirty $key] == $dbefore}] [rdrecs $key]]
    ase::ui::rundir_dialog $key
    update
    went $W.path [file join $scratch r26b]
    set delivered [send_key $W.path <Key-Escape> {![wex $W]}]
    set x [list $delivered [wex $W] [expr {[ser $key] eq $before}] \
              [expr {[ase::session_dirty $key] == $dbefore}] [rdrecs $key]]
    check {RD26 Cancel and ESC each close the dialog, leave the state byte-identical and the dirty bit as it was, and clear the records} \
      [list $c $x] [list {0 1 1 {}} {1 0 1 1 {}}]
  } e]} { check {RD26 ran to the end} "RAISED:$e" {} }

  # --- RD27: the title-bar X, PRESSED ---------------------------------------
  if {[catch {
    set before [ser $key]
    ase::ui::rundir_dialog $key
    update
    went $W.path [file join $scratch r27]
    set h [wm protocol $W WM_DELETE_WINDOW]
    uplevel #0 $h
    update
    check {RD27 the title-bar close runs Cancel: dialog gone, state unchanged, records cleared} \
      [list $h [wex $W] [expr {[ser $key] eq $before}] [rdrecs $key]] \
      [list [list ase::ui::rundir_cancel $key] 0 1 {}]
  } e]} { check {RD27 ran to the end} "RAISED:$e" {} }

  # --- RD28: an advisory reaches the CIW without moving the keyboard ---------
  set had_echo [llength [info commands ::ase::echo]]
  if {[catch {
    rename ::ase::echo ::rd28_real_echo
    proc ::ase::echo {msg {tag {}}} {
      set f0 [focus]
      set r [::rd28_real_echo $msg $tag]
      lappend ::rd28_calls [list $msg $f0 [focus]]
      return $r
    }
    set ::rd28_calls {}
    ase::ui::rundir_dialog $key
    update
    went $W.path [file join $scratch Rd28Up]
    winv $W.btns.proceed
    update
    set adv 0 ; set moved {}
    foreach c $::rd28_calls {
      if {[string first {OP annotation} [lindex $c 0]] >= 0} { incr adv }
      if {[lindex $c 1] ne [lindex $c 2]} { lappend moved $c }
    }
    check {RD28 the advisory is said once in the CIW after OK, and saying it moved no keyboard focus} \
      [list $adv $moved [wex $W] [ase::state_get [ase::session_state $key] rundir]] \
      [list 1 {} 0 [file normalize [file join $scratch Rd28Up]]]
  } e]} { check {RD28 ran to the end} "RAISED:$e" {} }
  catch {rename ::ase::echo {}}
  if {$had_echo} { catch {rename ::rd28_real_echo ::ase::echo} }
  check {RD28 the real notice channel is back} \
    [expr {[llength [info commands ::ase::echo]] == $had_echo \
           && [llength [info commands ::rd28_real_echo]] == 0}] 1

  # --- RD29: Use Default + OK returns the bench to the shared default -------
  if {[catch {
    ase::session_save $key
    set k0 [ase::state_get [ase::session_state $key] rundir]
    ase::ui::rundir_dialog $key
    update
    winv $W.default
    winv $W.btns.proceed
    update
    check {RD29 Use Default then OK stores {}, dirties, leaves the bench shared and closes the dialog} \
      [list [expr {$k0 ne {}}] [ase::state_get [ase::session_state $key] rundir] \
            [ase::session_dirty $key] [ase::rundir_is_shared [ase::session_state $key]] [wex $W]] \
      {1 {} 1 1 0}
  } e]} { check {RD29 ran to the end} "RAISED:$e" {} }

  # --- RD30: Return in the entry is OK -----------------------------------------
  if {[catch {
    ase::session_save $key
    set R30 [file join $scratch r30]
    ase::ui::rundir_dialog $key
    update
    went $W.path $R30
    set delivered [send_key $W.path <Key-Return> {![wex $W]}]
    check {RD30 Return in the entry commits like OK: key stored, session dirty, dialog closed} \
      [list $delivered [ase::state_get [ase::session_state $key] rundir] \
            [ase::session_dirty $key] [wex $W]] [list 1 [file normalize $R30] 1 0]
  } e]} { check {RD30 ran to the end} "RAISED:$e" {} }

  # --- RD31: a second open keeps what the user typed ----------------------------
  if {[catch {
    ase::ui::rundir_dialog $key
    update
    went $W.path typed_text
    winv $top.mb.setup $LBL
    update
    check {RD31 picking the menu entry again raises the open dialog and keeps the typed text} \
      [list [wex $W] [wget $W.path]] {1 typed_text}
    ase::ui::rundir_cancel $key
  } e]} { check {RD31 ran to the end} "RAISED:$e" {} }

  # --- RD32: an untouched OK on a non-canonical key is a no-op -----------------
  if {[catch {
    set legs {}
    set home0 $::env(HOME)
    set ::env(HOME) $scratch
    set R32 [file join $scratch r32]
    file mkdir $R32
    rename ::ase::echo ::rd32_real_echo
    proc ::ase::echo {msg {tag {}}} { lappend ::rd32_calls $msg }
    foreach raw [list "$R32/" ~/r32 [file dirname $R32]//r32] {
      set st [ase::session_state $key]
      dict set st rundir $raw
      dict set st models [list [dict create file models/rel.lib section tt]]
      ase::session_update $key $st
      ase::session_save $key
      set before [ser $key]
      set ::rd32_calls {}
      ase::ui::rundir_dialog $key
      update
      set pre [wget $W.path]
      winv $W.btns.proceed
      update
      lappend legs [list [expr {$pre eq $raw}] [expr {[ser $key] eq $before}] \
                         [ase::session_dirty $key] [llength $::rd32_calls] [wex $W]]
    }
    rename ::ase::echo {}
    rename ::rd32_real_echo ::ase::echo
    set ::env(HOME) $home0
    set st [ase::session_state $key]
    dict set st models {}
    dict set st rundir $rundir
    ase::session_update $key $st
    ase::session_save $key
    check {RD32 OK on a prefilled trailing-slash, ~ or doubled-separator key writes nothing, stays clean, says no note and closes} \
      $legs {{1 1 0 0 0} {1 1 0 0 0} {1 1 0 0 0}}
  } e]} { check {RD32 ran to the end} "RAISED:$e" {} }
  if {[llength [info commands ::rd32_real_echo]]} {
    catch {rename ::ase::echo {}} ; rename ::rd32_real_echo ::ase::echo
  }

  ase::ui::close $key
  update
  }
} else {
  puts "SKIP: RD19-RD32 need a display -- the dialog is their subject. Every\
 RD1-RD17 row ran."
}

# --- teardown ----------------------------------------------------------------
if {$NDSAVE eq {ZZUNSET}} { catch {unset ::netlist_dir} } else { set ::netlist_dir $NDSAVE }
if {$LNDSAVE eq {ZZUNSET}} { catch {unset ::local_netlist_dir} } else { set ::local_netlist_dir $LNDSAVE }
if {$UCDSAVE eq {ZZUNSET}} { catch {unset ::USER_CONF_DIR} } else { set ::USER_CONF_DIR $UCDSAVE }

# --- verdict -----------------------------------------------------------------
# The dual banner: tests/run_regression.tcl's banner_complete needs the
# whole-line OVERALL line; RESULT stays last-but-one as every sibling has it.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
