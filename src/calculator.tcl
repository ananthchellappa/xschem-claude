# calculator.tcl — the xschem Calculator window (a Cadence ViVA L Calculator
# work-alike).  Spec: doc/claude/specs/calculator.md.  Plan:
# doc/claude/calculator_batch/PLAN.md.  Human explainer:
# doc/claude/code_analysis/viva_calculator_explained.md.
#
# PHASE 1a.  Phase 0 built the window's partitions and its draggable dividers
# and nothing else; every region was a labelled placeholder.  Phase 1 replaces
# each placeholder with the real controls, correct class and initial state, all
# INERT.  That is deliberate: the plan paints the layout first (phase 0), fills
# every region with real-but-inert controls (phase 1) and only then wires
# behaviour (phase 3 onwards), so that no step ever leaves the window looking
# worse than the step before it.
#
# Landed so far in phase 1:
#   1a  the colour layer (calc::color), the Results Dir row (W03-W05) and the
#       status area with its 50-entry history (W32-W34, R506-R509).
#   1b  the 22-button selector grid (W06-W07), the mode strip (W08-W14), the
#       buffer and its toolbar (W15-W22) and the Stack (W23-W25).  All of it
#       INERT: correct path, class and initial state, and a -command that
#       routes through calc::inert -> calc::status and changes nothing else.
# Item 1d replaces the bodies of the Functions / Keypad labelframes.  It must
# not move a sash, change a -minsize or touch calc::pw_list.
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
#
# ---------------------------------------------------------------------------
# COLOUR (spec R113, as amended by RULING-1 in
# doc/claude/calculator_batch/LEDGER.md).
#
# There is ONE palette in this tree and it is the signal browser's:
# `ase::palette` (ase_window.tcl:121), the USER-LOCKED dict that `ase::theme`
# applies to the shared Ase.* styles and `ase::ui::apply_theme` (:190) walks a
# browser window with — from wviewer::browser_build (wave_viewer.tcl:8224) and
# ~30 further browser sites.  calc::color reads that dict; no literal colour is
# written in this file, so editing ase::palette moves both windows and neither
# can drift from the other.
#
# What this file deliberately does NOT do:
#   - it does not call ase::ui::apply_theme on .calc.  That proc also imposes
#     ASE's named fonts (AseLabelFont/AseEntryFont/AseMonoFont) on every widget
#     it walks, and this is not an ASE window: fonts stay stock here
#     (recon/theming.md §3 — nothing in the tree themes fonts for a new
#     dialog).  It also paints every class the same way, and the Calculator
#     needs the accent on panel HEADERS only.
#   - ⚠ it does not call `ase::theme` either, for the same reason one step
#     further out.  ase::theme is not a reader: it creates the three Ase* named
#     fonts and does a PROCESS-GLOBAL `option add *TCombobox*Listbox.font
#     AseEntryFont` (ase_window.tcl:171), which changes the dropdown font of
#     every ttk::combobox in xschem — the Graph dialog, Preferences, the
#     Library Manager — including ones created before the call, because a
#     popdown listbox is built lazily.  Merely OPENING this window must not do
#     that, so the palette is read through ase::palette, which has no side
#     effects at all.  (Measured: with ase::theme, a plain combobox's popdown
#     font goes TkTextFont -> AseEntryFont, +24% row height, for the rest of
#     the session and not undone by closing the Calculator.)
#     The one Ase.* style this window used to borrow, Ase.TCombobox, is
#     therefore replaced by a Calculator-local Calc.TCombobox (build_status).
#   - it does not invent a second palette and does not write a Cadence red.
#     The dark-red header accent is [calc::color accent], i.e. whatever the
#     browser is using.
#
# The known cost, recorded rather than discovered later: an explicit -bg/-fg at
# widget creation beats the startup option database (recon/theming.md §2), so
# these widgets are opted out of $dark_gui_colorscheme — exactly as the signal
# browser already is, because the browser's palette is USER-LOCKED and light.
# If that palette ever learns about the dark scheme, this window follows for
# free, which is the whole point of not having a second one.
#
# ---------------------------------------------------------------------------
# STATUS (spec W32-W34, R506-R509).  calc::status is on the path of nearly
# every action the tool will ever have, so its contract is pinned in the spec
# and not left to each caller: empty string clears and records nothing (R507);
# no window is a silent no-op (R508); 50 entries newest-first, the oldest drops
# (R509).

