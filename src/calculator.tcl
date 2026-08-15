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
# Items 1b-1d replace the bodies of the Selectors / Buffer / Stack / Functions
# / Keypad labelframes.  They must not move a sash, change a -minsize or touch
# calc::pw_list.
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
    wm minsize .calc 560 620
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

proc calc::style_init {} {
    catch {
        ttk::style configure Calc.TCombobox \
            -fieldbackground [calc::color field] \
            -postoffset [list [expr {-[calc::popdown_extra]}] 0 \
                              [calc::popdown_extra] 0]
    }
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

    # Phase 0 placeholders.  Phase 1 replaces the body of each of these with
    # the real controls; the labelframe and its pane stay.
    # (the Results Dir row is built below and packed into this pane; the hint
    # names only what item 2 still owes)
    calc::placeholder .calc.pw.sel      {Selectors}  {the 22 signal buttons, mode strip}
    calc::placeholder .calc.pw.buf      {Buffer}     {the expression being built, plus its toolbar}
    calc::placeholder .calc.pw.stk      {Stack}      {parked expressions}
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

    # W03-W05, plan step 1.1.  Created LAST so it stacks above .calc.pw (see
    # the note on build_res), and packed INTO the Selectors pane above the
    # place the selector grid takes in item 2.  `-before` pins that order; the
    # test asserts `pack slaves` so a later edit cannot silently reverse it.
    calc::build_res
    pack .calc.res -in .calc.pw.sel -side top -fill x -before .calc.pw.sel.hint
    raise .calc.res
}

proc calc::placeholder {path title hint} {
    # The labelframe's own title text is the "coloured accent on panel
    # headers" of the reference (ref/viva_xl_calculator.png), and it is the
    # browser's accent — ase::ui::apply_theme colours a Labelframe exactly this
    # way (ase_window.tcl:164-166).
    labelframe $path -text $title -padx 4 -pady 4 \
        -background [calc::color panel] -foreground [calc::color accent]
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
