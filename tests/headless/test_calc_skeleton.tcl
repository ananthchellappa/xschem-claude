# Calculator phase 0 — the skeleton and its dividers.
# Spec doc/claude/specs/calculator.md §4; plan doc/claude/calculator_batch/PLAN.md
# steps 0.1-0.10.
#
#   S1   calc::open builds .calc; a second call raises rather than duplicating
#        (spec R101)
#   S2   the menubar carries exactly the six reference cascades, every entry
#        disabled (phase 0 owns layout, not behaviour)
#   S3   the pane tree exists with the right classes and orientations
#   S4   every pane is a managed child of its panedwindow, with the -minsize
#        the plan specifies (landmine D3: a pane with no minsize collapses to
#        zero and cannot be dragged back)
#   S5   -stretch is applied where the plan says, when Tk supports it
#   S6   four sashes exist and report coordinates
#   S7   the status bar is NOT inside the panes — a status line that moved when
#        a sash dragged would be a bug
#   S8   a sash drag is captured by save_layout and reproduced by
#        restore_layout (the round trip that makes the layout persist)
#   S9   landmine D4: a saved coordinate that no longer fits the current window
#        is SKIPPED, not clamped — otherwise one small-screen session silently
#        rewrites the layout for every later one
#   S10  calc::close tears the window down and leaves nothing behind
#
# Needs a DISPLAY (Tk widgets). Under Xvfb set GUI_GATE=0. Standalone:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_calc_skeleton.tcl

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

if {![info exists ::has_x] || [info commands winfo] eq {}} {
    puts "calc skeleton legs skipped (no DISPLAY)"
    puts "RESULT: ALL PASS (0 checks)"
    flush stdout
    exit 0
}

