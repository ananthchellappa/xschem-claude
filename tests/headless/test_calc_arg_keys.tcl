## test_calc_arg_keys.tcl -- a choice field in a measurement's argument dialog
## takes its value from the keyboard by first letter (calc_feedback_batch item 5).
##
## The user's words, verbatim (doc/claude/calc_feedback_batch/BATCH.md):
##   "In the dialog for settlingTime, when one uses TAB key to move to one of the
##    dropdown entries (time/value), it should be possible to press t or v key to
##    select one or the other."
##
## WHAT THE CONTROL IS.  Every `enum` field of every argument dialog is built by
## ONE builder, `calc::arg_dialog_build`, as a readonly ttk::combobox -- and a
## readonly ttk::combobox does not type-to-select by itself.  So the fix is made
## once, in that builder, and reaches every dialog: settlingTime's two
## `value/time` fields, the edge fields (rising/falling/either), the X-axis
## fields (start/number/mid), the gain and response fields.
##
## THE DECISION AND THE ACT ARE SPLIT.  `calc::choice_pick` is pure (a value
## list, the current value and one character in; the value to select or {} out)
## so band P gates it on BOTH arms; `calc::choice_key` is the binding's act and
## band K drives it with REAL key events on the display arm.
##
## THE BINDING MUST NOT EAT THE KEYS IT DOES NOT USE.  The house helper's
## `<Key> {...; break}` shape is fine on the Calculator's own comboboxes, which
## are `-takefocus 0`; on a dialog field it would swallow Tab (traversal is an
## `all`-tag binding), Return (OK) and Escape (Cancel), which are toplevel
## bindings.  Band K drives all three through the focused combobox.
##
## DECLARED LIMITS: the popdown listbox is not driven (posting it takes a grab);
## a modified letter (Control, Alt) selects nothing, by design.
##
## Arms: band P on both; band K needs Tk and announces itself SKIPPED under
## --nogui.  Registered in BOTH hcases and dcases.

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
proc atleast {n k} { if {[string is integer -strict $n] && $n >= $k} { return "atleast$k" } ; return "only:$n" }

source [file join [file dirname [info script]] scratch.tcl]

# --- band P: the pure decision, both arms ------------------------------------
group P {
    check "P0 calc::choice_pick takes exactly {values current ch} (info args)" \
        [pcall info args calc::choice_pick] {values current ch}
    check "P1 t and v pick time and value from {value time}, whichever is current" \
        [list [pcall calc::choice_pick {value time} value t] \
              [pcall calc::choice_pick {value time} time v] \
              [pcall calc::choice_pick {value time} time t] \
              [pcall calc::choice_pick {value time} value v]] \
        {time value time value}
    check "P2 the letter is case-blind (T, V, D for dB, d for dB)" \
        [list [pcall calc::choice_pick {value time} value T] \
              [pcall calc::choice_pick {value time} time V] \
              [pcall calc::choice_pick {magnitude dB} magnitude D] \
              [pcall calc::choice_pick {magnitude dB} magnitude d]] \
        {time value dB dB}
    check "P3 two values sharing a first letter are CYCLED from the current one, and a current value not in the list starts from the first" \
        [list [pcall calc::choice_pick {alpha beta apple} alpha a] \
              [pcall calc::choice_pick {alpha beta apple} apple a] \
              [pcall calc::choice_pick {alpha beta apple} beta a] \
              [pcall calc::choice_pick {alpha beta apple} {} b]] \
        {apple alpha apple beta}
    check "P4 no match, an empty list, a control character, whitespace, punctuation and a multi-character string all answer {}" \
        [list [pcall calc::choice_pick {value time} value x] \
              [pcall calc::choice_pick {} {} t] \
              [pcall calc::choice_pick {value time} value "\t"] \
              [pcall calc::choice_pick {value time} value "\x1b"] \
              [pcall calc::choice_pick {value time} value " "] \
              [pcall calc::choice_pick {value time} value "-"] \
              [pcall calc::choice_pick {value time} value "tv"] \
              [pcall calc::choice_pick {value time} value {}]] \
        {{} {} {} {} {} {} {} {}}
}

# --- band K: real key events in the real dialog -------------------------------
proc k_press {w ks {state 0}} {
    event generate $w <KeyPress> -keysym $ks -state $state
    if {[winfo exists $w]} { event generate $w <KeyRelease> -keysym $ks -state $state }
    update idletasks
}
proc k_combos {} {
    set out {}
    foreach c [winfo children .calc.arg.f] {
        if {[winfo class $c] eq {TCombobox}} { lappend out $c }
    }
    return [lsort -dictionary $out]
}
proc k_focus {w} {
    focus -force $w
    update
    return [focus]
}

