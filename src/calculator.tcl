# calculator.tcl — the xschem Calculator window (a Cadence ViVA L Calculator
# work-alike).  Spec: doc/claude/specs/calculator.md.  Plan:
# doc/claude/calculator_batch/PLAN.md.  Human explainer:
# doc/claude/code_analysis/viva_calculator_explained.md.
#
# PHASE 0 — SKELETON ONLY.  This file currently builds the window's partitions
# and its draggable dividers and nothing else.  Every region is a labelled
# placeholder; no control does anything.  That is deliberate: the plan paints
# the layout first (phase 0), fills every region with real-but-inert controls
# (phase 1) and only then wires behaviour (phase 3 onwards), so that no step
# ever leaves the window looking worse than the step before it.
#
# THE POINT OF THE FILE, once it is finished: the Calculator is an EXPRESSION
# BUILDER, not a pocket calculator.  Its deliverable is a string — an RPN
# expression the existing engine (plot_raw_custom_data(), save.c:2381) can
# evaluate against the loaded .raw and the viewer can plot.  Do not add a
# second expression evaluator here; see spec §0 and §1.3.
#
# ---------------------------------------------------------------------------
# The pane tree (spec §4, plan "Pane tree").  Four sashes.  Every functional
# area the tool has is a pane and is resizable against its neighbours.
#
#   .calc.pw                    panedwindow -orient vertical    3 sashes
#    ├── .calc.pw.sel           Results Dir + selector grid + mode strip
#    ├── .calc.pw.buf           the buffer + its toolbar
#    ├── .calc.pw.stk           the Stack
#    └── .calc.pw.bot           panedwindow -orient horizontal  1 sash
#         ├── .calc.pw.bot.fn   function browser
#         └── .calc.pw.bot.pad  keypad + user buttons
#   .calc.status                packed OUTSIDE the panes, at the bottom
#
# House idiom, copied from load_file_dialog (xschem.tcl:7082) rather than
# invented:
#   - CLASSIC panedwindow, not ttk::panedwindow.  ttk::panedwindow has no
#     -minsize, and every pane here needs one (landmine D3 below).
#   - -stretch is catch-guarded, because Tk 8.4 does not have it
#     (xschem.tcl:7115).
#   - sash restore is `sash mark` then `sash dragto` (xschem.tcl:7332-7347).
#     The tree also contains a `sash place` idiom (.ins.center,
#     xschem.tcl:8332).  Both work; MIXING them in one file does not.  This
#     file is mark/dragto throughout.
#
# Divider landmines (plan "Divider landmines"), all of them already paid for
# somewhere in this tree:
#   D1  `sash coord` before the pane is mapped returns garbage, so the restore
#       runs at the end of the build with the widgets already packed.  If it
#       ever misbehaves use `update idletasks`, never `update` — the latter
#       reenters the event loop and can run a second calc::open.
#   D2  <Configure> on a toplevel that holds nested panes fires per resize.
#       Keep save_layout cheap; it reads four sash coords and nothing else.
#   D3  a pane with -stretch always and no -minsize collapses to zero on
#       window shrink and cannot be dragged back.  Every pane gets a -minsize.
#   D4  a sash position saved on a big screen and restored into a small window
#       clamps SILENTLY, so one laptop session would poison the desktop
#       layout.  restore_layout re-validates every value against the current
#       extent and skips the ones that no longer fit.
#   D5  the house <Configure> binding captures sash positions only when the
#       TOPLEVEL is resized — dragging a sash resizes children, not the
#       toplevel, so a drag-then-close would be lost.  save_layout is
#       therefore also called on <ButtonRelease-1> over each panedwindow and
#       once more from calc::close.
#   D6  a restore WRITES the layout, so capture must be OFF while one runs.
#       A <Configure> delivered during a restore lands in save_layout and
#       overwrites the very values being applied; the symptom is a restore that
#       silently does nothing.  restore_layout holds calc::restoring across the
#       whole operation and save_layout returns early while it is set.
#       This one is INVISIBLE UNDER Xvfb — no window manager means no pending
#       Configure — and was found only by running the phase-0 test on :0.
#       Anything added here that pumps the event loop must respect the flag.
#
# Layout state lives in this namespace and so persists for the session only.
# Persisting it to ~/.xschem/calculator.state is plan phase 9 (spec R704);
# when that lands, calc::save_layout/restore_layout are the only two procs
# that need to learn about the file.

namespace eval calc {
    # sash($pw,$idx) -> the saved coordinate along the panedwindow's own axis
    variable sash
    array set sash {}
    # last `wm geometry` of .calc
    variable geom {}
    # set once the guarded -stretch probe has run
    variable optnever {}
    variable optalways {}
}