if {[catch {

# --- S1 open / raise-or-open -------------------------------------------------
check "S1 open returns .calc"      [calc::open] .calc
update idletasks
check_true "S1 toplevel exists"    [winfo exists .calc]
check "S1 class"                   [winfo class .calc] Toplevel
check "S1 title"                   [wm title .calc] {xschem Calculator}
# R101: a second open must raise the existing window, not build a second one
set before [llength [winfo children .]]
check "S1 second open is raise"    [calc::open] .calc
check "S1 no duplicate toplevel"   [llength [winfo children .]] $before

# --- S2 menubar --------------------------------------------------------------
check_true "S2 menubar exists"     [winfo exists .calc.mbar]
check "S2 menu attached"           [.calc cget -menu] .calc.mbar
set labels {}
for {set i 0} {$i <= [.calc.mbar index end]} {incr i} {
    if {[.calc.mbar type $i] eq {cascade}} {
        lappend labels [.calc.mbar entrycget $i -label]
    }
}
check "S2 six cascades" $labels {File Tools View Options Constants Help}
set enabled 0
foreach sub {file tools view options constants help} {
    for {set i 0} {$i <= [.calc.mbar.$sub index end]} {incr i} {
        if {[.calc.mbar.$sub type $i] ne {separator}
            && [.calc.mbar.$sub entrycget $i -state] ne {disabled}} { incr enabled }
    }
}
check "S2 every entry disabled" $enabled 0

# --- S3 pane tree ------------------------------------------------------------
foreach {path cls} {
    .calc.pw          Panedwindow
    .calc.pw.sel      Labelframe
    .calc.pw.buf      Labelframe
    .calc.pw.stk      Labelframe
    .calc.pw.bot      Panedwindow
    .calc.pw.bot.fn   Labelframe
    .calc.pw.bot.pad  Labelframe
} {
    check "S3 $path class" [expr {[winfo exists $path] ? [winfo class $path] : {MISSING}}] $cls
}
check "S3 outer orient" [.calc.pw     cget -orient] vertical
check "S3 inner orient" [.calc.pw.bot cget -orient] horizontal

# --- S4 panes are managed, with their minsizes -------------------------------
check "S4 outer panes" [.calc.pw panes] \
    {.calc.pw.sel .calc.pw.buf .calc.pw.stk .calc.pw.bot}
check "S4 inner panes" [.calc.pw.bot panes] {.calc.pw.bot.fn .calc.pw.bot.pad}
foreach {pw pane min} {
    .calc.pw     .calc.pw.sel      120
    .calc.pw     .calc.pw.buf       70
    .calc.pw     .calc.pw.stk       80
    .calc.pw     .calc.pw.bot      140
    .calc.pw.bot .calc.pw.bot.fn   250
    .calc.pw.bot .calc.pw.bot.pad  140
} {
    check "S4 $pane -minsize" [$pw panecget $pane -minsize] $min
}

# --- S5 -stretch, where Tk has it -------------------------------------------
if {![catch {.calc.pw panecget .calc.pw.sel -stretch}]} {
    foreach {pw pane want} {
        .calc.pw     .calc.pw.sel     never
        .calc.pw     .calc.pw.buf     always
        .calc.pw     .calc.pw.stk     always
        .calc.pw     .calc.pw.bot     always
        .calc.pw.bot .calc.pw.bot.fn  always
        .calc.pw.bot .calc.pw.bot.pad never
    } {
        check "S5 $pane -stretch" [$pw panecget $pane -stretch] $want
    }
} else {
    puts "note: Tk without panedwindow -stretch; S5 skipped"
}

# --- S6 four sashes ----------------------------------------------------------
set nsash 0
foreach {pw n} {.calc.pw 3 .calc.pw.bot 1} {
    for {set i 0} {$i < $n} {incr i} {
        if {![catch {$pw sash coord $i} c] && [llength $c] == 2} { incr nsash }
    }
}
check "S6 four sashes report coords" $nsash 4

# --- S7 the status bar is outside the panes ---------------------------------
check_true "S7 status exists"      [winfo exists .calc.status]
check "S7 status parent"           [winfo parent .calc.status] .calc
check_true "S7 status not a pane" \
    [expr {[lsearch -exact [.calc.pw panes] .calc.status] < 0}]

# --- S8 sash drag round trip -------------------------------------------------
# Make the window big enough that a moved sash is inside the D4 guard band.
wm geometry .calc 700x800
update idletasks
set c0 [.calc.pw sash coord 0]
set y0 [lindex $c0 1]
set target [expr {$y0 + 30}]
eval .calc.pw sash mark 0 $c0
eval .calc.pw sash dragto 0 [list [lindex $c0 0] $target]
update idletasks
set moved [lindex [.calc.pw sash coord 0] 1]
check_true "S8 sash actually moved" [expr {$moved != $y0}]
calc::save_layout
check "S8 save_layout captured it" $calc::sash(.calc.pw,0) $moved
# put it back, then restore and confirm the saved value returns
eval .calc.pw sash mark 0 [.calc.pw sash coord 0]
eval .calc.pw sash dragto 0 [list [lindex $c0 0] $y0]
update idletasks
check_true "S8 sash reset"          [expr {[lindex [.calc.pw sash coord 0] 1] == $y0}]
calc::restore_layout
update idletasks
check "S8 restore_layout reproduced it" [lindex [.calc.pw sash coord 0] 1] $moved

# --- S9 landmine D4: an unfittable saved value is skipped, not clamped -------
# Poison the saved coordinate with a value from an imaginary tall window. A
# clamping restore would silently rewrite the layout; the contract is to leave
# Tk's own distribution alone for that sash.
set keep $calc::sash(.calc.pw,0)
set calc::sash(.calc.pw,0) 100000
set before_y [lindex [.calc.pw sash coord 0] 1]
calc::restore_layout
update idletasks
check "S9 oversize saved sash ignored" [lindex [.calc.pw sash coord 0] 1] $before_y
set calc::sash(.calc.pw,0) -5
calc::restore_layout
update idletasks
check "S9 negative saved sash ignored" [lindex [.calc.pw sash coord 0] 1] $before_y
set calc::sash(.calc.pw,0) $keep

# --- S10 close ---------------------------------------------------------------
calc::close
update idletasks
check_true "S10 toplevel gone"   [expr {![winfo exists .calc]}]
check_true "S10 reopens cleanly" [expr {[calc::open] eq {.calc}}]

# --- S11 first-open proportions ---------------------------------------------
# With nothing saved, the panes must open in the reference proportions, not
# Tk's even split. Clearing the saved array is what a first-ever open looks
# like from restore_layout's point of view.
wm geometry .calc 700x800
update idletasks
array unset ::calc::sash
calc::restore_layout
update idletasks
set H [winfo height .calc.pw]
set y0 [lindex [.calc.pw sash coord 0] 1]
check_true "S11 default sash0 near 21% of $H" [expr {abs($y0 - 0.21 * $H) < 14}]
set y2 [lindex [.calc.pw sash coord 2] 1]
check_true "S11 default sash2 near 64% of $H" [expr {abs($y2 - 0.64 * $H) < 14}]
set W  [winfo width .calc.pw.bot]
set x0 [lindex [.calc.pw.bot sash coord 0] 0]
check_true "S11 default bot sash near 78% of $W" [expr {abs($x0 - 0.78 * $W) < 14}]
# and an even split would have failed those, so assert the negative too
check_true "S11 not an even split" [expr {abs($y0 - $H / 4.0) > 20}]

calc::close

} bigerr]} {
    puts "UNEXPECTED ERROR: $bigerr"
    incr fail
}

if {$fail == 0} {
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
