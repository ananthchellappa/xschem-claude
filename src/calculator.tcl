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
#   1d  the function browser (W26-W28) over the one catalogue table, and the
#       keypad (W29-W31) — OPERATORS ONLY, per RULING-2.  With those two the
#       last placeholder is gone: every pane now holds its real controls.
#       calc::pw_list and every -minsize but ONE are untouched; the exception
#       is .calc.pw.bot.pad's, which item 4 was explicitly sent to judge
#       against the real buttons (see the note on build_panes).
#
# RESULTS BATCH ITEM 10 (2026-08-20) is the first behaviour to land out of that
# order, and deliberately so: it does not build a phase, it settles WHICH
# DATABASE the Calculator works against.  The `self` arm is gone (U6), the
# Results Dir row PICKS rather than reports (U3), Evaluate refuses and names the
# next action when there is no result (U7), and `Browse` is ruled permanently
# inert rather than unfinished (U9).  Evaluate's COMPUTATION is still phase 3's
# — this is the gate that phase was waiting on.  The four rulings and their
# mechanism are in the block above `calc::viewer_tokens`.
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
# House idiom, copied from load_file_dialog (xschem.tcl:7200) rather than
# invented:
#   - CLASSIC panedwindow, not ttk::panedwindow.  ttk::panedwindow has no
#     -minsize, and every pane here needs one (landmine D3 below).
#   - -stretch is catch-guarded, because Tk 8.4 does not have it
#     (xschem.tcl:7234).
#   - sash restore is `sash mark` then `sash dragto` (xschem.tcl:7450-7465).
#     The tree also contains a `sash place` idiom (.ins.center,
#     xschem.tcl:8450).  Both work; MIXING them in one file does not.  This
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
    # R413: the last hover help written to the status area, so that <Leave> can
    # retire ITS line and not somebody else's.
    variable fnhelp {}
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
#   .calc.pw.sel    119                 0.21       136      +17
#   .calc.pw.buf    124                 0.42-0.21  130       +6
#   .calc.pw.stk    133                 0.645-0.42 140       +7
#   .calc.pw.bot    158 (-minsize 158)  1-0.645    227      +69
#
# ⚠ RE-MEASURED FOR ITEM 4 (2026-08-15), which is the instruction this table
# carries and the one its own item did not follow at first: filling the bottom
# pair took .calc.pw.bot's requested height from the placeholder-era 67 to 158,
# and its -minsize from a hand-pinned 140 to a derived 158 (see
# calc::apply_pane_minsize).  The three numbers above it are unchanged in what
# they REQUEST; the "gets" column is the measured first-open allocation on this
# Tk, which the earlier revision of this table rounded.
#
# The surplus goes to the bottom pane on purpose: it is the one item 4 filled
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
# requested heights plus three sashes fit only with ~0 px of margin at any sash
# split S11 still accepts, and a zero-margin layout re-clips the moment a font
# changes.  ⚠ RE-MEASURED FOR ITEM 4: that sum is now 119 + 124 + 133 + 158 =
# 534 (the bottom pane went 67 -> 158 when the browser and keypad landed in it),
# which 680 still clears with room — the measured first-open allocation gives
# every pane at least +6 px (see the table above calc::pw_list).
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
# THE PANE MINIMUMS THAT FOLLOW THEIR CONTENTS (landmine D3, applied honestly).
#
# D3's contract is that a pane's -minsize is "the smallest height (or width) at
# which the contents are still usable".  Phase 0 wrote every number against
# EMPTY placeholder panes, where any number satisfies that.  Item 4 filled the
# bottom pair, and two of those numbers stopped being true the moment it did:
#
#   .calc.pw.bot       reqheight 67 -> 158, -minsize left at 140.  Dragging the
#                      bottom sash to its own legal floor gave the pane 140 and
#                      clipped `user 3` / `user 4` by 3 px — a pane dragged to a
#                      minimum that hides a control, which is the exact defect
#                      D3 exists to prevent.
#   .calc.pw.bot.pad   reqwidth 140, -minsize 140: TRUE at the shipped font and
#                      false at any larger one (at TkDefaultFont -size 12 the
#                      pane requests 164 against a pinned 140 and the keypad
#                      renders 143/152 — clipped).
#
# So the phase-0 numbers become FLOORS and this raises each of the two panes
# item 4 filled to what it really requests.  ONLY those two: the other four
# panes' contents landed in items 1-2 and no finding re-judged them, and phase-0
# layout is otherwise frozen.  The floors themselves are unchanged, so the frozen
# numbers are still the starting point — nothing here can LOWER a minimum.
#
# The order matters: this runs after the contents are packed (and after
# restore_layout, so a saved sash is replayed first and then clamped upward the
# same way apply_minsize self-heals a clipped toplevel geometry), and BEFORE the
# <Configure> binding exists, so the update idletasks it needs to get a real
# requested size cannot re-enter save_layout (landmine D6).
proc calc::apply_pane_minsize {} {
    if {![winfo exists .calc.pw] || ![winfo exists .calc.pw.bot]} { return {} }
    update idletasks
    set out {}
    foreach {pw pane dim} {
        .calc.pw     .calc.pw.bot      reqheight
        .calc.pw.bot .calc.pw.bot.pad  reqwidth
    } {
        if {![winfo exists $pane]} continue
        set have [$pw panecget $pane -minsize]
        set need [winfo $dim $pane]
        if {[string is integer -strict $have] && [string is integer -strict $need]
            && $need > $have} {
            $pw paneconfigure $pane -minsize $need
            set have $need
        }
        lappend out $pane $have
    }
    return $out
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
#   disabledfg  option db disabledForeground (xschem.tcl:15731)      grey50
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
# {grey50}`, set for both colour schemes at xschem.tcl:15731/15564), and it is
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

    # ...and the panes now hold their real contents, so the two minimums item 4
    # filled can be raised to what those contents ask for (D3).  Before the
    # <Configure> bind below, so its update idletasks cannot re-enter
    # save_layout (D6).
    calc::apply_pane_minsize

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
    # (xschem.tcl:15745), so File/Tools/View/Options/Constants/Help would be
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
#
# ⚠ TWO CONTROLS NO LONGER ROUTE STRAIGHT HERE, both by ruling and both still
# speaking: `Eval` goes through `calc::eval_click`, which refuses in U7's words
# when there is no result and falls through to this proc when there is one; and
# `Browse` goes through `calc::browse_inert`, which is not "not implemented" at
# all but permanently inert (U9).  "Not implemented (phase N)" is a promise, and
# it may only be made where a phase really is coming.
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
#
# ⚠ `record` — added by item 4, ruled by the crew and written into spec R507.
# It defaults to 1, so every existing caller and every existing check keeps the
# contract it had.  The one caller that passes 0 is R413's HOVER HELP, and the
# reason is R509's cap: help text is a LEGEND, not an event.  Dragging the
# pointer across the function list crosses fifty entries in a second, and with
# each one recorded the 50-entry history — the place a user goes to re-read what
# the tool just told them — would hold nothing but tooltips for functions they
# did not click.  The message field still shows it; the history does not keep
# it.  Everything that actually HAPPENS still records, which is what R506 asks.
proc calc::status {{msg {}} {record 1}} {
    variable statusmsg
    variable statushist
    variable histmax
    if {[info commands winfo] eq {}} { return {} }
    if {![winfo exists .calc.status.msg]} { return {} }
    set statusmsg $msg
    if {$msg eq {}} { return {} }
    if {!$record} { return $msg }
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
    # BROWSE STAYS DISABLED, AND IT IS NOT "NOT IMPLEMENTED" -- IT IS RULED
    # INERT.  U9 (spec section 17 decision 9, ruled by the user 2026-08-18) and
    # doc/claude/specs/results_selection.md R502: browsing TO a result is
    # `ASE-L > Results > Select...`'s job, and the Calculator CONSUMES the
    # session's selection -- it does not MAKE one.  R502's original text had
    # this button becoming live; the ruling reversed it, and the spec now says
    # why it is inert rather than promising it will not be.
    #
    # The stub keeps the shape phase 1a shipped -- a control that is missing
    # "because it comes later" is not allowed, a control that is inert is -- and
    # gains the REASON, here and in `calc::browse_inert`'s sentence, so that the
    # next reader does not "finish" it.  The path entry stays `-state readonly`
    # for the same ruling: there is nothing in this window that edits it.
    button .calc.res.browse -text {...} -width 2 -takefocus 0 -padx 1 -pady 0 \
        -state disabled -command calc::browse_inert \
        -background [calc::color panel] -activebackground [calc::color header] \
        -foreground [calc::color fieldfg] -activeforeground [calc::color fieldfg] \
        -disabledforeground [calc::color disabledfg]

    pack .calc.res.tog    -side left  -padx {2 4} -pady 2
    pack .calc.res.lab    -side left  -padx {0 4} -pady 2
    pack .calc.res.browse -side right -padx {4 2} -pady 2
    pack .calc.res.path   -side left  -fill x -expand 1 -padx {0 2} -pady 2

    calc::results_refresh
}

# ---------------------------------------------------------------------------
# W05 ANSWERS ABOUT THE ASE-L SESSION'S RESULT, AND THE ROW *PICKS*.
#
# RESULTS BATCH ITEM 10 (2026-08-20).  Four user rulings land in this block,
# taken 2026-08-18 one question at a time; they are decisions 3, 6, 7 and 9 of
# doc/claude/specs/results_selection.md section 17, carried as U3, U6, U7 and U9
# in doc/claude/results_batch/DECISIONS.md.  None is re-openable here.
#
#   U6  THE `self` ARM IS GONE ENTIRELY -- not demoted, removed.  The Calculator
#       reads the ASE-L session's result and NOTHING else, and must never
#       evaluate against a raw that a legacy path (the Waves menu, a graph
#       rect's `autoload=`, `raw_read_from_attr`) dropped into a SCHEMATIC
#       window's context.  `calc::results_path` -- the `xschem raw rawfile` read
#       of THIS context -- went with it.
#   U3  THE ROW PICKS.  It stops being a reporter: what the row NAMES is what
#       Evaluate READS.  That is a property of the code and not a promise,
#       because there is ONE resolver (`calc::results_source`) and Evaluate goes
#       through `calc::require_result`, which resolves ONCE, publishes the row
#       from that same measurement and only then decides.  The row cannot name
#       one database while the computation uses another -- which is exactly the
#       contradiction R503 recorded, now closed in favour of the selector.
#   U7  EVALUATE WITH NO RESULT REFUSES AND NAMES THE NEXT ACTION, in
#       `calc::no_result_msg`'s words.  The Calculator does NOT offer to launch
#       ASE-L itself.
#   U9  `Browse` STAYS DISABLED (see build_res above and `calc::browse_inert`).
#
# and U8, which is a property of this block rather than a line in it: A
# CALCULATOR READ DOES NOT DRAG THE WAVEFORM VIEWER WITH IT.  Every cross-window
# read here is a LOAN that is given back, and nothing in this file calls
# `results::select` -- so each window keeps its own choice and comparing two runs
# stays possible.
#
# THE ORIGINAL REPORT, and why the row reaches across windows at all (item 13,
# 2026-08-15): the Calculator was opened from the schematic editor while an
# ASE-L session had a state loaded and waveforms on screen, and the row said
# `(no raw file loaded)`.  That was TRUE of `xschem raw rawfile` in the editor's
# context and useless -- there WAS a result and the user was looking at it.  The
# fix stands.  What item 10 changes is WHICH answers are allowed to count:
#
#   ase      the borrowed context belongs to a live ASE-L session.  The viewer
#            token IS the session key -- ase_window.tcl calls
#            `wviewer::attach_raw $key ...` (:2334, :4972), and R407a
#            (results_selection.md section 6.1) states the rule: an ASE
#            session's results live in ITS waveform viewer's context.
#   viewer   a waveform viewer window that is not an ASE-L session's.  It is a
#            results holder in its own right -- its Location bar selects through
#            `results::select` (R501, item 5) -- so it is not the legacy door U6
#            closes.
#   refused  the loan came back REFUSED (F6).  REPORTED AS REFUSED, never as
#            "no results" -- `calc::busy_msg`, and see the warning on it.
#   none     nothing anywhere.
#
# ⚠ THE ANSWER IS `results::current` (R305), NOT `xschem raw rawfile`.  The two
# differ exactly where it matters.  `raw rawfile` names the current database
# whether or not it is a RESULT -- a VCD or a table slot can be the current one,
# because `ase::attach_dbs` reads the analog raw and THEN the VCDs (landmine L8)
# -- and whether or not its `schname`/`level` stamp still resolves against the
# current hierarchy stack (F4: a loaded-but-blind database, in which every name
# lookup answers -1).  `results::current` answers R103's three parts and returns
# {} for both.  Naming either of them in a row that PICKS is precisely how the
# Calculator ends up evaluating against a database no signal name resolves in.
#
# ⚠ AND `ase::last_rawfile` IS NOT AN ANSWER EITHER -- CREW RULING R502a
# (results_selection.md section 7.1a), which is why there is no `calc::ase_raw`
# any more.  It derives `<rundir>/<cell>.raw` and gates it on the file existing:
# a FILE ON DISK, not a selection.  Under U3 the row must name what Evaluate
# reads, and Evaluate cannot read a file nothing has loaded -- offering it would
# re-open R503's contradiction one arm to the left.  The honest answer there is
# "no result is loaded", and U7's sentence is what makes that actionable: it
# names the gesture that turns that file into a selection.  The item-13 report
# is unaffected: a session with waveforms on screen HAS a viewer context and is
# answered by the `ase` arm above.
#
# ⚠ R705 (doc/claude/specs/calculator.md) STILL BINDS, and results_selection.md
# R603 says why this is not a loophole: nothing here is persisted or cached.
# Every call is a live query through `results::current` -- "the Calculator reads
# the session's selection live rather than remembering it" is exactly that
# sentence.  The callers are the moments the answer can have changed:
# `calc::build_res`, at the end of building the row, which is the only one that
# runs on a FIRST open and is therefore the one that delivered item 13's fix (do
# not delete it as an unlisted extra -- `calc::open`'s raise arm does not run
# when there is nothing to raise); `calc::open`'s raise arm, for a later open
# onto a world that has moved; the row's own expand, whose whole meaning is
# "show me that path again"; and now Evaluate (U3).
#
# ⚠ THE READ TAKES A LOAN AND GIVES IT BACK (issue 0173).  Switching into a
# viewer runs save_ctx/restore_ctx and ends in set_modify(-1), which rewrites the
# target window's title; `wviewer::enter_ctx`/`leave_ctx` is the bracket that
# repairs it, and `1` = borrow is issue 0314's arm for the case that matters
# here -- EVERY menu-driven open holds `callback()`'s semaphore, and an
# unborrowed switch is refused 100% of the time from there while the identical
# call from the CIW works.  This body reads only, runs no update/after, and
# always restores, which is the door that arm was opened for.
proc calc::viewer_tokens {} {
    if {![info exists ::wviewer::windows]} { return {} }
    set out {}
    catch {
        set cur [wviewer::current_token]
        if {$cur ne {}} { lappend out $cur }
    }
    set all {}
    catch {set all [dict keys $::wviewer::windows]}
    foreach t $all {
        if {[lsearch -exact $out $t] < 0} { lappend out $t }
    }
    return $out
}

# The SELECTED RESULT of whatever context is CURRENT, as {path type idx}, or {}.
#
# ⚠ CALLED ONLY FROM INSIDE A LOAN.  It reads the current context, so calling it
# from the Calculator's own context is the `self` arm U6 removed.  The one call
# site is `calc::session_result`, between `enter_ctx` and `leave_ctx`.
#
# ⚠⚠ THE TYPE AND THE INDEX TRAVEL WITH THE PATH -- A RESULT IS NOT A PATH
# (FIXER ROUND, item 10, 2026-08-20).  The first draft returned {path type} and
# then dropped the type one proc later, so `calc::require_result` identified the
# database it had chosen BY PATH ALONE.  That is exactly what R407c clause (1)
# rules out and what U11 explains: one `multi.raw` read as `dc` and as `tran` is
# TWO registry slots, one file, one run -- and a by-path lookup selects the
# WRONG ANALYSIS OF THE RIGHT FILE (pinned SEL372 on that very fixture).  L6 and
# L10 say the same thing from the engine's side: a slot is reachable by name
# only with its `sim_type`, and `xschem raw switch <path>` with no type finds
# nothing.  So the slot's own `type` -- and its `idx`, which `results::current`
# already returns and which reaches the slot even when the type is `<NULL>` --
# are carried all the way to the dict phase 3 will read.  The ROW still names
# the path (W05 is a path entry, spec section 4); the GATE names the slot.
proc calc::ctx_result {} {
    set c {}
    if {[catch {results::current} c]} { return {} }
    if {$c eq {}} { return {} }
    set p {} ; set t {} ; set i {}
    catch {set p [dict get $c path]}
    catch {set t [dict get $c type]}
    catch {set i [dict get $c idx]}
    if {[string trim $p] eq {}} { return {} }
    return [list $p $t $i]
}

# Which provenance a viewer token carries.  The token IS the ASE-L session key
# for every viewer ASE opened (`wviewer::attach_raw $key ...`), so this is a
# lookup and not a guess; a viewer with no session behind it is `viewer`.
proc calc::token_origin {tok} {
    set has 0
    catch {set has [dict exists $::ase::sessions $tok]}
    return [expr {$has ? {ase} : {viewer}}]
}

# {origin path detail type idx}, origin `ase` | `viewer` | `refused` | `none`.
# Never throws.  The active viewer is asked first (`calc::viewer_tokens`), then
# the registry order.
#
# ⚠ FIVE ELEMENTS SINCE THE FIXER ROUND, not three: `type` and `idx` name the
# SLOT (see `calc::ctx_result`).  They are empty for every arm that has no
# result to name, which is every arm but the first two.
#
# ⚠ A REFUSED LOAN IS SKIPPED **AND REMEMBERED**.  Skipping is right -- another
# viewer may hold the session's result and a refusal says nothing about that one
# (issues 0313/0314).  But if the walk ends with no answer and a loan was
# refused, "there is no result" is NOT what was measured, and F6's whole defect
# is a refusal that reads like an answer.  So the refusal becomes the origin and
# `calc::busy_msg` is what the user is told (spec section 12, T-J).
proc calc::session_result {} {
    set refused {}
    foreach tok [calc::viewer_tokens] {
        set ticket {}
        if {[catch {wviewer::enter_ctx $tok 1} ticket]} { lappend refused $tok ; continue }
        if {![lindex $ticket 0]} { lappend refused $tok ; continue }
        set r {}
        catch {set r [calc::ctx_result]}
        catch {wviewer::leave_ctx $tok $ticket}
        if {[llength $r] == 3} {
            return [list [calc::token_origin $tok] [lindex $r 0] $tok \
                        [lindex $r 1] [lindex $r 2]]
        }
    }
    if {[llength $refused]} { return [list refused {} [lindex $refused 0] {} {}] }
    return [list none {} {} {} {}]
}

# {origin path detail type idx}: origin is ase|viewer|refused|none.
#
# ⚠ THE ONE ENTRY POINT, and that is the whole of U3's mechanism.  The row, the
# label, the tooltip and Evaluate all read THIS proc and nothing else, so "what
# the row names is what Evaluate reads" cannot drift into a promise: there is no
# second resolver for it to drift away from.
proc calc::results_source {} {
    set r {}
    if {[catch {calc::session_result} r]} { set r {} }
    if {[llength $r] == 5} { return $r }
    return [list none {} {} {} {}]
}

# U7's sentence, VERBATIM as ruled (spec section 17 decision 7).  Naming the
# command beats a neutral refusal, and as of results batch item 7 that menu
# entry really exists (`src/ase_window.tcl`, the ASE-L Results cascade), so the
# sentence is not a promise.  THE CALCULATOR DOES NOT OFFER TO LAUNCH ASE-L
# ITSELF: a refusal that opens a window is a second gesture the user did not
# ask for.
#
# The menu-path separator the ruling is written with is U+25B8; it is written
# as `\u25b8` rather than typed so the exactness of the sentence does not depend
# on this file's encoding surviving an editor.
proc calc::no_result_msg {} {
    return "No simulation results are loaded. Run a simulation, or pick an\
 existing one with ASE-L \u25b8 Results \u25b8 Select."
}

# F6 / T-J: A REFUSED BORROW IS REPORTED AS REFUSED.
#
# ⚠⚠ THIS SENTENCE AND `calc::no_result_msg` MUST NOT COLLAPSE INTO ONE.  "No
# results are loaded" is a legitimate answer the Calculator gives, which is
# exactly why a refused context switch may never borrow its words: the user
# would be told a fact about their simulations when what happened was that a
# window was busy for a moment.  Same shape as the dialog's own refusal
# (`ase::ui::rsel_borrow`, src/ase_window.tcl) -- it names the mechanism and
# then denies the wrong reading in so many words.
proc calc::busy_msg {} {
    return "Could not read the ASE-L session's result: the waveform viewer's\
 context is busy \u2014 that is a refused context switch, not an empty result\
 list."
}

# ---------------------------------------------------------------------------
# CREW RULING R503f, FIXER ROUND (item 10, 2026-08-20) -- U7'S SENTENCE MAY NOT
# BE SAID TO A USER WHO HAS ALREADY DONE WHAT IT ASKS.
#
# THE COLLISION, and it is between two items of this same batch.  R407a
# (`doc/claude/specs/results_selection.md` section 6.1, item 7) gives the
# `Results > Select...` dialog THREE arms: it borrows the session's waveform
# viewer when the session has one, it reads **the current context** when it has
# not (the `here` arm), and it reports a refusal as a refusal.  The `here` arm
# was ruled in deliberately -- *"evaluate against last night's raw happens
# BEFORE a run, which is exactly when no viewer exists"*.  So an ASE-L session
# with no waveform viewer can hold a perfectly good selection that lives in the
# HOST WINDOW'S context -- and U6 says the Calculator does not read that
# context.  Result, measured by a reviewer with no repo edit at all: the row
# said `(no raw file loaded)` and Evaluate told the user to *"pick an existing
# one with ASE-L > Results > Select"* -- the gesture they had just performed
# successfully.
#
# WHAT IS **NOT** DONE HERE, and why.  U6 is a USER ruling and reads *"removed
# entirely, not demoted"*; an arm that reads this window's own context, however
# late in the order and however tightly conditioned, is the demotion it forbids.
# A fixer may not take that decision, and the reviewer who found this said the
# same ("DO NOT quietly restore the `self` arm ... that needs the user's word").
# The gap is therefore FILED, not closed: issue **0516**, with the reviewer's
# reproducer, for the driver and the user to rule.
#
# WHAT **IS** DONE, which is the part that needs no ruling: the Calculator stops
# giving useless advice in that state.  The test is STRUCTURAL and reads no
# database at all -- is there a live ASE-L session that has no waveform viewer
# window?  That is exactly R407a's `here` precondition, asked with
# `wviewer::window_for`, and it answers with a BOOLEAN, never with a path.  It
# is not the `self` arm by any reading: it supplies nothing to Evaluate, it
# opens no context, and Evaluate still refuses.  It only refuses ACCURATELY.
proc calc::sessions_without_viewer {} {
    set out {}
    set keys {}
    catch {set keys [dict keys $::ase::sessions]}
    foreach k $keys {
        set wv {}
        catch {set wv [wviewer::window_for $k]}
        if {$wv eq {}} { lappend out $k }
    }
    return $out
}

# R503f's sentence.  It keeps U7's shape -- state the fact, then name the next
# action -- and differs from `calc::no_result_msg` in the one way that matters:
# it names the OBSTACLE (the session has no viewer, so its selection is not
# somewhere the Calculator reads) instead of asking for a gesture that cannot
# help.  The door it names is a TWO-step one on purpose, and both steps are
# real: with a viewer open, `ase::ui::rsel_borrow` takes its `viewer` arm, and
# `rsel_commit` then passes `token $key` and selects INSIDE that borrowed
# context -- which is precisely where `calc::session_result` looks.
proc calc::no_viewer_msg {} {
    return "The ASE-L session has no waveform viewer, and the Calculator reads\
 the session's viewer \u2014 a result selected while the session has no viewer\
 is not visible here. Run a simulation, or open the session's waveforms and\
 then pick a result with ASE-L \u25b8 Results \u25b8 Select."
}

# WHICH of the two "nothing to evaluate against" sentences this world deserves.
#
# ⚠ `calc::no_result_msg` STAYS UNCONDITIONAL, and this proc is why.  U7 ruled
# that string; making it state-dependent would make the ruled sentence a
# variable, and the check that asserts it by text would be asserting a branch.
# The choice lives HERE, one level up, where both callers -- the row's tooltip
# and `calc::require_result` -- reach it, so the row and Evaluate can never give
# different advice about the same world.
proc calc::no_result_advice {} {
    if {[llength [calc::sessions_without_viewer]]} { return [calc::no_viewer_msg] }
    return [calc::no_result_msg]
}

# W04's text carries the provenance, and it is W04 that carries it rather than a
# new widget or a decorated path for two reasons.  (1) The path stays a PATH:
# `.calc.res.path` is a readonly entry precisely so it can be selected and
# copied, and `sim.raw  (waveform viewer)` is not a filename.  (2) The row's
# widget set is normative (spec section 4, W03-W05) and its slave order is
# asserted; a fourth widget would change both for a string that has a natural
# home.  The empty provenance for `none` keeps the label EXACTLY as phase 1a
# shipped it in the case the user already approved.
proc calc::results_label {origin} {
    switch -exact -- $origin {
        viewer  {return {Results Dir (waveform viewer):}}
        ase     {return {Results Dir (ASE-L session):}}
        refused {return {Results Dir (unavailable):}}
        default {return {Results Dir:}}
    }
}

# The long form, for the tooltip: the same fact with the detail that does not
# fit a label (which viewer token / which session key).
proc calc::results_tip {origin path detail} {
    switch -exact -- $origin {
        ase     {return "The result selected in the ASE-L\
                         session[expr {$detail eq {} ? {} : " ($detail)"}].\n$path"}
        viewer  {return "The result selected in the waveform\
                         viewer[expr {$detail eq {} ? {} : " ($detail)"}].\n$path"}
        refused {return [calc::busy_msg]}
        default {return [calc::no_result_advice]}
    }
}

# W05's text.  With nothing loaded the entry says so in words: an empty readonly
# entry and a broken one look identical, and this row is the first thing a user
# reads when an expression fails to resolve.  The wording is the browser's own
# (wave_viewer.tcl's browser status), and it is KEPT unchanged by item 10 --
# what the row MEANS changed (U3), what it says when there is nothing to name
# did not, and it is a string the user has already approved.
#
# ⚠ `refused` GETS ITS OWN STRING.  It is not "no raw file loaded": nothing was
# measured about the raws at all (T-J again).
#
# ⚠ THIS PROC WRITES NO STATUS LINE, deliberately.  R508 makes the message
# history a property of the window and S16 pins "a fresh window starts silent";
# a refresh runs at BUILD time, so a line here would make every Calculator open
# with a message it did not earn.  The provenance is on the label and in the
# tooltip, where it is readable for as long as it is true rather than until the
# next message displaces it.  Evaluate is the one caller that DOES speak, and it
# speaks in `calc::eval_click`, after this has published the row.
proc calc::results_publish {src} {
    variable respath
    set origin none ; set p {} ; set detail {}
    foreach {origin p detail} $src break
    if {$origin eq {refused}} {
        set respath {(results unavailable: the session's context is busy)}
    } elseif {$p eq {}} {
        set respath {(no raw file loaded)}
    } else {
        set respath $p
    }
    if {[winfo exists .calc.res.lab]} {
        .calc.res.lab configure -text [calc::results_label $origin]
    }
    # `balloon` re-binds <Enter>/<Leave> on every call (xschem.tcl's balloon), so
    # re-attaching is how a baked-in string is UPDATED — the same property that
    # makes it useless for the 56 function entries makes it right here, where
    # there is one string and it changes rarely.
    if {[winfo exists .calc.res.path]} {
        catch {balloon .calc.res.path [calc::results_tip $origin $p $detail]}
    }
    return $respath
}

# Resolve, then publish.  Split from `results_publish` so that Evaluate can
# publish the SAME measurement it decides on (U3) instead of resolving twice --
# two resolutions are two loans and two answers, and the row would be naming the
# earlier one.
proc calc::results_refresh {} {
    return [calc::results_publish [calc::results_source]]
}

# ---------------------------------------------------------------------------
# THE GATE EVALUATE ASKS (U3, U7, T-I).  Resolves ONCE, publishes the row from
# that measurement, and then answers
# `{ok 0|1 origin .. path .. type .. idx .. msg ..}`.  Never throws.
#
# ⚠ THE ANSWER NAMES A SLOT, NOT A FILE (fixer round).  `type` and `idx` are
# carried the whole way from `results::current` (see `calc::ctx_result`) because
# one file read as two analyses is TWO slots and one result (U11), and phase 3
# handed only a path could not tell them apart -- it would reach the engine
# through a by-path lookup and get the wrong analysis of the right file (R407c
# clause 1, landmines L6/L10).  Both are `{}` on every refusing arm, because
# there is no slot to name.
#
# ⚠ SCOPE, and it is a fence rather than an omission: this settles WHICH
# DATABASE Evaluate reads and what it says when there is none.  The computation
# is calculator_batch phase 3 (doc/claude/specs/calculator.md R603-R607) and is
# deliberately NOT built here -- item 10 is the gate that phase was waiting on.
proc calc::require_result {} {
    set src [calc::results_source]
    catch {calc::results_publish $src}
    set origin none ; set p {} ; set detail {} ; set type {} ; set idx {}
    foreach {origin p detail type idx} $src break
    if {$origin eq {refused}} {
        return [dict create ok 0 origin refused path {} type {} idx {} \
                    msg [calc::busy_msg]]
    }
    if {$p eq {}} {
        # R503f: which "nothing to evaluate against" sentence this world earns.
        return [dict create ok 0 origin none path {} type {} idx {} \
                    msg [calc::no_result_advice]]
    }
    return [dict create ok 1 origin $origin path $p type $type idx $idx msg {}]
}

# W12's press.  The refusal is U7's and it comes BEFORE the phase-3 stub,
# because "which database" is settled by this item and "what to compute" is not.
proc calc::eval_click {} {
    set g [calc::require_result]
    if {![dict get $g ok]} { return [calc::status [dict get $g msg]] }
    return [calc::inert {Eval} 3]
}

# The Browse stub's sentence (U9 / results_selection.md R502).  The button is
# `-state disabled`, so Tk runs this from no click -- it is here so the REASON
# lives in the code, in one sentence, where the next reader of the stub finds
# it, and so a check can read it.  NEVER "not implemented": that word promises a
# later phase, and there is no later phase for this control.
proc calc::browse_inert {} {
    return [calc::status "Browse is deliberately inert: the Calculator consumes\
 the session's result and does not make one. Pick one with ASE-L \u25b8 Results\
 \u25b8 Select."]
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
        # THE "ON DEMAND" HALF OF W05's live query (item 13).  Re-opening the
        # row is the one gesture whose whole meaning is "show me that path
        # again", and R705 forbids the alternative (remembering it), so the
        # answer is re-resolved here rather than replayed.  The other two
        # callers are calc::build_res (first open) and calc::open's raise arm
        # (every later open).  Cheap, and it cannot recurse: results_refresh
        # writes a variable, a label and a binding, and packs nothing.
        catch {calc::results_refresh}
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
# tree (`option add *selectColor {white}`, xschem.tcl:15738).

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
                    # (xschem.tcl:12729) is the tree's ONE tooltip mechanism —
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

    # ⚠ W12 (Eval) IS NOT PLAIN INERT ANY MORE.  Results batch item 10 settles
    # WHICH DATABASE Evaluate reads -- the session's selection, through
    # `calc::require_result` -- and U7's refusal for when there is none.  The
    # computation is still calculator_batch phase 3's and is NOT built here, so
    # a press WITH a result still lands on the phase-3 stub; what changed is
    # that a press with NO result now says the one useful thing instead.
    foreach {id label phase} {plot Plot 3 eval Eval 3} {
        if {$id eq {eval}} {
            set cmd calc::eval_click
        } else {
            set cmd [list calc::inert $label $phase]
        }
        button .calc.mode.$id -text $label -takefocus 0 -padx 4 -pady 0 \
            -background [calc::color panel] \
            -activebackground [calc::color header] \
            -foreground [calc::color fieldfg] \
            -activeforeground [calc::color fieldfg] \
            -disabledforeground [calc::color disabledfg] \
            -command $cmd
        pack .calc.mode.$id -side left -padx {0 3} -pady 1
    }

    # W13.  The house combobox (recon/widgets.md §1): ttk, readonly, -values at
    # creation, `$w set` for the initial value, and combo_letter_cycle bound
    # because a readonly ttk::combobox does not type-to-cycle by itself
    # (xschem.tcl:10946).  The three values are the ones R601 hands to
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

# ---------------------------------------------------------------------------
# THE CATALOGUE (spec §3.2 + §7.1 + §7.2, and R413's "one table, not two")
#
# ONE table.  It is the single source for the function browser's list contents,
# for which entries are greyed out, and for the one-line hover help — R413 says
# so, and the reason is that the alternative has been built before: a second
# table drifts from the first silently, and the symptom is help that describes a
# function the list no longer offers.
#
# A row is SIX fields, in this order:
#
#   name      what the browser shows, and (phase 5) what a click inserts
#   category  one of §7.1's, verbatim — see D1 below
#   route     P primitive · C composed here · T Tcl measurement · N needs a new
#             C opcode · X out of scope in v1  (§7.2's Route column)
#   returns   scalar | wave | bool | scalar/wave  — §7.2's Returns column
#   insert    the RPN the entry emits, or {} where the route does not know yet
#   help      one line, R413, short enough for the status entry
#
# ⚠ THE ROWS ARE NOT THE RECON'S ROWS VERBATIM.  They were authored by one agent
# and audited by another (doc/claude/calculator_batch/recon/catalogue_defects.md);
# the audit's findings are applied HERE, and each one is worth knowing before
# editing a row:
#
#   D1  the special rows carried the category `Special`, but §7.1 names the
#       combobox value `Special Functions`.  Fixed in the DATA, not by loosening
#       the match — a filter that trims or prefix-matches a category name is a
#       filter that will one day match two.  Had it shipped, the DEFAULT
#       category would have rendered an empty list.
#   D2  `lshift` was route C with the recipe §7.2 prescribes, "del() with a
#       negative arg".  That recipe cannot work and is not merely wrong: the DEL
#       arm (save.c:2585-2607) compares `fabs(...) <= tmp`, so a negative tmp
#       never matches, the search runs past `last`, and ravg_store() then writes
#       one element past a my_calloc(last + 1) — an OUT-OF-BOUNDS READ in
#       shipped C, reachable from any node= expression.  The row is a T here and
#       emits nothing; the C question is item 12's.  (The row also emitted a
#       bare `del()`, i.e. a RIGHT shift — the opposite of its own help.)
#   D3  the schema had no returns column, so `integ` (scalar, the area) and
#       `iinteg` (wave, the running integral) were byte-identical rows.  The
#       `returns` field above is that column, populated from §7.2.
#   D4  §3.2's gloss "max() (clip above arg) min() (clip below arg)" is
#       INVERTED — MAX returns the greater operand (save.c:2629), i.e. it clips
#       from BELOW at a floor.  The rows are right; spec §3.2 is corrected.
#   D5  cph() unwraps by 360 (`ph - 360*floor((ph - prev)/360 + 0.5)`,
#       save.c:2805), which is the same fact as §3.2's "no ±180 jumps" seen from
#       the other side; both wordings are now in §3.2.
#   D6  `groupDelay`'s §7.2 recipe `cph() deriv()` negated returns DEGREES PER
#       HERTZ, which is not a group delay: -dφ/dω with φ in radians and ω=2πf is
#       -(dφ_deg/df)/360.  The row therefore emits `cph() deriv() -360 /`, and
#       §7.2 records the correction.  Shipping the spec's string verbatim would
#       have been off by π/90 with nothing to notice it.
#   D7  `/`'s help claimed a zero divisor "silently reuses the last result".
#       The C (save.c:2577) returns 0 when BOTH operands are zero and otherwise
#       y[p-1] — the previous point of the DESTINATION column, which at p==first
#       is whatever the last evaluation left there (landmine L2).
#
# RULING-3 (the driver's, LEDGER.md; already in spec §12.2): NO N-ROUTE
# FUNCTION SHIPS IN v1.  Every N row, and every X row, is RENDERED IN THE LIST
# AND DISABLED — greyed and unclickable, exactly the treatment §1.2 gives the RF
# selectors.  Their absence would be a lie about what the tool is; their
# presence, greyed, is information.
#
# ⚠ The five T-route verbs that STAND ON dft — spectrum, spectralPower,
# harmonic, harmonicFreq, thd — carry route `N` in this table, and that is a
# deliberate reading of §7.2 rather than a copying error.  §7.2 marks them
# "T (on dft)"; with dft absent there is no T to write, so the route the
# CALCULATOR would have to build is the N one.  Encoding it in the route field
# keeps the table the single source for the disabled state (RULING-3's
# requirement); the reason survives in each row's help text, which says which
# missing opcode it stands on.
proc calc::fn_fields {} { return {name category route returns insert help} }

# §7.1's combobox values, in order.  `All` is SYNTHETIC — no row carries it —
# and means every row of every category.
proc calc::fn_categories {} {
    return {{Special Functions} Arithmetic Trigonometric Exponential Complex
            Sequence Constants All}
}

# the routes that cannot be built in v1 and are therefore rendered disabled
proc calc::fn_dead_routes {} { return {N X} }

# ⚠ THE REASON IS BUDGETED FOR THE COMPOSED LINE, not for itself.  fn_click
# writes `function <name> is not available: <reason>`, and RULING-3's whole point
# is that a greyed entry carries INFORMATION — a sentence cut mid-word carries
# less than none.  Measured on the shipped 656x680 window: .calc.status.msg is
# 613 px wide in TkTextFont, and the old N text made
# `function spectralPower is not available: needs a new C opcode; no N-route
# function ships in v1` 94 characters / 666 px, of which 85 rendered — the line
# ended "...no N-route function sh".  The text below makes the same line 67
# characters / 474 px.  S24 asserts the COMPOSED string for every dead row, not
# the reason alone.
proc calc::fn_reason {route} {
    switch -exact -- $route {
        N       {return {needs a C opcode not in v1}}
        X       {return {out of scope in v1}}
        default {return {}}
    }
}

proc calc::catalogue {} {
    return {
{average {Special Functions} P scalar {avg()} {Mean value of the wave over the X range}}
{rms {Special Functions} C scalar {dup() * avg() sqrt()} {Root-mean-square value over the X range}}
{stddev {Special Functions} T scalar {} {Standard deviation of the wave over the X range}}
{integ {Special Functions} P scalar {integ()} {Area under the curve over the X range}}
{iinteg {Special Functions} P wave {integ()} {Running integral of the wave, read back as a wave}}
{deriv {Special Functions} P wave {deriv()} {Slope of the wave (derivative), as a wave}}
{clip {Special Functions} T wave {} {The wave restricted to a chosen X range}}
{flip {Special Functions} T wave {} {The wave mirrored along X}}
{lshift {Special Functions} T wave {} {The wave shifted along X by an offset (negative delay)}}
{sample {Special Functions} T wave {} {Wave values at chosen X points}}
{root {Special Functions} T scalar {} {The X value where the curve equals zero}}
{cross {Special Functions} T scalar {} {The X value at the Nth crossing of a threshold}}
{intersect {Special Functions} T scalar/wave {} {Where two curves meet: scalar or wave}}
{compare {Special Functions} T bool {} {Whether two curves agree within a tolerance}}
{dBm {Special Functions} C wave {log10() 10 * 30 +} {Power in dBm: 10*log10(power in watts) + 30}}
{peak {Special Functions} T wave {} {Locations and values of the wave's peaks}}
{histo {Special Functions} T wave {} {Histogram of the wave's values}}
{riseTime {Special Functions} T scalar {} {Time of a transition from a low % level to a high % level}}
{slewRate {Special Functions} T scalar {} {Rate of change dV/dt of a transition}}
{delay {Special Functions} T scalar {} {Time from an edge on one signal to an edge on another}}
{settlingTime {Special Functions} T scalar {} {Time taken to settle and stay inside a band}}
{overshoot {Special Functions} T scalar {} {Percent by which the wave passes its final value}}
{dutyCycle {Special Functions} T scalar {} {Fraction of a period the signal spends high}}
{frequency {Special Functions} T scalar/wave {} {Frequency measured from the wave's crossings}}
{freq {Special Functions} T scalar/wave {} {Frequency measured from the wave's crossings}}
{period_jitter {Special Functions} T scalar {} {Spread of the measured period}}
{freq_jitter {Special Functions} T scalar {} {Spread of the measured frequency}}
{eyeDiagram {Special Functions} T wave {} {The wave folded over one bit period, as an eye diagram}}
{bandwidth {Special Functions} T scalar {} {The X value where the response drops by N dB}}
{gainBwProd {Special Functions} T scalar {} {Gain multiplied by bandwidth}}
{gainMargin {Special Functions} T scalar {} {Gain stability margin of the loop}}
{phaseMargin {Special Functions} T scalar {} {Phase stability margin of the loop}}
{groupDelay {Special Functions} C wave {cph() deriv() -360 /} {Group delay in seconds: the phase slope, degrees per Hz, negated}}
{dft {Special Functions} N wave {} {Discrete Fourier transform: needs a new C opcode, not in v1}}
{psd {Special Functions} N wave {} {Power spectral density: needs a new C opcode, not in v1}}
{spectrum {Special Functions} N wave {} {Spectrum of the wave: stands on dft, which is not in v1}}
{spectralPower {Special Functions} N scalar {} {Power in the spectrum: stands on dft, which is not in v1}}
{harmonic {Special Functions} N scalar {} {The Nth harmonic: stands on dft, which is not in v1}}
{harmonicFreq {Special Functions} N scalar {} {Frequency of the Nth harmonic: stands on dft, not in v1}}
{fourEval {Special Functions} T wave {} {A Fourier series evaluated as a wave}}
{rmsNoise {Special Functions} C scalar {dup() * integ() sqrt()} {Noise integrated over a frequency band}}
{phaseNoise {Special Functions} T wave {} {Noise expressed as phase}}
{convolve {Special Functions} N wave {} {Convolution of two waves: needs a new C opcode, not in v1}}
{dnl {Special Functions} T wave {} {Differential nonlinearity of the wave}}
{compression {Special Functions} T scalar {} {The 1 dB compression point}}
{compressionVRI {Special Functions} T scalar {} {The 1 dB compression point, VRI variant}}
{ipn {Special Functions} T scalar {} {The intercept point}}
{ipnVRI {Special Functions} T scalar {} {The intercept point, VRI variant}}
{thd {Special Functions} N scalar {} {Total harmonic distortion: stands on dft, not in v1}}
{dftbb {Special Functions} X wave {} {Baseband (I/Q) Fourier transform - not available in v1}}
{psdbb {Special Functions} X wave {} {Baseband (I/Q) power spectral density - not in v1}}
{evmQAM {Special Functions} X scalar {} {Error vector magnitude for QAM - not available in v1}}
{evmQpsk {Special Functions} X scalar {} {Error vector magnitude for QPSK - not available in v1}}
{pzbode {Special Functions} X wave {} {Pole/zero Bode data - ngspice pz output not modelled}}
{pzfilter {Special Functions} X wave {} {Pole/zero filter data - ngspice pz output not modelled}}
{getAsciiWave {Special Functions} T wave {} {A curve loaded from a text file}}
{+ Arithmetic P wave + {Adds the top two stack values.}}
{- Arithmetic P wave - {Subtracts the top value from the one below: X Y - is X-Y.}}
{* Arithmetic P wave * {Multiplies the top two stack values.}}
{/ Arithmetic P wave / {X Y / is X/Y; a zero Y repeats the last output point, 0/0 is 0.}}
{** Arithmetic P wave ** {Raises to a power: X Y ** is X to the Y.}}
{== Arithmetic P wave == {Yields 1.0 if the two top values are equal, else 0.0.}}
{!= Arithmetic P wave != {Yields 1.0 if the two top values differ, else 0.0.}}
{> Arithmetic P wave > {Yields 1.0 if X is greater than Y, else 0.0.}}
{< Arithmetic P wave < {Yields 1.0 if X is less than Y, else 0.0.}}
{>= Arithmetic P wave >= {Yields 1.0 if X is greater than or equal to Y, else 0.0.}}
{<= Arithmetic P wave <= {Yields 1.0 if X is less than or equal to Y, else 0.0.}}
{? Arithmetic P wave ? {X cond Y ? gives X if cond is non-zero, else Y. Jumps hard.}}
{abs() Arithmetic P wave abs() {Absolute value of the top stack value.}}
{sgn() Arithmetic P wave sgn() {Sign of the top value: -1, 0 or +1.}}
{sqrt() Arithmetic P wave sqrt() {Square root of the top value.}}
{avg() Arithmetic P wave avg() {Cumulative mean from the window start to each point.}}
{ravg() Arithmetic P wave ravg() {Moving average of X over a window of width Y.}}
{max() Arithmetic P wave max() {Greater of X and Y: clips the wave up to a floor of Y.}}
{min() Arithmetic P wave min() {Lesser of X and Y: clips the wave down to a ceiling Y.}}
{integ() Arithmetic P wave integ() {Running trapezoid integral. Widens the window back 1 point.}}
{deriv() Arithmetic P wave deriv() {Slope vs the graph sweep var. Widens the window back 2.}}
{deriv0() Arithmetic P wave deriv0() {Slope vs the FIRST sweep var, whatever the graph sweep_idx is.}}
{deriv2() Arithmetic P wave deriv2() {3-point slope vs the graph sweep var. Widens window back 2.}}
{deriv20() Arithmetic P wave deriv20() {3-point slope vs the FIRST sweep var, ignoring sweep_idx.}}
{dup() Arithmetic P wave dup() {Duplicates the top stack value.}}
{exch() Arithmetic P wave exch() {Swaps the top two stack values.}}
{sin() Trigonometric P wave sin() {Sine of the top value, which is taken in radians.}}
{cos() Trigonometric P wave cos() {Cosine of the top value, which is taken in radians.}}
{tan() Trigonometric P wave tan() {Tangent of the top value, which is taken in radians.}}
{asin() Trigonometric P wave asin() {Arc sine of the top value; result in radians.}}
{acos() Trigonometric P wave acos() {Arc cosine of the top value; result in radians.}}
{atan() Trigonometric P wave atan() {Arc tangent of the top value; result in radians.}}
{sinh() Trigonometric P wave sinh() {Hyperbolic sine of the top value.}}
{cosh() Trigonometric P wave cosh() {Hyperbolic cosine of the top value.}}
{tanh() Trigonometric P wave tanh() {Hyperbolic tangent of the top value.}}
{asinh() Trigonometric P wave asinh() {Inverse hyperbolic sine of the top value.}}
{acosh() Trigonometric P wave acosh() {Inverse hyperbolic cosine; needs an input of 1 or more.}}
{atanh() Trigonometric P wave atanh() {Inverse hyperbolic tangent; blows up at inputs of +/-1.}}
{exp() Exponential P wave exp() {Raises e to the top stack value.}}
{ln() Exponential P wave ln() {Natural logarithm of the top value.}}
{log10() Exponential P wave log10() {Base-10 logarithm of the top value.}}
{db20() Exponential P wave db20() {Magnitude in dB: 20 times the base-10 log of the value.}}
{re() Complex P wave re() {Real part from magnitude X and phase Y given in degrees.}}
{im() Complex P wave im() {Imaginary part from magnitude X and phase Y in degrees.}}
{cph() Complex P wave cph() {Continuous phase: unwrapped, with no +/-360 degree jumps.}}
{prev() Sequence P wave prev() {Value at the previous point. Widens the window back 1 point.}}
{del() Sequence P wave del() {Delays X by Y in X-axis units. Widens window to dataset start.}}
{idx() Sequence P wave idx() {Index number of the current point in the raw file.}}
{pi() Constants P scalar pi() {Pushes pi, 3.14159265.}}
{k() Constants P scalar k() {Pushes the Boltzmann constant, 1.380649e-23 J/K.}}
{e() Constants P scalar e() {Pushes Euler's number e, 2.71828183.}}
{q() Constants P scalar q() {Pushes the electron charge, 1.602176634e-19 C.}}
    }
}

# A category's rows, ALPHABETICALLY.  The table's own order is §7.2's (grouped
# by kin: the timing verbs together, the RF ones together), which is the right
# order to READ the spec in and the wrong one to LOOK A NAME UP in — and looking
# a name up is the whole job of a 56-entry browser.  The reference tool sorts
# too (ref/viva_xl_calculator.png: aaSP, abs_jitter, analog2Digital, average, …
# down the first column).  `-dictionary` is case-insensitive, which is what puts
# `dBm` between `d2a` and `delay` there rather than in a capitals ghetto.
proc calc::fn_entries {cat} {
    set out {}
    foreach row [calc::catalogue] {
        if {$cat eq {All} || [lindex $row 1] eq $cat} { lappend out $row }
    }
    return [lsort -dictionary -index 0 $out]
}

proc calc::fn_row {name} {
    foreach row [calc::catalogue] {
        if {[lindex $row 0] eq $name} { return $row }
    }
    return {}
}

# ---------------------------------------------------------------------------
# W26-W28 — the function browser (spec §7.1, plan step 1.6)
#
# ⚠ .calc.fn.list IS A CANVAS, and the alternatives were rejected against this
# tree rather than skipped.  The requirements are the signal browser's exactly —
# many columns, a click that selects ONE cell, per-cell greying, per-cell hover
# help — and wave_viewer.tcl:9429-9436 records that enumeration in full:
# ttk::treeview has no cell selection in Tk 8.6 (and its tags are per ROW, so
# `dft` could not be greyed without greying the five names beside it);
# side-by-side listboxes each own their own selection and, worse here, each own
# their own xview, so the one horizontal scrollbar W28 requires could not scroll
# the grid; a text widget yields character-range selection.  A canvas gives
# per-item tags, per-item bindings, per-item colour, and `xview`/`scrollregion`
# for free.  The browser reached the same conclusion from the same constraints.
#
# The columns are laid out COLUMN-MAJOR (names run DOWN a column, then across),
# which is what the reference does and what makes an alphabetical list scannable.
proc calc::fn_cols {} { return 6 }

# gap between two columns, and between two rows, in pixels
proc calc::fn_pad {} { return 14 }

proc calc::fn_font {} { return TkDefaultFont }

proc calc::build_fn {} {
    frame .calc.fn -background [calc::color panel]

    # W27.  The house combobox (recon/widgets.md §1): ttk, readonly, -values at
    # creation, `$w set` for the initial value, combo_letter_cycle bound because
    # a readonly ttk::combobox does not type-to-cycle by itself.
    # ⚠ Calc.Field.TCombobox, NOT Calc.TCombobox: the latter carries the status
    # history's -postoffset, which drags a popdown 460 px to the left.
    ttk::combobox .calc.fn.cat -state readonly -width 17 \
        -values [calc::fn_categories] -takefocus 0 -style Calc.Field.TCombobox
    .calc.fn.cat set {Special Functions}
    bind .calc.fn.cat <Key> {combo_letter_cycle %W %A; break}
    bind .calc.fn.cat <<ComboboxSelected>> {calc::fn_cat_changed}

    canvas .calc.fn.list -takefocus 0 -relief sunken -borderwidth 1 \
        -highlightthickness 0 -width 120 -height 90 \
        -background [calc::color field] \
        -xscrollcommand {.calc.fn.hsb set} \
        -yscrollcommand {.calc.fn.vsb set}
    # W28 asks for the horizontal one; the vertical one is R112 ("if the layout
    # cannot honour that, the function browser is what SCROLLS, not what
    # disappears") — 56 names in 6 columns are ten rows deep and the pane is not
    # always ten rows tall.  Both wear the palette, for the reason the Stack's
    # scrollbar records.
    scrollbar .calc.fn.hsb -orient horiz -command {.calc.fn.list xview} \
        -takefocus 0 \
        -background [calc::color panel] -activebackground [calc::color header] \
        -troughcolor [calc::color header] \
        -highlightbackground [calc::color panel]
    scrollbar .calc.fn.vsb -command {.calc.fn.list yview} -takefocus 0 \
        -background [calc::color panel] -activebackground [calc::color header] \
        -troughcolor [calc::color header] \
        -highlightbackground [calc::color panel]

    grid .calc.fn.cat  -row 0 -column 0 -columnspan 2 -sticky w -pady {0 3}
    grid .calc.fn.list -row 1 -column 0 -sticky nsew
    grid .calc.fn.vsb  -row 1 -column 1 -sticky ns
    grid .calc.fn.hsb  -row 2 -column 0 -sticky ew
    grid rowconfigure    .calc.fn 1 -weight 1
    grid columnconfigure .calc.fn 0 -weight 1

    calc::fn_fill
}

# Repaint the list for the category the combobox is showing.  Every visible
# property of an entry — its text, whether it is greyed, what it says on hover,
# what it says on a click — comes from the ONE table (R413).
proc calc::fn_fill {} {
    if {![winfo exists .calc.fn.list] || ![winfo exists .calc.fn.cat]} { return 0 }
    set c .calc.fn.list
    $c delete all

    set rows [calc::fn_entries [.calc.fn.cat get]]
    set n [llength $rows]
    if {$n == 0} {
        $c configure -scrollregion {0 0 1 1}
        $c xview moveto 0
        $c yview moveto 0
        return 0
    }
    set fnt  [calc::fn_font]
    set pad  [calc::fn_pad]
    set lh   [expr {[font metrics $fnt -linespace] + 2}]
    set ncol [calc::fn_cols]
    set nrow [expr {($n + $ncol - 1) / $ncol}]

    # column widths are per column, not uniform: one 14-character name would
    # otherwise pad all six columns to its width and push half the list off the
    # right-hand edge.  The reference's columns are uneven for the same reason.
    set x $pad
    set dead [calc::fn_dead_routes]
    for {set col 0} {$col < $ncol} {incr col} {
        set w 0
        for {set r 0} {$r < $nrow} {incr r} {
            set i [expr {$col * $nrow + $r}]
            if {$i >= $n} break
            set tw [font measure $fnt [lindex [lindex $rows $i] 0]]
            if {$tw > $w} { set w $tw }
        }
        if {$w == 0} break
        for {set r 0} {$r < $nrow} {incr r} {
            set i [expr {$col * $nrow + $r}]
            if {$i >= $n} break
            foreach {name category route returns insert help} [lindex $rows $i] break
            set live [expr {[lsearch -exact $dead $route] < 0}]
            set fg [expr {$live ? [calc::color fieldfg] : [calc::color disabledfg]}]
            $c create text $x [expr {$pad / 2 + $r * $lh}] \
                -text $name -anchor nw -font $fnt -fill $fg \
                -tags [list fnentry fn$i]
            # per-ENTRY hover and click.  `balloon` cannot do this: it bakes its
            # string into an <Enter> binding at attach time (xschem.tcl:12729),
            # and there are 56 different strings on one widget — the same reason
            # the signal browser wrote its own cell tooltip.
            $c bind fn$i <Enter>    [list calc::fn_hover $name]
            $c bind fn$i <Leave>    [list calc::fn_unhover $name]
            $c bind fn$i <Button-1> [list calc::fn_click $name]
        }
        set x [expr {$x + $w + $pad}]
    }
    $c configure -scrollregion \
        [list 0 0 $x [expr {$pad + $nrow * $lh}]]
    # ⚠ THE VIEW GOES BACK TO THE TOP-LEFT, or a category switch renders the NEW
    # list mid-scroll.  Measured before this line: scroll `All` to its far corner
    # (which is exactly what dragging .calc.fn.hsb does — its -command IS
    # `.calc.fn.list xview`), switch to `Special Functions`, and 28 of the 56
    # entries were off-screen with the whole alphabetical head — `average`,
    # `bandwidth`, `clip`, `compare` — above the top edge.  A canvas keeps its
    # xview/yview across a `delete all`; only the scrollregion changed.
    $c xview moveto 0
    $c yview moveto 0
    return $n
}

proc calc::fn_cat_changed {} {
    if {![winfo exists .calc.fn.cat]} return
    set cat [.calc.fn.cat get]
    set n [calc::fn_fill]
    return [calc::status "functions: $cat ($n entries)"]
}

# R413: one line of help per entry, from the table, in the status area.
# ⚠ NOT RECORDED in the history (the second argument): see the note on
# calc::status.  Fifty tooltips would evict fifty real messages.
proc calc::fn_hover {name} {
    variable fnhelp
    set row [calc::fn_row $name]
    if {$row eq {}} { return {} }
    set fnhelp [lindex $row 5]
    return [calc::status $fnhelp 0]
}

# Retire the hover line — but ONLY if it is still the one THIS entry wrote.  A
# <Leave> that clears unconditionally would wipe whatever the click that
# happened in between had to say, which is R506's silence by another route.
#
# ⚠ THE GUARD IS PER ENTRY, which is what `$name` is for: the leaving entry's
# OWN help from the one table has to be what is on the status line, and it has
# to still be the line hover last wrote.  Guarding on `fnhelp` alone would let a
# <Leave> on entry B retire entry A's line — the canvas delivers <Leave> after
# the next item's <Enter> often enough for that to be a real sequence — and a
# `name` argument that the body never reads is a binding that carries a value
# nothing checks.
proc calc::fn_unhover {name} {
    variable fnhelp
    variable statusmsg
    set row [calc::fn_row $name]
    if {$row eq {}} { return {} }
    set mine [lindex $row 5]
    if {[info exists fnhelp] && $fnhelp eq $mine && $statusmsg eq $mine} {
        calc::status {}
    }
    return {}
}

# Clicking an entry.  Insertion is plan phase 5 (R410/R411), so this is inert
# and says so — except for the N/X rows, which will never be clickable at all
# and say THAT instead (RULING-3, and the same shape as R202's sel_refuse).
proc calc::fn_click {name} {
    set row [calc::fn_row $name]
    if {$row eq {}} { return {} }
    set why [calc::fn_reason [lindex $row 2]]
    if {$why ne {}} {
        return [calc::status "function $name is not available: $why"]
    }
    return [calc::inert "function $name" 5]
}

# ---------------------------------------------------------------------------
# W29-W31 — the keypad (spec §3.2, plan step 1.7)
#
# ⚠ THERE ARE NO NUMBER KEYS.  RULING-2 (LEDGER.md, user, 2026-08-15) amends
# both W30 and the reference screenshot's 4x4 digit pad: digits are TYPED into
# the buffer, and this pane holds the operators and the four user buttons.
#
# WHICH operators was left to the crew, and the set is the twelve OPERATOR
# tokens plot_raw_custom_data() lexes (save.c:2414-2425): `+ - * / **`, the six
# comparisons, and `?`.
#
# ⚠ ELEVEN of the twelve are BINARY; `?` IS NOT.  `?` is COND (`#define COND 49`
# at save.c:2361), dispatched at save.c:2531-2536 inside
# `if(stackptr2 > 2) { /* 3 argument operators */ }` as
# `stack2[p-3] = stack2[p-2] ? stack2[p-3] : stack2[p-1]; stackptr2 -= 2;` —
# THREE operands consumed.  R510's two-operand button rule therefore does not
# describe it, and PHASE 4 (ledger item 10) OWES `?` ITS OWN THREE-OPERAND RULE:
# a `?` button must consume the top THREE stack entries and push
# `<third> <second> <top> ?`.  Emitting `<second> <top> ?` leaves stackptr2 == 2
# at the token, the `stackptr2 > 2` guard is false, COND never fires and the
# expression silently yields an operand instead of a conditional.  The catalogue
# row for `?` states the same three-operand semantics; the two must not drift.
#
# The rationale, written into spec §4 W30:
#
#   - every one of the twelve is a token the engine really lexes.  A key that
#     emits a token the lexer does not know is not a shortcut, it is a trap:
#     §3.1 says an unknown token makes the WHOLE expression return -1, and the
#     failure surfaces phases later as "expression error".
#   - a key is not the same as typing the character, which is why keys survive
#     RULING-2 and digits do not.  R510/R511 give a binary-operator BUTTON stack
#     semantics — it consumes the top two stack entries and pushes
#     `<second> <top> <op>` as one entry — and there is no keystroke that does
#     that.  (For the eleven binary keys.  `?` is the ternary above and gets its
#     own rule in phase 4; that it is not covered by R510 is a reason to write
#     the rule, not a reason to drop the key.)  A digit has no such second
#     meaning, so a digit key would be a slower keyboard.
#   - `±` and `.` are DROPPED, and they are the two the brief left open.
#     Neither is in §3.2; both belong to typing a numeric literal, which is
#     exactly the job RULING-2 hands to the keyboard.  `.` alone is not even
#     lexable: strtod(".") fails, so §3.1 looks it up as a VECTOR NAME and the
#     expression returns -1.  A negative literal is typed `-3` and strtod eats
#     it; a negated expression is `-1 *`, which the pad's own `*` composes.
#   - the unary functions are NOT here.  They are the function browser's, one
#     entry each in the Arithmetic/Trigonometric/... categories, which is what
#     §7.1 means by "everything in §3.2 is exposed through the non-Special
#     categories".  Duplicating twenty of them on a keypad would be the second
#     table R413 forbids, in widget form.
#
# W30's path is normative: .calc.pad.k<n>, n from 1, in the order they are laid
# out (reading order, four to a row).
proc calc::pad_keys {} { return {+ - * / ** ? == != > < >= <=} }
proc calc::pad_cols {} { return 4 }

proc calc::build_pad {} {
    frame .calc.pad -background [calc::color panel]

    set n 1
    foreach tok [calc::pad_keys] {
        set row [expr {($n - 1) / [calc::pad_cols]}]
        set col [expr {($n - 1) % [calc::pad_cols]}]
        button .calc.pad.k$n -text $tok -width 2 -takefocus 0 -padx 2 -pady 0 \
            -background [calc::color panel] \
            -activebackground [calc::color header] \
            -foreground [calc::color fieldfg] \
            -activeforeground [calc::color fieldfg] \
            -disabledforeground [calc::color disabledfg] \
            -command [list calc::pad_click $tok]
        grid .calc.pad.k$n -row $row -column $col -sticky ew -padx 1 -pady 1
        incr n
    }
    # W31.  Four user buttons, 2x2 under the operators, spanning the same width.
    # Binding an expression to one is R703, plan phase 9.
    set base [expr {([llength [calc::pad_keys]] + [calc::pad_cols] - 1)
                    / [calc::pad_cols]}]
    for {set i 1} {$i <= 4} {incr i} {
        button .calc.pad.u$i -text "user $i" -width 6 -takefocus 0 -padx 2 -pady 0 \
            -background [calc::color panel] \
            -activebackground [calc::color header] \
            -foreground [calc::color fieldfg] \
            -activeforeground [calc::color fieldfg] \
            -disabledforeground [calc::color disabledfg] \
            -command [list calc::inert "user $i" 9]
        grid .calc.pad.u$i -row [expr {$base + ($i - 1) / 2}] \
            -column [expr {(($i - 1) % 2) * 2}] -columnspan 2 \
            -sticky ew -padx 1 -pady 1
    }
    for {set col 0} {$col < [calc::pad_cols]} {incr col} {
        grid columnconfigure .calc.pad $col -weight 1 -uniform padkey
    }
}

# An operator key.  Inserting at the caret is plan step 2.2 and the stack
# composition R510 asks of it is phase 4; this phase names the control and the
# phase that owns it, and touches nothing.
proc calc::pad_click {tok} {
    return [calc::inert "operator $tok" 2]
}

# ---------------------------------------------------------------------------
# MOUSE-WHEEL SCROLLING (item 13; the user's phase-1 eyeball pass)
#
# The report, verbatim: "should not require mouse pointer to be over the
# scrollbar to scroll. Must get vertical scroll with mouse scrollwheel if
# pointer is over the area that needs scrolling to make content visible".
#
# ⚠ THE HARD PART IS NOT THE BINDING, IT IS WHICH WIDGET GETS THE EVENT.  X
# delivers a wheel event to the window under the pointer and Tk then runs the
# bindings of THAT widget's bindtags — {widget, class, toplevel, all}.  It does
# NOT walk up the widget tree.  So the two obvious shapes are both wrong here:
#
#   bind .calc.fn.list ...   scrolls only while the pointer is over the canvas
#                            itself, not over its scrollbars or the frame.
#   bind .calc ...           reaches every descendant (the toplevel IS in every
#                            child's bindtags — that is why property_form.tcl's
#                            single-scroll-area dialog can do exactly this at
#                            :1462-1464) but has NO idea which of this window's
#                            three scrollable regions the pointer is in.
#
# THE HOUSE ANSWER IS `nhse_bind_wheel_tree` (xschem.tcl:1589), written from the
# same user feedback about the same defect — "the table scrolls on a wheel
# ANYWHERE over it, not only on the scrollbar" — and it is copied here rather
# than re-invented: WALK THE REGION'S WIDGET TREE AND BIND EACH WIDGET, skipping
# ttk comboboxes so an open dropdown keeps its own wheel.  The only thing added
# is that this window has THREE such regions instead of one, so the scroll
# target and its step are arguments rather than a hard-coded `.nhse.tbl.sf`.
# Each binding `break`s, exactly as nhse's does, so a widget whose CLASS already
# has a wheel binding cannot also fire it and double the scroll.
# calc::wheel_bind_all runs once, after everything is packed; a widget created
# after that must be bound by whoever creates it (nhse re-runs the walk after
# each rebuild for that reason).
#
# WHAT WAS ALREADY WORKING, and is now covered by one idiom instead of three
# accidents (measured on Tk 8.6.14, `bind <class> <Button-4>`):
#   Listbox   yview scroll -5 units      -> the Stack list already scrolled
#   Text      yview scroll -50 pixels    -> the buffer already scrolled
#   Scrollbar tk::ScrollByUnits          -> over a scrollbar it already worked
#   Canvas    NOTHING AT ALL             -> the function browser, the one region
#                                          that most needs it (56 entries, ten
#                                          rows deep, an eight-row pane), had no
#                                          wheel scroll anywhere except its
#                                          scrollbars.  That is the defect the
#                                          user hit.
# The steps below are those same class values, so no region's feel changes: 5
# units for a listbox and 50 pixels for a text.
#
# ⚠ THE CANVAS STEP IS 3 UNITS, NOT property_form.tcl's 1 — ruled by the crew
# 2026-08-15 (item 13 review), measured, and written into spec §4.1's R112a.
# The canvas leaves -yscrollincrement at 0, so one unit is one TENTH of the
# visible height, and 1 unit had two consequences neither of which anybody
# ruled on.  (1) The function browser would then be the slowest region in the
# window by a factor of four — 10% of a viewport per notch against the Stack
# listbox's 5 lines (~38%) and the buffer's 50 pixels (~50%) — in a dialog
# where the wheel is now meant to feel the same wherever the pointer is.
# (2) It made the ONE place the wheel already worked WORSE: this walk binds the
# scrollbars too (nhse's does, and a scrollbar is a visible slice of the
# region), and its binding `break`s, so it REPLACES Tk's Scrollbar class
# binding `tk::ScrollByUnits %W v 5`.  Measured on :99 with 56 entries:
#   over .calc.fn.vsb, one notch, Tk's class binding   -> yview 0.2205882…
#   over .calc.fn.vsb, one notch, ours at 1 unit       -> yview 0.0735294…
#   over .calc.fn.vsb, one notch, ours at 3 units      -> yview 0.2205882…
# 3 units is therefore not a taste: it is the number that leaves the scrollbar
# exactly as fast as it was before this item, to the last digit, while giving
# the canvas body the same gesture.  Do not "restore the house 1 unit" without
# also excluding Scrollbar-class widgets from the walk — and that is the wrong
# trade, because it puts a wheel-dead strip back under the horizontal
# scrollbar (Tk's Scrollbar binding is `v`-only, so a plain wheel over an
# `h` scrollbar does nothing at all).
#
# DIRECTION is the house convention and Tk's: Button-4 (wheel up) scrolls
# toward the START of the content (-1), Button-5 toward the end; <MouseWheel>'s
# signed %D is mapped the same way (%D > 0 -> -1), exactly as
# property_form.tcl:1464 and wave_viewer.tcl:16593 do it.  SHIFT is the house
# horizontal modifier (wave_viewer.tcl:16586, and Tk's own Shift-Button-4 on
# Listbox/Text), which W28's horizontally scrolling function list needs.
# X11 delivers buttons 4/5; Windows/macOS deliver <MouseWheel>.  Both are bound,
# as the viewer binds both.
#
# ⚠ ttk COMBOBOXES ARE EXCLUDED FROM THE WALK — nhse_bind_wheel_tree's own
# exclusion, for its own reason: TCombobox has a wheel meaning of its own
# (`ttk::combobox::Scroll`, which steps the VALUE), so binding `.calc.fn.cat`
# would silently take away the standard gesture for choosing a category, and the
# walk must not descend into one either — a combobox's popdown is a CHILD widget
# (`$cb.popdown`), so recursing would make the wheel scroll the function list
# while the user is scrolling the open dropdown.  The status history dropdown
# (W34) needs nothing from us for the same reason its popdown works today: that
# popdown holds a real Listbox, and Tk's Listbox class bindings scroll it.
#
# ⚠ THE PANE HOLDER IS A ROOT TOO, and it is a root in its own right rather
# than the parent of the content: `.calc.fn`, `.calc.stk` and `.calc.buf` are
# children of `.calc` and are packed INTO the labelframes with `-in` (spec §4's
# widget paths are normative), so `winfo children .calc.pw.buf` is EMPTY and a
# walk rooted at the content frame never reaches the holder.  What the holder
# draws is not decoration: it is the pane's title strip and the padding around
# the scrolling content — measured on :99 at the default 656x680, 25.2% of the
# Buffer pane's visible area, 16.0% of the Functions pane's and 10.8% of the
# Stack's.  Leaving them out is the user's own complaint in miniature ("the
# pointer is over the area that needs scrolling" — the title strip of a pane is
# over that area), and it was inconsistent as well: `.calc.stk` is a Labelframe
# too and was bound only because it happened to be a walk root.
#
# Region -> {name  y-target {y-step}  x-target {x-step}  {root widgets}}
proc calc::wheel_areas {} {
    return {
        {fn  .calc.fn.list  {3 units}
             .calc.fn.list  {3 units}     {.calc.pw.bot.fn .calc.fn}}
        {stk .calc.stk.list {5 units}
             .calc.stk.list {5 units}     {.calc.pw.stk .calc.stk}}
        {buf .calc.buf      {50 pixels}
             .calc.buf      {50 pixels}   {.calc.pw.buf .calc.buf .calc.btb}}
    }
}

# Scroll `w` along `axis` (y|x) by `dir` * `amount` `unit`.  Missing widget is a
# silent no-op: this runs from a binding, and a region torn down mid-gesture
# must not throw a background error over a wheel notch.
proc calc::wheel_scroll {w axis dir amount {unit units}} {
    if {![winfo exists $w]} { return 0 }
    catch {$w ${axis}view scroll [expr {$dir * $amount}] $unit}
    return 1
}

# Bind the six wheel sequences on ONE widget, aimed at this region's targets.
# nhse_bind_wheel's shape (xschem.tcl:1583-1587), with the target and step as
# arguments and Shift added for the horizontal axis W28 needs.
proc calc::wheel_bind {w yw ystep xw xstep} {
    foreach {seq tgt axis dir step} [list \
        <Button-4>         $yw y -1 $ystep \
        <Button-5>         $yw y  1 $ystep \
        <Shift-Button-4>   $xw x -1 $xstep \
        <Shift-Button-5>   $xw x  1 $xstep] {
        bind $w $seq "calc::wheel_scroll $tgt $axis $dir $step; break"
    }
    # <MouseWheel> carries a signed %D instead of a button number (Windows,
    # macOS, and Tcl > 8.7 on X11).  Same targets, same steps, sign from %D.
    bind $w <MouseWheel> \
        "calc::wheel_scroll $yw y \[expr {%D > 0 ? -1 : 1}\] $ystep; break"
    bind $w <Shift-MouseWheel> \
        "calc::wheel_scroll $xw x \[expr {%D > 0 ? -1 : 1}\] $xstep; break"
}

# ...and on every descendant, which is the whole point (bindings are per widget;
# Tk does not walk up the tree).  Returns how many widgets were bound — 0 means
# the region was not built, which is a bug and not a state.
proc calc::wheel_bind_tree {w yw ystep xw xstep} {
    if {![winfo exists $w]} { return 0 }
    # see the ruling above: a ttk::combobox owns the wheel, and its popdown is a
    # child, so this stops here rather than binding either.
    if {[winfo class $w] eq {TCombobox}} { return 0 }
    calc::wheel_bind $w $yw $ystep $xw $xstep
    set n 1
    foreach c [winfo children $w] {
        incr n [calc::wheel_bind_tree $c $yw $ystep $xw $xstep]
    }
    return $n
}

proc calc::wheel_bind_all {} {
    set out {}
    foreach area [calc::wheel_areas] {
        foreach {name yw ystep xw xstep roots} $area break
        set n 0
        foreach root $roots {
            incr n [calc::wheel_bind_tree $root $yw $ystep $xw $xstep]
        }
        lappend out $name $n
    }
    return $out
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

    # The panes.  Every one of the five now holds its real contents, so every
    # one is a bare labelframe (calc::panelframe).  The phase-0 placeholder
    # hints are gone with item 4, and so is the proc that drew them.
    #
    # ⚠ .calc.pw.stk is titled EMPTY, not `Stack`.  Spec W23 puts a labelframe
    # titled `Stack` INSIDE it (calc::build_stk), and two nested boxes both
    # captioned Stack is the word drawn twice.  See the note on build_stk.
    calc::panelframe .calc.pw.sel      {Selectors}
    calc::panelframe .calc.pw.buf      {Buffer}
    calc::panelframe .calc.pw.stk      {}
    calc::panelframe .calc.pw.bot.fn   {Functions}
    calc::panelframe .calc.pw.bot.pad  {Keypad}

    # D3: every pane carries a -minsize.  The numbers are the smallest height
    # (or width) at which the phase-1 contents are still usable, so a drag
    # cannot hide a region outright.
    #
    # ⚠ .calc.pw.bot.pad's 140 IS THE ONE NUMBER ITEM 4 WAS SENT TO RE-JUDGE,
    # and its FLOOR stays at 140 — deliberately, with a measurement behind it
    # now instead of a guess.  The phase-0 receipt ends owing exactly this: "the
    # keypad pane sits at its 140px minimum, against ~115px in the reference —
    # phase 1 puts real buttons there and that is when the number should be
    # judged".  Judged, against the real buttons (measured on this Tk, 1920x1080
    # dev display):
    #     winfo reqwidth .calc.pad          = 128   (the 4-wide key grid is
    #                                                96; the 2x2 of `user N`
    #                                                buttons is what needs 128)
    #     winfo reqwidth .calc.pw.bot.pad   = 140   (+ the labelframe's -padx 4
    #                                                a side and its border)
    # So 140 is not 25 px of whitespace over the reference's ~115: it is what
    # this pane's contents ask for, to the pixel, and lowering it to 128 was
    # tried and clipped the keypad by 2 px at the first-open sash (the pane got
    # 138).  A narrower pane is reachable — one COLUMN of four `user N` buttons
    # instead of a 2x2 gets to ~112 — and was rejected: it makes the keypad
    # seven rows tall and the four buttons read as a list rather than as the
    # block of four the reference draws.
    #
    # ⚠ 140 == 140 IS ZERO SLACK, and that is why the numbers below are only
    # FLOORS now: calc::apply_pane_minsize raises the two panes item 4 filled to
    # whatever their contents really request, the same way calc::apply_minsize
    # does for the toplevel.  Pinning 140 by hand made the comment above a claim
    # no code kept: with `font configure TkDefaultFont -size 12`, reqwidth
    # .calc.pad goes 128 -> 152 and reqwidth of the pane 140 -> 164, so at first
    # open the keypad rendered 143 against a request of 152 — CLIPPED, on a hand-
    # pinned minimum that could not follow it.  The floors stay as phase 0 wrote
    # them so the frozen layout is still the starting point; only the raise is
    # new.
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

    # W26-W31: the bottom pair.  Same `pack -in` rule as every row above — the
    # spec's paths are `.calc.fn` and `.calc.pad`, children of the toplevel,
    # drawn inside the two halves of .calc.pw.bot.
    calc::build_fn
    calc::build_pad
    pack .calc.fn  -in .calc.pw.bot.fn  -fill both -expand 1
    pack .calc.pad -in .calc.pw.bot.pad -fill both -expand 1

    foreach w {.calc.res .calc.sel .calc.mode .calc.buf .calc.btb .calc.stk
               .calc.fn .calc.pad} {
        raise $w
    }

    # LAST, because it walks the widget tree: every scrollable region's wheel
    # bindtag, on every widget in the region (see calc::wheel_areas).  Anything
    # created after this point must be tagged by whoever creates it.
    calc::wheel_bind_all
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

# (calc::placeholder — the "this pane is still owed" labelframe-plus-hint — is
# GONE as of item 4.  It had exactly two callers left, .calc.pw.bot.fn and
# .calc.pw.bot.pad, and both now hold their real contents; a proc that draws
# `category chooser + function list` in grey over a pane that HAS one would be a
# lie waiting for its next caller.  Phase 0's history is in the receipts.)

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
