## test_calc_stack_gestures.tcl -- a Calculator stack entry is recalled by a
## double-click and copied to the clipboard from a right-click menu
## (calc_feedback_batch items 7 and 8).
##
## The user's words, verbatim (doc/claude/calc_feedback_batch/BATCH.md):
##   "Double-clicking one of the expressions saved in the Calculator stack should
##    populate the Calculator buffer with that expression - effectively recalling
##    it."
##   "Right-click on an expression in the Calculator stack should provide a
##    context menu enabling the user to copy that expression to clipboard."
##
## NEITHER GESTURE ALTERS THE STACK.  Recall copies the entry into the buffer and
## leaves it on the stack (it is not Pop); Copy touches the clipboard only.  Every
## display row reads the model back to prove it.
##
## THE ENTRY IS THE ONE UNDER THE POINTER, NOT THE LISTBOX'S `nearest`.  Tk's
## `nearest` answers the LAST entry for a click in the empty area below it, so a
## double-click on blank space would recall an expression the user never pointed
## at.  Rows D7 and D13 click below the last entry and assert nothing happens
## except a sentence saying so.
##
## THE SIDE BUTTONS STAY INERT.  `Del`, `Recall`, `Swap`, `Roll` are an open
## ruling (BATCH.md); row D14 asserts the stack buttons still run calc::inert.
##
## DECLARED LIMITS: the context menu's Copy entry is reached by `invoke` after a
## real right-click posts the menu -- clicking inside a posted menu needs its
## grab and is not driven; the clipboard is read back in this process only, not
## from another X client.
##
## Arms: band P (model + sentences) on both; band D needs Tk and announces
## itself SKIPPED under --nogui.  Registered in BOTH hcases and dcases.

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc pcall {args} {
    if {[catch {uplevel 1 $args} r]} { return "ERR:[string map [list \{ ( \} ) \" '] $r]" }
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

source [file join [file dirname [info script]] scratch.tcl]

set ::sg_model [list {v(a) 2 *} {-v(b)} {cross(v(vbg), 0.5, 1, rising)}]

# --- band P: the model accessor and the sentences, both arms -----------------
group P {
    check "P0 calc::stk_entry takes exactly {idx} (info args)" \
        [pcall info args calc::stk_entry] {idx}
    pcall calc::stk_set $::sg_model
    check "P1 calc::stk_entry answers the model's entry at an index, top of stack first" \
        [list [pcall calc::stk_entry 0] [pcall calc::stk_entry 1] [pcall calc::stk_entry 2]] \
        $::sg_model
    check "P2 an index off either end, a non-integer and an empty index all answer {} (entries are never empty, so {} is unambiguous)" \
        [list [pcall calc::stk_entry 3] [pcall calc::stk_entry -1] \
              [pcall calc::stk_entry end] [pcall calc::stk_entry x] [pcall calc::stk_entry {}]] \
        {{} {} {} {} {}}
    check "P3 reading entries leaves the model alone" \
        [pcall calc::stk_get] $::sg_model
    set s [list [pcall calc::stk_msg recalled 2] [pcall calc::stk_msg norecall] \
               [pcall calc::stk_msg copied 2] [pcall calc::stk_msg nocopy]]
    set nonempty 1
    foreach x $s { if {$x eq {} || [string match ERR:* $x]} { set nonempty 0 } }
    check "P4 calc::stk_msg has four distinct, non-empty sentences for recall, nothing-to-recall, copy and nothing-to-copy; the numbered two name the entry" \
        [list $nonempty [llength [lsort -unique $s]] \
              [string match *2* [lindex $s 0]] [string match *2* [lindex $s 2]]] \
        {1 4 1 1}
    pcall calc::stk_set {}
}

# --- band D: real pointer events on the real listbox -------------------------
# A row with no box (a sabotaged product that shrank the stack) answers a
# point off the widget rather than raising, so the band reports rows, not an abort.
proc sg_xy {i} {
    set bb [.calc.stk.list bbox $i]
    if {[llength $bb] != 4} { return {3 5000} }
    lassign $bb x y w h
    return [list [expr {$x + 3}] [expr {$y + $h / 2}]]
}
proc sg_below {} {
    set n [.calc.stk.list size]
    set bb [.calc.stk.list bbox [expr {$n - 1}]]
    if {[llength $bb] != 4} { return {3 5000} }
    lassign $bb x y w h
    return [list [expr {$x + 3}] [expr {$y + $h + 12}]]
}
# Event times are explicit: Tk counts a press as a double (or triple) click
# from the event time and position, so two gestures in quick succession at one
# spot would otherwise merge -- each gesture starts 5 s after the last.
set ::sg_t 1000000
proc sg_click {b xy {gap 5000}} {
    lassign $xy x y
    set w .calc.stk.list
    incr ::sg_t $gap
    event generate $w <Enter> -x $x -y $y -time $::sg_t
    event generate $w <Motion> -x $x -y $y -time $::sg_t
    event generate $w <ButtonPress-$b> -x $x -y $y -time $::sg_t
    incr ::sg_t 20
    event generate $w <ButtonRelease-$b> -x $x -y $y -time $::sg_t
    update
}
proc sg_dbl {xy} { sg_click 1 $xy ; sg_click 1 $xy 60 }
proc sg_buf {} { return [.calc.buf get 1.0 end-1c] }
proc sg_typed {s} {
    .calc.buf delete 1.0 end
    .calc.buf edit reset
    .calc.buf insert end $s
    .calc.buf mark set insert end-1c
}
proc sg_unpost {} {
    if {[winfo exists .calc.stk.menu]} {
        catch {.calc.stk.menu unpost}
        catch {grab release .calc.stk.menu}
    }
    update
}
proc sg_status {} { return $::calc::statusmsg }

if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "SKIPPED: band D (no X: the stack listbox is Tk-only)"
} else {
    group D {
        check "D0 fixture: the Calculator opens and the stack shows the three-entry model, top first" \
            [list [pcall calc::open] [pcall calc::stk_set $::sg_model] \
                  [pcall .calc.stk.list get 0 end]] \
            [list .calc 3 $::sg_model]
        update
        check "D1 fixture: every entry has an on-screen box to click" \
            [list [llength [.calc.stk.list bbox 0]] [llength [.calc.stk.list bbox 1]] \
                  [llength [.calc.stk.list bbox 2]]] {4 4 4}

        # item 7 -- double-click recalls
        sg_typed typed
        sg_click 1 [sg_xy 1]
        check "D2 a SINGLE click on an entry does not recall it (buffer unchanged)" \
            [sg_buf] typed
        sg_typed typed
        sg_dbl [sg_xy 1]
        check "D3 THE USER'S GESTURE: double-clicking entry 2 puts exactly that expression in the buffer, and says so" \
            [list [sg_buf] [sg_status]] [list {-v(b)} [calc::stk_msg recalled 2]]
        check "D4 ...and the stack is not altered: model and listbox both still the three entries, in order" \
            [list [calc::stk_get] [.calc.stk.list get 0 end]] [list $::sg_model $::sg_model]
        set u1 [pcall .calc.buf edit undo]
        set b1 [sg_buf]
        check "D5 the recall is ONE undo step: one Undo restores what the user had typed" \
            [list [string match ERR:* $u1] $b1] {0 typed}
        sg_typed typed
        sg_dbl [sg_xy 1]
        sg_click 1 [sg_xy 1] 60
        set u1 [pcall .calc.buf edit undo]
        check "D5b a TRIPLE-click recalls once: still one Undo back to what the user had typed" \
            [list [string match ERR:* $u1] [sg_buf]] {0 typed}
        sg_typed typed
        sg_dbl [sg_xy 2]
        check "D6 double-clicking the bottom entry recalls the bottom entry (not the top, not the nearest-to-something)" \
            [sg_buf] [lindex $::sg_model 2]
        sg_typed typed
        set st [calc::status {}]
        sg_dbl [sg_below]
        check "D7 double-clicking the empty area BELOW the last entry recalls nothing, leaves the stack alone, and says why" \
            [list [sg_buf] [calc::stk_get] [sg_status]] \
            [list typed $::sg_model [calc::stk_msg norecall]]

        # item 8 -- right-click menu copies
        clipboard clear
        clipboard append STALE
        sg_click 3 [sg_xy 0]
        set m .calc.stk.menu
        set posted [expr {[winfo exists $m] && [winfo ismapped $m]}]
        set lbl {}
        if {[winfo exists $m]} { catch {set lbl [$m entrycget 0 -label]} }
        set sel [.calc.stk.list curselection]
        check "D8 THE USER'S GESTURE: right-clicking entry 1 posts a context menu whose entry is Copy, and selects the entry it was posted for" \
            [list $posted $lbl $sel] {1 Copy 0}
        set inv [pcall $m invoke Copy]
        sg_unpost
        check "D9 Copy puts exactly that expression on the clipboard, REPLACING what was there, and says so" \
            [list [pcall clipboard get] [sg_status]] [list [lindex $::sg_model 0] [calc::stk_msg copied 1]]
        sg_click 3 [sg_xy 1]
        pcall $m invoke Copy
        sg_unpost
        check "D10 an entry starting with '-' (a negated operand) is copied verbatim" \
            [pcall clipboard get] {-v(b)}
        sg_click 3 [sg_xy 2]
        pcall $m invoke Copy
        sg_unpost
        check "D11 the bottom entry copies the bottom entry" \
            [pcall clipboard get] [lindex $::sg_model 2]
        check "D12 ...and none of the copies altered the stack or the buffer" \
            [list [calc::stk_get] [.calc.stk.list get 0 end] [sg_buf]] \
            [list $::sg_model $::sg_model typed]
        clipboard clear
        clipboard append STALE
        sg_click 3 [sg_below]
        set posted [expr {[winfo exists $m] && [winfo ismapped $m]}]
        sg_unpost
        check "D13 right-clicking the empty area below the last entry posts no menu, leaves the clipboard alone, and says why" \
            [list $posted [pcall clipboard get] [sg_status]] \
            [list 0 STALE [calc::stk_msg nocopy]]

        # the open ruling stays open
        set inert {}
        foreach id {push pop del recall} {
            lappend inert [string match {calc::inert *} [.calc.stk.$id cget -command]]
        }
        check "D14 the four stack side buttons still run calc::inert (their behaviour is the user's open ruling)" \
            $inert {1 1 1 1}
        catch {calc::stk_set {}}
        catch {calc::close}
    }
}

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
