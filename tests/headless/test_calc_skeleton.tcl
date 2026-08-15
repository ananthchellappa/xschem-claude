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
foreach r [list window panel header field fieldfg accent disabledfg] {
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
    # ...and the hint INSIDE it, in every pane. Sampling one pane let four
    # panes revert to a literal with the suite green.
    check "S14 $lf hint text is the muted role" \
        [pcall $lf.hint cget -foreground] $c_disabledfg
    check "S14 $lf hint background" [pcall $lf.hint cget -background] $c_panel
}
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
check "S15 packed into the Selectors pane, first" \
    [pcall pack slaves .calc.pw.sel] {.calc.res .calc.pw.sel.hint}
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
check_true "S15 row sits at the top of the pane" \
    [expr {[winfo exists .calc.res]
           && [winfo rooty .calc.res] < [winfo rooty .calc.pw.sel.hint]}]

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
