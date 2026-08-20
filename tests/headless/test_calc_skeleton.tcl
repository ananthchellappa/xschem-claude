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
#   S11  first-open sash proportions (not Tk's even split)
#   S12  landmine D6, forced deterministically rather than hoped for
#
# Phase 1a (item 1) adds:
#   S13  calc::color — the palette accessor.  Every role resolves, none to the
#        empty string, and each one equals the SIGNAL BROWSER's own definition
#        (ase::palette, or the startup option database for disabledfg) rather
#        than a copy of it.  Resolving the palette must also be a PURE READ:
#        it must not create ASE's fonts or change any other window's combobox.
#        Spec R113 as amended by RULING-1.
#   S14  the chrome actually wears it: toplevel, the five labelframes (panel
#        background + accent title), the panedwindows and the status bar — and
#        none of them is still the stock grey the user rejected
#   S15  the Results Dir row (W03-W05): the normative path .calc.res packed
#        INTO .calc.pw.sel and mapped, the readonly path entry, the
#        no-raw-loaded wording, the disabled Browse stub, the collapse toggle
#   S16  the status area (W32-W34) and calc::status's contract (R506-R509):
#        readonly + initially empty, prepend, the 50-entry cap dropping the
#        OLDEST, empty string clears without recording, no window is a silent
#        no-op, recall re-displays without re-recording
#
# Phase 1b (item 2) adds, and restates three phase-1a checks whose subject the
# filled panes changed (each marked ⚠ RESTATED where it stands):
#   S17  the 22-button selector grid (W06-W07, spec §5): the exact two rows in
#        three visual groups, the eight rendered-and-disabled ids (§1.2), their
#        tooltips, and that they cannot be armed by invoke OR by a click (R202)
#   S18  the mode strip (W08-W14): pick scope on ::calc::pickscope initially
#        off, Clip initially ON, the plot/evaluate/table buttons and the
#        destination combobox's three values
#   S19  the buffer (W15) and its toolbar (W16-W22): typing works, undo/redo
#        are created disabled, and no button touches the buffer or the stack
#   S20  the Stack (W23-W25): the labelframe, the listbox and the four side
#        buttons — all inert, all speaking
#   S21  what a cget cannot see: the FIRST-OPEN layout (every widget gets at
#        least the size it asked for; the buffer draws all four of its lines)
#        and the toplevel's own declared minimum (all 22 selectors still on
#        screen at it, and a window saved too small is corrected on reopen)
#
# Phase 1d (item 4) adds, and restates one phase-1a/1b check whose subject the
# last two filled panes removed (⚠ RESTATED, in place):
#   S22  the keypad (W29-W31): the twelve operator keys the crew ruled under
#        RULING-2 and NO digit key, the four user buttons, all inert and all
#        speaking, and the -minsize this item was sent to re-judge
#   S23  the function browser (W26-W28): the category combobox, the canvas
#        list in six column-major columns with a scrollbar that really scrolls,
#        the greyed N-route/out-of-scope entries (RULING-3), per-entry hover
#        help that does NOT flood the history, and repopulation on a switch
#   S24  the catalogue (R413, one table): arity, categories, the §3.2 token set
#        written out from the SPEC, every emitted token lexable, the audited
#        defects D1/D2/D3/D6, and no duplicate names
#
# Item 13 (the phase-1 eyeball punch-list) adds:
#   S25  the wheel scrolls under the POINTER, not only over a scrollbar: every
#        widget of all three scrollable regions is bound (the house walk,
#        xschem.tcl:1589, comboboxes excluded), each aimed at its own target
#        with Tk's own step; the gestures fire over a CHILD that is not the
#        target and has no wheel class binding of its own; direction, the
#        Shift horizontal axis, the <MouseWheel> arm, and that each binding
#        `break`s so one notch is not scrolled twice
#   S26  the Results Dir row answers about the result the USER is looking at:
#        a waveform viewer's context through the 0173 loan, with a refused
#        ticket skipped and the loan given back, and the label SAYS whose it
#        is. R705: nothing cached.
#        ⚠ RESTATED by results batch item 10 — it used to pin `self -> viewer
#        -> ase -> none`; the `self` arm was removed by the user (U6) and the
#        `ase` arm's derived-path source by crew ruling R502a, and the borrowed
#        read now asks `results::current` rather than `xschem raw rawfile`.
#        The reasons are at the head of the block itself.
#
# Results batch item 10 (doc/claude/results_batch/PLAN.md §1) adds, and restates
# three legs of S15 and one of S18 in place:
#   S27  the Results Dir row PICKS: ONE resolution feeds both the row and
#        Evaluate (U3/T-I), Evaluate with no result refuses in the ruled words
#        and does not offer to launch ASE-L (U7), a REFUSED loan is reported as
#        refused rather than as "no results" (T-J), the read is a loan that is
#        given back and the Calculator selects nothing (U8), and `Browse` is
#        permanently inert with the reason in the code (U9)
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

# ⚠ BEFORE THE CALCULATOR IS EVER OPENED, and before anything in this file has
# called ase::theme.  These two values are the baseline for S13's purity checks
# and they can only be taken here: ase::theme's side effects are one-way and
# permanent — it creates AseLabelFont/AseEntryFont/AseMonoFont and does a global
# `option add *TCombobox*Listbox.font AseEntryFont` (ase_window.tcl:159-171)
# which changes the dropdown font of EVERY ttk::combobox in xschem (33 call
# sites), including ones that already exist, because a popdown listbox is built
# lazily.  Reading a COLOUR must not do that, so calc::color goes through the
# side-effect-free ase::palette.  Taking the baseline after S1 would measure the
# leak as if it were the normal state.
# ⚠ .calccbprobe.cb's popdown is deliberately NOT materialised here.  The
# option database is consulted when the popdown LISTBOX is created, which ttk
# does lazily on the first post — so a combobox that already existed when the
# leak happened still flips.  Materialising it now would freeze its font and
# make S13's check on it vacuous.  .calccbprobe.ref is the throwaway that
# supplies the stock value.
proc cbfont {w} {
    if {[catch {[ttk::combobox::PopdownWindow $w].f.l cget -font} r]} { return "ERR:$r" }
    return $r
}
toplevel .calccbprobe
ttk::combobox .calccbprobe.cb  -values {aaa bbb}
ttk::combobox .calccbprobe.ref -values {aaa bbb}
set stock_cbfont [cbfont .calccbprobe.ref]
set ase_font_at_start [expr {[lsearch -exact [font names] AseEntryFont] >= 0}]

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
# ⚠ .calc.pw.bot's number is 158, NOT phase 0's 140, and this is the second
# sanctioned amendment to a frozen phase-0 minsize (the first was the keypad
# pane, re-judged by item 4 and unchanged at 140). Filling the bottom pair took
# .calc.pw.bot's REQUESTED height from 67 to 158 while its -minsize stayed at
# the placeholder-era 140, so dragging the bottom sash to its own legal floor
# gave the pane 140 and clipped `user 3`/`user 4` by 3 px — a pane whose stated
# minimum hides a control, which is the exact thing landmine D3's -minsize
# exists to prevent. calc::apply_pane_minsize now raises the two panes item 4
# filled to what their contents request; 140 remains the FLOOR in build_panes
# and nothing can lower a minimum below it. The number below is the derived
# value at the shipped font — S22's leg carries the font-independent form
# (-minsize >= the pane's own requested size), which is what actually pins the
# rule.
foreach {pw pane min} {
    .calc.pw     .calc.pw.sel      120
    .calc.pw     .calc.pw.buf       70
    .calc.pw     .calc.pw.stk       80
    .calc.pw     .calc.pw.bot      158
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

# --- S12 landmine D6, forced rather than hoped for ---------------------------
# The clobber needs a save_layout to run INSIDE a restore. Who delivers that
# depends entirely on the display: on :0 the window manager's Configure traffic
# does it (measured: save_layout is entered twice per restore_layout), while
# under Xvfb it is zero — with or without openbox, because openbox reparents and
# honours iconify but does not generate WSLg's extra asynchronous Configures.
# So the environment cannot be trusted to produce the race, and a guard that is
# only exercised on one developer's display is not covered at all.
#
# Force it instead: wrap the restore body so a real save_layout attempt lands
# while calc::restoring is set — precisely what a mid-restore Configure does —
# and assert the restore still applies the value it was asked to apply.
wm geometry .calc 700x800
update idletasks
set c0     [.calc.pw sash coord 0]
set y0     [lindex $c0 1]
set target [expr {$y0 + 30}]
eval .calc.pw sash mark 0 $c0
eval .calc.pw sash dragto 0 [list [lindex $c0 0] $target]
update idletasks
calc::save_layout
set saved $::calc::sash(.calc.pw,0)
check_true "S12 fixture: sash moved and captured" [expr {$saved != $y0}]
# put the sash back, so a restore that does nothing is visibly distinguishable
eval .calc.pw sash mark 0 [.calc.pw sash coord 0]
eval .calc.pw sash dragto 0 [list [lindex $c0 0] $y0]
update idletasks

rename calc::restore_layout_body calc::_s12_orig_body
proc calc::restore_layout_body {} {
    calc::save_layout          ;# the mid-restore <Configure>, made deterministic
    calc::_s12_orig_body
}
set s12err [catch {calc::restore_layout} s12msg]
rename calc::restore_layout_body {}
rename calc::_s12_orig_body calc::restore_layout_body
update idletasks
check "S12 restore survived a mid-restore save (no error)" $s12err 0
check "S12 mid-restore save did not clobber" [lindex [.calc.pw sash coord 0] 1] $saved

calc::close

# =============================================================================
# PHASE 1a
# =============================================================================

# error-guarded call: a sabotage that makes the code under test THROW would
# otherwise hit the outer catch and delete every remaining check
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }

# ⚠ A TK BUTTON UNDER THE POINTER READS BACK `active`, NOT `normal` — FIXER
# ROUND, results batch item 10 (2026-08-20). `-state active` is Tk's HOVER
# state (set by the class <Enter> binding), not a widget-state defect, and on
# the dev display :99 the pointer stays wherever the PREVIOUS suite left it. A
# reviewer measured it deterministically 3/3: after
# `run_suites.sh test_results_dialog test_waves_gate test_results_select
# test_wave_viewer` the pointer sat at (1309,463) and `S17 exactly the 7 RF ids
# and mp are disabled` reported `{var=active}`; warping the pointer to (6,340)
# and re-running the SAME unmodified file gave ALL PASS. It reds at HEAD too
# (with `{vt=active}`), so it is not this item's edit — but a check whose
# PASS/FAIL depends on where the mouse happens to sit is not evidence, and it
# is not on the batch's known-flake list.
#
# So every sweep that asks "is this button enabled?" asks it through here.
# `disabled` is unaffected (Tk never makes a disabled widget active), so the
# only thing collapsed is the enabled/hovered distinction — which no check in
# this file is about.
# a dict read that cannot ABORT the file. `dict get` on a key the code under
# test never wrote THROWS, which would hit the outer catch and delete every
# remaining check — so the reviewer's own sabotage recipe for the slot-identity
# legs ("make the key not exist") would have been unreadable. It must red the
# check that asked for the key, and nothing else.
proc dg {d k} { if {[catch {dict get $d $k} v]} { return NO-SUCH-KEY } ; return $v }

proc btnstate {w} {
    set st [pcall $w cget -state]
    if {$st eq {active}} { return normal }
    return $st
}

# --- S13 the palette accessor (spec R113 / RULING-1) -------------------------
# .calc does not exist here (S12 closed it), which is deliberate: the palette
# must resolve without a window, and R508's no-window no-op is testable now.
check_true "S13 no window open" [expr {![winfo exists .calc]}]

# The purity baseline was taken at the top of this file, before S1 opened the
# Calculator for the first time — see the note there.  S1-S12 have since opened
# and closed the window twelve times over, which is precisely the exposure this
# guards: one open must not have imposed ASE's fonts on the application.
check_true "S13 no ASE font existed before the Calculator was opened" \
    [expr {!$ase_font_at_start}]
check_true "S13 opening the Calculator created no ASE font" \
    [expr {[lsearch -exact [font names] AseEntryFont] < 0}]

set roles [pcall calc::color_roles]
check "S13 roles" $roles {window panel header field accent fieldfg selectbg selectfg disabledfg}
set empties {}
foreach r $roles {
    set v [pcall calc::color $r]
    if {$v eq {} || [string match ERR:* $v]} { lappend empties $r }
}
check "S13 every role resolves non-empty" $empties {}
# a typo must not silently paint a widget stock grey
check_true "S13 unknown role errors, a known one does not" \
    [expr {![string match ERR:* [pcall calc::color panel]]
           && [string match ERR:* [pcall calc::color nosuchrole]]}]

# Resolving the whole palette must also have created nothing and changed
# nothing outside this window — for a combobox that existed before the
# Calculator did, and for one created after it.
check_true "S13 the stock dropdown font was readable at baseline" \
    [expr {$stock_cbfont ne {} && ![string match ERR:* $stock_cbfont]}]
check "S13 a combobox that predates the Calculator keeps its dropdown font" \
    [cbfont .calccbprobe.cb] $stock_cbfont
pcall ttk::combobox .calccbprobe.cb2 -values {aaa bbb}
check "S13 a combobox created after it keeps the stock dropdown font" \
    [cbfont .calccbprobe.cb2] $stock_cbfont

# Each role is READ BACK from the signal browser's own definition. These are
# not "the same literal" checks: if ase::palette moves, both sides move
# together and these stay green; if calc::color ever hardcodes a value, they go
# red the moment the browser changes. (RULING-1: reuse the variables.)
#
# ⚠ ase::palette, NOT ase::theme, and NOT `ttk::style lookup Ase.Treeview ...`.
# `lookup` falls through the style name chain to ttk's ROOT style when the
# named style does not set the option, so the three roles that used it were
# reading the ambient ttk theme and `ttk::style lookup NoSuchStyle.Treeview
# -foreground` returned the very same value — a check comparing the two sides
# could not tell the browser's palette from a style that does not exist. The
# "not the ambient ttk default" checks below are the positive control for that.
check "S13 window  = ase::palette panel"  [pcall calc::color window] [pcall ase::palette panel]
check "S13 panel   = ase::palette panel"  [pcall calc::color panel]  [pcall ase::palette panel]
check "S13 header  = ase::palette header" [pcall calc::color header] [pcall ase::palette header]
check "S13 field   = ase::palette table"  [pcall calc::color field]  [pcall ase::palette table]
check "S13 accent  = ase::palette accent" [pcall calc::color accent] [pcall ase::palette accent]
check "S13 fieldfg  = ase::palette fieldfg"  [pcall calc::color fieldfg]  [pcall ase::palette fieldfg]
check "S13 selectbg = ase::palette selectbg" [pcall calc::color selectbg] [pcall ase::palette selectbg]
check "S13 selectfg = ase::palette selectfg" [pcall calc::color selectfg] [pcall ase::palette selectfg]
check "S13 disabledfg = option db disabledForeground" [pcall calc::color disabledfg] \
    [option get . disabledForeground DisabledForeground]

# A role must come from a source that EXISTS. Every role above is read through
# one script; break the source and the role must throw, not quietly substitute
# a plausible literal that renders like the real thing and then never tracks the
# palette again. (The old code had a fallback column for exactly these nine.)
# ⚠ Value equality cannot pin the SOURCE, and it is worth being explicit about
# why. ase::palette's selectbg is the same #4a6984 that ttk's stock Treeview
# map supplies, so re-pointing that role at
# `ttk::style lookup NoSuchBrowser.Treeview -background selected` — a style name
# that does not exist — yields the identical value and every value check above
# stays green (measured: ALL PASS). That is not a hypothetical: it is how the
# three tree-derived roles were written before this suite grew this check, and
# it meant "comes from the signal browser" was untested for a third of the
# palette. So pin the source text: the browser's palette for eight roles, the
# startup option database for disabledfg, and nothing else — no literal, no
# style lookup, no second palette.
set badsrc {}
set srcs [pcall calc::color_sources]
foreach {role src} $srcs {
    if {$role eq {disabledfg}} {
        if {$src ne {option get . disabledForeground DisabledForeground}} {
            lappend badsrc $role
        }
    } elseif {![regexp {^ase::palette [a-z]+$} $src]} {
        lappend badsrc $role
    }
}
check "S13 every role reads the browser's palette, and nothing else" $badsrc {}
check "S13 every role has a source" [lsort [dict keys $srcs]] [lsort $roles]

set defaulted {}
if {[catch {rename ::ase::palette ::calc_test_real_palette}]} {
    set defaulted NO-ase::palette-TO-REMOVE
} else {
    foreach r $roles {
        if {![string match ERR:* [pcall calc::color $r]]} { lappend defaulted $r }
    }
    catch {rename ::calc_test_real_palette ::ase::palette}
}
check "S13 a role with no source throws, it does not default" $defaulted {}
check "S13 the palette resolves again once the source is back" \
    [pcall calc::color accent] [pcall ase::palette accent]

# The accent is the browser's dark red and NOT a literal typed here: assert it
# is what ase::palette says, and separately that it is not the stock foreground.
check_true "S13 accent is the browser's red, not the stock foreground" \
    [expr {[pcall calc::color accent] eq [pcall ase::palette accent]
           && [pcall calc::color accent] ne [option get . foreground Foreground]}]
# ...and the three roles that used to fall through to ttk's own Treeview
# defaults are now the browser's, i.e. ase::theme APPLIES them to Ase.Treeview.
# Without this the browser is not the source, only the name of one.
pcall ase::theme
proc mapval {style opt state} {
    set m [pcall ttk::style map $style $opt]
    if {[string match ERR:* $m] || [llength $m] % 2} { return MAP-UNREADABLE }
    if {![dict exists $m $state]} { return NO-SUCH-STATE }
    return [dict get $m $state]
}
check "S13 the browser applies fieldfg to its own tree style" \
    [pcall ttk::style configure Ase.Treeview -foreground] [pcall ase::palette fieldfg]
check "S13 the browser applies selectbg to its own tree style" \
    [mapval Ase.Treeview -background selected] [pcall ase::palette selectbg]
check "S13 the browser applies selectfg to its own tree style" \
    [mapval Ase.Treeview -foreground selected] [pcall ase::palette selectfg]
# ...and the `disabled` half of that map survived being declared (ttk::style map
# REPLACES a style's map, it does not merge into it), so browser trees still
# grey out. Note `dict get` on an absent key THROWS, so a naive
# `... ne {}` reads the error string as "present" and passes — mapval names it.
check "S13 the tree style kept its disabled foreground" \
    [mapval Ase.Treeview -foreground disabled] \
    [pcall ase::palette disabledfg]
check "S13 the tree style kept its disabled background" \
    [mapval Ase.Treeview -background disabled] \
    [pcall ase::palette disabledbg]

# The point of RULING-1 was that phase 0 was default grey. Pin the departure:
# a freshly built labelframe with no palette is the grey the user rejected, and
# the panel role must not be it.
labelframe .calcstockprobe
set stockbg [.calcstockprobe cget -background]
set stockfg [.calcstockprobe cget -foreground]
destroy .calcstockprobe
check_true "S13 panel is the browser's, and differs from stock grey" \
    [expr {[pcall calc::color panel] eq [pcall ase::theme panel]
           && [pcall calc::color panel] ne $stockbg}]
check_true "S13 field is the browser's, and differs from stock grey" \
    [expr {[pcall calc::color field] eq [pcall ase::theme table]
           && [pcall calc::color field] ne $stockbg}]

# R508, before any window exists at all
check "S13 status with no window is a no-op" [pcall calc::status {before the window}] {}
check "S13 no window records nothing"        [pcall calc::status_history] {}
# R508 also names `--nogui`, where the `winfo` COMMAND does not exist at all.
# This suite always runs under Tk, so that branch is never entered by accident;
# force it. (Measured: deleting the guard left the suite ALL PASS.)
set nogui_ret NO-winfo-TO-REMOVE ; set nogui_hist NO-winfo-TO-REMOVE
if {![catch {rename ::winfo ::calc_test_real_winfo}]} {
    set nogui_ret  [pcall calc::status {a line with no Tk at all}]
    set nogui_hist [pcall calc::status_history]
    catch {rename ::calc_test_real_winfo ::winfo}
}
check "S13 no winfo command is a silent no-op" $nogui_ret  {}
check "S13 no winfo command records nothing"   $nogui_hist {}

# --- S14 the chrome wears the palette ---------------------------------------
# The roles are resolved ONCE, through pcall, into locals: a sabotage that
# makes calc::color throw would otherwise take the outer catch and silently
# delete every check below it (the wvbs_common.tcl:84 rule).
foreach r [list window panel header field fieldfg accent disabledfg \
                selectbg selectfg] {
    set c_$r [pcall calc::color $r]
}
check "S14 open returns .calc" [calc::open] .calc
update idletasks
check "S14 toplevel background" [pcall .calc cget -background] $c_window
foreach lf {.calc.pw.sel .calc.pw.buf .calc.pw.stk .calc.pw.bot.fn .calc.pw.bot.pad} {
    check "S14 $lf background" [pcall $lf cget -background] $c_panel
    # the "coloured accent on panel headers" of the reference screenshot: a
    # labelframe's title text, coloured the way ase::ui::apply_theme colours a
    # Labelframe (ase_window.tcl:195-197)
    check "S14 $lf title accent" [pcall $lf cget -foreground] $c_accent
    check_true "S14 $lf is not stock grey" \
        [expr {[pcall $lf cget -background] ne $stockbg
               && [pcall $lf cget -foreground] ne $stockfg}]
}
# ...and the hint INSIDE it, in every pane THAT STILL HAS ONE. Sampling one
# pane let four panes revert to a literal with the suite green.
#
# ⚠ RESTATED by item 2 (phase 1b), and again by item 4 (phase 1d) — and the
# subject is now GONE, which is why the two per-pane colour checks went with it
# rather than being renumbered around. A placeholder hint is what a pane shows
# INSTEAD of its contents; item 2 filled Selectors, Buffer and Stack, item 4
# filled Functions and Keypad, so no pane has one left and `calc::placeholder`
# itself is deleted. What survives is the half that still has teeth: NO pane may
# carry a hint, which is what stops "filled" from meaning "drawn on top of the
# old placeholder" — the muted-colour checks could only ever have covered a
# widget the window no longer builds.
set leftover {}
foreach lf {.calc.pw.sel .calc.pw.buf .calc.pw.stk .calc.pw.bot.fn .calc.pw.bot.pad} {
    if {[winfo exists $lf.hint]} { lappend leftover $lf }
}
check "S14 a filled pane keeps no placeholder hint" $leftover {}
check "S14 the placeholder proc is gone with its last caller" \
    [expr {[llength [info procs ::calc::placeholder]] ? {STILL-THERE} : {gone}}] gone
# ⚠ ...and every pane still SAYS what it is. Nothing asserted the pane
# captions, so filling a pane could take its title with it — the mirror image
# of the "no second title" check S20 adds for .calc.pw.stk, and measured: with
# `calc::panelframe .calc.pw.sel {}` / `.calc.pw.buf {}` the suite stayed ALL
# PASS with two panes silently uncaptioned. .calc.pw.stk's empty title is the
# crew's item-2 ruling and is pinned here from the positive side too.
set panetitles {}
foreach lf {.calc.pw.sel .calc.pw.buf .calc.pw.stk .calc.pw.bot.fn .calc.pw.bot.pad} {
    lappend panetitles [pcall $lf cget -text]
}
check "S14 the five panes carry their captions" $panetitles \
    {Selectors Buffer {} Functions Keypad}