# The panedwindows this window owns, as
#     {path orientation nsashes {default sash fractions}}.
# One list, read by build, save_layout and restore_layout, so a new pane cannot
# be added to one of them and forgotten by the other two.
#
# The fractions are where each sash sits, as a fraction of the panedwindow's
# extent, on a FIRST open with nothing saved.  Tk's own distribution is an even
# split, which is not what the tool should look like: the reference gives the
# selector grid only as much height as its two button rows need and hands the
# surplus to the stack and the function browser.  Measured off the reference
# screenshot and rounded.
proc calc::pw_list {} {
    return {
        {.calc.pw     vertical   3 {0.21 0.36 0.64}}
        {.calc.pw.bot horizontal 1 {0.78}}
    }
}

# Raise-or-open.  Spec R101: one Calculator, not one per invocation.
proc calc::open {} {
    if {[winfo exists .calc]} {
        wm deiconify .calc
        raise .calc
        focus .calc
        return .calc
    }
    return [calc::build]
}

proc calc::close {} {
    # D5: capture the layout before the widgets go away, and swallow the
    # errors a half-destroyed panedwindow raises.
    catch {calc::save_layout}
    catch {destroy .calc}
}

# ---------------------------------------------------------------------------
# Build

proc calc::build {} {
    variable optnever
    variable optalways

    toplevel .calc
    wm title .calc {xschem Calculator}
    wm protocol .calc WM_DELETE_WINDOW calc::close
    wm minsize .calc 560 620

    calc::build_menubar
    .calc configure -menu .calc.mbar

    # Status bar first, and packed -side bottom, so it owns the bottom edge of
    # the toplevel and the panes get everything above it.  It is NOT a pane:
    # a status line that moved when you dragged a sash would be a bug.
    calc::build_status
    pack .calc.status -side bottom -fill x

    calc::build_panes
    pack .calc.pw -side top -fill both -expand 1

    # D1: the widgets are packed by now, so sash coord is meaningful.
    calc::restore_layout

    # D2/D5: three capture points — toplevel resize, end of a sash drag, and
    # close.  Together they cover every way the layout can change.
    bind .calc <Configure> {if {{%W} eq {.calc}} {calc::save_layout}}
    foreach ent [calc::pw_list] {
        bind [lindex $ent 0] <ButtonRelease-1> {+calc::save_layout}
    }
    return .calc
}

# Six cascades, matching the reference tool.  Every entry is disabled: phase 0
# owns the layout, not the behaviour.  Each cascade carries one placeholder
# entry so that it posts visibly and an eyeball can confirm it exists.
proc calc::build_menubar {} {
    menu .calc.mbar -tearoff 0 -takefocus 0
    foreach {label sub} {
        File file  Tools tools  View view
        Options options  Constants constants  Help help
    } {
        menu .calc.mbar.$sub -tearoff 0 -takefocus 0
        .calc.mbar add cascade -label $label -menu .calc.mbar.$sub
        .calc.mbar.$sub add command -label {(phase 0: not implemented)} \
            -state disabled
    }
}

proc calc::build_status {} {
    frame .calc.status
    label .calc.status.msg -anchor w -relief sunken -borderwidth 1 \
        -text {status area}
    # The history dropdown (spec W34) is phase 1; the button exists now so the
    # status bar has its final height and the layout does not shift later.
    button .calc.status.hist -text {v} -width 2 -state disabled -takefocus 0
    pack .calc.status.hist -side right -padx 2 -pady 1
    pack .calc.status.msg  -side left -fill x -expand 1 -padx 2 -pady 1
}

