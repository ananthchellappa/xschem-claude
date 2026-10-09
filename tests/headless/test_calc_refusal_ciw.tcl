## test_calc_refusal_ciw.tcl -- a Calculator refusal explains itself in the
## Calculator's status line AND in the CIW, and the CIW pane and the action log
## FILE both carry it (calc_feedback_batch items 2 and 3).
##
## The user's words, verbatim (doc/claude/calc_feedback_batch/BATCH.md):
##   "When Calculator does nothing after a button press, the explanation should
##    be available in the CIW, along with status bar of Calculator"
##   "Also, these things aren't being logged in the CIW log and log file."
##
## WHY THEY REACHED NEITHER (measured, band R0 below): `calc::status` wrote one
## Tk variable -- the Entry's -textvariable -- plus its own history list, and
## nothing else.  No Calculator proc called `ciw_echo` or `xschem log_action`,
## so the CIW pane and Xschem.log never heard of a refusal.  The fix is ONE tee,
## `calc::ciw_say`, called by `calc::status` for every line it RECORDS: every
## refusal arm in the tree already speaks through `calc::status` (directly, or
## through `calc::inert` / `calc::pick_echo`, both of which call it), so a tee
## there reaches every one of them by construction, and a refusal arm added
## later reaches the CIW without anyone remembering to.  Hover help
## (`record 0`) is not an event and is not teed.
##
## THE POPULATION IS DERIVED, NOT LISTED:
##   * band P walks the live `.calc` widget tree and collects every control a
##     user can press -- each widget's `-command`, each `<Button-1>` binding on
##     a widget, each `<Button-1>` binding on a canvas item -- and PRESSES every
##     one of them in the empty state (no result selected, empty buffer, empty
##     stack), which is where nearly every press is a refusal.  Each press must
##     put a line in the status history, and that same line must arrive in the
##     CIW pane and in the log file.  A disabled control is not pressable (its
##     -command never fires); it is counted, and its greyed look is its answer.
##   * band A reads every handler those controls name, closed over the procs
##     they DELEGATE to (`return [calc::X ...]`), strips comments, and classifies
##     every `return` arm: it speaks (through calc::status / calc::inert /
##     calc::pick_echo), delegates to a proc that is itself classified, sits
##     behind a no-window guard (derived from what its condition tests, never
##     from the line merely naming a window), or is one of the declared silent
##     arms below.  Each handler's reachable END is classified as well, so a
##     path that runs off the end of the proc without a word is named too.
##     Anything else is an UNCLASSIFIED silent arm and reddens the row by name.
##     A synthetic silent proc is fed to the same classifier as the
##     non-vacuity leg, and every declared exemption must match exactly once
##     so a stale one reddens too.
##
## A CLOSED CIW STILL RECEIVES THE LINE (row R0g): closing the CIW withdraws
## `.ciw` (its WM_DELETE_WINDOW script in src/ciw.tcl) and the pane survives,
## so a refusal made while it is closed is in the pane when it is reopened.
## The line is missing from the CIW only if the CIW was never created.
##
## DECLARED LIMITS: band A reads source text, so an arm written across a
## backslash continuation, or a `return` produced by `eval`, is not seen; the
## behavioural band P is the cross-check for the arms it can reach.  Band P
## reaches only the empty state; arms that need a loaded result are covered by
## band A and by the tee being inside calc::status.
##
## Display-only (the status line is a no-op without Tk: R508), so this suite is
## registered in `dcases` alone.  The log-file legs need `--logdir`, which T1's
## display arm passes; under `run_suites.sh`'s default `--nolog` arm they are
## announced SKIPPED, and `run_suites.sh --logdir test_calc_refusal_ciw` runs
## them.

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
    return $r
}
set ::abortnames {}
proc group {name script} {
    if {[catch {uplevel 1 $script} e]} {
        puts "FAIL: group $name ABORTED -> $e : FAIL"
        puts $::errorInfo
        lappend ::abortnames $name
        incr ::fail
    }
}
proc ::bgerror {msg} { puts "BGERROR: $msg : FAIL"; incr ::fail }

if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "RESULT: SKIP (no X: the Calculator status line is Tk-only)"
    flush stdout
    exit 0
}

source [file join [file dirname [info script]] scratch.tcl]