if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "SKIPPED: band K (no X: the argument dialog is Tk-only)"
} else {
    group K {
        check "K0 fixture: the Calculator opens and the settlingTime dialog builds" \
            [list [pcall calc::open] [pcall calc::arg_dialog_build settlingTime]] \
            {.calc .calc.arg}
        update
        set cb [k_combos]
        check "K1 fixture: settlingTime's dialog carries exactly two combobox fields, bound to initfrom and finalfrom, both opening on value" \
            [list [llength $cb] \
                  [lmap c $cb {$c cget -textvariable}] \
                  [lmap c $cb {$c get}]] \
            {2 {::calc::argval(initfrom) ::calc::argval(finalfrom)} {value value}}
        lassign $cb ci cf
        check "K2 fixture: the initfrom combobox takes keyboard focus" \
            [k_focus $ci] $ci
        k_press $ci t
        set a [list [$ci get] $::calc::argval(initfrom) [$cf get]]
        k_press $ci v
        lappend a [$ci get] $::calc::argval(initfrom)
        k_press $ci T
        lappend a [$ci get]
        check "K3 THE USER'S GESTURE: with focus on 'Initial is a', t selects time (the field's variable follows, the other field does not), v selects value, T selects time" \
            $a {time time value value value time}
        k_focus $cf
        k_press $cf t
        check "K4 the same on 'Final is a'" \
            [list [$cf get] $::calc::argval(finalfrom)] {time time}
        k_focus $ci
        k_press $ci x
        set b [list [$ci get]]
        k_press $ci t 4
        lappend b [$ci get]
        k_press $ci v 8
        lappend b [$ci get]
        check "K5 a letter matching no value, Control-t and Alt-v all leave the field alone" \
            $b {time time time}

        # traversal: the next field in grid order is the entry below
        set rows {}
        foreach c [winfo children .calc.arg.f] {
            if {[string match {*.v[0-9]*} $c]} { lappend rows $c }
        }
        set rows [lsort -dictionary $rows]
        set nexti [lindex $rows [expr {[lsearch -exact $rows $ci] + 1}]]
        check "K6 fixture: the field after 'Initial is a' is the 'Final' entry" \
            [list [winfo class $nexti] [$nexti cget -textvariable]] \
            {Entry ::calc::argval(final)}
        k_focus $ci
        k_press $ci Tab
        update
        check "K7 TAB STILL TRAVERSES: Tab on the focused combobox moves focus to the next field, and its value is untouched" \
            [list [focus] [$ci get]] [list $nexti time]

        # Return reaches OK: the required fields are empty, so it refuses in
        # the dialog's own line and the dialog stays up
        set ::calc::argmsg {}
        k_focus $ci
        k_press $ci Return
        update
        check "K8 RETURN STILL REACHES OK through the focused combobox: the dialog refuses its empty required fields in its own line and stays up" \
            [list [expr {$::calc::argmsg ne {}}] [winfo exists .calc.arg]] {1 1}
        set ::calc::arg_result POISON
        k_focus $ci
        k_press $ci Escape
        update
        check "K9 ESCAPE STILL REACHES CANCEL through the focused combobox: the dialog is gone and the answer is empty" \
            [list [winfo exists .calc.arg] $::calc::arg_result] {0 {}}

        # every enum field of every dialog, derived
        set nverb 0; set ncombo 0; set npress 0; set miss {}; set shape {}
        foreach r [calc::catalogue] {
            set n [lindex $r 0]
            set enums {}
            foreach f [calc::fn_argspec $n] {
                if {[lindex $f 2 0] eq {enum}} { lappend enums [lrange [lindex $f 2] 1 end] }
            }
            if {![llength $enums]} continue
            incr nverb
            if {[pcall calc::arg_dialog_build $n] ne {.calc.arg}} { lappend miss "$n:nodialog"; continue }
            update
            set cbs [k_combos]
            if {[llength $cbs] != [llength $enums]} { lappend shape "$n:[llength $cbs]/[llength $enums]" }
            foreach c $cbs {
                incr ncombo
                k_focus $c
                set vals [$c cget -values]
                foreach v $vals {
                    set got 0
                    for {set k 0} {$k < [llength $vals]} {incr k} {
                        incr npress
                        k_press $c [string index $v 0]
                        if {[$c get] eq $v} { set got 1; break }
                    }
                    if {!$got} { lappend miss "$n:$c:$v" }
                }
            }
            catch {destroy .calc.arg}
        }
        check "K10 EVERY enum field of EVERY verb that opens a dialog (derived from calc::catalogue x calc::fn_argspec) reaches EVERY one of its values by pressing that value's first letter; verb, field and press counts ride along" \
            [list [lrange $miss 0 7] [llength $miss] $shape \
                  [atleast $nverb 8] [atleast $ncombo 12] [atleast $npress 30]] \
            [list {} 0 {} atleast8 atleast12 atleast30]
        catch {destroy .calc.arg}
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
