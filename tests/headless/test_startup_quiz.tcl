# TIP OF THE DAY, ASKED AS A QUIZ (doc/claude/specs/startup_quiz.md).
#
# src/startup_quiz.tcl is the engine, src/startup_quiz_bank.tcl the questions.
# This suite fences both, in bands:
#
#   Z*  the state a session starts in: nothing has read the bank, and asking
#       for the launch decision on an arm that will not show does not read it.
#   B*  the launch decision (startup_quiz::decide), one gate at a time.
#   V*  the bank's own validation: every malformed entry is refused by name and
#       costs nobody else their place; a broken or missing file never raises.
#   C*  choosing: no answered question while an unanswered one exists, none
#       displayed twice in a session, the round restarts when all are answered.
#   N*  questions with a condition (`only`): asked where it holds, nowhere else.
#   O*  option order: True/False fixed, multiple choice shuffled, `last` pinned.
#   G*  marking, and the wording of every verdict.
#   E*  the saved switch and the answered list (USER_CONF_DIR is a scratch dir).
#   A*  THE SHIPPED BANK: it loads clean, it is varied, every text fits its
#       budget, and EVERY QUESTION'S PROOF HOLDS against this tree.
#   F*  the wiring: the two actions.csv rows, the Help-menu entries, the caught
#       `source`, the install list, and where Tcl_AppInit calls the launch hook.
#   L*  real launches, each a CHILD process: which command lines get asked.
#   M*  a CHILD whose share dir has no engine, or one that fails partway: it
#       says so once, in a line that is not a notice channel announcement, so
#       it spends neither notice-channel latch and a later channel fault is
#       still announced; it keeps no engine proc, and its table, palette and
#       menus are the control's less the engine's entries; a plain launch on
#       the partway one is not asked.
#   D*  the dialog itself, driven through its widgets (display arm only).
#
# THE PROOFS (band A). Every bank entry carries a `proof`: an expression over the
# P_* helpers below that is true while the entry's claim is still right. A
# shipped feature's proof says the thing is there (a proc, a menu label, a key
# binding, a default); an upcoming feature's proof says it is still absent. So a
# renamed menu entry, a rebound key or a planned feature that has since been
# built reddens the question that talks about it, here, and not in front of a
# user. The engine never evaluates a proof; only this suite does.
#
# Run:
#   headless: tests/headless/run_suites.sh --nogui test_startup_quiz
#   display:  tests/headless/run_suites.sh test_startup_quiz
# Registered in hcases AND dcases in tests/run_regression.tcl: band D and most of
# band L need a display; on the --nogui arm they print an uppercase SKIPPED:
# line, which is neither a counted nor a skip-counted shape. Prints "OVERALL: ok".

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
  flush stdout
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# Evaluate $script in the CALLER's frame and return its result, or a legible
# sentinel if it raised, so one missing proc costs one row and not the band.
proc q {script} {
  if {[catch {uplevel 1 $script} r]} { return "RAISED($r)" }
  return $r
}

set here [file normalize [file dirname [info script]]]
set root [file normalize [file join $here .. ..]]
set bin  [info nameofexecutable]
source [file join $here scratch.tcl]
set work [test_scratch startup_quiz]
set have_tk [expr {[llength [info commands winfo]] && ![catch {winfo exists .}]}]

proc slurp {path} {
  if {[catch {open $path r} f]} { return {} }
  set s [read $f]; close $f
  return $s
}
proc spit {path text} {
  set f [open $path w]; puts -nonewline $f $text; close $f
}

# =====================================================================
# Z* -- the state a session starts in
# =====================================================================
check "Z1 the engine was sourced on this arm (its procs exist)" \
  [llength [info commands ::startup_quiz::at_launch]] 1
check "Z2 nothing has read the bank before a question was asked for" \
  [q {set ::startup_quiz::loaded}] 0
check "Z3 this suite's own launch has not been through the hook (it runs as --script, before it)" \
  [q {set ::startup_quiz::launch}] {}
check "Z4 the launch decision on this arm is a no, for the reason this arm has" \
  [q {startup_quiz::launch_decision}] [expr {$have_tk ? {0 automation} : {0 no-display}}]
check "Z5 asking for that decision did not read the bank" [q {set ::startup_quiz::loaded}] 0
check "Z6 the shipped default is ON (the set_ne line itself: the live value may come from a saved choice)" \
  [regexp -line {^set_ne startup_quiz 1$} [slurp [file join $root src xschem.tcl]]] 1

# Everything below writes its preference files here, never the real ~/.xschem.
set conf [file join $work conf]
file mkdir $conf
set ::USER_CONF_DIR $conf
proc fresh {} {
  set ::startup_quiz 1
  set ::startup_quiz_done {}
  set ::startup_quiz::shown {}
  set ::startup_quiz::cur {}
  set ::startup_quiz::rng {}
}
fresh

# =====================================================================
# B* -- the launch decision, one gate at a time
# =====================================================================
set yes {tk 1 automation 0 nolog 0 enabled 1 questions 5}
check "B1 a display, a person, logging on, switched on, questions: ask" \
  [q {startup_quiz::decide $yes}] {1 show}
foreach {row key val want} {
  B2 tk         0 {0 no-display}
  B3 automation 1 {0 automation}
  B4 nolog      1 {0 nolog}
  B5 enabled    0 {0 off}
  B6 questions  0 {0 no-questions}
} {
  set in $yes
  dict set in $key $val
  check "$row with only '$key' changed the answer is no, and says why" \
    [q {startup_quiz::decide $in}] $want
}
check "B7 with every gate against it, the first one named is the display" \
  [q {startup_quiz::decide {tk 0 automation 1 nolog 1 enabled 0 questions 0}}] {0 no-display}
check "B8 a script-driven session is named before the saved switch" \
  [q {startup_quiz::decide {tk 1 automation 1 nolog 0 enabled 0 questions 5}}] {0 automation}

unset -nocomplain ::startup_quiz
check "B9 the switch unset counts as on" [q {startup_quiz::enabled}] 1
foreach {v want} {0 0 1 1 no 0 yes 1 false 0 true 1 off 0 on 1 banana 1 {} 1} {
  set ::startup_quiz $v
  check "B10 the switch set to '$v' reads as $want" [q {startup_quiz::enabled}] $want
}
set ::startup_quiz 1
set keep_pipe [expr {[info exists ::cli_opt_pipe] ? $::cli_opt_pipe : {}}]
check "B11 this suite's own session was started with --pipe, and C says so" $keep_pipe 1
check "B12 a --pipe session is a script driving, not a person" [q {startup_quiz::automation}] 1
set ::cli_opt_pipe 0
check "B13 a session without --pipe is not" [q {startup_quiz::automation}] 0
set keep_nrf [expr {[info exists ::no_recent_files] ? $::no_recent_files : {}}]
set ::no_recent_files 1
check "B14 --norecent alone does not make it one (a person passes that option)" [q {startup_quiz::automation}] 0
if {$keep_nrf ne {}} { set ::no_recent_files $keep_nrf }

# =====================================================================
# V* -- validation of bank entries
# =====================================================================
set synth [file join $work synth_bank.tcl]
spit $synth {
startup_quiz::add a {type tf kind shipped topic T q {Statement a} ok true why {Why a} proof {1}}
startup_quiz::add b {type tf kind upcoming topic T q {Statement b} ok false why {Why b} proof {1}}
startup_quiz::add c {type tf kind myth topic T q {Statement c} ok false why {Why c} proof {1}}
startup_quiz::add d {type mc kind howto topic T q {Question d} a {d0 d1 d2 d3} ok 2 why {Why d} proof {1}}
startup_quiz::add e {type mc kind upcoming topic T q {Question e} a {e0 e1 e2 e3} ok 1 last 3
                     why {Why e} proof {1}}
}
check "V1 a five-question file loads as five questions" [q {startup_quiz::load_bank $synth}] 5
check "V2 ... with nothing refused" [q {set ::startup_quiz::bank_errors}] {}
check "V3 ... in file order" [q {set ::startup_quiz::order}] {a b c d e}

