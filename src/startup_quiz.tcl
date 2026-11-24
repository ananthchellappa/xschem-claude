#
#  File: startup_quiz.tcl
#
#  This file is part of XSCHEM.
#
#  Tip of the day, asked as a quiz (doc/claude/specs/startup_quiz.md).
#
#  One question about what this XSCHEM can do, shown once per launch of an
#  interactive session, and on demand from the Help menu and the command palette.
#  The questions live in startup_quiz_bank.tcl (same share dir), which is read
#  the first time a question is needed and never at startup.
#
#  PROC DEFINITIONS ONLY AT SOURCE TIME. xschem.tcl sources this file in every
#  session, --nogui included, so nothing here may run a Tk command while the file
#  is being read; every Tk command sits behind startup_quiz::have_tk.
#
#  TWO LAYERS. The decision layer (add, load_bank, pick, order_options, grade,
#  decide, the two writers) has no Tk in it and runs under --nogui. The act layer
#  (show, display, answer, next_question, dismiss) needs a display.
#
#  This file is GPL like the rest of XSCHEM (see xschem.tcl header).

namespace eval startup_quiz {
  ## id -> entry, and the ids in bank-file order
  variable bank [dict create]
  variable order {}
  ## 1 once the bank file has been read, whether or not it read cleanly
  variable loaded 0
  ## one line per entry (or file) that could not be used; empty on a healthy bank
  variable bank_errors {}
  ## the question on display, the option order it is displayed in (a list of
  ## indices into the entry's own option list), and whether it has been answered
  variable cur {}
  variable perm {}
  variable answered 0
  ## the radiobuttons' variable: the DISPLAYED position picked, -1 for none
  variable choice -1
  ## the ids displayed since this process started (answered or not)
  variable shown {}
  ## this launch's decision, {show reason}; empty until the launch hook has run
  variable launch {}
  ## the last answer given, {id pick correct head}; empty until there is one
  variable last {}
  ## a command prefix called with n and returning an integer in 0..n-1; empty
  ## means Tcl's rand(). A test sets it to make the pick and the shuffle repeatable.
  variable rng {}
  ## wait before the launch question appears, and how long to keep waiting for
  ## the main window to be on screen: ms, ms per retry, retries
  variable launch_delay 400
  variable launch_retry 200
  variable launch_tries 25
  ## the families the window's text may be set in, best first: the first one this
  ## display has is used, and the family the labels have anyway when it has none
  variable font_prefs {
    {SF Pro Text} {SF Pro Display} Inter {Helvetica Neue} {Segoe UI} Roboto
    {Noto Sans} {Open Sans} {Source Sans 3} {Source Sans Pro} Lato {Ubuntu Sans}
    Ubuntu Cantarell {Liberation Sans} {Nimbus Sans} Helvetica Arial
  }
  ## the family in use; empty until a window has been built
  variable font_family {}
  ## 1 once the open window has been given its place on the screen
  variable placed 0
  ## pixels kept free between the window and the screen's edges when it grows
  variable screen_margin 48
}

# ---------------------------------------------------------------------------
# the bank
# ---------------------------------------------------------------------------

# Collapse every run of white space to one blank, so a bank entry can be wrapped
# over several lines in the file and still be one paragraph on screen.
proc startup_quiz::flat {s} {
  regsub -all {\s+} [string trim $s] { } s
  return $s
}