check "S14 outer panedwindow background" [pcall .calc.pw     cget -background] $c_panel
check "S14 inner panedwindow background" [pcall .calc.pw.bot cget -background] $c_panel
check "S14 status bar background"        [pcall .calc.status cget -background] $c_panel

# The MENUBAR, which had no coverage at all: it can revert to stock grey80 —
# the "visible seam" the code comment says it exists to prevent — with every
# other check green. And a background from the palette with a foreground from
# the startup option database is a legibility BUG, not a half-fix: under
# dark_gui_colorscheme the option database says white, which is invisible on
# this window's light bar. Both halves, on the bar and on all six cascades.
check "S14 menubar background"        [pcall .calc.mbar cget -background] $c_panel
check "S14 menubar foreground"        [pcall .calc.mbar cget -foreground] $c_fieldfg
check "S14 menubar active background" [pcall .calc.mbar cget -activebackground] $c_header
check "S14 menubar active foreground" [pcall .calc.mbar cget -activeforeground] $c_fieldfg
check_true "S14 menubar is not stock grey" \
    [expr {[pcall .calc.mbar cget -background] ne $stockbg}]
set mbadbg {}; set mbadfg {}
foreach sub {file tools view options constants help} {
    if {[pcall .calc.mbar.$sub cget -background] ne $c_panel} { lappend mbadbg $sub }
    if {[pcall .calc.mbar.$sub cget -foreground] ne $c_fieldfg} { lappend mbadfg $sub }
    if {[pcall .calc.mbar.$sub cget -activeforeground] ne $c_fieldfg} { lappend mbadfg $sub! }
}
check "S14 every cascade takes the panel background" $mbadbg {}
check "S14 every cascade takes a palette foreground" $mbadfg {}

# --- S15 the Results Dir row (W03-W05) ---------------------------------------
check "S15 .calc.res class" \
    [expr {[winfo exists .calc.res] ? [winfo class .calc.res] : {MISSING}}] Frame
# W03's path is normative: a CHILD of .calc, not of the pane it is drawn in
check "S15 .calc.res parent is .calc" [pcall winfo parent .calc.res] .calc
# ...and plan 1.1 puts it inside the Selectors pane, above where the selector
# grid lands in item 2. pack -in does both; the ORDER is the assertion.
# ⚠ RESTATED by item 2: the selector grid and the mode strip have landed, so
# the pane's slaves are the three rows of the reference in reading order and
# the placeholder hint is gone. The assertion is unchanged in kind — the
# Results Dir row is still FIRST — and it is now also what pins the grid above
# the mode strip.
check "S15 packed into the Selectors pane, first" \
    [pcall pack slaves .calc.pw.sel] {.calc.res .calc.sel .calc.mode}
# mapped at all: catches "never packed"
check_true "S15 row is mapped" \
    [expr {[winfo exists .calc.res] && [winfo ismapped .calc.res]}]
# ⚠ ...and `winfo ismapped` is ALL that check does. It returns 1 for a widget
# that is mapped and completely OBSCURED, so it cannot see the landmine it was
# once advertised to guard: a widget packed into a non-parent maps BEHIND its
# siblings unless it was created after them, and changing `raise .calc.res` to
# `lower .calc.res` made the whole Results Dir row invisible behind .calc.pw
# with the suite at ALL PASS (measured, 144 checks). These two see it.
#
# `winfo children` is documented as bottom-to-top STACKING order, so the row
# must come after the panedwindow it is drawn on top of.
set kids [pcall winfo children .calc]
check_true "S15 row stacks above the panedwindow" \
    [expr {[lsearch -exact $kids .calc.res] > [lsearch -exact $kids .calc.pw]
           && [lsearch -exact $kids .calc.res] >= 0}]
# ...and the pixel-level version of the same thing: whatever is drawn at the
# row's own centre must BE the row. (Returns .calc.pw.sel when it is lowered.)
update
set resat NO-ROW
catch {
    set rescx [expr {[winfo rootx .calc.res] + [winfo width  .calc.res] / 2}]
    set rescy [expr {[winfo rooty .calc.res] + [winfo height .calc.res] / 2}]
    set resat [winfo containing $rescx $rescy]
}
check_true "S15 row is the topmost widget at its own centre" \
    [expr {$resat eq {.calc.res} || [string match {.calc.res.*} $resat]}]
# ⚠ RESTATED by item 2: the thing the row must sit above used to be the pane's
# placeholder hint and is now the selector grid that replaced it.
check_true "S15 row sits at the top of the pane" \
    [expr {[winfo exists .calc.res] && [winfo exists .calc.sel]
           && [winfo rooty .calc.res] < [winfo rooty .calc.sel]}]

foreach {path cls} {
    .calc.res.tog    Button
    .calc.res.lab    Label
    .calc.res.path   Entry
    .calc.res.browse Button
} {
    check "S15 $path class" \
        [expr {[winfo exists $path] ? [winfo class $path] : {MISSING}}] $cls
}
check "S15 label text"       [pcall .calc.res.lab cget -text] {Results Dir:}
check "S15 path is readonly" [pcall .calc.res.path cget -state] readonly
check "S15 path field colour" [pcall .calc.res.path cget -readonlybackground] $c_field
check "S15 row background"    [pcall .calc.res cget -background] $c_panel
# ...and the row's OWN CHILDREN, which had no coverage: all three could revert
# to stock grey80 controls inside an #f2f2f2 row with the suite green.
check "S15 toggle background"        [pcall .calc.res.tog cget -background] $c_panel
check "S15 toggle wears the accent"  [pcall .calc.res.tog cget -foreground] $c_accent
check "S15 toggle keeps it on hover" [pcall .calc.res.tog cget -activeforeground] $c_accent
check "S15 toggle hover background"  [pcall .calc.res.tog cget -activebackground] $c_header
check "S15 label background"         [pcall .calc.res.lab cget -background] $c_panel
check "S15 label foreground"         [pcall .calc.res.lab cget -foreground] $c_fieldfg
check "S15 Browse background"        [pcall .calc.res.browse cget -background] $c_panel
check "S15 Browse disabled text is the muted role" \
    [pcall .calc.res.browse cget -disabledforeground] $c_disabledfg
check "S15 Browse has a palette foreground for when it is enabled" \
    [pcall .calc.res.browse cget -foreground] $c_fieldfg
# ⚠ "not $stockbg" is true of an error string too, so a missing widget would
# pass this. Collect what each one actually reports and demand a real colour.
set rowbgs {}
foreach w {.calc.res.tog .calc.res.lab .calc.res.browse} {
    set b [pcall $w cget -background]
    if {$b eq $stockbg || $b eq {} || [string match ERR:* $b]} { lappend rowbgs $w=$b }
}
check "S15 no control in the row is still stock grey" $rowbgs {}
# W05's Browse is a later item: present, so the row has its final shape, and
# disabled, so it cannot be pressed
check "S15 Browse stub disabled" [pcall .calc.res.browse cget -state] disabled

# no raw loaded: the entry must SAY so, not sit empty and not throw
check "S15 entry says no raw is loaded" [pcall .calc.res.path get] {(no raw file loaded)}
check_true "S15 entry reads as a sentence, not empty" \
    [expr {[set t [pcall .calc.res.path get]] ne {}
           && ![string match ERR:* $t] && [string match {*no raw*} $t]}]

# ⚠⚠ RESTATED, RESULTS BATCH ITEM 10 (U6) — SAME SUBJECT, OPPOSITE EXPECTATION.
# These legs used to shim `xschem raw rawfile` and assert the row showed the
# path: they pinned the `self` arm. The user removed that arm ENTIRELY on
# 2026-08-18 (doc/claude/specs/results_selection.md §17 decision 6, U6): the
# Calculator reads the ASE-L session's result and nothing else, and must never
# evaluate against a raw that a legacy path — the Waves menu, a graph rect's
# `autoload=`, `raw_read_from_attr` — dropped into a SCHEMATIC window's context.
# `calc::results_path`, which was that arm's reader, went with it.
#
# The subject is unchanged (what the row says while a raw IS loaded in THIS
# context) and the expectation is now the opposite, so the leg carries its own
# positive evidence in the same assertion: the shim really answers, and the row
# still refuses to use it. A `results_source` that quietly kept the self arm
# reds this, and so does one that lost the ability to see a raw at all.
check "S15 the self-arm reader is gone (U6)" [pcall info procs ::calc::results_path] {}
set shimerr [catch {
    rename ::xschem ::calc_test_real_xschem
    proc ::xschem {args} {
        if {[lrange $args 0 1] eq {raw rawfile}} { return {/tmp/calc test/sim.raw} }
        return [uplevel 1 [linsert $args 0 ::calc_test_real_xschem]]
    }
    calc::results_refresh
} shimmsg]
set shown [pcall .calc.res.path get]
set shimlive [pcall xschem raw rawfile]
set shimsrc [pcall calc::results_source]
catch {rename ::xschem {}}
catch {rename ::calc_test_real_xschem ::xschem}
check "S15 shim installed cleanly"       $shimerr 0
check "S15 a raw in THIS window's context is not what the row names (U6)" \
    [list $shimlive $shown $shimsrc] \
    {{/tmp/calc test/sim.raw} {(no raw file loaded)} {none {} {} {} {}}}
# the shim WAS live (it answered) and is gone again: with no raw loaded the
# real command throws (scheduler.c:10462) while other verbs still answer
check_true "S15 shim was live and is now gone" \
    [expr {$shimlive eq {/tmp/calc test/sim.raw}
           && ![string match ERR:* [pcall xschem get current_win_path]]
           && [string match ERR:* [pcall xschem raw rawfile]]}]
pcall calc::results_refresh
check "S15 refresh back to no-raw wording" [pcall .calc.res.path get] {(no raw file loaded)}

# the collapse toggle is layout, so it works now
check "S15 collapse hides all but the toggle" [pcall calc::res_toggle] 1
check "S15 collapsed slaves" [pcall pack slaves .calc.res] {.calc.res.tog}
check "S15 collapsed toggle relabelled" [pcall .calc.res.tog cget -text] {>}
check "S15 expand restores the row" [pcall calc::res_toggle] 0
check "S15 expanded slaves" [pcall pack slaves .calc.res] \
    {.calc.res.tog .calc.res.lab .calc.res.browse .calc.res.path}
check "S15 expanded toggle relabelled back" [pcall .calc.res.tog cget -text] {v}

# --- S16 the status area and calc::status's contract (R506-R509) -------------
# a fresh window starts silent (R508: the history belongs to the window)
check "S16 msg class"     [expr {[winfo exists .calc.status.msg] ? [winfo class .calc.status.msg] : {MISSING}}] Entry
check "S16 msg readonly"  [pcall .calc.status.msg cget -state] readonly
check "S16 hist class"    [expr {[winfo exists .calc.status.hist] ? [winfo class .calc.status.hist] : {MISSING}}] TCombobox
check "S16 hist readonly" [pcall .calc.status.hist cget -state] readonly
check "S16 field colour"  [pcall .calc.status.msg cget -readonlybackground] $c_field
# the collapse toggle above wrote two lines; clear them so the contract legs
# start from a known state, the way a fresh window does
set ::calc::statushist {}
pcall calc::status {}
check "S16 msg starts empty"  [pcall .calc.status.msg get] {}
check "S16 history starts empty" [pcall calc::status_history] {}

check "S16 status returns what it wrote" [pcall calc::status {first line}] {first line}
check "S16 msg shows it"      [pcall .calc.status.msg get] {first line}
check "S16 history has it"    [pcall calc::status_history] [list {first line}]
pcall calc::status {second line}
# R509: NEWEST FIRST. The order is the whole point of a history dropdown.
check "S16 newest first"      [pcall calc::status_history] {{second line} {first line}}
check "S16 dropdown reveals the history" [pcall .calc.status.hist cget -values] \
    {{second line} {first line}}

# W34 says the dropdown REVEALS the messages, and `cget -values` is the
# widget's DATA, not what the dropdown shows. ttk sizes the popdown to the
# combobox's own pixel width and this combobox is deliberately 2 characters
# wide, so with no -postoffset the popdown was 35 px and revealed `Buf`, `Plo`,
# `Eva`. Post it for real and measure the list.
pcall calc::status {Evaluate: expected a number, got the empty string}
pcall calc::status {Plot: no raw file loaded}
set longest {}
foreach v [pcall .calc.status.hist cget -values] {
    if {[string length $v] > [string length $longest]} { set longest $v }
}
set pdw 0; set pdlb {}
set posterr [catch {
    set pd [ttk::combobox::PopdownWindow .calc.status.hist]
    ttk::combobox::Post .calc.status.hist
    update idletasks
    set pdlb $pd.f.l
    set pdw [winfo width $pdlb]
} postmsg]
set needpx [expr {$posterr ? 0 : [font measure [$pdlb cget -font] $longest]}]
catch {ttk::combobox::Unpost .calc.status.hist}
update idletasks
set histpx 0
catch {set histpx [winfo width .calc.status.hist]}
check "S16 the dropdown posts" $posterr 0
check_true "S16 the dropdown is wider than the button that opens it" \
    [expr {$histpx > 0 && $pdw > 4 * $histpx}]
check_true "S16 the dropdown is wide enough to read the longest message" \
    [expr {$needpx > 0 && $pdw >= $needpx}]
# ...and put the history back where the contract legs below expect to find it
set ::calc::statushist [list {second line} {first line}]
pcall .calc.status.hist configure -values $::calc::statushist
# R507: the empty string clears and records nothing
check "S16 empty string returns {}" [pcall calc::status {}] {}
check "S16 empty string cleared the field" [pcall .calc.status.msg get] {}
check "S16 empty string recorded nothing"  [llength [pcall calc::status_history]] 2
# R509: consecutive duplicates are KEPT (two identical lines mean it happened
# twice; ciw_history dedupes because it recalls commands, this does not)
pcall calc::status {twice}
pcall calc::status {twice}
check "S16 duplicates are kept" [lrange [pcall calc::status_history] 0 1] {twice twice}

# R509: the cap is 50 and the OLDEST goes
set ::calc::statushist {}
for {set i 1} {$i <= 60} {incr i} { pcall calc::status "m$i" }
check "S16 capped at 50"        [llength [pcall calc::status_history]] 50
check "S16 newest kept"         [lindex [pcall calc::status_history] 0] m60
check "S16 oldest dropped"      [lindex [pcall calc::status_history] end] m11
check "S16 dropdown capped too" [llength [pcall .calc.status.hist cget -values]] 50

# W34 recall: re-display, do NOT re-record.
# ⚠ The length is NOT the assertion: re-recording at the cap pushes the tail
# out and leaves the length at 50, so a length check stays green over exactly
# the bug it is aimed at (measured — sabotage 8). Compare the whole list.
#
# ⚠ AND the snapshot must be REAL. Comparing [calc::status_history] against a
# $histbefore that is also [calc::status_history] passes vacuously when the proc
# does not exist — both sides become the same "ERR:invalid command name" string
# — which is exactly how this check passed against HEAD's calculator.tcl with
# the whole feature absent. The positive control below fails in that case, and
# the comparison substitutes a value that cannot match.
set histbefore [pcall calc::status_history]
check_true "S16 the pre-recall snapshot is a real 50-entry history" \
    [expr {![string match ERR:* $histbefore] && [llength $histbefore] == 50
           && [lindex $histbefore 0] eq {m60}}]
pcall .calc.status.hist set m20
pcall event generate .calc.status.hist <<ComboboxSelected>>
update idletasks
check "S16 recall re-displays"        [pcall .calc.status.msg get] m20
check "S16 recall recorded nothing" \
    [expr {[string match ERR:* $histbefore] ? {NO-SNAPSHOT-TO-COMPARE}
                                            : [pcall calc::status_history]}] \
    $histbefore
check "S16 recall cleared the button" [pcall .calc.status.hist get] {}

# R508: after the window goes, a status call is a silent no-op, not an error
calc::close
update idletasks
check "S16 status after close is a no-op" [pcall calc::status {gone}] {}
check "S16 close cleared the history"     [pcall calc::status_history] {}
check "S16 reopened window starts silent" [expr {[calc::open] eq {.calc}
    && [pcall .calc.status.msg get] eq {} && [pcall calc::status_history] eq {}}] 1
calc::close

# =============================================================================
# PHASE 1b (item 2) — the selector grid, the mode strip, the buffer + toolbar
# and the Stack.  All of it REAL BUT INERT: the assertions are path, class,
# initial state, and that pressing a control changes nothing except the status
# line (R506 — silence is a bug, and it has to be true of the inert window
# too).
#
#   S17  W06-W07: the 22-button selector grid — the exact two rows of spec §5
#        in three visual groups, the 8 that are rendered-and-disabled (§1.2),
#        their tooltips, and that they CANNOT be armed (R202)
#   S18  W08-W14: the mode strip — pick scope, Clip defaulting ON, the plot /
#        evaluate / table buttons and the destination combobox
#   S19  W15-W22: the buffer (typing works, because a text widget is not a
#        behaviour) and its toolbar, undo/redo created disabled
#   S20  W23-W25: the Stack labelframe, its listbox and the four side buttons
# =============================================================================