# --- sink readers -------------------------------------------------------------
proc ciw_text {} {
    if {![winfo exists .ciw.l.t]} { return {} }
    return [.ciw.l.t get 1.0 end-1c]
}
proc log_name {} {
    set f {}
    catch {set f [xschem get actionlog_filename]}
    return $f
}
proc log_size {} {
    set f [log_name]
    if {$f eq {} || ![file exists $f]} { return -1 }
    return [file size $f]
}
proc log_tail {from} {
    set f [log_name]
    if {$f eq {} || ![file exists $f] || $from < 0} { return {} }
    set h [open $f r]
    seek $h $from
    set t [read $h]
    close $h
    return $t
}
proc hist_len {} { return [llength [pcall calc::status_history]] }
proc hist_top {} { return [lindex [pcall calc::status_history] 0] }

# the reset that makes every press start from the same empty state
proc empty_state {} {
    catch {.calc.buf delete 1.0 end}
    catch {calc::buf_sync}
    catch {calc::stk_clear}
    catch {calc::pick_end close}
    # the history is capped (R509), so a press is detected by the history
    # GROWING from empty, never by its length against a full list
    catch {set ::calc::statushist {}}
}

# --- the fixture ----------------------------------------------------------------
set ::haslog [expr {[log_name] ne {}}]
if {!$::haslog} {
    puts "SKIPPED: the log-file legs (no action log: this arm ran with --nolog; T1's display arm and run_suites.sh --logdir pass --logdir)"
}
if {![winfo exists .ciw.l.t]} { catch {ciw_create} }
check "F0 fixture: the CIW pane exists to be written" [winfo exists .ciw.l.t] 1
check "F1 fixture: calc::open builds the window" [pcall calc::open] .calc
update
empty_state