namespace eval calc {
    # sash($pw,$idx) -> the saved coordinate along the panedwindow's own axis
    variable sash
    array set sash {}
    # last `wm geometry` of .calc
    variable geom {}
    # set once the guarded -stretch probe has run
    variable optnever {}
    variable optalways {}
    # W05: the -textvariable of .calc.res.path
    variable respath {}
    # W03: 1 while the Results Dir row is collapsed to its toggle
    variable rescollapsed 0
    # W33: the -textvariable of .calc.status.msg
    variable statusmsg {}
    # W34: the message history, NEWEST FIRST, capped at histmax (R509)
    variable statushist {}
    variable histmax 50
    # W07: the selector grid's shared radio variable.  EMPTY means no selector
    # is armed, which is also what R201's re-click-to-disarm returns it to.
    variable selmode {}
    # W09: off | family | wave (spec §6).  Initial `off` = pick from the
    # schematic canvas.
    variable pickscope off
    # W10: Clip, INITIAL 1 (spec §4 W10 says so in bold, and R304 is what it
    # means: evaluation is restricted to the displayed X range).
    variable clip 1
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
#
# ⚠ AMENDED by item 2's fix round (spec §4 "First-open size", ruled 2026-08-15).
# Phase 0 picked {0.21 0.36 0.64} against EMPTY placeholder panes, where any
# split looks plausible.  Once phase 1b put the real controls in, the Buffer
# pane's share was 15% of 597 px = 81 px for a widget stack that requests 124
# (`text -height 4` = 72 + the 23 px toolbar + 29 px of labelframe chrome), so
# the tool's primary work surface rendered ONE AND A HALF of its four lines —
# `.calc.buf bbox 3.0` and `bbox 4.0` both empty — while `cget -height` still
# said 4 and 299 checks stayed green.  The arithmetic the fractions now satisfy,
# at the first-open pw extent of 657 px (see calc::min_floor):
#
#   pane            wants (reqheight)   gets       margin
#   .calc.pw.sel    119                 0.21       138      +19
#   .calc.pw.buf    124                 0.42-0.21  133       +9
#   .calc.pw.stk    133                 0.645-0.42 143      +10
#   .calc.pw.bot     67 (-minsize 140)  1-0.645    228      +88
#
# The surplus goes to the bottom pane on purpose: it is the one item 4 fills
# (function browser + keypad) and the only one whose contents still grow.
# If a later item changes a pane's contents, re-measure — the check that pins
# this is S19's "the buffer shows all four of its lines at first open", which
# reads `bbox 4.0`, not a cget.
proc calc::pw_list {} {
    return {
        {.calc.pw     vertical   3 {0.21 0.42 0.645}}
        {.calc.pw.bot horizontal 1 {0.78}}
    }
}

# ---------------------------------------------------------------------------
# The toplevel's minimum size.
#
# ⚠ THE MINIMUM MUST BE DERIVED FROM THE CONTENTS, not guessed.  Phase 0 wrote
# `wm minsize .calc 560 620` against empty placeholder panes; phase 1b then put
# a 614 px selector grid in, and at the window's OWN declared minimum the grid
# overflowed its pane by 66 px — `winfo containing` at the centres of
# `.calc.sel.zm` and `.calc.sel.data` returned the EMPTY STRING (nothing of them
# on screen) while `winfo ismapped` still returned 1, which is the trap the
# comment in build_panes warns about.  `data` is an ENABLED selector, and
# because save_layout persists the geometry the clipped state survived a
# close/reopen: once a user had shrunk the window those two selectors were
# permanently unreachable.
#
# So the floor below is a FLOOR, and calc::apply_minsize raises it to whatever
# the selector pane actually requests.  A vertical panedwindow gives every pane
# its own full width, and `.calc.pw` is packed edge to edge in the toplevel, so
# the width the toplevel needs IS `winfo reqwidth .calc.pw.sel` (the widest of
# the three rows it holds, plus the labelframe's own chrome).  A grid that grows
# — a longer id, a bigger font, item 4's keypad — carries the minimum with it
# instead of silently clipping.
#
# The height floor moved 620 -> 680 in the same round: at 620 the four panes'
# requested heights (119 + 124 + 133 + 140) plus three sashes fit only with
# ~0 px of margin at any sash split S11 still accepts, and a zero-margin layout
# re-clips the moment a font changes.  680 buys every pane at least 9 px.
proc calc::min_floor {} { return {560 680} }

proc calc::apply_minsize {} {
    if {![winfo exists .calc]} { return {} }
    foreach {w h} [calc::min_floor] break
    if {[winfo exists .calc.pw.sel]} {
        set need [winfo reqwidth .calc.pw.sel]
        if {[string is integer -strict $need] && $need > $w} { set w $need }
    }
    wm minsize .calc $w $h
    return [list $w $h]
}

# ---------------------------------------------------------------------------
# The palette (spec R113 / RULING-1)
#
# Every role below names ONE source and is READ from it, never copied.
#
#   role        source                                              light value
#   ----------  --------------------------------------------------  -----------
#   window      ase::palette panel   (ase_window.tcl:151)            #f2f2f2
#   panel       ase::palette panel                                   #f2f2f2
#   header      ase::palette header  — strips/active menu entries    #e8e8e8
#   field       ase::palette table   — list and entry backgrounds    #ffffff
#   accent      ase::palette accent  — the pane-title dark red       #8b0000
#   fieldfg     ase::palette fieldfg — text on a `field` surface     #000000
#   selectbg    ase::palette selectbg                                #4a6984
#   selectfg    ase::palette selectfg                                #ffffff
#   disabledfg  option db disabledForeground (xschem.tcl:15546)      grey50
#
# ⚠ `fieldfg`/`selectbg`/`selectfg` used to be read with
# `ttk::style lookup Ase.Treeview ...`, which was wrong twice and is recorded
# here so it is not reintroduced.  (1) `lookup` walks the style NAME CHAIN and
# falls through to ttk's ROOT style when the requested option is not set on the
# named style — and ase::theme set none of these three, so all three came from
# the ambient ttk theme, not from the browser: `ttk::style lookup
# NoSuchStyle.Treeview -foreground` returned the identical value, so a check
# comparing the two sides could never notice a wrong source.  (2) The
# fallthrough is not even deterministic — one run in this tree resolved
# selectbg/selectfg to the ROOT style's `#d9d9d9`/`#000000`, which would have
# made selected text in the status entry invisible for the whole session.
# ase::palette now NAMES those three and ase::theme APPLIES them to
# Ase.Treeview, so the browser owns them and this reads the same dict the
# browser's own widgets are painted from.
#
# ⚠ There are no fallback literals.  A role that silently defaulted would paint
# a widget a plausible colour that no `cget` check could tell from a deliberate
# one — and would keep painting the OLD value forever if the palette moved.  An
# unresolvable role is a bug, so it throws.
#
# `disabledfg` is deliberately NOT a browser colour: it is xschem's own
# tree-wide convention for greyed-out text (`option add *disabledForeground
# {grey50}`, set for both colour schemes at xschem.tcl:15546/15564), and it is
# used here for exactly that — the disabled Browse stub and the muted pane
# hints.  R113 says so; do not "fix" it into ase::palette.
#
# `window` and `panel` are the same colour today and are still two roles: the
# reference tool (ref/viva_xl_calculator.png) has a light neutral window with
# slightly separated panels, and one of the two will move before the other.
proc calc::color_roles {} {
    return {window panel header field accent fieldfg selectbg selectfg disabledfg}
}

# role -> source, as a script evaluated at the global level.
proc calc::color_sources {} {
    return {
        window     {ase::palette panel}
        panel      {ase::palette panel}
        header     {ase::palette header}
        field      {ase::palette table}
        accent     {ase::palette accent}
        fieldfg    {ase::palette fieldfg}
        selectbg   {ase::palette selectbg}
        selectfg   {ase::palette selectfg}
        disabledfg {option get . disabledForeground DisabledForeground}
    }
}

# ⚠ Resolved on every call, and NOT cached.  A cached palette is a palette that
# can be wrong for the whole life of the process with no way to re-resolve, and
# the only guard a cache can cheaply carry is "not the empty string", which a
# wrong-but-plausible value walks straight through.  The sources are a dict
# lookup and an option-database read; there is nothing here worth cacheing.
proc calc::palette {} {
    set out {}
    foreach {role src} [calc::color_sources] {
        set v {}
        catch {set v [uplevel #0 $src]}
        if {$v eq {}} {
            error "calc::palette: role '$role' did not resolve from {$src}"
        }
        lappend out $role $v
    }
    return $out
}

proc calc::color {role} {
    set pal [calc::palette]
    if {[dict exists $pal $role]} { return [dict get $pal $role] }
    error "calc::color: unknown role '$role' (have: [calc::color_roles])"
}

# Raise-or-open.  Spec R101: one Calculator, not one per invocation.
proc calc::open {} {
    if {[winfo exists .calc]} {
        wm deiconify .calc
        raise .calc
        focus .calc
        # W05 answers about the CURRENT xschem context, and a raise is the
        # moment the answer is most likely to have changed since the last one.
        catch {calc::results_refresh}
        return .calc
    }
    return [calc::build]
}

proc calc::close {} {
    variable statusmsg
    variable statushist
    # D5: capture the layout before the widgets go away, and swallow the
    # errors a half-destroyed panedwindow raises.
    catch {calc::save_layout}
    catch {destroy .calc}
    # R508: the message history belongs to the WINDOW.  The layout persists
    # across a close (that is the whole of save_layout); the messages must not,
    # or a reopened Calculator presents the last session's notices about a raw
    # that may no longer be loaded — the same trap R705 names.
    set statusmsg {}
    set statushist {}
}

# ---------------------------------------------------------------------------
# Build

proc calc::build {} {
    variable optnever
    variable optalways

    toplevel .calc
    wm title .calc {xschem Calculator}
    wm protocol .calc WM_DELETE_WINDOW calc::close
    # the FLOOR now; tightened to what the selector grid needs once the panes
    # exist and have a requested width (below, after restore_layout)
    calc::apply_minsize
    .calc configure -background [calc::color window]

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

    # ...and NOW the panes have a requested width, so the toplevel minimum can
    # be raised to what the selector grid needs.  Deliberately AFTER the
    # restore: a geometry saved while the window was clipped is replayed first
    # and then corrected upward by the new minimum, which is what makes the
    # clipped state self-heal on reopen instead of persisting for the session.
    calc::apply_minsize

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
    # Menus take the palette the same way the waveform viewer's menubar does
    # (wave_viewer.tcl:17527-17537): panel background, header as the active
    # (hover) background.  A stock grey80 menubar over an #f2f2f2 window is a
    # visible seam, and the browser already solved it this way.
    #
    # ⚠ -foreground/-activeforeground are set TOO, which the browser's menubar
    # forgets to do.  A background from the palette and a foreground from the
    # startup option database is not a half-fix, it is a legibility bug: under
    # $dark_gui_colorscheme the option database says `*foreground white`
    # (xschem.tcl:15560), so File/Tools/View/Options/Constants/Help would be
    # white text on this window's light #f2f2f2 bar — invisible.  Phase 0, which
    # set no colours at all, was readable in both schemes; a colour layer must
    # not be a regression for half the users.  Every widget in this file that
    # takes a palette background takes a palette foreground with it.
    menu .calc.mbar -tearoff 0 -takefocus 0 \
        -background [calc::color panel] -activebackground [calc::color header] \
        -foreground [calc::color fieldfg] -activeforeground [calc::color fieldfg] \
        -disabledforeground [calc::color disabledfg]
    foreach {label sub} {
        File file  Tools tools  View view
        Options options  Constants constants  Help help
    } {
        menu .calc.mbar.$sub -tearoff 0 -takefocus 0 \
            -background [calc::color panel] -activebackground [calc::color header] \
            -foreground [calc::color fieldfg] -activeforeground [calc::color fieldfg] \
            -disabledforeground [calc::color disabledfg]
        .calc.mbar add cascade -label $label -menu .calc.mbar.$sub
        .calc.mbar.$sub add command -label {(phase 1: not implemented)} \
            -state disabled
    }
}

# ---------------------------------------------------------------------------
# W32-W34 — the status area, and R506-R509, its contract
#
# W33 is an ENTRY, not a label: R603 requires an evaluated scalar to be left
# selectable and copyable, and only an entry gives that.  It is -state readonly
# (so it shows -readonlybackground, which is why that option carries the field
# colour) and driven through its -textvariable, never `configure -text`.
#
# W34 is a readonly ttk::combobox two characters wide — the house combobox
# (recon/widgets.md §1) shrunk to the dropdown button the reference draws at
# the right end of the status bar.  Its -values ARE the history: "reveals the
# last 50 messages" needs no other machinery, which is why there is none.
#
# ⚠ ...but a two-character combobox has a two-character DROPDOWN.  ttk sizes the
# popdown to the combobox's own pixel width (ttk/combobox.tcl:363), so the
# widget that is supposed to "reveal the last 50 messages" revealed about three
# characters of each: measured 35 px wide, showing `Buf`, `Plo`, `Eva`.  The
# knob is the style option -postoffset {dx dy dw dh}, which the same code adds
# to the popdown's placement: shifting it left and widening it makes the LIST
# readable while the BUTTON stays the small dropdown the reference draws.
# CALC_POPDOWN_EXTRA is that widening, in pixels.
#
# The style is Calculator-local, not the browser's Ase.TCombobox, because
# reaching Ase.TCombobox means calling ase::theme, whose global font side
# effect is the trap recorded in the header comment.
proc calc::popdown_extra {} { return 460 }

#
# ⚠ `ttk::style configure ... -fieldbackground` DOES NOT REACH A READONLY
# COMBOBOX.  Both comboboxes here are `-state readonly` (that is what a chooser
# is), and in this tree's ttk theme the readonly field is painted from the
# style's STATE MAP, not its base option — so the two comboboxes rendered with
# the stock #d9d9d9 field while `ttk::style configure Calc.Field.TCombobox
# -fieldbackground` cheerfully reported #ffffff and the checks that read the
# style option were green about a colour that was not on screen.  MEASURED by
# sampling the live window: the dest combobox's field read (217,217,217) beside
# a `.calc.status.msg` Entry in the same role reading (255,255,255).
# The base `configure` stays (it is what an editable combobox would use, and it
# is the value the map is derived from); the `map` is what actually paints.
proc calc::style_init {} {
    catch {
        ttk::style configure Calc.TCombobox \
            -fieldbackground [calc::color field] \
            -postoffset [list [expr {-[calc::popdown_extra]}] 0 \
                              [calc::popdown_extra] 0]
    }
    # ⚠ The second style exists because -postoffset is a property of the STYLE,
    # not of the widget.  W13 (the plot-destination combobox) is a normal-width
    # combobox whose popdown must sit under itself; giving it Calc.TCombobox
    # would shift its list 460 px to the left and off the window.  Same field
    # colour, no offset.
    catch {
        ttk::style configure Calc.Field.TCombobox \
            -fieldbackground [calc::color field]
    }
    foreach st {Calc.TCombobox Calc.Field.TCombobox} {
        catch {
            ttk::style map $st \
                -fieldbackground [list readonly [calc::color field]] \
                -foreground      [list readonly [calc::color fieldfg]] \
                -selectbackground [list readonly [calc::color field]] \
                -selectforeground [list readonly [calc::color fieldfg]]
        }
    }
}

# ---------------------------------------------------------------------------
# Phase 1 is REAL BUT INERT, and R506 ("every operation that changes the buffer
# or the stack updates the status area; silence is a bug") is made true of the
# inert window here: every phase-1 -command routes through this one proc, which
# names the control and the plan phase that will implement it.  A user pressing
# a button that does nothing and says nothing cannot tell it from a broken one.
proc calc::inert {what phase} {
    return [calc::status "$what: not implemented (phase $phase)"]
}

proc calc::build_status {} {
    variable statusmsg
    variable statushist
    set statusmsg {}
    set statushist {}

    calc::style_init
    frame .calc.status -background [calc::color panel]
    entry .calc.status.msg -textvariable ::calc::statusmsg -state readonly \
        -relief sunken -borderwidth 1 -takefocus 0 \
        -background [calc::color field] \
        -readonlybackground [calc::color field] \
        -foreground [calc::color fieldfg] \
        -selectbackground [calc::color selectbg] \
        -selectforeground [calc::color selectfg]
    ttk::combobox .calc.status.hist -state readonly -width 2 -values {} \
        -takefocus 0 -style Calc.TCombobox
    bind .calc.status.hist <<ComboboxSelected>> {calc::status_recall}
    pack .calc.status.hist -side right -padx 2 -pady 1
    pack .calc.status.msg  -side left -fill x -expand 1 -padx 2 -pady 1
}

# R507/R508/R509.  Write a line to the status area and remember it.
#
#   - no window (never built, closed, or --nogui where `winfo` does not exist):
#     silent no-op returning {}.  This proc is called from stubs, teardown and
#     headless tests; the ciw_echo precedent (ciw.tcl:120-127) is the same.
#   - empty message: CLEARS the field and records nothing.  A blank history row
#     is not information.
#   - otherwise: prepend, cap at histmax, drop the OLDEST (the tail).
#
# Returns the message it wrote, so a caller can `return [calc::status ...]`.
proc calc::status {{msg {}}} {
    variable statusmsg
    variable statushist
    variable histmax
    if {[info commands winfo] eq {}} { return {} }
    if {![winfo exists .calc.status.msg]} { return {} }
    set statusmsg $msg
    if {$msg eq {}} { return {} }
    set statushist [linsert $statushist 0 $msg]
    if {[llength $statushist] > $histmax} {
        set statushist [lrange $statushist 0 [expr {$histmax - 1}]]
    }
    catch {.calc.status.hist configure -values $statushist}
    return $msg
}

# The history, newest first.  Public because every test and every later phase
# that wants to assert "it said so" needs a reader that is not the widget.
proc calc::status_history {} {
    variable statushist
    return $statushist
}

# W34 selection: re-display the chosen line, and do NOT re-record it (R509) —
# recording a recall would push the older entries out with copies of
# themselves.  The combobox's own field is emptied again because it is two
# characters wide and would otherwise show a truncated message forever.
proc calc::status_recall {} {
    variable statusmsg
    if {![winfo exists .calc.status.hist]} return
    set v [.calc.status.hist get]
    catch {.calc.status.hist set {}}
    if {$v ne {}} { set statusmsg $v }
    return
}

# ---------------------------------------------------------------------------
# W03-W05 — the Results Dir row
#
# ⚠ THE PATH IS .calc.res, NOT .calc.pw.sel.res.  Spec §4's widget paths are
# normative (tests address widgets by path) and W03 says `.calc.res`, while
# plan step 1.1 says the row lives inside the Selectors pane.  Both hold at
# once through pack's `-in`: a widget may be managed by its parent OR by any
# descendant of its parent, so `.calc.res` (child of `.calc`) is packed into
# `.calc.pw.sel`.  Two consequences worth knowing before editing:
#   - stacking order is creation order among siblings, so .calc.res must be
#     created AFTER .calc.pw or it maps behind the panedwindow and is
#     invisible.  build_panes creates it last, and raises it anyway.
#     ⚠ `winfo ismapped` cannot see this: it returns 1 for a widget that is
#     mapped and completely obscured, so the whole row can vanish behind
#     .calc.pw with the suite green.  The guards that DO see it are S15's
#     "row stacks above the panedwindow" (its position in `winfo children
#     .calc`) and "row is the topmost widget at its own centre" (`winfo
#     containing`); both were added after `lower .calc.res` survived 144
#     checks.  If you move this code, keep them pointed at it.
#   - `pack forget` on it detaches it from .calc.pw.sel, not from .calc; the
#     collapse toggle relies on that.
#
# Spec §13 records the deliberate deviation from Cadence: "Results Dir" is a
# .raw FILE path here, because ngspice writes one file and not a PSF directory.
proc calc::build_res {} {
    variable rescollapsed
    set rescollapsed 0

    frame .calc.res -background [calc::color panel]
    # The collapse toggle (W03).  Layout, not behaviour, so it is live.
    # every palette background carries a palette foreground with it, hover
    # included — see the note on the menubar in build_menubar
    button .calc.res.tog -text {v} -width 2 -takefocus 0 -padx 1 -pady 0 \
        -command calc::res_toggle \
        -background [calc::color panel] -activebackground [calc::color header] \
        -foreground [calc::color accent] -activeforeground [calc::color accent]
    label .calc.res.lab -text {Results Dir:} -anchor w \
        -background [calc::color panel] -foreground [calc::color fieldfg]
    entry .calc.res.path -textvariable ::calc::respath -state readonly \
        -takefocus 0 -relief sunken -borderwidth 1 \
        -background [calc::color field] \
        -readonlybackground [calc::color field] \
        -foreground [calc::color fieldfg] \
        -selectbackground [calc::color selectbg] \
        -selectforeground [calc::color selectfg]
    # W05's note allows editing the path via Browse.  Browse is NOT phase 1a;
    # the button exists disabled so the row has its final shape (plan's rule:
    # a control that is missing "because it comes later" is not allowed, a
    # control that is inert is).
    button .calc.res.browse -text {...} -width 2 -takefocus 0 -padx 1 -pady 0 \
        -state disabled -command {calc::status {Browse: not implemented}} \
        -background [calc::color panel] -activebackground [calc::color header] \
        -foreground [calc::color fieldfg] -activeforeground [calc::color fieldfg] \
        -disabledforeground [calc::color disabledfg]

    pack .calc.res.tog    -side left  -padx {2 4} -pady 2
    pack .calc.res.lab    -side left  -padx {0 4} -pady 2
    pack .calc.res.browse -side right -padx {4 2} -pady 2
    pack .calc.res.path   -side left  -fill x -expand 1 -padx {0 2} -pady 2

    calc::results_refresh
}

# The loaded raw's full path, or {}.
#
# ⚠ `xschem raw rawfile` (scheduler.c:10005) sits inside the `raw && raw->values`
# gate at scheduler.c:9881, and the chain's final else THROWS "No raw file
# loaded" (scheduler.c:10046) — it does not return the empty string.  The house
# idiom is therefore a catch, exactly as wave_viewer.tcl:17341 does it.
proc calc::results_path {} {
    set p {}
    catch {set p [xschem raw rawfile]}
    return $p
}

# W05's text.  With nothing loaded the entry says so in words: an empty readonly
# entry and a broken one look identical, and this row is the first thing a user
# reads when an expression fails to resolve.  The wording is the browser's own
# (wave_viewer.tcl:7886).
proc calc::results_refresh {} {
    variable respath
    set p [calc::results_path]
    if {$p eq {}} {
        set respath {(no raw file loaded)}
    } else {
        set respath $p
    }
    return $respath
}

# W03 collapse.  Hides everything except the toggle itself, which is what makes
# it re-expandable.  R110 (persisted collapse state) is plan phase 10; this is
# the layout half only.
proc calc::res_toggle {} {
    variable rescollapsed
    if {![winfo exists .calc.res]} return
    if {$rescollapsed} {
        pack .calc.res.lab    -side left  -padx {0 4} -pady 2 -after .calc.res.tog
        pack .calc.res.browse -side right -padx {4 2} -pady 2
        pack .calc.res.path   -side left  -fill x -expand 1 -padx {0 2} -pady 2
        .calc.res.tog configure -text {v}
        set rescollapsed 0
    } else {
        pack forget .calc.res.lab .calc.res.path .calc.res.browse
        .calc.res.tog configure -text {>}
        set rescollapsed 1
    }
    calc::status [expr {$rescollapsed ? {Results Dir collapsed}
                                      : {Results Dir expanded}}]
    return $rescollapsed
}

# ---------------------------------------------------------------------------
# W06-W07 — the 22-button selector grid (spec §5, plan step 1.2)
#
# THE LAYOUT IS NORMATIVE and comes from spec §5 plus the ASCII layout in
# doc/claude/code_analysis/viva_calculator_explained.md §4 (region C): two rows
# of eleven, in three visual groups of 4 / 3 / 4:
#
#     vt  vf  vdc  vs  |  op   var  vn   |  sp  vswr  hp  zm
#     it  if  idc  is  |  opt  mp   vn2  |  zp  yp    gd  data
#
# ⚠ ref/viva_xl_calculator.png is the XL calculator and shows a DIFFERENT id
# set (`os`, `ot`, no `data` in that row).  It is the COLOUR reference only;
# the ids and their row come from spec §5.
#
# Column layout, and why it is not the house radiobutton idiom verbatim:
# recon/widgets.md §2 says the tree has no N-by-M radiobutton grid anywhere and
# that the idiom is "loop into its own frame, pack -side left, grid the frame
# as one cell".  That idiom cannot produce these PATHS: spec §4 W07 is
# `.calc.sel.<id>`, i.e. the buttons are direct children of .calc.sel, so a
# per-group frame would make them .calc.sel.g1.vt and every test that addresses
# a widget by path would be addressing the wrong one.  What is kept from the
# idiom is the part that matters — the buttons are built by a loop over ONE
# table (calc::sel_rows), so the layout is data, not twenty-two hand-written
# calls.  The grouping is done with two spacer columns carrying a hairline
# separator, which is what the reference draws between groups.
#
# ⚠ Tk writes a radiobutton's -variable BEFORE it fires -command
# (wave_viewer.tcl:17665).  Nothing here diffs old against new, and nothing
# later may: a -command that decides "did this change?" always sees "no".
# R201's re-click-to-disarm therefore cannot be a -command diff; it is phase 6
# and will need its own remembered value.
#
# ⚠ -selectcolor is the indicator's FIELD colour, NOT its "lit" colour, and
# getting that backwards paints the grid unreadable.  MEASURED here (a scanline
# across .calc.sel.vt's indicator at three states, on this Tk):
#     ::calc::selmode = {}   background disc + grey dot   (Tk's TRISTATE look,
#                                                          which is what "no
#                                                          selector armed" is)
#     ::calc::selmode = vt   -selectcolor disc + BLACK dot (armed)
#     ::calc::selmode = vf   -selectcolor disc, flat       (not armed)
# So with `-selectcolor [calc::color selectbg]` all 22 buttons render as solid
# dark-blue blobs and the armed one is the same blob with a dot in it.  The
# role that means "the white inside a field" is `field`, which is also what
# xschem's own startup option database says for every other radiobutton in the
# tree (`option add *selectColor {white}`, xschem.tcl:15552).

proc calc::sel_rows {} {
    return {
        {{vt vf vdc vs} {op  var vn}  {sp vswr hp zm}}
        {{it if idc is} {opt mp  vn2} {zp yp   gd data}}
    }
}

# The eight that are rendered and DISABLED (spec §1.2): the seven RF ids and
# `mp`.  Rendering them is information — removing them would change the shape
# of the grid, and the grid's shape is the tool's identity — so each one
# carries the reason it cannot be armed, as a tooltip and as the status line it
# writes when clicked (R202).
proc calc::sel_disabled {} {
    return {
        sp   {no S-parameter analysis in ngspice}
        zp   {no S-parameter analysis in ngspice}
        yp   {no S-parameter analysis in ngspice}
        hp   {no S-parameter analysis in ngspice}
        vswr {no S-parameter analysis in ngspice}
        zm   {no S-parameter analysis in ngspice}
        gd   {no S-parameter analysis in ngspice}
        mp   {needs a model-database reader}
    }
}

# the width of a spacer column between two groups, in pixels
proc calc::sel_gap {} { return 12 }

# ⚠ Tk's DEFAULT -tristatevalue is the EMPTY STRING, and the empty string is
# exactly what ::calc::selmode holds when nothing is armed (and what R201's
# re-click-to-disarm returns it to).  A radiobutton whose -variable equals its
# -tristatevalue renders in the MIXED look — a panel-grey disc with a grey dot
# in it — so the state the window is BORN in drew all 22 selectors as though
# every one of them were half-armed, and it was the only unarmed state that
# drew a dot at all.  MEASURED by scanline across .calc.sel.vt's indicator:
#     selmode {}   panel-grey (242,242,242) disc + a (127,127,127) dot
#     selmode zzz  flat white (255,255,255) disc      <- the `field` disc meant
#     selmode vt   white disc + a black (0,0,0) dot   <- armed
# "S17 nothing is armed at first open" was green while 22 indicators showed a
# dot, because the check reads the VARIABLE and the defect is in the rendering.
#
# The fix keeps {} as the normative "nothing armed" value — every later phase
# and R201 depend on it — and moves the tristate sentinel to a string no
# selector id can ever be and no legitimate state can ever hold.  Configured
# with a catch because Tk 8.4 has no -tristatevalue at all and this tree still
# targets it (see the -stretch probe in build_panes).
proc calc::sel_tristate {} { return {(no such selector)} }

proc calc::build_sel {} {
    variable selmode
    # ⚠ Seeded BEFORE the widgets exist (wave_viewer.tcl:8051-8082): a
    # radiobutton whose -variable does not exist yet CREATES it, and no check
    # can then tell "deliberately unarmed" from "happened to be empty".
    set selmode {}

    frame .calc.sel -background [calc::color panel]
    set dis [calc::sel_disabled]
    set r 0
    foreach rowgroups [calc::sel_rows] {
        set col 0
        set g 0
        foreach group $rowgroups {
            if {$g > 0} {
                # the visible gap between groups, drawn once (on the first row
                # pass) as a hairline spanning both rows
                if {$r == 0} {
                    frame .calc.sel.sep$g -width 1 \
                        -background [calc::color disabledfg]
                    grid .calc.sel.sep$g -row 0 -column $col -rowspan 2 \
                        -sticky ns -padx [expr {[calc::sel_gap] / 2}]
                }
                incr col
            }
            foreach id $group {
                radiobutton .calc.sel.$id -text $id -value $id \
                    -variable ::calc::selmode -takefocus 0 \
                    -padx 1 -pady 0 -borderwidth 1 \
                    -background [calc::color panel] \
                    -activebackground [calc::color header] \
                    -foreground [calc::color fieldfg] \
                    -activeforeground [calc::color fieldfg] \
                    -disabledforeground [calc::color disabledfg] \
                    -selectcolor [calc::color field] \
                    -command [list calc::sel_click $id]
                # see calc::sel_tristate: without this, selmode {} IS the
                # tristate value and every selector renders half-armed
                catch {.calc.sel.$id configure \
                           -tristatevalue [calc::sel_tristate]}
                if {[dict exists $dis $id]} {
                    .calc.sel.$id configure -state disabled
                    # the tooltip spec §1.2 asks for.  `balloon`
                    # (xschem.tcl:12551) is the tree's ONE tooltip mechanism —
                    # no proc named tooltip/set_tooltip exists — and it BAKES
                    # its string into the <Enter> binding at attach time, which
                    # is fine here because these strings never change.
                    catch {balloon .calc.sel.$id [dict get $dis $id]}
                    # R202: a disabled selector cannot be armed, and says why.
                    # ⚠ -command cannot deliver that: Tk's button `invoke` and
                    # the Button class bindings both return early on a disabled
                    # widget, so a disabled control's -command NEVER fires.  An
                    # explicit <Button-1> binding does fire (X still delivers
                    # events to a disabled widget), and it cannot arm anything
                    # because it does not touch ::calc::selmode.
                    bind .calc.sel.$id <Button-1> \
                        [list calc::sel_refuse $id [dict get $dis $id]]
                }
                grid .calc.sel.$id -row $r -column $col -sticky w -padx 1
                incr col
            }
            incr g
        }
        incr r
    }
}

# An enabled selector: arming the pick is phase 6 (plan 6.1-6.2).  The radio
# variable is written by Tk itself — that is the widget's own state, not
# behaviour this phase is wiring — and nothing else happens.
proc calc::sel_click {id} {
    return [calc::inert "selector $id: signal picking" 6]
}

# A disabled selector (spec §1.2 / R202).  Explains, and leaves
# ::calc::selmode exactly as it found it.
proc calc::sel_refuse {id why} {
    return [calc::status "selector $id is not available: $why"]
}

# ---------------------------------------------------------------------------
# W08-W14 — the mode strip (spec §6, plan step 1.3)
#
# Off/Family/Wave is the PICK SCOPE (§6): where the next pick comes from, not
# what it picks.  Clip is evaluation-only (R305: it never rewrites the buffer),
# and it starts ON.
#
# W11/W12/W14 are drawn as ICONS in the reference (a waveform, an arrow, a
# table).  They are TEXT here.  Ruled by the crew, 2026-08-15: this tree ships
# no icon set a new dialog can draw from (src/resources.tcl is base64 toolbar
# icons for the main window's own toolbar, recon/theming.md §1), and an
# invented glyph font would be a second asset to maintain for three buttons.
# Written into spec §4 W11/W12/W14.
proc calc::build_mode {} {
    variable pickscope
    variable clip
    # seeded before the widgets exist, same rule as the selector grid
    set pickscope off
    set clip 1

    frame .calc.mode -background [calc::color panel]
    foreach {id label} {off Off family Family wave Wave} {
        radiobutton .calc.mode.$id -text $label -value $id \
            -variable ::calc::pickscope -takefocus 0 -padx 1 -pady 0 \
            -background [calc::color panel] \
            -activebackground [calc::color header] \
            -foreground [calc::color fieldfg] \
            -activeforeground [calc::color fieldfg] \
            -disabledforeground [calc::color disabledfg] \
            -selectcolor [calc::color field] \
            -command [list calc::inert "pick scope $label" 6]
        pack .calc.mode.$id -side left -padx {0 3} -pady 1
    }
    checkbutton .calc.mode.clip -text {Clip} -variable ::calc::clip \
        -takefocus 0 -padx 1 -pady 0 \
        -background [calc::color panel] \
        -activebackground [calc::color header] \
        -foreground [calc::color fieldfg] \
        -activeforeground [calc::color fieldfg] \
        -disabledforeground [calc::color disabledfg] \
        -selectcolor [calc::color field] \
        -command [list calc::inert {Clip} 6]
    pack .calc.mode.clip -side left -padx {8 6} -pady 1

    foreach {id label phase} {plot Plot 3 eval Eval 3} {
        button .calc.mode.$id -text $label -takefocus 0 -padx 4 -pady 0 \
            -background [calc::color panel] \
            -activebackground [calc::color header] \
            -foreground [calc::color fieldfg] \
            -activeforeground [calc::color fieldfg] \
            -disabledforeground [calc::color disabledfg] \
            -command [list calc::inert $label $phase]
        pack .calc.mode.$id -side left -padx {0 3} -pady 1
    }

    # W13.  The house combobox (recon/widgets.md §1): ttk, readonly, -values at
    # creation, `$w set` for the initial value, and combo_letter_cycle bound
    # because a readonly ttk::combobox does not type-to-cycle by itself
    # (xschem.tcl:10828).  The three values are the ones R601 hands to
    # wviewer::set_plot_dest in phase 3; the LABELS are fixed here.
    ttk::combobox .calc.mode.dest -state readonly -width 10 \
        -values {Append Replace {New Strip}} -takefocus 0 \
        -style Calc.Field.TCombobox
    .calc.mode.dest set {Append}
    bind .calc.mode.dest <Key> {combo_letter_cycle %W %A; break}
    bind .calc.mode.dest <<ComboboxSelected>> {calc::dest_changed}
    pack .calc.mode.dest -side left -padx {6 3} -pady 1

    button .calc.mode.table -text {Table} -takefocus 0 -padx 4 -pady 0 \
        -background [calc::color panel] \
        -activebackground [calc::color header] \
        -foreground [calc::color fieldfg] \
        -activeforeground [calc::color fieldfg] \
        -disabledforeground [calc::color disabledfg] \
        -command [list calc::inert {Table} 10]
    pack .calc.mode.table -side left -padx {3 0} -pady 1
}

# W13's selection is remembered by the widget (that is what a combobox is for)
# and consumed by phase 3's Plot.  Saying so is R506.
proc calc::dest_changed {} {
    if {![winfo exists .calc.mode.dest]} return
    return [calc::inert "plot destination [.calc.mode.dest get]" 3]
}

# ---------------------------------------------------------------------------
# W15-W22 — the buffer and its toolbar (plan step 1.4)
#
# The buffer is the one phase-1 control that is not inert, and deliberately so:
# it is a text widget, and typing into a text widget is the widget working, not
# a behaviour this phase is wiring.  -undo 1 is the blanket house default on
# every editable text in the tree (recon/widgets.md §5, 16 sites).
#
# ⚠ Undo/redo are created DISABLED and stay that way here (W22).  R505 makes
# them cover buffer edits AND stack operations as ONE history, which is phase 2
# (2.3) and phase 4 (4.4); an undo button that drove only the text widget's own
# stack would be a different feature wearing the same label.
proc calc::build_buf {} {
    text .calc.buf -height 4 -undo 1 -wrap none -exportselection 1 \
        -relief sunken -borderwidth 1 \
        -background [calc::color field] \
        -foreground [calc::color fieldfg] \
        -insertbackground [calc::color fieldfg] \
        -selectbackground [calc::color selectbg] \
        -selectforeground [calc::color selectfg]

    frame .calc.btb -background [calc::color panel]
    # id / label / the plan phase that makes it work.  Order is spec §4's:
    # W17 enter, W18 pop, W19 swap roll clrbuf clrstk, W20 M+, W21 ME,
    # W22 undo redo.
    foreach {id label phase} {
        enter  {Enter}  4
        pop    {Pop}    4
        swap   {Swap}   4
        roll   {Roll}   4
        clrbuf {ClrBuf} 2
        clrstk {ClrStk} 4
        mplus  {M+}     9
        me     {ME}     9
        undo   {Undo}   2
        redo   {Redo}   2
    } {
        button .calc.btb.$id -text $label -takefocus 0 -padx 3 -pady 0 \
            -background [calc::color panel] \
            -activebackground [calc::color header] \
            -foreground [calc::color fieldfg] \
            -activeforeground [calc::color fieldfg] \
            -disabledforeground [calc::color disabledfg] \
            -command [list calc::inert $label $phase]
        pack .calc.btb.$id -side left -padx 1 -pady 1
    }
    .calc.btb.undo configure -state disabled
    .calc.btb.redo configure -state disabled
}

# ---------------------------------------------------------------------------
# W23-W25 — the Stack (plan step 1.5)
#
# ⚠ TOP OF STACK IS INDEX 0 (spec §4 W24).  Nothing pushes yet — the model is
# phase 4 (R502-R504) — but the direction has to be written down now, because
# it is invisible in an empty listbox and every later phase reads it: R503's
# Pop takes item 0, R504's cap drops the LAST item, and R511's operand order
# (`[b, a]` + `+` -> `[a b +]`) is stated in the same convention.  A listbox
# filled the other way round would pass every widget check and get the operand
# order backwards, which the spec calls the classic bug.
#
# ⚠ The PANE labelframe .calc.pw.stk is retitled to nothing when this row is
# built.  Spec W23 makes `.calc.stk` a labelframe titled `Stack` and phase 0
# had already titled the pane that holds it `Stack`; drawing both renders the
# word twice, one inside the other.  Ruled by the crew, 2026-08-15: the spec's
# widget wins, the pane keeps its frame and loses its title.  Written into
# spec §4 W23.
proc calc::build_stk {} {
    labelframe .calc.stk -text {Stack} -padx 4 -pady 4 \
        -background [calc::color panel] -foreground [calc::color accent]

    # the four side buttons of the reference, in a column at the left
    set row 0
    foreach {id label phase} {push Push 4 pop Pop 4 del Del 4 recall Recall 4} {
        button .calc.stk.$id -text $label -takefocus 0 -padx 3 -pady 0 \
            -width 6 \
            -background [calc::color panel] \
            -activebackground [calc::color header] \
            -foreground [calc::color fieldfg] \
            -activeforeground [calc::color fieldfg] \
            -disabledforeground [calc::color disabledfg] \
            -command [list calc::inert "Stack $label" $phase]
        grid .calc.stk.$id -row $row -column 0 -sticky ew -padx {0 4} -pady 1
        incr row
    }
    listbox .calc.stk.list -height 4 -exportselection 0 -activestyle dotbox \
        -selectmode browse -borderwidth 1 -relief sunken \
        -yscrollcommand {.calc.stk.sb set} \
        -background [calc::color field] \
        -foreground [calc::color fieldfg] \
        -selectbackground [calc::color selectbg] \
        -selectforeground [calc::color selectfg]
    # ⚠ the scrollbar takes the palette too.  It was the one widget in this
    # file created with no colours at all, and it showed: a stock grey80 bar
    # with a #b3b3b3 trough (sampled: (204,204,204)) against a #f2f2f2 panel,
    # which is the visible seam RULING-1 was written about.  Every palette
    # background carries a palette foreground with it — see build_menubar.
    scrollbar .calc.stk.sb -command {.calc.stk.list yview} -takefocus 0 \
        -background [calc::color panel] \
        -activebackground [calc::color header] \
        -troughcolor [calc::color header] \
        -highlightbackground [calc::color panel]
    # ⚠ The stretch goes to an EMPTY row below the buttons, not to the last
    # button's row.  Weighting row $row-1 is the obvious thing and it spreads
    # the four buttons down the whole pane — measured, `Recall` ended up 60 px
    # under `Del` with a gap between them, which reads as two groups of
    # buttons rather than one column.  The listbox spans one row further so it
    # still fills.
    grid .calc.stk.list -row 0 -column 1 -rowspan [expr {$row + 1}] -sticky nsew
    grid .calc.stk.sb   -row 0 -column 2 -rowspan [expr {$row + 1}] -sticky ns
    grid rowconfigure    .calc.stk $row -weight 1
    grid columnconfigure .calc.stk 1 -weight 1
}

proc calc::build_panes {} {
    variable optnever
    variable optalways

    # The panedwindows carry the palette too: the sash strips are the only
    # part of them that is ever visible, and a grey80 strip between #f2f2f2
    # panes is exactly the seam RULING-1 was about.
    panedwindow .calc.pw -orient vertical \
        -sashwidth 5 -sashrelief raised -showhandle 1 -borderwidth 0 \
        -background [calc::color panel]
    panedwindow .calc.pw.bot -orient horizontal \
        -sashwidth 5 -sashrelief raised -showhandle 1 -borderwidth 0 \
        -background [calc::color panel]

    # The panes.  A pane whose real contents have landed is a bare labelframe
    # (calc::panelframe); one still waiting for its item keeps the phase-0
    # placeholder hint inside it (calc::placeholder).  Three of the five are
    # filled as of item 2; Functions and Keypad are item 4's.
    #
    # ⚠ .calc.pw.stk is titled EMPTY, not `Stack`.  Spec W23 puts a labelframe
    # titled `Stack` INSIDE it (calc::build_stk), and two nested boxes both
    # captioned Stack is the word drawn twice.  See the note on build_stk.
    calc::panelframe  .calc.pw.sel      {Selectors}
    calc::panelframe  .calc.pw.buf      {Buffer}
    calc::panelframe  .calc.pw.stk      {}
    calc::placeholder .calc.pw.bot.fn   {Functions}  {category chooser + function list}
    calc::placeholder .calc.pw.bot.pad  {Keypad}     "operators,\nuser 1-4"

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

    # The pane CONTENTS, all of them children of `.calc` and drawn inside a
    # pane with `pack -in`.  Spec §4's paths are normative — `.calc.res`,
    # `.calc.sel`, `.calc.mode`, `.calc.buf`, `.calc.btb`, `.calc.stk` are all
    # children of the toplevel — and pack allows a widget to be managed by any
    # descendant of its parent, so both hold at once.  Two consequences, both
    # already paid for by the Results Dir row:
    #   - a widget packed into a non-parent maps BEHIND its siblings unless it
    #     was created after them, so these are built LAST and raised anyway.
    #     `winfo ismapped` cannot see the failure (S15's note); the guards that
    #     can are stacking order in `winfo children .calc` and `winfo
    #     containing` at the widget's own centre.
    #   - `pack forget` detaches from the PANE, not from `.calc`, which is what
    #     makes a collapse toggle possible (R110, phase 10).
    # Packing order inside .calc.pw.sel is the reference's: Results Dir row,
    # then the selector grid, then the mode strip.  `pack slaves` is asserted,
    # so a later edit cannot silently reverse it.
    calc::build_res
    calc::build_sel
    calc::build_mode
    pack .calc.res  -in .calc.pw.sel -side top -fill x
    pack .calc.sel  -in .calc.pw.sel -side top -fill x -pady {2 0}
    pack .calc.mode -in .calc.pw.sel -side top -fill x -pady {2 0}

    # W15-W22: the buffer takes the growth, its toolbar sits under it.
    #
    # ⚠ THE TOOLBAR IS PACKED FIRST, and the visual order is the reverse of the
    # packing order on purpose.  pack fills the cavity in packing order, so a
    # `-fill both -expand 1` buffer packed first takes ALL of it and the
    # fixed-height toolbar packed after it gets nothing: MEASURED at 660x700,
    # `winfo ismapped .calc.btb` was 0 and the whole button row — Enter, Pop,
    # M+, ME, undo, redo — was simply not on screen, with every widget check
    # green because the widgets all existed.  Reserving the fixed-height row
    # first is the fix; S19 asserts both are mapped AND which is on top.
    calc::build_buf
    pack .calc.btb -in .calc.pw.buf -side bottom -fill x
    pack .calc.buf -in .calc.pw.buf -side top    -fill both -expand 1

    # W23-W25
    calc::build_stk
    pack .calc.stk -in .calc.pw.stk -fill both -expand 1

    foreach w {.calc.res .calc.sel .calc.mode .calc.buf .calc.btb .calc.stk} {
        raise $w
    }
}

# A pane whose real contents have landed: the labelframe only.
proc calc::panelframe {path title} {
    # The labelframe's own title text is the "coloured accent on panel
    # headers" of the reference (ref/viva_xl_calculator.png), and it is the
    # browser's accent — ase::ui::apply_theme colours a Labelframe exactly this
    # way (ase_window.tcl:164-166).
    labelframe $path -text $title -padx 4 -pady 4 \
        -background [calc::color panel] -foreground [calc::color accent]
}

# A pane still waiting for its item: the labelframe plus a hint naming what is
# owed.  Item 4 removes the last two.
proc calc::placeholder {path title hint} {
    calc::panelframe $path $title
    # muted hint text; disabledfg is the option database's own grey50, the same
    # value every disabled widget in the tree already renders with.  It
    # replaces the literal `grey40` phase 0 wrote, which was the only hardcoded
    # colour in this file.
    label $path.hint -text $hint -anchor center -justify center \
        -background [calc::color panel] -foreground [calc::color disabledfg]
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