proc calc::build_panes {} {
    variable optnever
    variable optalways

    panedwindow .calc.pw -orient vertical \
        -sashwidth 5 -sashrelief raised -showhandle 1 -borderwidth 0
    panedwindow .calc.pw.bot -orient horizontal \
        -sashwidth 5 -sashrelief raised -showhandle 1 -borderwidth 0

    # Phase 0 placeholders.  Phase 1 replaces the body of each of these with
    # the real controls; the labelframe and its pane stay.
    calc::placeholder .calc.pw.sel      {Selectors}  {Results Dir, the 22 signal buttons, mode strip}
    calc::placeholder .calc.pw.buf      {Buffer}     {the expression being built, plus its toolbar}
    calc::placeholder .calc.pw.stk      {Stack}      {parked expressions}
    calc::placeholder .calc.pw.bot.fn   {Functions}  {category chooser + function list}
    calc::placeholder .calc.pw.bot.pad  {Keypad}     "digits,\noperators,\nuser 1-4"

    # D3: every pane carries a -minsize.  The numbers are the smallest height
    # (or width) at which the phase-1 contents are still usable, so a drag
    # cannot hide a region outright.
    .calc.pw add .calc.pw.sel -minsize 120
    .calc.pw add .calc.pw.buf -minsize 70
    .calc.pw add .calc.pw.stk -minsize 80
    .calc.pw add .calc.pw.bot -minsize 140
    .calc.pw.bot add .calc.pw.bot.fn  -minsize 250
    .calc.pw.bot add .calc.pw.bot.pad -minsize 140

    # Tk 8.4 has no -stretch.  Probe once, then apply through the two vars so
    # the calls below are identical on both.
    if {![catch {.calc.pw panecget .calc.pw.sel -stretch}]} {
        set optnever  {-stretch never}
        set optalways {-stretch always}
    } else {
        set optnever  {}
        set optalways {}
    }
    # The selector grid is a fixed grid of buttons: extra height would be
    # whitespace, so it does not take its share when the window grows.  It is
    # still a pane, and its sash still drags.  Same argument for the keypad in
    # the horizontal direction.
    eval .calc.pw paneconfigure .calc.pw.sel $optnever
    eval .calc.pw paneconfigure .calc.pw.buf $optalways
    eval .calc.pw paneconfigure .calc.pw.stk $optalways
    eval .calc.pw paneconfigure .calc.pw.bot $optalways
    eval .calc.pw.bot paneconfigure .calc.pw.bot.fn  $optalways
    eval .calc.pw.bot paneconfigure .calc.pw.bot.pad $optnever
}

proc calc::placeholder {path title hint} {
    labelframe $path -text $title -padx 4 -pady 4
    label $path.hint -text $hint -anchor center -justify center \
        -foreground grey40
    pack $path.hint -fill both -expand 1
}

# ---------------------------------------------------------------------------
# Layout persistence
#
# A panedwindow's `sash coord i` returns {x y}; only the coordinate along the
# widget's own orientation means anything, and `sash dragto` wants both.  These
# two procs are the only place that asymmetry is handled.

proc calc::sash_axis {orient} {
    return [expr {$orient eq {vertical} ? 1 : 0}]
}

proc calc::save_layout {} {
    variable sash
    variable geom
    variable restoring
    # D6. A restore WRITES the layout, so capture must be off while one runs.
    # A <Configure> delivered during a restore lands here, captures the
    # positions the restore is halfway through replacing, and clobbers the
    # values it was about to apply. The symptom is a restore that appears to do
    # nothing at all. Invisible under Xvfb, which runs no WM and so has no
    # pending Configure to deliver.
    if {[info exists restoring] && $restoring} return
    if {![winfo exists .calc]} return
    foreach ent [calc::pw_list] {
        foreach {pw orient n fracs} $ent break
        if {![winfo exists $pw]} continue
        set axis [calc::sash_axis $orient]
        for {set i 0} {$i < $n} {incr i} {
            if {[catch {$pw sash coord $i} c]} continue
            set sash($pw,$i) [lindex $c $axis]
        }
    }
    catch {set geom [wm geometry .calc]}
}

proc calc::restore_layout {} {
    variable restoring
    set restoring 1
    set rc [catch {calc::restore_layout_body} msg]
    set restoring 0
    if {$rc} {error $msg}
}

proc calc::restore_layout_body {} {
    variable sash
    variable geom

    if {$geom ne {}} {catch {wm geometry .calc $geom}}
    # D1: no sash coordinate is meaningful until the panes have been laid out.
    # idletasks only — `update` would pump X events mid-restore, and events can
    # run anything, including calc::close.
    update idletasks
    if {![winfo exists .calc]} return

    foreach ent [calc::pw_list] {
        foreach {pw orient n fracs} $ent break
        if {![winfo exists $pw]} continue
        set axis [calc::sash_axis $orient]
        # the extent the sash can travel along: the pane's own height for a
        # vertical split, its width for a horizontal one
        set extent [expr {$axis ? [winfo height $pw] : [winfo width $pw]}]
        for {set i 0} {$i < $n} {incr i} {
            if {[info exists sash($pw,$i)]} {
                set want $sash($pw,$i)
            } else {
                # first open: lay the panes out in the reference proportions
                # rather than Tk's even split
                set want [expr {int([lindex $fracs $i] * $extent)}]
            }
            # D4: a value saved in a taller/wider window would clamp silently
            # and quietly rewrite the saved layout.  Skip it instead, leaving
            # Tk's own distribution in place for that sash.
            if {$extent <= 40 || $want < 20 || $want > $extent - 20} continue
            if {[catch {$pw sash coord $i} c]} continue
            eval $pw sash mark $i $c
            if {$axis} {
                eval $pw sash dragto $i [list [lindex $c 0] $want]
            } else {
                eval $pw sash dragto $i [list $want [lindex $c 1]]
            }
        }
    }
}