# Each row: an id, a body, and words the refusal must contain.
set bad {
  {Bad_Id   {type tf kind shipped topic T q Q ok true why W proof 1}            {the id may hold only}}
  {short    {type tf}                                                            {missing key 'kind'}}
  {notdict  {type tf kind shipped topic}                                         {not a list of key/value pairs}}
  {unk      {type tf kind shipped topic T q Q ok true why W proof 1 colour red}  {unknown key 'colour'}}
  {nowhy    {type tf kind shipped topic T q Q ok true proof 1}                   {missing key 'why'}}
  {noproof  {type tf kind shipped topic T q Q ok true why W}                     {missing key 'proof'}}
  {emproof  {type tf kind shipped topic T q Q ok true why W proof { }}           {'proof' is empty}}
  {badtype  {type xx kind shipped topic T q Q ok true why W proof 1}             {neither tf nor mc}}
  {tfa      {type tf kind shipped topic T q Q a {x y z} ok true why W proof 1}   {takes no 'a'}}
  {tflast   {type tf kind shipped topic T q Q last 0 ok true why W proof 1}      {takes no 'last'}}
  {tfkind   {type tf kind howto topic T q Q ok true why W proof 1}               {does not go with a true/false}}
  {tfok     {type tf kind shipped topic T q Q ok maybe why W proof 1}            {must be true or false}}
  {tfcontra {type tf kind shipped topic T q Q ok false why W proof 1}            {contradict}}
  {tfcontr2 {type tf kind myth topic T q Q ok true why W proof 1}                {contradict}}
  {mcnoa    {type mc kind howto topic T q Q ok 0 why W proof 1}                  {missing key 'a'}}
  {mctwo    {type mc kind howto topic T q Q a {x y} ok 0 why W proof 1}          {3 to 5 options}}
  {mcsix    {type mc kind howto topic T q Q a {u v w x y z} ok 0 why W proof 1}  {3 to 5 options}}
  {mcok     {type mc kind howto topic T q Q a {x y z} ok 7 why W proof 1}        {index of an option}}
  {mcokt    {type mc kind howto topic T q Q a {x y z} ok true why W proof 1}     {index of an option}}
  {mcdup    {type mc kind howto topic T q Q a {x y x} ok 0 why W proof 1}        {listed twice}}
  {mckind   {type mc kind shipped topic T q Q a {x y z} ok 0 why W proof 1}      {does not go with a multiple-choice}}
  {mclast   {type mc kind howto topic T q Q a {x y z} ok 0 last 9 why W proof 1} {'last' must be}}
  {emq      {type tf kind shipped topic T q {  } ok true why W proof 1}          {'q' is empty}}
  {emopt    {type mc kind howto topic T q Q a {x {} z} ok 0 why W proof 1}       {an option is empty}}
}
set nbad 0
foreach row $bad {
  lassign $row id body words
  set before [llength $::startup_quiz::order]
  set r [q {startup_quiz::add $id $body}]
  set line [lindex $::startup_quiz::bank_errors end]
  check "V4 '$id' is refused (add answers 0), named, with the reason ($words)" \
    [list $r [string match "$id: *" $line] [expr {[string first $words $line] >= 0}] \
          [expr {[llength $::startup_quiz::order] - $before}]] {0 1 1 0}
  incr nbad
}
check "V5 the refusal table above really ran ($nbad shapes)" [expr {$nbad >= 24}] 1
set before [llength $::startup_quiz::order]
check "V6 an id already taken is refused too" [q {startup_quiz::add a {type tf kind shipped topic T q Q ok true why W proof 1}}] 0
check "V7 ... and says so" [string match {a: this id is used twice} [lindex $::startup_quiz::bank_errors end]] 1
check "V8 after all of those the five good questions are still the bank" \
  [list [llength $::startup_quiz::order] $before] {5 5}
check "V9 a good entry after a bad one still goes in" \
  [q {startup_quiz::add f {type tf kind shipped topic T q {Statement f} ok true why {Why f} proof {1}}}] 1

check "V10 text wrapped over several lines in the file is stored as one paragraph" \
  [q {dict get [startup_quiz::validate w {type tf kind shipped topic T ok true proof 1 why W q {one
          two    three
     four}}] q}] {one two three four}
check "V11 a true/false question is stored as the options True and False, true first" \
  [q {dict get [startup_quiz::get a] a}] {True False}
check "V12 ... with ok as an index: true is 0, false is 1" \
  [list [q {dict get [startup_quiz::get a] ok}] [q {dict get [startup_quiz::get b] ok}]] {0 1}

set broken [file join $work broken_bank.tcl]
spit $broken {
startup_quiz::add p {type tf kind shipped topic T q {Statement p} ok true why {Why p} proof {1}}
this_is_not_a_command at all
startup_quiz::add r {type tf kind shipped topic T q {Statement r} ok true why {Why r} proof {1}}
}
check "V13 a file that breaks part way down never raises and keeps what it read" \
  [q {startup_quiz::load_bank $broken}] 1
check "V14 ... and names the file in one line" \
  [list [llength $::startup_quiz::bank_errors] \
        [string match "$broken: *this_is_not_a_command*" [lindex $::startup_quiz::bank_errors 0]]] {1 1}
set nofile [file join $work no_such_bank.tcl]
check "V15 a missing file is zero questions, not an error" [q {startup_quiz::load_bank $nofile}] 0
check "V16 ... and one line saying it cannot be read" \
  [string match "$nofile: cannot be read" [lindex $::startup_quiz::bank_errors 0]] 1
check "V17 with no question there is nothing to pick" [q {startup_quiz::pick}] {}

# =====================================================================
# C* -- choosing the next question
# =====================================================================
startup_quiz::load_bank $synth
fresh
set ::startup_quiz::rng {apply {{n} {return 0}}}
check "C1 nothing answered, nothing shown: the first of all five" [q {startup_quiz::pick}] a
set ::startup_quiz_done {a}
check "C2 an answered question is passed over" [q {startup_quiz::pick}] b
set ::startup_quiz::shown {b}
check "C3 so is one already displayed in this session" [q {startup_quiz::pick}] c
set ::startup_quiz::shown {b c d e}
check "C4 when the rest were all displayed, an unanswered one comes round again, never the answered one" \
  [q {startup_quiz::pick e}] b
check "C5 ... and never the one on display" [q {startup_quiz::pick b}] c
set ::startup_quiz_done {a b c d e}
check "C6 when every question is answered the round starts again, away from the one on display" \
  [q {startup_quiz::pick a}] b
check "C7 ... and the answered list is emptied for the new round" [q {set ::startup_quiz_done}] {}
set ::startup_quiz_done {zz a a nope}
check "C8 ids the bank does not hold, and repeats, are dropped from the answered list" \
  [q {startup_quiz::done_ids}] {a}
set ::startup_quiz_done "\{ not a list"
check "C9 an answered list that is not a list reads as empty and does not raise" \
  [q {startup_quiz::done_ids}] {}
fresh
set seen {}
set cur {}
for {set i 0} {$i < 5} {incr i} {
  set cur [q {startup_quiz::pick $cur}]
  lappend seen $cur
  lappend ::startup_quiz::shown $cur
  lappend ::startup_quiz_done $cur
}
check "C10 five picks with Tcl's own rand(), each answered: all five questions, none twice" \
  [lsort $seen] {a b c d e}
set one [file join $work one_bank.tcl]
spit $one {startup_quiz::add only {type tf kind shipped topic T q Q ok true why W proof 1}}
startup_quiz::load_bank $one
set ::startup_quiz_done {only}
check "C11 a one-question bank hands back its one question even when it is on display" \
  [q {startup_quiz::pick only}] only

# =====================================================================
# N* -- questions that apply only to some sessions (`only`)
# =====================================================================
set cond [file join $work cond_bank.tcl]
spit $cond {
startup_quiz::add yes   {type tf kind shipped topic T q Qy ok true why W proof 1 only {1}}
startup_quiz::add no    {type tf kind shipped topic T q Qn ok true why W proof 1 only {0}}
startup_quiz::add boom  {type tf kind shipped topic T q Qb ok true why W proof 1 only {[error boom]}}
startup_quiz::add word  {type tf kind shipped topic T q Qw ok true why W proof 1 only {banana}}
startup_quiz::add flag  {type tf kind shipped topic T q Qf ok true why W proof 1 only {$::quiz_flag}}
startup_quiz::add plain {type tf kind shipped topic T q Qp ok true why W proof 1}
startup_quiz::add blank {type tf kind shipped topic T q Qk ok true why W proof 1 only { }}
}
check "N1 a bank with conditions loads whole: a condition is not checked when the file is read" \
  [list [q {startup_quiz::load_bank $cond}] $::startup_quiz::bank_errors] {7 {}}
fresh
set ::quiz_flag 0
set got {}
foreach id {yes no boom word flag plain blank} { lappend got [q {startup_quiz::eligible $id}] }
check "N2 true applies; false, an error and a non-boolean do not; none, or a blank one, always applies" \
  $got {1 0 0 0 0 1 1}
check "N3 the questions that apply, in bank order" [q {startup_quiz::eligible_ids}] {yes plain blank}
set ::quiz_flag 1
check "N4 a condition is read each time it is asked, not once" [q {startup_quiz::eligible_ids}] {yes flag plain blank}
set ::quiz_flag 0
set strays {}
for {set i 0} {$i < 60} {incr i} {
  set ::startup_quiz::shown {}
  set id [startup_quiz::pick]
  if {[lsearch -exact {yes plain blank} $id] < 0} { lappend strays $id }
}
check "N5 60 picks never hand out a question that does not apply" $strays {}
set ::startup_quiz_done {yes flag plain blank}
set ::startup_quiz::rng {apply {{n} {return 0}}}
check "N6 when every question that applies is answered, the round restarts among those" \
  [q {startup_quiz::pick yes}] plain
check "N7 ... and a question answered in a session where it did apply stays answered" \
  $::startup_quiz_done {flag}
set none [file join $work none_bank.tcl]
spit $none {startup_quiz::add never {type tf kind shipped topic T q Q ok true why W proof 1 only {0}}}
startup_quiz::load_bank $none
check "N8 a bank where nothing applies here has nothing to pick" [q {startup_quiz::pick}] {}
fresh

# =====================================================================
# O* -- the order options are displayed in
# =====================================================================
startup_quiz::load_bank $synth
fresh
check "O1 True/False is never shuffled" [q {startup_quiz::order_options a}] {0 1}
set ::startup_quiz::rng {apply {{n} {return 0}}}
check "O2 multiple choice follows the random source (always-0 gives this exact order)" \
  [q {startup_quiz::order_options d}] {1 2 3 0}
check "O3 an option named by 'last' stays at the bottom" [q {startup_quiz::order_options e}] {1 2 0 3}
set ::startup_quiz::rng {apply {{n} {return 99}}}
check "O4 a random source answering out of range is ignored, not obeyed" \
  [lsort [q {startup_quiz::order_options d}]] {0 1 2 3}