# a namespace variable read that cannot ABORT the file. `$::calc::foo` on a
# variable the build never created throws, the outer catch swallows the rest of
# the suite, and a sabotage that deletes a seed then looks like one failure
# instead of the twenty it caused (measured against HEAD: the file died at the
# first such read with 14 of the new checks reported and the other ~95 never
# run).
proc nsval {v} {
    if {[catch {uplevel #0 [list set $v]} r]} { return NO-SUCH-VARIABLE }
    return $r
}

check "S17 open returns .calc" [calc::open] .calc
update idletasks

# ⚠ THE INERT-PURITY SNAPSHOT, TAKEN BEFORE ANYTHING IS PRESSED.
# "EVERYTHING IN THIS ITEM IS INERT ... no button may act on it yet" was
# covered for the ten toolbar buttons only: S19 takes its own snapshot AFTER a
# `.calc.buf delete 1.0 end`, so any selector, pick-scope radio, Clip, Plot,
# Eval, Table or the destination combobox could write into the buffer and all
# checks stayed green (measured: `calc::sel_click` gaining a
# `.calc.buf insert end "v($id) "` left the suite at ALL PASS). Snapshot here,
# compare at the end of S18, with a positive control so an absent buffer cannot
# make the comparison vacuous (the S16 recall lesson).
pcall .calc.buf delete 1.0 end
pcall .calc.buf insert end {S17 INERT SENTINEL}
set inertbuf [pcall .calc.buf get 1.0 end]
set inertstk [pcall .calc.stk.list size]

# --- S17 the 22-button selector grid (W06-W07, spec §5) ----------------------
# The two rows are written out HERE as literals rather than read back from
# calc::sel_rows: a test that asks the implementation what the layout is
# asserts nothing about the layout. This is the ASCII in
# viva_calculator_explained.md §4 region C, which is the same set spec §5
# tabulates. (ref/viva_xl_calculator.png is the XL tool and shows a different
# set — `os`, `ot`, no `data` in that row. Colour reference only.)
set selrow1 {vt vf vdc vs op var vn sp vswr hp zm}
set selrow2 {it if idc is opt mp vn2 zp yp gd data}
set selall  [concat $selrow1 $selrow2]

check "S17 .calc.sel class" \
    [expr {[winfo exists .calc.sel] ? [winfo class .calc.sel] : {MISSING}}] Frame
check "S17 .calc.sel parent is .calc" [pcall winfo parent .calc.sel] .calc
check_true "S17 grid is mapped" \
    [expr {[winfo exists .calc.sel] && [winfo ismapped .calc.sel]}]
# ...and the stacking guard the Results Dir row paid for: a widget packed into
# a non-parent maps BEHIND its siblings unless it is raised, and `ismapped`
# returns 1 for a widget that is completely obscured.
set kids [pcall winfo children .calc]
check_true "S17 grid stacks above the panedwindow" \
    [expr {[lsearch -exact $kids .calc.sel] > [lsearch -exact $kids .calc.pw]
           && [lsearch -exact $kids .calc.sel] >= 0}]
update
set selat NO-GRID
catch {
    set selcx [expr {[winfo rootx .calc.sel] + [winfo width  .calc.sel] / 2}]
    set selcy [expr {[winfo rooty .calc.sel] + [winfo height .calc.sel] / 2}]
    set selat [winfo containing $selcx $selcy]
}
check_true "S17 grid is the topmost widget at its own centre" \
    [expr {$selat eq {.calc.sel} || [string match {.calc.sel.*} $selat]}]

# every id exists, is a radiobutton, shares the ONE radio variable, and carries
# its own id as its value (a shared -variable with a duplicated -value is a
# grid where two buttons light at once)
set badcls {}; set badvar {}; set badval {}; set badtext {}
foreach id $selall {
    set w .calc.sel.$id
    # ⚠ a MISSING widget is recorded in ALL FOUR lists, not skipped: skipping
    # it leaves the other three empty, and "every -value is its own id" then
    # passes over a grid that does not exist (measured — it did).
    if {![winfo exists $w]} {
        foreach l {badcls badvar badval badtext} { lappend $l $id=MISSING }
        continue
    }
    if {[winfo class $w] ne {Radiobutton}} { lappend badcls $id=[winfo class $w] }
    if {[pcall $w cget -variable] ne {::calc::selmode}} {
        lappend badvar $id=[pcall $w cget -variable]
    }
    if {[pcall $w cget -value] ne $id} { lappend badval $id=[pcall $w cget -value] }
    if {[pcall $w cget -text]  ne $id} { lappend badtext $id=[pcall $w cget -text] }
}
check "S17 all 22 exist and are radiobuttons" $badcls {}
check "S17 all 22 share ::calc::selmode"      $badvar {}
check "S17 each -value is its own id"         $badval {}
check "S17 each is labelled with its id"      $badtext {}
set nrb 0
foreach w [pcall winfo children .calc.sel] {
    if {[pcall winfo class $w] eq {Radiobutton}} { incr nrb }
}
check "S17 the grid holds exactly 22 radiobuttons, no strays" $nrb 22

# the LAYOUT: which row each id is on, and their left-to-right order in it.
# Read back from the geometry manager, not from the source table.
proc selpos {id} {
    set gi [pcall grid info .calc.sel.$id]
    if {[string match ERR:* $gi] || ![dict exists $gi -row]} { return {} }
    return [list [dict get $gi -row] [dict get $gi -column]]
}
array unset ::byrow ; array set ::byrow {0 {} 1 {}}
set unplaced {}
foreach id $selall {
    set p [selpos $id]
    if {$p eq {}} { lappend unplaced $id ; continue }
    foreach {r c} $p break
    if {$r != 0 && $r != 1} { lappend unplaced $id=row$r ; continue }
    lappend ::byrow($r) [list $c $id]
}
check "S17 every selector is placed in row 0 or row 1" $unplaced {}
proc rowids {r} {
    set out {}
    foreach e [lsort -integer -index 0 $::byrow($r)] { lappend out [lindex $e 1] }
    return $out
}
check "S17 row 1 is the voltage row, left to right" [rowids 0] $selrow1
check "S17 row 2 is the current row, left to right" [rowids 1] $selrow2

# three visual groups of 4 / 3 / 4. A group boundary is a COLUMN GAP: the
# reference draws the RF block, the op/var/vn block and the v-vs-i block apart,
# and 22 evenly-spaced buttons would read as one undifferentiated strip.
proc selcol {id} {
    set p [selpos $id]
    if {$p eq {}} { return -999 }   ;# absent: reportable, never an abort
    return [lindex $p 1]
}
set nogap {}
foreach {lastof firstof} {vs op  vn sp  is opt  vn2 zp} {
    if {[selcol $firstof] - [selcol $lastof] < 2} { lappend nogap $lastof/$firstof }
}
check "S17 the three groups are separated by a spacer column" $nogap {}
# ...and the spacer is VISIBLE, not just empty: the reference rules a hairline
# between groups. A gap of zero pixels is a gap nobody can see.
#
# ⚠ AND IT MUST CONTRAST WITH WHAT IT SITS ON. exists + ismapped + width>=1
# says nothing about visibility: painting the hairline `[calc::color panel]`,
# i.e. the grid frame's own background, leaves NO visible group separation at
# all — the one thing this check's name claims — and the suite stayed ALL PASS
# (measured). The two sabotages that used to redden it both deleted the `grid`
# call, which tests mapping, not visibility.
set badsep {}
foreach s {.calc.sel.sep1 .calc.sel.sep2} {
    if {![winfo exists $s] || ![winfo ismapped $s] || [winfo width $s] < 1} {
        lappend badsep $s
        continue
    }
    set sbg [pcall $s cget -background]
    if {$sbg eq $c_panel || $sbg eq {} || [string match ERR:* $sbg]} {
        lappend badsep $s=$sbg
    }
}
check "S17 both group separators are drawn" $badsep {}

# spec §1.2: seven RF ids and `mp` are RENDERED AND DISABLED — rendering them
# is information, and removing them would change the shape of the grid, which
# is the tool's identity
set want_disabled {sp zp yp hp vswr zm gd mp}
set badstate {}
foreach id $selall {
    set st [btnstate .calc.sel.$id]
    set want [expr {[lsearch -exact $want_disabled $id] >= 0 ? {disabled} : {normal}}]
    if {$st ne $want} { lappend badstate $id=$st }
}
check "S17 exactly the 7 RF ids and mp are disabled" $badstate {}
# ...and the table the implementation disables FROM is the spec's eight, so a
# ninth id cannot be quietly retired into it
check "S17 the disabled table is the spec's eight, no more" \
    [lsort [pcall dict keys [pcall calc::sel_disabled]]] [lsort $want_disabled]

# R202: a disabled selector CANNOT BE ARMED. This is worth more than the
# -state check above, because it is the behaviour -state is there to buy.
# Arm a real one first, so "unchanged" is distinguishable from "cleared".
check "S17 nothing is armed at first open" [nsval ::calc::selmode] {}
pcall .calc.sel.vt invoke
check "S17 an enabled selector arms" [nsval ::calc::selmode] vt
check "S17 arming says so (R506)" [pcall .calc.status.msg get] \
    {selector vt: signal picking: not implemented (phase 6)}
set armed {}
foreach id $want_disabled {
    pcall .calc.sel.$id invoke
    if {[nsval ::calc::selmode] ne {vt}} { lappend armed $id=[nsval ::calc::selmode] }
}
check "S17 invoking a disabled selector arms nothing" $armed {}
# ...and the same through a real pointer gesture, because `invoke` is not what
# a user does. Tk's Button class bindings return early on a disabled widget,
# but the widget still RECEIVES the events, which is what makes R202's
# explanatory line deliverable at all.
pcall calc::status {}
pcall event generate .calc.sel.sp <Enter> -x 3 -y 3
pcall event generate .calc.sel.sp <Button-1> -x 3 -y 3
pcall event generate .calc.sel.sp <ButtonRelease-1> -x 3 -y 3
pcall event generate .calc.sel.sp <Leave>
update idletasks
check "S17 clicking a disabled selector still arms nothing" [nsval ::calc::selmode] vt
check "S17 clicking a disabled selector explains why (R202)" \
    [pcall .calc.status.msg get] \
    {selector sp is not available: no S-parameter analysis in ngspice}

# ⚠ EVERY ENABLED SELECTOR, not just vt. Only `.calc.sel.vt` was ever invoked,
# so the CROSS-CUTTING rule ("every inert control's -command must route through
# calc::status ... so that R506 is already true of the inert window") was
# unverified for the other thirteen: silencing all but vt left the suite at ALL
# PASS (measured). Each one must arm ITSELF and name itself and its phase.
set selsilent {}
set selunarmed {}
foreach id $selall {
    if {[lsearch -exact $want_disabled $id] >= 0} continue
    pcall calc::status {}
    pcall .calc.sel.$id invoke
    if {[nsval ::calc::selmode] ne $id} { lappend selunarmed $id=[nsval ::calc::selmode] }
    if {[pcall .calc.status.msg get] ne "selector $id: signal picking: not implemented (phase 6)"} {
        lappend selsilent $id=[pcall .calc.status.msg get]
    }
}
check "S17 every enabled selector arms itself" $selunarmed {}
check "S17 every enabled selector names itself and its phase (R506)" $selsilent {}
pcall .calc.sel.vt invoke

# ⚠ THE UNARMED LOOK. Tk's DEFAULT -tristatevalue is the EMPTY STRING, and {}
# is exactly what ::calc::selmode holds when nothing is armed — so at first
# open every one of the 22 selectors rendered in Tk's MIXED look, a panel-grey
# disc with a grey dot in it, instead of the empty white `field` disc the code
# picked -selectcolor for. MEASURED by scanline across .calc.sel.vt's
# indicator: selmode {} gave a (242,242,242) disc + a (127,127,127) dot, while
# a non-matching non-empty value gave the flat (255,255,255) disc and `vt` gave
# white + a BLACK dot. The window shipped looking as though every selector were
# half-armed, with "S17 nothing is armed at first open" green — that check
# reads the VARIABLE, and the defect is in the rendering.
# The invariant that fixes it: no value ::calc::selmode can legitimately hold —
# {} or any of the 22 ids — may equal the widget's -tristatevalue.
set tristate_clash {}
foreach id $selall {
    set tv [pcall .calc.sel.$id cget -tristatevalue]
    if {[string match ERR:* $tv]} { lappend tristate_clash $id=NO-TRISTATE ; continue }
    foreach legit [concat [list {}] $selall] {
        if {$tv eq $legit} { lappend tristate_clash $id=clashes-with-{$legit} ; break }
    }
}
check "S17 no legitimate selmode value renders as Tk's tristate" $tristate_clash {}

# the tooltip spec §1.2 asks for, on every one of the eight. `balloon` bakes
# its string into the <Enter> binding at attach time (xschem.tcl:12729), which
# is how the tree's other suites assert a tooltip.
set notip {}
foreach {id why} [pcall calc::sel_disabled] {
    set b [pcall bind .calc.sel.$id <Enter>]
    if {[string match ERR:* $b] || ![string match "*$why*" $b]} { lappend notip $id }
}
check "S17 every disabled selector carries its reason as a tooltip" $notip {}
check_true "S17 the RF reason and the mp reason are the spec's two, and differ" \
    [expr {[string match {*no S-parameter analysis in ngspice*} \
                [pcall bind .calc.sel.vswr <Enter>]]
           && [string match {*needs a model-database reader*} \
                [pcall bind .calc.sel.mp <Enter>]]}]
# an ENABLED selector must not claim to be unavailable
check "S17 an enabled selector has no refusal tooltip" \
    [pcall bind .calc.sel.vt <Enter>] {}

# colours, on all 22 at once — sampling one let 21 revert with the suite green
set badcolor {}
foreach id $selall {
    set w .calc.sel.$id
    if {[pcall $w cget -background] ne $c_panel}        { lappend badcolor $id-bg }
    if {[pcall $w cget -foreground] ne $c_fieldfg}      { lappend badcolor $id-fg }
    if {[pcall $w cget -disabledforeground] ne $c_disabledfg} { lappend badcolor $id-dis }
    if {[pcall $w cget -selectcolor] ne $c_field}       { lappend badcolor $id-sel }
}
check "S17 every selector wears the palette" $badcolor {}
# ⚠ -selectcolor is the indicator's FIELD colour, not its "lit" colour, and
# the difference is not academic. MEASURED on this Tk (scanline across the
# indicator of .calc.sel.vt at 3 states): unarmed-and-another-armed = a disc
# filled flat with -selectcolor; ARMED = the same disc with a BLACK dot in it;
# nothing armed at all = the tristate look, a background-coloured disc with a
# grey dot. So -selectcolor selectbg painted every unarmed selector as a solid
# dark-blue blob and the armed one as the same blob with a dot — 22 buttons
# that all read as "on". The palette role that means "the white inside a
# field" is `field`, which is also what xschem's own option database says for
# every other radiobutton in the tree (*selectColor white, xschem.tcl:15738).
check_true "S17 the indicator field is not the panel it sits on" \
    [expr {$c_field ne $c_panel}]

# --- S18 the mode strip (W08-W14, spec §6) -----------------------------------
check "S18 .calc.mode class" \
    [expr {[winfo exists .calc.mode] ? [winfo class .calc.mode] : {MISSING}}] Frame
check "S18 .calc.mode parent is .calc" [pcall winfo parent .calc.mode] .calc
check_true "S18 strip sits below the grid" \
    [expr {[winfo exists .calc.mode] && [winfo exists .calc.sel]
           && [winfo rooty .calc.mode] > [winfo rooty .calc.sel]}]

foreach {path cls} {
    .calc.mode.off    Radiobutton
    .calc.mode.family Radiobutton
    .calc.mode.wave   Radiobutton
    .calc.mode.clip   Checkbutton
    .calc.mode.plot   Button
    .calc.mode.eval   Button
    .calc.mode.dest   TCombobox
    .calc.mode.table  Button
} {
    check "S18 $path class" \
        [expr {[winfo exists $path] ? [winfo class $path] : {MISSING}}] $cls
}
# W09: one variable, initial `off` (spec §6: pick from the schematic canvas)
set badscope {}
foreach {id val} {off off family family wave wave} {
    if {[pcall .calc.mode.$id cget -variable] ne {::calc::pickscope}} {
        lappend badscope $id-var
    }
    if {[pcall .calc.mode.$id cget -value] ne $val} { lappend badscope $id-val }
}
check "S18 the three scopes share ::calc::pickscope with their own values" $badscope {}
check "S18 pick scope starts off" [nsval ::calc::pickscope] off
check "S18 the scope labels are the spec's" \
    [list [pcall .calc.mode.off cget -text] [pcall .calc.mode.family cget -text] \
          [pcall .calc.mode.wave cget -text]] {Off Family Wave}
# ⚠ ...and the three are actually PRESSED. Nothing in the suite ever invoked
# them or ever set ::calc::pickscope to family or wave, so `-command {}` on all
# three left the suite at ALL PASS (measured) — the cross-cutting R506 rule was
# unverified for the whole pick-scope group. Each must move the variable to its
# own value AND say so.
set scopesilent {}
set scopestuck {}
foreach {id label} {family Family wave Wave off Off} {
    pcall calc::status {}
    pcall .calc.mode.$id invoke
    if {[nsval ::calc::pickscope] ne $id} { lappend scopestuck $id=[nsval ::calc::pickscope] }
    if {[pcall .calc.status.msg get] ne "pick scope $label: not implemented (phase 6)"} {
        lappend scopesilent $id=[pcall .calc.status.msg get]
    }
}
check "S18 each pick scope selects itself" $scopestuck {}
check "S18 each pick scope names itself and its phase (R506)" $scopesilent {}
check "S18 the sweep left the scope back at off" [nsval ::calc::pickscope] off

# W10: Clip INITIAL 1. The variable AND the widget's own on-value, because a
# checkbutton whose -onvalue is not what the variable holds renders unchecked
# while the variable says 1.
check "S18 clip variable"  [pcall .calc.mode.clip cget -variable] {::calc::clip}
check "S18 clip starts ON" [nsval ::calc::clip] 1
check "S18 clip on-value matches the initial value" [pcall .calc.mode.clip cget -onvalue] 1
check "S18 clip text"      [pcall .calc.mode.clip cget -text] {Clip}
# ...and it is a live checkbutton that SAYS what it did, and nothing else
pcall .calc.mode.clip invoke
check "S18 clip toggles"   [nsval ::calc::clip] 0
check "S18 clip toggle speaks" [pcall .calc.status.msg get] \
    {Clip: not implemented (phase 6)}
pcall .calc.mode.clip invoke
check "S18 clip toggles back" [nsval ::calc::clip] 1

# W13: the destination combobox. Exactly these three values, initial Append.
check "S18 dest values"   [pcall .calc.mode.dest cget -values] {Append Replace {New Strip}}
check "S18 dest initial"  [pcall .calc.mode.dest get] {Append}
check "S18 dest readonly" [pcall .calc.mode.dest cget -state] readonly
# the house companion: a readonly ttk::combobox does not type-to-cycle by
# itself (recon/widgets.md §1d, xschem.tcl:10946)
check_true "S18 dest binds combo_letter_cycle" \
    [string match {*combo_letter_cycle*} [pcall bind .calc.mode.dest <Key>]]
# ⚠ and it must NOT wear the status bar's style: Calc.TCombobox carries a
# -postoffset that drags its popdown ~460 px to the LEFT, which is right for a
# 2-character button at the right edge of the window and would fling this
# 10-character combobox's list off the window.
check "S18 dest does not borrow the status history's offset style" \
    [pcall .calc.mode.dest cget -style] {Calc.Field.TCombobox}
# ...and the style it does wear is a real one (it paints the field), which is
# what stops this pair from passing over a combobox that does not exist
check "S18 dest style is real, and carries no popdown offset" \
    [list [pcall ttk::style configure Calc.Field.TCombobox -fieldbackground] \
          [pcall ttk::style configure Calc.Field.TCombobox -postoffset]] \
    [list $c_field {}]
check_true "S18 the status history style does have one (control)" \
    [expr {[llength [pcall ttk::style configure Calc.TCombobox -postoffset]] == 4}]
# ⚠ AND THE STYLE OPTION IS NOT WHAT PAINTS A READONLY COMBOBOX. Both
# comboboxes in this window are -state readonly (that is what a chooser is),
# and in this theme the readonly field comes from the style's STATE MAP:
# `ttk::style configure Calc.Field.TCombobox -fieldbackground` reported #ffffff
# while the widget rendered the stock #d9d9d9 (sampled from the live window:
# (217,217,217), against .calc.status.msg — a plain Entry in the same role —
# at (255,255,255)). The two checks above read the style OPTION and could not
# see it. Assert the map, for both styles, on the state the widgets are in.
proc stmap {style opt state} {
    set m [pcall ttk::style map $style $opt]
    if {[string match ERR:* $m] || [llength $m] % 2} { return MAP-UNREADABLE }
    if {![dict exists $m $state]} { return NO-SUCH-STATE }
    return [dict get $m $state]
}
set badmap {}
foreach st {Calc.TCombobox Calc.Field.TCombobox} {
    if {[stmap $st -fieldbackground readonly] ne $c_field}   { lappend badmap $st-field }
    if {[stmap $st -foreground      readonly] ne $c_fieldfg} { lappend badmap $st-fg }
}
check "S18 the readonly field colour is MAPPED, not just configured" $badmap {}
# ...and the widgets really are in that state, or the map above paints nothing
check "S18 both comboboxes are the state the map covers" \
    [list [pcall .calc.mode.dest cget -state] [pcall .calc.status.hist cget -state]] \
    {readonly readonly}
pcall .calc.mode.dest set {Replace}
pcall event generate .calc.mode.dest <<ComboboxSelected>>
update idletasks
check "S18 choosing a destination says so" [pcall .calc.status.msg get] \
    {plot destination Replace: not implemented (phase 3)}
pcall .calc.mode.dest set {Append}

# the three action buttons are INERT, and each names itself and its phase.
#
# ⚠ RESTATED FOR `eval` ONLY, results batch item 10 (U7). Evaluate is no longer
# plain-inert: it resolves the session's result FIRST, and with none loaded it
# refuses in the ruled words instead of naming a phase. That is the point of the
# ruling — "not implemented (phase 3)" is true and useless to a user who has no
# results, and the sentence that replaces it names the gesture that fixes it.
# Plot and Table are deliberately untouched: U7 names Evaluate, and gating the
# other two would be scope creep (the phase-3 stub is still what a press WITH a
# result reaches — S27 drives that arm).
foreach {id label phase} {plot Plot 3 eval Eval 3 table Table 10} {
    check "S18 $id text" [pcall .calc.mode.$id cget -text] $label
    check "S18 $id enabled" [btnstate .calc.mode.$id] normal
    pcall .calc.mode.$id invoke
    if {$id eq {eval}} {
        check "S18 $id with no result refuses and names the next action (U7)" \
            [pcall .calc.status.msg get] \
            "No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L \u25b8 Results \u25b8 Select."
    } else {
        check "S18 $id is inert and says so" [pcall .calc.status.msg get] \
            "$label: not implemented (phase $phase)"
    }
}

# --- S17/S18 inert purity: nothing pressed above touched the work surfaces ---
# Everything from the top of S17 to here has been invoked: all 22 selectors,
# the three pick scopes, Clip twice, Plot, Eval, Table and the destination
# combobox. NONE of them may write to the buffer or the stack. Compare against
# the snapshot taken before the first press, with a positive control so an
# absent buffer cannot pass the comparison vacuously.
check_true "S17/S18 the pre-press snapshot is real text" \
    [expr {![string match ERR:* $inertbuf]
           && [string match {*INERT SENTINEL*} $inertbuf]
           && [string is integer -strict $inertstk]}]
check "S17/S18 no selector or mode control touched the buffer" \
    [expr {[string match ERR:* $inertbuf] ? {NO-SNAPSHOT-TO-COMPARE}
                                          : [pcall .calc.buf get 1.0 end]}] $inertbuf
check "S17/S18 no selector or mode control touched the stack" \
    [expr {[string is integer -strict $inertstk] ? [pcall .calc.stk.list size]
                                                 : {NO-SNAPSHOT-TO-COMPARE}}] $inertstk

# --- S19 the buffer and its toolbar (W15-W22) --------------------------------
check "S19 .calc.buf class" \
    [expr {[winfo exists .calc.buf] ? [winfo class .calc.buf] : {MISSING}}] Text
check "S19 buffer height"   [pcall .calc.buf cget -height] 4
check "S19 buffer undo on"  [pcall .calc.buf cget -undo] 1
check "S19 buffer editable" [pcall .calc.buf cget -state] normal
check "S19 buffer field colour"   [pcall .calc.buf cget -background] $c_field
check "S19 buffer text colour"    [pcall .calc.buf cget -foreground] $c_fieldfg
check "S19 buffer caret is visible on the field" \
    [pcall .calc.buf cget -insertbackground] $c_fieldfg
# ⚠ BOTH MAPPED, and the buffer above. `winfo exists` is not enough and
# neither is the slaves list: pack fills the cavity in PACKING order, so a
# `-fill both -expand 1` buffer packed before the fixed-height toolbar takes
# all of it and the toolbar is never mapped at all — measured at 660x700, the
# entire button row was off-screen with every widget check green. The packing
# order is therefore deliberately the reverse of the visual order.
check "S19 the Buffer pane packs the toolbar first, so it gets its height" \
    [pcall pack slaves .calc.pw.buf] {.calc.btb .calc.buf}
check_true "S19 buffer AND toolbar are both mapped, buffer above" \
    [expr {[winfo exists .calc.buf] && [winfo exists .calc.btb]
           && [winfo ismapped .calc.buf] && [winfo ismapped .calc.btb]
           && [winfo rooty .calc.buf] < [winfo rooty .calc.btb]}]

# "typing into the buffer must work" — a text widget accepting text is the
# widget working, not a behaviour this phase wires. Asserted through the widget
# API rather than a synthesised <Key>: bare `event generate` key delivery is a
# known ~1-in-5 flake in this tree, and a flaky check is not evidence.
pcall .calc.buf delete 1.0 end
pcall .calc.buf insert end {v(out) v(in) / db20()}
check "S19 the buffer holds what was typed into it" \
    [string trim [pcall .calc.buf get 1.0 end]] {v(out) v(in) / db20()}
pcall .calc.buf edit undo
check_true "S19 -undo 1 is live (Tk's own edit stack)" \
    [expr {[string trim [pcall .calc.buf get 1.0 end]] eq {}}]
pcall .calc.buf insert end {v(out) v(in) / db20()}

check "S19 .calc.btb class" \
    [expr {[winfo exists .calc.btb] ? [winfo class .calc.btb] : {MISSING}}] Frame
set btb {enter Enter pop Pop swap Swap roll Roll clrbuf ClrBuf clrstk ClrStk
         mplus M+ me ME undo Undo redo Redo}
set badbtb {}
foreach {id label} $btb {
    set w .calc.btb.$id
    if {![winfo exists $w]} { lappend badbtb $id=MISSING ; continue }
    if {[winfo class $w] ne {Button}} { lappend badbtb $id=[winfo class $w] }
    if {[pcall $w cget -text] ne $label} { lappend badbtb $id=[pcall $w cget -text] }
}
check "S19 all ten toolbar buttons, with the spec's labels" $badbtb {}
set btborder {}
foreach {id label} $btb { lappend btborder .calc.btb.$id }
check "S19 toolbar order is the spec's, left to right" \
    [pcall pack slaves .calc.btb] $btborder
# W22: undo/redo are created DISABLED (R505 — their history is empty, and the
# history they will cover spans the buffer AND the stack, which is phase 2/4)
check "S19 undo starts disabled" [pcall .calc.btb.undo cget -state] disabled
check "S19 redo starts disabled" [pcall .calc.btb.redo cget -state] disabled
set badenabled {}
foreach {id label} $btb {
    if {$id in {undo redo}} continue
    if {[btnstate .calc.btb.$id] ne {normal}} { lappend badenabled $id }
}
check "S19 the other eight are pressable" $badenabled {}

# NO BUTTON MAY ACT ON THE BUFFER YET, and every one of them must still speak.
set bufbefore [pcall .calc.buf get 1.0 end]
set silent {}
foreach {id label} $btb {
    if {$id in {undo redo}} continue
    pcall calc::status {}
    pcall .calc.btb.$id invoke
    if {![string match "$label: not implemented*" [pcall .calc.status.msg get]]} {
        lappend silent $id=[pcall .calc.status.msg get]
    }
}
check "S19 every toolbar button names itself and its phase" $silent {}
# ⚠ the snapshot must be REAL: with no buffer widget both sides are the same
# "ERR:bad window path name" string and the comparison passes over the very
# absence it is aimed at (the S16 recall lesson). Positive control, then a
# value that cannot match when it fails.
check_true "S19 the pre-press buffer snapshot is real text" \
    [expr {![string match ERR:* $bufbefore] && [string match {*v(out)*} $bufbefore]}]
check "S19 no toolbar button touched the buffer" \
    [expr {[string match ERR:* $bufbefore] ? {NO-SNAPSHOT-TO-COMPARE}
                                           : [pcall .calc.buf get 1.0 end]}] $bufbefore
check "S19 no toolbar button touched the stack" [pcall .calc.stk.list size] 0
# a disabled button does not fire at all — the sentinel stays put
pcall calc::status {S19 sentinel}
pcall .calc.btb.undo invoke
pcall .calc.btb.redo invoke
check "S19 disabled undo/redo do not fire" \
    [list [winfo exists .calc.btb.undo] [winfo exists .calc.btb.redo] \
          [pcall .calc.status.msg get]] {1 1 {S19 sentinel}}
pcall .calc.buf delete 1.0 end

# --- S20 the Stack (W23-W25) -------------------------------------------------
check "S20 .calc.stk class" \
    [expr {[winfo exists .calc.stk] ? [winfo class .calc.stk] : {MISSING}}] Labelframe
check "S20 titled Stack"           [pcall .calc.stk cget -text] {Stack}
check "S20 .calc.stk parent is .calc" [pcall winfo parent .calc.stk] .calc
check "S20 drawn in the Stack pane" [pcall pack slaves .calc.pw.stk] {.calc.stk}
# ⚠ ...and the word is drawn ONCE. Phase 0 titled the PANE `Stack`; spec W23
# puts a labelframe titled `Stack` inside it. Two nested boxes both captioned
# Stack is a defect no colour or class check can see. (Crew ruling, item 2:
# the spec's widget keeps the title, the pane loses it.)
check "S20 the pane holding it carries no second title" \
    [pcall .calc.pw.stk cget -text] {}
check "S20 the pane is still a labelframe wearing the accent" \
    [list [pcall winfo class .calc.pw.stk] [pcall .calc.pw.stk cget -foreground]] \
    [list Labelframe $c_accent]

check "S20 .calc.stk.list class" \
    [expr {[winfo exists .calc.stk.list] ? [winfo class .calc.stk.list] : {MISSING}}] Listbox
check "S20 the stack starts empty" [pcall .calc.stk.list size] 0
check "S20 list field colour"   [pcall .calc.stk.list cget -background] $c_field
check "S20 list text colour"    [pcall .calc.stk.list cget -foreground] $c_fieldfg
check "S20 list selection colours" \
    [list [pcall .calc.stk.list cget -selectbackground] \
          [pcall .calc.stk.list cget -selectforeground]] [list $c_selectbg $c_selectfg]
# ⚠ the scrollbar beside it, which had no coverage at all (`grep 'stk\.sb'`:
# no hits) and was the ONE widget this item added with no palette on it: stock
# grey80 with a #b3b3b3 trough, sampled from the live window at (204,204,204)
# against a (242,242,242) panel. The cross-cutting rule is that every colour
# comes from calc::color; "not stock" is asserted as well as "is the palette",
# because an error string is also "not stock".
check "S20 .calc.stk.sb class" \
    [expr {[winfo exists .calc.stk.sb] ? [winfo class .calc.stk.sb] : {MISSING}}] Scrollbar
check "S20 the scrollbar wears the palette" \
    [list [pcall .calc.stk.sb cget -background] \
          [pcall .calc.stk.sb cget -troughcolor] \
          [pcall .calc.stk.sb cget -activebackground]] \
    [list $c_panel $c_header $c_header]
# ⚠ "not stock" is true of an error string too, so demand a REAL colour first
set sbbad {}
foreach opt {-background -troughcolor} {
    set v [pcall .calc.stk.sb cget $opt]
    if {$v eq {} || [string match ERR:* $v] || $v eq $stockbg || $v eq {#b3b3b3}} {
        lappend sbbad $opt=$v
    }
}
check "S20 the scrollbar is not still stock grey" $sbbad {}
check "S20 the scrollbar actually drives the listbox" \
    [pcall .calc.stk.sb cget -command] {.calc.stk.list yview}
set badstk {}
foreach {id label} {push Push pop Pop del Del recall Recall} {
    set w .calc.stk.$id
    if {![winfo exists $w]} { lappend badstk $id=MISSING ; continue }
    if {[winfo class $w] ne {Button}} { lappend badstk $id=[winfo class $w] }
    if {[pcall $w cget -text] ne $label} { lappend badstk $id=[pcall $w cget -text] }
    if {[btnstate $w] ne {normal}} { lappend badstk $id=[btnstate $w] }
}
check "S20 the four side buttons, with the spec's labels" $badstk {}
# ...and they are ONE COLUMN, not two groups. The obvious way to make the
# listbox fill the pane is to weight the last button's grid row, and that
# stretches the row: measured, `Recall` sat 60 px under `Del` with a gap
# between them, which reads as a separate button. The stretch belongs to an
# empty row below them.
set stkgap 0
set stkh [expr {[winfo exists .calc.stk.push] ? [winfo height .calc.stk.push] : 0}]
set stky {}
foreach id {push pop del recall} {
    if {[winfo exists .calc.stk.$id]} { lappend stky [winfo rooty .calc.stk.$id] }
}
foreach a [lrange $stky 0 end-1] b [lrange $stky 1 end] {
    if {$b - $a > $stkgap} { set stkgap [expr {$b - $a}] }
}
check_true "S20 the four side buttons are one contiguous column" \
    [expr {$stkh > 0 && [llength $stky] == 4 && $stkgap <= $stkh + 6}]
set stksilent {}
foreach {id label} {push Push pop Pop del Del recall Recall} {
    pcall calc::status {}
    pcall .calc.stk.$id invoke
    if {![string match "Stack $label: not implemented*" [pcall .calc.status.msg get]]} {
        lappend stksilent $id=[pcall .calc.status.msg get]
    }
}
check "S20 every side button names itself and its phase" $stksilent {}
check "S20 no side button pushed anything" [pcall .calc.stk.list size] 0

# --- S17-S20 fixture teardown: the initial state is a property of the BUILD --
# Everything above pressed things. Reopen and re-read the four initial values,
# so `Clip starts ON` cannot be an artefact of the order the checks ran in.
calc::close
update idletasks
check "S17 reopen returns .calc" [calc::open] .calc
update idletasks
check "S17 a fresh window arms no selector"  [nsval ::calc::selmode] {}
check "S18 a fresh window scopes to off"     [nsval ::calc::pickscope] off
check "S18 a fresh window has Clip ON"       [nsval ::calc::clip] 1
check "S18 a fresh window destination is Append" [pcall .calc.mode.dest get] {Append}
check "S19 a fresh window has an empty buffer" \
    [string trim [pcall .calc.buf get 1.0 end]] {}
check "S19 a fresh window has undo/redo disabled" \
    [list [pcall .calc.btb.undo cget -state] [pcall .calc.btb.redo cget -state]] \
    {disabled disabled}
check "S20 a fresh window has an empty stack" [pcall .calc.stk.list size] 0

# --- S21 the FIRST-OPEN layout, and the toplevel's own declared minimum ------
# Every check above reads a cget or a variable, and a cget cannot see a widget
# that is on screen at a fraction of the size it asked for. Two defects lived
# behind 299 such checks:
#
#   * the buffer — spec W15, `height 4`, the tool's primary work surface — was
#     given 29 px of the 72 it requests, so it drew one full line and a sliced
#     second one. `.calc.buf cget -height` was 4 throughout; `bbox 3.0` and
#     `bbox 4.0` were EMPTY. The knob is calc::pw_list's first-open fractions.
#   * the 22-button grid needs 614 px, and the toplevel's own declared minimum
#     let the window shrink to 548 px of usable width, so `zm` and `data` — and
#     `data` is an ENABLED selector — were entirely off screen while
#     `winfo ismapped` still returned 1. It survived a close/reopen, because
#     save_layout persists the geometry.
#
# ⚠ THIS BLOCK NEEDS A TRUE FIRST OPEN. Everything above has resized the window
# to 700x800 and calc::geom persists across a close, so the plain teardown
# reopen is NOT the layout a new user gets — it is a roomier one, in which the
# buffer defect does not reproduce. Clear the persisted layout as well as the
# sash array; that is exactly what a first-ever open looks like.
calc::close
update idletasks
array unset ::calc::sash
set ::calc::geom {}
check "S21 first open returns .calc" [calc::open] .calc
update idletasks
raise .calc
update

# the buffer, in RENDERED lines rather than in its -height option
pcall .calc.buf delete 1.0 end
pcall .calc.buf insert end "l1\nl2\nl3\nl4"
update idletasks
check_true "S21 fixture: the buffer really holds four lines" \
    [expr {[pcall .calc.buf bbox 1.0] ne {} && ![string match ERR:* [pcall .calc.buf bbox 1.0]]
           && [string trim [pcall .calc.buf get 1.0 end]] eq "l1\nl2\nl3\nl4"}]
set unseen {}
foreach i {1 2 3 4} {
    set bb [pcall .calc.buf bbox $i.0]
    if {$bb eq {} || [string match ERR:* $bb]} { lappend unseen $i }
}
check "S21 the buffer shows all four of its lines at first open (W15)" $unseen {}
pcall .calc.buf delete 1.0 end

# ...and the general form of the same defect: no pane may hand its contents
# less than they ask for at first open. `winfo reqheight` is what the widget
# asked for; `winfo height` is what it got.
set squeezed {}
foreach w {.calc.sel .calc.mode .calc.buf .calc.btb .calc.stk} {
    set got [pcall winfo height $w] ; set want [pcall winfo reqheight $w]
    if {[string match ERR:* $got] || [string match ERR:* $want] || $got < $want} {
        lappend squeezed $w=$got/$want
    }
}
check "S21 no pane's contents are squeezed below their requested height" $squeezed {}
set narrow {}
foreach w {.calc.res .calc.sel .calc.mode .calc.btb} {
    set got [pcall winfo width $w] ; set want [pcall winfo reqwidth $w]
    if {[string match ERR:* $got] || [string match ERR:* $want] || $got < $want} {
        lappend narrow $w=$got/$want
    }
}
check "S21 no row is narrower than it asked to be at first open" $narrow {}

# THE DECLARED MINIMUM. The two axes are pinned separately: the number, and
# what is actually reachable at it.
set mins [pcall wm minsize .calc]
check_true "S21 the declared minimum is wide enough for the selector pane" \
    [expr {[llength $mins] == 2
           && [lindex $mins 0] >= [pcall winfo reqwidth .calc.pw.sel]}]
# and it is DERIVED, not a constant that the next wider grid outgrows
check_true "S21 the minimum tracks the grid, it is not a guessed constant" \
    [expr {[lindex $mins 0] >= [lindex [pcall calc::min_floor] 0]
           && [lindex $mins 0] >= [pcall winfo reqwidth .calc.sel]}]

# shrink to the minimum — and past it, which the wm must refuse
wm geometry .calc [format {%dx%d} [lindex $mins 0] [lindex $mins 1]]
update idletasks ; update
wm geometry .calc 400x400
update idletasks ; raise .calc ; update
# ⚠ compared against what the CONTENTS need, not against the number the window
# reports: a minimum that has been set to 1x1 reports 1x1 and then "the window
# is at least its minimum" is true of a window that has clipped everything.
check_true "S21 the window cannot be shrunk to where the grid would clip" \
    [expr {[winfo width .calc]  >= [pcall winfo reqwidth .calc.pw.sel]
           && [winfo height .calc] >= [lindex [pcall calc::min_floor] 1]}]
# ⚠ `winfo ismapped` returns 1 for a widget that is entirely off the window,
# which is why it cannot guard this. `winfo containing` at the widget's own
# centre returns the EMPTY STRING when nothing of it is on screen — that is
# what zm and data returned at 560x620.
set offscreen {}
foreach id $selall {
    set w .calc.sel.$id
    if {![winfo exists $w]} { lappend offscreen $id=MISSING ; continue }
    set cx [expr {[winfo rootx $w] + [winfo width  $w] / 2}]
    set cy [expr {[winfo rooty $w] + [winfo height $w] / 2}]
    set at [pcall winfo containing $cx $cy]
    if {$at ne $w} { lappend offscreen $id=($at) }
}
check "S21 all 22 selectors are on screen at the declared minimum" $offscreen {}
# ⚠ pcall + a sentinel, not a bare `winfo`: a missing .calc.sel makes a bare
# call THROW, the outer catch swallows every remaining check, and the file
# reports one failure instead of the several it caused (measured against
# HEAD's calculator.tcl: `UNEXPECTED ERROR: bad window path name ".calc.sel"`
# with two checks never run).
proc gridfit {} {
    set got  [pcall winfo width    .calc.sel]
    set want [pcall winfo reqwidth .calc.sel]
    if {![string is integer -strict $got] || ![string is integer -strict $want]} {
        return NO-GRID
    }
    return [expr {$got >= $want ? {fits} : "clipped($got/$want)"}]
}
check "S21 the grid is not clipped at the declared minimum" [gridfit] fits

# ...and the clip must not be able to come back through the persisted geometry:
# a saved-too-small window is corrected on the next open, not replayed.
calc::close
update idletasks
check "S21 reopen after a shrink returns .calc" [calc::open] .calc
update idletasks ; raise .calc ; update
check "S21 a reopened window is not clipped either" \
    [list [gridfit] [expr {[winfo width .calc] >= [lindex [pcall wm minsize .calc] 0]}]] \
    {fits 1}

# =============================================================================
# PHASE 1d (item 4) — the keypad (W29-W31, RULING-2) and the function browser
# (W26-W28) over the one catalogue table (R413).  Still INERT: a key press and
# a function click report through calc::status and insert nothing (insertion is
# plan phase 2 / phase 5).
#
#   S22  W29-W31: the keypad — the twelve OPERATOR keys the crew ruled and NO
#        digit key, the four user buttons, all inert and all speaking, and the
#        one -minsize item 4 was sent to re-judge
#   S23  W26-W28: the function browser — the category combobox, the canvas
#        list, the two scrollbars, per-entry colour/hover/click, and that
#        switching category really repopulates
#   S24  THE CATALOGUE, which is the most testable thing in the item and the
#        cheapest place to catch drift: arity, categories, the §3.2 token set
#        read back from the spec rather than from the implementation, every
#        emitted RPN token lexable, the disabled set, and no duplicate names
# =============================================================================

# a true first open again — S21 shrank the window and calc::geom persists
calc::close
update idletasks
array unset ::calc::sash
set ::calc::geom {}
check "S22 first open returns .calc" [calc::open] .calc
update idletasks
raise .calc
update

# --- S22 the keypad (W29-W31) ------------------------------------------------
# ⚠ THE KEY SET IS WRITTEN OUT HERE AS A LITERAL, not read back from
# calc::pad_keys: a test that asks the implementation what the layout is
# asserts nothing about the layout. This is RULING-2 (no digits) plus the
# crew's phase-1d ruling on the set, now in spec §4 W30 — the twelve OPERATOR
# tokens plot_raw_custom_data() lexes, four to a row.
# ⚠ ELEVEN of them are binary; `?` is the engine's ternary COND (save.c:2361,
# dispatched at save.c:2531-2536 under `stackptr2 > 2`, three operands). R510's
# two-operand button rule does not describe it and phase 4 owes it its own; the
# catalogue row and spec §4 W30 both say so, and S24 asserts they agree.
set padkeys {+ - * / ** ? == != > < >= <=}

check "S22 .calc.pad class" \
    [expr {[winfo exists .calc.pad] ? [winfo class .calc.pad] : {MISSING}}] Frame
check "S22 .calc.pad parent is .calc" [pcall winfo parent .calc.pad] .calc
check "S22 drawn in the Keypad pane" [pcall pack slaves .calc.pw.bot.pad] {.calc.pad}
# the stacking guard every `pack -in` row in this window has paid for: a widget
# packed into a non-parent maps BEHIND its siblings unless it is raised, and
# `ismapped` returns 1 for a widget that is completely obscured
set kids [pcall winfo children .calc]
check_true "S22 keypad stacks above the panedwindow" \
    [expr {[lsearch -exact $kids .calc.pad] > [lsearch -exact $kids .calc.pw]
           && [lsearch -exact $kids .calc.pad] >= 0}]
set padat NO-PAD
catch {
    set padcx [expr {[winfo rootx .calc.pad] + [winfo width  .calc.pad] / 2}]
    set padcy [expr {[winfo rooty .calc.pad] + [winfo height .calc.pad] / 2}]
    set padat [winfo containing $padcx $padcy]
}
check_true "S22 keypad is the topmost widget at its own centre" \
    [expr {$padat eq {.calc.pad} || [string match {.calc.pad.*} $padat]}]

# W30: .calc.pad.k<n>, n from 1, in reading order, one per token
set badkey {}
set n 1
foreach tok $padkeys {
    set w .calc.pad.k$n
    if {![winfo exists $w]} { lappend badkey k$n=MISSING ; incr n ; continue }
    if {[winfo class $w] ne {Button}}   { lappend badkey k$n=[winfo class $w] }
    if {[pcall $w cget -text] ne $tok}  { lappend badkey k$n=[pcall $w cget -text] }
    if {[btnstate $w] ne {normal}} { lappend badkey k$n=[btnstate $w] }
    incr n
}
check "S22 the twelve operator keys, in order, all pressable" $badkey {}
# ⚠ RULING-2's WHOLE POINT, asserted from the negative side: NO DIGIT KEY, and
# no thirteenth key either. A pad that grew a `7` back would pass every check
# above (it asserts k1..k12 only), so count the buttons and read every label.
set padbuttons {}
foreach w [pcall winfo children .calc.pad] {
    if {[pcall winfo class $w] eq {Button}} { lappend padbuttons $w }
}
check "S22 the pad holds exactly 12 keys + 4 user buttons, no strays" \
    [llength $padbuttons] 16
set digitkey {}
foreach w $padbuttons {
    set t [pcall $w cget -text]
    if {[string is double -strict $t] || $t eq {.} || $t eq {±}} {
        lappend digitkey $w=$t
    }
}
# ⚠ the COUNT rides along in every "nothing bad is present" check in this
# section. With no keypad at all the loops above are empty and every such check
# passes over the feature's total absence — measured against HEAD's
# calculator.tcl, where five of them did exactly that.
check "S22 no digit, decimal point or sign key (RULING-2)" \
    [list [llength $padbuttons] $digitkey] {16 {}}
check "S22 there is no k13, and there is a k12" \
    [list [winfo exists .calc.pad.k12] [winfo exists .calc.pad.k13]] {1 0}
# ...and every key emits a token the ENGINE really lexes. A key whose label is
# not in §3.2 is not a shortcut, it is a whole-expression -1 three phases later
# (§3.1). The 52 tokens are written out in S24 from the spec.
check "S22 the key set is the ruled twelve" [pcall calc::pad_keys] $padkeys

# W31: four user buttons, spec's labels
set baduser {}
foreach i {1 2 3 4} {
    set w .calc.pad.u$i
    if {![winfo exists $w]} { lappend baduser u$i=MISSING ; continue }
    if {[winfo class $w] ne {Button}} { lappend baduser u$i=[winfo class $w] }
    if {[pcall $w cget -text] ne "user $i"} { lappend baduser u$i=[pcall $w cget -text] }
}
check "S22 the four user buttons, with the spec's labels" $baduser {}
check "S22 there is no u5, and there is a u4" \
    [list [winfo exists .calc.pad.u4] [winfo exists .calc.pad.u5]] {1 0}

# the palette, on all sixteen at once — sampling one let fifteen revert
set padcolor {}
foreach w $padbuttons {
    if {[pcall $w cget -background] ne $c_panel}   { lappend padcolor $w-bg }
    if {[pcall $w cget -foreground] ne $c_fieldfg} { lappend padcolor $w-fg }
    if {[pcall $w cget -activebackground] ne $c_header} { lappend padcolor $w-abg }
}
check "S22 every key wears the palette" [list [llength $padbuttons] $padcolor] {16 {}}
check "S22 the pad frame wears the panel colour" \
    [pcall .calc.pad cget -background] $c_panel

# INERT, and R506: every key names itself and the phase that will implement it.
# Insertion at the caret is plan 2.2; the stack composition R510 asks of a
# binary operator button is phase 4.
pcall .calc.buf delete 1.0 end
pcall .calc.buf insert end {S22 INERT SENTINEL}
set padbuf [pcall .calc.buf get 1.0 end]
set padstk [pcall .calc.stk.list size]
set padsilent {}
set padpressed 0
set n 1
foreach tok $padkeys {
    pcall calc::status {}
    if {![string match ERR:* [pcall .calc.pad.k$n invoke]]} { incr padpressed }
    if {[pcall .calc.status.msg get] ne "operator $tok: not implemented (phase 2)"} {
        lappend padsilent k$n=[pcall .calc.status.msg get]
    }
    incr n
}
check "S22 every operator key names itself and its phase (R506)" $padsilent {}
set usersilent {}
foreach i {1 2 3 4} {
    pcall calc::status {}
    if {![string match ERR:* [pcall .calc.pad.u$i invoke]]} { incr padpressed }
    if {[pcall .calc.status.msg get] ne "user $i: not implemented (phase 9)"} {
        lappend usersilent u$i=[pcall .calc.status.msg get]
    }
}
check "S22 every user button names itself and its phase (R506)" $usersilent {}
check_true "S22 the pre-press snapshot is real text" \
    [expr {![string match ERR:* $padbuf] && [string match {*INERT SENTINEL*} $padbuf]
           && [string is integer -strict $padstk]}]
# ⚠ the press COUNT is part of the purity assertion: "nothing was pressed" and
# "everything was pressed and touched nothing" are the same green otherwise.
check "S22 no key touched the buffer" \
    [list $padpressed \
          [expr {[string match ERR:* $padbuf] ? {NO-SNAPSHOT-TO-COMPARE}
                                              : [pcall .calc.buf get 1.0 end]}]] \
    [list 16 $padbuf]
check "S22 no key touched the stack" \
    [list $padpressed \
          [expr {[string is integer -strict $padstk] ? [pcall .calc.stk.list size]
                                                     : {NO-SNAPSHOT-TO-COMPARE}}]] \
    [list 16 $padstk]
pcall .calc.buf delete 1.0 end

# THE ONE -minsize ITEM 4 WAS SENT TO RE-JUDGE (phase-0 receipt: "the keypad
# pane sits at its 140px minimum, against ~115px in the reference — phase 1 puts
# real buttons there and that is when the number should be judged").
# S4 still pins the NUMBER, which did not change. This pins the JUDGEMENT: it
# must be at least what the pane's contents ask for, so a keypad that grows
# carries the minimum with it instead of clipping — spec §4.2 rule 1's rule,
# applied to a pane. (Measured: -minsize 128 let the first-open sash give the
# pane 138 and the keypad rendered 2 px narrower than it asked for.)
set padmin [pcall .calc.pw.bot panecget .calc.pw.bot.pad -minsize]
set padreq [pcall winfo reqwidth .calc.pw.bot.pad]
# ⚠ "the pane holds the keypad" is part of the assertion. An EMPTY pane requests
# almost nothing and any minimum covers it, which is how this passed against a
# tree with no keypad in it at all (measured).
check "S22 the keypad pane's minimum covers what it holds" \
    [list [pcall pack slaves .calc.pw.bot.pad] \
          [expr {[string is integer -strict $padmin] && [string is integer -strict $padreq]
                 && $padreq > 0 && $padmin >= $padreq}]] \
    {.calc.pad 1}
# ...and at first open it really got it: a cget cannot see a clipped keypad
proc padfit {} {
    set got  [pcall winfo width    .calc.pad]
    set want [pcall winfo reqwidth .calc.pad]
    if {![string is integer -strict $got] || ![string is integer -strict $want]} {
        return NO-KEYPAD
    }
    return [expr {$got >= $want ? {fits} : "clipped($got/$want)"}]
}
check "S22 the keypad is not squeezed at first open" [padfit] fits
# ...and the SAME RULE ON THE PANE THAT HOLDS IT, vertically. Item 4 re-judged
# the pad pane's WIDTH and left the height minimum of `.calc.pw.bot` at phase
# 0's 140 while filling it took its request from 67 to 158: dragging the bottom
# sash to its own legal floor then gave the pane 140 and clipped `user 3` and
# `user 4` by 3 px. A minimum that hides a control is not a minimum.
set botmin [pcall .calc.pw panecget .calc.pw.bot -minsize]
set botreq [pcall winfo reqheight .calc.pw.bot]
check "S22 the bottom pane's minimum covers what it holds, vertically too" \
    [list [pcall winfo children .calc.pw.bot] \
          [expr {[string is integer -strict $botmin] && [string is integer -strict $botreq]
                 && $botreq > 100 && $botmin >= $botreq}]] \
    {{.calc.pw.bot.fn .calc.pw.bot.pad} 1}
# ...and it is not vacuous: DRAG the sash to the floor and read the pixels. A
# cget cannot see a clipped user button (the S21 lesson, applied to a drag).
# ⚠ EVERY number is proved to BE a number before it reaches `expr`, and every
# widget is proved to exist. A bare `winfo rooty .calc.pad` against a tree with
# no keypad throws, the outer catch swallows the rest of the FILE, and S23/S24
# never run at all — which is the same trap this file's other geometry loops
# already record, arriving here through a proc instead of a loop.
proc botdrag_overflow {} {
    if {![winfo exists .calc.pw] || ![winfo exists .calc.pad]} { return NO-KEYPAD }
    set co [pcall .calc.pw sash coord 2]
    if {[llength $co] != 2} { return NO-SASH }
    foreach {sx sy} $co break
    if {![string is integer -strict $sx] || ![string is integer -strict $sy]} {
        return NO-SASH
    }
    set h [pcall winfo height .calc.pw]
    if {![string is integer -strict $h]} { return NO-PW }
    pcall .calc.pw sash place 2 $sx $h
    update idletasks
    set over {}
    set padbot [expr {[winfo rooty .calc.pad] + [winfo height .calc.pad]}]
    foreach u {u1 u2 u3 u4} {
        set w .calc.pad.$u
        if {![winfo exists $w]} { lappend over $u=MISSING ; continue }
        set wb [expr {[winfo rooty $w] + [winfo height $w]}]
        if {$wb > $padbot} { lappend over $u=[expr {$wb - $padbot}] }
    }
    # put it back where the first-open layout had it
    pcall .calc.pw sash place 2 $sx $sy
    update idletasks
    return $over
}
check "S22 the user buttons survive a drag to the bottom pane's own minimum" \
    [botdrag_overflow] {}
# every key on screen, by pixels, not by ismapped
set padoff {}
foreach w $padbuttons {
    set cx [expr {[winfo rootx $w] + [winfo width  $w] / 2}]
    set cy [expr {[winfo rooty $w] + [winfo height $w] / 2}]
    if {[pcall winfo containing $cx $cy] ne $w} { lappend padoff $w }
}
check "S22 all sixteen keypad buttons are on screen at first open" \
    [list [llength $padbuttons] $padoff] {16 {}}

# --- S23 the function browser (W26-W28) --------------------------------------
check "S23 .calc.fn class" \
    [expr {[winfo exists .calc.fn] ? [winfo class .calc.fn] : {MISSING}}] Frame
check "S23 .calc.fn parent is .calc" [pcall winfo parent .calc.fn] .calc
check "S23 drawn in the Functions pane" [pcall pack slaves .calc.pw.bot.fn] {.calc.fn}
# THE SAME STACKING GUARD THE KEYPAD CARRIES, on the item's larger payload.
# `.calc.fn` is `pack -in` a non-parent exactly as `.calc.pad` is, so it maps
# BEHIND its siblings unless it was created after them or raised — and
# `winfo ismapped` returns 1 for a browser that is wholly obscured. Measured:
# appending `lower .calc.fn` to calc::build_panes left all checks green while
# `winfo containing` at both .calc.fn's centre and .calc.fn.list's centre
# returned `.calc.pw.bot.fn`, i.e. the empty pane in front of the 56 names.
set kids [pcall winfo children .calc]
check_true "S23 the function browser stacks above the panedwindow" \
    [expr {[lsearch -exact $kids .calc.fn] > [lsearch -exact $kids .calc.pw]
           && [lsearch -exact $kids .calc.fn] >= 0}]
set fnat NO-FN
catch {
    set fncx [expr {[winfo rootx .calc.fn] + [winfo width  .calc.fn] / 2}]
    set fncy [expr {[winfo rooty .calc.fn] + [winfo height .calc.fn] / 2}]
    set fnat [winfo containing $fncx $fncy]
}
check_true "S23 the function browser is the topmost widget at its own centre" \
    [expr {$fnat eq {.calc.fn} || [string match {.calc.fn.*} $fnat]}]
# ...and the LIST itself, not just the frame: the frame could be on top with the
# canvas the thing that is covered.
set fnlat NO-LIST
catch {
    set flx [expr {[winfo rootx .calc.fn.list] + [winfo width  .calc.fn.list] / 2}]
    set fly [expr {[winfo rooty .calc.fn.list] + [winfo height .calc.fn.list] / 2}]
    set fnlat [winfo containing $flx $fly]
}
check "S23 the function LIST is the topmost widget at its own centre" \
    $fnlat {.calc.fn.list}
check "S23 .calc.fn.cat class" \
    [expr {[winfo exists .calc.fn.cat] ? [winfo class .calc.fn.cat] : {MISSING}}] TCombobox
check "S23 .calc.fn.list class" \
    [expr {[winfo exists .calc.fn.list] ? [winfo class .calc.fn.list] : {MISSING}}] Canvas

# W27: §7.1's categories verbatim, initial `Special Functions`. Written out as
# a literal from the spec, not read back from calc::fn_categories.
set fncats {{Special Functions} Arithmetic Trigonometric Exponential Complex
            Sequence Constants All}
check "S23 the category values are §7.1's, in order" \
    [pcall .calc.fn.cat cget -values] $fncats
check "S23 the initial category is Special Functions" \
    [pcall .calc.fn.cat get] {Special Functions}
check "S23 the category chooser is readonly" [pcall .calc.fn.cat cget -state] readonly
check_true "S23 the chooser binds combo_letter_cycle" \
    [string match {*combo_letter_cycle*} [pcall bind .calc.fn.cat <Key>]]
# ⚠ not the status history's style: Calc.TCombobox carries a -postoffset that
# drags its popdown ~460 px left, which is right for a 2-character button at the
# window's right edge and wrong for this one.
check "S23 the chooser does not borrow the status history's offset style" \
    [pcall .calc.fn.cat cget -style] {Calc.Field.TCombobox}

# the list is painted from the palette, and the two scrollbars with it
check "S23 the list wears the field colour" \
    [pcall .calc.fn.list cget -background] $c_field
set fnsb {}
foreach {sb cmd} {.calc.fn.hsb {.calc.fn.list xview} .calc.fn.vsb {.calc.fn.list yview}} {
    if {![winfo exists $sb]} { lappend fnsb $sb=MISSING ; continue }
    if {[pcall winfo class $sb] ne {Scrollbar}} { lappend fnsb $sb=[pcall winfo class $sb] }
    if {[pcall $sb cget -command] ne $cmd} { lappend fnsb $sb=[pcall $sb cget -command] }
    if {[pcall $sb cget -background] ne $c_panel} { lappend fnsb $sb-bg }
    if {[pcall $sb cget -troughcolor] ne $c_header} { lappend fnsb $sb-trough }
}
check "S23 both scrollbars exist, drive the list and wear the palette" $fnsb {}
check "S23 the horizontal scrollbar is the horizontal one" \
    [pcall .calc.fn.hsb cget -orient] horizontal
# ⚠ THE WIRE BACK, which the scrollbar->list direction above does not cover.
# Delete the canvas's two -*scrollcommand options and the bars are dead
# decoration: no thumb, `get` stuck at `0 0 0 0` forever, dragging one still
# scrolls (that is the -command above) but neither ever reports where the view
# IS. Measured: with the two lines deleted the whole suite stayed green.
check "S23 the list reports its view back to both scrollbars" \
    [list [pcall .calc.fn.list cget -xscrollcommand] \
          [pcall .calc.fn.list cget -yscrollcommand]] \
    {{.calc.fn.hsb set} {.calc.fn.vsb set}}

# W28 "horizontally scrollable" is a CLAIM ABOUT PIXELS: an h-scrollbar over a
# scrollregion no wider than the canvas is pure decoration (the measured trap
# recon/widgets.md §4d records for the browser's treeview). Assert the list is
# really wider than its window at the default size.
set sr [pcall .calc.fn.list cget -scrollregion]
# ⚠ every number here is proved to BE a number first. `pcall` returns
# "ERR:invalid command name .calc.fn.list", which is a four-element list whose
# third element compares greater than a width that is also an error string — so
# both of these passed against a tree with no function browser in it (measured).
proc srnum {sr i} {
    if {[llength $sr] != 4} { return {} }
    set v [lindex $sr $i]
    if {![string is double -strict $v]} { return {} }
    return $v
}
check_true "S23 the scrollregion is a real four-tuple" \
    [expr {[srnum $sr 2] ne {} && [srnum $sr 3] ne {}
           && [srnum $sr 2] > 0 && [srnum $sr 3] > 0}]
check_true "S23 the six columns are wider than the visible list, so the h-scrollbar scrolls" \
    [expr {[srnum $sr 2] ne {} && [string is integer -strict [pcall winfo width .calc.fn.list]]
           && [srnum $sr 2] > [pcall winfo width .calc.fn.list]}]
# ⚠ READ IT OFF THE SCROLLBAR, not off the canvas. The check is named for what
# the h-scrollbar shows, and `.calc.fn.list xview` is the canvas's own opinion —
# true even when the bar was never wired to hear it. `.calc.fn.hsb get` is a
# two-element float pair ONLY if the canvas really called `.calc.fn.hsb set`;
# an unwired scrollbar returns the four zeros `0 0 0 0` of an unset old-style
# bar. Same for the vertical one, which R112 makes load-bearing here.
set hsbv [pcall .calc.fn.hsb get]
set vsbv [pcall .calc.fn.vsb get]
proc sbpartial {v} {
    if {[llength $v] != 2} { return 0 }
    foreach e $v { if {![string is double -strict $e]} { return 0 } }
    return [expr {[lindex $v 0] >= 0.0 && [lindex $v 1] < 1.0
                  && [lindex $v 1] > [lindex $v 0]}]
}
check_true "S23 the horizontal scrollbar reports a partial view" [sbpartial $hsbv]
check_true "S23 the vertical scrollbar reports a partial view too (R112)" \
    [sbpartial $vsbv]

# every entry of the default category is on the canvas, ONE item each.
# ⚠ the ERR string is flattened to the empty list HERE, once: without it the
# geometry loops below feed "ERR:invalid" to `expr` as a float and the whole
# file dies in the outer catch with S24 never run (measured against HEAD).
set fnitems [pcall .calc.fn.list find withtag fnentry]
if {[string match ERR:* $fnitems]} { set fnitems {} }
set fnnames {}
foreach id $fnitems { lappend fnnames [pcall .calc.fn.list itemcget $id -text] }
check "S23 the default category renders all 56 of its entries" [llength $fnitems] 56
check "S23 ...and they are the catalogue's names, alphabetically" \
    [list [llength $fnnames] $fnnames] [list 56 [lsort -dictionary $fnnames]]
set catnames {}
foreach row [pcall calc::fn_entries {Special Functions}] { lappend catnames [lindex $row 0] }
check "S23 the rendered names are exactly the table's for that category" \
    [lsort -dictionary $fnnames] [lsort -dictionary $catnames]

# COLUMN-MAJOR, six columns: the reference's layout, and the thing that makes
# the horizontal scrollbar the right one. Read the geometry back off the canvas.
set xs {}
foreach id $fnitems {
    set x [lindex [pcall .calc.fn.list coords $id] 0]
    if {[lsearch -exact $xs $x] < 0} { lappend xs $x }
}
check "S23 the entries are laid out in six columns" [llength $xs] 6
# ...and DOWN each column, not across: the first six names alphabetically must
# NOT be the first row. (An across-the-row layout puts them side by side.)
set firstcol {}
set x0 [lindex [lsort -real $xs] 0]
foreach id $fnitems {
    if {[lindex [pcall .calc.fn.list coords $id] 0] == $x0} {
        lappend firstcol [list [lindex [pcall .calc.fn.list coords $id] 1] \
                               [pcall .calc.fn.list itemcget $id -text]]
    }
}
set firstcolnames {}
foreach e [lsort -real -index 0 $firstcol] { lappend firstcolnames [lindex $e 1] }
check "S23 the first column holds the first names, top to bottom (column-major)" \
    [list [llength $firstcolnames] $firstcolnames] \
    [list 10 [lrange [lsort -dictionary $catnames] 0 \
                     [expr {[llength $firstcolnames] - 1}]]]

# RULING-3: every N-route and every out-of-scope entry is RENDERED AND GREYED.
# The names are written out here from the ledger + §7.2, not read back.
set deadnames {dft psd convolve spectrum spectralPower harmonic harmonicFreq thd
               dftbb psdbb evmQAM evmQpsk pzbode pzfilter}
set badgrey {}
foreach id $fnitems {
    set nm [pcall .calc.fn.list itemcget $id -text]
    set fg [pcall .calc.fn.list itemcget $id -fill]
    set want [expr {[lsearch -exact $deadnames $nm] >= 0 ? $c_disabledfg : $c_fieldfg}]
    if {$fg ne $want} { lappend badgrey $nm=$fg }
}
check "S23 exactly the N-route and out-of-scope entries are greyed (RULING-3)" \
    [list [llength $fnitems] $badgrey] [list 56 {}]
check_true "S23 the greyed colour is not the live one (or the check above is vacuous)" \
    [expr {$c_disabledfg ne $c_fieldfg}]
check "S23 all fourteen greyed entries are RENDERED, not removed" \
    [llength [lsearch -all -inline -exact $fnnames dft]] 1
# ⚠ AND THE GREYING IS DERIVED FROM THE TABLE — the check above compares the
# render against a literal name list from the ledger, which is the right
# SPEC-side check and says nothing about WHERE the renderer got it. R413's "one
# table, not two" is a claim about the coupling: measured, replacing
# fn_fill's `lsearch $dead $route` with a hardcoded list of the fourteen names
# (literally the second table R413 forbids) left every check green. So assert
# the render against the ROUTE FIELD of the row, entry by entry.
set badcouple {}
foreach id $fnitems {
    set nm  [pcall .calc.fn.list itemcget $id -text]
    set fg  [pcall .calc.fn.list itemcget $id -fill]
    set row [pcall calc::fn_row $nm]
    if {[llength $row] != 6} { lappend badcouple $nm=NO-ROW ; continue }
    set deadrt [expr {[lsearch -exact [pcall calc::fn_dead_routes] [lindex $row 2]] >= 0}]
    set want [expr {$deadrt ? $c_disabledfg : $c_fieldfg}]
    if {$fg ne $want} { lappend badcouple $nm=route[lindex $row 2]/$fg }
}
check "S23 the greying is read off the table's route field, not a second list" \
    [list [llength $fnitems] $badcouple] [list 56 {}]
# ...and the coupling check above only sees a DIVERGENCE, so MAKE one: move the
# dead-route set at runtime and repaint. If fn_fill reads the table, every
# T-route special greys out with it; if it carries its own list of names,
# nothing moves. This is the check that a hardcoded second list cannot pass even
# when its contents happen to agree with the table today.
set greybefore 0
foreach id $fnitems {
    if {[pcall .calc.fn.list itemcget $id -fill] eq $c_disabledfg} { incr greybefore }
}
set greyafter 0
set greynames {}
# ⚠ guarded: against a tree with no browser these renames throw and the outer
# catch takes the rest of the FILE with them, S24 included.
if {[llength [info procs ::calc::fn_dead_routes]] == 1} {
    rename ::calc::fn_dead_routes ::calc::fn_dead_routes_SAVED
    proc ::calc::fn_dead_routes {} { return {N X T} }
    pcall calc::fn_fill
    update idletasks
    foreach id [pcall .calc.fn.list find withtag fnentry] {
        if {[pcall .calc.fn.list itemcget $id -fill] eq $c_disabledfg} {
            incr greyafter
            lappend greynames [pcall .calc.fn.list itemcget $id -text]
        }
    }
    rename ::calc::fn_dead_routes {}
    rename ::calc::fn_dead_routes_SAVED ::calc::fn_dead_routes
    pcall calc::fn_fill
    update idletasks
}
set greyrestored 0
foreach id [pcall .calc.fn.list find withtag fnentry] {
    if {[pcall .calc.fn.list itemcget $id -fill] eq $c_disabledfg} { incr greyrestored }
}
# 14 dead by N/X; +34 T-route specials (56 = 4 P + 4 C + 34 T + 8 N + 6 X) = 48
check "S23 moving the dead-route set repaints the greying (the table IS the source)" \
    [list $greybefore $greyafter $greyrestored \
          [expr {[lsearch -exact $greynames clip] >= 0}]] \
    {14 48 14 1}
# ⚠ two fn_fill calls have happened, so every canvas item id above is stale.
# Re-read them, or the per-entry binding and gesture legs below address items
# that no longer exist and pass over the wreckage.
set fnitems [pcall .calc.fn.list find withtag fnentry]
if {[string match ERR:* $fnitems]} { set fnitems {} }
set fnnames {}
foreach id $fnitems { lappend fnnames [pcall .calc.fn.list itemcget $id -text] }
check "S23 the repaint left the same 56 entries behind" \
    [list [llength $fnitems] [lsort -dictionary $fnnames]] \
    [list 56 [lsort -dictionary $catnames]]
# ...and the refusal a click gives comes from the SAME field, for every dead
# entry the browser drew — not from a per-name string beside the renderer.
set badrefuse {}
set nrefused 0
foreach id $fnitems {
    set nm  [pcall .calc.fn.list itemcget $id -text]
    set row [pcall calc::fn_row $nm]
    if {[llength $row] != 6} continue
    set why [pcall calc::fn_reason [lindex $row 2]]
    if {$why eq {}} continue
    incr nrefused
    pcall calc::status {}
    pcall calc::fn_click $nm
    if {[pcall .calc.status.msg get] ne "function $nm is not available: $why"} {
        lappend badrefuse $nm=[pcall .calc.status.msg get]
    }
}
# ⚠ the COUNT rides along: with nothing greyed the loop body never runs and an
# empty `badrefuse` would be the same green.
check "S23 every greyed entry refuses with its own route's reason" \
    [list $nrefused $badrefuse] {14 {}}
pcall calc::status {}

# per-ENTRY bindings, which is why this is a canvas and not a treeview (whose
# tags are per ROW) — assert the binding is attached to the item's own tag and
# carries its own name
proc fntag {id} {
    foreach t [pcall .calc.fn.list gettags $id] {
        if {[string match fn* $t] && $t ne {fnentry}} { return $t }
    }
    return {}
}
set badbind {}
foreach id $fnitems {
    set nm [pcall .calc.fn.list itemcget $id -text]
    set tg [fntag $id]
    if {$tg eq {}} { lappend badbind $nm=NO-TAG ; continue }
    foreach {ev want} [list <Button-1> "calc::fn_click $nm" \
                            <Enter>    "calc::fn_hover $nm"] {
        if {[pcall .calc.fn.list bind $tg $ev] ne $want} {
            lappend badbind $nm$ev=[pcall .calc.fn.list bind $tg $ev]
        }
    }
}
check "S23 every entry carries its own click and hover binding" \
    [list [llength $fnitems] $badbind] [list 56 {}]

# R413: hover writes THE TABLE'S help for that entry — and does not record it.
# ⚠ The no-record half is the crew's phase-1d amendment to R507 and it has
# teeth: 56 tooltips would evict the 50-entry history the user goes to to
# re-read what the tool told them.
pcall calc::status {}
set ::calc::statushist {}
pcall calc::status {a real event happened}
set histbeforehover [pcall calc::status_history]
pcall calc::fn_hover average
check "S23 hovering an entry shows its one-line help (R413)" \
    [pcall .calc.status.msg get] {Mean value of the wave over the X range}
check "S23 the help comes from the table, not a second one" \
    [pcall .calc.status.msg get] [lindex [pcall calc::fn_row average] 5]
# ⚠ the SHOWN line rides along, or "nothing was recorded" is also true of a
# hover that never happened (measured against HEAD, where it passed).
check "S23 hovering records nothing in the history" \
    [list [pcall .calc.status.msg get] [pcall calc::status_history]] \
    [list {Mean value of the wave over the X range} $histbeforehover]
check_true "S23 the pre-hover history snapshot is real" \
    [expr {[llength $histbeforehover] == 1}]
# ⚠ A <Leave> ON A DIFFERENT ENTRY MUST NOT RETIRE THIS ONE'S LINE. The guard
# is per entry — that is what the `name` argument of calc::fn_unhover is for —
# and the canvas really does deliver a <Leave> for the entry you came from after
# the <Enter> of the one you are on. Guarding on the shared `fnhelp` alone made
# the argument dead code and let entry B's <Leave> wipe entry A's help.
check "S23 hovering B does not let A's <Leave> wipe B's line" \
    [list [pcall calc::fn_unhover dft] [pcall .calc.status.msg get]] \
    [list {} {Mean value of the wave over the X range}]
pcall calc::fn_unhover average
check "S23 leaving retires the help line" [pcall .calc.status.msg get] {}
# ...and a <Leave> must not wipe a line somebody else wrote in between
set hovok [pcall calc::fn_hover average]
pcall calc::status {something else entirely}
pcall calc::fn_unhover average
check "S23 leaving does not wipe a message written after the hover" \
    [list $hovok [pcall .calc.status.msg get]] \
    [list {Mean value of the wave over the X range} {something else entirely}]

# a click is INERT and says so; a greyed one refuses and says WHY (RULING-3)
pcall .calc.buf delete 1.0 end
pcall .calc.buf insert end {S23 INERT SENTINEL}
set fnbuf [pcall .calc.buf get 1.0 end]
set fnclicked 0
foreach nm {average dft pzbode} {
    if {![string match ERR:* [pcall calc::fn_click $nm]]} { incr fnclicked }
}
pcall calc::status {}
pcall calc::fn_click average
check "S23 clicking a live entry is inert and names its phase" \
    [pcall .calc.status.msg get] {function average: not implemented (phase 5)}
pcall calc::status {}
pcall calc::fn_click dft
check "S23 clicking an N-route entry explains why it cannot be used" \
    [pcall .calc.status.msg get] \
    {function dft is not available: needs a C opcode not in v1}
pcall calc::status {}
pcall calc::fn_click pzbode
check "S23 clicking an out-of-scope entry explains why too" \
    [pcall .calc.status.msg get] {function pzbode is not available: out of scope in v1}
check_true "S23 the pre-click buffer snapshot is real text" \
    [expr {![string match ERR:* $fnbuf] && [string match {*INERT SENTINEL*} $fnbuf]}]
# ⚠ the click COUNT rides along: "nothing was clicked" and "everything was
# clicked and touched nothing" are the same green otherwise (the S22 lesson).
check "S23 no function click touched the buffer" \
    [list $fnclicked \
          [expr {[string match ERR:* $fnbuf] ? {NO-SNAPSHOT-TO-COMPARE}
                                             : [pcall .calc.buf get 1.0 end]}]] \
    [list 3 $fnbuf]
check "S23 no function click touched the stack" \
    [list $fnclicked [pcall .calc.stk.list size]] {3 0}
pcall .calc.buf delete 1.0 end

# ...and the wiring really reaches the handler from a real pointer gesture, not
# only from a direct call. A canvas dispatches item bindings off its own
# current-item tracking, so the <Motion> is not optional.
set clickable [lindex $fnitems 0]
set cname [pcall .calc.fn.list itemcget $clickable -text]
set bb [pcall .calc.fn.list bbox $clickable]
set gestured NO-GESTURE
# ⚠ all four numeric, not just four elements: `ERR:invalid command name
# ".calc.fn.list"` IS a four-element list, and feeding it to expr took the whole
# file down in the outer catch with S24 never run (measured against HEAD).
set bbok 1
foreach v $bb { if {![string is double -strict $v]} { set bbok 0 } }
if {[llength $bb] == 4 && $bbok} {
    set gx [expr {int(([lindex $bb 0] + [lindex $bb 2]) / 2 - [.calc.fn.list canvasx 0])}]
    set gy [expr {int(([lindex $bb 1] + [lindex $bb 3]) / 2 - [.calc.fn.list canvasy 0])}]
    pcall calc::status {}
    pcall event generate .calc.fn.list <Motion> -x $gx -y $gy
    pcall event generate .calc.fn.list <Button-1> -x $gx -y $gy
    pcall event generate .calc.fn.list <ButtonRelease-1> -x $gx -y $gy
    update idletasks
    set gestured [pcall .calc.status.msg get]
}
check "S23 a real click on an entry reaches its handler" \
    $gestured "function $cname: not implemented (phase 5)"

# switching category REPOPULATES (plan 1.6's "done when")
pcall .calc.fn.cat set {Constants}
pcall event generate .calc.fn.cat <<ComboboxSelected>>
update idletasks
set constnames {}
foreach id [pcall .calc.fn.list find withtag fnentry] {
    lappend constnames [pcall .calc.fn.list itemcget $id -text]
}
check "S23 switching category repopulates the list" \
    [lsort -dictionary $constnames] {e() k() pi() q()}
check "S23 the category switch says what it did (R506)" \
    [pcall .calc.status.msg get] {functions: Constants (4 entries)}
pcall .calc.fn.cat set {All}
pcall event generate .calc.fn.cat <<ComboboxSelected>>
update idletasks
check "S23 the All category shows every row of the table" \
    [list [llength [pcall .calc.fn.list find withtag fnentry]] \
          [llength [pcall calc::catalogue]]] {108 108}

# A REPOPULATE MUST ALSO RESET THE VIEW. A canvas keeps its xview/yview across
# a `delete all`; only the scrollregion changes. Measured before the fix:
# scroll `All` to its far corner — which is exactly what dragging .calc.fn.hsb
# does, its -command IS `.calc.fn.list xview` — then switch to Special
# Functions, and 28 of the 56 entries were off-screen with the whole
# alphabetical head (`average`, `bandwidth`, `clip`, `compare`) above the top
# edge. Both axes, and BOTH must be scrolled first or the small categories
# clamp the view to 0 by themselves and the check proves nothing.
pcall .calc.fn.list xview moveto 1.0
pcall .calc.fn.list yview moveto 1.0
update idletasks
set scrolledaway [list [lindex [pcall .calc.fn.list xview] 0] \
                       [lindex [pcall .calc.fn.list yview] 0]]
check_true "S23 fixture: the list really was scrolled off its origin first" \
    [expr {[string is double -strict [lindex $scrolledaway 0]]
           && [string is double -strict [lindex $scrolledaway 1]]
           && [lindex $scrolledaway 0] > 0.1 && [lindex $scrolledaway 1] > 0.1}]
pcall .calc.fn.cat set {Special Functions}
pcall event generate .calc.fn.cat <<ComboboxSelected>>
update idletasks
check "S23 switching category scrolls the new list back to its top-left" \
    [list [lindex [pcall .calc.fn.list xview] 0] [lindex [pcall .calc.fn.list yview] 0]] \
    {0.0 0.0}
# ...and it is the ENTRIES that came back on screen, not just two numbers: every
# one of the 56 must be inside the visible window after the switch.
# ⚠ every number proved numeric before `expr` sees it: `ERR:invalid command
# name ".calc.fn.list"` is a list too, and feeding it to expr takes the whole
# FILE down in the outer catch with S24 never run (the trap this file records
# twice already).
set offview {}
set vw [pcall winfo width  .calc.fn.list]
set vh [pcall winfo height .calc.fn.list]
set ox [pcall .calc.fn.list canvasx 0]
set oy [pcall .calc.fn.list canvasy 0]
set nseen 0
set viewok [expr {[string is integer -strict $vw] && [string is integer -strict $vh]
                  && [string is double -strict $ox] && [string is double -strict $oy]}]
foreach id [pcall .calc.fn.list find withtag fnentry] {
    set bb [pcall .calc.fn.list bbox $id]
    set bbok $viewok
    if {[llength $bb] != 4} { set bbok 0 }
    if {$bbok} { foreach v $bb { if {![string is double -strict $v]} { set bbok 0 } } }
    if {!$bbok} { lappend offview NO-BBOX ; continue }
    incr nseen
    set x0 [expr {[lindex $bb 0] - $ox}]
    set y0 [expr {[lindex $bb 1] - $oy}]
    set x1 [expr {[lindex $bb 2] - $ox}]
    set y1 [expr {[lindex $bb 3] - $oy}]
    if {$x0 < 0 || $y0 < 0 || $x1 > $vw || $y1 > $vh} {
        lappend offview [pcall .calc.fn.list itemcget $id -text]
    }
}
# ⚠ NOT asserted empty: at the default size the six columns are deliberately
# wider than the pane (that is what the h-scrollbar is FOR), so some entries are
# legitimately off to the right. What must be true is that the head of the
# alphabet is back — before the fix `average` itself was above the top edge.
check "S23 ...and the head of the alphabet is on screen again" \
    [list $nseen [lsearch -exact $offview average] [lsearch -exact $offview bandwidth] \
          [lsearch -exact $offview clip]] {56 -1 -1 -1}

# --- S24 the catalogue table (R413's "one table, not two") -------------------
# ⚠ THE SPEC'S §3.2 TOKEN LIST, WRITTEN OUT HERE. This is the whole point of
# the section: a wrong `insert` string is a silent -1 from the engine three
# phases from now (§3.1 — one unknown token poisons the WHOLE expression), and
# it is undebuggable there. 52 tokens, copied from the spec's §3.2 table, which
# recon/catalogue_primitives.tclpart verified equals the 52 `strcmp(n, "…")`
# arms in plot_raw_custom_data() (src/save.c:2414-2497) set-difference empty in
# both directions.
set tok32 {+ - * / ** == != > < >= <= ?
           sin() cos() tan() asin() acos() atan()
           sinh() cosh() tanh() asinh() acosh() atanh()
           exp() ln() log10() db20()
           abs() sgn() sqrt()
           re() im() cph()
           integ() deriv() deriv0() deriv2() deriv20()
           avg() ravg() max() min()
           prev() del() idx()
           dup() exch()
           pi() k() e() q()}
check "S24 fixture: the spec's §3.2 lists 52 tokens" [llength $tok32] 52

set rows [pcall calc::catalogue]
check_true "S24 the catalogue is a real, non-empty list" \
    [expr {![string match ERR:* $rows] && [llength $rows] > 100}]
# every row is a well-formed list of the FIXED arity, with no empty field where
# the schema does not allow one
check "S24 the schema is the six ruled fields" [pcall calc::fn_fields] \
    {name category route returns insert help}
set badrow {}
foreach row $rows {
    if {[catch {llength $row} L] || $L != 6} { lappend badrow [lindex $row 0]=arity$L ; continue }
    foreach {name category route returns insert help} $row break
    if {$name eq {}}     { lappend badrow (blank-name) }
    if {$category eq {}} { lappend badrow $name=no-category }
    if {[lsearch -exact {P C T N X} $route] < 0} { lappend badrow $name=route$route }
    if {[lsearch -exact {scalar wave bool scalar/wave} $returns] < 0} {
        lappend badrow $name=returns$returns
    }
    if {[string trim $help] eq {}} { lappend badrow $name=no-help }
}
check "S24 every row is a well-formed six-field row" $badrow {}

# EVERY §7.1 CATEGORY IS NON-EMPTY, including the synthetic All. A category
# that renders empty is the D1 defect, and D1 was one string away from shipping.
# ⚠ asserted as the COUNTS, not as "none of them is zero": with no catalogue at
# all `pcall calc::fn_entries` returns a four-word error string whose length is
# 4, so the emptiness form passed against a tree with no catalogue in it
# (measured). The numbers are §7.2's 56 specials and §3.2's 52 primitives split
# over six categories.
set catcounts {}
foreach cat $fncats { lappend catcounts [llength [pcall calc::fn_entries $cat]] }
check "S24 every §7.1 category has entries, in the spec's numbers" \
    $catcounts {56 26 12 4 3 3 4 108}
check "S24 the DEFAULT category is the one that must not be empty (D1)" \
    [llength [pcall calc::fn_entries {Special Functions}]] 56
# ...and no row carries a category that is not one of the eight (`All` being
# synthetic, no row may carry it either)
set badcat {}
foreach row $rows {
    set cat [lindex $row 1]
    if {[lsearch -exact $fncats $cat] < 0 || $cat eq {All}} { lappend badcat [lindex $row 0]=$cat }
}
check "S24 every row's category is a §7.1 value, and never the synthetic All" $badcat {}
check "S24 All is the union, not a category" \
    [list [llength [pcall calc::fn_entries All]] [llength $rows]] {108 108}

# NO TWO ROWS SHARE A NAME WITHIN A CATEGORY (and in fact not across the table:
# calc::fn_row looks a name up globally, so a global duplicate would silently
# shadow one of them)
array unset ::seen ; array set ::seen {}
set dupes {}
foreach row $rows {
    set key [lindex $row 1]/[lindex $row 0]
    if {[info exists ::seen($key)]} { lappend dupes $key }
    set ::seen($key) 1
}
check "S24 no two rows share a name within a category" \
    [list [llength $rows] $dupes] {108 {}}
array unset ::seen ; array set ::seen {}
set gdupes {}
foreach row $rows {
    set nm [lindex $row 0]
    if {[info exists ::seen($nm)]} { lappend gdupes $nm }
    set ::seen($nm) 1
}
check "S24 no name is duplicated across the whole table either" \
    [list [llength $rows] $gdupes] {108 {}}

# THE PRIMITIVES ARE §3.2, EXACTLY: one entry per token, inserting the token
# verbatim (§7.1: "everything in §3.2 is exposed through the non-Special
# categories, one entry per token, inserting the token verbatim")
set primnames {}
set badprim {}
foreach row $rows {
    if {[lindex $row 1] eq {Special Functions}} continue
    foreach {name category route returns insert help} $row break
    lappend primnames $name
    if {$route ne {P}}   { lappend badprim $name=route$route }
    if {$insert ne $name} { lappend badprim $name=inserts($insert) }
}
check "S24 the non-Special categories are exactly the §3.2 token set" \
    [lsort $primnames] [lsort $tok32]
check "S24 every primitive is route P and inserts itself verbatim" $badprim {}

# ⚠ `?` IS THE ODD ONE OUT AND ITS ROW MUST SAY SO. Eleven of the twelve keypad
# tokens are binary; `?` is the engine's COND (`#define COND 49`, src/save.c:2361)
# dispatched at src/save.c:2531-2536 inside `if(stackptr2 > 2) { /* 3 argument
# operators */ }` as `stack2[p-3] = stack2[p-2] ? stack2[p-3] : stack2[p-1];
# stackptr2 -= 2;` — THREE operands consumed. Phase 1d's first cut of spec §4
# W30 called the whole set "the twelve binary tokens" and grounded the ruling in
# R510's two-operand button semantics, which would have had phase 4 pop two
# entries: the guard is then false, COND never fires, and the expression
# silently yields an operand instead of a conditional. The table always got it
# right; this pins the table so the two cannot drift apart again.
set qrow [pcall calc::fn_row ?]
check "S24 the `?` row is on the keypad, in Arithmetic, emitting the bare token" \
    [list [expr {[lsearch -exact $padkeys ?] >= 0}] [lindex $qrow 1] [lindex $qrow 4]] \
    {1 Arithmetic ?}
check_true "S24 ...and its help states THREE operands, not two (COND, save.c:2361)" \
    [expr {[string match {*cond*} [lindex $qrow 5]]
           && [llength [lindex $qrow 5]] > 3
           && [string first {X cond Y} [lindex $qrow 5]] == 0}]

# EVERY EMITTED RPN STRING IS LEXABLE. This is the check that pays for itself:
# every whitespace-separated token of every `insert` must be either one of the
# 52 the engine knows or a number strtod/atof_spice can eat — anything else is
# §3.1's whole-expression -1, arriving phases later with no trace of its source.
set badtok {}
set nemit 0
foreach row $rows {
    foreach {name category route returns insert help} $row break
    if {$insert eq {}} continue
    incr nemit
    foreach t $insert {
        if {[lsearch -exact $tok32 $t] >= 0} continue
        if {[string is double -strict $t]} continue
        lappend badtok $name:$t
    }
}
# the count of rows that actually emitted something rides along, or a table
# that emits nothing at all passes this (measured against HEAD)
check "S24 every emitted token is one the engine lexes, or a number" \
    [list $nemit $badtok] {60 {}}
# ...and L3: a composed expression must CONTAIN WHITESPACE, or callers do not
# treat it as an expression at all (strpbrk(express, " \n\t"))
set badcomp {}
set ncomp 0
foreach row $rows {
    if {[lindex $row 2] ne {C}} continue
    incr ncomp
    if {[llength [lindex $row 4]] < 2} { lappend badcomp [lindex $row 0] }
}
check "S24 every C-route composition is more than one token (L3)" \
    [list $ncomp $badcomp] {4 {}}
# a route that cannot emit yet must emit NOTHING, rather than something wrong
set badempty {}
foreach row $rows {
    foreach {name category route returns insert help} $row break
    if {[lsearch -exact {T N X} $route] >= 0 && $insert ne {}} {
        lappend badempty $name=($insert)
    }
    if {[lsearch -exact {P C} $route] >= 0 && $insert eq {}} {
        lappend badempty $name=EMPTY
    }
}
check "S24 P and C rows emit, T/N/X rows emit nothing" \
    [list [llength $rows] $badempty] {108 {}}

# THE THREE AUDITED DEFECTS, each pinned by the row it was found in
# (recon/catalogue_defects.md D1-D3, D6).
check "S24 D1: the special rows carry the combobox's own category string" \
    [lindex [pcall calc::fn_row average] 1] {Special Functions}
check "S24 D2: lshift is a T route and emits nothing (the del() recipe reads out of bounds)" \
    [list [lindex [pcall calc::fn_row lshift] 2] [lindex [pcall calc::fn_row lshift] 4]] \
    {T {}}
check "S24 D3: integ and iinteg are no longer byte-identical rows" \
    [list [lindex [pcall calc::fn_row integ] 3] [lindex [pcall calc::fn_row iinteg] 3]] \
    {scalar wave}
check_true "S24 D3: ...and it is the returns field that separates them" \
    [expr {[pcall calc::fn_row integ] ne [pcall calc::fn_row iinteg]
           && [lindex [pcall calc::fn_row integ] 4] eq [lindex [pcall calc::fn_row iinteg] 4]}]
check "S24 D6: groupDelay carries the degrees-per-Hz conversion" \
    [lindex [pcall calc::fn_row groupDelay] 4] {cph() deriv() -360 /}

# ⚠ ALL FOUR C-ROUTE COMPOSITIONS, PINNED BY LITERAL. Everything above this
# asserts SHAPE — lexable tokens, more than one token, route C — and shape is
# not semantics: measured, rewriting `rms` to `dup() + avg() ln()`, `dBm` to
# `log10() 20 * 30 -` and `rmsNoise` to `dup() / integ() abs()` kept every one
# of those checks green while rms became a logarithm of a doubled cumulative
# mean and dBm lost both its factor of 10 and its +30. A wrong composition is
# not a crash, it is a plausible number three phases from now, and only the
# literal catches it. Each with the arithmetic it stands on:
#   rms       dup() *      -> x^2      avg()   -> mean(x^2)   sqrt()
#   rmsNoise  dup() *      -> x^2      integ() -> ∫x^2 df     sqrt()
#   dBm       log10() 10 * -> dB(W)    30 +    -> dBm
#   groupDelay cph() deriv() -> dφ/df in degrees/Hz, / -360 -> -dφ/dω in seconds
foreach {nm want} {
    rms        {dup() * avg() sqrt()}
    rmsNoise   {dup() * integ() sqrt()}
    dBm        {log10() 10 * 30 +}
    groupDelay {cph() deriv() -360 /}
} {
    check "S24 the C-route composition for $nm is exactly the ruled RPN" \
        [lindex [pcall calc::fn_row $nm] 4] $want
}
# ...and those four ARE the whole C-route set, or the block above pins a subset
set crows {}
foreach row $rows { if {[lindex $row 2] eq {C}} { lappend crows [lindex $row 0] } }
check "S24 ...and those are every C-route row there is" \
    [lsort $crows] {dBm groupDelay rms rmsNoise}

# RULING-3: the disabled set is exactly the N routes and the out-of-scope rows,
# and it is what the browser greys.
set deadrows {}
foreach row $rows {
    if {[lsearch -exact [pcall calc::fn_dead_routes] [lindex $row 2]] >= 0} {
        lappend deadrows [lindex $row 0]
    }
}
check "S24 the disabled set is the ledger's N routes plus the out-of-scope rows" \
    [lsort $deadrows] [lsort $deadnames]
check "S24 a live route has no refusal reason, a dead one does" \
    [list [pcall calc::fn_reason P] [pcall calc::fn_reason T] \
          [expr {[pcall calc::fn_reason N] ne {}}] [expr {[pcall calc::fn_reason X] ne {}}]] \
    {{} {} 1 1}
# every help line fits the status area it is written to (R413 + the item's
# "if the help does not fit the status line, shorten the help in the table")
set longhelp {}
foreach row $rows {
    if {[string length [lindex $row 5]] > 72} {
        lappend longhelp [lindex $row 0]=[string length [lindex $row 5]]
    }
}
check "S24 every help line is short enough for the status entry" \
    [list [llength $rows] $longhelp] {108 {}}
# ⚠ AND THE STRING fn_click ACTUALLY COMPOSES, which is the one that overflowed.
# The bound above covers the table's `help` field; the refusal a greyed entry
# gives is `function <name> is not available: <reason>` and is built at click
# time from two other fields, so nothing bounded it. Measured on the shipped
# 656x680 window: `.calc.status.msg` is 613 px wide in TkTextFont and the old
# N-route reason made the spectralPower line 94 characters / 666 px, of which 85
# rendered — the line ended "...no N-route function sh". RULING-3's whole point
# is that a greyed entry carries information; a sentence cut mid-word does not.
set longrefusal {}
set nrefusals 0
foreach row $rows {
    set why [pcall calc::fn_reason [lindex $row 2]]
    if {$why eq {}} continue
    incr nrefusals
    set line "function [lindex $row 0] is not available: $why"
    if {[string length $line] > 72} {
        lappend longrefusal [lindex $row 0]=[string length $line]
    }
}
check "S24 every refusal line fn_click composes fits the status entry too" \
    [list $nrefusals $longrefusal] {14 {}}

# --- S22-S24 teardown: the initial state is a property of the BUILD ----------
calc::close
update idletasks
check "S22 reopen returns .calc" [calc::open] .calc
update idletasks
check "S23 a fresh window opens on Special Functions" \
    [pcall .calc.fn.cat get] {Special Functions}
check "S23 a fresh window renders that category" \
    [llength [pcall .calc.fn.list find withtag fnentry]] 56
check "S22 a fresh window still has no digit key" \
    [list [winfo exists .calc.pad.k12] [winfo exists .calc.pad.k13]] {1 0}

# --- S25 mouse-wheel scrolling under the pointer (item 13, Part A) ------------
# The user's words, from the phase-1 eyeball pass: "should not require mouse
# pointer to be over the scrollbar to scroll. Must get vertical scroll with
# mouse scrollwheel if pointer is over the area that needs scrolling to make
# content visible".
#
# ⚠ A WHEEL CHECK IS EASY TO WRITE VACUOUSLY. `event generate <the widget that
# already scrolls> <Button-5>` proves nothing about the pointer being over a
# CHILD of the region — and two of the three regions here already scrolled over
# their own list, through Tk's Listbox/Text CLASS bindings, before this item
# existed. So every functional leg below fires over a widget that is NOT the
# scroll target and has NO wheel class binding of its own (a Button), except
# the function browser's, whose target is a canvas — and Canvas has no wheel
# class binding at all, which is asserted here as the fingerprint of the defect.
check "S25 fixture: Tk's Canvas class has NO wheel binding of its own" \
    [list [bind Canvas <Button-4>] [bind Canvas <Button-5>] [bind Canvas <MouseWheel>]] \
    {{} {} {}}
check_true "S25 fixture: Listbox and Text DO have one (so only a non-list child proves ours)" \
    [expr {[bind Listbox <Button-4>] ne {} && [bind Text <Button-4>] ne {}}]

# ⚠ THIS SECTION MUST NOT CALL calc::wheel_bind_all, and the first draft did —
# to read its per-region counts. That one line made every check below GREEN WITH
# THE BUILD'S OWN CALL DELETED (measured: sabotage A1, 483/483), because the
# test was installing the feature it was about to test. The counts are therefore
# MEASURED off the widgets instead: what the BUILD left behind is the subject.
proc s25_bound {w} {
    if {![winfo exists $w]} { return 0 }
    set n [expr {[bind $w <Button-4>] ne {} ? 1 : 0}]
    foreach c [winfo children $w] { incr n [s25_bound $c] }
    return $n
}
# ⚠ THE PANE HOLDER COUNTS. `.calc.fn`/`.calc.stk`/`.calc.buf` are children of
# `.calc` and are packed into the labelframes with `-in`, so the holder is NOT
# an ancestor in the widget tree and a walk rooted at the content frame cannot
# reach it. The holder is what draws the pane's title strip and the padding
# around the scrolling content — a measured 25.2% / 16.0% / 10.8% of the three
# panes' visible area — so it is bound as a root of its own region, and counted
# here as one widget each.
check "S25 the BUILD bound every widget of all three regions, holder included" \
    [list fn [expr {[pcall s25_bound .calc.pw.bot.fn] + [pcall s25_bound .calc.fn]}] \
          stk [expr {[pcall s25_bound .calc.pw.stk] + [pcall s25_bound .calc.stk]}] \
          buf [expr {[pcall s25_bound .calc.pw.buf] + [pcall s25_bound .calc.buf] \
                     + [pcall s25_bound .calc.btb]}]] \
    {fn 5 stk 8 buf 13}
check "S25 ...and the holder really is the pane title strip, not an ancestor" \
    [list [pcall winfo class .calc.pw.buf] [pcall winfo children .calc.pw.buf] \
          [pcall winfo parent .calc.buf]] \
    {Labelframe {} .calc}
# the six sequences, on a widget that is NOT the scroll target
foreach seq {<Button-4> <Button-5> <Shift-Button-4> <Shift-Button-5>
             <MouseWheel> <Shift-MouseWheel>} {
    check_true "S25 $seq bound on .calc.stk.push (a child, not the listbox)" \
        [expr {[pcall bind .calc.stk.push $seq] ne {}}]
}
# ...and it aims at the region's own target, with the region's own step
check "S25 the child's binding scrolls the STACK LIST, 5 units (Tk's own listbox step)" \
    [pcall bind .calc.stk.push <Button-4>] \
    {calc::wheel_scroll .calc.stk.list y -1 5 units; break}
check "S25 the buffer toolbar's binding scrolls the BUFFER, 50 pixels (Tk's own text step)" \
    [pcall bind .calc.btb.enter <Button-4>] \
    {calc::wheel_scroll .calc.buf y -1 50 pixels; break}
# ⚠ 3 canvas units, NOT property_form.tcl's 1 — the crew's item-13 ruling
# (R112a), and a measured number rather than a taste. This walk binds the
# scrollbars too and every binding `break`s, so it REPLACES Tk's Scrollbar class
# binding `tk::ScrollByUnits %W v 5`; at 1 unit the one place the wheel already
# worked became 3x slower (measured on :99: 0.0735294 per notch against Tk's
# 0.2205882), and the canvas region would have been the slowest in the window by
# a factor of four. 3 units restores the scrollbar's pre-item step to the last
# digit. The check that guards the FEEL, not just the text, is below.
check "S25 the function browser's is 3 canvas units (R112a, item 13 review)" \
    [pcall bind .calc.fn.vsb <Button-4>] \
    {calc::wheel_scroll .calc.fn.list y -1 3 units; break}
# the house exclusion (xschem.tcl:1589, and test_nh_editor_flush_scroll.tcl W2):
# a ttk::combobox keeps its own wheel, and the walk does not descend into one
check "S25 no wheel binding on the category combobox (its dropdown keeps its own)" \
    [pcall bind .calc.fn.cat <Button-4>] {}
check "S25 nor on the plot-destination or status-history comboboxes" \
    [list [pcall bind .calc.mode.dest <Button-4>] \
          [pcall bind .calc.status.hist <Button-4>]] {{} {}}
# ...and the history dropdown (W34) still scrolls, which is WHY it needs nothing
# from us: its popdown holds a real Listbox and Tk's class binding scrolls it.
# The popdown is a CHILD of the combobox and is built lazily, which is the other
# half of the exclusion — a walk that descended into a combobox would bind this
# listbox to scroll the FUNCTION list while the user scrolls this dropdown.
# ⚠ NOT a scroll gesture: the popdown listbox is EMPTY until the combobox is
# POSTED (measured — `size` 0 and `yview` {0.0 1.0} with 50 values on the
# combobox), and posting takes a grab, which is not worth risking in the last
# section of a 480-check file for a leg whose subject is Tk's own binding. What
# is asserted is what this file is responsible for: that the popdown carries the
# Listbox class tag (whose wheel binding the S25 fixture leg above proved
# exists) and NOT one of ours.
set pop [pcall ttk::combobox::PopdownWindow .calc.status.hist]
check "S25 the history popdown is a child of the combobox, and holds a Listbox" \
    [list [expr {$pop eq {.calc.status.hist.popdown}}] [pcall winfo class $pop.f.l]] \
    {1 Listbox}
check_true "S25 ...whose bindtags carry Listbox, so Tk's wheel binding reaches it" \
    [expr {[lsearch -exact [pcall bindtags $pop.f.l] Listbox] >= 0}]
check "S25 ...and it scrolls ITSELF, not the function browser" \
    [pcall bind $pop.f.l <Button-4>] {}

# --- and now the gesture itself, over a child, at real coordinates ------------
# ⚠ SETTLE, DON'T HOPE. The first draft of these legs did one `update idletasks`
# before the gesture and one `update` after, and went red once in seven runs on
# a byte-identical tree — the whole gesture cluster at once, always reporting
# "it did not move". The gesture-test rule in this tree (CLAUDE.md, and S12's
# own forced race) says drive the full sequence and make the race deterministic
# rather than let the environment supply it: the pane relayout that follows
# S24's teardown and the fixture inserts lands on an `after idle`, and if it
# lands between the `moveto 0` and the read, the view it recomputes is 0 again
# and the notch is invisible. So: pump to quiescence BEFORE measuring, and after
# the notch wait a BOUNDED time for the view to actually move. A view that never
# moves still fails — it just takes 200 ms to say so instead of 0.
proc s25_settle {} {
    for {set i 0} {$i < 5} {incr i} { update idletasks ; update ; after 5 }
    update idletasks ; update
}
# wait (bounded) for $tgt's $axis view to leave $from; returns where it ended up
proc s25_await {tgt axis from} {
    for {set i 0} {$i < 20} {incr i} {
        update idletasks ; update
        set now [lindex [$tgt ${axis}view] 0]
        if {$now != $from} { return $now }
        after 10
    }
    return [lindex [$tgt ${axis}view] 0]
}

# FIXTURE: content that really overflows. A view that cannot move cannot show
# that the wheel moved it.
for {set i 0} {$i < 40} {incr i} {
    .calc.stk.list insert end "stack entry $i [string repeat wide 20]"
}
for {set i 0} {$i < 40} {incr i} {
    .calc.buf insert end "line $i [string repeat x 60]\n"
}
s25_settle
check_true "S25 fixture: all three regions really do overflow their viewports" \
    [expr {[lindex [pcall .calc.fn.list yview] 1]  < 1.0
        && [lindex [pcall .calc.fn.list xview] 1]  < 1.0
        && [lindex [pcall .calc.stk.list yview] 1] < 1.0
        && [lindex [pcall .calc.stk.list xview] 1] < 1.0
        && [lindex [pcall .calc.buf yview] 1]      < 1.0}]

# helper: fire a wheel event ON A GIVEN WIDGET at a coordinate inside it, and
# report how far the region's target moved.
proc s25_wheel {w seq tgt axis} {
    s25_settle
    catch {$tgt ${axis}view moveto 0}
    s25_settle
    set before [lindex [$tgt ${axis}view] 0]
    set x [expr {[winfo width  $w] / 2}]
    set y [expr {[winfo height $w] / 2}]
    catch {event generate $w $seq -x $x -y $y}
    return [list $before [s25_await $tgt $axis $before]]
}

# THE HEADLINE: the pointer is over a BUTTON in the Stack region — not the
# listbox, not the scrollbar — and the list scrolls.
set r [pcall s25_wheel .calc.stk.push <Button-5> .calc.stk.list y]
check_true "S25 wheel over a Stack BUTTON scrolls the stack list down" \
    [expr {[lindex $r 0] == 0.0 && [lindex $r 1] > 0.0}]
set r [pcall s25_wheel .calc.stk.del <Shift-Button-5> .calc.stk.list x]
check_true "S25 Shift-wheel over a Stack button scrolls it sideways (house horizontal modifier)" \
    [expr {[lindex $r 0] == 0.0 && [lindex $r 1] > 0.0}]
# ...and the same for the buffer, over its TOOLBAR
set r [pcall s25_wheel .calc.btb.enter <Button-5> .calc.buf y]
check_true "S25 wheel over the buffer TOOLBAR scrolls the buffer" \
    [expr {[lindex $r 0] == 0.0 && [lindex $r 1] > 0.0}]
# ...and the function browser, whose canvas had no wheel of any kind before
set r [pcall s25_wheel .calc.fn.list <Button-5> .calc.fn.list y]
check_true "S25 wheel over the function list scrolls it vertically (R112)" \
    [expr {[lindex $r 0] == 0.0 && [lindex $r 1] > 0.0}]
set r [pcall s25_wheel .calc.fn.list <Shift-Button-5> .calc.fn.list x]
check_true "S25 Shift-wheel over the function list scrolls it horizontally (W28)" \
    [expr {[lindex $r 0] == 0.0 && [lindex $r 1] > 0.0}]
set r [pcall s25_wheel .calc.fn.hsb <Button-5> .calc.fn.list y]
check_true "S25 ...and over its horizontal scrollbar too (which Tk's own binding no-ops)" \
    [expr {[lindex $r 0] == 0.0 && [lindex $r 1] > 0.0}]
# ...and over the PANE TITLE STRIP, which is a slice of the pane the user sees
# and which a walk rooted at the content frame never reaches (the content frame
# is a child of .calc, packed in with -in).
set r [pcall s25_wheel .calc.pw.buf <Button-5> .calc.buf y]
check_true "S25 wheel over the BUFFER PANE's title strip scrolls the buffer" \
    [expr {[lindex $r 0] == 0.0 && [lindex $r 1] > 0.0}]
set r [pcall s25_wheel .calc.pw.bot.fn <Button-5> .calc.fn.list y]
check_true "S25 ...and over the FUNCTIONS pane's title strip" \
    [expr {[lindex $r 0] == 0.0 && [lindex $r 1] > 0.0}]
set r [pcall s25_wheel .calc.pw.stk <Button-5> .calc.stk.list y]
check_true "S25 ...and over the STACK pane's title strip" \
    [expr {[lindex $r 0] == 0.0 && [lindex $r 1] > 0.0}]

# THE FEEL, not just the binding text (item 13 review): one notch over the
# function browser's scrollbar must move it exactly as far as Tk's own Scrollbar
# class binding moved it BEFORE this walk bound over the top of it. At the
# house canvas step of 1 unit it was three times slower — the one place the
# wheel already worked, made worse. This is the check that reddens if anyone
# "restores" that step.
catch {.calc.fn.list yview moveto 0}
pcall s25_settle
catch {event generate .calc.fn.vsb <Button-5> -x 3 -y 30}
set fn_wheel [pcall s25_await .calc.fn.list y 0.0]
catch {.calc.fn.list yview moveto 0}
pcall s25_settle
pcall tk::ScrollByUnits .calc.fn.vsb v 5
pcall s25_settle
check "S25 one notch over the fn scrollbar is still Tk's own pre-item step" \
    $fn_wheel [lindex [pcall .calc.fn.list yview] 0]

# DIRECTION, the house/Tk convention: Button-4 is toward the start of the
# content. Scrolled down first, so "back to 0" is a real movement and not the
# clamp it would be from the top.
catch {.calc.stk.list yview moveto 0.5}
pcall s25_settle
set d0 [lindex [pcall .calc.stk.list yview] 0]
catch {event generate .calc.stk.push <Button-4> -x 5 -y 5}
set d1 [pcall s25_await .calc.stk.list y $d0]
check_true "S25 Button-4 scrolls UP (toward the start), Button-5 down" \
    [expr {$d0 > 0.0 && $d1 < $d0}]

# <MouseWheel>'s signed %D maps the same way (Windows/macOS, Tcl > 8.7)
catch {.calc.buf yview moveto 0.5}
pcall s25_settle
set m0 [lindex [pcall .calc.buf yview] 0]
catch {event generate .calc.btb.pop <MouseWheel> -delta 120 -x 5 -y 5}
set m1 [pcall s25_await .calc.buf y $m0]
catch {event generate .calc.btb.pop <MouseWheel> -delta -120 -x 5 -y 5}
set m2 [pcall s25_await .calc.buf y $m1]
check_true "S25 <MouseWheel> +%D scrolls up and -%D scrolls down, from the same child" \
    [expr {$m0 > 0.0 && $m1 < $m0 && $m2 > $m1}]

# ⚠ <Shift-MouseWheel> IS THE ONE THE FIRST DRAFT LEFT AS AN EXISTENCE CHECK,
# and it could therefore be pointed at the wrong AXIS with the sign REVERSED
# and stay green (measured: 487/487). It is the Windows/macOS half of W28's
# horizontal contract, so it gets the same two-direction gesture the vertical
# <MouseWheel> gets — over a Stack BUTTON, and asserting the list's XVIEW.
catch {.calc.stk.list xview moveto 0.5}
pcall s25_settle
set h0 [lindex [pcall .calc.stk.list xview] 0]
catch {event generate .calc.stk.push <Shift-MouseWheel> -delta 120 -x 5 -y 5}
set h1 [pcall s25_await .calc.stk.list x $h0]
catch {event generate .calc.stk.push <Shift-MouseWheel> -delta -120 -x 5 -y 5}
set h2 [pcall s25_await .calc.stk.list x $h1]
check_true "S25 <Shift-MouseWheel> moves the X axis, +%D left and -%D right" \
    [expr {$h0 > 0.0 && $h1 < $h0 && $h2 > $h1}]

# ⚠ EVERY BINDING `break`s, and this is what proves it. .calc.buf is a Text, so
# Tk's OWN class binding would also fire without the break and the wheel would
# scroll TWICE per notch — a defect no "did it move?" check can see. One notch
# must move the buffer exactly as far as one manual scroll of the same step.
catch {.calc.buf yview moveto 0}
pcall s25_settle
catch {event generate .calc.buf <Button-5> -x 5 -y 5}
set viawheel [pcall s25_await .calc.buf y 0.0]
catch {.calc.buf yview moveto 0}
catch {.calc.buf yview scroll 50 pixels}
pcall s25_settle
check "S25 one notch over the buffer scrolls it ONCE, not once per bindtag" \
    $viawheel [lindex [pcall .calc.buf yview] 0]

# re-running the walk is safe (nhse re-runs it after every rebuild): `bind`
# REPLACES, so nothing is doubled and no widget is bound twice. Deliberately the
# LAST leg of S25, after everything above has judged the build's own call.
#
# ⚠ COUNTS ALONE DO NOT ASSERT IDEMPOTENCE, which is what this check is named
# for. A walk that APPENDED (`bind $w $seq "+..."`) re-reports the identical
# counts and stays green on the return value — measured, 487/487 — while the
# binding script really does grow on each pass; nothing user-visible happens
# only because Tk's `break` aborts the appended copy, i.e. the check would be
# passing for a reason it does not test. So the BINDING TEXT is compared against
# the same literal used before the re-run, and the one-notch-moves-once
# measurement is repeated after it.
set bind_lit {calc::wheel_scroll .calc.stk.list y -1 5 units; break}
set bind_before [pcall bind .calc.stk.push <Button-4>]
set wcounts [pcall calc::wheel_bind_all]
check "S25 the walk reports what it bound, and re-running it changes nothing" \
    [list $wcounts [pcall s25_bound .calc.fn] [pcall s25_bound .calc.stk]] \
    {{fn 5 stk 8 buf 13} 4 7}
check "S25 ...the binding SCRIPT is byte-identical after the re-walk (bind replaces, never appends)" \
    [list $bind_before [pcall bind .calc.stk.push <Button-4>]] \
    [list $bind_lit $bind_lit]
catch {.calc.buf yview moveto 0}
pcall s25_settle
catch {event generate .calc.buf <Button-5> -x 5 -y 5}
check "S25 ...and one notch still moves the buffer exactly once after it" \
    [pcall s25_await .calc.buf y 0.0] $viawheel

# the fixture leaves nothing behind: the buffer and the stack are phase-2/4's
.calc.buf delete 1.0 end
.calc.stk.list delete 0 end
update idletasks
check "S25 fixture cleaned up" \
    [list [pcall .calc.stk.list size] [string trim [pcall .calc.buf get 1.0 end]]] {0 {}}

# --- S26 Results Dir against the SESSION'S result (item 13 Part C, RESTATED by
#     results batch item 10) --------------------------------------------------
#
# ⚠⚠ RESTATED, NOT DELETED, AND THE EXPECTATION GENUINELY CHANGED. As shipped,
# S26 pinned `calc::results_source`'s resolution as **self -> viewer -> ase ->
# none**, with the first arm reading `xschem raw rawfile` in THIS window's
# context. Two of those three arms are gone by ruling, and the third answers a
# different question:
#
#   * the `self` arm was removed ENTIRELY by the user on 2026-08-18 (U6,
#     doc/claude/specs/results_selection.md §17 decision 6). The Calculator
#     reads the ASE-L session's result and nothing else; it must never evaluate
#     against a raw a legacy path dropped into a schematic window's context.
#   * the `ase` arm's `ase::last_rawfile` derivation went with it (CREW RULING
#     R502a, spec §7.1a). It names a FILE ON DISK, not a selection, and under
#     U3 the row must name what Evaluate READS. `ase` survives as a PROVENANCE
#     — the borrowed context belongs to a live session — not as a path source.
#   * the borrowed read now asks `results::current` (R305) instead of
#     `xschem raw rawfile`. The two differ exactly where it matters: `raw
#     rawfile` names the current database even when it is a VCD or a table (L8)
#     and even when its stamp no longer resolves against the hierarchy stack
#     (F4), and naming one of those in a row that PICKS is how the Calculator
#     ends up evaluating against a database no signal name resolves in.
#
# ⚠ FIVE ELEMENTS, NOT THREE (fixer round). `calc::results_source` answers
# `{origin path detail type idx}`: a result is a SLOT, not a file, and the two
# trailing terms are what let `calc::require_result` hand phase 3 an analysis
# rather than a filename (U11 / R407c clause 1 / landmines L6, L10). Every
# expectation below carries them, which is why they read `... good_tok tran 0`
# and `{none {} {} {} {}}`.
#
# What did NOT change, and is asserted below exactly as before: the ACTIVE
# viewer answers first, a REFUSED loan is skipped rather than read as "that
# viewer has none", the loan is taken with borrow=1 and given back, the label
# says WHOSE the path is, the tooltip really reaches the widget, nothing is
# cached (R705), and the row re-resolves on expand and not on collapse.
#
# The shims sit one layer lower than they did: `results::current` is shimmed
# rather than `xschem raw rawfile`, because that is the reader item 10 put in
# calc::ctx_result. `calc::session_result`'s real loop (`src/calculator.tcl:924`)
# still runs against a fake registry and a fake 0173 loan bracket, so the ticket
# bail, the ordering and the give-back are all still exercised.
# (⚠ FIXER ROUND: this paragraph named `calc::viewer_raw`, the proc item 10
# DELETED — landmine L9's exact class, in text written fresh in the item. The
# subject is `calc::session_result`; S15 asserts its sibling reader is gone.)
check "S26 with nothing anywhere it is still the phase-1a wording" \
    [pcall calc::results_source] {none {} {} {} {}}
check "S26 ...and the label is untouched in that case" \
    [pcall .calc.res.lab cget -text] {Results Dir:}

set ::s26_log {}
set ::s26_inctx 0
# what a BORROWED context answers, and what THIS one answers. Two variables on
# purpose: U6's whole content is that the second is never used.
set ::s26_cur [dict create idx 0 path /tmp/s26/from_viewer.raw type tran cur 1 \
                   label {from_viewer.raw (tran)}]
set ::s26_here {}
# which token the loan is currently standing in, and which tokens answer "no
# result selected here" — the pair that lets the walk be driven past a context
# it CAN enter but that holds nothing.
set ::s26_tok {}
set ::s26_noresult {}
set ::s26_shimerr [catch {
    rename ::results::current ::calc_s26_current
    proc ::results::current {} {
        if {$::s26_inctx} {
            if {[lsearch -exact $::s26_noresult $::s26_tok] >= 0} { return {} }
            return $::s26_cur
        }
        return $::s26_here
    }
    rename ::wviewer::enter_ctx ::calc_s26_enter
    rename ::wviewer::leave_ctx ::calc_s26_leave
    proc ::wviewer::enter_ctx {token {borrow 0}} {
        lappend ::s26_log "enter $token borrow=$borrow"
        # a REFUSED loan is not an answer about that viewer (issues 0313/0314)
        if {$token eq {refused_tok}} { return {0 {}} }
        set ::s26_inctx 1
        set ::s26_tok $token
        return {1 .somewhere}
    }
    proc ::wviewer::leave_ctx {token ticket} {
        lappend ::s26_log "leave $token"
        set ::s26_inctx 0
        return 1
    }
    set ::s26_savedwin $::wviewer::windows
    set ::s26_savedsess $::ase::sessions
    set ::wviewer::windows [dict create \
        refused_tok [dict create win_path .nosuch1 top .nosuch1] \
        good_tok    [dict create win_path .nosuch2 top .nosuch2]]
    set ::ase::sessions [dict create]
} s26msg]
check "S26 shims installed cleanly" $::s26_shimerr 0

set src [pcall calc::results_source]
check "S26 the borrowed context's SELECTED RESULT is what the row reports" \
    $src {viewer /tmp/s26/from_viewer.raw good_tok tran 0}
check "S26 a REFUSED loan is skipped, not read as 'that viewer has none'" \
    [lsearch -exact $::s26_log {enter refused_tok borrow=1}] 0
check "S26 the loan is taken with borrow=1 (issue 0314: a menu open holds the semaphore)" \
    [lsearch -exact $::s26_log {enter good_tok borrow=1}] 1
check "S26 ...and given back (issue 0173: a switch clobbers the viewer's title)" \
    [lsearch -exact $::s26_log {leave good_tok}] 2
check "S26 no leave for the refused token — there was nothing to give back" \
    [lsearch -exact $::s26_log {leave refused_tok}] -1

pcall calc::results_refresh
check "S26 the entry shows the borrowed path in full" \
    [pcall .calc.res.path get] {/tmp/s26/from_viewer.raw}
check "S26 ...and the label SAYS whose it is (a path with no provenance is worse)" \
    [pcall .calc.res.lab cget -text] {Results Dir (waveform viewer):}
check_true "S26 the tooltip names the source and the path" \
    [expr {[string match {*waveform viewer*} \
              [set tip [pcall calc::results_tip viewer /tmp/s26/from_viewer.raw good_tok]]]
           && [string match {*/tmp/s26/from_viewer.raw*} $tip]}]
# ⚠ THE WIDGET, NOT THE FORMATTER (item 13 review). The leg above calls the pure
# formatter with arguments the TEST supplies, so the whole `balloon` attach can
# be deleted from calc::results_publish and it stays green — measured, 487/487,
# with the row carrying no tooltip in any state. `balloon` bakes its text into
# the <Enter> script it binds (xschem.tcl's balloon), so the BINDING is the
# evidence that the provenance actually reached the user.
set tipbind [pcall bind .calc.res.path <Enter>]
check_true "S26 ...and the ROW really carries it: balloon attached, naming source and path" \
    [expr {[string match {*waveform viewer*} $tipbind]
           && [string match {*/tmp/s26/from_viewer.raw*} $tipbind]}]

# ⚠⚠ RESTATED — this leg used to read *"a session with no results is skipped,
# not reported as empty"* and drove `calc::ase_raw`, which R502a deleted. The
# same rule now lives one layer down and is worth more there: a context the walk
# CAN enter but which holds no selected result is skipped and the NEXT token is
# asked. Without the second leg the first is satisfied by a walk that never
# entered the empty one at all.
set ::s26_log {}
set ::wviewer::windows [dict create empty_tok [dict create win_path .nosuch3] \
                                    good_tok  [dict create win_path .nosuch2]]
set ::s26_noresult {empty_tok}
check "S26 a context with no selected result is skipped, and the next is asked" \
    [pcall calc::results_source] {viewer /tmp/s26/from_viewer.raw good_tok tran 0}
check_true "S26 ...and the empty one really WAS entered and given back" \
    [expr {[lsearch -exact $::s26_log {enter empty_tok borrow=1}] >= 0
           && [lsearch -exact $::s26_log {leave empty_tok}] >= 0}]
set ::s26_noresult {}
set ::wviewer::windows [dict create \
    refused_tok [dict create win_path .nosuch1 top .nosuch1] \
    good_tok    [dict create win_path .nosuch2 top .nosuch2]]

# ⚠ THE ACTIVE VIEWER ANSWERS FIRST, not whichever the registry happens to list
# first — that is the whole premise of Part C (two viewers open, the user is
# looking at ONE of them), and calc::viewer_tokens' current-token block can be
# deleted with the rest of S26 still green unless the shim registry has more
# than one answering token AND a current one that is not first.
set ::s26_savedwin2 $::wviewer::windows
set ::wviewer::windows [dict create good_tok {} good2_tok {}]
set ::s26_curtok {}
set ::s26_hadcur [expr {[info commands ::wviewer::current_token] ne {}}]
if {$::s26_hadcur} { rename ::wviewer::current_token ::calc_s26_curtok }
proc ::wviewer::current_token {} { return $::s26_curtok }
check "S26 with no ACTIVE viewer, the registry order decides" \
    [lindex [pcall calc::results_source] 2] good_tok
set ::s26_curtok good2_tok
check "S26 ...but the ACTIVE viewer outranks it (viewer_tokens puts it first)" \
    [lindex [pcall calc::results_source] 2] good2_tok

# ⚠ NEW, item 10: THE PROVENANCE IS THE SESSION WHEN THE TOKEN IS ONE. The
# viewer token IS the ASE-L session key — ase_window.tcl attaches with
# `wviewer::attach_raw $key ...` — so "whose result is this" is a lookup, not a
# guess, and U6's answer ("the ASE-L session's") is what the label then says.
set ::ase::sessions [dict create good2_tok [dict create path /tmp/s26/s.ase]]
set asesrc [pcall calc::results_source]
pcall calc::results_refresh
check "S26 a token that IS a live ASE-L session key reports as one" \
    $asesrc {ase /tmp/s26/from_viewer.raw good2_tok tran 0}
check "S26 ...and the label names ASE-L, not the viewer" \
    [pcall .calc.res.lab cget -text] {Results Dir (ASE-L session):}

# ⚠⚠ THE NEGATIVE CONTROL FOR THAT LOOKUP — FIXER ROUND, results batch item 10.
# R503b says `ase` is a LOOKUP ("the viewer token IS the session key"), not the
# question "is ANY ASE-L session open?". Without a case where a session EXISTS
# and the answering token is NOT one of its keys, a `calc::token_origin` that
# ignored its argument entirely stays fully green: a reviewer replaced the
# `dict exists $::ase::sessions $tok` with `[dict size $::ase::sessions] > 0`
# and the whole suite passed, while a plain waveform viewer holding the
# selection was reported `ase` and labelled `Results Dir (ASE-L session):`.
# Same world as the leg above, ONE key changed.
set ::ase::sessions [dict create some_other_sess [dict create path /tmp/s26/o.ase]]
set plainsrc [pcall calc::results_source]
pcall calc::results_refresh
check "S26 a token that is NOT a session key stays 'viewer', with a session open" \
    $plainsrc {viewer /tmp/s26/from_viewer.raw good2_tok tran 0}
check "S26 ...and the label still names the waveform viewer" \
    [pcall .calc.res.lab cget -text] {Results Dir (waveform viewer):}
set ::ase::sessions [dict create]
catch {rename ::wviewer::current_token {}}
if {$::s26_hadcur} { catch {rename ::calc_s26_curtok ::wviewer::current_token} }
catch {set ::wviewer::windows $::s26_savedwin2}

# ⚠⚠ RESTATED — THIS LEG USED TO READ "a raw in THIS context outranks the
# viewer's". U6 reverses it: THIS window's own context is not consulted AT ALL.
# The positive term is in the same assertion, because "the row says none" is
# also what a broken resolver says: `results::current` really does answer here,
# and the row still refuses to name it.
set ::wviewer::windows [dict create]
set ::s26_here [dict create idx 0 path /tmp/s26/from_self.raw type tran cur 1 \
                    label {from_self.raw (tran)}]
pcall calc::results_refresh
check "S26 a result in THIS window's own context is NOT consulted (U6)" \
    [list [dict get [pcall results::current] path] [pcall calc::results_source] \
          [pcall .calc.res.path get]] \
    {/tmp/s26/from_self.raw {none {} {} {} {}} {(no raw file loaded)}}
set ::s26_here {}

# ⚠ NEW, item 10 — T-J: A REFUSED BORROW IS REPORTED AS REFUSED, NEVER AS "no
# results". Both sentences are legitimate answers this window gives, which is
# exactly why they may not collapse into one: "no results are loaded" is a fact
# about the user's simulations, and a busy window is not.
set ::wviewer::windows [dict create refused_tok [dict create win_path .nosuch1]]
set refsrc [pcall calc::results_source]
pcall calc::results_refresh
check "S26 the only loan refused: the ORIGIN is the refusal, not 'none'" \
    $refsrc {refused {} refused_tok {} {}}
check "S26 ...and the row says so in its own words, not the no-raw ones" \
    [pcall .calc.res.path get] {(results unavailable: the session's context is busy)}
check "S26 ...and the label marks it unavailable" \
    [pcall .calc.res.lab cget -text] {Results Dir (unavailable):}
check_true "S26 ...the tooltip is the refusal, and it DENIES the wrong reading" \
    [expr {[set rt [pcall bind .calc.res.path <Enter>]] ne {}
           && [string match {*refused context switch*} $rt]
           && [string match {*not an empty result list*} $rt]
           && ![string match {*No simulation results are loaded*} $rt]}]
check_true "S26 ...and the two sentences are genuinely different strings" \
    [expr {[pcall calc::busy_msg] ne [pcall calc::no_result_msg]}]

# ⚠ NEW, item 10 — CREW RULING R502a: A DERIVED PATH IS NOT AN ANSWER. The old
# `ase` arm returned `ase::last_rawfile` — the run directory's raw, gated on the
# file existing. Under U3 the row names what Evaluate READS, and Evaluate cannot
# read a file nothing has loaded; offering it would re-open R503's contradiction
# one arm to the left. The positive term: the derivation really does answer.
set ::wviewer::windows [dict create]
set ::s26_lastraw_had [expr {[info commands ::ase::last_rawfile] ne {}}]
if {$::s26_lastraw_had} { rename ::ase::last_rawfile ::calc_s26_lastraw }
proc ::ase::last_rawfile {key} { return /tmp/s26/derived.raw }
set ::ase::sessions [dict create sess_b [dict create path /tmp/s26/b.ase]]
check "S26 a DERIVED session path is not a selection and is not reported (R502a)" \
    [list [pcall ase::last_rawfile sess_b] [pcall calc::results_source]] \
    {/tmp/s26/derived.raw {none {} {} {} {}}}
catch {rename ::ase::last_rawfile {}}
if {$::s26_lastraw_had} { catch {rename ::calc_s26_lastraw ::ase::last_rawfile} }
set ::ase::sessions [dict create]

# ⚠ THE "ON DEMAND" HALF, AND WHY THE WORLD MUST CHANGE IN THE MIDDLE OF IT.
# The first draft collapsed the row, expanded it, and asserted the entry still
# read `(no raw file loaded)` — the value the test itself had put there two
# lines earlier. It could not distinguish a re-resolve from a leftover, and it
# stayed green with the `catch {calc::results_refresh}` in calc::res_toggle's
# expand arm deleted (measured: 487/487) — i.e. the entire on-demand half of the
# W05/R705 ruling had zero coverage. So: collapse, CHANGE THE WORLD while it is
# collapsed, and expand. A replay and a re-resolve now differ.
# ORDER MATTERS: the world changes BEFORE the collapse, so the collapse leg
# proves the collapse arm does NOT refresh (it would otherwise pick the new
# value up and make the expand leg indistinguishable from a leftover again),
# and the expand leg proves the expand arm DOES.
pcall calc::results_refresh
check "S26 the row starts this leg with no result" \
    [pcall .calc.res.path get] {(no raw file loaded)}
set ::s26_cur [dict create idx 0 path /tmp/s26/on_demand.raw type tran cur 1 \
                   label {on_demand.raw (tran)}]
set ::wviewer::windows [dict create good_tok [dict create win_path .nosuch2]]
pcall calc::res_toggle
check "S26 ...collapsing does NOT refresh: the row still holds the OLD string" \
    [pcall .calc.res.path get] {(no raw file loaded)}
pcall calc::res_toggle
check "S26 re-expanding the row re-resolves it (on demand, never remembered)" \
    [pcall .calc.res.path get] {/tmp/s26/on_demand.raw}
check "S26 ...and the re-resolve reached the label too" \
    [pcall .calc.res.lab cget -text] {Results Dir (waveform viewer):}

# =============================================================================
# S27 — RESULTS BATCH ITEM 10: THE ROW PICKS, AND EVALUATE READS WHAT IT NAMES.
#
# Four user rulings and one invariant, all of them about WHICH DATABASE the
# Calculator works against — never about what it computes, which is
# calculator_batch phase 3's and is deliberately absent here.
#
#   U3   the Results Dir row PICKS: what it NAMES is what Evaluate READS
#   U7   Evaluate with no result refuses and names the next action
#   U8   a Calculator read does not drag the waveform viewer with it
#   U9   `Browse` stays disabled, and the stub carries the REASON
#   T-I  the row and `results::current` agree
#   T-J  a refused borrow is reported AS REFUSED (S26 above, plus Evaluate here)
#
# The shims from S26 are still installed: `good_tok` answers with
# `/tmp/s26/on_demand.raw`.
# =============================================================================

# --- U3 / T-I: ONE resolution feeds the row AND the decision ------------------
# The strongest form of "the row names what Evaluate reads" is not two equal
# strings — two resolutions can agree by luck — it is that there is only ONE
# resolution. `calc::require_result` resolves once, publishes the row from that
# measurement and then answers, so a world that changes between the two cannot
# put a different path in the row from the one the decision used.
set ::s27_calls 0
rename ::calc::results_source ::calc_s27_src
proc ::calc::results_source {} {
    incr ::s27_calls
    return [::calc_s27_src]
}
set ::s27_calls 0
set g [pcall calc::require_result]
# T-I is asked WHERE THE READ HAPPENS. `results::current` reads whatever context
# is current, and this window's own is not consulted at all (U6) — so the third
# term stands inside the borrowed context, which is where `calc::ctx_result`
# asks it. Asking it out here would measure the arm the ruling removed.
set ::s26_inctx 1
set cur_in_viewer [pcall results::current]
set ::s26_inctx 0
check "S27 T-I the row and results::current name the same database" \
    [list [pcall .calc.res.path get] [dict get $g path] \
          [dict get $cur_in_viewer path]] \
    {/tmp/s26/on_demand.raw /tmp/s26/on_demand.raw /tmp/s26/on_demand.raw}
# ⚠ FIXER ROUND — A RESULT IS NOT A PATH. T-I compared only `path`, so the gate
# could identify a database BY FILE and the leg could not see it (measured: the
# first draft's dict had no `type` key at all).
check "S27 T-I ...and the same SLOT, not just the same file (type and idx)" \
    [list [dg $g type] [dg $g idx] \
          [dg $cur_in_viewer type] [dg $cur_in_viewer idx]] \
    {tran 0 tran 0}
check "S27 U3 the row is published from the SAME resolution the decision used" \
    $::s27_calls 1
check "S27 ...and it says a result IS available" [dict get $g ok] 1
check "S27 ...naming the provenance it came from" [dict get $g origin] viewer
rename ::calc::results_source {}
rename ::calc_s27_src ::calc::results_source

# --- U3, the other direction: change the selection, the row and the decision
# move TOGETHER. This is what "changing the row changes what Evaluate reads"
# means for a row the user cannot type into (U9): the session's selection is the
# only input, and both read it live.
set ::s26_cur [dict create idx 1 path /tmp/s26/second_run.raw type tran cur 1 \
                   label {second_run.raw (tran)}]
set g2 [pcall calc::require_result]
check "S27 U3 a new session selection moves the row and the decision together" \
    [list [pcall .calc.res.path get] [dict get $g2 path]] \
    {/tmp/s26/second_run.raw /tmp/s26/second_run.raw}

# --- ONE FILE, TWO ANALYSES, TWO SLOTS (fixer round) -------------------------
# U11: one run is one result and analyses are dimensions INSIDE it, but the
# ENGINE's identity key is `(rawfile, sim_type)` and it stores one slot per
# analysis — so a two-plot `multi.raw` is two rows of `results::list`, and
# R407c clause (1) rules that a by-path lookup selects "the WRONG ANALYSIS OF
# THE RIGHT FILE" (pinned SEL372 on that exact fixture; L6/L10 say the same
# from the engine's side). The gate's answer must therefore name the SLOT. The
# ROW is right to stay identical across the pair: W05 is a path entry.
set ::s26_cur [dict create idx 0 path /tmp/s26/multi.raw type dc cur 1 \
                   label {multi.raw (dc)}]
set gdc [pcall calc::require_result]
set rowdc [pcall .calc.res.path get]
set ::s26_cur [dict create idx 1 path /tmp/s26/multi.raw type tran cur 1 \
                   label {multi.raw (tran)}]
set gtr [pcall calc::require_result]
check "S27 U11 the same FILE as two analyses gives two answers, not one" \
    [list [dg $gdc path] [dg $gdc type] [dg $gdc idx] \
          [dg $gtr path] [dg $gtr type] [dg $gtr idx]] \
    {/tmp/s26/multi.raw dc 0 /tmp/s26/multi.raw tran 1}
check "S27 ...and the ROW names the file, so it is identical for both (W05)" \
    [list $rowdc [pcall .calc.res.path get]] \
    {/tmp/s26/multi.raw /tmp/s26/multi.raw}
# back to the world the rest of S27 expects
set ::s26_cur [dict create idx 1 path /tmp/s26/second_run.raw type tran cur 1 \
                   label {second_run.raw (tran)}]
pcall calc::results_refresh
check "S27 the multi-analysis fixture is put back" \
    [pcall .calc.res.path get] {/tmp/s26/second_run.raw}

# --- Evaluate WITH a result still lands on the phase-3 stub (SCOPE FENCE) ----
# Item 10 settles which database Evaluate reads; it does NOT build the
# computation. A press with a result must therefore still say what it always
# said, or this item has quietly grown a phase.
pcall .calc.mode.eval invoke
check "S27 Evaluate WITH a result falls through to the phase-3 stub" \
    [pcall .calc.status.msg get] {Eval: not implemented (phase 3)}

# --- U8: the read is a LOAN, and the viewer is not dragged along -------------
set ::s26_log {}
set winbefore [pcall xschem get current_win_path]
pcall calc::require_result
set winafter [pcall xschem get current_win_path]
check "S27 U8 every loan taken is given back (the viewer keeps its context)" \
    [list [llength [lsearch -all -exact $::s26_log {enter good_tok borrow=1}]] \
          [llength [lsearch -all -exact $::s26_log {leave good_tok}]]] {1 1}
check "S27 U8 ...and this window did not move" [list $winbefore $winafter] \
    [list $winbefore $winbefore]
check_true "S27 U8 ...the window path was really readable (not two empty strings)" \
    [expr {$winbefore ne {} && ![string match ERR:* $winbefore]}]

# --- U7: with NO result, Evaluate refuses in the ruled words ------------------
set ::wviewer::windows [dict create]
pcall calc::status {} 0
pcall .calc.mode.eval invoke
check "S27 U7 Evaluate with no result refuses in the ruled words" \
    [pcall .calc.status.msg get] \
    "No simulation results are loaded. Run a simulation, or pick an existing one with ASE-L \u25b8 Results \u25b8 Select."
check_true "S27 U7 ...it names the command, and does NOT offer to launch ASE-L" \
    [expr {[string match {*Results*Select*} [set m [pcall calc::no_result_msg]]]
           && [string match {*Run a simulation*} $m]
           && ![string match {*[Ll]aunch*} $m] && ![string match {*[Oo]pen ASE*} $m]}]
check "S27 U7 ...and the gate says why it refused" \
    [list [dict get [set gr [pcall calc::require_result]] ok] [dict get $gr origin]] {0 none}

# --- R503f (FIXER ROUND): U7's sentence is never said to a user who has
#     ALREADY done what it asks -----------------------------------------------
# THE COLLISION, between two items of this same batch. R407a (item 7, spec
# §6.1) gives the `Results ▸ Select…` dialog a `here` arm: with no waveform
# viewer the session selects into the CURRENT context — ruled in deliberately,
# because "evaluate against last night's raw" happens BEFORE a run, which is
# exactly when no viewer exists. U6 says the Calculator does not read that
# context. A reviewer drove it with NO repo edit: the row read
# `(no raw file loaded)` and Evaluate answered "pick an existing one with
# ASE-L ▸ Results ▸ Select" — the gesture just performed successfully.
#
# The GAP is filed as issue 0516 and is deliberately NOT closed here: U6 is a
# USER ruling that says "removed entirely, not demoted", and an arm that reads
# this window's context — however conditioned — is the demotion it forbids.
# What IS closed is the advice. The test is STRUCTURAL (is there a live session
# with no viewer window?), reads no database, and hands Evaluate nothing: the
# refusal stands, it is only accurate now.
set ::ase::sessions [dict create sess_noview [dict create path /tmp/s26/nv.ase]]
set ::wviewer::windows [dict create]
# ⚠ AND THIS IS ISSUE 0516'S STATE EXACTLY: a result really IS selected in THIS
# window's context — that is what the `here` arm leaves behind — and U6 says the
# Calculator does not read it. The leg below carries both halves in one
# assertion, so it reds if the gate ever starts answering from here.
set ::s26_here [dict create idx 0 path /tmp/s26/here_arm.raw type tran cur 1 \
                    label {here_arm.raw (tran)}]
pcall calc::status {} 0
pcall .calc.mode.eval invoke
set nvmsg [pcall .calc.status.msg get]
check "S27 R503f a session with NO viewer is told the obstacle, not 'pick one'" \
    $nvmsg [pcall calc::no_viewer_msg]
check_true "S27 R503f ...and that sentence is not U7's, and does not re-ask the gesture" \
    [expr {[string match {*no waveform viewer*} $nvmsg]
           && [string match {*open the session's waveforms*} $nvmsg]
           && $nvmsg ne [pcall calc::no_result_msg]}]
check_true "S27 R503f ...the ROW's balloon gives the same advice as Evaluate" \
    [string match {*no waveform viewer*} [pcall bind .calc.res.path <Enter>]]
check "S27 R503f Evaluate still REFUSES — nothing is adopted from this window (U6)" \
    [list [dict get [pcall results::current] path] \
          [dg [set gnv [pcall calc::require_result]] ok] \
          [dg $gnv origin] [dg $gnv path]] {/tmp/s26/here_arm.raw 0 none {}}
set ::s26_here {}
# THE DISCRIMINATING POSITIVE CONTROL: the same session, now WITH a viewer whose
# context holds no result, gets U7's ruled sentence back. Without it, "always
# say the obstacle" would pass.
set ::wviewer::windows [dict create sess_noview [dict create win_path .nosuch9 top .]]
set ::s26_noresult {sess_noview}
pcall calc::status {} 0
pcall .calc.mode.eval invoke
check "S27 R503f ...and a session that HAS a viewer gets U7's ruled sentence" \
    [pcall .calc.status.msg get] [pcall calc::no_result_msg]
set ::s26_noresult {}
set ::wviewer::windows [dict create]
set ::ase::sessions [dict create]

# --- T-J again, at Evaluate: a refused borrow is not "no results" ------------
set ::wviewer::windows [dict create refused_tok [dict create win_path .nosuch1]]
pcall calc::status {} 0
pcall .calc.mode.eval invoke
set evalmsg [pcall .calc.status.msg get]
check_true "S27 T-J Evaluate reports a REFUSED loan as refused, not as 'no results'" \
    [expr {[string match {*refused context switch*} $evalmsg]
           && [string match {*not an empty result list*} $evalmsg]
           && ![string match {*No simulation results are loaded*} $evalmsg]}]
check "S27 T-J ...and the gate carries the refusal as its own origin" \
    [dict get [pcall calc::require_result] origin] refused

# --- U9: Browse is DISABLED and it is not "not implemented" -------------------
check "S27 U9 Browse is still disabled" [pcall .calc.res.browse cget -state] disabled
check "S27 U9 ...the path entry is still readonly (nothing here edits it)" \
    [pcall .calc.res.path cget -state] readonly
check "S27 U9 ...and its command is the ruled stub" \
    [pcall .calc.res.browse cget -command] calc::browse_inert
check_true "S27 U9 the stub's sentence gives the REASON and points at the door" \
    [expr {[string match {*ASE-L*Results*Select*} [set b [pcall calc::browse_inert]]]
           && [string match {*consumes*} $b]
           && ![string match {*not implemented*} $b]}]
# ⚠ ANTI-VACUITY: a disabled button is only inert if Tk really refuses the
# press. `invoke` on a disabled button is a no-op, so the status line must not
# move — and the positive control is that the SAME gesture on an enabled button
# does move it.
pcall calc::status {} 0
pcall .calc.res.browse invoke
set afterbrowse [pcall .calc.status.msg get]
pcall .calc.mode.table invoke
check "S27 U9 a press on the disabled Browse says nothing (and Table proves the gesture works)" \
    [list $afterbrowse [pcall .calc.status.msg get]] \
    {{} {Table: not implemented (phase 10)}}

# --- U8 / R303, by grep: the Calculator SELECTS nothing ----------------------
# It consumes the session's selection and never makes one, so `results::select`
# — the one gesture that moves the engine — must not appear in calculator.tcl at
# all. Comment-stripped, because item 2's SEL82 and item 8 both met a check that
# a COMMENT satisfied.
set calcsrc {}
set s27_calcfile [file normalize \
    [file join [file dirname [info script]] .. .. src calculator.tcl]]
if {![catch {open $s27_calcfile r} fh]} {
    set calcsrc [read $fh] ; close $fh
}
set calccode {}
foreach ln [split $calcsrc "\n"] {
    if {[regexp {^\s*#} $ln]} continue
    regsub {;\s*#.*$} $ln {} ln
    append calccode $ln "\n"
}
check_true "S27 the source really was read (positive control)" \
    [expr {[string length $calccode] > 20000 && [string match {*proc calc::eval_click*} $calccode]}]
check "S27 U8 the Calculator never calls results::select" \
    [llength [lsearch -all -regexp [split $calccode "\n"] {results::select}]] 0
check "S27 U6 and the self-arm reader is gone from the source too" \
    [llength [lsearch -all -regexp [split $calccode "\n"] {raw rawfile}]] 0

# --- the row is a MAPPED widget carrying this, not just a variable -----------
set ::wviewer::windows [dict create good_tok [dict create win_path .nosuch2]]
pcall calc::results_refresh
update idletasks
check "S27 the picked path is in a MAPPED row, not just in a variable" \
    [list [pcall winfo ismapped .calc.res.path] [pcall winfo manager .calc.res.path] \
          [pcall .calc.res.path get]] \
    {1 pack /tmp/s26/second_run.raw}

# --- R705: nothing is cached. Take every shim away and the next query answers
#     from the world as it now is.
catch {rename ::results::current {}}
catch {rename ::calc_s26_current ::results::current}
catch {rename ::wviewer::enter_ctx {}}
catch {rename ::calc_s26_enter ::wviewer::enter_ctx}
catch {rename ::wviewer::leave_ctx {}}
catch {rename ::calc_s26_leave ::wviewer::leave_ctx}
catch {set ::wviewer::windows $::s26_savedwin}
catch {set ::ase::sessions $::s26_savedsess}
check_true "S27 shims are gone again (the real procs answer)" \
    [expr {[info commands ::calc_s26_current] eq {}
           && [pcall results::current] eq {}
           && ![string match ERR:* [pcall xschem get current_win_path]]}]
check "S27 R705: nothing was cached — the answer is live" \
    [pcall calc::results_source] {none {} {} {} {}}
pcall calc::results_refresh
check "S27 ...so the row is back to the no-result wording and the plain label" \
    [list [pcall .calc.res.path get] [pcall .calc.res.lab cget -text]] \
    {{(no raw file loaded)} {Results Dir:}}
check_true "S27 ...and the balloon reverted with it (the widget, not the formatter)" \
    [string match {*No simulation results are loaded*} [pcall bind .calc.res.path <Enter>]]

# --- A FIRST OPEN PUBLISHES THE ROW (fixer round) ----------------------------
# `calc::build_res` ends with `calc::results_refresh`, and its own comment flags
# that call as load-bearing — "do not delete it as an unlisted extra:
# `calc::open`'s raise arm does not run when there is nothing to raise". It had
# ZERO coverage: a reviewer deleted the line and the suite stayed ALL PASS,
# while a user's first Calculator open showed an EMPTY Results Dir entry and no
# tooltip at all — exactly the "an empty readonly entry and a broken one look
# identical" state W05's wording exists to prevent. Nothing could see it because
# S1's "second open is raise" calls `calc::open` twice and the RAISE arm
# refreshes before any later leg reads the row. So: close, clear the variable
# the entry is bound to, and open ONCE.
pcall calc::close
set ::calc::respath {}
check "S27 the row's variable really was cleared first (control)" \
    [nsval ::calc::respath] {}
pcall calc::open
update idletasks
check "S27 a FIRST open publishes the row — build_res's own refresh ran" \
    [list [pcall .calc.res.path get] [pcall .calc.res.lab cget -text]] \
    {{(no raw file loaded)} {Results Dir:}}
check_true "S27 ...and the balloon was attached on that first build too" \
    [string match {*No simulation results are loaded*} [pcall bind .calc.res.path <Enter>]]

calc::close
catch {destroy .calccbprobe}

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