# --- band R0: the tee itself --------------------------------------------------
group R0 {
    check "R0a calc::ciw_say exists and takes exactly {msg}" \
        [pcall info args ::calc::ciw_say] msg
    set probe "refusal probe [clock clicks]"
    set c0 [ciw_text]
    set l0 [log_size]
    calc::status $probe
    update idletasks
    set c1 [ciw_text]
    set added [string range $c1 [string length $c0] end]
    check "R0b a recorded status line reaches the CIW pane exactly once, prefixed so the reader knows it came from the Calculator" \
        [regexp -all -- [string map {. \\.} "Calculator: $probe"] $added] 1
    if {$::haslog} {
        check "R0c ...and the action log FILE, as a comment line so the log stays replayable" \
            [regexp -line -- "^#.*Calculator: [string map {. \\.} $probe]\$" [log_tail $l0]] 1
    }
    set c0 [ciw_text]
    set l0 [log_size]
    set hov "hover probe [clock clicks]"
    calc::status $hov 0
    update idletasks
    check "R0d hover help (record 0) is a legend, not an event: it reaches NEITHER the CIW nor the log" \
        [list [string first $hov [ciw_text]] [string first $hov [log_tail $l0]]] {-1 -1}
    check "R0e the status line itself still shows the recorded probe (the tee did not replace the first sink)" \
        [lindex [calc::status_history] 0] $probe
    # Focus is put on a KNOWN widget first, and a leg proves it landed there:
    # without that, f0 is whatever an earlier call left behind -- including
    # the CIW, if the tee had already stolen it -- and the row only compares
    # one copy with the copy before it.
    catch {focus -force .calc.buf}
    update
    set f0 {}
    catch {set f0 [focus]}
    check "R0f0 fixture: the keyboard focus sits on the Calculator buffer before the probe, so R0f compares against a known widget" \
        $f0 .calc.buf
    calc::status "focus probe"
    update
    set f1 {}
    catch {set f1 [focus]}
    check "R0f the tee does not move the keyboard focus off the widget the user was typing in" $f1 $f0
    # A CLOSED CIW STILL HEARS IT.  The CIW's close is its own WM_DELETE_WINDOW
    # script (src/ciw.tcl, ciw_create), which WITHDRAWS `.ciw` rather than
    # destroying it, so the pane still exists and ::ciw_echo writes into it:
    # the line is waiting there when the user reopens the CIW.  The close is
    # driven by evaluating that protocol script -- not by a hand-written
    # `wm withdraw` -- so the row measures what the title-bar X really does.
    # A line is lost from the CIW only when the CIW was never created (then
    # ::ciw_echo no-ops and calc::ciw_say does not report the `ciw` sink).
    set wasmapped [winfo ismapped .ciw]
    set closer [wm protocol .ciw WM_DELETE_WINDOW]
    catch {uplevel #0 $closer}
    update
    set c0 [ciw_text]
    set cprobe "closed-ciw probe [clock clicks]"
    calc::status $cprobe
    update idletasks
    set sinks {}
    catch {set sinks [dict get [calc::ciw_last] sinks]}
    check "R0g a refusal made while the CIW is CLOSED (its own close script run) still lands in the CIW pane, which survives the close, and ciw_say reports the ciw sink" \
        [list [expr {$closer ne {}}] [winfo exists .ciw.l.t] [expr {[winfo exists .ciw] ? [winfo ismapped .ciw] : {gone}}] \
              [regexp -all -- [string map {. \\.} "Calculator: $cprobe"] [string range [ciw_text] [string length $c0] end]] \
              [expr {"ciw" in $sinks}]] \
        {1 1 0 1 1}
    if {$wasmapped} { catch {wm deiconify .ciw} ; update }
    if {![winfo exists .ciw.l.t]} { catch {ciw_create} }
}

# --- band P: press every control the user can press, in the empty state -------
proc walk {w} {
    set out [list $w]
    foreach c [winfo children $w] { lappend out {*}[walk $c] }
    return $out
}
proc controls {} {
    set out {}
    foreach w [walk .calc] {
        set cls [winfo class $w]
        if {$cls in {Scrollbar TScrollbar TCombobox}} { continue }
        if {![catch {$w cget -command} cmd] && [string trim $cmd] ne {}} {
            lappend out [list cmd $w $cmd]
        }
        set b [bind $w <Button-1>]
        if {$b ne {} && [string match *calc::* $b]} { lappend out [list bind $w $b] }
        if {$cls eq {Canvas}} {
            set tags {}
            foreach it [$w find all] {
                foreach tg [concat $it [$w gettags $it]] {
                    if {$tg ni $tags} { lappend tags $tg }
                }
            }
            foreach tg $tags {
                set ib [$w bind $tg <Button-1>]
                if {$ib ne {}} { lappend out [list item $w:$tg $ib] }
            }
        }
    }
    return $out
}

group P {
    set ctl [controls]
    set npop [llength $ctl]
    set names {}
    foreach c $ctl { lappend names [lindex $c 1] }
    check "P0 non-vacuity: the derived population includes the toolbar's Eval, Plot, Enter, Pop and ClrStk and the function list's items, and is not small" \
        [list [expr {".calc.mode.eval" in $names}] [expr {".calc.mode.plot" in $names}] \
              [expr {".calc.btb.enter" in $names}] [expr {".calc.btb.pop" in $names}] \
              [expr {".calc.btb.clrstk" in $names}] \
              [expr {[llength [lsearch -all -glob $names .calc.fn.list:*]] > 10}] \
              [expr {$npop > 40}]] {1 1 1 1 1 1 1}
    set pressed 0 ; set disabled 0 ; set silent {} ; set noCiw {} ; set noLog {}
    set spoke 0
    foreach c $ctl {
        lassign $c kind w script
        empty_state
        update idletasks
        if {$kind eq {cmd}} {
            set st normal
            catch {set st [$w cget -state]}
            if {$st eq {disabled}} { incr disabled ; continue }
        }
        set h0 [hist_len]
        set c0 [string length [ciw_text]]
        set l0 [log_size]
        if {$kind eq {cmd}} {
            set r [pcall $w invoke]
        } else {
            set r [pcall uplevel #0 $script]
        }
        update idletasks
        incr pressed
        if {[string match ERR:* $r]} { lappend silent "$w(raised:$r)" ; continue }
        if {[hist_len] <= $h0} { lappend silent $w ; continue }
        incr spoke
        set m [hist_top]
        set cadd [string range [ciw_text] $c0 end]
        if {[string first "Calculator: $m" $cadd] < 0} { lappend noCiw $w }
        if {$::haslog && [string first "Calculator: $m" [log_tail $l0]] < 0} { lappend noLog $w }
        # undo the two presses whose success changes the window itself
        if {$w eq {.calc.btb.fsz}} { catch {calc::font_step -1} }
        if {$w eq {.calc.res.tog} || [string match *res_toggle* $script]} { catch {calc::res_toggle} }
    }
    empty_state
    check "P1 every enabled control pressed in the empty state SAYS something on the status line -- the silent ones are named" \
        $silent {}
    check "P2 ...and every one of those lines reached the CIW pane" $noCiw {}
    if {$::haslog} {
        check "P3 ...and the action log file" $noLog {}
    }
    check "P4 riding count: pressed + disabled = the derived population, and every press spoke ($pressed pressed, $disabled disabled)" \
        [list [expr {$pressed + $disabled}] $spoke] [list $npop $pressed]
}

# --- band A: every return arm of every handler, classified --------------------
# comment lines dropped, and a line whose `[` is still open (or that ends in a
# backslash) joined to the next, so a call spanning lines is one arm's text
proc decomment {body} {
    set out {}
    set acc {}
    foreach l [split $body \n] {
        if {$acc eq {} && [regexp {^\s*#} $l]} { continue }
        if {$acc ne {}} { set l "$acc [string trim $l]" }
        set open [expr {[regexp -all {\[} $l] - [regexp -all {\]} $l]}]
        if {$open > 0 || [string index $l end] eq "\\"} {
            set acc [string trimright $l "\\"]
            continue
        }
        set acc {}
        lappend out $l
    }
    if {$acc ne {}} { lappend out $acc }
    return $out
}
# the first word of a command script, resolved to a ::calc:: proc
proc script_proc {s} {
    set s [string trim $s]
    if {[catch {lindex $s 0} w]} { return {} }
    set w [string trimleft $w :]
    if {![string match calc::* $w]} { return {} }
    if {[info procs ::$w] eq {}} { return {} }
    return ::$w
}
# the procs that speak by themselves
set ::speakers {calc::status calc::inert calc::pick_echo}
# A speaker is matched as a whole COMMAND NAME, never as a substring: a line
# writing calc::statusmsg (the status bar's variable) or calling
# calc::status_fit / calc::status_history shows text on the Calculator and
# reaches neither the CIW nor the log, so it must NOT count as speaking.
proc speaks_in {t} {
    regexp {(^|[\s\[;\{])(::)?calc::(status|inert|pick_echo)(\s|\]|;|\}|$)} $t
}
# DECLARED SILENT ARMS: proc + the arm's own text.  Each must match EXACTLY once.
#   * Cancel is the user's own choice and R412 requires it to leave nothing;
#     the same `return {}` text ends the ACCEPTED path, whose caller
#     (calc::fn_measure) is the one that speaks -- hence two matches.
#   * font_step's argument guard is not reachable from a control (both
#     bindings pass 1 or -1).
#   * pick_click with no pick armed is a stale binding, not a press.
#   * pick_end's switch/close/no-id returns are internal teardown; its
#     `picked` return follows the pick_echo that already spoke.
#   * fn_measure's empty answer is the dialog's Cancel (the dialog builder's own
#     failure arms speak inside calc::arg_dialog).
set ::exempt {
    {::calc::arg_dialog_done {return {}} cancel+accepted 2}
    {::calc::font_step {if {$dir ne {1} && $dir ne {-1}} { return 0 }} argguard}
    {::calc::pick_click {if {![info exists pick(id)]} { return {} }} notarmed}
    {::calc::pick_end {if {$why eq {switch} || $why eq {close}} { return $r }} teardown}
    {::calc::pick_end {if {$id eq {}} { return $r }} teardown}
    {::calc::pick_end {return $r} picked}
    {::calc::fn_measure {if {$ans eq {}} { return {} }} cancel}
}
# Brace depth at the START of each decommented line (escaped braces ignored).
proc line_depths {lines} {
    set d 0 ; set out {}
    foreach l $lines {
        lappend out $d
        set x [string map [list "\\\{" {} "\\\}" {}] $l]
        incr d [expr {[regexp -all {\{} $x] - [regexp -all {\}} $x]}]
    }
    return $out
}
# A statement that speaks UNCONDITIONALLY when it runs: the speaker is the
# line's own command (optionally under catch, or as `set v [speaker`), never a
# call buried inside an if/foreach/switch body on that line.
proc speaks_stmt {t} {
    regexp {^((catch\s+\{\s*)|(set\s+\w+\s+\[\s*))?(::)?calc::(status|inert|pick_echo)(\s|\]|;|\}|$)} $t
}
# The PREV-LINE rule: a BARE `return ...` (the return is the line's own
# command, not the body of a one-line if) speaks when the statement directly
# before it IN THE SAME BLOCK is a speaking statement.  "Same block" is
# measured: equal start depth, and the previous line neither closes a block
# (`}` / `} else {`) nor opens one, nor is itself a return.  A return line is
# never a predecessor, so a silent arm right under a speaking arm is not
# credited with its neighbour's sentence.
# The HAND-OFF rule: a bare `return $v` speaks when the last DOMINATING
# assignment to v is `set v [speaker ...`.  Walking backwards, a line
# dominates when its start depth is <= every depth seen so far and it is not
# inside a block a `}` line closed; an assignment in a sibling branch does not.
# A NO-WINDOW GUARD is DERIVED from what its condition tests, never from the
# line merely mentioning a window: the line must be exactly `if {COND} {
# return ... }`, and COND must be one term or an `||` of terms, EVERY one of
# which is a negated window test, `![calc::has_win W]` or `![winfo exists W]`.
# Only then does the return fire solely when a window is missing, which is
# R508's silent no-op.  A condition that ANDs a window test with anything else
# (`... eq {} && [calc::has_win .calc.buf]`), ORs one with a non-window term,
# or tests a window un-negated fires while the window is up, so it is a
# refusal and must speak like any other.  Parsed as a Tcl list, so a line that
# does not parse is simply not a guard.
proc guard_line {t} {
    if {[catch {llength $t} n] || $n != 3 || [lindex $t 0] ne {if}} { return 0 }
    set body [string trim [lindex $t 2]]
    if {![regexp {^return(\s|$)} $body] || [string first {;} $body] >= 0} { return 0 }
    set cond [lindex $t 1]
    if {[string first && $cond] >= 0} { return 0 }
    foreach term [split [string map [list || \x01] $cond] \x01] {
        if {![regexp {^\s*!\s*\[\s*(::)?(calc::has_win|winfo\s+exists)\s+[^\s\[\]]+\s*\]\s*$} $term]} {
            return 0
        }
    }
    return 1
}
# THE REACHABLE END.  A path that runs off the end of a proc returns silently
# with no `return` line for classify to see, so every handler's end is
# classified too: the proc's LAST top-level statement (start depth 0) must be
# an explicit `return` -- whose own arm classify already judged -- or a single
# line that speaks unconditionally.  Anything else (an `if`/`switch`/`foreach`
# block, an assignment, an empty body) means some path falls through without a
# word, and the end is reported UNCLASSIFIED under the arm text
# `<falls off the end after: ...>`.  An end can only be reached through the
# last top-level statement, so this one statement decides it.  Returns
# {p text cls} with cls `return` for an explicit return.
proc end_arm {p lines} {
    set deps [line_depths $lines]
    set i -1
    for {set k 0} {$k < [llength $lines]} {incr k} {
        if {[lindex $deps $k] == 0 && [string trim [lindex $lines $k]] ne {}} { set i $k }
    }
    if {$i < 0} { return [list $p {<falls off the end after: (empty body)>} UNCLASSIFIED] }
    set t [string trim [lindex $lines $i]]
    if {[regexp {^return(\s|$)} $t]} { return [list $p $t return] }
    set last [expr {[llength $lines] - 1}]
    while {$last > $i && [string trim [lindex $lines $last]] eq {}} { incr last -1 }
    if {$last == $i && [speaks_stmt $t]} { return [list $p "<falls off the end after: $t>" speaks] }
    return [list $p "<falls off the end after: $t>" UNCLASSIFIED]
}
proc classify {p lines} {
    set out {}
    set deps [line_depths $lines]
    set n [llength $lines]
    for {set i 0} {$i < $n} {incr i} {
        set t [string trim [lindex $lines $i]]
        if {![regexp {(^|[;\{\[]\s*)return(\s|$|\])} $t]} { continue }
        set d [lindex $deps $i]
        set bare [regexp {^return(\s|$)} $t]
        set cls {}
        if {[speaks_in $t]} { set cls speaks }
        if {$cls eq {} && $bare && $i > 0} {
            set j [expr {$i - 1}]
            while {$j >= 0 && [string trim [lindex $lines $j]] eq {}} { incr j -1 }
            if {$j >= 0} {
                set pt [string trim [lindex $lines $j]]
                if {[lindex $deps $j] == $d && ![string match "\}*" $pt] \
                        && [string index $pt end] ne "\{" \
                        && ![regexp {(^|[;\{\[]\s*)return(\s|$|\])} $pt] \
                        && [speaks_stmt $pt]} {
                    set cls speaks
                }
            }
        }
        if {$cls eq {} && $bare && [regexp {^return \$(\w+)\s*$} $t -> rv]} {
            set m $d
            for {set j [expr {$i - 1}]} {$j >= 0} {incr j -1} {
                set pt [string trim [lindex $lines $j]]
                set pd [lindex $deps $j]
                if {[string match "\}*" $pt]} { set m [expr {min($m, $pd - 1)}] ; continue }
                if {$pd > $m} { continue }
                set m $pd
                if {[regexp "^set\\s+$rv\\s" $pt]} {
                    if {[speaks_stmt $pt]} { set cls speaks }
                    break
                }
            }
        }
        if {$cls eq {} && [regexp {return \[calc::(\w+)} $t -> dp] && [info procs ::calc::$dp] ne {}} {
            set cls [list delegates ::calc::$dp]
        }
        if {$cls eq {} && [guard_line $t]} { set cls guard }
        if {$cls eq {}} {
            foreach e $::exempt {
                if {[lindex $e 0] eq $p && [lindex $e 1] eq $t} { set cls [list exempt [lindex $e 2]] ; break }
            }
        }
        if {$cls eq {}} { set cls UNCLASSIFIED }
        lappend out [list $p $t $cls]
    }
    return $out
}

group A {
    set roots {}
    foreach c [controls] {
        set p [script_proc [lindex $c 2]]
        if {$p ne {} && $p ni $roots} { lappend roots $p }
    }
    # the dialog's OK is not on the window until a dialog is open: its command
    # is derived from the builder's own text rather than listed here
    if {[regexp {calc::arg_dialog_done} [info body ::calc::arg_dialog_build]]} {
        lappend roots ::calc::arg_dialog_done
    }
    # likewise the pick's canvas click lives on the DESIGN window, installed by
    # the seize, and is derived from the seize's own text
    if {[regexp {calc::pick_click} [info body ::calc::_pick_seize]]} {
        lappend roots ::calc::pick_click
    }
    set todo $roots ; set seen {} ; set arms {} ; set ends {}
    while {[llength $todo]} {
        set p [lindex $todo 0] ; set todo [lrange $todo 1 end]
        if {$p in $seen} { continue }
        lappend seen $p
        if {[string trimleft $p :] in $::speakers} { continue }
        set lines [decomment [info body $p]]
        foreach a [classify $p $lines] {
            lappend arms $a
            set cls [lindex $a 2]
            if {[lindex $cls 0] eq {delegates}} { lappend todo [lindex $cls 1] }
        }
        set e [end_arm $p $lines]
        lappend ends $e
        if {[lindex $e 2] ne {return}} { lappend arms $e }
    }
    set bad {} ; set n(speaks) 0 ; set n(delegates) 0 ; set n(guard) 0 ; set n(exempt) 0
    set hits {}
    foreach a $arms {
        set k [lindex $a 2 0]
        if {$k eq {UNCLASSIFIED}} { lappend bad "[lindex $a 0]: [lindex $a 1]" ; continue }
        incr n($k)
        if {$k eq {exempt}} { lappend hits [list [lindex $a 0] [lindex $a 1]] }
    }
    check "A0 non-vacuity: the derived handler set includes eval_click, pick_click, plot_click, stk_popped, fn_click, sel_click and arg_dialog_done" \
        [list [expr {"::calc::eval_click" in $seen}] [expr {"::calc::pick_click" in $seen}] [expr {"::calc::plot_click" in $seen}] \
              [expr {"::calc::stk_popped" in $seen}] [expr {"::calc::fn_click" in $seen}] \
              [expr {"::calc::sel_click" in $seen}] [expr {"::calc::arg_dialog_done" in $seen}]] \
        {1 1 1 1 1 1 1}
    check "A1 every return arm of every handler speaks, delegates, is behind a no-window guard, or is a declared silent arm -- an UNCLASSIFIED arm is a silent refusal and is named here ([llength $arms] arms: $n(speaks) speak, $n(delegates) delegate, $n(guard) guarded, $n(exempt) exempt, over [llength $seen] procs)" \
        $bad {}
    set stale {}
    foreach e $::exempt {
        set k [list [lindex $e 0] [lindex $e 1]]
        set c [llength [lsearch -all -exact $hits $k]]
        set want 1
        if {[llength $e] > 3} { set want [lindex $e 3] }
        if {$c != $want} { lappend stale "[lindex $e 0] ([lindex $e 2]) x$c" }
    }
    check "A2 every declared silent arm matched exactly its declared number of times (once unless stated), so a stale or duplicated exemption reddens" $stale {}
    check "A3 riding count: more arms speak than are exempt, and the classifier saw real arms" \
        [list [expr {$n(speaks) > 3 * $n(exempt)}] [expr {[llength $arms] > 40}]] {1 1}
    set adl [decomment [info body ::calc::arg_dialog]]
    set ad [classify ::calc::arg_dialog $adl]
    set ade [end_arm ::calc::arg_dialog $adl]
    if {[lindex $ade 2] ne {return}} { lappend ad $ade }
    set adbad {}
    foreach a $ad {
        if {[lindex $a 2] eq {UNCLASSIFIED} && [lindex $a 1] ne {return $arg_result}} {
            lappend adbad [lindex $a 1]
        }
    }
    check "A6 the argument dialog's own failure arms (builder raised, builder built nothing) speak, so fn_measure's empty answer can only be the user's Cancel -- every other arm is named here ([llength $ad] arms; `return \$arg_result` is the hand-off)" \
        $adbad {}
    proc ::calc::zz_silent_probe {} {
        if {1} { return {} }
        return [calc::status x]
    }
    set s [classify ::calc::zz_silent_probe [decomment [info body ::calc::zz_silent_probe]]]
    rename ::calc::zz_silent_probe {}
    check "A4 the classifier is not vacuous: a synthetic silent arm is reported UNCLASSIFIED and its speaking arm is not" \
        [list [lindex $s 0 2] [lindex $s 1 2]] {UNCLASSIFIED speaks}
    # An arm that writes the status bar's VARIABLE (or calls a status_*
    # sibling) shows text on the Calculator and reaches neither the CIW nor the
    # log -- the user's reported defect -- so it must come out UNCLASSIFIED,
    # whether the write is on the return line or the line before it.
    proc ::calc::zz_bar_only_probe {} {
        if {1} { set ::calc::statusmsg [calc::plot_msg empty] ; return {} }
        if {2} {
            set ::calc::statusmsg x
            return {}
        }
        if {3} { calc::status_fit ; return {} }
        if {4} { calc::status_history ; return {} }
        if {5} { calc::status x ; return {} }
        return [::calc::status x]
    }
    set s [classify ::calc::zz_bar_only_probe [decomment [info body ::calc::zz_bar_only_probe]]]
    rename ::calc::zz_bar_only_probe {}
    set got {}
    foreach a $s { lappend got [lindex $a 2 0] }
    check "A4b a status-bar-only arm (writes calc::statusmsg, or calls calc::status_fit / status_history) is UNCLASSIFIED, while a real calc::status call still speaks" \
        $got {UNCLASSIFIED UNCLASSIFIED UNCLASSIFIED UNCLASSIFIED speaks speaks}
    # A silent arm placed directly under a speaking arm, or under a speaking
    # statement in ANOTHER block, must not borrow that sentence; nor may a
    # `return $v` whose speaking assignment sits in a sibling branch.  The
    # last three arms are the shapes that really speak, so the probe cannot
    # pass by calling everything silent.
    proc ::calc::zz_neighbour_probe {rpn} {
        if {$rpn eq {}} { return [calc::status x] }
        if {[llength $rpn] > 0} { return {} }
        if {1} { calc::status y }
        if {2} { return {} }
        if {3} {
            calc::status z
        }
        return {}
        if {4} {
            set v [calc::status w]
        } else {
            set v {}
        }
        return $v
        if {5} {
            set u [calc::status u]
            return $u
        }
        if {6} {
            calc::status q
            return {}
        }
        set s [calc::pick_echo k]
        return $s
    }
    set s [classify ::calc::zz_neighbour_probe [decomment [info body ::calc::zz_neighbour_probe]]]
    rename ::calc::zz_neighbour_probe {}
    set got {}
    foreach a $s { lappend got [lindex $a 2 0] }
    check "A4c a silent arm directly under a speaking arm, after a speaker in another block, or handing off a variable set by a speaker only in a sibling branch is UNCLASSIFIED; same-block speakers and dominating hand-offs still speak" \
        $got {speaks UNCLASSIFIED UNCLASSIFIED UNCLASSIFIED UNCLASSIFIED speaks speaks speaks}
    # Fall-through: the first probe is the verifier's sabotage shape (the
    # speaking return sits INSIDE the if, nothing follows it); the others are
    # an assignment as the last statement, an empty body, a speaking last
    # statement (must speak) and an explicit last return (must be `return`).
    proc ::calc::zz_fall_probe1 {rpn} {
        if {[string trim $rpn] ne {}} {
            set m x
            return [calc::status $m]
        }
    }
    proc ::calc::zz_fall_probe2 {} { set x 1 }
    proc ::calc::zz_fall_probe3 {} {}
    proc ::calc::zz_fall_probe4 {} {
        if {1} { return [calc::status a] }
        calc::status b
    }
    proc ::calc::zz_fall_probe5 {} {
        if {1} { return [calc::status a] }
        return [calc::status b]
    }
    set got {}
    foreach k {1 2 3 4 5} {
        set pp ::calc::zz_fall_probe$k
        lappend got [lindex [end_arm $pp [decomment [info body $pp]]] 2]
        rename $pp {}
    }
    check "A4d a handler path that runs off the end of the proc with no return is UNCLASSIFIED (speaking return only inside an if, last statement an assignment, empty body), while a speaking last statement speaks and an explicit last return is left to its own arm" \
        $got {UNCLASSIFIED UNCLASSIFIED UNCLASSIFIED speaks return}
    # Guards are derived from the condition: only an all-negated window test
    # (alone or ||-joined) is a guard.  The third line is the verifier's
    # sabotage; the rest are an || with a non-window term, an un-negated test,
    # a guard whose body does more than return, and an ||-joined pair of
    # real window tests (a guard).
    set got {}
    foreach t [list \
        {if {![calc::has_win .calc.buf]} { return {} }} \
        {if {![winfo exists .calc]} { return {} }} \
        {if {[string trim $rpn] eq {} && [calc::has_win .calc.buf]} { return {} }} \
        {if {![calc::has_win .calc.buf] || $rpn eq {}} { return {} }} \
        {if {[calc::has_win .calc.buf]} { return {} }} \
        {if {![calc::has_win .calc.buf]} { set x 1 ; return {} }} \
        {if {![calc::has_win .calc.buf] || ![::calc::has_win .calc]} { return {} }} ] {
        lappend got [guard_line $t]
    }
    check "A4e a no-window guard is derived from what its condition tests: only a negated has_win / winfo exists, alone or ||-joined, is a guard; ANDed with a real condition, ORed with one, un-negated, or with a body that does more than return, it is not" \
        $got {1 1 0 0 0 0 1}
    # The same sabotage, end to end through classify: the guard-shaped
    # refusal arm comes out UNCLASSIFIED rather than guarded.
    proc ::calc::zz_guard_probe {rpn} {
        if {[string trim $rpn] eq {} && [calc::has_win .calc.buf]} { return {} }
        if {![calc::has_win .calc.buf]} { return {} }
        return [calc::status x]
    }
    set s [classify ::calc::zz_guard_probe [decomment [info body ::calc::zz_guard_probe]]]
    rename ::calc::zz_guard_probe {}
    set got {}
    foreach a $s { lappend got [lindex $a 2 0] }
    check "A4f through classify, a refusal that merely mentions has_win is UNCLASSIFIED and a real no-window guard is still guarded" \
        $got {UNCLASSIFIED guard speaks}
    set fell {}
    set nret 0
    set nsp 0
    foreach q $seen { if {[string trimleft $q :] in $::speakers} { incr nsp } }
    foreach e $ends {
        if {[lindex $e 2] eq {return}} { incr nret } else { lappend fell "[lindex $e 0]: [lindex $e 1] ([lindex $e 2])" }
    }
    check "A7 every handler's reachable end was classified, and every one ends in an explicit return -- a handler that can run off its end is named here ([llength $ends] ends over [llength $seen] procs, $nret explicit returns, the three speakers excluded)" \
        [list [llength $ends] [expr {[llength $ends] == [llength $seen] - $nsp}] $fell] \
        [list [llength $ends] 1 {}]
    check "A5 the three speakers really route through calc::status, and calc::status really calls the tee" \
        [list [regexp {calc::status} [info body ::calc::inert]] \
              [regexp {calc::status} [info body ::calc::pick_echo]] \
              [regexp {calc::ciw_say} [join [decomment [info body ::calc::status]] \n]]] {1 1 1}
}

catch {calc::close}
check "EVERY band above this one RAN TO ITS END (names of any abandoned band)" \
    [list [llength $::abortnames] $::abortnames] {0 {}}

if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