set ::startup_quiz::rng {apply {{n} {return banana}}}
check "O5 ... and so is one answering a word" [lsort [q {startup_quiz::order_options d}]] {0 1 2 3}
set ::startup_quiz::rng {}
set perms 0; set lastok 0; set pos {}
for {set i 0} {$i < 300} {incr i} {
  set p [startup_quiz::order_options d]
  if {[lsort $p] eq {0 1 2 3}} { incr perms }
  dict set pos [lsearch -exact $p 2] 1
  if {[lindex [startup_quiz::order_options e] end] == 3} { incr lastok }
}
check "O6 300 shuffles with Tcl's own rand() are 300 permutations of the four options" $perms 300
check_true "O7 ... and the right answer turns up in at least three of the four places" \
  [expr {[dict size $pos] >= 3}]
check "O8 ... while 'last' stayed last in all 300" $lastok 300
check "O9 multiple-choice options are lettered by where they are displayed" \
  [list [q {startup_quiz::option_text d {1 2 3 0} 0}] [q {startup_quiz::option_text d {1 2 3 0} 3}]] \
  {{A. d1} {D. d0}}
check "O10 True/False options are not lettered" \
  [list [q {startup_quiz::option_text a {0 1} 0}] [q {startup_quiz::option_text a {0 1} 1}]] {True False}
check "O11 the line above the question says which kind it is" \
  [list [q {startup_quiz::prompt a}] [q {startup_quiz::prompt d}]] {{True or false?} {Pick one:}}

# =====================================================================
# G* -- marking, and the wording of every verdict
# =====================================================================
proc verdict {id pick} {
  set g [q {startup_quiz::grade $id $pick}]
  if {[catch {list [dict get $g correct] [dict get $g head]} r]} { return $g }
  return $r
}
check "G1 a shipped feature, answered True"  [verdict a 0] {1 {You nailed it!}}
check "G2 a shipped feature, answered False" [verdict a 1] {0 {Not quite: this one is true.}}
check "G3 an upcoming feature, answered False" [verdict b 1] \
  {1 {You nailed it. This is an upcoming feature! Stay tuned!}}
check "G4 an upcoming feature, answered True" [verdict b 0] \
  {0 {Not yet! This is an upcoming feature. Stay tuned!}}
check "G5 a false statement, answered False" [verdict c 1] {1 {You nailed it!}}
check "G6 a false statement, answered True"  [verdict c 0] {0 {Not quite: this one is false.}}
check "G7 multiple choice, the right option" [verdict d 2] {1 {You nailed it!}}
check "G8 multiple choice, a wrong option"   [verdict d 0] {0 {Not quite.}}
check "G9 which-is-not-built-yet, the right option" [verdict e 1] \
  {1 {You nailed it. This is an upcoming feature! Stay tuned!}}
check "G10 which-is-not-built-yet, a wrong option" [verdict e 0] {0 {Not quite: that one already works.}}
check "G11 the explanation and the right option's index come back with the verdict" \
  [list [q {dict get [startup_quiz::grade d 0] why}] [q {dict get [startup_quiz::grade d 0] ok}]] {{Why d} 2}