# Check one entry and return it in the stored shape, or raise naming what is
# wrong. The stored shape is the same for both question types: `a` is the option
# list and `ok` the index of the right one; a true/false question is stored as
# the options True and False. Every entry carries a `proof`: no claim goes in
# front of a user without something that re-checks it (see the bank's header).
proc startup_quiz::validate {id spec} {
  if {![regexp {^[a-z0-9][a-z0-9_-]*$} $id]} {
    error "the id may hold only a-z, 0-9, '-' and '_'"
  }
  if {[catch {dict size $spec}]} { error "the body is not a list of key/value pairs" }
  set known {type kind topic q a ok why proof last only}
  dict for {k v} $spec {
    if {[lsearch -exact $known $k] < 0} { error "unknown key '$k'" }
  }
  foreach k {type kind topic q ok why proof} {
    if {![dict exists $spec $k]} { error "missing key '$k'" }
  }
  set type [dict get $spec type]
  set kind [dict get $spec kind]
  set e [dict create type $type kind $kind last {}]
  foreach k {topic q why} {
    set v [flat [dict get $spec $k]]
    if {$v eq {}} { error "'$k' is empty" }
    dict set e $k $v
  }
  set ok [dict get $spec ok]
  if {$type eq {tf}} {
    if {[dict exists $spec a]}    { error "a true/false question takes no 'a'" }
    if {[dict exists $spec last]} { error "a true/false question takes no 'last'" }
    if {[lsearch -exact {shipped upcoming myth} $kind] < 0} {
      error "kind '$kind' does not go with a true/false question"
    }
    if {[lsearch -exact {true false} $ok] < 0} { error "'ok' must be true or false" }
    if {($kind eq {shipped}) != ($ok eq {true})} {
      error "kind '$kind' and ok '$ok' contradict each other"
    }
    dict set e a {True False}
    dict set e ok [expr {$ok eq {true} ? 0 : 1}]
  } elseif {$type eq {mc}} {
    if {![dict exists $spec a]} { error "missing key 'a'" }
    if {[lsearch -exact {howto upcoming} $kind] < 0} {
      error "kind '$kind' does not go with a multiple-choice question"
    }
    if {[catch {llength [dict get $spec a]} n]} { error "'a' is not a list" }
    if {$n < 3 || $n > 5} { error "'a' must hold 3 to 5 options, not $n" }
    set opts {}
    foreach o [dict get $spec a] {
      set o [flat $o]
      if {$o eq {}} { error "an option is empty" }
      if {[lsearch -exact $opts $o] >= 0} { error "the option '$o' is listed twice" }
      lappend opts $o
    }
    if {![string is integer -strict $ok] || $ok < 0 || $ok >= $n} {
      error "'ok' must be the index of an option, 0 to [expr {$n - 1}]"
    }
    dict set e a $opts
    dict set e ok $ok
    if {[dict exists $spec last]} {
      set l [dict get $spec last]
      if {![string is integer -strict $l] || $l < 0 || $l >= $n} {
        error "'last' must be the index of an option, 0 to [expr {$n - 1}]"
      }
      dict set e last $l
    }
  } else {
    error "type '$type' is neither tf nor mc"
  }
  ## the claim's own check, an expression that is true while the question is still
  ## right. Kept as written and never evaluated here: the suite evaluates it.
  set proof [string trim [dict get $spec proof]]
  if {$proof eq {}} { error "'proof' is empty" }
  dict set e proof $proof
  ## an optional condition on the SESSION: the question is asked only where the
  ## expression is true (a key that exists only in the Cadence profile, a symbol
  ## that exists only in a PDK workarea). Evaluated by startup_quiz::eligible.
  set only {}
  if {[dict exists $spec only]} { set only [string trim [dict get $spec only]] }
  dict set e only $only
  return $e
}

# The bank file's one command. An entry that does not validate is left out and
# named in bank_errors: one bad entry must not cost the user every other question.
proc startup_quiz::add {id spec} {
  variable bank
  variable order
  variable bank_errors
  if {[dict exists $bank $id]} {
    lappend bank_errors "$id: this id is used twice"
    return 0
  }
  if {[catch {validate $id $spec} e]} {
    lappend bank_errors "$id: $e"
    return 0
  }
  dict set bank $id $e
  lappend order $id
  return 1
}

proc startup_quiz::bank_path {} {
  return [file join $::XSCHEM_SHAREDIR startup_quiz_bank.tcl]
}

