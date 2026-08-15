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
# ⚠ RESTATED by item 2 (phase 1b), and the expectation genuinely changed: a
# placeholder hint is what a pane shows INSTEAD of its contents, and Selectors,
# Buffer and Stack now have their contents (the grid + mode strip, the buffer +
# toolbar, the Stack). Only Functions and Keypad — item 4's — are still owed,
# so only those two still carry a hint. The other half of the restatement is
# the check below: the three filled panes must have no hint LEFT, which is what
# stops "filled" from meaning "drawn on top of the old placeholder".
foreach lf {.calc.pw.bot.fn .calc.pw.bot.pad} {
    check "S14 $lf hint text is the muted role" \
        [pcall $lf.hint cget -foreground] $c_disabledfg
    check "S14 $lf hint background" [pcall $lf.hint cget -background] $c_panel
}
set leftover {}
foreach lf {.calc.pw.sel .calc.pw.buf .calc.pw.stk} {
    if {[winfo exists $lf.hint]} { lappend leftover $lf }
}
check "S14 a filled pane keeps no placeholder hint" $leftover {}
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
check "S15 results_path with no raw is empty, not an error" [pcall calc::results_path] {}
check "S15 entry says no raw is loaded" [pcall .calc.res.path get] {(no raw file loaded)}
check_true "S15 entry reads as a sentence, not empty" \
    [expr {[set t [pcall .calc.res.path get]] ne {}
           && ![string match ERR:* $t] && [string match {*no raw*} $t]}]

# ...and with one loaded it shows the full path. `xschem raw rawfile` needs a
# real .raw, so the C command is shimmed for exactly this leg and restored
# immediately: the branch under test is calc::results_refresh's, not the
# engine's.
set shimerr [catch {
    rename ::xschem ::calc_test_real_xschem
    proc ::xschem {args} {
        if {[lrange $args 0 1] eq {raw rawfile}} { return {/tmp/calc test/sim.raw} }
        return [uplevel 1 [linsert $args 0 ::calc_test_real_xschem]]
    }
    calc::results_refresh
} shimmsg]
set shown [pcall .calc.res.path get]
catch {rename ::xschem {}}
catch {rename ::calc_test_real_xschem ::xschem}
check "S15 shim installed cleanly"       $shimerr 0
check "S15 loaded raw shows its full path" $shown {/tmp/calc test/sim.raw}
# the shim WAS live (it answered) and is gone again: with no raw loaded the
# real command throws (scheduler.c:10046) while other verbs still answer
check_true "S15 shim was live and is now gone" \
    [expr {$shown eq {/tmp/calc test/sim.raw}
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
    set st [pcall .calc.sel.$id cget -state]
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
# its string into the <Enter> binding at attach time (xschem.tcl:12551), which
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
# every other radiobutton in the tree (*selectColor white, xschem.tcl:15552).
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
# itself (recon/widgets.md §1d, xschem.tcl:10828)
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

# the three action buttons are INERT, and each names itself and its phase
foreach {id label phase} {plot Plot 3 eval Eval 3 table Table 10} {
    check "S18 $id text" [pcall .calc.mode.$id cget -text] $label
    check "S18 $id enabled" [pcall .calc.mode.$id cget -state] normal
    pcall .calc.mode.$id invoke
    check "S18 $id is inert and says so" [pcall .calc.status.msg get] \
        "$label: not implemented (phase $phase)"
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
    if {[pcall .calc.btb.$id cget -state] ne {normal}} { lappend badenabled $id }
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
    if {[pcall $w cget -state] ne {normal}} { lappend badstk $id=[pcall $w cget -state] }
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