# =====================================================================
# E* -- the saved switch and the answered list
# =====================================================================
fresh
set pf [file join $conf startup_quiz]
set df [file join $conf startup_quiz_done]
file delete -force $pf $df
set ::startup_quiz 0
check "E1 writing the switch succeeds" [q {startup_quiz::write_pref}] 1
check "E2 the file holds exactly one command, the switch" \
  [regexp -all -line {^[^#\n].*$} [slurp $pf]] 1
check "E3 ... which is this one" [regexp -line {^set startup_quiz 0$} [slurp $pf]] 1
set ::startup_quiz 1
proc reload_in_a_proc {} { startup_quiz::load_conf }
reload_in_a_proc
check "E4 reading it back from INSIDE a proc sets the global switch (not a local of the reader)" \
  $::startup_quiz 0
check "E5 the toggle turns it on, answers the new value" [q {startup_quiz::toggle}] 1
check "E6 ... saves it" [regexp -line {^set startup_quiz 1$} [slurp $pf]] 1
check "E7 ... and tells the person in a sentence" \
  [q {dict get $::xschem::notify_last msg}] {Tip of the day at startup: ON.}
check "E8 toggled again it is off" [list [q {startup_quiz::toggle}] $::startup_quiz] {0 0}
check_true "E9 ... and the off sentence says where to turn it back on" \
  [expr {[string first {Toggle tip of the day at startup} [q {dict get $::xschem::notify_last msg}]] >= 0 \
      && [string first {Ctrl+Shift+P} [q {dict get $::xschem::notify_last msg}]] >= 0}]
check "E10 the short form fits the status field's budget of 28" \
  [expr {[string length [q {dict get $::xschem::notify_last short}]] <= 28}] 1
set ::startup_quiz yes
check "E11 a word like 'yes' is normalised to 1 when the switch is saved" \
  [list [q {startup_quiz::pref_changed}] $::startup_quiz [regexp -line {^set startup_quiz 1$} [slurp $pf]]] {1 1 1}
check "E12 set_enabled 0 turns it off and saves" \
  [list [q {startup_quiz::set_enabled 0}] [regexp -line {^set startup_quiz 0$} [slurp $pf]]] {0 1}
set ::startup_quiz banana
spit $pf "set startup_quiz maybe\n"
startup_quiz::load_conf
check "E13 a saved value that is not a boolean reads back as the default, 1" $::startup_quiz 1

startup_quiz::load_bank $synth
fresh
set ::cli_opt_pipe 1
check "E14 in an automation session an answered question is remembered for the session" \
  [q {startup_quiz::mark_done a}] {a}
check "E15 ... but nothing is written" [file exists $df] 0
set ::cli_opt_pipe 0
check "E16 in a person's session it is written" [list [q {startup_quiz::mark_done b}] [file exists $df]] {{a b} 1}
check "E17 the file holds exactly one command, the list" \
  [list [regexp -all -line {^[^#\n].*$} [slurp $df]] [regexp -line {^set startup_quiz_done \{a b\}$} [slurp $df]]] {1 1}
check "E18 answering the same question again does not list it twice" [q {startup_quiz::mark_done a}] {a b}
check "E19 an id the bank does not hold is not recorded" [q {startup_quiz::mark_done zz}] {a b}
set ::startup_quiz_done {}
reload_in_a_proc
check "E20 the list reads back from inside a proc, into the global" $::startup_quiz_done {a b}

set spaced [file join $work {conf with space}]
file mkdir $spaced
set ::USER_CONF_DIR $spaced
set ::startup_quiz 0
check "E21 a configuration directory with a space in its path: written" [q {startup_quiz::write_pref}] 1
set ::startup_quiz 1
startup_quiz::load_conf
check "E22 ... and read back" $::startup_quiz 0
set ::USER_CONF_DIR [file join $work no_such_dir]
check "E23 a directory that is not there: the writer answers 0 and does not raise" \
  [q {startup_quiz::write_pref}] 0
check "E24 ... the reader is a silent no-op" [catch {startup_quiz::load_conf}] 0
set ::startup_quiz 1
set r [q {startup_quiz::set_enabled 0}]
check_true "E25 ... and the person is told the choice holds for this session only" \
  [expr {$r eq {0} && [string first {this session only} [q {dict get $::xschem::notify_last msg}]] >= 0}]
set ::USER_CONF_DIR $conf
file delete -force $pf $df
fresh

# =====================================================================
# A* -- the shipped bank
# =====================================================================
set bankfile [q {startup_quiz::bank_path}]
set nq [q {startup_quiz::load_bank $bankfile}]
check "A1 the shipped bank loads with nothing refused" [q {set ::startup_quiz::bank_errors}] {}
set banktext [slurp $bankfile]
set nadd [regexp -all -line {^startup_quiz::add\s} $banktext]
check "A2 every startup_quiz::add in the file became a question" $nq $nadd
check_true "A3 there are at least 60 questions ($nq)" [expr {[string is integer -strict $nq] && $nq >= 60}]
foreach f {startup_quiz.tcl startup_quiz_bank.tcl} {
  set t [slurp [file join $root src $f]]
  check "A4 src/$f is plain ASCII (no glyph the X fonts or the C locale could mangle)" \
    [regexp {[^\x09\x0a\x20-\x7e]} $t] 0
}

# What the bank is made of.
set types [dict create]; set kinds [dict create]; set topics [dict create]
set toolong {}
set budget {q 240 why 420 topic 28 opt 110}
if {[string is integer -strict $nq]} {
  foreach id $::startup_quiz::order {
    set e [startup_quiz::get $id]
    dict incr types [dict get $e type]
    dict incr kinds "[dict get $e type]/[dict get $e kind]"
    dict incr topics [dict get $e topic]
    foreach k {q why topic} {
      if {[string length [dict get $e $k]] > [dict get $budget $k]} {
        lappend toolong "$id.$k=[string length [dict get $e $k]]"
      }
    }
    foreach o [dict get $e a] {
      if {[string length $o] > [dict get $budget opt]} { lappend toolong "$id.option=[string length $o]" }
    }
  }
}
proc cnt {d k} { expr {[dict exists $d $k] ? [dict get $d $k] : 0} }
check_true "A5 both question types are there, at least 10 of each ([cnt $types tf] true/false, [cnt $types mc] multiple choice)" \
  [expr {[cnt $types tf] >= 10 && [cnt $types mc] >= 10}]
check_true "A6 true/false is not all 'true': at least 8 shipped ([cnt $kinds tf/shipped]), 4 upcoming ([cnt $kinds tf/upcoming]), 3 false statements ([cnt $kinds tf/myth])" \
  [expr {[cnt $kinds tf/shipped] >= 8 && [cnt $kinds tf/upcoming] >= 4 && [cnt $kinds tf/myth] >= 3}]
check_true "A7 the questions range over at least 12 topics ([dict size $topics])" \
  [expr {[dict size $topics] >= 12}]
set most 0
dict for {t n} $topics { if {$n > $most} { set most $n } }
check_true "A8 no one topic has more than 6 questions (most: $most)" [expr {$most <= 6}]
check "A9 every text is inside its budget (question [dict get $budget q], explanation [dict get $budget why], topic [dict get $budget topic], option [dict get $budget opt] characters)" \
  $toolong {}
set sames {}
if {[string is integer -strict $nq]} {
  set seenq [dict create]
  foreach id $::startup_quiz::order {
    set k [string tolower [dict get [startup_quiz::get $id] q]]
    if {[dict exists $seenq $k]} { lappend sames "$id=[dict get $seenq $k]" }
    dict set seenq $k $id
  }
}
check "A10 no question is asked twice under two ids" $sames {}
set trues 0; set falses 0
if {[string is integer -strict $nq]} {
  foreach id $::startup_quiz::order {
    set e [startup_quiz::get $id]
    if {[dict get $e type] ne {tf}} continue
    if {[dict get $e ok] == 0} { incr trues } else { incr falses }
  }
}
check_true "A11 'always answer True' is not a winning strategy: at least a third of true/false is false ($falses of [expr {$trues + $falses}])" \
  [expr {$falses * 3 >= $trues + $falses}]

# ---- the proof helpers. Each answers 0 or 1 and never raises. --------------
set ::P_cache [dict create]
proc P_text {rel} {
  if {![dict exists $::P_cache $rel]} { dict set ::P_cache $rel [slurp [file join $::root $rel]] }
  return [dict get $::P_cache $rel]
}
# a command or proc of that name exists in this interpreter
proc P_proc {name} { expr {[llength [info commands $name]] > 0} }
# the body of that proc holds that literal text (0 when there is no such proc)
proc P_body {name literal} {
  if {[catch {info body $name} b]} { return 0 }
  expr {[string first $literal $b] >= 0}
}
# ... or matches that regular expression
proc P_bodyre {name re} {
  if {[catch {info body $name} b]} { return 0 }
  regexp -- $re $b
}
# the file (path from the repo root) holds that literal text
proc P_has {rel literal} { expr {[string first $literal [P_text $rel]] >= 0} }
# ... or matches that regular expression
proc P_hasre {rel re} { regexp -- $re [P_text $rel] }
# ... holds a, and b somewhere after it
proc P_order {rel a b} {
  set t [P_text $rel]
  set i [string first $a $t]
  expr {$i >= 0 && [string first $b $t $i] > $i}
}
# the file exists (path from the repo root)
proc P_file {rel} { file exists [file join $::root $rel] }
# the action table (src/actions.csv) has a row with that id
proc P_row {id} {
  if {![info exists ::action_table]} { return {} }
  foreach r $::action_table { if {[dict get $r id] eq $id} { return $r } }
  return {}
}
proc P_action {id} { expr {[P_row $id] ne {}} }
# ... and the palette can run it (a command row with a command)
proc P_palette {id} {
  set r [P_row $id]
  expr {$r ne {} && [dict get $r type] eq {command} && [dict get $r command] ne {}}
}
# ... and its label is exactly that
proc P_label {id label} {
  set r [P_row $id]
  expr {$r ne {} && [dict get $r label] eq $label}
}
# the live binding table has exactly that row: device code mods context action
proc P_bind {dev code mods ctx action} {
  if {[catch {xschem bindings dump} rows]} { return 0 }
  foreach r $rows {
    if {[lrange $r 0 4] eq [list $dev $code $mods $ctx $action]} { return 1 }
  }
  return 0
}
# `xschem <name>` is a subcommand the dispatcher knows
proc P_sub {name} { P_has src/scheduler.c "strcmp(argv\[1\], \"$name\")" }
# the shipped default of a Tcl variable: a `set_ne <var> <value>` line in xschem.tcl
proc P_default {var value} {
  foreach line [split [P_text src/xschem.tcl] "\n"] {
    if {[regexp {^\s*set_ne\s+(\S+)\s+(.*?)\s*$} $line -> v val] && $v eq $var} {
      return [expr {$val eq $value || $val eq "{$value}" || $val eq "\"$value\""}]
    }
  }
  return 0
}
proc proves {expression} {
  if {[catch {uplevel #0 [list expr $expression]} r]} { return "RAISED($r)" }
  return $r
}

check "A12 every helper can say no, on something that is not there" \
  [list [P_proc ::no::such::proc] [P_body ::startup_quiz::show {no such text zzqq}] \
        [P_body ::no::such::proc x] [P_bodyre ::startup_quiz::show {zz+qq}] \
        [P_has src/xschem.tcl {no such text zzqq}] [P_hasre src/xschem.tcl {zz+qq}] \
        [P_order src/xinit.c {source_tcl_file(cli_opt_tcl_script)} {Tcl_CreateCommand(interp, "xschem"}] \
        [P_file src/no_such_file] \
        [P_action no.such.action] [P_palette no.such.action] [P_label help.about_xschem {Not this}] \
        [P_bind key 50 alt canvas no.such.action] [P_sub no_such_subcommand] [P_default startup_quiz 7]] \
  {0 0 0 0 0 0 0 0 0 0 0 0 0 0}
check "A13 ... and yes, on something that is" \
  [list [P_proc ::startup_quiz::show] [P_body ::startup_quiz::show {load_bank}] \
        [P_bodyre ::startup_quiz::show {load_\w+}] \
        [P_has src/xschem.tcl {-label "Command palette"}] [P_hasre src/xschem.tcl {-label\s+"Command palette"}] \
        [P_order src/xinit.c {Tcl_CreateCommand(interp, "xschem"} {source_tcl_file(cli_opt_tcl_script)}] \
        [P_file src/actions.csv] \
        [P_action help.about_xschem] [P_palette help.about_xschem] [P_label help.about_xschem {About XSCHEM}] \
        [P_bind key 50 alt canvas view.toggle_view_type] [P_sub bindings] [P_default startup_quiz 1]] \
  {1 1 1 1 1 1 1 1 1 1 1 1 1}
check "A14 a proof that cannot be evaluated is reported, not passed" \
  [string match {RAISED(*)} [proves {[no_such_helper x]}]] 1

set nproof 0
if {[string is integer -strict $nq]} {
  foreach id $::startup_quiz::order {
    set e [startup_quiz::get $id]
    check "A15 $id ([dict get $e kind]): its proof holds -- [dict get $e proof]" \
      [proves [dict get $e proof]] 1
    incr nproof
  }
}
check "A16 a proof was evaluated for every question" $nproof $nq

# A proof has to ASK something: one that is a bare constant holds for ever.
set soft {}
if {[string is integer -strict $nq]} {
  foreach id $::startup_quiz::order {
    if {[string first \[ [dict get [startup_quiz::get $id] proof]] < 0} { lappend soft $id }
  }
}
check "A17 no question's proof is a bare constant: each one calls something" $soft {}

# Conditions. This suite runs in a plain launch: no Cadence profile, no PDK workarea.
set badonly {}; set ncond 0
if {[string is integer -strict $nq]} {
  foreach id $::startup_quiz::order {
    set o [dict get [startup_quiz::get $id] only]
    if {$o eq {}} continue
    incr ncond
    if {[catch {uplevel #0 [list expr $o]} r] || ![string is boolean -strict $r]} { lappend badonly "$id: $r" }
  }
}
check "A18 every condition in the bank evaluates here to a clean yes or no ($ncond conditions)" $badonly {}
set napply [llength [q {startup_quiz::eligible_ids}]]
check_true "A19 a plain launch, with no profile and no PDK, still has at least 60 questions that apply ($napply)" \
  [expr {$napply >= 60}]
check_true "A20 ... and the conditional ones are the rest ($napply + conditional = $nq)" \
  [expr {[string is integer -strict $nq] && $napply <= $nq && $nq - $napply <= $ncond}]

# =====================================================================
# F* -- the wiring
# =====================================================================
set xt [P_text src/xschem.tcl]
check "F1 xschem.tcl sources the engine under a catch (a session without the file is a session without the quiz)" \
  [expr {[string first "if \{\[catch \{source \$XSCHEM_SHAREDIR/startup_quiz.tcl\}" $xt] >= 0}] 1
check "F2 the engine names no Tk command outside a proc body: sourcing it on a Tk-less interpreter defines its procs and nothing else" \
  [q {
    set i [interp create]
    $i eval {foreach c {toplevel label button frame radiobutton checkbutton pack bind wm winfo font update focus grab destroy} {
      catch {rename $c {}}
    }}
    $i eval [list set XSCHEM_SHAREDIR [file join $root src]]
    set r [list [catch {$i eval [list source [file join $root src startup_quiz.tcl]]} m] \
                [$i eval {llength [info commands ::startup_quiz::show]}]]
    interp delete $i
    set r
  }] {0 1}
foreach f {startup_quiz.tcl startup_quiz_bank.tcl} {
  check "F3 $f is on src/Makefile.in's install list (sourced but not installed is issue 0424)" \
    [regexp -- "\\s[string map {. \\.} $f]\\s" [P_text src/Makefile.in]] 1
}
set mk [file join $root src Makefile]
if {[file exists $mk]} {
  foreach f {startup_quiz.tcl startup_quiz_bank.tcl} {
    check "F4 the generated src/Makefile installs and uninstalls $f (./configure was re-run)" \
      [regexp -all -- "/[string map {. \\.} $f] " [slurp $mk]] 2
  }
} else {
  puts "SKIPPED: F4 (no generated src/Makefile in this tree)"
}
set xi [P_text src/xinit.c]
set at_hook  [string first {startup_quiz::at_launch} $xi]
set at_cmd   [string first {tcleval(cli_opt_tcl_post_command)} $xi]
set at_scr   [string first {source_tcl_file(cli_opt_tcl_script)} $xi]
set at_quit  [string first {"exit %d", exit_code} $xi]
check_true "F5 Tcl_AppInit calls the launch hook after --script, after --command and after the -q exit" \
  [expr {$at_scr > 0 && $at_cmd > $at_scr && $at_quit > $at_cmd && $at_hook > $at_quit}]
check "F6 ... once" [regexp -all {startup_quiz::at_launch\]} $xi] 1

set ID_SHOW   help.tip_of_the_day
set ID_TOGGLE help.tip_of_the_day_startup
check "F7 the palette can run 'ask a question now'" \
  [list [P_palette $ID_SHOW] [q {dict get [P_row $ID_SHOW] command}]] {1 startup_quiz::show}
check "F8 the palette can run the on/off toggle" \
  [list [P_palette $ID_TOGGLE] [q {dict get [P_row $ID_TOGGLE] command}]] {1 startup_quiz::toggle}
set TOGGLE_LABEL [q {dict get [P_row $ID_TOGGLE] label}]
check "F9 the toggle's label says what it toggles" $TOGGLE_LABEL {Toggle tip of the day at startup}
foreach word {tip quiz startup} {
  set hits {}
  foreach id [list $ID_SHOW $ID_TOGGLE] {
    set r [P_row $id]
    set best -1
    foreach field {label help id} {
      set s [q {fuzzy_subseq_score $word [dict get $r $field]}]
      if {[string is integer -strict $s] && $s > $best} { set best $s }
    }
    if {$best >= 0} { lappend hits $id }
  }
  check "F10 typing '$word' in the palette finds [expr {$word eq {startup} ? {the toggle} : {both rows}}] (the palette's own matcher)" \
    $hits [expr {$word eq {startup} ? [list $ID_TOGGLE] : [list $ID_SHOW $ID_TOGGLE]}]
}
check "F11 the dialog's hint and the off sentence both name the toggle by its palette label, word for word" \
  [list [expr {[string first "\"$TOGGLE_LABEL\"" [q {startup_quiz::hint_text}]] >= 0}] \
        [expr {[string first "\"$TOGGLE_LABEL\"" [q {startup_quiz::pref_notice 0}]] >= 0}]] {1 1}
check "F12 the Help menu gets 'ask a question now'" \
  [P_has src/xschem.tcl {menubar.help add command -label "Tip of the day (quiz)..." -command {startup_quiz::show}}] 1
check "F13 the Help menu gets the on/off checkbutton, on the same variable as the dialog's box" \
  [list [P_has src/xschem.tcl {menubar.help add checkbutton -label "Tip of the day at startup" -variable startup_quiz}] \
        [P_has src/startup_quiz.tcl {-variable ::startup_quiz}]] {1 1}

check "F14 the rc template (src/xschemrc) shows the switch, commented out" \
  [regexp -all -line {^# set startup_quiz 0$} [P_text src/xschemrc]] 1

# =====================================================================
# L* -- real launches, each a child process
# =====================================================================
# The child is launched the way the row says, with a HOME of its own, and runs a
# --script that waits for the launch hook's decision (and, when the decision is
# to ask, for the window), then writes what it saw and exits. In a session with
# no engine namespace at all (band M's farms) there is no decision to wait for:
# it watches for a window for a while past the launch delay, then writes
# `no-engine`.
set childscript [file join $work child.tcl]
spit $childscript {
  set ::W_out $::env(QUIZ_WITNESS)
  proc w_write {when} {
    set launch {HOOK-NOT-RUN}
    catch { if {$::startup_quiz::launch ne {}} { set launch $::startup_quiz::launch } }
    set win 0
    catch { set win [winfo exists .startup_quiz] }
    set grab {}
    catch { set grab [grab current] }
    set loaded NO-ENGINE
    catch { set loaded $::startup_quiz::loaded }
    set cur NO-ENGINE
    catch { set cur $::startup_quiz::cur }
    set f [open $::W_out w]
    puts $f [list when $when launch $launch win $win grab $grab switch $::startup_quiz \
                  loaded $loaded cur $cur]
    close $f
  }
  rename exit w_real_exit
  proc exit {args} { catch {w_write exit} ; w_real_exit {*}$args }
  proc w_poll {n} {
    set l {}
    catch { set l $::startup_quiz::launch }
    set win 0
    catch { set win [winfo exists .startup_quiz] }
    if {$l ne {} && (![lindex $l 0] || $win)} { w_write settled ; w_real_exit 0 }
    if {![namespace exists ::startup_quiz] && ($win || $n >= 15)} { w_write no-engine ; w_real_exit 0 }
    if {$n >= 100} { w_write deadline ; w_real_exit 0 }
    after 100 [list w_poll [expr {$n + 1}]]
  }
  after 100 {w_poll 0}
}
## $farm, when given, is the child's XSCHEM_SHAREDIR (band M)
proc launch {tag flags {conf_lines {}} {farm {}}} {
  global work bin childscript
  set home [file join $work home_$tag]
  file mkdir [file join $home .xschem]
  if {$conf_lines ne {}} { spit [file join $home .xschem startup_quiz] $conf_lines }
  set wf [file join $work witness_$tag.txt]
  file delete -force $wf
  ## its own log directory, so the child's action log is not left in the temp dir
  ## -- except with --nolog, which refuses to start beside --logdir
  set logdir [list --logdir [file join $work log_$tag]]
  if {[lsearch -exact $flags --nolog] >= 0} { set logdir {} }
  set share {}
  if {$farm ne {}} { set share [list XSCHEM_SHAREDIR=$farm] }
  catch {exec env HOME=$home QUIZ_WITNESS=$wf GUI_GATE=0 {*}$share timeout 90 $bin {*}$flags \
           {*}$logdir --script $childscript < /dev/null 2>@1} out
  set w [string trim [slurp $wf]]
  if {$w eq {}} { return [dict create launch NO-WITNESS win {} out [string range $out end-300 end]] }
  return $w
}
proc wl {w} {
  if {[catch {list [dict get $w launch] [dict get $w win]} r]} { return $w }
  return $r
}

set w [launch nogui {--nogui}]
check "L1 --nogui and no -q: the hook is never reached, and the bank never read" \
  [list [q {dict get $w launch}] [q {dict get $w loaded}]] {HOOK-NOT-RUN 0}

if {$have_tk} {
  set w [launch plain {}]
  check "L2 a launch with nothing but a --script file is asked a question: decision and window" \
    [wl $w] {{1 show} 1}
  check_true "L3 ... the question on display is one of the bank's" \
    [expr {[lsearch -exact $::startup_quiz::order [q {dict get $w cur}]] >= 0}]
  check "L4 ... and the window holds no grab: the editor underneath stays usable" [q {dict get $w grab}] {}
  check "L5 --pipe is a script driving: not asked"     [wl [launch pipe {--pipe}]]         {{0 automation} 0}
  check "L6 --norecent is an option a person passes: asked" [wl [launch norecent {--norecent}]] {{1 show} 1}
  check "L7 --nolog (no CIW either): not asked"        [wl [launch nolog {--nolog}]]       {{0 nolog} 0}
  check "L8 a saved 'Don't show anymore': not asked" \
    [wl [launch saved_off {} "set startup_quiz 0\n"]] {{0 off} 0}
  check "L9 a saved ON over nothing: asked" \
    [wl [launch saved_on {} "set startup_quiz 1\n"]] {{1 show} 1}
  check "L10 --command {set startup_quiz 0} decides for that launch, over a saved ON" \
    [wl [launch cmd_off [list --command {set startup_quiz 0}] "set startup_quiz 1\n"]] {{0 off} 0}
  check "L11 --preinit {set startup_quiz 0} with nothing saved: not asked (the default does not overwrite it)" \
    [wl [launch pre_off [list --preinit {set startup_quiz 0}]]] {{0 off} 0}
  check "L12 ... but a choice saved from the program wins over it" \
    [wl [launch pre_off_saved_on [list --preinit {set startup_quiz 0}] "set startup_quiz 1\n"]] {{1 show} 1}
  set w [launch quit {-q}]
  check "L13 -q: the session ends before the hook, nothing is asked" \
    [list [q {dict get $w when}] [q {dict get $w launch}] [q {dict get $w win}]] {exit HOOK-NOT-RUN 0}
  check "L14 none of those launches wrote an answered list (nobody answered)" \
    [llength [glob -nocomplain -directory $work -join home_* .xschem startup_quiz_done]] 0
} else {
  puts "SKIPPED: L2-L14 real launches on a display (no Tk on this arm)"
  flush stdout
}

# =====================================================================
# M* -- a session whose share dir has no engine, or a broken one
# =====================================================================
# An installed copy built from a src/Makefile that ./configure did not write
# again after src/Makefile.in gained the two files has neither (issues 0423 and
# 0424). The `source` of the engine is caught, and the session must then be one
# without the quiz: it says so once, in a line of its own that is NOT a notice
# channel announcement (a missing tip file is not a fault of that channel, and
# must not spend its one-shot latches, issue 0664), so a real channel fault later
# in the same session is still announced; and the command palette, which lists
# every command row of src/actions.csv, offers no row naming an engine proc.
# Each launch is a CHILD on a share farm (tests/headless/sharefarm.tcl) with -q,
# so it leaves before the launch hook; a farm with the file is the control.
source [file join $here sharefarm.tcl]
set farm_gone  [share_farm $root [file join $work farm_gone]]
file delete [file join $farm_gone startup_quiz.tcl]
set farm_whole [share_farm $root [file join $work farm_whole]]
set mprobe {
  set r [dict create]
  dict set r procs [llength [info commands ::startup_quiz::*]]
  dict set r ns [namespace exists ::startup_quiz]
  dict set r latches [list [set ::xschem::notify_fault] [set ::xschem::notify_degraded]]
  set n 0
  set ids {}
  set eng {}
  foreach row $::action_table {
    lappend ids [dict get $row id]
    if {[string match {startup_quiz::*} [dict get $row command]]} { incr n ; lappend eng [dict get $row id] }
  }
  dict set r rows $n
  dict set r ids $ids
  dict set r engine_ids $eng
  set pal {}
  set palids {}
  if {[llength [info commands winfo]] && [llength [info commands command_palette]]} {
    command_palette .
    foreach query {{} tip} {
      set ::palette_query $query
      unset -nocomplain ::palette_last_query
      palette_refilter
      set n 0
      foreach row $::palette_rows {
        if {[string match {startup_quiz::*} [dict get $row command]]} { incr n }
        if {$query eq {}} { lappend palids [dict get $row id] }
      }
      lappend pal $n
    }
    destroy .cmd_palette
  }
  dict set r palette $pal
  dict set r palids $palids
  ## the menus a person sees: how many entries File has, and Help's {label command}
  set fileend {}
  set help {}
  if {[llength [info commands winfo]]} {
    if {[winfo exists .menubar.file]} { set fileend [.menubar.file index end] }
    if {[winfo exists .menubar.help] && [.menubar.help index end] ne {none}} {
      for {set i 0} {$i <= [.menubar.help index end]} {incr i} {
        if {[.menubar.help type $i] in {separator tearoff}} continue
        set c {}
        catch {set c [.menubar.help entrycget $i -command]}
        lappend help [list [.menubar.help entrycget $i -label] $c]
      }
    }
  }
  dict set r fileend $fileend
  dict set r help $help
  dict set r later [xschem::notify_degraded_once {M-probe: a later channel fault}]
  puts "MWITNESS $r"
  flush stdout
}
proc mlaunch {tag farm flags} {
  global work bin mprobe
  set d [file join $work m_$tag]
  file mkdir $d
  set sf [file join $d probe.tcl]
  spit $sf $mprobe
  set rc [catch {exec env XSCHEM_SHAREDIR=$farm GUI_GATE=0 timeout 90 $bin {*}$flags \
                   --logdir $d --script $sf < /dev/null 2>@1} out]
  set st [share_farm_status $rc $::errorCode]
  set w {}
  regexp -line {^MWITNESS (.*)$} $out -> w
  set log [split [slurp [file join $d Xschem.log]] "\n"]
  return [dict create status $st out [split $out "\n"] log $log w $w]
}
proc mw {r key} {
  if {[catch {dict get [dict get $r w] $key} v]} { return "NO-WITNESS([string range [join [dict get $r out] { | }] end-300 end])" }
  return $v
}
# the lines that name the failed source, and those of them that say NOTICE CHANNEL
proc mnamed {lines} { share_farm_count $lines {startup_quiz.tcl failed to source} }
proc mchannel {lines} {
  set n 0
  foreach l $lines {
    if {[string first {startup_quiz.tcl} $l] >= 0 && [string first {NOTICE CHANNEL} $l] >= 0} { incr n }
  }
  return $n
}
check "M1 the fixture: one farm lacks the engine, the control has it" \
  [list [file exists [file join $farm_gone startup_quiz.tcl]] [file exists [file join $farm_whole startup_quiz.tcl]]] {0 1}
set mg [mlaunch gone $farm_gone {--nogui --pipe -q}]
set mc [mlaunch whole $farm_whole {--nogui --pipe -q}]
check "M2 without the engine the session exits 0 with no startup_quiz:: proc; the control exits 0 with them" \
  [list [dict get $mg status] [mw $mg procs] [dict get $mc status] \
        [expr {[string is integer -strict [mw $mc procs]] && [mw $mc procs] > 0}]] {0 0 0 1}
check "M3 ... it says so once on its output and once in its action log; the control says nothing" \
  [list [mnamed [dict get $mg out]] [mnamed [dict get $mg log]] [mnamed [dict get $mc out]] [mnamed [dict get $mc log]]] {1 1 0 0}
check "M4 ... in a line that is not a notice channel announcement" \
  [list [mchannel [dict get $mg out]] [mchannel [dict get $mg log]]] {0 0}
check "M5 ... so neither of that channel's one-shot latches is spent (fault, degraded)" \
  [list [mw $mg latches] [mw $mc latches]] {{0 0} {0 0}}
check "M6 ... and a real channel fault later in that session is still announced, as in the control" \
  [list [mw $mg later] [share_farm_count [dict get $mg out] {NOTICE CHANNEL FAULT: M-probe}] [mw $mc later]] {1 1 1}
check "M7 ... the action table keeps no row that names an engine proc; the control keeps both" \
  [list [mw $mg rows] [mw $mc rows]] {0 2}

# M7 counts only the rows that must go. A filter that also drops rows that must
# stay (an emptied table, a filter on the Help menu) passes it, so M9 compares the
# whole table with the control's: the same ids in the same order, less exactly
# the ones the CONTROL says name an engine proc. M11 does the same for what a
# person sees with a display. M10 and M12 build those two wrong repairs and want
# a no from each comparison.
proc m_less {items drop} {
  set out {}
  foreach x $items { if {[lsearch -exact $drop $x] < 0} { lappend out $x } }
  return $out
}
proc m_table_ok {g c} {
  if {[catch {
    set drop [mw $c engine_ids]
    set want [m_less [mw $c ids] $drop]
    expr {[llength $drop] > 0 && [llength $want] > 0 && [mw $g ids] eq $want}
  } r]} { return "RAISED($r)" }
  return $r
}
## {palette File Help}: the palette for an empty query is the control's less the
## engine rows; File has as many entries as the control's; Help's labels are the
## control's less those whose command is an engine proc (and the control has
## some). Labels, because some Help commands name the share dir, i.e. the farm.
proc m_menus_ok {g c} {
  if {[catch {
    set pwant [m_less [mw $c palids] [mw $c engine_ids]]
    set hwant {}
    foreach e [mw $c help] { if {![string match {startup_quiz::*} [lindex $e 1]]} { lappend hwant [lindex $e 0] } }
    set hgot {}
    foreach e [mw $g help] { lappend hgot [lindex $e 0] }
    list [expr {[llength $pwant] > 0 && [mw $g palids] eq $pwant}] \
         [expr {[string is integer -strict [mw $c fileend]] && [mw $g fileend] eq [mw $c fileend]}] \
         [expr {[llength $hwant] > 0 && [llength $hwant] < [llength [mw $c help]] && $hgot eq $hwant}]
  } r]} { return "RAISED($r)" }
  return $r
}
check "M9 ... and keeps every other row: its table is the control's, less exactly the control's engine rows, in order" \
  [m_table_ok $mg $mc] 1
set mc_n $mc
## the two wrong repairs, each on a farm without the engine whose xschem.tcl is
## the real one with that one edit
set xs_real [slurp [file join $root src xschem.tcl]]
set M_wrong [list \
  emptied  [list "  set action_table \$startup_quiz_keep\n" "  set action_table {}\n"] \
  helpmenu [list {if {[string match {startup_quiz::*} [dict get $row command]]} continue} \
                 {if {[dict get $row menu] eq {help}} continue}]]
proc m_wrong_farm {tag map} {
  global root work xs_real
  set xs [string map $map $xs_real]
  set f [share_farm $root [file join $work farm_$tag] [list xschem.tcl $xs]]
  file delete [file join $f startup_quiz.tcl]
  return [list [expr {$xs ne $xs_real}] $f]
}
set got {}
foreach {tag map} $M_wrong {
  lassign [m_wrong_farm $tag $map] differs f
  set w [mlaunch wrong_$tag $f {--nogui --pipe -q}]
  lappend got $tag [list $differs [dict get $w status] [m_table_ok $w $mc_n]]
}
check "M10 ... and M9 says no to each wrong repair (the edit applies, the session still exits 0, the comparison fails)" \
  $got {emptied {1 0 0} helpmenu {1 0 0}}
if {$have_tk} {
  set mg [mlaunch gone_x $farm_gone {--pipe -q}]
  set mc [mlaunch whole_x $farm_whole {--pipe -q}]
  set mc_x $mc
  check "M8 with a display, the live palette lists no engine row for an empty query or for 'tip'; the control lists both" \
    [list [mw $mg palette] [mw $mc palette]] {{0 0} {2 2}}
  check "M11 ... and the rest is the control's: the palette less the engine rows, as many File entries, Help less the quiz entries" \
    [m_menus_ok $mg $mc] {1 1 1}
  set got {}
  foreach {tag map} $M_wrong {
    lassign [m_wrong_farm $tag $map] differs f
    set w [mlaunch wrong_x_$tag $f {--pipe -q}]
    lappend got $tag [list $differs [dict get $w status] [expr {[m_menus_ok $w $mc] eq {1 1 1}}]]
  }
  check "M12 ... and M11 says no to each wrong repair with a display too" \
    $got {emptied {1 0 0} helpmenu {1 0 0}}
} else {
  puts "SKIPPED: M8, M11, M12 the live command palette and menus (no Tk on this arm)"
  flush stdout
}

# An engine that FAILS PARTWAY: an installed copy cut short, or a slip in an
# edit. Tcl's `source` runs a file one command at a time, so every proc above the
# failing command is already defined when the error is raised. The session must
# still be one without the quiz: no proc left behind for a guard to find (the
# Help entries test one proc, load_conf's call another, Tcl_AppInit's launch hook
# a third), and so no window whose buttons call procs that were never defined.
set sq_real [slurp [file join $root src startup_quiz.tcl]]
set M_slip_at "proc startup_quiz::answer \{pos\} \{"
set sq_part [string map [list "$M_slip_at\n" "$M_slip_at \{\n"] $sq_real]
set farm_part [share_farm $root [file join $work farm_part] [list startup_quiz.tcl $sq_part]]
set mi [interp create]
$mi eval [list set XSCHEM_SHAREDIR $farm_part]
set mi_rc [catch {$mi eval [list source [file join $farm_part startup_quiz.tcl]]} mi_err]
set mi_left [$mi eval {list [llength [info commands ::startup_quiz::at_launch]] \
                            [llength [info commands ::startup_quiz::show]] \
                            [llength [info commands ::startup_quiz::answer]] [namespace exists ::startup_quiz]}]
interp delete $mi
check "M13 the fixture: a farm whose engine has one extra brace at startup_quiz::answer; sourced alone it raises and leaves at_launch and show defined, answer not, the namespace there" \
  [list [expr {[string length $sq_part] == [string length $sq_real] + 2}] $mi_rc \
        [string match {*missing close-brace*} $mi_err] $mi_left] {1 1 1 {1 1 0 1}}
## What M14, M18 and M19 ask of a session, as procs, so that M20 can put the same
## questions to a session built on a wrong repair.
proc m_part_said {r} {
  list [dict get $r status] [mw $r procs] [mw $r ns] [mnamed [dict get $r out]] [mnamed [dict get $r log]]
}
proc m_quiet {r} {
  list [mchannel [dict get $r out]] [mchannel [dict get $r log]] [mw $r latches]
}
proc m_later {r} {
  list [mw $r later] [share_farm_count [dict get $r out] {NOTICE CHANNEL FAULT: M-probe}]
}
set mp [mlaunch part $farm_part {--nogui --pipe -q}]
set mp_n $mp
check "M14 that session exits 0 with no startup_quiz:: proc and no namespace left, and says so once on its output and once in its action log" \
  [m_part_said $mp] {0 0 0 1 1}
check "M15 ... and its table is the control's less exactly the engine rows" [m_table_ok $mp $mc_n] 1
if {$have_tk} {
  set mp [mlaunch part_x $farm_part {--pipe -q}]
  check "M16 with a display, it offers no tip entry: palette, File and Help are the control's less the engine's entries" \
    [m_menus_ok $mp $mc_x] {1 1 1}
  set w [launch part_plain {} {} $farm_part]
  check "M17 ... and a plain launch (nothing but a --script file, asked in L2) is not asked: no engine, no decision, no window" \
    [list [q {dict get $w when}] [q {dict get $w launch}] [q {dict get $w win}]] {no-engine HOOK-NOT-RUN 0}
} else {
  puts "SKIPPED: M16, M17 the half-sourced engine's menus and launch (no Tk on this arm)"
  flush stdout
}
# A broken tip file is no more a fault of the notice channel than a missing one,
# so the partway session must leave that channel's one-shot latches unspent too.
# M5 and M6 ask that of the missing-engine session only, and M14 counts the
# announcement by its text, which a notice channel FAULT line also carries. So
# a repair that announces a partway file through xschem::notify_degraded_once
# (a broken install looks like a fault) and a missing one as before passes M5,
# M6 and M14. M18 and M19 ask the partway session; M20 builds that repair and
# wants a no from each, and shows that M14, and M5 on a farm without the
# engine, stay green on it.
check "M18 ... in a line that is not a notice channel announcement, so neither of that channel's one-shot latches is spent (fault, degraded)" \
  [m_quiet $mp_n] {0 0 {0 0}}
check "M19 ... and a real channel fault later in that session is still announced" \
  [m_later $mp_n] {1 1}
set M_latch_old "  catch {puts stderr \"xschem: \$startup_quiz_l\" ; flush stderr}
  catch {xschem::notify_log \$startup_quiz_l error}
"
set M_latch_new "  if {!\[string match {couldn't read file*} \$startup_quiz_source_err\]} {
    xschem::notify_degraded_once \$startup_quiz_l
  } else {
    catch {puts stderr \"xschem: \$startup_quiz_l\" ; flush stderr}
    catch {xschem::notify_log \$startup_quiz_l error}
  }
"
set xs_latch [string map [list $M_latch_old $M_latch_new] $xs_real]
set f [share_farm $root [file join $work farm_latch_part] \
         [list xschem.tcl $xs_latch startup_quiz.tcl $sq_part]]
set wp [mlaunch latch_part $f {--nogui --pipe -q}]
lassign [m_wrong_farm latch_gone [list $M_latch_old $M_latch_new]] differs_g f
set wg [mlaunch latch_gone $f {--nogui --pipe -q}]
check "M20 ... and M18 and M19 say no to a repair that spends the FAULT latch for a partway file only (the edit applies, the session exits 0, M14 stays green; without the engine M5's pair stays {0 0})" \
  [list [expr {$xs_latch ne $xs_real}] $differs_g [dict get $wp status] \
        [expr {[m_part_said $wp] eq {0 0 0 1 1}}] \
        [expr {[m_quiet $wp] eq {0 0 {0 0}}}] [expr {[m_later $wp] eq {1 1}}] \
        [dict get $wg status] [mw $wg latches]] {1 1 0 1 0 0 0 {0 0}}

# =====================================================================
# D* -- the dialog, through its widgets
# =====================================================================
if {$have_tk} {
  set W .startup_quiz
  proc pump {ms} {
    set ::pump_done 0
    after $ms {set ::pump_done 1}
    vwait ::pump_done
  }
  proc opts {} {
    set out {}
    foreach c [lsort -dictionary [winfo children .startup_quiz.opts]] { lappend out [$c cget -text] }
    return $out
  }
  # how many options are locked, and how many there are (an unlocked one reads
  # normal, or active while the pointer happens to rest on it)
  proc locked {} {
    set n 0; set all 0
    foreach c [winfo children .startup_quiz.opts] {
      incr all
      if {[$c cget -state] eq {disabled}} { incr n }
    }
    return [list $n $all]
  }
  # is a checkbutton drawn ticked? (Tk ticks it when its variable holds its -onvalue)
  proc ticked {b} {
    upvar #0 [$b cget -variable] v
    expr {[info exists v] && $v eq [$b cget -onvalue] ? 1 : 0}
  }
  # press a Tk button the way a hand does: enter, press, release, leave
  proc press {b} {
    update
    set x [expr {[winfo width $b] / 2}]; set y [expr {[winfo height $b] / 2}]
    event generate $b <Enter> -x $x -y $y
    event generate $b <ButtonPress-1> -x $x -y $y
    event generate $b <ButtonRelease-1> -x $x -y $y
    ## the Close button takes its own window away with it
    if {[winfo exists $b]} { event generate $b <Leave> }
    update
  }

  startup_quiz::load_bank $synth
  fresh
  set ::cli_opt_pipe 0
  set ::startup_quiz::rng {apply {{n} {return 0}}}
  catch {destroy $W}
  check "D1 asking for question d opens the window and answers its id" \
    [list [q {startup_quiz::show d}] [winfo exists $W]] {d 1}
  update
  check "D2 the window is titled, and belongs to the main window" \
    [list [wm title $W] [wm transient $W]] {{Tip of the day} .}
  check "D3 it holds no grab" [grab current] {}
  check "D4 the topic, the kind of question and the question are the entry's" \
    [list [$W.head.topic cget -text] [$W.prompt cget -text] [$W.q cget -text]] {T {Pick one:} {Question d}}
  check "D5 the options are the entry's, lettered, in the displayed order" \
    [opts] {{A. d1} {B. d2} {C. d3} {D. d0}}
  check "D6 nothing is picked, marked or explained yet" \
    [list $::startup_quiz::choice [$W.verdict cget -text] [$W.why cget -text] [locked]] \
    {-1 {} {} {0 4}}
  check "D7 a question on display but unanswered is not on the answered list" \
    [list $::startup_quiz_done [file exists $df]] {{} 0}

  # option A is d1: wrong. Pressed with the mouse.
  press $W.opts.o0
  check "D8 pressing a wrong option: the verdict line says so" [$W.verdict cget -text] {Not quite.}
  check "D9 ... the explanation appears" [$W.why cget -text] {Why d}
  check "D10 ... the right option and the pressed one are labelled, the others untouched" \
    [opts] {{A. d1   (your answer)} {B. d2   (correct)} {C. d3} {D. d0}}
  check "D11 ... every option is locked" [locked] {4 4}
  check "D12 ... the verdict is in the 'wrong' tone and the right option in the 'right' tone" \
    [list [$W.verdict cget -foreground] [$W.opts.o1 cget -disabledforeground] [$W.opts.o0 cget -disabledforeground]] \
    [list [startup_quiz::tone_of $W bad] [startup_quiz::tone_of $W good] [startup_quiz::tone_of $W bad]]
  check "D13 ... the answer is on record" $::startup_quiz::last {id d pick 1 correct 0 head {Not quite.}}
  check "D14 ... and the question is now on the answered list, in memory and on disk" \
    [list $::startup_quiz_done [regexp -line {^set startup_quiz_done d$} [slurp $df]]] {d 1}
  check "D15 a second answer to the same question is ignored" \
    [list [q {startup_quiz::answer 1}] [$W.verdict cget -text]] {{} {Not quite.}}

  set wid [winfo id $W]
  check "D16 'Next question' puts up a different one, in the same window" \
    [list [q {press $W.foot.next ; set ::startup_quiz::cur}] [expr {[winfo id $W] == $wid}]] {a 1}
  check "D17 ... unanswered again" [list [$W.verdict cget -text] [locked] [opts]] \
    {{} {0 2} {True False}}
  $W.opts.o0 invoke
  check "D18 True on a shipped feature: nailed it, and the option says correct" \
    [list [$W.verdict cget -text] [opts] [$W.verdict cget -foreground]] \
    [list {You nailed it!} {{True   (correct)} False} [startup_quiz::tone_of $W good]]
  startup_quiz::show b
  $W.opts.o1 invoke
  check "D19 False on an upcoming feature: the upcoming-feature sentence" \
    [$W.verdict cget -text] {You nailed it. This is an upcoming feature! Stay tuned!}
  startup_quiz::show b
  $W.opts.o0 invoke
  check "D20 True on an upcoming feature: told it is still to come" \
    [list [$W.verdict cget -text] [opts]] \
    {{Not yet! This is an upcoming feature. Stay tuned!} {{True   (your answer)} {False   (correct)}}}

  # the box
  set ::startup_quiz 1
  startup_quiz::show c
  update
  check "D21 the box reads 'Don't show anymore' and is drawn unticked while the switch is on" \
    [list [$W.foot.dont cget -text] [$W.foot.dont cget -variable] $::startup_quiz [ticked $W.foot.dont]] \
    {{Don't show anymore} ::startup_quiz 1 0}
  press $W.foot.dont
  check "D22 pressing it ticks it, turns the switch off and saves that at once" \
    [list [ticked $W.foot.dont] $::startup_quiz [regexp -line {^set startup_quiz 0$} [slurp $pf]]] {1 0 1}
  press $W.foot.dont
  check "D23 pressing it again unticks it, turns the switch back on and saves that" \
    [list [ticked $W.foot.dont] $::startup_quiz [regexp -line {^set startup_quiz 1$} [slurp $pf]]] {0 1 1}
  set ::startup_quiz 0
  startup_quiz::show c
  update
  check "D24 opened while the switch is off, the question still comes up (asked for by hand), the box is drawn ticked and the switch stays off" \
    [list [winfo exists $W] [ticked $W.foot.dont] $::startup_quiz] {1 1 0}

  # the Help menu
  set hm .menubar.help
  set ix_show {}; set ix_chk {}
  set lastix -1
  catch {set lastix [$hm index end]}
  if {[string is integer -strict $lastix]} {
    for {set i 0} {$i <= $lastix} {incr i} {
      if {[catch {$hm entrycget $i -label} lbl]} continue
      if {$lbl eq {Tip of the day (quiz)...}} { set ix_show $i }
      if {$lbl eq {Tip of the day at startup}} { set ix_chk $i }
    }
  }
  check_true "D25 the live Help menu carries both entries" [expr {$ix_show ne {} && $ix_chk ne {}}]
  check "D26 the checkbutton entry is on the switch itself, ticked when the switch is on" \
    [list [q {$hm entrycget $ix_chk -variable}] [q {$hm entrycget $ix_chk -onvalue}] [q {$hm entrycget $ix_chk -offvalue}]] \
    {startup_quiz 1 0}
  set ::startup_quiz 0
  q {$hm invoke $ix_chk}
  check "D27 picking it turns the switch on and saves that" \
    [list $::startup_quiz [regexp -line {^set startup_quiz 1$} [slurp $pf]]] {1 1}
  catch {destroy $W}
  q {$hm invoke $ix_show}
  update
  check "D28 picking 'Tip of the day (quiz)...' opens the window with a question" \
    [list [winfo exists $W] [expr {$::startup_quiz::cur ne {}}]] {1 1}

  # the palette
  set ::startup_quiz 1
  command_palette .
  set ::palette_query {toggle tip}
  unset -nocomplain ::palette_last_query
  palette_refilter
  set ids {}
  foreach r $::palette_rows { lappend ids [dict get $r id] }
  check "D29 the live palette, asked for 'toggle tip', puts the toggle first" [lindex $ids 0] $ID_TOGGLE
  palette_run
  update
  check "D30 running that row turns the switch off, saves it, and closes the palette" \
    [list $::startup_quiz [regexp -line {^set startup_quiz 0$} [slurp $pf]] [winfo exists .cmd_palette]] {0 1 0}
  set ::startup_quiz 1

  # closing
  startup_quiz::show a
  update
  press $W.foot.close
  check "D31 the Close button closes it" [winfo exists $W] 0
  startup_quiz::show a
  update
  uplevel #0 [wm protocol $W WM_DELETE_WINDOW]
  update
  check "D32 so does the title bar's close" [winfo exists $W] 0
  startup_quiz::show a
  update
  set esc [bind $W <Escape>]
  catch {uplevel #0 $esc}
  update
  check "D33 so does the script bound to Escape on the window" [list [expr {$esc ne {}}] [winfo exists $W]] {1 0}
  check "D33b the dialog's hint line is on screen as written" \
    [q {startup_quiz::show a ; .startup_quiz.hint cget -text}] [q {startup_quiz::hint_text}]
  catch {destroy $W}
  check "D34 closing changed neither the switch nor the answered list" \
    [list $::startup_quiz $::startup_quiz_done] {1 {d a b}}

  # the launch path: waits for a grab to go, then asks; never asks twice
  fresh
  set ::startup_quiz::launch_retry 50
  toplevel .quizgrab
  update
  grab set .quizgrab
  startup_quiz::launch_show 0
  pump 200
  check "D35 while another dialog holds a grab the launch question waits" [winfo exists $W] 0
  grab release .quizgrab
  destroy .quizgrab
  pump 300
  check "D36 ... and comes up once the grab is gone" [winfo exists $W] 1
  set was $::startup_quiz::cur
  startup_quiz::launch_show 0
  update
  check "D37 a second launch call does not replace the question already on display" $::startup_quiz::cur $was
  catch {destroy $W}

  # a question with a condition that does not hold here
  startup_quiz::load_bank $cond
  fresh
  set ::quiz_flag 0
  check "D37b asked for by id, a question is shown even where its condition does not hold" \
    [list [q {startup_quiz::show no}] [$W.q cget -text]] {no Qn}
  catch {destroy $W}
  startup_quiz::load_bank $none
  set keep_nolog $::cli_opt_nolog
  set ::cli_opt_nolog 0
  check "D37c with a display, a person and the switch on, but no question that applies: not asked" \
    [q {startup_quiz::launch_decision}] {0 no-questions}
  startup_quiz::load_bank $cond
  check "D37d ... and with one that applies: asked" [q {startup_quiz::launch_decision}] {1 show}
  set ::cli_opt_nolog $keep_nolog

  # tones
  check "D38 on a light background the three tones are dark" \
    [list [startup_quiz::tone {55769 55769 55769} good] [startup_quiz::tone {55769 55769 55769} bad] \
          [startup_quiz::tone {55769 55769 55769} dim]] [list {#116329} {#a40e26} {#555555}]
  check "D39 on a dark background they are light" \
    [list [startup_quiz::tone {8000 8000 8000} good] [startup_quiz::tone {8000 8000 8000} bad] \
          [startup_quiz::tone {8000 8000 8000} dim]] [list {#7ee787} {#ff9492} {#b0b0b0}]
  check "D40 the bold face is a private named font; no Tk*Font was touched" \
    [list [expr {[lsearch -exact [font names] startup_quiz_bold] >= 0}] [font configure TkDefaultFont -weight]] \
    {1 normal}

  # the whole shipped bank, displayed and answered: every question fits
  startup_quiz::load_bank $bankfile
  fresh
  set ::cli_opt_pipe 1
  set tall {}; set wide {}; set n 0; set wrongmark {}
  set maxh [expr {int([winfo screenheight .] * 0.7)}]
  foreach id $::startup_quiz::order {
    startup_quiz::show $id
    set right [lsearch -exact $::startup_quiz::perm [dict get [startup_quiz::get $id] ok]]
    startup_quiz::answer $right
    update idletasks
    if {[winfo reqheight $W] > $maxh} { lappend tall "$id=[winfo reqheight $W]" }
    if {[winfo reqwidth $W] > 760} { lappend wide "$id=[winfo reqwidth $W]" }
    if {![string match {*(correct)} [$W.opts.o$right cget -text]] || ![dict get $::startup_quiz::last correct]} {
      lappend wrongmark $id
    }
    incr n
  }
  check "D41 every question of the shipped bank was displayed and answered ($n)" $n $nq
  check "D42 ... answering with the entry's own 'ok' is marked correct, for every one" $wrongmark {}
  check "D43 ... and none makes the window taller than 70% of the screen or wider than 760 px" \
    [list $tall $wide] {{} {}}
  catch {destroy $W}
} else {
  puts "SKIPPED: D1-D43 the dialog (no Tk on this arm)"
  flush stdout
}

if {$keep_pipe ne {}} { set ::cli_opt_pipe $keep_pipe }

# --- verdict ---
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail != 0}]