# Read the bank and return how many questions it holds. With no argument the
# shipped file is read once per process; with a path that file replaces whatever
# was loaded. Never raises: a file that is missing, unreadable or broken part
# way down leaves the questions read so far and one line in bank_errors.
proc startup_quiz::load_bank {{path {}}} {
  variable bank
  variable order
  variable loaded
  variable bank_errors
  if {$path eq {}} {
    if {$loaded} { return [llength $order] }
    set path [bank_path]
  }
  set bank [dict create]
  set order {}
  set bank_errors {}
  set loaded 1
  if {![file readable $path]} {
    lappend bank_errors "$path: cannot be read"
    return 0
  }
  if {[catch {uplevel #0 [list source $path]} err]} {
    lappend bank_errors "$path: $err"
  }
  return [llength $order]
}

proc startup_quiz::has {id} {
  variable bank
  return [dict exists $bank $id]
}

proc startup_quiz::get {id} {
  variable bank
  return [dict get $bank $id]
}

# ---------------------------------------------------------------------------
# choosing a question and laying out its options
# ---------------------------------------------------------------------------

# An integer in 0..n-1.
proc startup_quiz::randint {n} {
  variable rng
  if {$n <= 1} { return 0 }
  if {$rng ne {}} {
    set r [uplevel #0 [linsert $rng end $n]]
  } else {
    set r [expr {int(rand() * $n)}]
  }
  if {![string is integer -strict $r] || $r < 0 || $r >= $n} { return 0 }
  return $r
}

# Does question $id apply to this session? One with no `only` always does; one
# whose `only` raises or is not a boolean does not.
proc startup_quiz::eligible {id} {
  set only [dict get [get $id] only]
  if {$only eq {}} { return 1 }
  if {[catch {uplevel #0 [list expr $only]} r]} { return 0 }
  if {![string is boolean -strict $r]} { return 0 }
  return [expr {$r ? 1 : 0}]
}

# The questions that apply to this session, in bank order.
proc startup_quiz::eligible_ids {} {
  variable order
  set out {}
  foreach id $order { if {[eligible $id]} { lappend out $id } }
  return $out
}

# The answered ids that are still in the bank, in the order they were answered.
proc startup_quiz::done_ids {} {
  variable bank
  set out {}
  if {![info exists ::startup_quiz_done]} { return $out }
  if {[catch {llength $::startup_quiz_done}]} { return $out }
  foreach id $::startup_quiz_done {
    if {[dict exists $bank $id] && [lsearch -exact $out $id] < 0} { lappend out $id }
  }
  return $out
}

# The next question's id, or {} when no question applies to this session.
# Preference, in order: one neither answered (in any session) nor displayed in
# this one; one not answered; then, when every question has been answered, the
# round starts again. The question on display ($avoid) is never handed straight
# back while another exists.
proc startup_quiz::pick {{avoid {}}} {
  variable shown
  set ids [eligible_ids]
  if {![llength $ids]} { return {} }
  set done [done_ids]
  set pool {}
  foreach id $ids {
    if {[lsearch -exact $done $id] < 0 && [lsearch -exact $shown $id] < 0} { lappend pool $id }
  }
  if {![llength $pool]} {
    foreach id $ids {
      if {[lsearch -exact $done $id] < 0 && $id ne $avoid} { lappend pool $id }
    }
  }
  if {![llength $pool]} {
    ## a new round: only the questions of THIS session start again; one answered
    ## in a session it applied to stays answered
    set keep {}
    foreach id $done { if {[lsearch -exact $ids $id] < 0} { lappend keep $id } }
    set ::startup_quiz_done $keep
    foreach id $ids { if {$id ne $avoid} { lappend pool $id } }
  }
  if {![llength $pool]} { set pool $ids }
  return [lindex $pool [randint [llength $pool]]]
}

# The order a question's options are displayed in, as indices into its option
# list. True/False keeps its order; multiple choice is shuffled, except that an
# option named by `last` (an "all of these") stays at the bottom.
proc startup_quiz::order_options {id} {
  set e [get $id]
  if {[dict get $e type] eq {tf}} { return {0 1} }
  set n [llength [dict get $e a]]
  set last [dict get $e last]
  set idx {}
  for {set i 0} {$i < $n} {incr i} {
    if {$i ne $last} { lappend idx $i }
  }
  for {set i [expr {[llength $idx] - 1}]} {$i > 0} {incr i -1} {
    set j [randint [expr {$i + 1}]]
    set t [lindex $idx $i]
    lset idx $i [lindex $idx $j]
    lset idx $j $t
  }
  if {$last ne {}} { lappend idx $last }
  return $idx
}

# The text of the option displayed at position $pos: multiple choice is lettered.
proc startup_quiz::option_text {id perm pos} {
  set e [get $id]
  set txt [lindex [dict get $e a] [lindex $perm $pos]]
  if {[dict get $e type] eq {tf}} { return $txt }
  return "[string index ABCDE $pos]. $txt"
}

proc startup_quiz::prompt {id} {
  if {[dict get [get $id] type] eq {tf}} { return {True or false?} }
  return {Pick one:}
}

# Mark an answer. $pick is an index into the entry's own option list (not the
# displayed position). Returns {correct head why ok}.
proc startup_quiz::grade {id pick} {
  set e [get $id]
  set ok [dict get $e ok]
  set type [dict get $e type]
  set kind [dict get $e kind]
  set correct [expr {$pick == $ok ? 1 : 0}]
  if {$correct && $kind eq {upcoming}} {
    set head {You nailed it. This is an upcoming feature! Stay tuned!}
  } elseif {$correct} {
    set head {You nailed it!}
  } elseif {$kind eq {upcoming} && $type eq {tf}} {
    set head {Not yet! This is an upcoming feature. Stay tuned!}
  } elseif {$kind eq {upcoming}} {
    set head {Not quite: that one already works.}
  } elseif {$type eq {tf} && $ok == 0} {
    set head {Not quite: this one is true.}
  } elseif {$type eq {tf}} {
    set head {Not quite: this one is false.}
  } else {
    set head {Not quite.}
  }
  return [dict create correct $correct head $head why [dict get $e why] ok $ok]
}

# ---------------------------------------------------------------------------
# the preference and the answered list
# ---------------------------------------------------------------------------

# Is the quiz shown at launch? Anything that is not a boolean counts as yes, the
# shipped default.
proc startup_quiz::enabled {} {
  if {![info exists ::startup_quiz]} { return 1 }
  if {![string is boolean -strict $::startup_quiz]} { return 1 }
  return [expr {$::startup_quiz ? 1 : 0}]
}

# A --pipe session: a script is driving through stdin, not a person. (C mirrors
# the option as ::cli_opt_pipe. NOT no_recent_files: --norecent sets that too,
# and --norecent is an option a person passes -- the PDK launcher offers it.)
proc startup_quiz::automation {} {
  if {![info exists ::cli_opt_pipe]} { return 0 }
  if {![string is boolean -strict $::cli_opt_pipe]} { return 0 }
  return [expr {$::cli_opt_pipe ? 1 : 0}]
}

proc startup_quiz::conf_path {name} {
  return [file join $::USER_CONF_DIR $name]
}

# Write $lines to $path. Returns 1, or 0 when the file could not be written.
proc startup_quiz::write_file {path lines} {
  if {[catch {open $path w} fd]} { return 0 }
  set bad [catch {
    foreach l $lines { puts $fd $l }
  }]
  if {[catch {close $fd}]} { set bad 1 }
  return [expr {$bad ? 0 : 1}]
}

# The explicit choice, written whenever the person changes it.
proc startup_quiz::write_pref {} {
  return [write_file [conf_path startup_quiz] [list \
    {# xschem: ask the tip-of-the-day quiz at launch (1) or not (0). Written by the quiz's} \
    {# "Don't show anymore" box, by Help > Tip of the day at startup and by the command} \
    {# palette's "Toggle tip of the day at startup".} \
    [list set startup_quiz [enabled]]]]
}

# The questions answered so far, so they are not asked again until the rest have
# had their turn. Not written in an automation session.
proc startup_quiz::write_done {} {
  if {[automation]} { return 0 }
  return [write_file [conf_path startup_quiz_done] [list \
    {# xschem: tip-of-the-day questions already answered (a harmless breadcrumb; delete} \
    {# the file to start the round again).} \
    [list set startup_quiz_done [done_ids]]]]
}

# Startup: read both files back, at global scope (issue 0925: `source` runs in
# its caller's frame, so sourced here the names would be locals of this proc).
proc startup_quiz::load_conf {} {
  foreach f {startup_quiz startup_quiz_done} {
    set p [conf_path $f]
    if {![file exists $p]} continue
    if {[catch {uplevel #0 [list source $p]} err]} {
      puts "startup_quiz::load_conf: problem sourcing $f: $err"
    }
  }
  ## the Help-menu checkbutton and the dialog's box need the switch as 0 or 1
  set ::startup_quiz [enabled]
}

# Record that $id was answered. Returns the answered list.
proc startup_quiz::mark_done {id} {
  set done [done_ids]
  if {[has $id] && [lsearch -exact $done $id] < 0} { lappend done $id }
  set ::startup_quiz_done $done
  write_done
  return $done
}

# The sentence that tells the person what the switch now says.
proc startup_quiz::pref_notice {on} {
  if {$on} { return {Tip of the day at startup: ON.} }
  return "Tip of the day at startup: OFF. Turn it back on from the command palette\
(Ctrl+Shift+P, \"Toggle tip of the day at startup\") or the Help menu."
}

# The switch has just been moved (by the dialog's box, the Help-menu
# checkbutton or set_enabled): save it and say so. Returns the new value.
proc startup_quiz::pref_changed {} {
  set on [enabled]
  set ::startup_quiz $on
  set saved [write_pref]
  set msg [pref_notice $on]
  if {!$saved} {
    append msg " (Could not save this to [conf_path startup_quiz]; it holds for this session only.)"
  }
  catch { ::xschem::notify $msg -short [expr {$on ? {Tip of the day: ON} : {Tip of the day: OFF}}] }
  return $on
}

proc startup_quiz::set_enabled {on} {
  set ::startup_quiz [expr {$on ? 1 : 0}]
  return [pref_changed]
}

# The command palette's "Toggle tip of the day at startup".
proc startup_quiz::toggle {} {
  return [set_enabled [expr {![enabled]}]]
}

# ---------------------------------------------------------------------------
# the launch decision
# ---------------------------------------------------------------------------

# PURE. $in is {tk automation nolog enabled questions}; returns {show reason}.
proc startup_quiz::decide {in} {
  if {![dict get $in tk]}            { return {0 no-display} }
  if {[dict get $in automation]}     { return {0 automation} }
  if {[dict get $in nolog]}          { return {0 nolog} }
  if {![dict get $in enabled]}       { return {0 off} }
  if {[dict get $in questions] <= 0} { return {0 no-questions} }
  return {1 show}
}

proc startup_quiz::have_tk {} {
  if {![llength [info commands winfo]]} { return 0 }
  if {[catch {winfo exists .} r]} { return 0 }
  return [expr {$r ? 1 : 0}]
}

# This session's answer. The bank is read only when everything else already
# says yes, so a session that will not ask never opens the file.
proc startup_quiz::launch_decision {} {
  set nolog 0
  if {[info exists ::cli_opt_nolog] && [string is boolean -strict $::cli_opt_nolog]} {
    set nolog [expr {$::cli_opt_nolog ? 1 : 0}]
  }
  set in [dict create tk [have_tk] automation [automation] nolog $nolog \
            enabled [enabled] questions 1]
  set d [decide $in]
  if {![lindex $d 0]} { return $d }
  load_bank
  dict set in questions [llength [eligible_ids]]
  return [decide $in]
}

# Called once by Tcl_AppInit, after the rc files, the --script file and
# --command have run, in a session that has a display and is staying open.
# Never blocks and never raises; returns the decision.
proc startup_quiz::at_launch {} {
  variable launch
  variable launch_delay
  set ::startup_quiz [enabled]
  if {[catch {launch_decision} d]} { set d [list 0 "error: $d"] }
  set launch $d
  if {[lindex $d 0]} { after $launch_delay [list startup_quiz::launch_show 0] }
  return $d
}

# Show the launch question once the main window is on screen and no dialog
# holds a grab; give up waiting after launch_tries and show it anyway.
proc startup_quiz::launch_show {n} {
  variable launch_retry
  variable launch_tries
  if {![have_tk]} return
  if {[winfo exists .startup_quiz]} return
  set busy 0
  catch { if {![winfo viewable .] || [grab current] ne {}} { set busy 1 } }
  if {$busy && $n < $launch_tries} {
    after $launch_retry [list startup_quiz::launch_show [expr {$n + 1}]]
    return
  }
  catch { show }
}

# ---------------------------------------------------------------------------
# the window
# ---------------------------------------------------------------------------

# Foreground colours that stay readable on the widget background in use: $rgb is
# the background as {r g b}, each 0..65535, $what is good, bad, dim or rule (the
# hairline above the buttons).
proc startup_quiz::tone {rgb what} {
  lassign $rgb r g b
  set lum [expr {(0.299 * $r + 0.587 * $g + 0.114 * $b) / 65535.0}]
  if {$lum >= 0.5} {
    set t {good #116329 bad #a40e26 dim #555555 rule #a6a6a6}
  } else {
    set t {good #7ee787 bad #ff9492 dim #b0b0b0 rule #5c5c5c}
  }
  return [dict get $t $what]
}

proc startup_quiz::tone_of {w what} {
  set rgb {65535 65535 65535}
  catch { set rgb [winfo rgb $w [$w cget -background]] }
  return [tone $rgb $what]
}

# The line under the buttons: where the switch can be found again.
proc startup_quiz::hint_text {} {
  return {Bring it back any time: command palette (Ctrl+Shift+P), "Toggle tip of the day at startup".}
}

# The family the window is set in: the first of font_prefs this display has,
# else the family of $fallback (the font the labels have anyway).
proc startup_quiz::family {fallback} {
  variable font_prefs
  set have [dict create]
  catch { foreach f [font families] { dict set have [string tolower $f] $f } }
  foreach want $font_prefs {
    set k [string tolower $want]
    if {[dict exists $have $k]} { return [dict get $have $k] }
  }
  return [font actual $fallback -family]
}

# The window's faces: private named fonts, never a change to a Tk*Font. Sized
# from $from, the font the labels have anyway, so a session that runs its
# interface larger or smaller gets a window in proportion. A size below zero is
# one in pixels, where larger means further from zero.
#   body   the options, the explanation, the buttons   one step up
#   bold   the title and the verdict                   body, bold
#   head   the question itself                         three steps up
#   small  the topic, the kind of question, the hint   the labels' own size
proc startup_quiz::fonts {from} {
  variable font_family
  set font_family [family $from]
  set base [font actual $from -size]
  foreach {name step weight} {body 1 normal bold 1 bold head 3 normal small 0 normal} {
    set size [expr {$base < 0 ? $base - $step : $base + $step}]
    set f startup_quiz_$name
    if {[lsearch -exact [font names] $f] < 0} { font create $f }
    font configure $f -family $font_family -size $size -weight $weight \
      -slant roman -underline 0 -overstrike 0
  }
  return $font_family
}

# Build the window if it is not there. Returns its path.
proc startup_quiz::window {} {
  variable placed
  set w .startup_quiz
  if {[winfo exists $w]} {
    catch { wm deiconify $w ; raise $w }
    return $w
  }
  set placed 0
  toplevel $w -class Dialog -padx 20 -pady 16
  wm title $w {Tip of the day}
  set parent .
  catch { set parent [winfo toplevel [xschem get topwindow]] }
  catch { wm transient $w $parent }
  wm protocol $w WM_DELETE_WINDOW startup_quiz::dismiss

  frame $w.head
  label $w.head.title -text {Tip of the day} -anchor w
  label $w.head.topic -text {} -anchor e
  pack $w.head.title -side left
  pack $w.head.topic -side right
  label $w.prompt -text {} -anchor w
  label $w.q -text {} -anchor w -justify left
  frame $w.opts
  label $w.verdict -text {} -anchor w -justify left
  label $w.why -text {} -anchor w -justify left
  frame $w.foot
  checkbutton $w.foot.dont -text {Don't show anymore} -variable ::startup_quiz \
    -onvalue 0 -offvalue 1 -command startup_quiz::pref_changed
  button $w.foot.close -text {Close} -command startup_quiz::dismiss -padx 12
  button $w.foot.next -text {Next question} -command startup_quiz::next_question -padx 12
  pack $w.foot.dont -side left
  pack $w.foot.close -side right
  pack $w.foot.next -side right -padx 8
  label $w.hint -anchor w -justify left -text [hint_text]
  frame $w.rule -height 1 -background [tone_of $w rule]

  fonts [$w.q cget -font]
  $w.head.title configure -font startup_quiz_bold
  $w.head.topic configure -font startup_quiz_small
  $w.prompt configure -font startup_quiz_small
  $w.q configure -font startup_quiz_head
  $w.verdict configure -font startup_quiz_bold
  $w.why configure -font startup_quiz_body
  $w.foot.dont configure -font startup_quiz_body
  $w.foot.close configure -font startup_quiz_body
  $w.foot.next configure -font startup_quiz_body
  $w.hint configure -font startup_quiz_small
  ## one column of text for everything, a comfortable line long
  set wrap [font measure startup_quiz_body [string repeat n 64]]
  foreach l [list $w.q $w.verdict $w.why $w.hint] { $l configure -wraplength $wrap }
  set dim [tone_of $w dim]
  $w.head.topic configure -foreground $dim
  $w.prompt configure -foreground $dim
  $w.hint configure -foreground $dim

  ## THE BUTTONS ARE PACKED FIRST. The packer gives room in packing order, so in
  ## a window that is too short for everything it is the explanation that loses
  ## its last lines, never the row with Next question and Close.
  pack $w.hint -side bottom -fill x -pady {10 0}
  pack $w.foot -side bottom -fill x
  pack $w.rule -side bottom -fill x -pady {0 12}
  pack $w.head -side top -fill x
  pack $w.prompt -side top -fill x -pady {14 0}
  pack $w.q -side top -fill x -pady {2 10}
  pack $w.opts -side top -fill x
  pack $w.verdict -side top -fill x -pady {14 0}
  pack $w.why -side top -fill x -pady {4 16}
  bind $w <Escape> startup_quiz::dismiss
  return $w
}

# Give the window the room its content asks for, and keep all of it on the
# screen. Called whenever the content has changed: a question put up, an answer
# given. Returns the size asked for as {width height}, or {} with no window.
#
# The size is SET, every time, and not left to Tk's following of its widgets: Tk
# stops following for good the first time the window gets a size from outside (a
# person's drag of its border, or a window manager's own idea of the size), and
# from then on an answer's explanation pushed the buttons out of the window.
#
# The window only ever grows: the size it has is kept when the content asks for
# less. So a question shorter than the one before leaves Next question and Close
# where the pointer left them, and a size a person dragged it to stays. What the
# content asks for is also the window's minimum size, so a drag cannot take it
# below that.
proc startup_quiz::fit {} {
  variable placed
  variable screen_margin
  set w .startup_quiz
  if {![have_tk] || ![winfo exists $w]} { return {} }
  update idletasks
  set nw [winfo reqwidth $w]
  set nh [winfo reqheight $w]
  wm minsize $w $nw $nh
  if {$placed && [winfo ismapped $w]} {
    set nw [expr {max($nw, [winfo width $w])}]
    set nh [expr {max($nh, [winfo height $w])}]
  }
  ## where it is, or where it goes the first time: centred on the window it
  ## belongs to, a third of the way down
  set gx 0
  set gy 0
  set ox 0
  set oy 0
  if {!$placed} {
    set parent .
    catch { set parent [winfo toplevel [xschem get topwindow]] }
    catch {
      set gx [expr {[winfo rootx $parent] + ([winfo width $parent] - $nw) / 2}]
      set gy [expr {[winfo rooty $parent] + ([winfo height $parent] - $nh) / 3}]
    }
  } elseif {[regexp {([+-]-?[0-9]+)([+-]-?[0-9]+)$} [wm geometry $w] -> gx gy]} {
    set gx [expr {$gx + 0}]
    set gy [expr {$gy + 0}]
    ## the window manager's border and title bar, when it has put them on
    if {[winfo ismapped $w]} {
      set ox [expr {max(0, min(100, [winfo rootx $w] - $gx))}]
      set oy [expr {max(0, min(100, [winfo rooty $w] - $gy))}]
    }
  }
  ## all of it on the screen: one that would pass the right or the bottom edge
  ## is moved back by that much, and never past the top or the left
  set x [expr {max(0, min($gx, [winfo screenwidth $w] - $screen_margin - $nw - $ox))}]
  set y [expr {max(0, min($gy, [winfo screenheight $w] - $screen_margin - $nh - $oy))}]
  if {!$placed} {
    wm geometry $w ${nw}x${nh}+$x+$y
    set placed 1
  } else {
    wm geometry $w ${nw}x${nh}
    if {$x != $gx || $y != $gy} { wm geometry $w +$x+$y }
  }
  return [list $nw $nh]
}

# Put question $id in the window, unanswered.
proc startup_quiz::display {id} {
  variable cur
  variable perm
  variable answered
  variable choice
  variable shown
  set w .startup_quiz
  set e [get $id]
  set cur $id
  set perm [order_options $id]
  set answered 0
  set choice -1
  if {[lsearch -exact $shown $id] < 0} { lappend shown $id }
  ## the box is the switch read the other way round, so the switch has to be 0 or 1
  set ::startup_quiz [enabled]
  $w.head.topic configure -text [dict get $e topic]
  $w.prompt configure -text [prompt $id]
  $w.q configure -text [dict get $e q]
  $w.verdict configure -text {}
  $w.why configure -text {}
  foreach c [winfo children $w.opts] { destroy $c }
  set wrap [$w.q cget -wraplength]
  set n [llength $perm]
  for {set i 0} {$i < $n} {incr i} {
    radiobutton $w.opts.o$i -text [option_text $id $perm $i] -anchor w -justify left \
      -wraplength $wrap -variable ::startup_quiz::choice -value $i \
      -font startup_quiz_body -command [list startup_quiz::answer $i]
    pack $w.opts.o$i -side top -fill x -pady 1
  }
  fit
  return $id
}

# Ask a question now: $id if it names one, else the next one. Returns the id on
# display, or {} when there is no display or no question.
proc startup_quiz::show {{id {}}} {
  variable cur
  variable bank_errors
  if {![have_tk]} { return {} }
  if {[load_bank] <= 0} {
    catch { ::xschem::notify "Tip of the day: no questions could be loaded\
([lindex $bank_errors 0])." -short {Tip of the day: none} }
    return {}
  }
  ## a question asked for by id is shown whether or not it applies to this session
  if {$id eq {} || ![has $id]} { set id [pick $cur] }
  if {$id eq {}} { return {} }
  window
  display $id
  return $id
}

# The option displayed at position $pos was picked. Marks the question, shows
# the verdict and the explanation, and locks the options. Returns what grade
# returned, or {} when there is nothing to answer or it was answered already.
proc startup_quiz::answer {pos} {
  variable cur
  variable perm
  variable answered
  variable choice
  variable last
  set w .startup_quiz
  if {$cur eq {} || $answered || ![have_tk] || ![winfo exists $w]} { return {} }
  if {![string is integer -strict $pos] || $pos < 0 || $pos >= [llength $perm]} { return {} }
  set pick [lindex $perm $pos]
  set g [grade $cur $pick]
  set answered 1
  set choice $pos
  set right [lsearch -exact $perm [dict get $g ok]]
  set n [llength $perm]
  for {set i 0} {$i < $n} {incr i} {
    set b $w.opts.o$i
    if {$i == $right} {
      $b configure -text "[option_text $cur $perm $i]   (correct)" \
        -disabledforeground [tone_of $w good]
    } elseif {$i == $pos} {
      $b configure -text "[option_text $cur $perm $i]   (your answer)" \
        -disabledforeground [tone_of $w bad]
    }
    $b configure -state disabled
  }
  $w.verdict configure -text [dict get $g head] \
    -foreground [tone_of $w [expr {[dict get $g correct] ? {good} : {bad}}]]
  $w.why configure -text [dict get $g why]
  set last [dict create id $cur pick $pick correct [dict get $g correct] head [dict get $g head]]
  mark_done $cur
  ## the verdict and the explanation need room the unanswered question did not
  fit
  return $g
}

proc startup_quiz::next_question {} {
  return [show]
}

proc startup_quiz::dismiss {} {
  catch { destroy .startup_quiz }
}
