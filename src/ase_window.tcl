# ase_window.tcl — the ASE-L session window (items 03+05-08+13 of
# doc/claude/ase_l_batch, spec doc/claude/specs/ase_l.md — UI v2 "ADE-L
# parity rework" is the authoritative chrome contract): ALL Tk widget code of
# the ASE-L feature. ase.tcl (the headless core + session model) stays
# Tk-free; its has_x-guarded `ase::open_state` is the ONE seam that reaches
# into this file.
#
# Dialog layer (item 07, spec "Menu tree v2" / "Choose Analyses dialog" /
# "Dialog style"): every menu-tree dialog is real — Choose Analyses (top
# radio section + per-analysis quick-field form + extra-options editor),
# Setup > Design (L/C/V type-to-filter comboboxes, View limited to schematic
# views), Setup > Model Files + Simulation > Options (one shared two-column
# list-dialog engine over the state's `models`/`options` lists, immediate
# commit per mutation), Outputs > Save All (save_all_v/save_all_i blankets,
# deck mapping allv -> `.save all` / alli -> `.options savecurrents` in
# ase.tcl), Session > Load State (mkinst-style 3-column browser filtered to
# simulation-state views, content import into THIS session) and Session >
# Save State (always Save-As; a read-only-opened session overwriting its own
# view goes through the shared modeless confirm). All dialogs are MODELESS
# (no grab/tkwait — test-drivable), themed, with deterministic widget paths
# and per-key records in the `dlg` array cleaned on proceed/cancel AND close.
#
# One toplevel per state view, named .ase<N> where N is the Cadence-style
# window number allocated from the SHARED C counter (`xschem
# allocate_window_number`, doc/claude/specs/window_numbering.md) — unique
# forever, so .ase<N> can never collide with a future editor/textwindow name.
# Chrome (UI v2): title `Analog Sim Environment <design cell>` (+ ` *` dirty
# marker); toolbar row under the menubar with the simulation-temperature
# entry (state key `temperature`, emits `.temp <T>` in the deck); bottom
# status bar `<win#> | Status: <S> | T=<T> C | Simulator: <sim> |
# State: <view>`; the v2 menu tree; NO log pane — a run opens a live-follow
# log toplevel instead (Ctrl-W closes, Simulation > Log reopens). Palette +
# named fonts are centralized in ase::theme / ase::ui::apply_theme (USER-
# LOCKED colors; no ASE widget left on Tk defaults). The four type roles —
# AseEntryFont data, AseBodyFont chrome, AseLabelFont headings, AseMonoFont
# machine text — are DERIVED from TkDefaultFont/TkFixedFont and name no family
# (issue 1398); the size knob is `ase_font_size`.
#
# Editing model (UI v2 "Panes", item 06): exactly THREE panes — Design
# Variables, Analyses, Outputs — each a ttk::treeview column table that is a
# pure VIEW of `ase::session_state` (no inline editing, no +/- buttons).
# Every mutation (checkbox-cell click, dialog OK, action-strip X delete)
# edits the session dict directly and calls `ase::session_update`, then
# repopulates the affected panes — there is nothing to harvest. Dialogs merge
# their fields over the row's ORIGINAL dict, so per-row keys the dialog does
# not show are preserved byte-for-byte. Row multi-select lives within ONE
# pane at a time (selecting in a pane clears the others); double-click a row
# opens its edit dialog; per-pane right-click context menus offer
# Add/Edit/Delete; the right vertical action strip carries the spec's
# OP,TR = --> X N&> > ! ~ buttons. The Outputs Value column fills from the
# per-SESSION `results` attr after a successful run (blank pre-run).
# The `ase::session_notify` hook only refreshes the TITLE + status bar;
# pane-changing paths repopulate explicitly.
#
# Run pipeline: a run opens the log toplevel and streams the simulator's
# stdout into it live via a `trace add variable ::execute(data,$id) write`
# (execute_fileevent appends 1024-byte chunks, so the trace fires per chunk;
# the EOF unset kills the trace, and run_finished — the completion callback,
# eval'd AFTER ase::run_done flushed the log file + parsed results — appends
# the tail and colors the status segment). Status mirrors
# set_simulate_button semantics: orange=Running, Green=Ready(ok), red=Error,
# themed panel background=idle. Stop kills via the pipe pid
# (`kill_running_cmds <id> -9`), unix only.

namespace eval ase::ui {
  # session key -> toplevel path (.ase<N>)
  variable wins [dict create]
  # item 16: ask_save_close's yes/no/cancel result (read across tkwait)
  variable asksave_result {}
  # session key -> allocated Cadence window number
  variable wnum [dict create]
  # session key -> {lib cell view}
  variable meta [dict create]
  # idlebg(key): status segment idle -background (the themed panel color),
  # captured after apply_theme at build
  variable idlebg;  array set idlebg {}
  # live-log bookkeeping: loglen(key) = chars of execute(data,$id) already in
  # the log widget; tracecb(key) = {id callback} of the attached trace
  variable loglen;  array set loglen {}
  variable tracecb; array set tracecb {}
  # ── STAGE 1: `anaargs` IS DELETED. ─────────────────────────────────────────
  # It was the per-type field order for the Arguments column -- one of EIGHT
  # copies of "what is a dc analysis", and the copy that PROVED the drift: it
  # advertised `ac {points start stop dec}` while ase::ui::chana_fields returned
  # `{points start stop}` and render_deck hardwired the word `dec`. The column
  # now renders ase::analysis_line -- THE SAME CALL render_deck emits -- so it
  # is structurally impossible for this pane to show a setting the deck does not
  # carry. See doc/claude/ase_analyses_batch/PLAN.md §1c.
  # pane frame name -> the state list key it views (UI v2: ONLY these three)
  variable panekeys [dict create vars variables ana analyses outs outputs]
  # selclear(key): suppress flag while pane_selected clears the other panes'
  # selections (the libmgr::suppress_select idiom)
  variable selclear; array set selclear {}
  # edrow(key,var|out): state-list index the open edit dialog targets
  # (-1 = the outputs Add flavor); cleaned on proceed/cancel AND in close
  variable edrow;   array set edrow {}
  # edchk(key,plot|save): the output editor's checkbutton variables
  variable edchk;   array set edchk {}
  # annot(key,op|volt): the `Results > Annotate` checkbutton variables (issue
  # 0682). SESSION-KEYED, not two globals: the ASE-L window is a plain toplevel
  # and several sessions can be open at once, so a bare ::annot_show_op would
  # make every session's menu show the last one's state. Re-derived from the
  # DESIGN context's mask by the submenu's -postcommand; cleaned in close.
  variable annot;   array set annot {}
  # dlg(key,...): per-window records of the item-07 dialog layer — Choose
  # Analyses antype/anen/anextra, Save All allv/alli, the Design/Save-As
  # combo full-value lists (dlib/dcell/dview/salib), the list-dialog row
  # index (models/simopt), and the Simulators row editor's own two
  # (simnames/simrow, plus simns — the -n checkbutton's variable, issue 1371).
  # Cleaned on dialog proceed/cancel AND in close.
  variable dlg;     array set dlg {}
  # issue 1398. cbopt: which toplevels have had their ttk::combobox popdown
  # option-database entries added (once per window; the entries are additive and
  # are never removed, so adding them twice is waste, not a bug).
  # colpolicy: per-treeview {columns headings policy}, so retune_columns can
  # re-derive a width the way build_pane first derived it.
  # colfont: the AseEntryFont/AseLabelFont metric the widths were last derived
  # AT, per toplevel — the guard that stops a retune undoing a dragged column.
  variable cbopt;     array set cbopt {}
  variable colpolicy; array set colpolicy {}
  variable colfont;   array set colfont {}
  # simuse(key): the Simulators dialog's "which one is in force" combobox
  # variable (issue 0937). Session-keyed for the same reason `annot` is: two
  # ASE-L windows can be open at once, and Tk resolves a -textvariable in the
  # global namespace, so one shared name would make both dialogs fight over
  # one value. The REGISTRY behind it is process-global; two open dialogs do
  # not refresh each other until reopened, which is recorded in issue 0937.
  variable simuse;  array set simuse {}
  # the shared two-column list-dialog configs (Setup > Model Files and
  # Simulation > Options share one engine): toplevel suffix, state list key,
  # row dict fields, column headings, row-editor toplevel suffix + title
  variable listdlg [dict create \
    models [dict create win models skey models cols {file section} \
                        heads {File Section} ed modrow edtitle {Model File}] \
    simopt [dict create win simopt skey options cols {name value} \
                        heads {Name Value} ed optrow edtitle {Simulation Option} \
                        fill ase::ui::optsheet_fill \
                        stamp ase::ui::optsheet_stamp]]
  # sod(...): the Select On Design click mode (item 08). ONE mode globally:
  # sod(active) = the owning session key; per key: sod($key,canvas) = the
  # design window's canvas whose <ButtonPress-1>/<ButtonRelease-1>/
  # <Key-Escape> bindings the mode seized, sod($key,flavor) = the queue
  # flavor dict {save S plot P}, sod($key,prevpress|prevrel|prevesc) = the
  # seized bindings' PREVIOUS scripts (restored VERBATIM on exit — empty
  # string = no binding — so the mode composes with the addpin/addlabel
  # shared canvas-Esc slot), sod($key,count) = outputs queued this mode.
  # Item 13 adds the mode dimension: sod($key,mode) = `outputs` (item-08
  # behavior: clicks write session outputs via sod_queue) or `plot`
  # (Results > Direct Plot: clicks queue TRACE expressions into
  # sod($key,queue) via dp_queue — session outputs are NEVER written — and
  # sod_end hands the queue to dp_finish, which raises the waveform viewer).
  variable sod;     array set sod {}
}

# --- theme (UI v2 "Window chrome": USER-LOCKED palette + named fonts) --------

# The USER-LOCKED palette, as a PURE READ. No font is created, no ttk style is
# configured, no option-database entry is added: calling this cannot change how
# any other window in the application looks.
#
# ⚠ That is the whole reason it exists separately from ase::theme. ase::theme
# RECONFIGURES four named fonts (issue 1398 — it used to `font create` three,
# guarded, which is why a size knob could never have reached an open window)
# and it configures the shared ttk styles. A caller that only wants to know
# what colour a panel is must not pay a font-changed cascade for it — and the
# per-widget colour reads inside ase::ui::_theme_widget come through HERE for
# the same reason. Until 1398 ase::theme also did a bare
# `option add *TCombobox*Listbox.font AseEntryFont`, PROCESS-GLOBAL, reaching
# the popdown of every ttk::combobox in xschem (33 call sites, 15 of them in
# xschem.tcl) including ones created before the call, because the popdown
# listbox is built lazily; that entry is now scoped per ASE window in
# ase::ui::_combobox_popdown_font. The Calculator's
# calc::color reads this proc for exactly that reason
# (doc/claude/specs/calculator.md R113); ase::theme itself returns
# `[ase::palette $name]` so there is one definition, not two.
#
#   panel      window and panel chrome
#   table      list / tree / entry backgrounds
#   header     header strips, column headings, active menu entries
#   accent     the dark-red pane-title accent
#   fieldfg    text on a `table` surface
#   selectbg   selection background in lists and trees
#   selectfg   selection foreground
#   disabledbg a disabled row's background
#   disabledfg a disabled row's foreground
#
# The last five were ttk's Treeview defaults until 2026-08-15 and are now named
# here and APPLIED by ase::theme below, so that a reader (the Calculator) gets
# the same value the browser's own widgets render with instead of whatever the
# ambient ttk theme happens to supply. Their values are the measured `default`
# theme defaults, so nothing moved when they were written down.
proc ase::palette {{name {}}} {
  set pal [dict create panel #f2f2f2 table #ffffff header #e8e8e8 \
                       accent #8b0000 \
                       fieldfg #000000 selectbg #4a6984 selectfg #ffffff \
                       disabledbg #d9d9d9 disabledfg #a3a3a3]
  if {$name ne {}} { return [dict get $pal $name] }
  return $pal
}

# One derived hover/trough step off a palette colour: ±40 of 255, with the
# direction flipped on a dark ground so the step exists at both ends. A
# deliberate COPY of rdw::_shade_step (rdw.tcl:2499-2515) and its rdw::_rgb255
# (:2456) rather than a call: ase_window.tcl must not require rdw.tcl to have
# been sourced. (NOT, as an earlier draft of the plan claimed, because
# test_rdw_window_1245.tcl:9849 would red — that check constrains rdw.tcl's own
# literals, not this file's; PLAN.md §0.6.)
#
# Why it exists at all: the Button/Menu arms of apply_theme set -background to
# the palette's panel and left -activebackground at Tk's stock #f8f8f8, which
# is 1.05:1 against #f2f2f2 — theming ASE-L DESTROYED a hover step stock Tk
# had. On the shipped palette this returns #cacaca: 1.46:1 against the panel,
# with black text on it at 12.81:1. Issue 1398.
#
# An unparseable colour returns itself, so the worst case is no hover step
# rather than a wrong colour or a throw.
proc ase::shade {c} {
  set rgb {}
  if {[regexp {^#([0-9a-fA-F]{6})$} $c -> h]} {
    for {set i 0} {$i < 3} {incr i} {
      set v 0
      if {[scan [string range $h [expr {$i * 2}] [expr {$i * 2 + 1}]] %x v] != 1} {
        return $c
      }
      lappend rgb $v
    }
  } elseif {[llength [info commands winfo]]} {
    catch {
      set raw [winfo rgb . $c]
      if {[llength $raw] == 3} {
        foreach v $raw { lappend rgb [expr {int($v / 257.0 + 0.5)}] }
      }
    }
  }
  if {[llength $rgb] != 3} { return $c }
  lassign $rgb r g b
  set d [expr {0.30 * $r + 0.59 * $g + 0.11 * $b > 96 ? -40 : 40}]
  set out {}
  foreach v $rgb {
    set n [expr {$v + $d}]
    if {$n < 0} { set n 0 }
    if {$n > 255} { set n 255 }
    lappend out $n
  }
  return [format {#%02x%02x%02x} {*}$out]
}

# ---------------------------------------------------------------------------
# THE TYPE ROLES, Tk HALF — ISSUE 1398. Nothing below may be reached without a
# display: `--nogui` has no `font` command AT ALL, measured, which is the same
# trap rdw.tcl:2553 records for every other Tk command.

# Create-or-RECONFIGURE one named font. `font create` RAISES on a name that
# already exists, which is why ase::theme guarded each of its three fonts with
# an lsearch — and why a size knob would have been dead on arrival: the guard
# meant a size change could never reach a window that was already open.
# slickprop::_mkfont (property_form.tcl:340) and rdw::_font (rdw.tcl:2589) are
# the two shapes already in this tree; this is theirs.
#
# ⚠ THE NO-OP GUARD IS LOAD-BEARING, NOT TIDY. ase::theme is reached from
# ase::ui::apply_theme, and ase::ui::populate (:1597 below) runs that on EVERY
# state mutation across ~53 widgets. A `font configure` that writes the same
# spec back still fires Tk's font-changed cascade to every widget carrying the
# font, so an unguarded reconfigure turns each repopulate into a relayout
# storm. Comparing first makes the steady state free and keeps the knob live.
proc ase::_mkfont {name spec weight} {
  if {$spec eq {}} { return }
  set want [dict merge $spec [dict create -weight $weight -slant roman \
                                          -underline 0 -overstrike 0]]
  if {[lsearch -exact [font names] $name] < 0} {
    if {[catch {font create $name}]} { return }
  } elseif {![catch {font configure $name} have] && $have eq $want} {
    return
  }
  catch {font configure $name {*}$want}
}

# The user's ASE-L text size in points, or {} for "follow TkDefaultFont".
# Declared as `set_ne ase_font_size 0` in src/xschem.tcl beside its two
# siblings ciw_font_size and rdw_font_size.
#
# Read on every ase::theme call rather than once, so it is ORDER-INDEPENDENT:
# an xschemrc that sets it after this file is sourced still lands, and because
# ase::_mkfont RECONFIGURES, re-calling ase::theme rescales every open ASE
# window and dialog with no widget walk at all.
#
# ⚠ AN OUT-OF-BAND VALUE IS REFUSED, NOT CLAMPED. ciw_font (ciw.tcl:391) and
# rdw::font_size (rdw.tcl:2313) both refuse; a clamp turns a typo into a silent
# new setting the user never chose and can only discover by measuring glyphs.
proc ase::font_size {} {
  if {![info exists ::ase_font_size]} { return {} }
  set n $::ase_font_size
  if {![string is integer -strict $n] || $n == 0} { return {} }
  if {$n < 6 || $n > 32} { return {} }
  # ⚠ CANONICAL INTEGER, NOT THE RAW STRING. `string is integer -strict` accepts
  # ` 8 `, `+8` and `0x10`; handing any of those back defeats ase::_mkfont's
  # no-op guard for the life of the process, because Tk normalises the stored
  # spec and `$have eq $want` can then never be true — four font configures on
  # every ase::theme call, and ase::ui::populate calls it on every mutation.
  # Measured 2026-09-09 by this item's adversary. This cannot change WHICH
  # values are accepted; the band test above has already run.
  return [expr {$n + 0}]
}

# The central ASE look: the four named fonts DERIVED from the system faces, the
# combobox field style + state map, and the locked palette applied to the
# shared styles. Returns the whole palette dict, or one color when `name` is
# given.
#
# ⚠ NOT a pure reader — see ase::palette. Call THIS when widgets are about to
# be created or themed; call ase::palette when only a colour is wanted.
proc ase::theme {{name {}}} {
  # --- THE FOUR TYPE ROLES, DERIVED. No family literal anywhere. Issue 1398.
  #
  # This window asked for Arial 10 bold and Courier 13. NEITHER FAMILY IS
  # INSTALLED here — `fc-match Arial` -> Nimbus Sans, `fc-match Courier` ->
  # Nimbus Mono PS — so Tk substituted silently and ASE-L became the only
  # window in the application not in the system face: the RDW, the Calculator,
  # the Library Manager, the CIW and the property form all render in DejaVu.
  # ASE-L's OWN menubar was Nimbus too, because the Menu arm of apply_theme
  # paints it — it was not the exception, it was part of the same fault, and
  # it was the only BOLD menubar in the process.
  #
  # ⚠ `font configure`, NOT `font actual`. `configure` answers the spec AS
  # SPELLED, so a TkDefaultFont an xschemrc spelled in PIXELS is copied
  # verbatim; `actual` normalises pixels to POINTS behind the user's back and
  # the copy then drifts the moment `tk scaling` moves. MEASURED on :99 with
  # the base at `-size -14`: the `configure` copy is 18 px linespace at scaling
  # 1.39 and 18 px at 2.0, tracking the base exactly, while the `actual` copy
  # is 17 px and then 24 px — 33% adrift, from a spelling the user chose.
  # rdw.tcl:2562 records the same trap from the other side.
  #
  # ⚠ ONE SIZE, SEPARATED BY WEIGHT. The old ladder was 10 bold over 13
  # regular — headings THREE POINTS SMALLER than the rows they head — and
  # apply_theme put the bold font on 52 of the window's 53 fonted widgets
  # (measured, the one exception being the temperature entry), so nothing in
  # the window could be emphasised because everything already was. Bold is now
  # spent on labelframe titles and column headings and on nothing else.
  #
  # ⚠ AseLabelFont KEEPS ITS NAME AND KEEPS ITS BOLD, and only loses its job.
  # src/wave_viewer.tcl carries it on widgets outside this window's theming
  # walk (:9036, :9052, :9075, :9425, :10498), so inverting the name to regular
  # would silently un-bold them. AseBodyFont is the one new name and takes
  # everything the bold font used to paint.
  if {[llength [info commands font]]} {        ;# --nogui has no `font` at all
    set uispec {}
    set mospec {}
    catch {set uispec [font configure TkDefaultFont]}
    catch {set mospec [font configure TkFixedFont]}
    set want [ase::font_size]
    if {$want ne {} && $uispec ne {}} { dict set uispec -size $want }
    if {$want ne {} && $mospec ne {}} { dict set mospec -size $want }
    ase::_mkfont AseEntryFont $uispec normal   ;# DATA: cells, entries, combos
    ase::_mkfont AseBodyFont  $uispec normal   ;# CHROME: menus, buttons, prose
    ase::_mkfont AseLabelFont $uispec bold     ;# HEADINGS ONLY: titles+columns
    ase::_mkfont AseMonoFont  $mospec normal   ;# MACHINE TEXT: the log
  }
  # ⚠ THE COMBOBOX POPDOWN FONT IS NO LONGER SET HERE. It used to be a global
  # `option add *TCombobox*Listbox.font AseEntryFont`, which permanently changed
  # the dropdown font of EVERY combobox in xschem the moment a bench was
  # opened. It is now scoped per ASE window — see
  # ase::ui::_combobox_popdown_font below, which also records why the obvious
  # narrowing does not work.
  #
  # ⚠ THE COMBOBOX STATE MAP IS THE POINT, not the base -fieldbackground.
  # ttk's own `map TCombobox -fieldbackground {readonly #d9d9d9 disabled
  # #d9d9d9}` is inherited by every derived style, so declaring only the base
  # colour still painted BOTH readonly comboboxes the palette's own DISABLED
  # grey — including "Use this one:" in the Simulators dialog, the control
  # that decides which binary runs. The Calculator measured and fixed this
  # identical trap (test_calc_skeleton.tcl:1271-1292); ASE-L never got it.
  # Locked palette values only, and `map` REPLACES rather than merges, so the
  # disabled half is re-declared alongside.
  catch {
    ttk::style configure Ase.TCombobox \
      -fieldbackground [ase::palette table] -foreground [ase::palette fieldfg]
    ttk::style map Ase.TCombobox \
      -fieldbackground [list readonly [ase::palette table] \
                             disabled [ase::palette disabledbg]] \
      -foreground [list disabled [ase::palette disabledfg]]
  }
  # pane tables (UI v2): white rows in the entry font, the USER-LOCKED
  # header-strip color on the column headings.
  # The -foreground and the state map are declared rather than inherited: they
  # were ttk Treeview defaults, which meant the palette did not actually own
  # the text and selection colours the browser renders with, and anything
  # reading them back (calc::color) was reading the ambient theme, not this
  # one. The values are the measured `default`-theme defaults, so declaring
  # them changed no pixel; the `disabled` half is re-declared with them because
  # `ttk::style map` REPLACES a style's map rather than merging into it.
  catch {
    ttk::style configure Ase.Treeview -font AseEntryFont \
      -background [ase::palette table] -fieldbackground [ase::palette table] \
      -foreground [ase::palette fieldfg] \
      -rowheight [expr {[font metrics AseEntryFont -linespace] + 4}]
    ttk::style map Ase.Treeview \
      -background [list disabled [ase::palette disabledbg] \
                        selected [ase::palette selectbg]] \
      -foreground [list disabled [ase::palette disabledfg] \
                        selected [ase::palette selectfg]]
    # the heading's -foreground is DECLARED for the same reason the rows' is:
    # unowned, it comes from whatever `dark_gui_colorscheme` last wrote into
    # the option database. Its value is the measured `default`-theme default,
    # so nothing moved on the light palette (issue 1398).
    ttk::style configure Ase.Treeview.Heading -font AseLabelFont \
      -background [ase::palette header] -foreground [ase::palette fieldfg]
  }
  return [ase::palette $name]
}

# The popdown LISTBOX of a ttk::combobox has no -font option: ttk builds it
# LAZILY on the first post and it takes its font from the OPTION DATABASE. So
# the option database is the only lever, and ase::theme used to pull it with a
# bare `option add *TCombobox*Listbox.font AseEntryFont` — an unqualified
# pattern that permanently changed the dropdown font of every combobox in
# xschem (33 constructor sites, including ones that already existed) the moment
# a bench was opened. test_calc_skeleton.tcl:120-137 records that leak in prose.
#
# ⚠ AND THE OBVIOUS NARROWING DOES NOT WORK. MEASURED on :99 against a real
# `.ase9.simdlg.use.popdown.f.l` and a control combobox outside the window:
#
#     *TCombobox*Listbox.font       ase HIT    other HIT    <- the shipped leak
#     *ase*TCombobox*Listbox.font   ase miss   other miss   <- matches NOTHING:
#                                        the path component is `ase9`, not
#                                        `ase`, and option components match
#                                        WHOLE, never by prefix
#     .ase9*Listbox.font            ase miss   other miss   <- a LEADING dot
#                                        makes an empty first component
#     *ase9*Listbox.font            ase HIT    other miss   <- the one that works
#
# So the pattern is built from the window's own `.aseN` component. `option add`
# is additive and is never removed, so re-adding it on every repopulate would
# grow the option database for the life of the process: one entry per ASE
# window, recorded in `cbopt`, and never again.
proc ase::ui::_combobox_popdown_font {w} {
  variable cbopt
  # ⚠ THE SCOPE IS THE TOPLEVEL WE WERE HANDED, NOT AN `aseN` NAME. This proc
  # first matched only `ase[0-9]+`, but ase::ui::apply_theme is called on FIVE
  # waveform-viewer trees (src/wave_viewer.tcl:9252, 16233, 16683, 16983,
  # 17066) whose toplevels are `wvN`. Those comboboxes got AseEntryFont on the
  # ENTRY and left their popdown on the ambient font, so with ::ase_font_size
  # set the control scaled and its own dropdown did not. Measured 2026-09-09.
  # Keying on the toplevel keeps the per-window scoping that replaced the old
  # process-global `option add *TCombobox*Listbox.font` — which reached all 33
  # ttk::combobox call sites in xschem — while covering every tree that is
  # actually themed.
  # ⚠ THE ROOT COMPONENT, NOT `winfo toplevel`. Every ASE-L dialog IS a
  # toplevel (`.ase4.simdlg`), so `winfo toplevel` answers `.ase4.simdlg` and
  # the pattern would carry a dot in the middle — `*ase4.simdlg*Listbox.font`,
  # which matches nothing. Measured: it left the ASE-L window's own comboboxes
  # with an unstyled popdown, i.e. it broke the case the old `ase[0-9]+` scan
  # got right. The first path component is `ase4` for the window AND for every
  # dialog under it, and `wv3` for a waveform-viewer tree.
  set root [lindex [split [string trimleft $w .] .] 0]
  if {$root eq {} || [info exists cbopt($root)]} { return }
  set cbopt($root) 1
  # The popdown LIST is a separate widget from the field. Owning the field's
  # background (Ase.TCombobox -fieldbackground) and not the list's left a white
  # field above a grey80 list — they matched before this batch, both grey.
  catch {option add *$root*Listbox.font AseEntryFont}
  catch {option add *$root*Listbox.background [ase::palette table]}
  catch {option add *$root*Listbox.foreground [ase::palette fieldfg]}
}

# Recursively re-skin an ASE widget tree: every widget class the ASE window
# uses gets the locked palette + a named font — no stock-Tk leftovers. The
# shared `textwindow` viewer (Netlist > Display) deliberately stays stock:
# restyling it would restyle every non-ASE use.
#
# ⚠ THE FONTS AND SHARED STYLES ARE BUILT ONCE PER WALK, NOT ONCE PER WIDGET.
# ase::theme is not a pure reader (its own header says so) and, since issue
# 1398, it RECONFIGURES four named fonts instead of create-guarding three. The
# per-widget colour reads below therefore go through ase::palette, which is
# pure; the one ase::theme call is here.
proc ase::ui::apply_theme {w} {
  catch {ase::theme}
  ase::ui::_theme_widget $w
  # the fonts may just have moved under the columns; retune_columns is a no-op
  # unless they actually did
  catch {ase::ui::retune_columns [winfo toplevel $w]}
}

# The recursion. Split out of apply_theme so ase::theme runs once per walk.
#
# ⚠ EVERY ARM THAT WRITES A BACKGROUND NOW WRITES A FOREGROUND (issue 1398).
# Without one, xschem's shipped `dark_gui_colorscheme 1` (src/xschem.tcl:19078,
# `option add *foreground white startupFile`) won every widget ASE-L painted:
# MEASURED live, 58 widgets at 1.119:1 — the whole action strip, the whole
# status bar, every menu and every cascade — and the temperature entry at
# 1.000:1, white on its own #ffffff, literally invisible. Owning the foreground
# is the WHOLE of that fix. It is NOT a new colour: on the shipped light
# palette fieldfg is #000000, which is what every classic widget already
# rendered, so this moves zero pixels there. ase::palette stays USER-LOCKED.
proc ase::ui::_theme_widget {w} {
  # ⚠ A LIVE TOOLTIP IS NOT OURS. ::balloon (src/xschem.tcl:14948-14958) builds
  # `<parent>.balloon` as a CHILD toplevel with -background black and a
  # lightyellow label, and ase::ui::populate ends in apply_theme on every state
  # mutation — so a tooltip that happened to be on screen when a row changed
  # was repainted to panel grey with its border gone, in place, while the user
  # was reading it.
  if {[string match {*.balloon} $w]} { return }
  set pal   [ase::palette]
  set panel [dict get $pal panel]
  set table [dict get $pal table]
  set fg    [dict get $pal fieldfg]
  set dis   [dict get $pal disabledfg]
  set hot   [ase::shade $panel]
  set cls [winfo class $w]
  switch -- $cls {
    Toplevel - Frame {
      catch {$w configure -background $panel}
    }
    Labelframe {
      # ⚠ THE ACCENT IS THE ONLY -foreground THIS ARM MAY WRITE. The three pane
      # titles are the window's one accent surface and test_ase_window.tcl:551
      # pins them at #8b0000; a generic fieldfg written after it would red that
      # check and flatten the only grouping cue the window has.
      catch {$w configure -background $panel -font AseLabelFont \
                          -foreground [dict get $pal accent]}
    }
    Menu {
      catch {$w configure -background $panel -foreground $fg \
                          -activebackground $hot -activeforeground $fg \
                          -disabledforeground $dis -font AseBodyFont}
    }
    Button - Checkbutton - Radiobutton {
      # Radiobutton is new here: Choose Analyses' four type pills were stock
      # #d9d9d9 against a #f2f2f2 window because no arm claimed them.
      catch {$w configure -background $panel -foreground $fg \
                          -activebackground $hot -activeforeground $fg \
                          -disabledforeground $dis -font AseBodyFont}
      # The indicator box is a third colour and only two of the three classes
      # have it, so it gets its own catch: ONE unknown option voids the WHOLE
      # configure call, which would silently leave a Button unthemed.
      catch {$w configure -selectcolor $table}
    }
    Label {
      catch {$w configure -background $panel -foreground $fg -font AseBodyFont}
    }
    Entry {
      # -insertbackground is a foreground too: the dark scheme's
      # `option add *insertBackground white` put a white caret in the white
      # temperature field, so even the cursor was invisible.
      # ⚠ AND -readonlybackground AND -disabledbackground. A Tk Entry in
      # `readonly` or `disabled` state paints with THOSE, not with -background,
      # so owning only -background and -foreground made the dark scheme WORSE
      # than it was: measured 2026-09-09, the Simulators row editor's readonly
      # Name: field went from 12.635:1 (white on grey20, inherited) to
      # 1.662:1 — black text on the option database's near-black ground —
      # in the very scheme this arm exists to fix. Both values are already in
      # the locked palette; no new colour is minted here.
      #
      # ⚠ READONLY TAKES `disabledbg`, NOT `table`. A readonly Entry that is the
      # same white as an editable one has lost the only thing that said it was
      # not editable — and the shipped light scheme drew it grey (the ambient
      # `option add *readonlyBackground grey70`). disabledbg keeps the
      # affordance, keeps it identical in both schemes, and reads 14.17:1
      # against fieldfg. The Simulators row editor's `Name:` field is the one
      # widget in ASE-L this decides.
      catch {$w configure -background $table -foreground $fg \
                          -readonlybackground [dict get $pal disabledbg] \
                          -disabledbackground [dict get $pal disabledbg] \
                          -disabledforeground $dis -insertbackground $fg \
                          -selectbackground [dict get $pal selectbg] \
                          -selectforeground [dict get $pal selectfg] \
                          -font AseEntryFont}
    }
    Listbox {
      # Load State's three lib/cell/view browsers (:6150). They were stock
      # apart from the two options set at construction, so the selection they
      # draw came from the ambient theme rather than the locked palette.
      catch {$w configure -background $table -foreground $fg \
                          -disabledforeground $dis \
                          -selectbackground [dict get $pal selectbg] \
                          -selectforeground [dict get $pal selectfg] \
                          -font AseEntryFont}
    }
    Text {
      catch {$w configure -background $table -foreground $fg \
                          -insertbackground $fg -font AseMonoFont}
    }
    TCombobox {
      catch {$w configure -font AseEntryFont -style Ase.TCombobox}
      ase::ui::_combobox_popdown_font $w
    }
    Treeview {
      # ttk widgets ignore -background/-font configure: style-based theming
      catch {$w configure -style Ase.Treeview}
    }
    Scrollbar {
      catch {$w configure -background $panel}
    }
  }
  foreach c [winfo children $w] { ase::ui::_theme_widget $c }
}

# The toplevel of the session `key`, or {} (the ase::open_state raise seam and
# the tests' window lookup).
proc ase::ui::window_for {key} {
  variable wins
  if {[dict exists $wins $key]} { return [dict get $wins $key] }
  return {}
}

# The Cadence-style window NUMBER of the session `key`'s ASE-L window (the N
# of .aseN, allocated from the shared C counter at window build time), or {}
# when the session has no window (headless, or never opened). Public
# accessor for the private `wnum` dict — issue 0151, the schematic-side
# `ase::window_number_for_current` query.
proc ase::ui::number_for {key} {
  variable wnum
  if {[dict exists $wnum $key]} { return [dict get $wnum $key] }
  return {}
}

# Build + show the session window (called by ase::open_state only when no
# window exists for the key — this is the only place a window number is
# consumed). Returns the toplevel path.
proc ase::ui::open {key lib cell view} {
  variable wins; variable wnum; variable meta
  set N [xschem allocate_window_number]
  set top .ase$N
  toplevel $top
  dict set wins $key $top
  dict set wnum $key $N
  dict set meta $key [list $lib $cell $view]
  # session mutations repaint the title + status bar (dirty marker, T=) from
  # now on
  set ::ase::session_notify ase::ui::session_changed
  ## 1370's REPAIR: and so does a REGISTRY mutation, from wherever it is made.
  ## The dialog's own refresh (ase::ui::simdlg_fill) covers all five gestures
  ## of Setup > Simulators and NOTHING ELSE, and the registry has a second
  ## door: `ase::sim_register <name> <path>` then `ase::sim_select <name>`
  ## typed into the Command window, which is the pre-0937 path and the one this
  ## user's own ngspice-ver50 entry was first created through. Measured live by
  ## 1370's adversary: with a window open on `Simulator: ngspice-ver50`, that
  ## pair left the bar naming ngspice-ver50 while ase::sim_label already
  ## answered the new entry -- a name on the bar for a simulator that would NOT
  ## run, until the run itself healed it.
  ##
  ## 1395: AND AS OF THAT ISSUE THAT DOOR ALSO PERSISTS. `ase::sim_register`
  ## and `ase::sim_unregister` write the saved list themselves (ase::sim_touch),
  ## so the CIW pair above now survives the restart it always promised -- the
  ## dialog is no longer the only door that reaches disk.
  ##
  ## ⚠ AND THE CHOICE HALF OF THAT DOOR DOES NOT, DELIBERATELY. `ase::sim_select`
  ## writes nothing: the user's ruling is that *which* registered simulator is
  ## the one to use is part of the ASE-L state, so it DIRTIES the session and
  ## waits for an explicit save. Registering is environment and lands at once;
  ## choosing is state and is saved with the bench. The dialog's own combobox
  ## goes through ase::ui::simdlg_use, which sets the state key and never the
  ## file.
  ##
  ## ⚠ NO ARGUMENT. The registry is process-global and this hook has no session
  ## to name, so it repaints EVERY open bar. Same single-slot discipline as
  ## session_notify, and set here rather than at file scope for the same reason
  ## that one is: nothing in ase.tcl may depend on this file existing.
  set ::ase::sim_notify ase::ui::refresh_status_all
  # window-activation logging, the CIW/LibMgr pattern ('+' keeps other
  # bindings; notify_window_active dedupes the FocusIn repeats)
  bind $top <FocusIn> "+[list notify_window_active $N "ASE-L $lib/$cell"]"
  # item 16: the real user close entry points route through close_request (the
  # dirty-session save prompt); ase::ui::close stays the teardown primitive
  wm protocol $top WM_DELETE_WINDOW [list ase::ui::close_request $key]
  bind $top <Control-w> [list ase::ui::close_request $key]
  bind $top <Control-W> [list ase::ui::close_request $key]
  ase::ui::build $key $top
  ase::ui::populate $key
  # item 14 (D6): a state saved with its viewer open relaunches the viewer —
  # FRESH-open only, deliberately not the ase::open_state raise arm
  # (re-raising an existing session must not resurrect a viewer the user
  # closed)
  ase::ui::viewer_restore $key
  return $top
}

# Session > Close / WM close: drop trace bookkeeping, unregister the session
# (v1 contract: close DISCARDS unsaved edits — an ase::echo notice, no modal
# save-nag), destroy the toplevel and every per-key record. The log toplevel
# is a child of the session toplevel, so it dies with it.
proc ase::ui::close {key} {
  variable wins; variable wnum; variable meta; variable idlebg
  variable loglen; variable selclear; variable edrow; variable edchk
  variable dlg; variable annot; variable simuse
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  ase::ui::drop_trace $key
  if {[ase::session_dirty $key]} {
    catch {::ase::echo "ase: closed $key with unsaved state edits (discarded)"}
  }
  ase::session_close $key
  dict unset wins $key
  dict unset wnum $key
  dict unset meta $key
  catch {unset idlebg($key)}
  catch {unset loglen($key)}
  catch {unset selclear($key)}
  array unset edrow $key,*
  array unset edchk $key,*
  array unset annot $key,*
  array unset dlg $key,*
  # issue 0937: the Simulators dialog's in-force combobox variable is keyed by
  # session, not by dialog, so it outlives the dialog on purpose and has to be
  # dropped with the session.
  catch {unset simuse($key)}
  catch {destroy $top}
  # item 13 (D10): the session's waveform viewer dies with the session
  # (wviewer::close destroys its OWN toplevel and is registry-keyed — no-op
  # headless or when no viewer is open)
  catch {wviewer::close $key}
  # binding-leak guard (item 08): end an active Select On Design mode so the
  # design canvas gets its bindings back. AFTER the destroy + wins unset, so
  # sod_end's raise-the-ASE-window arm no-ops on the dead toplevel.
  ase::ui::sod_end $key
}

# --- item 16: save-on-close prompt -------------------------------------------
# Opening a state view, editing it, then closing the ASE window (or quitting
# xschem) must offer a Cadence/ask_save-style Yes/No/Cancel "save changes?"
# prompt for any DIRTY session — exactly like a normal schematic. See
# doc/claude/ase_l_batch/prompts/item16_dirty-prompt.md (D1-D9). ase::ui::close
# stays the unconditional teardown primitive (~10 direct test/quit callers);
# the prompt lives in the close_request WRAPPER wired to the real user close
# entry points (WM_DELETE, Session>Close, Ctrl-W).

proc ase::ui::asksave_done {w val} {
  set ::ase::ui::asksave_result $val
  catch {destroy $w}
}

# Modal "save this dirty ASE session?" prompt (ask_save semantics + ASE theme).
# Returns yes / no / {} (empty == Cancel). Child of the session toplevel so it
# dies with it and tests can find it at $top.askclose.
proc ase::ui::ask_save_close {key} {
  variable wins
  if {![dict exists $wins $key]} { return no }
  set top [dict get $wins $key]
  set w $top.askclose
  catch {destroy $w}
  toplevel $w
  wm title $w {Save State?}
  catch {wm transient $w $top}
  set cell [ase::ui::design_cell_name $key]
  label $w.msg -font AseLabelFont -justify left -anchor w \
    -text "Simulation state “$cell” has unsaved changes.\n\nSave changes before closing?"
  pack $w.msg -side top -fill x -padx 16 -pady 12
  frame $w.btns
  button $w.btns.yes    -text Yes    -width 8 -command [list ase::ui::asksave_done $w yes]
  button $w.btns.no     -text No     -width 8 -command [list ase::ui::asksave_done $w no]
  button $w.btns.cancel -text Cancel -width 8 -command [list ase::ui::asksave_done $w {}]
  pack $w.btns.yes $w.btns.no $w.btns.cancel -side left -padx 5 -expand yes
  pack $w.btns -side bottom -fill x -padx 8 -pady 8
  bind $w <Return> [list $w.btns.yes invoke]
  bind $w <y>      [list $w.btns.yes invoke]
  bind $w <n>      [list $w.btns.no invoke]
  ase::ui::bind_dialog_esc $w [list $w.btns.cancel invoke]  ;# ESC = Cancel
  ase::ui::apply_theme $w
  set ::ase::ui::asksave_result {}
  update
  # The build-time `update` above pumps the event loop, so a Cancel/close that
  # lands during it (a WM or WSLg compositor teardown, or a test driving the
  # modal) can destroy $w before we reach tkwait. raise/grab already tolerate a
  # gone window via catch; guard focus the same way and skip tkwait on an
  # already-destroyed window (tkwait on a missing window throws) so this modal
  # can never leak an uncaught "bad window path name". The result asksave_done
  # recorded still stands (its Cancel/{} init when nothing ran).
  catch {raise $w}
  catch {grab set $w}
  catch {focus $w.btns.yes}
  if {[winfo exists $w]} { tkwait window $w }
  return $::ase::ui::asksave_result
}

# Run Save State (Save-As) MODALLY for the close/quit paths: show the modeless
# save_state_dialog, block until it is dismissed, and report whether the save
# COMPLETED (1) or was cancelled (0). No grab (the overwrite confirm is a nested
# child — since 2026-09-09 that is EITHER the read-only confirm or the new
# "this state exists" one, save_state_ok :6481; both are the same modeless
# ase::ui::confirm and both leave THIS dialog up, so the tkwait below still
# ends only on a completed save or a dismissed form). Completion is flagged by
# do_save_state_as via dlg($key,saveas_result).
proc ase::ui::save_state_modal {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return 0 }
  set dlg($key,saveas_result) 0
  set w [ase::ui::save_state_dialog $key]
  if {![winfo exists $w]} { catch {unset dlg($key,saveas_result)}; return 0 }
  tkwait window $w
  set r 0
  if {[info exists dlg($key,saveas_result)]} { set r $dlg($key,saveas_result) }
  catch {unset dlg($key,saveas_result)}
  return $r
}

# item 16: prompt-aware session close. Clean -> teardown. Dirty -> yes/no/cancel:
#   Yes    -> Save-As; close ONLY if the save completed (cancelled Save-As aborts)
#   No     -> close, discarding (ase::ui::close's discard notice fires)
#   Cancel -> abort, leaving the window + per-window state arrays intact
proc ase::ui::close_request {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  if {![ase::session_dirty $key]} { ase::ui::close $key; return }
  switch -- [ase::ui::ask_save_close $key] {
    yes     { if {[ase::ui::save_state_modal $key]} { ase::ui::close $key } }
    no      { ase::ui::close $key }
    default { return }
  }
}

# item 16: xschem-quit ASE sweep. Prompt each dirty open session; a Cancel on
# ANY aborts the whole quit (return 0). Yes -> Save-As (a cancelled Save-As also
# aborts); No -> discard+close. Returns 1 to proceed. No-op (returns 1) when no
# ASE window is open. Iterates a snapshot of the open-window keys so the
# ase::ui::close dict-unset mid-loop is safe.
proc ase::ui::prompt_all_on_quit {} {
  variable wins
  foreach key [dict keys $wins] {
    if {![dict exists $wins $key]} { continue }
    if {![ase::session_dirty $key]} { continue }
    catch {raise [dict get $wins $key]}
    switch -- [ase::ui::ask_save_close $key] {
      yes     { if {![ase::ui::save_state_modal $key]} { return 0 }
                ase::ui::close $key }
      no      { ase::ui::close $key }
      default { return 0 }
    }
  }
  return 1
}

# --- window construction -----------------------------------------------------

proc ase::ui::build {key top} {
  ase::theme   ;# fonts + styles must exist before any widget is themed

  # menubar — the v2 menu tree VERBATIM (spec "Menu tree (v2)"), cascades in
  # order: Launch Session Setup Analyses Variables Outputs Simulation Results
  # Tools
  menu $top.mb -tearoff 0
  $top configure -menu $top.mb

  # Launch: placeholder (spec: "ignore for now"). The menubar entry is
  # disabled so the empty placeholder menu can never post.
  menu $top.mb.launch -tearoff 0
  $top.mb.launch add command -label {(placeholder)} -state disabled
  $top.mb add cascade -label Launch -menu $top.mb.launch -state disabled

  menu $top.mb.session -tearoff 0
  $top.mb add cascade -label Session -menu $top.mb.session
  $top.mb.session add command -label {Design Window} \
    -command [list ase::ui::design_window $key]
  # Load State = the state-view library browser (content import); Save State
  # = the always-Save-As form (menu LABELS are v2-spec-fixed, W1m asserts
  # them)
  $top.mb.session add command -label {Load State} \
    -command [list ase::ui::load_state_dialog $key]
  $top.mb.session add command -label {Save State} \
    -command [list ase::ui::save_state_dialog $key]
  $top.mb.session add separator
  $top.mb.session add command -label Close \
    -command [list ase::ui::close_request $key]

  menu $top.mb.setup -tearoff 0
  $top.mb add cascade -label Setup -menu $top.mb.setup
  $top.mb.setup add command -label "Design\u2026" \
    -command [list ase::ui::design_dialog $key]
  $top.mb.setup add command -label "Model Files\u2026" \
    -command [list ase::ui::model_files_dialog $key]
  # Simulators… = the registry issue 0931 shipped with no door at all (issue
  # 0937). Setup, not Simulation: this is configuration that outlives a run,
  # and it is where the other configuration dialogs already live. The menu
  # LABEL is v2-spec-fixed the way the Session ones are (doc/claude/specs/
  # ase_l.md, and W1m/S16 assert it). NO LOG CALL BELONGS HERE OR IN THE
  # DIALOG: the 0930 interceptor logs this pick by construction, from the
  # entry's own -command, and a second call would double every line.
  $top.mb.setup add command -label "Simulators\u2026" \
    -command [list ase::ui::simulators_dialog $key]

  menu $top.mb.analyses -tearoff 0
  $top.mb add cascade -label [ase::ui::lbl_analyses] -menu $top.mb.analyses
  # ⚠ LABELS FROM THE CONSTANTS, NOT TYPED HERE (issue 1391). The `OP,TR`
  # strip button's tooltip is `ase::ui::menu_path_choose_analyses`, composed
  # from these two; typing either string twice is how the 0661 drift happened.
  $top.mb.analyses add command -label [ase::ui::lbl_choose] \
    -command [list ase::ui::choose_analyses $key]

  menu $top.mb.variables -tearoff 0
  $top.mb add cascade -label Variables -menu $top.mb.variables
  # Variables > Edit...: the per-row variable editor on the first selected
  # variables row, or the Add Variable dialog when nothing is selected (the
  # minimal honest reading of the spec's "variables editor" within item 06)
  $top.mb.variables add command -label "Edit\u2026" \
    -command [list ase::ui::edit_variables $key]

  menu $top.mb.outputs -tearoff 0
  $top.mb add cascade -label [ase::ui::lbl_outputs] -menu $top.mb.outputs
  menu $top.mb.outputs.saved -tearoff 0
  # Select On Design (item 08): click mode on the design schematic — wire /
  # net-label clicks queue v(<net>), source clicks queue i(<inst>); the To Be
  # Saved flavor queues {save 1 plot 0}, To Be Plotted {save 1 plot 1}
  $top.mb.outputs.saved add command -label {Select On Design} \
    -command [list ase::ui::select_on_design $key {save 1 plot 0}]
  $top.mb.outputs add cascade -label {To Be Saved} -menu $top.mb.outputs.saved
  menu $top.mb.outputs.plotted -tearoff 0
  $top.mb.outputs.plotted add command -label {Select On Design} \
    -command [list ase::ui::select_on_design $key {save 1 plot 1}]
  $top.mb.outputs add cascade -label {To Be Plotted} \
    -menu $top.mb.outputs.plotted
  $top.mb.outputs add command -label [ase::ui::lbl_save_all] \
    -command [list ase::ui::save_all_dialog $key]

  menu $top.mb.sim -tearoff 0
  $top.mb add cascade -label [ase::ui::lbl_simulation] -menu $top.mb.sim
  menu $top.mb.sim.netlist -tearoff 0
  # ⚠ THESE TWO LABELS ARE READ BY MORE THAN THIS MENU (issue 1435, the same
  # rule the three below already carry). The precondition banner under the
  # Choose Analyses form names this entry as the door to a netlist, and it
  # composes the path from these constants -- so a rename here follows.
  $top.mb.sim.netlist add command -label [ase::ui::lbl_netlist_recreate] \
    -command [list ase::ui::do_netlist_recreate $key]
  $top.mb.sim.netlist add command -label Display \
    -command [list ase::ui::view_netlist $key]
  $top.mb.sim add cascade -label [ase::ui::lbl_netlist] -menu $top.mb.sim.netlist
  # ⚠ THESE THREE LABELS ARE READ BY MORE THAN THIS MENU (issue 1391). The
  # `N&>` / `>` / `!` strip buttons tip from the composed paths, and issue
  # 1389's second-launch refusal names `[ase::ui::menu_path_stop]` as the way
  # out. Rename an entry here and the tip and the refusal follow it.
  $top.mb.sim add command -label [ase::ui::lbl_netlist_and_run] \
    -command [list ase::ui::do_run $key]
  $top.mb.sim add command -label [ase::ui::lbl_run] \
    -command [list ase::ui::do_run_existing $key]
  $top.mb.sim add command -label [ase::ui::lbl_stop] \
    -command [list ase::ui::do_stop $key]
  $top.mb.sim add command -label Log -command [list ase::ui::show_log $key]
  $top.mb.sim add command -label "Options\u2026" \
    -command [list ase::ui::sim_options_dialog $key]

  # Results: Direct Plot is LIVE (item 13) — the Select-On-Design click mode
  # in the `plot` flavor: clicks queue traces, ESC opens/raises the session's
  # waveform viewer with a new stacked graph.
  #
  # ⚠ ANNOTATE IS LIVE SINCE ISSUE 0682, AND IT IS NOW THE ONLY ANNOTATION
  # VISIBILITY CONTROL IN THE PROGRAM. Both entries were `add command ...
  # -state disabled` placeholders for as long as this menu has existed (the
  # ase_l spec: "(DEFERRED) ... Menu entries may exist disabled"), and probed
  # they were deader than that -- `-command` was an EMPTY string and nothing
  # anywhere called entryconfigure on them. Driving the shipped feature on a
  # real sky130 bench the user ruled, verbatim: "What is View > Show? We want
  # to be like Cadence. It needs to ONLY be in ASE-L > Results > Annotate >
  # Operating Point Info", and "results (including OP info) only make sense
  # when there is a result loaded - meaning an ASE-L is active, to which this
  # schematic is 'bound'". That REVERSES issue 0457(b) (the same user, two days
  # earlier, put the pair in the schematic's `View > Show / Hide`); 0457(b)
  # answered the question it was asked, so this is a change of destination and
  # not a repair. The View pair is deleted in the same change.
  #
  # CHECKBUTTON, not command (decision D1): the two bits are booleans
  # (xschem.h:431), text_hidden() gates them independently (actions.c:1437-1439)
  # and all four mask states are coherent and reachable. `add command` cannot
  # display state, and state is the entire content of a visibility control.
  #
  # BUILT DISABLED on purpose. Nothing is live until the predicate
  # (ase::has_results) has been asked, and the -postcommand always runs before
  # the submenu can be used, so this costs the user nothing while making it
  # impossible for a click to reach the mask before anyone asked whether
  # results exist.
  #
  # THE LABELS ARE THE USER'S OWN TWO STRINGS (decision D9) and Cadence's:
  # `Operating Point info` / `DC Node Voltages`. Consequence, recorded rather
  # than hidden: the deleted View pair's labels PARTITIONED the two content
  # classes (issue 0678 -- bit0 covers device OP info AND branch currents),
  # and these do not. That partition property has no successor here.
  menu $top.mb.results -tearoff 0
  $top.mb add cascade -label Results -menu $top.mb.results
  # RESULTS BATCH item 7 (R401): `Select\u2026` is the door onto
  # `results::select` -- ABOVE Direct Plot, because choosing WHICH result you
  # are working against precedes plotting from it, and separated because it
  # acts on the session's result binding while everything below it acts on the
  # result already bound. The menu had no separator before this entry.
  #
  # ⚠ HAND-BUILT, AND NO actions.csv ROW IS NEEDED. ASE-L's menubar is plain Tk
  # (only the main File menu is generated from the action table, via
  # build_menu_from_table in xschem.tcl); a KEY CHORD would need a csv row AND
  # an action_registry[] entry in callback.c, and spec section 16 / D8 give v1
  # no chord.
  #
  # ⚠ ASE-L ONLY (user ruling U5) and NO CASCADE IS ADDED TO THE WAVEFORM
  # VIEWER'S MENUBAR (R504/D12) -- tests/headless/test_wave_viewer.tcl G2
  # freezes that cascade set at {File View Graph Cursors Options}.
  $top.mb.results add command -label "Select\u2026" \
    -command [list ase::ui::rsel_dialog $key]
  $top.mb.results add separator
  $top.mb.results add command -label {Direct Plot} \
    -command [list ase::ui::direct_plot $key]
  menu $top.mb.results.annotate -tearoff 0 \
    -postcommand [list ase::ui::annot_menu_sync $key]
  $top.mb.results.annotate add checkbutton -label {Operating Point info} \
    -variable ::ase::ui::annot($key,op) -state disabled \
    -command [list ase::ui::annot_apply $key op]
  $top.mb.results.annotate add checkbutton -label {DC Node Voltages} \
    -variable ::ase::ui::annot($key,volt) -state disabled \
    -command [list ase::ui::annot_apply $key volt]
  # ISSUE 0868 -- THE THIRD ENTRY, and the user asked for it by name: "We can add
  # a menu item in Results > Annotate for annotating TRAN node voltages for
  # time-point given by cursor B, or A - whatever the convention is".
  #
  # THE LABEL NAMES ITS TIME SOURCE, and that is a decision rather than a
  # phrasing. The two entries above name a CONTENT class; a transient has no
  # single meaningful time, so a bare `Transient Node Voltages` would leave the
  # user asking "at when?". Rejected: that bare form, and `Annotate at Cursor`
  # (which says nothing about what). Unratified -- see doc/claude/issues/0868-*.md.
  #
  # CHECKBUTTON and BUILT DISABLED for exactly the reasons the pair above are:
  # it is a third independently clearable bit of one mask (ANNOT_SHOW_TRAN,
  # xschem.h), and nothing in this menu may be clickable before
  # `ase::has_results` has been asked.
  # ⚠ AND THE BODY IS MADE REACHABLE HERE, WHERE THE ENTRY IS BUILT. The mode
  # lives in utils/annot_mode.tcl, which only the CADENCE profile's rc sources,
  # while this menu belongs to every ASE-L user -- so building the entry without
  # the body would ship a control that greys correctly and does nothing. The
  # helper never clobbers an existing definition and never sources a file that
  # is not there (it `file isfile`s each candidate first), so a session that
  # already loaded the profile, and an installation that ships no utils/, are
  # both no-ops rather than errors. Deliberately NOT a `source` line in
  # src/xschem.tcl: utils/ is not in the install list, and a shipped xschem.tcl
  # sourcing a file it did not install is the startup segfault CLAUDE.md records
  # as issues 0423/0424.
  catch {ase::ui::annot_tran_helper}
  $top.mb.results.annotate add checkbutton -label {Transient Node Voltages (at cursor)} \
    -variable ::ase::ui::annot($key,tran) -state disabled \
    -command [list ase::ui::annot_apply $key tran]
  $top.mb.results add cascade -label Annotate -menu $top.mb.results.annotate

  # Tools: Waveform Viewer raises-or-opens THE waveform viewer of THIS session
  # — wviewer::open is per-token idempotent (re-open arm raises the existing
  # toplevel), so a session never gets a second viewer window; same seam the
  # `~` strip button and Direct Plot use.
  #
  # Calculator is LIVE (calculator batch item 13). It was a named placeholder
  # (`-state disabled`, added in 63e10b87) for the same reason the Annotate
  # entries still are — the window did not exist. It does now: phase 0 shipped
  # `.calc` and phase 1 filled every pane, and the schematic editor's Tools menu
  # (xschem.tcl:15143) and the viewer's View menu (wave_viewer.tcl:17599) were
  # both wired to `calc::open` at the time. This one was missed, so the tool the
  # user actually works in was the one place the Calculator stayed greyed out.
  #
  # ⚠ NO `$key`, and that is not an oversight. Every other live entry in this
  # menu is `[list ase::ui::<proc> $key]` because it acts on THIS session;
  # `calc::open` is per-PROCESS idempotent (spec R101: one Calculator, not one
  # per invocation), exactly like the viewer's own View-menu entry. Passing a
  # session key would be a promise of a per-session Calculator that R101
  # forbids. Which raw the window reports is answered live at open time
  # (calc::results_source), not by whoever opened it.
  menu $top.mb.tools -tearoff 0
  $top.mb add cascade -label [ase::ui::lbl_tools] -menu $top.mb.tools
  $top.mb.tools add command -label [ase::ui::lbl_waveform_viewer] \
    -command [list ase::ui::open_viewer $key]
  $top.mb.tools add command -label Calculator -command calc::open

  # toolbar row under the menubar: the simulation-temperature entry (state
  # key `temperature`, commit-validated numeric -> `.temp <T>` in the deck)
  frame $top.tb
  entry $top.tb.temp -width 7
  # ⚠ THE TIP IS ARMED BEFORE THE TWO BINDS, AND THE FocusOut BIND IS `+`
  # (issue 1391). `balloon` (xschem.tcl:14826) does a PLAIN `bind` on <Enter>,
  # <Leave> and <FocusOut>, so whichever of the two is written second wins the
  # FocusOut slot outright. MEASURED on :99 before this was written: arming the
  # tip after the bind left
  #     <FocusOut> = after cancel balloon_show %W {...} 1; destroy %W.balloon
  # and `ase::ui::temp_commit` was simply gone -- a temperature typed and then
  # clicked away from would never reach the deck, with nothing said. So the
  # balloon goes first and the commit APPENDS. Order here is load-bearing;
  # W1s3 reads the composed script back off the live widget and reds if either
  # half is missing.
  #
  # This entry is the only widget in the window carrying no word of its own --
  # the `°C` label beside it gives the unit, not the subject.
  catch {::balloon $top.tb.temp [ase::ui::lbl_sim_temperature] 1 0 300}
  bind $top.tb.temp <Return>   [list ase::ui::temp_commit $key]
  bind $top.tb.temp <FocusOut> +[list ase::ui::temp_commit $key]
  label $top.tb.degc -text "\u00b0C"
  pack $top.tb.temp -side left -padx {6 2} -pady 2
  pack $top.tb.degc -side left
  pack $top.tb -side top -fill x

  # bottom status bar, packed BEFORE the expanding center (LibMgr lesson: an
  # expanding widget packed first claims the cavity and clips the bars off):
  # `<win#> | Status: <S> | T=<T> C | Simulator: <sim> | State: <view>`.
  # One label per segment, deterministic names; only .stat is colored.
  variable wnum
  frame $top.status
  label $top.status.win   -text [dict get $wnum $key]
  label $top.status.sep1  -text { | }
  label $top.status.stat  -text {Status: Ready}
  label $top.status.sep2  -text { | }
  label $top.status.temp  -text {}
  label $top.status.sep3  -text { | }
  label $top.status.sim   -text {}
  label $top.status.sep4  -text { | }
  label $top.status.state -text {}
  pack $top.status.win $top.status.sep1 $top.status.stat $top.status.sep2 \
       $top.status.temp $top.status.sep3 $top.status.sim $top.status.sep4 \
       $top.status.state -side left
  pack $top.status -side bottom -fill x -pady 2

  # right vertical action strip (spec "Action strip"): text placeholders,
  # top-down in spec order; ~ (Plot waveforms, live since item 13) raises or
  # opens the session's waveform viewer, no traces added.
  # Packed AFTER the toolbar + status bar and BEFORE the expanding body (the
  # item-05 packing lesson: the expanding widget must be packed last).
  frame $top.strip
  button $top.strip.ana -text {OP,TR} -width 5 \
    -command [list ase::ui::choose_analyses $key]
  button $top.strip.var -text = -width 5 \
    -command [list ase::ui::add_variable_dialog $key]
  # --> = the v1 "Setup Outputs" dialog (the Add Output editor: optional
  # name + expression + Plot/Save); choose-from-design is item 08
  button $top.strip.out -text --> -width 5 \
    -command [list ase::ui::output_editor $key -1]
  button $top.strip.del -text X -width 5 \
    -command [list ase::ui::delete_selection $key]
  button $top.strip.netrun -text {N&>} -width 5 \
    -command [list ase::ui::do_run $key]
  button $top.strip.run -text > -width 5 \
    -command [list ase::ui::do_run_existing $key]
  button $top.strip.stop -text ! -width 5 \
    -command [list ase::ui::do_stop $key]
  button $top.strip.plot -text ~ -width 5 \
    -command [list ase::ui::open_viewer $key]
  pack $top.strip.ana $top.strip.var $top.strip.out $top.strip.del \
       $top.strip.netrun $top.strip.run $top.strip.stop $top.strip.plot \
       -side top -padx 2 -pady 1
  pack $top.strip -side right -fill y

  # --- 1391: EVERY STRIP BUTTON GETS A TIP, FROM ONE TABLE --------------------
  # Eight glyphs and not one word between them; `N&>` and `~` are not guessable
  # and never were. The strings come from `ase::ui::strip_tips` (~:5477) so the
  # FIVE with a menubar twin tip with the twin's own label, composed. Five,
  # not four: `OP,TR` is `Analyses > Choose…` and is twinned like the rest.
  #
  # ⚠ ONE LOOP, NOT EIGHT CALLS. The suite asserts that EVERY child of
  # $top.strip carries a tip, so a ninth button added without a `strip_tips`
  # entry reds W1s2 rather than shipping bare -- which a hand-written list of
  # eight calls could not do.
  #
  # ⚠ `catch`, like rdw.tcl:3226: `balloon` is pure Tk and the headless suites
  # drive these procs with no display at all.
  # ⚠ 300 ms, matching rdw.tcl:3226 rather than the 1000 ms default the rest of
  # the tree takes. That figure is the user's "as soon as user hovers over it"
  # and is still UNRATIFIED -- rule debt 1368; this inherits it rather than
  # opening a second question.
  # ⚠ INSTANCE <Enter> ONLY. MEASURED on :99: `bind Button <Enter>` is still
  # `tk::ButtonEnter %W` after the call, so the buttons keep their hover
  # highlight -- a class binding is not what `balloon` replaces.
  foreach {sfx tip} [ase::ui::strip_tips] {
    catch {::balloon $top.strip.$sfx $tip 1 0 300}
  }

  # UI v2 body: EXACTLY three panes (spec "Panes") — Design Variables (left,
  # full height), Analyses (right top), Outputs (right bottom); each a
  # ttk::treeview column table (pure view — no inline editing, no +/-)
  frame $top.body
  labelframe $top.body.vars -text {Design Variables}
  labelframe $top.body.ana  -text {Analyses}
  labelframe $top.body.outs -text {Outputs}
  grid $top.body.vars -row 0 -column 0 -rowspan 2 -sticky nsew -padx 2 -pady 2
  grid $top.body.ana  -row 0 -column 1 -sticky nsew -padx 2 -pady 2
  grid $top.body.outs -row 1 -column 1 -sticky nsew -padx 2 -pady 2
  grid columnconfigure $top.body 0 -weight 1
  grid columnconfigure $top.body 1 -weight 2
  grid rowconfigure $top.body 0 -weight 1
  grid rowconfigure $top.body 1 -weight 1
  # COLUMN POLICY (issue 1398), one `{glyphs stretch anchor}` triple per column
  # instead of the pixel constant that used to sit here. The width is that many
  # `0`s of the DATA font, floored at the column's own heading ink in the
  # HEADING font — see ase::ui::colw, which also records why this cannot ship
  # without the derived fonts above it.
  #
  # ⚠ EXACTLY ONE STRETCHY COLUMN PER TABLE, and it is the content column.
  # ttk hands slack out in ABSOLUTE PIXELS across every -stretch 1 column and
  # clamps on the way down at -minwidth, but never gives the clamped pixels
  # back on the way up — so the old all-stretch tables RATCHETED. Measured on
  # the shipped code, four drag cycles at 798 px moved `#` from 32 px to 60 px
  # permanently, bled `Type` 63 -> 59, and took `Save Options` from 90 to 87,
  # i.e. that heading clipped for the rest of the session after ONE drag.
  #
  # ⚠ -anchor center on the three flag columns. `Enable` was 63 px of column
  # for a 16 px glyph pinned to the left edge; centring it is what makes
  # Stage 5's checkbox hit-band a band and not a guess.
  ase::ui::build_pane $key $top vars {name value} {Name Value} \
    {name {14 0 w} value {13 1 w}}
  ase::ui::build_pane $key $top ana {num type enable args} \
    [list # Type Enable Arguments] \
    {num {3 0 e} type {6 0 w} enable {3 0 center} args {28 1 w}}
  ase::ui::build_pane $key $top outs {name value plot save saveopts} \
    [list Name Value Plot Save {Save Options}] \
    [list name {12 0 w} value {11 1 w} plot {3 0 center} save {3 0 center} \
          saveopts {10 0 w}]
  pack $top.body -side top -fill both -expand 1

  ase::ui::apply_theme $top
  # captured AFTER theming so "idle" restores the themed panel color
  variable idlebg
  set idlebg($key) [$top.status.stat cget -background]
}

# One themed treeview pane: columns + headings, vertical scrollbar, the
# selection/checkbox/double-click bindings and the Add/Edit/Delete context
# menu. Item ids are the row's 0-based index into the pane's state list
# (repopulate after every mutation keeps them dense), so identify/selection
# results address the state directly.
# A column's width: `n` glyphs of the DATA font, never below its own heading's
# ink in the HEADING font. This is what stops `Enable` rendering `Enabl` and
# `Save Options` rendering `Save Option`. Called with n == 0 it answers the
# heading floor alone, which is the column's -minwidth. Issue 1398.
#
# ⚠ THIS IS WHY THE COLUMN POLICY CANNOT SHIP WITHOUT THE DERIVED FONTS, and
# vice versa. Pixel constants against POINT font sizes break at every
# `tk scaling`: measured live on the shipped code at scaling 2.0, `Enable`
# needed 65 px in a 63 px column, `Save` 46 in 50 and `Save Options` 128 in 90
# — 72 after four resize cycles. And the derived bold is WIDER than the
# substituted one, so the font change ALONE would have made `Save Options` clip
# worse than it already did in its 90 px column.
#
# The +16 is ttk's own heading padding, both sides, on the `default` theme.
# With no display (`--nogui`) there is no `font` command at all, so the glyph
# falls back to a plain number and the pane still builds.
proc ase::ui::colw {n head} {
  set g 0
  set h 0
  catch {set g [font measure AseEntryFont 0]}
  catch {set h [font measure AseLabelFont $head]}
  if {$g < 1} { set g 9 }
  set w [expr {$n * $g}]
  set h [expr {$h + 16}]
  return [expr {$w > $h ? $w : $h}]
}

# Show the horizontal scrollbar only while there is something off-screen.
#
# ⚠ THIS EXISTS BECAUSE ISSUE 1398's COLUMN POLICY CAN OVERFLOW THE PANE.
# The shipped code gave every column -stretch 1, so a narrow window shrank them
# all and clipped the text in place — ugly, but every column stayed reachable.
# Deriving the widths and pinning the narrow ones (-stretch 0) fixes the resize
# ratchet and trades it for a real overflow: measured 2026-09-09, the Outputs
# pane's `Save Options` column leaves the viewport below 740 px of window width
# and at 560x360 thirty per cent of the pane is off-screen with no way to reach
# it. A horizontal bar is the reach. It also closes a defect that pre-dates this
# batch — build_pane never had one, so clipped content was simply gone.
#
# The `need != shown` guard is load-bearing, not tidiness: mapping a scrollbar
# changes the treeview's width, which fires -xscrollcommand again. Acting only
# on a CHANGE of state ends the cascade after one step.
proc ase::ui::pane_hscroll {pf first last} {
  catch {$pf.hsb set $first $last}
  if {![winfo exists $pf.hsb]} { return }
  set need  [expr {$first > 0.0 || $last < 1.0}]
  set shown [expr {[lsearch -exact [grid slaves $pf] $pf.hsb] >= 0}]
  if {$need && !$shown}  { catch {grid $pf.hsb} }
  if {!$need && $shown}  { catch {grid remove $pf.hsb} }
}

# Re-derive every pane's column widths when — and ONLY when — the data font's
# size has actually moved under them.
#
# ⚠ THE LIVE ::ase_font_size PATH RESCALED THE FONTS AND LEFT THE COLUMNS.
# Measured 2026-09-09 through the real user gesture (open the window, set the
# knob, edit a variable so ase::ui::populate runs): AseEntryFont 10 -> 16,
# rowheight 21 -> 31, and SIX OF ELEVEN HEADINGS CLIPPED, because -width and
# -minwidth were both still the ink of a 10 pt face. The floor that is supposed
# to stop `Enable` rendering `Enabl` was itself stale.
#
# ⚠ AND ONLY ON A CHANGE. apply_theme runs on every state mutation, so
# re-applying widths unconditionally would silently undo a column the user had
# dragged, on every checkbox click. The guard is the font size the widths were
# last derived AT, per window.
proc ase::ui::retune_columns {top} {
  variable colpolicy
  variable colfont
  set sz 0
  catch {set sz [font actual AseEntryFont -size]}
  catch {set sz [list $sz [font measure AseLabelFont 0]]}
  if {[info exists colfont($top)] && $colfont($top) eq $sz} { return }
  set colfont($top) $sz
  foreach pane {vars ana outs} {
    set tv $top.body.$pane.tv
    if {![winfo exists $tv] || ![info exists colpolicy($tv)]} { continue }
    lassign $colpolicy($tv) columns headings policy
    foreach c $columns h $headings {
      lassign [dict get $policy $c] glyphs stretch anchor
      catch {$tv column $c -width [ase::ui::colw $glyphs $h] \
                           -minwidth [ase::ui::colw 0 $h]}
    }
  }
}

proc ase::ui::build_pane {key top pane columns headings policy} {
  variable colpolicy
  set pf $top.body.$pane
  ttk::treeview $pf.tv -columns $columns -show headings \
    -selectmode extended -height 8 -style Ase.Treeview \
    -yscrollcommand [list $pf.sb set]
  foreach c $columns h $headings {
    lassign [dict get $policy $c] glyphs stretch anchor
    $pf.tv heading $c -text $h
    # -minwidth is the heading's own ink: the column can be dragged narrow but
    # never narrower than the word that names it. The shipped code declared no
    # -minwidth at all and took ttk's 20 px default.
    $pf.tv column $c -width [ase::ui::colw $glyphs $h] \
                     -minwidth [ase::ui::colw 0 $h] \
                     -anchor $anchor -stretch $stretch
  }
  # kept so ase::ui::retune_columns can re-derive these when the knob moves
  set colpolicy($pf.tv) [list $columns $headings $policy]
  scrollbar $pf.sb  -orient vertical   -command [list $pf.tv yview]
  scrollbar $pf.hsb -orient horizontal -command [list $pf.tv xview]
  $pf.tv configure -xscrollcommand [list ase::ui::pane_hscroll $pf]
  # ⚠ GRID, NOT PACK, AND THE REASON IS THE HORIZONTAL BAR. `grid remove`
  # remembers the cell, so the bar can appear and vanish without re-deriving a
  # layout; the pack equivalent has to re-pack inside an -xscrollcommand
  # callback, which is a geometry feedback loop. The three widget PATHS are
  # unchanged ($pf.tv, $pf.sb, and the new $pf.hsb), which is what the suites
  # address.
  grid $pf.tv  -row 0 -column 0 -sticky nsew
  grid $pf.sb  -row 0 -column 1 -sticky ns
  grid $pf.hsb -row 1 -column 0 -sticky ew
  grid remove $pf.hsb
  grid rowconfigure    $pf 0 -weight 1
  grid columnconfigure $pf 0 -weight 1
  # multi-select within ONE pane: selecting here clears the other panes
  bind $pf.tv <<TreeviewSelect>> [list ase::ui::pane_selected $key $pane]
  # checkbox cells: a click on an Enable/Plot/Save cell flips the flag and
  # consumes the event (break skips the class binding's selection change)
  bind $pf.tv <Button-1> \
    "if {\[[list ase::ui::pane_click $key $pane] %x %y\]} break"
  # double-click a row -> its edit dialog (binding <Double-1> is legal; only
  # event GENERATE of <Double-1> is refused — tests replay two click pairs)
  bind $pf.tv <Double-1> [list ase::ui::pane_dblclick $key $pane %x %y]
  # context menu: exactly Add... / Edit... / Delete (checkable without posting)
  menu $pf.ctx -tearoff 0
  switch -- $pane {
    vars {
      $pf.ctx add command -label "Add\u2026" \
        -command [list ase::ui::add_variable_dialog $key]
      $pf.ctx add command -label "Edit\u2026" \
        -command [list ase::ui::edit_variable_first $key]
    }
    ana {
      $pf.ctx add command -label "Add\u2026" \
        -command [list ase::ui::choose_analyses $key]
      $pf.ctx add command -label "Edit\u2026" \
        -command [list ase::ui::edit_analysis_first $key]
    }
    outs {
      $pf.ctx add command -label "Add\u2026" \
        -command [list ase::ui::output_editor $key -1]
      $pf.ctx add command -label "Edit\u2026" \
        -command [list ase::ui::edit_output_first $key]
    }
  }
  $pf.ctx add command -label Delete \
    -command [list ase::ui::delete_selection $key]
  bind $pf.tv <Button-3> [list ase::ui::pane_ctx_post $key $pane %X %Y]
}

# --- pane interaction (UI v2) ------------------------------------------------

# <<TreeviewSelect>> handler: enforce single-pane selection by clearing the
# OTHER two panes. selclear suppresses the handler while the clears re-fire
# it (libmgr::suppress_select idiom); the non-empty test keeps a clear from
# cascading.
proc ase::ui::pane_selected {key pane} {
  variable wins; variable selclear
  if {[info exists selclear($key)] && $selclear($key)} { return }
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  set tv $top.body.$pane.tv
  if {![winfo exists $tv] || [$tv selection] eq {}} { return }
  set selclear($key) 1
  foreach p {vars ana outs} {
    if {$p eq $pane} { continue }
    set o $top.body.$p.tv
    if {[winfo exists $o] && [$o selection] ne {}} { $o selection set {} }
  }
  set selclear($key) 0
}

# <Button-1> on a pane: a click landing on a checkbox cell (analyses Enable,
# outputs Plot/Save) flips that flag in the row's state dict and returns 1
# (the bind script then breaks so the selection is untouched); any other
# click returns 0 and falls through to normal selection handling.
proc ase::ui::pane_click {key pane x y} {
  variable wins
  if {![dict exists $wins $key]} { return 0 }
  set tv [dict get $wins $key].body.$pane.tv
  if {![winfo exists $tv]} { return 0 }
  set item [$tv identify row $x $y]
  set col  [$tv identify column $x $y]
  if {$item eq {} || $col eq {}} { return 0 }
  set cname [lindex [$tv cget -columns] [expr {[string range $col 1 end] - 1}]]
  if {$pane eq {ana} && $cname eq {enable}} {
    ase::ui::toggle_flag $key analyses $item enabled
    return 1
  }
  if {$pane eq {outs} && ($cname eq {plot} || $cname eq {save})} {
    ase::ui::toggle_flag $key outputs $item $cname
    return 1
  }
  return 0
}

# Flip a 0/1 flag of row `idx` in the state list `skey`, preserving every
# other per-row key, then commit + repopulate.
proc ase::ui::toggle_flag {key skey idx field} {
  set st [ase::session_state $key]
  set rows [ase::state_get $st $skey]
  if {![string is integer -strict $idx] || $idx < 0 || $idx >= [llength $rows]} {
    return
  }
  set row [lindex $rows $idx]
  set cur [expr {[ase::state_get $row $field 0] eq {1} ? 1 : 0}]
  dict set row $field [expr {1 - $cur}]
  lset rows $idx $row
  dict set st $skey $rows
  ase::session_update $key $st
  ase::ui::populate $key
}

# Double-click a row -> the per-item edit dialog (spec "Panes" interaction
# model). Analyses rows route to Choose Analyses preselected on that row's
# type.
proc ase::ui::pane_dblclick {key pane x y} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set tv [dict get $wins $key].body.$pane.tv
  if {![winfo exists $tv]} { return }
  set item [$tv identify row $x $y]
  if {$item eq {}} { return }
  switch -- $pane {
    vars { ase::ui::variable_editor $key $item }
    outs { ase::ui::output_editor $key $item }
    ana  {
      set rows [ase::state_get [ase::session_state $key] analyses]
      set type {}
      if {[string is integer -strict $item] && $item >= 0 \
          && $item < [llength $rows]} {
        set type [ase::state_get [lindex $rows $item] type]
      }
      ase::ui::choose_analyses $key $type
    }
  }
}

proc ase::ui::pane_ctx_post {key pane X Y} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set m [dict get $wins $key].body.$pane.ctx
  if {![winfo exists $m]} { return }
  tk_popup $m $X $Y
}

# Action-strip X (noun-verb): delete the current selection — scan the three
# panes for the one holding a selection (single-pane selection is enforced by
# pane_selected), remove those rows from its state list in descending index
# order, commit, repopulate. No confirm anywhere in this path.
proc ase::ui::delete_selection {key} {
  variable wins; variable panekeys
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  foreach pane {vars ana outs} {
    set tv $top.body.$pane.tv
    if {![winfo exists $tv]} { continue }
    set sel [$tv selection]
    if {$sel eq {}} { continue }
    set skey [dict get $panekeys $pane]
    set st [ase::session_state $key]
    set rows [ase::state_get $st $skey]
    foreach i [lsort -integer -decreasing $sel] {
      if {[string is integer -strict $i] && $i >= 0 && $i < [llength $rows]} {
        set rows [lreplace $rows $i $i]
      }
    }
    dict set st $skey $rows
    ase::session_update $key $st
    ase::ui::populate $key
    return
  }
  catch {::ase::echo "ase: nothing selected"}
}

# --- pure cell helpers (Tk-free — headless tests drive these directly) -------

# Outputs Name cell: the user-given name when present, else the expression —
# whole when <= 24 chars, else the first 21 chars + `...` (deterministic
# truncation; column autosizing is not deterministic across DPI).
proc ase::ui::output_display_name {row} {
  if {[dict exists $row name] && [dict get $row name] ne {}} {
    return [dict get $row name]
  }
  set e [ase::state_get $row expr]
  if {[string length $e] <= 24} { return $e }
  return "[string range $e 0 20]..."
}

# The results-dict key of an output row: name when present and non-empty,
# else expr (matches ase::backend::*::result_probe keying).
proc ase::ui::output_result_key {row} {
  if {[dict exists $row name] && [dict get $row name] ne {}} {
    return [dict get $row name]
  }
  return [ase::state_get $row expr]
}

# Classify an output expression: `v(` -> voltage, `i(` or `@` (ngspice
# terminal-current form) -> current, else other. Leading whitespace/`-`
# stripped, case-insensitive.
proc ase::ui::output_kind {ex} {
  set e [string trim $ex]
  set e [string trimleft $e -]
  set e [string trim $e]
  if {[string match -nocase {v(*} $e]} { return voltage }
  if {[string match -nocase {i(*} $e] || [string match {@*} $e]} {
    return current
  }
  return other
}

# Outputs Save Options auto-cell: `allv` for a voltage while blanket
# save-all-voltages is on, `alli` for a current while save-all-currents is
# on, blank otherwise (the blankets are state keys save_all_v/save_all_i;
# item 07's Save All dialog writes them, item 06 displays their effect).
proc ase::ui::save_options_cell {state row} {
  set kind [ase::ui::output_kind [ase::state_get $row expr]]
  if {$kind eq {voltage} && [ase::state_get $state save_all_v 0] eq {1}} {
    return allv
  }
  if {$kind eq {current} && [ase::state_get $state save_all_i 0] eq {1}} {
    return alli
  }
  return {}
}

# Analyses Arguments summary (view-only): THE LINE THE DECK WILL CARRY.
#
# ⚠ THIS IS ase::analysis_line, THE SAME PROC render_deck EMITS. A dc row reads
# `dc V2 0 1.8 0.01` where it used to read `source=V2 start=0 stop=1.8
# step=0.01`. That is the one thing Stage 1 deliberately changes on screen, and
# two rows assert it by value: test_ase_window P4 and test_ase_dialogs G2.
#
# ⚠ THE `key=value` DUMP SURVIVES AS THE FALLBACK, for a backend in force that
# declares no `analysis_types` hook -- there is no registry to spell its line
# from, and a blank Arguments column would be worse than an honest dump.
proc ase::ui::arg_summary {row {sim {}}} {
  if {$sim eq {}} { set sim [ase::default_simulator] }
  set type [ase::state_get $row type]
  ## ⚠ AN INCOMPLETE ROW HAS NO DECK LINE, AND ASKING FOR ONE RAISES.
  ## `ase::state_default` seeds `{type dc enabled 0}` with NO field keys at all,
  ## and ase::analysis_line resolves `@source` with `dict get` -- deliberately,
  ## because that is byte-for-byte the failure render_deck had before Stage 1 and
  ## a refactor may not change a failure mode. But this pane renders EVERY row,
  ## enabled or not, including the three empty seed rows every new bench opens
  ## with. MEASURED on the display arm when this was not caught: `key "source"
  ## not known in dictionary`, and test_ase_dialogs died at 0 of 215 checks.
  ## The dump below is the honest answer for a row that cannot yet be a line.
  ## ⚠ THE VERBATIM HATCH IS SHOWN AS A COUNT, NOT AS ITS CONTENTS. Issue 1419.
  ## The Arguments column is one line in a treeview; pasting three `.control`
  ## lines into it would push the analysis line -- the thing the column is FOR --
  ## off the right-hand edge. But it may not be silent either: a deck carrying
  ## lines the window never mentions is the second half of this batch's
  ## acceptance criterion failing, and it fails in the direction where the user
  ## runs something they cannot see.
  set vb {}
  set nvb [llength [ase::analysis_verbatim $row]]
  if {$nvb == 1} {
    set vb "  + verbatim: 1 line"
  } elseif {$nvb > 1} {
    set vb "  + verbatim: $nvb lines"
  }
  if {[ase::analysis_entry $sim $type] ne {}} {
    if {![catch {ase::analysis_line $sim $row} line] && $line ne {}} {
      return "$line$vb"
    }
    ## ⚠ NO DECK LINE: SAY WHY, DO NOT DUMP THE KEYS. Issue 1420, and it is the
    ## OTHER half of this batch's acceptance criterion. The fallback below lists
    ## `step=1n stop=10u` for a row that cannot render -- values the deck will
    ## NOT carry, shown in the column whose whole job is to say what the deck
    ## carries. It reads exactly like a setting that is in force. The honest
    ## answer to "what will this run?" for a row that cannot run is the reason
    ## it cannot, in the same words the commit door and the gate use.
    ##
    ## ⚠ ONLY FOR AN ENABLED ROW. A switched-off row makes no claim about a run,
    ## so it has nothing to be wrong about -- and every new bench opens with
    ## three empty disabled rows, which would otherwise each carry a complaint
    ## about a value nobody has been asked for yet.
    if {[ase::state_get $row enabled 0] eq {1}} {
      if {![catch {ase::analysis_emit_check $sim $row} _bad] && [llength $_bad]} {
        return [lindex [lindex $_bad 0] 2]
      }
    }
  }
  set order [ase::analysis_field_names $sim $type]
  set out {}
  foreach a $order {
    if {[dict exists $row $a]} { lappend out "$a=[dict get $row $a]" }
  }
  dict for {k v} $row {
    if {$k eq {type} || $k eq {enabled} || $k eq {x}} { continue }
    if {[lsearch -exact $order $k] >= 0} { continue }
    lappend out "$k=$v"
  }
  return "[join $out { }]$vb"
}

# Select On Design expression builder: kind `voltage` + a net name ->
# `v(<net>)`, kind `current` + an instance name -> `i(<inst>)`.
#
# CASE (casemode batch item 9; spec doc/claude/specs/simulator_profiles.md §13).
# The token is lowercased ONLY when the run's requested mode is `fold`. Under
# `preserve`/`distinguish` the schematic's own spelling is what goes into the
# deck, which is what those modes exist for; ngspice accepts the schematic case
# in `.save` in all three modes (PLAN §F2), while the FOLDED spelling is
# `rc=1, zero vectors, analysis not run` under `distinguish` — the whole
# session's data. `fold` is DECISIONS A1's default everywhere, so a stock user's
# expression is byte-identical to the one this proc shipped before item 9.
#
# `$mode` is a REQUIRED argument and deliberately has no default value. A
# defaulted mode is a silent fold, and the failure a silent fold causes under
# `distinguish` is the one above: nothing to see, no diagnostic, every trace
# gone. A missing argument is a Tcl error at the call site instead. Anything
# that is not `preserve`/`distinguish` folds — an unrecognised mode must not
# fall through to "emit verbatim".
#
# The mode is passed IN rather than looked up because this proc must stay pure
# (see below); ase::ui::sod_case_mode resolves it once per click at the impure
# call site.
#
# The sentence this replaced said the token must be lower case because
# result_probe matches `print`'s echo literally. §13.6 first said that mattered
# for exactly ONE combination — requested `preserve`, measured `fold` — and
# **item 11 measured that to be one combination too few** (spec §15.2, and
# §13.6 is corrected in place). This proc is the only fold in the whole file,
# so every expression that did NOT come through it keeps its typed case: the
# Add/Edit Output dialog (ase::ui::output_editor_ok) stores the string as
# typed, a hand-written state file stores what it says, and
# ase::expand_bus_outputs carries a row's spelling into every bit. A plain
# `fold` run therefore ships `v(In)` too and gets `v(in)` back.
# What item 11 owns is NOT a `-nocase` flag: it is a ladder in result_probe —
# exact spelling first, a case-insensitive pass second, and a D2 decline when
# that pass offers more than one differently-cased label — with the lenient
# rung switched off whenever the LOG says the run delivered `distinguish`,
# whatever it requested (§15.3–§15.4b).
#
# The leading `#` of an AUTO-NAMED net is stripped (issue 0154). An unlabeled
# net carries the engine's marker name `#netN` (get_unnamed_node, netlist.c) but
# the netlister emits it WITHOUT the marker (`V1 net1 GND 1`), so `v(#net1)`
# names nothing: `get_raw_index` misses it, `wviewer::validate_rpn` rejects it,
# and — the worst arm — a `.save v(#net1)` card makes ngspice abort the entire
# analysis ("no data saved for Transient analysis; analysis not run"), taking
# every other trace in the session with it. This mirrors send_net_to_graph()
# (hilight.c), the C path that sends highlighted nets to a graph: strip `#`,
# then lowercase.
#
# Deliberately a PURE string op and NOT `xschem resolved_net` (the C helper
# send_net_to_graph uses after the strip). Two reasons: this proc is called
# with no design loaded (test_ase_interact H1), and `xschem resolved_net` is
# contaminated on its first call after any netlist-struct invalidation — it
# resets the interp result BEFORE prepare_netlist_structs, so the first answer
# comes back as `0net1` (scheduler.c; the sibling `nets`/`net_members` verbs
# already carry the fix and its comment). At top level the two agree byte for
# byte. Descended, they do NOT — and that is `sod_qualify`'s job below, not this
# proc's: the token arrives here already hierarchy-qualified (issue 0161), so
# this stays the pure wrap H1 asserts.
proc ase::ui::sod_expr {kind token mode} {
  if {$kind eq {voltage}} { set token [string trimleft $token #] }
  if {$mode ne {preserve} && $mode ne {distinguish}} {
    set token [string tolower $token]
  }
  if {$kind eq {voltage}} { return "v($token)" }
  return "i($token)"
}

# The case mode this click's expressions must be written in: the session's
# REQUESTED run mode (the resolved simulator profile's `casemode`, else the
# global floor `sim_case_mode`, else `fold` — B1, spec §3), never a loaded raw's
# `case_sensitive` and never a file's resolved verdict. These strings are `.save`
# and `print` cards in a deck we are about to run, so the question is "what will
# this run be asked to do", which item 3 explicitly allows the floor to answer
# and item 8 already treats as a request.
#
# Resolved ONCE PER GESTURE at the call site (item 4's rule), not per bus bit and
# never from inside sod_expr, which must stay pure.
#
# AN UNKNOWN KEY IS NOT AN ERROR — it is the `{}` state, which resolves to the
# tool's own DEFAULT profile row, and that is the right answer for the scripted
# and stubbed picks every headless harness makes (`ase::session_state` cannot
# throw: its `sessions` dict is initialised at namespace-eval time, ase.tcl:68).
# A THROW from the resolver IS an error, and the fix round made it stop being
# silent: a blanket `catch` around the whole thing turned any resolver failure
# into a mute `fold`, which is exactly the silent-fold failure §13.2 made the
# `mode` argument required to prevent — a `distinguish` session emitting folded
# cards with no error, no CIW notice and no log line. So the catch is narrowed to
# the resolver call and it ECHOES before falling back (SC208c).
#
# It DELEGATES rather than re-validating, and that is deliberate. A first cut
# ended `if {$m ne {preserve} && $m ne {distinguish}} { return fold }` — a second
# copy of the validation ase::sim_casemode_requested already does (spec §3: a
# `set sim_case_mode sideways` in an rc cannot become a request). It survived
# every sabotage green, because the authority above it had already answered
# `fold`; worse, it MASKED a real one — with the copy in place, a mutation that
# bypassed the authority and read `$::sim_case_mode` raw still folded garbage, so
# SC206 could not see it. Deleted, SC206 covers both. `sod_expr` is the backstop
# for anything unrecognised that gets this far (SC192d).
#
# The `{}` line normalises an empty answer into a mode name so this proc's own
# return value is always one; it has no behavioural drive of its own, since
# sod_expr folds `{}` exactly as it folds `fold`.
#
# ⚠ THE `init 0` DANCE IS GONE, AND SO IS THE DEFECT IT GUARDED (the `annotate`
# merge). `fluid-editing` resolved the mode off a `sim()` profile row, and
# ase::sim_profile_resolve opened with `::set_sim_defaults` because `sim()` is
# built lazily — but `::set_sim_defaults` is NOT a read: with the Simulation
# Configuration dialog open it slurped every `.sim…r.$i.cmd` widget back into
# `sim($tool,$i,cmd)`. Reached from here it therefore COMMITTED the user's
# unsaved dialog edits on every Direct-Plot / Select-On-Design click and defeated
# that dialog's Cancel — measured, `USER-IS-STILL-TYPING` typed into the spice
# row-0 cmd box survived one pick AND the Cancel that followed. This proc's
# answer was to ask read-only and do the lazy build itself.
#
# The mode now comes from the ASE-L simulator registry, which is built eagerly
# and has no side effect to guard against: reading it is a read, so a pick can
# simply ask. SC208's claim (a pick makes no `set_sim_defaults` call) holds by
# construction rather than by care, which is the stronger form of the same
# property; SC208b's virgin-array build has nothing left to build; and
# test_ase_dialogs G13 still pins the dialog symptom itself, with real widgets.
proc ase::ui::sod_case_mode {key} {
  set m {}
  if {[catch {ase::sim_casemode_requested \
                [ase::state_get [ase::session_state $key] simulator ngspice]} m]} {
    catch {::ase::echo "ase: cannot resolve this session's requested case mode\
 ($m) — writing FOLDED expressions" error}
    return fold
  }
  if {$m eq {}} { return fold }
  return $m
}

# The simulator's name for a token picked at hierarchy depth (issue 0161).
# Identity at the top level, so every shipped top-level expression is unchanged
# byte for byte; only a descended pick moves.
#
# This is where the pick path becomes IMPURE, and that is deliberate: sod_expr
# is called with no design loaded (test_ase_interact H1) and must stay a string
# op, while a correct hierarchical name can only come from the engine. Measured
# on tests/headless/fixtures/ase_hier (xschem netlist -> ngspice-42 -b), the raw
# carries `x1.x2.mid` and `v.x1.x2.v1#branch`, and `.save v(x1.x2.mid)
# i(v.x1.x2.v1)` is accepted verbatim — which is exactly what the two arms
# below produce.
#
# VOLTAGE — `xschem resolved_net`, never a Tcl path-prefix. A path-prefix would
# be wrong four ways that the C already handles:
#   - a child PORT is not `x1.A`, it is the PARENT's net (`A` -> `TOPNET`);
#   - a port left dangling one level up stops there (`B` -> `x1.net1`, ONE
#     prefix level, not two);
#   - a global net is flat and never prefixed (`0` -> `0`);
#   - the `#` auto-name marker is stripped per bus element (issue 0158).
# Called per BIT, after sod_pick_tokens/bus_dialog (issue 0159) have split a bus,
# so the comma-list arm of resolved_net never fires here.
#
# CURRENT — no such resolver exists for instance names, so this mirrors
# send_current_to_graph() (hilight.c): the branch prefix + the sch_path + the
# name, and the bare `i(name)` at the top.
#
# THIS PROC TAKES NO MODE, and that is a ruling (casemode item 9, spec
# simulator_profiles.md §13.3): it answers in the SCHEMATIC's own spelling in
# every mode, and the whole simulator-side case mapping lives in sod_expr and
# nowhere else — the statement sod_net_at's comment already makes. Two folds used
# to leak out of sod_expr into here (the path, and the hard-coded lower-case
# prefix letter); both are gone, and under `fold` sod_expr folds the composed
# name to exactly the bytes this arm used to produce.
#
# THE BRANCH PREFIX FOLLOWS THE TOKEN. It is the device's own first character,
# not a literal `v.` and not a letter chosen by the mode. Item 4 MEASURED this on
# ver_50 with the device renamed (receipts/04-hilight-senders.md, spec
# raw_case_mode.md §11): a deck naming the source `Vs` gives `i(V.X1.Vs)` under
# preserve, one naming it `vs` gives `i(v.X1.vs)`, and both fold to `i(v.x1.vs)`.
# hilight.c's sender_current_prefix() is the C half of the same rule; if the two
# ever disagree about the spelling of one current, one of them is wrong.
#
# A1 SCOPE, corrected in the fix round — this is byte-for-byte the old literal
# `v.` for every token whose FIRST CHARACTER FOLDS TO `v`, which is every
# conformant vsource/ammeter name (`V1`, `Vmeas`), and NOT universally. A device
# the user renamed away from v/V moves under `fold` too, and it moves TOWARDS the
# simulator: MEASURED on ver_50 with a VCVS `E1` inside `X1` (a `type=vsource`
# cell — `vsource_pwl.sym` is templated `name=E1`, and nothing here validates the
# first letter), the raw carries `i(e.x1.e1)`; `.save i(e.x1.e1)` is accepted,
# while the old spelling `.save i(v.x1.e1)` produces "no data saved for Transient
# analysis; analysis not run" and a 570-byte empty raw — the whole run lost. So
# the old hard-coded `v.` was not "unchanged" for those devices, it was broken,
# and the derivation repairs it. SC211/SC211b pin both columns.
#
# Known limits, both inherited rather than introduced (see the issue doc):
# resolved_net measures its path from `sch_waves_loaded()`, so an expression
# queued while a raw is loaded BELOW the top is relative to that raw; and
# resolved_net resolves a net through a parent instance attribute only when the
# parent symbol declares that attribute in its `extra=` list (issue 0163), taking
# the symbol TEMPLATE default when the instance omits it (issue 0164).
#
# `baselvl` (issue 0168) is the hierarchy level the name is measured FROM: the
# level at which the SESSION's own design sits in this window's stack, since that
# design is the top of the deck the expression is written into. 0 (the default)
# is the shipped meaning, "the window's top", and every top-level session keeps
# its byte-for-byte behavior. It matters once a session is bound to an
# intermediate cell: descended two levels under a session on the MID cell, the
# node ngspice knows is `x2.mid`, not `x1.x2.mid`.
proc ase::ui::sod_qualify {kind token {baselvl 0}} {
  if {$token eq {}} { return $token }
  if {[catch {xschem get currsch} lvl]} { return $token }
  if {![string is integer -strict $baselvl] || $baselvl < 0} { set baselvl 0 }
  ## at (or above) the session's own level there is no path to add
  if {![string is integer -strict $lvl] || $lvl <= $baselvl} { return $token }
  if {$kind eq {voltage}} {
    if {[catch {xschem resolved_net $token $baselvl} rn] || $rn eq {}} { return $token }
    return $rn
  }
  set path [ase::ui::sod_rel_path $baselvl]
  if {$path eq {}} { return $token }
  return "[string index $token 0].$path$token"
}

# The instance path from hierarchy level `baselvl` down to the current level,
# `x2.` style — the current sch_path (`.x1.x2.`) with the base level's own
# sch_path (`.x1.`) stripped off the front. Plain prefix arithmetic is sound here
# and NOT for nets: an instance path is a pure prefix chain, while a net can
# resolve UP through a port and stop at any level (which is why the voltage arm
# above hands the level to the engine instead). Empty when the two agree or the
# prefix does not match.
proc ase::ui::sod_rel_path {baselvl} {
  set cur {}
  catch {set cur [xschem get sch_path]}
  if {$cur eq {}} { return {} }
  set base {}
  catch {set base [xschem get sch_path $baselvl]}
  if {$base eq {} || [string first $base $cur] != 0} {
    ## no usable base: fall back to the whole path, minus its leading dot
    return [string range $cur 1 end]
  }
  return [string range $cur [string length $base] end]
}

# Where the session's OWN design sits in this window's hierarchy stack (issue
# 0168) — the `baselvl` sod_qualify measures names from. 0 (the window's top)
# whenever the session's design is not in the stack at all, which keeps a
# scripted/stubbed pick (an unknown key, no design resolvable) on the shipped
# path. Recomputed per click rather than latched when the mode was armed, so
# descending or ascending WHILE the pick mode is up stays correct.
proc ase::ui::sod_base_level {key} {
  set dpath {}
  catch {set dpath [ase::ui::design_path $key]}
  if {$dpath eq {}} { return 0 }
  set lvl 0
  catch {set lvl [xschem get currsch]}
  if {![string is integer -strict $lvl] || $lvl <= 0} { return 0 }
  for {set l $lvl} {$l >= 0} {incr l -1} {
    set p {}
    catch {set p [xschem get schname $l]}
    if {$p ne {} && [file normalize $p] eq $dpath} { return $l }
  }
  return 0
}

# Split a possibly-bussed net token into its individual bits (issue 0159).
# `A[1:0]` -> {A[1] A[0]}, `D,E` -> {D E}, `A[1:0],B` -> {A[1] A[0] B}, and a
# scalar -> a one-element list. The `#` marker rides along per bit; sod_expr
# strips it later, which is where that mapping belongs.
#
# PURE, exactly like sod_expr, and for the same reason: `xschem expandlabel` is
# the bison label parser and needs no loaded design (verified), unlike
# `xschem resolved_net` which runs prepare_netlist_structs. test_ase_interact H1
# calls this family with nothing loaded.
#
# Why buses need splitting at all: sod_expr is a string wrap, so a bus picked
# whole became one invalid vector -- `v(a[1:0])` -- and src/ase.tcl interpolates
# the expr verbatim into `.save`/`print` cards. Measured with ngspice-42: that
# card ALONE aborts the entire analysis ("no data saved for Transient analysis;
# analysis not run"); alongside any other valid `.save` it is silently dropped
# and the trace just never appears.
proc ase::ui::sod_bits {token} {
  if {$token eq {}} { return {} }
  set r {}
  if {[catch {xschem expandlabel $token} r]} { return [list $token] }
  ## `xschem expandlabel` answers "<expanded> <mult>"; the expansion is a
  ## comma-separated list in MSB-first (declaration) order.
  set exp [lindex $r 0]
  if {$exp eq {}} { return [list $token] }
  return [split $exp ,]
}

# What one Select-On-Design click should queue: a list of tokens. A scalar (or
# any `current` pick, which is an instance name and can never be a bus) is
# itself; a multi-bit net opens the bit dialog and yields the user's chosen bits
# in the order the dialog displayed them, or {} for Cancel.
#
# This is the seam sod_click routes through, so a test can stub
# `ase::ui::bus_dialog` and assert the queue set without driving Tk (the same
# idiom the descend tests use to stub `ask_save`).
proc ase::ui::sod_pick_tokens {key kind token} {
  if {$kind ne {voltage}} { return [list $token] }
  set bits [ase::ui::sod_bits $token]
  if {[llength $bits] < 2} { return [list $token] }
  return [ase::ui::bus_dialog $key $token $bits]
}

# Build the bus bit-selection dialog and return its toplevel path. Split out of
# `bus_dialog` so the widgets can be driven directly by a test without a modal
# `tkwait` (the ask_save_close precedent keeps its widgets at deterministic
# paths for the same reason).
#
# Contract (user decision, issue 0159): nothing is selected when it opens --
# OK with an empty selection is therefore a no-op, same as Cancel. `All`
# selects every bit; Ctrl-click toggles individual bits (Tk `extended`
# selectmode gives that plus Shift-click ranges for free). `Reverse` flips the
# DISPLAYED order, carrying the selection with the items, because the display
# order IS the order the bits get queued in.
proc ase::ui::bus_dialog_build {parent token bits} {
  set w [expr {$parent eq {} ? {.asebusbits} : "$parent.busbits"}]
  catch {destroy $w}
  toplevel $w
  wm title $w {Select Bus Bits}
  catch {wm transient $w [expr {$parent eq {} ? {.} : $parent}]}
  label $w.msg -font AseLabelFont -justify left -anchor w \
    -text "Bus “$token” has [llength $bits] bits.\nSelect the bits to plot\
 (Ctrl-click toggles, Shift-click extends)."
  pack $w.msg -side top -fill x -padx 12 -pady {10 6}
  ## list + scrollbar share a frame so the toplevel itself stays pack-managed
  frame $w.lf
  set n [llength $bits]
  listbox $w.lf.list -selectmode extended -exportselection 0 -activestyle none \
    -height [expr {$n > 16 ? 16 : ($n < 2 ? 2 : $n)}] \
    -yscrollcommand [list $w.lf.sb set]
  scrollbar $w.lf.sb -orient vertical -command [list $w.lf.list yview]
  foreach b $bits { $w.lf.list insert end $b }
  pack $w.lf.sb -side right -fill y
  pack $w.lf.list -side left -fill both -expand yes
  pack $w.lf -side top -fill both -expand yes -padx 12 -pady 4
  frame $w.btns
  button $w.btns.all    -text All     -width 8 \
    -command [list ase::ui::bus_dialog_all $w]
  button $w.btns.rev    -text Reverse -width 8 \
    -command [list ase::ui::bus_dialog_reverse $w]
  button $w.btns.ok     -text OK      -width 8 \
    -command [list ase::ui::bus_dialog_done $w 1]
  button $w.btns.cancel -text Cancel  -width 8 \
    -command [list ase::ui::bus_dialog_done $w 0]
  pack $w.btns.all $w.btns.rev -side left -padx 5
  pack $w.btns.cancel $w.btns.ok -side right -padx 5
  pack $w.btns -side bottom -fill x -padx 8 -pady {4 10}
  bind $w <Return> [list $w.btns.ok invoke]
  ase::ui::bind_dialog_esc $w [list $w.btns.cancel invoke]  ;# ESC = Cancel
  catch {ase::ui::apply_theme $w}
  set ::ase::ui::bus_dialog_result {}
  return $w
}

# The selected bits in DISPLAY order. `curselection` returns indices ascending,
# which is display order by construction, so Reverse changing the display also
# changes the queue order -- the whole point of the button.
proc ase::ui::bus_dialog_selected {w} {
  set out {}
  if {![winfo exists $w.lf.list]} { return {} }
  foreach i [$w.lf.list curselection] { lappend out [$w.lf.list get $i] }
  return $out
}

proc ase::ui::bus_dialog_all {w} {
  if {[winfo exists $w.lf.list]} { $w.lf.list selection set 0 end }
}

# Flip the displayed order, re-selecting the same BITS (not the same indices) so
# a selection made before the flip survives it.
proc ase::ui::bus_dialog_reverse {w} {
  if {![winfo exists $w.lf.list]} { return }
  set lb $w.lf.list
  set sel [ase::ui::bus_dialog_selected $w]
  ## built by hand rather than with `lreverse`: the C side still declares Tcl
  ## 8.4 support (CLAUDE.md), and lreverse is 8.5+.
  set items {}
  foreach it [$lb get 0 end] { set items [linsert $items 0 $it] }
  $lb delete 0 end
  foreach it $items { $lb insert end $it }
  foreach it $sel {
    set i [lsearch -exact $items $it]
    if {$i >= 0} { $lb selection set $i }
  }
}

proc ase::ui::bus_dialog_done {w ok} {
  if {$ok} {
    set ::ase::ui::bus_dialog_result [ase::ui::bus_dialog_selected $w]
  } else {
    set ::ase::ui::bus_dialog_result {}
  }
  catch {destroy $w}
}

# Modal wrapper: show the dialog, block until dismissed, return the chosen bits
# (empty on Cancel). Same teardown-tolerance as ask_save_close -- the build-time
# `update` pumps the event loop, so a test or a compositor can destroy $w before
# tkwait is reached; tkwait on a dead window throws, so guard it. The result
# bus_dialog_done recorded still stands.
proc ase::ui::bus_dialog {key token bits} {
  variable wins
  set parent {}
  if {[dict exists $wins $key]} { set parent [dict get $wins $key] }
  set w [ase::ui::bus_dialog_build $parent $token $bits]
  update
  catch {raise $w}
  catch {grab set $w}
  catch {focus $w.lf.list}
  if {[winfo exists $w]} { tkwait window $w }
  return $::ase::ui::bus_dialog_result
}

# Select On Design queue merge (pure): dedupe on the EXACT expr string.
# Existing row -> OR the flavor's plot/save flags into it; a row already
# carrying both flags is left alone. Returns {newoutputs status} with status
# `added` (row appended), `merged` (flags ORed into an existing row) or
# `nochange` (identical re-queue — the outputs list is returned unchanged).
proc ase::ui::sod_merge {outputs ex flavor} {
  set p [expr {[ase::state_get $flavor plot 0] eq {1} ? 1 : 0}]
  set s [expr {[ase::state_get $flavor save 0] eq {1} ? 1 : 0}]
  for {set i 0} {$i < [llength $outputs]} {incr i} {
    set row [lindex $outputs $i]
    if {[ase::state_get $row expr] ne $ex} { continue }
    set op [expr {[ase::state_get $row plot 0] eq {1} ? 1 : 0}]
    set os [expr {[ase::state_get $row save 0] eq {1} ? 1 : 0}]
    set np [expr {$op || $p ? 1 : 0}]
    set ns [expr {$os || $s ? 1 : 0}]
    if {$np == $op && $ns == $os} { return [list $outputs nochange] }
    dict set row plot $np
    dict set row save $ns
    lset outputs $i $row
    return [list $outputs merged]
  }
  lappend outputs [dict create name {} expr $ex plot $p save $s]
  return [list $outputs added]
}

# Output-expression -> viewer-trace mapping (item 13, D6; PURE): a single
# token starting with `-` (and more than the dash — the canonical `-i(v1)`
# nfet output shape) becomes the RPN `<rest> -1 *`, which add_trace
# materializes as a raw vector via `xschem raw add` — a leading minus is
# print-deck syntax the graph engine cannot resolve as a vector name.
# Everything else (plain vectors, ready RPN, a bare `-`) passes through
# verbatim after a trim; add_trace's validate_rpn is the backstop.
proc ase::ui::plot_map_expr {ex} {
  set ex [string trim $ex]
  if {[llength [regexp -all -inline {\S+} $ex]] != 1} { return $ex }
  if {[string index $ex 0] eq {-} && [string length $ex] > 1} {
    return "[string range $ex 1 end] -1 *"
  }
  return $ex
}

# --- populate ----------------------------------------------------------------

# Checkbox-cell glyphs (unicode ballot boxes as escapes — file stays ASCII).
proc ase::ui::chk_glyph {on} {
  return [expr {$on eq {1} ? "\u2611" : "\u2610"}]
}

# Fill the three treeview panes + the toolbar temperature entry from the
# session state; Outputs Value cells come from the per-session `results`
# attr (set by run_finished — blank before the first successful run).
proc ase::ui::populate {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  if {![winfo exists $top]} { return }
  set st [ase::session_state $key]
  set results [ase::session_getattr $key results]
  set tv $top.body.vars.tv
  $tv delete [$tv children {}]
  set i 0
  foreach row [ase::state_get $st variables] {
    $tv insert {} end -id $i -values \
      [list [ase::state_get $row name] \
        [ase::format_value [ase::state_get $row value]]]
    incr i
  }
  set tv $top.body.ana.tv
  $tv delete [$tv children {}]
  set i 0
  foreach row [ase::state_get $st analyses] {
    $tv insert {} end -id $i -values [list [expr {$i + 1}] \
      [ase::state_get $row type] \
      [ase::ui::chk_glyph [ase::state_get $row enabled 0]] \
      [ase::ui::arg_summary $row [ase::ui::chana_sim $key]]]
    incr i
  }
  set tv $top.body.outs.tv
  $tv delete [$tv children {}]
  set i 0
  foreach row [ase::state_get $st outputs] {
    set val {}
    set rkey [ase::ui::output_result_key $row]
    if {$results ne {} && [dict exists $results $rkey]} {
      set val [dict get $results $rkey]
    }
    $tv insert {} end -id $i -values \
      [list [ase::ui::output_display_name $row] [ase::format_value $val] \
        [ase::ui::chk_glyph [ase::state_get $row plot 0]] \
        [ase::ui::chk_glyph [ase::state_get $row save 0]] \
        [ase::ui::save_options_cell $st $row]]
    incr i
  }
  $top.tb.temp delete 0 end
  $top.tb.temp insert 0 [ase::state_get $st temperature 27]
  ase::ui::refresh_title $key
  ase::ui::refresh_status $key
  ase::ui::apply_theme $top
}

# Refresh only the Outputs Value cells from the session `results` attr —
# called by run_finished after a successful run (keeps the selection, unlike
# a full repopulate).
proc ase::ui::refresh_output_values {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set tv [dict get $wins $key].body.outs.tv
  if {![winfo exists $tv]} { return }
  set st [ase::session_state $key]
  set results [ase::session_getattr $key results]
  set i 0
  foreach row [ase::state_get $st outputs] {
    set val {}
    set rkey [ase::ui::output_result_key $row]
    if {$results ne {} && [dict exists $results $rkey]} {
      set val [dict get $results $rkey]
    }
    catch {$tv set $i value [ase::format_value $val]}
    incr i
  }
}

# Return/FocusOut on the toolbar temperature entry: numeric -> straight into
# the session state (the harvest model is gone — this is the entry's own
# commit); garbage -> restore the entry from the state + report.
proc ase::ui::temp_commit {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  if {![winfo exists $top.tb.temp]} { return }
  set v [string trim [$top.tb.temp get]]
  if {![string is double -strict $v]} {
    $top.tb.temp delete 0 end
    $top.tb.temp insert 0 [ase::state_get [ase::session_state $key] temperature 27]
    catch {::ase::echo "ase: temperature must be numeric" error}
    return
  }
  set st [ase::session_state $key]
  dict set st temperature $v
  ase::session_update $key $st
}

# --- dialogs (UI v2 "Dialog style": modeless, themed, Return = proceed) ------
# All three follow references/copy_current_cell_dialog.tcl: named fonts,
# catch-destroy reuse, Return on every entry = proceed, per-window records
# (edrow/edchk) cleaned on proceed/cancel AND in ase::ui::close. MODELESS —
# no grab/tkwait — which is what keeps them test-drivable.
# ESC = Cancel (item 10 esc-dismiss): every dialog toplevel binds <Key-Escape>
# to its OWN cancel path via bind_dialog_esc — wired centrally in
# dialog_buttons, so every dialog_frame+dialog_buttons dialog (including
# FUTURE ones) gets ESC by construction; the non-scaffold dialogs (confirm,
# chana_options, listdlg_open, load_state_dialog) call it explicitly at
# creation. The ASE session window and the log window stay ESC-unbound by
# design (no accidental session close; Ctrl-W owns the log window).

# ESC dismisses the dialog through the SAME command as its Cancel/Close
# button — never a bare destroy that would leak the per-window records
# (edrow/edchk/dlg). Bound on the dialog TOPLEVEL: a child widget's bindtags
# include its nearest toplevel, so ESC pressed inside any entry bubbles here
# (Tk's Entry class Escape binding is a no-op and does not stop propagation).
# No `break`: `bind all <Key-Escape>` is empty in this app.
proc ase::ui::bind_dialog_esc {w cancelcmd} {
  bind $w <Key-Escape> $cancelcmd
}

# Shared scaffold: (re)create a modeless dialog toplevel; everything is
# GRIDDED into $w directly so the entries live at the deterministic paths
# $w.name / $w.value / $w.expr.
proc ase::ui::dialog_frame {w title} {
  catch {destroy $w}
  toplevel $w
  wm title $w $title
  grid columnconfigure $w 1 -weight 1
  return $w
}

proc ase::ui::dialog_row {w row label ename} {
  label $w.l$ename -text $label -font AseLabelFont -anchor w
  entry $w.$ename -width 26 -font AseEntryFont
  grid $w.l$ename -row $row -column 0 -sticky w -padx {8 6} -pady 2
  grid $w.$ename  -row $row -column 1 -sticky we -padx {0 8} -pady 2
  return $w.$ename
}

proc ase::ui::dialog_buttons {w row okcmd cancelcmd} {
  frame $w.btns
  button $w.btns.proceed -text OK -command $okcmd
  button $w.btns.cancel -text Cancel -command $cancelcmd
  pack $w.btns.proceed -side left -padx 5
  pack $w.btns.cancel -side right -padx 5
  grid $w.btns -row $row -column 0 -columnspan 2 -sticky we -padx 8 -pady 6
  # item 10: every scaffold dialog dismisses on ESC through its cancel path
  ase::ui::bind_dialog_esc $w $cancelcmd
}

# `=` / Variables context Add… / Variables > Edit… fallback: the Add Variable
# dialog (fields: name, value). OK appends {name N value V} to `variables`;
# empty or duplicate names are rejected with the dialog kept up.
proc ase::ui::add_variable_dialog {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [ase::ui::dialog_frame [dict get $wins $key].addvar \
           [ase::ui::lbl_add_variable]]
  set ne [ase::ui::dialog_row $w 0 Name: name]
  set ve [ase::ui::dialog_row $w 1 Value: value]
  ase::ui::dialog_buttons $w 2 [list ase::ui::add_variable_ok $key] \
    [list destroy $w]
  bind $ne <Return> [list ase::ui::add_variable_ok $key]
  bind $ve <Return> [list ase::ui::add_variable_ok $key]
  ase::ui::apply_theme $w
  focus $ne
  return $w
}

proc ase::ui::add_variable_ok {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].addvar
  if {![winfo exists $w]} { return }
  set name [string trim [$w.name get]]
  set value [string trim [$w.value get]]
  if {$name eq {}} {
    catch {::ase::echo "ase: variable name must not be empty" error}
    return
  }
  set st [ase::session_state $key]
  set rows [ase::state_get $st variables]
  foreach v $rows {
    if {[ase::state_get $v name] eq $name} {
      catch {::ase::echo "ase: variable '$name' already exists" error}
      return
    }
  }
  lappend rows [list name $name value $value]
  dict set st variables $rows
  ase::session_update $key $st
  ase::ui::populate $key
  destroy $w
}

# Double-click / context Edit… on a variables row: per-row editor
# (name/value prefilled); OK merges over the ORIGINAL row dict.
proc ase::ui::variable_editor {key idx} {
  variable wins; variable edrow
  if {![dict exists $wins $key]} { return }
  set rows [ase::state_get [ase::session_state $key] variables]
  if {![string is integer -strict $idx] || $idx < 0 || $idx >= [llength $rows]} {
    return
  }
  set row [lindex $rows $idx]
  set w [ase::ui::dialog_frame [dict get $wins $key].edvar {Edit Variable}]
  set edrow($key,var) $idx
  set ne [ase::ui::dialog_row $w 0 Name: name]
  set ve [ase::ui::dialog_row $w 1 Value: value]
  $ne insert 0 [ase::state_get $row name]
  $ve insert 0 [ase::state_get $row value]
  ase::ui::dialog_buttons $w 2 [list ase::ui::variable_editor_ok $key] \
    [list ase::ui::variable_editor_cancel $key]
  bind $ne <Return> [list ase::ui::variable_editor_ok $key]
  bind $ve <Return> [list ase::ui::variable_editor_ok $key]
  ase::ui::apply_theme $w
  focus $ve
  return $w
}

proc ase::ui::variable_editor_ok {key} {
  variable wins; variable edrow
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].edvar
  if {![winfo exists $w] || ![info exists edrow($key,var)]} { return }
  set name [string trim [$w.name get]]
  set value [string trim [$w.value get]]
  if {$name eq {}} {
    catch {::ase::echo "ase: variable name must not be empty" error}
    return
  }
  set idx $edrow($key,var)
  set st [ase::session_state $key]
  set rows [ase::state_get $st variables]
  if {$idx >= 0 && $idx < [llength $rows]} {
    set row [lindex $rows $idx]
    dict set row name $name
    dict set row value $value
    lset rows $idx $row
    dict set st variables $rows
    ase::session_update $key $st
    ase::ui::populate $key
  }
  catch {unset edrow($key,var)}
  destroy $w
}

proc ase::ui::variable_editor_cancel {key} {
  variable wins; variable edrow
  catch {unset edrow($key,var)}
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].edvar}
  }
}

# Double-click / context Edit… on an outputs row (idx >= 0), or the outputs
# Add… flavor (idx -1, blank prefill): name (optional) / expr entries +
# Plot / Save checkbuttons; OK merges name/expr/plot/save over the ORIGINAL
# row dict (blank name = unnamed output, allowed; expr must be non-empty).
proc ase::ui::output_editor {key idx} {
  variable wins; variable edrow; variable edchk
  if {![dict exists $wins $key]} { return }
  set rows [ase::state_get [ase::session_state $key] outputs]
  set row {}
  if {$idx >= 0} {
    if {![string is integer -strict $idx] || $idx >= [llength $rows]} { return }
    set row [lindex $rows $idx]
  } else {
    set idx -1
  }
  # ⚠ THE ADD TITLE IS THE `-->` STRIP BUTTON'S TOOLTIP (issue 1391): the tip
  # names the window the click produces, so the two are one string.
  set w [ase::ui::dialog_frame [dict get $wins $key].edout \
           [expr {$idx >= 0 ? {Edit Output} : [ase::ui::lbl_add_output]}]]
  set edrow($key,out) $idx
  set ne [ase::ui::dialog_row $w 0 Name: name]
  set xe [ase::ui::dialog_row $w 1 Expression: expr]
  $ne insert 0 [ase::state_get $row name]
  $xe insert 0 [ase::state_get $row expr]
  set edchk($key,plot) [expr {[ase::state_get $row plot 0] eq {1} ? 1 : 0}]
  set edchk($key,save) [expr {[ase::state_get $row save 0] eq {1} ? 1 : 0}]
  checkbutton $w.plot -text Plot -variable ::ase::ui::edchk($key,plot)
  checkbutton $w.save -text Save -variable ::ase::ui::edchk($key,save)
  grid $w.plot -row 2 -column 1 -sticky w -padx {0 8} -pady 2
  grid $w.save -row 3 -column 1 -sticky w -padx {0 8} -pady 2
  # item 08: choose-from-design — closes this dialog and enters the Select On
  # Design click mode with the checkboxes' current flavor (rows 2/3 column 0
  # are free; existing field paths untouched)
  button $w.fromdes -text "From Design…" \
    -command [list ase::ui::output_editor_from_design $key]
  grid $w.fromdes -row 2 -column 0 -rowspan 2 -sticky w -padx {8 6} -pady 2
  ase::ui::dialog_buttons $w 4 [list ase::ui::output_editor_ok $key] \
    [list ase::ui::output_editor_cancel $key]
  bind $ne <Return> [list ase::ui::output_editor_ok $key]
  bind $xe <Return> [list ase::ui::output_editor_ok $key]
  ase::ui::apply_theme $w
  focus $xe
  return $w
}

proc ase::ui::output_editor_ok {key} {
  variable wins; variable edrow; variable edchk
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].edout
  if {![winfo exists $w] || ![info exists edrow($key,out)]} { return }
  set name [string trim [$w.name get]]
  set ex [string trim [$w.expr get]]
  if {$ex eq {}} {
    catch {::ase::echo "ase: output expression must not be empty" error}
    return
  }
  set plot [expr {[info exists edchk($key,plot)] && $edchk($key,plot) ? 1 : 0}]
  set save [expr {[info exists edchk($key,save)] && $edchk($key,save) ? 1 : 0}]
  set idx $edrow($key,out)
  set st [ase::session_state $key]
  set rows [ase::state_get $st outputs]
  if {$idx < 0} {
    lappend rows [dict create name $name expr $ex plot $plot save $save]
  } elseif {$idx < [llength $rows]} {
    set row [lindex $rows $idx]
    dict set row name $name
    dict set row expr $ex
    dict set row plot $plot
    dict set row save $save
    lset rows $idx $row
  } else {
    ase::ui::output_editor_cancel $key
    return
  }
  dict set st outputs $rows
  ase::session_update $key $st
  ase::ui::populate $key
  catch {unset edrow($key,out)}
  catch {unset edchk($key,plot)}
  catch {unset edchk($key,save)}
  destroy $w
}

proc ase::ui::output_editor_cancel {key} {
  variable wins; variable edrow; variable edchk
  catch {unset edrow($key,out)}
  catch {unset edchk($key,plot)}
  catch {unset edchk($key,save)}
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].edout}
  }
}

# --- Select On Design (item 08) ----------------------------------------------
# A click mode on the design schematic that queues Outputs rows: wire /
# net-label click -> voltage output `v(<net>)`, source-class instance click
# (symbol type vsource/ammeter) -> source-current output `i(<inst>)`; ESC
# ends the mode, restores the seized canvas bindings VERBATIM and returns
# focus to the ASE window. Entry points: Outputs > To Be Saved/To Be Plotted >
# Select On Design and the Add/Edit Output dialog's "From Design…" button.
#
# Mechanism (no C hook): Tk fires the MOST SPECIFIC matching binding per tag,
# so seizing <ButtonPress-1>/<ButtonRelease-1>/<Key-Escape> on the design
# canvas pre-empts the generic <ButtonPress>/<ButtonRelease>/<KeyPress> ->
# `xschem callback` bindings for exactly those events while Motion (context
# switching + mousex_snap updates) keeps flowing to C. Every seized script
# ends in `break` so the generic class/all bindtags never see the event. The
# previous binding STRINGS are saved at entry and restored verbatim at exit,
# which composes with the addpin/addlabel forms' shared `.drw <Key-Escape>`
# slot for free.
#
# v1 terminal-current scope (honest restriction, spec "Select On Design v1
# scope"): only SOURCE-class instances (symbol type vsource/ammeter) queue
# currents — a source has exactly one branch current, so instance-level hit
# granularity is exact. Per-terminal currents of other devices need ngspice
# `.options savecurrents` + `@m.x<inst>.<subdev>[id]` names that depend on
# subcircuit internals invisible to the schematic click — deferred.

# The design window's bottom mode-prompt slot for a canvas $cv: the green
# .statusbar.10 label (xschem's "DRAW WIRE!" / "HIGHLIGHT NET!" convention),
# per-window (.drw -> "", .x1.drw -> ".x1"). Kept as raw Tk configure — there
# is no xschem verb wrapper for this slot.
proc ase::ui::sod_statusbar {cv} {
  regsub {\.drw$} $cv {} top
  return "$top.statusbar.10"
}
# Show / clear the select-on-design prompt on that slot. `-state active` turns on
# the green background; clearing restores the neutral state + blank text. Both
# catch — the canvas/statusbar may not exist (headless, torn-down window).
proc ase::ui::sod_prompt_set {cv text} {
  catch {[ase::ui::sod_statusbar $cv] configure -state active -text $text}
}
proc ase::ui::sod_prompt_clear {cv} {
  catch {[ase::ui::sod_statusbar $cv] configure -state normal -text { }}
}
# Keep the prompt up while the mode is armed. Every generic canvas event forwards
# to C callback() -> update_statusbar(), which BLANKS .statusbar.10 whenever no C
# ui_state mode bit is set (this is a pure-Tcl mode, so none is) — and window
# focus/creation churn re-establishes the generic canvas bindings, so appending a
# re-assert to them does not survive. A light periodic re-set is immune to both
# the blank and the rebind. Self-cancels the instant the mode ends (sod(active)
# gone or moved to another key); the pending `after` id is also cancelled
# explicitly in sod_end. ~80 ms => a blanking event shows at most a sub-frame
# flicker before the prompt returns; a C ui_state bit would remove even that.
proc ase::ui::sod_prompt_pump {key} {
  variable sod
  if {![info exists sod(active)] || $sod(active) ne $key} return
  if {![info exists sod($key,canvas)] || ![info exists sod($key,prompt)]} return
  ase::ui::sod_prompt_set $sod($key,canvas) $sod($key,prompt)
  set sod($key,pump) [after 80 [list ase::ui::sod_prompt_pump $key]]
}

# Enter the mode for session `key` with `flavor` = {save S plot P} (menu To
# Be Saved -> {save 1 plot 0}, To Be Plotted -> {save 1 plot 1}, From Design…
# -> the dialog checkboxes). `mode` (item 13, D1) selects what a click
# queues: `outputs` (default — item-08 behavior, session outputs written) or
# `plot` (Results > Direct Plot — trace expressions collected into
# sod($key,queue), handed to dp_finish on ESC; the flavor is inert there).
# ONE mode globally: entering while another is active cleanly ends the
# previous one first. Returns 1 when the mode is armed, 0 when the design
# window cannot be opened.
proc ase::ui::select_on_design {key flavor {mode outputs} {do_raise 1}} {
  variable sod
  if {[info exists sod(active)]} { ase::ui::sod_end $sod(active) }
  # do_raise 0 (Ctrl-4 from the design window): the design is ALREADY the current
  # front window, so skip design_window's raise_activate_toplevel — a visible
  # withdraw/deiconify flash + a toplevel focus-steal (the reported "hiccup").
  # The menu path (Session/Results) keeps do_raise 1 to bring the design forward.
  if {$do_raise} {
    if {![ase::ui::design_window $key]} { return 0 }
  }
  set cv [xschem get current_win_path]
  if {![winfo exists $cv]} {
    catch {::ase::echo "ase: no design canvas to select on ($cv)" error}
    return 0
  }
  set sod($key,canvas)    $cv
  set sod($key,flavor)    $flavor
  set sod($key,mode)      $mode
  if {$mode eq {plot}} { set sod($key,queue) {}; set sod($key,qcolors) {} }
  set sod($key,count)     0
  set sod($key,prevpress) [bind $cv <ButtonPress-1>]
  set sod($key,prevrel)   [bind $cv <ButtonRelease-1>]
  set sod($key,prevesc)   [bind $cv <Key-Escape>]
  bind $cv <ButtonPress-1>   "[list ase::ui::sod_click $key]; break"
  # a lone release must not reach the C callback — the press it pairs with
  # was swallowed above
  bind $cv <ButtonRelease-1> {break}
  bind $cv <Key-Escape>      "[list ase::ui::sod_end $key]; break"
  # The seized <Key-Escape>/<ButtonPress-1> binds live on the design CANVAS, but
  # design_window's raise_activate_toplevel + `focus $tp` just moved keyboard
  # focus to the TOPLEVEL (and the seized Button-1 `break`s before the generic
  # <ButtonPress> that would refocus the canvas). Without the canvas holding
  # focus, a real ESC keypress never reaches this binding — the mode gets stuck
  # (mouse picking still works, ESC does not). Give the canvas keyboard focus.
  catch {focus $cv}
  # Bottom-status-line prompt (the schematic window's own mode line, distinct
  # from the CIW/action-log ase::echo notice below): set it now and keep it
  # up via sod_prompt_pump
  # (the C engine blanks .statusbar.10 on every event — see that proc). Cleared
  # and the pump cancelled in sod_end.
  if {$mode eq {plot}} {
    set sod($key,prompt) {select signals to plot}
  } else {
    set sod($key,prompt) {select outputs on design}
  }
  set sod(active) $key
  ase::ui::sod_prompt_set $cv $sod($key,prompt)
  ase::ui::sod_prompt_pump $key
  if {$mode eq {plot}} {
    catch {::ase::echo "ase: Direct Plot — click wires/net labels for voltage\
 traces, sources for current traces; ESC plots"}
  } else {
    catch {::ase::echo "ase: Select On Design — click wires/net labels for\
 voltages, sources for currents; ESC ends"}
  }
  return 1
}

# End the mode: restore the three seized bindings verbatim (catch — the
# canvas may be dead; the restore is IDENTICAL for both modes), clear the
# mode records, then finish per mode: `outputs` reports how many outputs
# were queued and returns focus to the ASE window (raise_activate_toplevel —
# a bare raise is a no-op under WSLg/Weston, issue 0054); `plot` (item 13)
# SKIPS the ASE-window raise and hands the queued trace expressions to
# dp_finish, which raises/opens the VIEWER instead. Safe to call when no
# mode is active for `key` (early return).
# Shared teardown: hand the three seized canvas bindings back verbatim, stop the prompt
# pump, clear the status-line prompt. Deliberately does NOT touch the sod($key,*) records
# and does NOT finish the command — both sod_end (which then finishes) and sod_suspend
# (which must not) go through here. Returns 0 if no mode was live for `key`.
# doc/claude/issues/0201-no-command-suspend-resume-contract.md D3.
proc ase::ui::sod_release {key} {
  variable sod
  if {![info exists sod($key,canvas)]} { return 0 }
  set cv $sod($key,canvas)
  catch {bind $cv <ButtonPress-1>   $sod($key,prevpress)}
  catch {bind $cv <ButtonRelease-1> $sod($key,prevrel)}
  catch {bind $cv <Key-Escape>      $sod($key,prevesc)}
  if {[info exists sod($key,pump)]} { catch {after cancel $sod($key,pump)} }
  ase::ui::sod_prompt_clear $cv
  return 1
}

proc ase::ui::sod_end {key} {
  variable sod; variable wins
  if {![ase::ui::sod_release $key]} { return }
  set n 0
  if {[info exists sod($key,count)]} { set n $sod($key,count) }
  # item 13 (D1): capture mode + queue BEFORE the records are wiped
  set mode outputs
  if {[info exists sod($key,mode)]} { set mode $sod($key,mode) }
  set queue {}
  if {[info exists sod($key,queue)]} { set queue $sod($key,queue) }
  set qcolors {}                        ;# issue 0153: colors already on the schematic
  if {[info exists sod($key,qcolors)]} { set qcolors $sod($key,qcolors) }
  array unset sod $key,*
  if {[info exists sod(active)] && $sod(active) eq $key} { unset sod(active) }
  if {$mode eq {plot}} {
    catch {::ase::echo "ase: Direct Plot — $n trace(s) queued"}
    ase::ui::dp_finish $key $queue $qcolors
    return
  }
  catch {::ase::echo "ase: Select On Design ended — $n output(s) queued"}
  if {[dict exists $wins $key]} {
    set top [dict get $wins $key]
    if {[winfo exists $top]} {
      catch {raise_activate_toplevel $top}
      catch {focus $top}
    }
  }
}

# --- cmdmode participation (issue 0201) ---------------------------------------------
#
# ASE's ENTIRE share of the suspend/resume contract: two arms and one register line. The
# mechanism is in src/cmdmode.tcl and knows nothing about sessions, traces, waveforms or
# graph elements (D1, the user's explicit constraint). sod_end is untouched.

# Suspend arm. Release the canvas, KEEP the records: queue, qcolors, count, flavor, mode
# and prompt all survive. This is the whole difference from sod_end, which wipes them and
# — in plot flavour — PLOTS what it wiped. Returns 1 if a live mode was released.
proc ase::ui::sod_suspend {} {
  variable sod
  if {![info exists sod(active)]} { return 0 }
  set key $sod(active)
  if {![ase::ui::sod_release $key]} { return 0 }
  # sod(active) stays SET while suspended, on purpose: select_on_design's self-serialise
  # (`if {[info exists sod(active)]} { sod_end $sod(active) }`) must still find this mode
  # and end it properly if the user starts a fresh one instead of coming back, and
  # sod_click's own gate is sod($key,flavor), not this. The prompt pump does not restart
  # — sod_release cancelled its pending `after` and only sod_resume re-arms it.
  set sod($key,suspended) 1
  return 1
}

# Resume arm. Bring the paused mode back up on `canvas` — which after a new-window /
# new-tab descend is NOT the canvas it was seized on (D2). Deliberately NOT a second
# select_on_design call: that re-initialises queue/qcolors and resets count to 0, i.e. it
# would silently discard every trace the user picked before the interruption.
#
# The three `bind` reads below re-capture the predecessors from the canvas we are landing
# on, so ESC/Button-1 are handed back correctly on THAT canvas when the mode finally ends
# — a new canvas has its own binding set (set_bindings + clone_canvas_bindings), and the
# predecessors latched on the parent do not describe it.
proc ase::ui::sod_resume {{canvas {}}} {
  variable sod
  if {![info exists sod(active)]} { return 0 }
  set key $sod(active)
  if {![info exists sod($key,suspended)]} { return 0 }
  if {$canvas eq {} || ![winfo exists $canvas]} {
    set canvas {}
    catch {set canvas $sod($key,canvas)}
  }
  if {$canvas eq {} || ![winfo exists $canvas]} {
    # Nowhere left to come back to (the window was closed while suspended). Drop the
    # mode rather than leave an unreachable record behind; do not plot a queue the user
    # can no longer see or extend.
    catch {::ase::echo "ase: the design window the pick mode was on is gone — mode dropped" error}
    array unset sod $key,*
    unset -nocomplain sod(active)
    return 0
  }
  set sod($key,canvas)    $canvas
  set sod($key,prevpress) [bind $canvas <ButtonPress-1>]
  set sod($key,prevrel)   [bind $canvas <ButtonRelease-1>]
  set sod($key,prevesc)   [bind $canvas <Key-Escape>]
  bind $canvas <ButtonPress-1>   "[list ase::ui::sod_click $key]; break"
  bind $canvas <ButtonRelease-1> {break}
  bind $canvas <Key-Escape>      "[list ase::ui::sod_end $key]; break"
  catch {focus $canvas}
  unset -nocomplain sod($key,suspended)
  if {[info exists sod($key,prompt)]} {
    ase::ui::sod_prompt_set $canvas $sod($key,prompt)
    ase::ui::sod_prompt_pump $key
  }
  return 1
}

cmdmode::register ase_sod ase::ui::sod_suspend ase::ui::sod_resume

# The net under a mode click, as the RAW schematic token (issue 0154).
#
# `xschem flylines at` is the primary resolver and stays first: it is read-only
# and resolves wires, net labels and labeled pins through the very switch
# hilight_net() uses (flyline_net_of, flyline.c), so every named net keeps its
# shipped behavior byte for byte. It has one blind spot, deliberate for
# fly-lines and wrong for signal picking — rule A6, "exclude auto-named nets"
# (flyline.c: `if(netname[0] == '#') netname = NULL`). A `#netN` cluster is
# unique per physical cluster and can never connect implicitly, so a fly-line
# star for it would be meaningless; but it is a perfectly ordinary net to
# probe, and inheriting the exclusion is what made clicking one print the
# "source currents only" notice. A6 is NOT relaxed — the overlay, the query and
# tests/headless/test_flylines.sh keep it exactly as shipped.
#
# The fallback is `xschem net_name_at`, the READ-ONLY net probe (issue 0204):
# the wire's raw node token, resolved straight from the coordinate, with no
# selection anywhere in the path. It replaces `select_at` + `xschem nets
# -selected`, which could only answer this question by first SELECTING the
# wire — and that leftover selection is what made the next `e` descend into a
# net label instead of arming the verb-noun pick.
#
# Both halves of the old idiom live on inside net_name_at, because both were
# load-bearing. It is cold-correct (prepare_netlist_structs first, exactly as
# `nets` does), and it is restricted to WIRE hits: on a device BODY
# `nets -selected` reported every net the device touches (2 for a vsource, 3
# for a mosfet), and a two-pin device with both pins on one net reported
# exactly one — so an llength test alone would misclassify a non-source device
# click as a voltage pick and break the "non-source click queues nothing"
# contract (test_ase_interact I6, test_ase_unnamed_net AN7b). A wire lies on
# exactly one net by construction. The `$hit` type gate below is kept as well:
# it is this caller's own statement of that contract, and it costs nothing.
#
# Returns the token WITH its `#` and in its original case: dp_hilight needs
# that form (`xschem hilight_netname net1` finds nothing, `#net1` works). The
# simulator-side mapping belongs to sod_expr, and only there.
proc ase::ui::sod_net_at {x y hit} {
  set net {}
  catch {set net [dict get [xschem flylines at $x $y] net]}
  if {$net ne {}} { return $net }
  if {[lindex $hit 0] ne {wire}} { return {} }
  # by INDEX, not by coordinate: `$hit` was already hit-tested, and the coordinate form
  # would run a second, independent find_closest_obj — which re-expands floater text
  # through Tcl and could hand the pick to a different object on that second pass.
  set name {}
  catch {set name [xschem net_name_at -wire [lindex $hit 1]]}
  return $name
}

# One mode click. Bare x/y (the canvas binding) read the last snapped mouse
# position — kept current by the generic <Motion> binding that still flows to
# C; tests pass explicit schematic coordinates (replayable). Classification
# (D4): object_at miss -> nothing; source-class instance -> current output;
# anything resolving to a net under the click (wires, net labels, labeled
# pins — via sod_net_at) -> voltage output; else the v1 scope notice.
#
# issue 0204: the pick is READ-ONLY. It used to classify with `xschem select_at`,
# the MUTATING coordinate pick, so every plot click left its target selected —
# and `hi_descend` reads a non-empty `xschem selected_set` as "noun-verb", so the
# next `e` descended into the net label the user had just picked a signal from
# instead of arming the verb-noun pick (issue 0200). A pick is not a selection:
# `xschem object_at` classifies identically (same find_closest_obj cascade, same
# override_lock=0) and selects, draws and logs nothing.
#
# What that costs, recorded rather than glossed: (a) the stashed
# `xschem select_at x y` action-log line is gone. It logged a selection that no
# longer happens, so keeping it would have been a lie — and replaying it never
# re-created the pick anyway (it re-selects an object; it does not re-enter
# Direct Plot or queue anything). An honest SOD-pick log line is a separate
# piece of work. (b) In `plot` flavour dp_hilight still paints the picked object
# in its future trace colour (issue 0153), but `outputs` flavour paints nothing,
# so there the selection highlight WAS the only on-canvas acknowledgement; its
# feedback is now the CIW echo and the Outputs pane only.
proc ase::ui::sod_click {key {x {}} {y {}}} {
  variable sod
  if {![info exists sod($key,flavor)]} { return }
  if {$x eq {}} { set x [xschem get mousex_snap] }
  if {$y eq {}} { set y [xschem get mousey_snap] }
  # issue 0160: an EMPTY hit is not the end of the click. The hit test runs with
  # override_lock=0, so a `lock=true` wire returns nothing even though its net
  # resolves perfectly (`xschem flylines at` uses override_lock=1 and never had a
  # problem with it) — the pick died before classification, so not even the
  # notice below fired.
  #
  # The fix was deliberately NOT to override the lock here, and 0204 did not
  # change that even though object_at could now afford to. `lock` is enforced in
  # exactly two files, select.c and findnet.c; there is no lock check in move.c,
  # actions.c or any delete path, because every edit acts on the SELECTION.
  # Selection IS the lock — that argument was about SELECTING a locked object,
  # and it no longer applies to a probe that selects nothing. But relaxing it
  # here would silently change what a locked vsource body and a locked unnamed
  # wire classify as (test_ase_locked_wire_pick_0160 LK11 pins the first), so it
  # stays a separate, deliberate decision rather than a side effect of 0204 —
  # doc/claude/issues/0205-read-only-probes-still-honour-the-lock.md.
  #
  # The empty-hit return therefore stays at the bottom (see `$hit eq {}` there),
  # where it only ends a click that classified as nothing — so an empty-canvas
  # click stays silent exactly as before.
  set hit [xschem object_at $x $y]
  set kind {}
  set token {}
  if {[lindex $hit 0] eq {instance}} {
    set n [lindex $hit 1]
    set ctype {}
    catch {set ctype [xschem getprop instance $n cell::type]}
    if {[lsearch -exact {vsource ammeter} $ctype] >= 0} {
      set kind current
      set token [xschem getprop instance $n name]
    }
  }
  if {$kind eq {}} {
    set net [ase::ui::sod_net_at $x $y $hit]
    if {$net ne {}} {
      set kind voltage
      set token $net
    }
  }
  if {$kind eq {}} {
    # nothing under the cursor at all (empty canvas): stay silent, as before
    # this became the late return — a pick mode that scolded every miss-click
    # would be noise (issue 0160).
    if {$hit eq {}} { return }
    catch {::ase::echo "ase: v1 queues source currents only — click a wire, a\
 net label or a voltage source/ammeter"}
    return
  }
  # item 13 (D1): route on the mode — `outputs` writes session outputs
  # (item-08 behavior), `plot` collects trace expressions for dp_finish.
  # issue 0153: plot mode also gets the classification (kind + raw net/instance
  # name) so it can paint that object in the color the trace will use — `ex` is
  # already wrapped as v(...)/i(...) and is not a highlight target.
  # issue 0159: a BUS net is not one signal. sod_pick_tokens asks the user which
  # bits (bit dialog; Cancel -> empty list -> queue nothing) and we queue one row
  # per chosen bit, in the order the dialog displayed them. A scalar or a current
  # pick comes back as the single original token, so the common path is unchanged.
  set toks [ase::ui::sod_pick_tokens $key $kind $token]
  if {![llength $toks]} { return }
  # issue 0161: a pick at currsch>0 named a node the simulator does not have
  # (`v(mid)` for what ngspice calls `v(x1.x2.mid)`). sod_qualify resolves the
  # token against the hierarchy HERE, at the impure click site, so sod_expr can
  # stay the pure string wrap H1 asserts. Identity at the top level. Note the
  # 0153 colour cue below still gets the RAW `$token`: `hilight_netname` wants
  # the schematic's own name, not the simulator's.
  # issue 0168: names are measured from the level of the SESSION's own design in
  # this window's stack, not blindly from the window's top — a pick made under a
  # session bound to an intermediate cell must match THAT session's deck.
  # casemode item 9: the expression is written in the mode this session will
  # REQUEST of its simulator (profile, then the global floor, then fold). Both
  # the level and the mode are resolved ONCE per gesture, before the fan-out, so
  # a bus's bits cannot disagree with each other.
  set base [ase::ui::sod_base_level $key]
  set cmode [ase::ui::sod_case_mode $key]
  set first 1
  foreach t $toks {
    set ex [ase::ui::sod_expr $kind [ase::ui::sod_qualify $kind $t $base] $cmode]
    if {[info exists sod($key,mode)] && $sod($key,mode) eq {plot}} {
      # 0153's schematic cue: colour the picked object ONCE, in the first
      # trace's colour. The bus is a single wire, so N cues would just repaint
      # it N times and end on the last bit's colour; and the per-bit token is
      # not a highlightable net name in its own right.
      ase::ui::dp_queue $key $ex $kind [expr {$first ? $token : {}}]
    } else {
      ase::ui::sod_queue $key $ex
    }
    set first 0
  }
}

# Paint the schematic object a queued Direct Plot signal came from, in the layer
# color its waveform trace will carry (issue 0153) — the whole point of the
# feature: the viewer's traces map back onto the schematic by color.
#
# `xschem hilight_netname/-instname -layer N` highlights in the PLAIN color of
# drawing layer N (a negative hilight value, the engine's existing
# "layer color, no style" path) rather than taking the next entry from the
# net-hilight STYLE table. That is required, not a convenience: the viewer
# palette is layer indices, and two of them (4, 5) have no style-table entry at
# all (default styles cover layers >= 7 only), so `-style` could not reproduce
# them. It also leaves the user's style cursor untouched.
#
# Highlights PERSIST past ESC (user decision) so the color map stays readable
# while reading the plots; clear them the normal way (Del/unhilight). Existing
# highlights are deliberately NOT wiped on entry. All catch-guarded: a net that
# resolves to nothing must never break the picking mode.
proc ase::ui::dp_hilight {kind token color} {
  if {$color eq {} || $token eq {}} { return 0 }
  if {![string is integer -strict $color] || $color <= 0} { return 0 }
  if {$kind eq {current}} {
    # a current probe was picked on a source/ammeter BODY: there is no wire to
    # color, so the instance itself carries the cue
    return [expr {[catch {xschem hilight_instname -layer $color $token}] ? 0 : 1}]
  }
  return [expr {[catch {xschem hilight_netname -layer $color $token}] ? 0 : 1}]
}

# Queue `ex` into the session's outputs with the mode's flavor (the
# delete_selection mutation idiom: session_update + populate, so the row is
# visible in the Outputs pane IMMEDIATELY even while the pane is stacked
# under the design window). An identical re-queue writes nothing.
proc ase::ui::sod_queue {key ex} {
  variable sod
  if {![info exists sod($key,flavor)]} { return }
  set st [ase::session_state $key]
  lassign [ase::ui::sod_merge [ase::state_get $st outputs] $ex \
             $sod($key,flavor)] rows status
  if {$status eq {nochange}} {
    catch {::ase::echo "ase: output '$ex' already queued"}
    return
  }
  dict set st outputs $rows
  ase::session_update $key $st
  ase::ui::populate $key
  incr sod($key,count)
  catch {::ase::echo "ase: queued output '$ex' ($status)"}
}

# Direct Plot queue step (item 13, D1/D2): collect the trace expression into
# the mode's queue — session outputs are NEVER written in plot mode (Cadence
# Direct Plot creates no save entries; test-asserted). Exact-string dedupe.
#
# issue 0153: each accepted signal also gets its FUTURE trace color resolved
# now (wviewer::predict_colors is prefix-stable, so asking for the colors of the
# queue-so-far always returns this signal's color last), recorded in a parallel
# `qcolors` list, and applied to the clicked net/instance. dp_finish hands the
# colors to plot_signals, so the schematic cue and the trace can never disagree.
# A duplicate re-queue colors nothing (it adds no trace).
proc ase::ui::dp_queue {key ex {kind {}} {token {}}} {
  variable sod
  if {![info exists sod($key,queue)]} { return }
  if {[lsearch -exact $sod($key,queue) $ex] >= 0} {
    catch {::ase::echo "ase: trace '$ex' already queued"}
    return
  }
  lappend sod($key,queue) $ex
  incr sod($key,count)
  set col {}
  catch {set col [lindex [wviewer::predict_colors $key [llength $sod($key,queue)]] end]}
  lappend sod($key,qcolors) $col
  ase::ui::dp_hilight $kind $token $col
  catch {::ase::echo "ase: queued trace '$ex'"}
}

# POST-LOAD CURRENT REPAIR — casemode batch item 12 (PLAN.md §3b item 12 and
# §D6 part 2; DECISIONS.md D2; spec doc/claude/specs/simulator_profiles.md §16).
#
# Called AFTER the run's databases are attached and BEFORE the expressions are
# handed to the viewer, at the two seams that attach one: dp_finish (Direct
# Plot) and auto_plot (the session's `plot` rows). A CURRENT expression is
# constructed from our model of how the simulator names a branch — the device's
# own first character, the instance path, the name (sod_qualify) plus the case
# map (sod_expr) — so the database the run actually wrote is the only authority
# that can correct it. wviewer::repair_currents does the lookup; this proc owns
# the ANNOUNCEMENT, which is ASE-L's channel (ase::echo -> the CIW pane and the
# action log), and returns the list with its length preserved.
#
# ⚠ THE SESSION IS NEVER REWRITTEN, and that is DECISIONS.md D1's precedent, not
# an omission. D1 refused a silent re-case pass because a wrong map would
# corrupt saved work with no trace, and item 10 made its correction an EXPLICIT
# command (ase::preflight_fix_session) rather than an implicit edit. The repair
# is therefore in memory, for this attach: the row's stored `expr` and the
# state file keep the user's own text, the session is not marked dirty, and the
# next attach repairs — and re-announces — again. What DOES carry the repaired
# spelling is the trace the viewer stores, because that is a description of the
# data now on screen and it is the viewer's own document, not the user's.
#
# ⚠ NOT SILENT IN EITHER DIRECTION. A repair says which spelling it plotted (a
# name the user never typed, appearing in a legend, is exactly the surprise
# item 14's relay ruling is about) and a D2 decline names every candidate at tag
# `error`. A token nothing folds to is NOT announced here: add_trace and
# plot_signals already report it per expression, and two lines for one failure
# is the noise item 10's per-offender rule was written against.
#
# ⚠ AND THE COUNTING UNIT IS THE OFFENDING SPELLING, NOT THE OCCURRENCE — the
# same rule again, applied to this loop rather than only to the candidate scan.
# One mis-cased current referenced by N output rows (or twice inside one RPN)
# produces ONE line, not N byte-identical ones: `wviewer::repair_currents`
# returns a note per token OCCURRENCE, because its caller needs the positions,
# and this proc folds them onto {status old new} before it speaks. Item 11
# §15.5 counts spellings for the same reason.
proc ase::ui::repair_currents {key exprs} {
  set out $exprs
  set notes {}
  if {[catch {lassign [wviewer::repair_currents $key $exprs] out notes}]} {
    return $exprs
  }
  # LENGTH IS THE CONTRACT, and it is checked rather than trusted: dp_finish
  # pairs this list with `qcolors` positionally, so a short answer would not
  # merely lose a trace, it would repaint the survivors in the wrong colours.
  if {[llength $out] != [llength $exprs]} { return $exprs }
  set said {}
  foreach n $notes {
    lassign $n st old new cands
    set sig [list $st $old $new]
    if {[lsearch -exact $said $sig] >= 0} { continue }
    lappend said $sig
    if {$st eq {repaired}} {
      catch {::ase::echo "ase: current '$old' is not in the results database —\
 plotting its own spelling '$new'" note}
    } elseif {$st eq {ambiguous}} {
      # ⚠ "MATCH IT CASE-INSENSITIVELY", not "differ from it only in case": the
      # candidates come off `name_rungs`, so one of them can differ by the whole
      # dropped branch prefix as well (item 2's `i(v.x` -> `i(x` rung, e.g.
      # `i(X1.Vs)` against `i(V.X1.VS)`). The old wording was simply false for
      # that candidate, and a user asked to choose between two names deserves an
      # accurate description of why they are both in the list.
      catch {::ase::echo "ase: current '$old' is not in the results database and\
 [llength $cands] names in it match case-insensitively ([join $cands {, }]) —\
 declining to guess which one you meant" error}
    }
  }
  return $out
}

# The exact-string dedupe `ase::ui::dp_queue` applies at PICK time, re-applied
# after the repair — in LOCKSTEP with the parallel colour list.
#
# ⚠ WHY IT HAS TO RUN TWICE. dp_queue refuses a duplicate with `lsearch -exact`,
# which is the right test at pick time; but the repair can rewrite two DISTINCT
# queued spellings of one current (`i(v.x1.vs)` and `i(V.x1.Vs)`, both legal
# picks on a case_sensitive database) into one identical string. Handing that to
# plot_signals plots the same data twice — two strips in multi-plot, two
# same-data traces in one strip in single-plot — at two DIFFERENT colours, so
# one of the two schematic net cues issue 0153 paints can never match its trace.
# The FIRST occurrence and its colour survive; that keeps the colour the picker
# already painted on the wire the user clicked first.
#
# ⚠ COLOURS ARE FILTERED WITH IT OR NOT AT ALL. dp_finish pairs the two lists
# positionally, so dropping an expression without its colour would repaint every
# survivor after it. A colour list that is empty (a scripted or replayed call —
# plot_signals then derives them) or that is not the same length as the
# expressions is not positional and comes back untouched.
proc ase::ui::dedupe_plot_queue {exprs {colors {}}} {
  set paired [expr {[llength $colors] == [llength $exprs]}]
  set oe {}
  set oc {}
  set i 0
  foreach ex $exprs {
    if {[lsearch -exact $oe $ex] < 0} {
      lappend oe $ex
      if {$paired} { lappend oc [lindex $colors $i] }
    }
    incr i
  }
  if {!$paired} { return [list $oe $colors] }
  return [list $oe $oc]
}

# Direct Plot finish (item 13, D3): runs AFTER sod_end restored the canvas
# bindings, with the queued trace expressions. Policy: (1) op-only results
# have no sweep -> notice, queue discarded, viewer untouched; (2) viewer
# raised-or-opened; (3) the session's raw attached when a run has produced
# one — no run yet is a notice, NOT an abort: the traces are still recorded
# (add_trace's pre-run seam) and resolve at the next attach_raw; (4) ONE new
# stacked graph per invocation, every queued expression appended to it
# (per-trace add errors are reported and skipped); an empty queue just
# leaves the raised viewer. The mode itself already exited clean before this
# runs, whatever happens here.
proc ase::ui::dp_finish {key queue {qcolors {}}} {
  set st [ase::session_state $key]
  set sim_t [ase::plot_sim_type $st]
  if {$sim_t eq {op}} {
    catch {::ase::echo "ase: op results have no sweep — nothing to plot"}
    return
  }
  if {![wviewer::open $key]} {
    catch {::ase::echo "ase: cannot open the waveform viewer for $key" error}
    return
  }
  set rf [ase::last_rawfile $key]
  set attached 0
  if {$rf ne {}} {
    if {[wviewer::attach_raw $key $rf $sim_t [ase::last_vcdfiles $key]]} { set attached 1 }
  } else {
    catch {::ase::echo "ase: no simulation results yet — run first (queued\
 traces are recorded and resolve after the run)"}
  }
  if {![llength $queue]} { return }
  # casemode item 12: the databases are attached now, so a constructed current
  # that misses can be resolved against what the run actually wrote. Once, for
  # the whole queue, before plot_signals — `qcolors` stays aligned because the
  # list length is preserved (and the dedupe below filters both together).
  #
  # ⚠ ONLY WHEN THIS CALL ACTUALLY ATTACHED, and that is the "post-load" in the
  # item's name rather than a belt-and-braces guard. On the NO-RUN path above
  # there is no session database — but the viewer window may still hold a raw
  # somebody opened by hand (rawbar_load), and repairing against THAT rewrites a
  # queued trace to a foreign file's spelling and then pins it there, while the
  # notice one line up promises the trace "resolves after the run". Two
  # statements contradicting each other in the same breath, and the wrong one
  # wins. Nothing attached -> nothing to repair against -> the queue goes
  # through exactly as dp_queue recorded it (CU238e).
  if {$attached} {
    set queue [ase::ui::repair_currents $key $queue]
    lassign [ase::ui::dedupe_plot_queue $queue $qcolors] queue qcolors
  }
  # issue 0151: WHERE the queued signals land is the viewer window's plot mode
  # (doc/claude/specs/waveform_viewer_modes.md) — single-plot appends them all
  # into the target strip, multi-plot gives each one its own new strip. The
  # whole policy lives in wviewer::plot_signals; this side only reports the
  # per-signal failures it returns.
  # issue 0153: `qcolors` are the colors the picker already painted onto the
  # schematic nets, passed through verbatim so each trace lands in ITS wire's
  # color. Empty (a scripted/replayed call) -> plot_signals derives them itself.
  foreach pair [wviewer::plot_signals $key $queue $qcolors] {
    lassign $pair ex err
    catch {::ase::echo "ase: cannot plot '$ex': $err" error}
  }
}

# Results > Direct Plot (item 13, D13): the Select-On-Design mode in the
# `plot` flavor — clicks queue traces; the flavor content is inert in plot
# mode (D2) but kept self-documenting.
proc ase::ui::direct_plot {key {do_raise 1}} {
  ase::ui::select_on_design $key {save 0 plot 1} plot $do_raise
}

# --- Results > Annotate: the annotation visibility control (issue 0682) ------
#
# THE WHOLE PROBLEM IN ONE SENTENCE: the mask this menu governs (`annot_show`)
# is per DESIGN CONTEXT, and an ASE-L window is a plain Tk toplevel
# (ase_window.tcl `toplevel $top`), not an xschem drawing context. So a
# a `-command` that wrote the mask directly, hung off `.aseN`, writes into whatever
# xschem context happens to be CURRENT when the user clicks -- which after any
# tab switch is not the session's design. Everything below exists to make the
# menu READ and WRITE the DESIGN's mask instead of the current one's.
#
# OWNERSHIP, MEASURED 2026-08-24 rather than assumed (0682 §4 asks for exactly
# this): `xctx->annot_show` (xschem.h:2241) is per-context, but
# annot_show_sync_cache() (actions.c:1321-1325) does
# `xctx->annot_show = tclgetintvar("annot_show")` at all eight bulk-evaluation
# entry points -- the C field is a per-frame PULL-CACHE of the one global Tcl
# var. Probe: after setting the mask to 3, a bare `set ::annot_show 0` still
# read back 3, and one `xschem update_all_sym_bboxes` made it 0. What makes the
# mask nevertheless behave per-context is that `annot_show` is a member of
# tctx::global_list (xschem.tcl), so the tab/window switch swaps the Tcl var and
# snapshots the outgoing one into `::tctx::<win_path>(...)`.
#
# DECISION D2, and it is why nothing here is session-scoped: the mask STAYS per
# design context. Making it per-ASE-session means teaching that C pull, at all
# eight entry points, where a session's value lives -- and it would make `6` and
# this menu's tick describe different things, which is worse than the problem.
# The ASE-L control REACHES the session's design context instead.

# The `xschem windows` entry path of the window holding session `key`'s design,
# or {} when no window holds it. Same resolution ORDER as raise_design_editor --
# exact `current_name` first, then a window DESCENDED into the design (issue
# 0168) -- so the window this reads is the window annot_goto_design switches to.
proc ase::ui::annot_design_win {key} {
  set dpath [ase::ui::design_path $key]
  if {$dpath eq {}} { return {} }
  set wins {}
  if {[catch {xschem windows} wins]} { return {} }
  foreach e $wins {
    if {[catch {file normalize [lindex $e 4]} p]} { continue }
    if {$p eq $dpath} { return [lindex $e 0] }
  }
  foreach e $wins {
    foreach sp [lindex $e 6] {
      if {$sp eq {}} { continue }
      if {[catch {file normalize $sp} p]} { continue }
      if {$p eq $dpath} { return [lindex $e 0] }
    }
  }
  return {}
}

# The DESIGN context's annot_show mask, WITHOUT switching context (decision D7).
# 0 when the design is not open anywhere, or anything is unreadable.
#
# ⚠ NO CONTEXT SWITCH HERE, deliberately: the one caller is a menu
# -postcommand, i.e. code that runs while the menu is POSTING, and a switch
# does save_ctx/restore_ctx/housekeeping_ctx and moves focus -- a menu that
# mutates program state and moves focus while posting can unpost itself.
#
# ⚠ AND NOT $::annot_show EITHER: the Tcl mirror describes whichever context
# wrote it last, not the one this menu is about. For a NON-current window the
# honest source is that window's tctx snapshot -- `xschem windows` field 0 is
# both the win_path and the tctx array name (measured 2026-08-24: with .x1.drw
# non-current holding mask 2, `::tctx::.x1.drw(annot_show)` read exactly 2 while
# the current .drw read 0). The snapshot is EXACT, not approximate: every writer
# writes the CURRENT xctx, so a non-current window's mask cannot move between
# its save_ctx and this read.
proc ase::ui::annot_mask {key} {
  set win [ase::ui::annot_design_win $key]
  if {$win eq {}} { return 0 }
  set cur {}
  catch {set cur [xschem get current_win_path]}
  set m {}
  if {$cur ne {} && $cur eq $win} {
    if {[catch {xschem get annot_show} m]} { return 0 }
  } else {
    if {[catch {set ::tctx::${win}(annot_show)} m]} { return 0 }
  }
  if {![string is integer -strict $m]} { return 0 }
  return $m
}

# The submenu's -postcommand: GREY the two entries by the predicate, then PULL
# the two ticks out of the design's mask.
#
# ⚠ A PULL IS NOT OPTIONAL (decision D4, invariant I5). The three cadence chords
# (utils/annot_mode.tcl), both `Annotate Operating Point` menu items and a user's
# own rc all write this mask without telling any menu, so a design that needed
# every writer to remember this menu would show a stale tick the first time
# anyone pressed `6`. Same reasoning that put a -postcommand on the View submenu
# this control replaces.
#
# GREYING uses ase::has_results (ase.tcl), the ONE named predicate -- the same
# one issue 0683's reasoning about the orphan state names, so the two cannot
# drift apart.
proc ase::ui::annot_menu_sync {key} {
  variable wins
  variable annot
  if {![dict exists $wins $key]} { return }
  set m [dict get $wins $key].mb.results.annotate
  if {[catch {winfo exists $m} ex] || !$ex} { return }
  set hr 0
  catch {set hr [ase::has_results $key]}
  set st [expr {$hr ? {normal} : {disabled}}]
  catch {$m entryconfigure {Operating Point info} -state $st}
  catch {$m entryconfigure {DC Node Voltages}     -state $st}
  # 0868: the third entry greys and pulls with the other two. A sync that knew
  # about two bits and left the third alone would show a stale tick on the very
  # first Alt-Shift-6 the user pressed -- decision D4's reasoning, widened.
  catch {$m entryconfigure {Transient Node Voltages (at cursor)} -state $st}
  set mask [ase::ui::annot_mask $key]
  set annot($key,op)   [expr {($mask & 1) ? 1 : 0}]
  set annot($key,volt) [expr {($mask & 2) ? 1 : 0}]
  set annot($key,tran) [expr {($mask & 4) ? 1 : 0}]
  return
}

# Make session `key`'s design the CURRENT xschem context and VERIFY it. 1 on
# success, 0 when no window holds the design or the switch was refused.
#
# ⚠ LANDMINE 17 (wave_viewer.tcl:1352-1355): `xschem new_schematic switch`
# SILENTLY NO-OPS while the current context's semaphore is raised. A blind
# switch followed by a write lands the mask in a FOREIGN schematic -- an
# annotation toggle that silently annotates somebody else's sheet. So the switch
# is verified by comparing `xschem get current_win_path`, exactly as
# wviewer::switch_ctx does.
#
# `ifhidden`, not `always` (issue 0616): the `always` arm re-MAPs the toplevel,
# which on WSLg costs a ~32px NW creep per call -- a design window that jumped
# on every tick would be its own defect. A hidden or minimised design window is
# still brought back.
#
# It never OPENS a window: `Session > Design Window` is the seam that does that,
# and loading a schematic as a side effect of a visibility toggle would be a
# surprise out of all proportion to the gesture.
proc ase::ui::annot_goto_design {key} {
  set win [ase::ui::annot_design_win $key]
  if {$win eq {}} { return 0 }
  set cur {}
  catch {set cur [xschem get current_win_path]}
  if {$cur ne {} && $cur eq $win} { return 1 }
  set dpath [ase::ui::design_path $key]
  if {$dpath eq {}} { return 0 }
  catch {ase::ui::raise_design_editor $dpath ifhidden}
  set cur {}
  catch {set cur [xschem get current_win_path]}
  return [expr {$cur ne {} && $cur eq $win}]
}

# Attach the session's raw to the DESIGN context when it has none (decision D8).
# Caller must already be IN the design context.
#
# ⚠ WHY A VISIBILITY CONTROL LOADS ANYTHING AT ALL. MEASURED:
# `grep -rn 'annotate_op|raw_read' src/ase.tcl src/ase_window.tcl
# src/wave_viewer.tcl` returns NOTHING -- ASE-L never loads a raw into the DESIGN
# context (the waveform viewer attaches into its OWN context). So after a real
# `Netlist and Run` the design has no database, and a visibility-only tick would
# turn annotation on and render BLANKS (invariant I3), i.e. a control that looks
# dead on the very next bench run. That is the class of defect this batch is
# made of.
#
# ⚠ A DATABASE THE USER LOADED FROM SOMEWHERE ELSE IS NEVER THROWN AWAY, and
# that is now a property of the PREDICATE rather than of a blanket early return.
# `op_annot::db_current` answers "current, leave it alone" whenever the attached
# database is at a path other than this session's -- another corner's operating
# point, say -- because replacing it really would destroy it (`xschem
# annotate_op` deletes a 1-point op/dc it replaces, scheduler.c). Row W1a16 of
# tests/headless/test_ase_window.tcl is that claim's owner.
#
# ⚠ ISSUE 0684 IS FIXED HERE, AND THE GUARD IT REPLACED IS WHAT A READER WILL
# EXPECT TO FIND. This proc used to open with
#     set ld -1 ; catch {set ld [xschem raw loaded]}
#     if {$ld >= 0} { return }
# which answers "is SOME database attached", not "are THIS session's CURRENT
# results attached". Two defects fell out of it. (a) ngspice overwrites ONE
# stable raw path in place, so after a second run that early return kept the
# FIRST run's numbers on screen forever -- invariant I3's own phrase, "not the
# previous run's number". (b) An ordinary waveform graph's `xschem raw_read`
# leaves `raw loaded` = 0 with `raw annot` = -1, so the tick returned without
# annotating, the mask went on and NOTHING rendered -- and it was the one path
# here that echoed nothing, i.e. a dead-looking control.
#
#   GUARD G12  the currency question is the FIRST question and the ONLY early
#              return. `op_annot::db_current` (src/op_annot.tcl) is the mint;
#              every catch inside it falls to "re-attach", never to a return,
#              because `xschem raw rawfile` RAISES with nothing attached and an
#              early return on an unanswerable question is precisely how the old
#              guard painted run 1 forever. Row F28 of
#              tests/headless/test_annot_stale_0684.tcl greps this body and
#              requires `xschem raw loaded` to appear on no code line of it.
#
#   GUARD G13  RE-ATTACH OR BLANK. When the attached database is this surface's
#              and is out of date, it comes OFF before anything below can
#              refuse -- the 0838 staleness refusal, or a failed attach. A
#              refusal spoken over the previous run's numbers is RULING D5-1
#              with a caption, which is worse than the silent version because
#              the caption makes it look checked. The `$ann` term is what stops
#              this taking off a waveform graph the user is looking at: that
#              database is not something this surface attached or can paint
#              from, so defect B is repaired by ADDING ours beside it, not by
#              destroying theirs. Rows F24 and F25 -- and specifically F24's
#              LAST leg, which asks whether the graph is still in the registry
#              afterwards. ⚠ WITHOUT THAT LEG NOTHING SEES THE `$ann` TERM
#              (measured 2026-08-28): making the detach unconditional still
#              renders the numbers and still leaves the session's own file
#              current, so every other gold in every suite is satisfied while
#              the trace the user was looking at has been unloaded from under
#              their waveform window.
proc ase::ui::annot_ensure_loaded {key} {
  set path {}
  catch {set path [ase::last_rawfile $key]}
  set ann 0
  catch {set ann [::op_annot::_annotated]}
  if {[::op_annot::db_current $path]} { return }
  if {$ann} { ::op_annot::db_detach }
  if {$path eq {}} { return }
  # ⚠ issue 0838: A STALE RAW IS NOT ATTACHED. `last_rawfile` answers "the raw
  # path, if the file exists" and deliberately stays that loose — the three
  # WAVEFORM callers (:2118, :4035, :4583) are right to plot an old raw, and
  # refusing to plot last good run's traces after a failed netlist would be a
  # regression. ANNOTATION is the opposite case: a number painted onto a
  # schematic carries no provenance and no timestamp, so an out-of-date one is
  # indistinguishable from a live one. This is the door the user came through —
  # a failed run, then `6`, then id=/gm= from a run five minutes and one netlist
  # earlier. Ask the named predicate, and SAY SO rather than silently drawing
  # nothing.
  set stale 0
  catch {set stale [ase::results_stale $key]}
  if {$stale} {
    ## ⚠ ISSUE 0886 -- THIS SURFACE GETS ITS OWN WORDS, NOT THE MINT'S.
    ## Row V43 of tests/headless/test_op_annot.tcl requires the fragment "is
    ## older than the circuit it describes" to appear in utils/annot_mode.tcl
    ## and in NO other file, ase_window.tcl included, so pasting the mint's
    ## sentence here would red that row. It says the same thing about the same
    ## situation from ASE-L's own side, with the `ase:` prefix its channel uses.
    ## The file is still NAMED, because "not used" without saying which file is
    ## not something a user can act on (issue 0838's argument, unchanged).
    catch {::ase::echo "ase: [file tail $path] is from an earlier run than the circuit now on screen, so it was not used. Run the simulation again first." error}
    return
  }
  # the hierarchy LEVEL the raw refers to, from the same seam
  # cadence::_annot_raw_candidate uses (utils/annot_mode.tcl), so the two cannot
  # disagree about level semantics. Unknown -> let annotate_op decide.
  set level {}
  set s {}
  catch {set s [ase::session_for_current]}
  if {[llength $s] >= 2 && [lindex $s 0] eq $key} { set level [lindex $s 1] }
  ## ⚠ ONE CALL SITE NOW, AND THE FAILURE CAN ACTUALLY BE SPOKEN (issue 0684).
  ## There used to be two `xschem annotate_op` calls here, one with a level and
  ## one without, each inside its own `catch` -- and MEASURED, that catch never
  ## fires: annotate_op returns TCL_OK for a file that does not exist and for
  ## one that will not parse, so this surface's failure sentence could never
  ## reach a user. `op_annot::db_attach` verifies by RE-ASKING and hands back
  ## {ok reason}, so the sentence below is now reachable. Rows F26 and F32.
  set att [::op_annot::db_attach $path $level]
  if {![lindex $att 0]} {
    catch {::ase::echo [ase::ui::annot_fail_msg $path [lindex $att 1]] error}
  }
  return
}

# ISSUE 0684, THE HALF THAT REACHES THE DISPLAY WITH NO GESTURE AT ALL.
#
# ⚠ THIS IS WHAT REFUTED THE 2026-08-25 ATTEMPT, and a reader who only fixes the
# tick will re-ship the defect. That attempt made run completion drop the
# freshness stamp, so the cache stopped lying -- and the SCREEN kept painting
# run 1's number, because nothing re-attached. Issue 0684 section 7's own words:
# "what it must do is re-attach-or-blank, not merely invalidate." The user's
# gesture is: annotation is already on, the simulation is re-run, and with no
# key press and no tick the numbers must be the new ones or blank.
#
#   GUARD G15  ANNOTATION OFF -> NOTHING IS OWED. Attaching a raw is not a
#              neutral act -- it can destroy a 1-point op/dc it replaces -- and
#              the user's own ruling on 0684 was about what the TICK shows, not
#              about firing a data operation nobody asked for. Bits 0 and 1 are
#              this surface's; bit 2 is the transient chord's and is not this
#              seam's business. Row F29.
#   GUARD G16  THE BORROW ALWAYS GIVES THE CONTEXT BACK. Same discipline and
#              same reason as wviewer::enter_ctx: a borrow that entered and
#              never left would strand the user in another window's context with
#              the schematic still on screen (issue 0173's shape). And the switch
#              is VERIFIED, never assumed -- landmine 17: `new_schematic switch`
#              silently no-ops while the current context's semaphore is raised,
#              and a blind switch followed by a write lands the numbers in a
#              FOREIGN schematic. It never RAISES or opens a window either: a
#              finished run must not pop the design over the ASE-L window.
#              ⚠ THIS GUARD NEEDS TWO SCHEMATIC WINDOWS TO BE SEEN AT ALL, and
#              for a while it had none. The tick's own `annot_goto_design`
#              leaves the design current, so every fixture that drove this proc
#              entered it with cur == win and the borrow branch was dead code
#              under test -- both halves could be deleted with every suite
#              green (measured 2026-08-28, 12 of 12 calls). The witnesses are
#              rows W1a28 and W1a29 of tests/headless/test_ase_window.tcl,
#              which drive a finished run from a foreign tab; W1a29 stages the
#              refused switch through `xschem set semaphore`, the landmine
#              itself, and shows the numbers landing in the foreign schematic
#              when the verification is removed. Row F33 of
#              tests/headless/test_annot_stale_0684.tcl is the single-window
#              floor only: it cannot reach this branch, and says so.
proc ase::ui::annot_refresh_after_run {key} {
  set win [ase::ui::annot_design_win $key]
  if {$win eq {}} { return 0 }
  set cur {}
  catch {set cur [xschem get current_win_path]}
  if {$cur eq {}} { return 0 }
  set back 0
  if {$cur ne $win} {
    catch {xschem new_schematic switch $win}
    set now {}
    catch {set now [xschem get current_win_path]}
    if {$now eq {} || $now ne $win} { return 0 }
    set back 1
  }
  set did 0
  catch {set did [ase::ui::annot_refresh_here $key]}
  if {$back} { catch {xschem new_schematic switch $cur} }
  return $did
}

# The design-context half of the refresh. Caller must already BE in the design
# context; `annot_refresh_after_run` is the seam that arranges that.
#
# ⚠ IT GOES THROUGH `annot_ensure_loaded`, NOT ROUND IT (RULING D5-4). The tick
# and a finished run are the same question -- "are the numbers on this sheet the
# ones this session just produced" -- and one body answers it, so the 0838
# staleness refusal, the level resolution and the single failure sentence cannot
# drift between the two doors.
proc ase::ui::annot_refresh_here {key} {
  set m 0
  catch {set m [xschem get annot_show]}
  if {![string is integer -strict $m]} { set m 0 }
  if {($m & 3) == 0} { return 0 }
  ase::ui::annot_ensure_loaded $key
  catch {xschem update_all_sym_bboxes}
  catch {xschem redraw}
  return 1
}

# The deferred entry `run_finished` schedules. WHY `after idle`, and it is the
# same reason `auto_plot_idle` already carries: run_finished fires from the
# execute fileevent, which can be dispatched INSIDE ase::wait's semaphore
# bracket -- and with the current window's semaphore raised every
# `new_schematic switch` is a silent no-op (xinit.c switch_window), so the
# borrow above would run its whole body in the WRONG context and re-attach the
# session's raw to whatever window happened to be current. At idle time the
# bracket is balanced. The catch keeps an idle-time failure out of Tk's bgerror
# modal.
proc ase::ui::annot_refresh_idle {key} {
  catch {ase::ui::annot_refresh_after_run $key}
}

## THE ONE SENTENCE FOR "the engine refused to put these numbers on the sheet".
##
## ⚠ ISSUE 0886, RULING D5-4. It was written out TWICE, at the two
## `xschem annotate_op` call sites in `ase::ui::annot_ensure_loaded` -- one with
## a hierarchy level and one without -- which is one message with two places to
## edit and only a reader comparing them can tell they were meant to agree. Row
## A11-8 of tests/headless/test_op_annot.tcl greps for exactly one copy of the
## fragment "could not put the results from", and for zero copies of the old
## `ase: cannot annotate` spelling.
##
## ⚠ `$e` IS THE ENGINE'S OWN RAISE TEXT and is passed through unedited.
## It is the only part of this sentence that says WHICH thing went wrong, and
## paraphrasing it would leave the user a polite apology with no fact in it.
proc ase::ui::annot_fail_msg {path e} {
  return "ase: could not put the results from '$path' onto the schematic. The reason given was: $e"
}

# ISSUE 0868 -- make `cadence::annot_tran` reachable from a session that never
# loaded the cadence profile, and do it WITHOUT clobbering an existing
# definition. utils/ sits beside the installed share dir in a source tree; when
# neither candidate resolves the caller says so rather than doing nothing (the
# silence issue 0857 is about).
proc ase::ui::annot_tran_helper {} {
  if {[llength [info commands ::cadence::annot_tran]]} { return 1 }
  set sd {}
  catch {set sd [uplevel #0 {set XSCHEM_SHAREDIR}]}
  if {$sd eq {}} { return 0 }
  foreach cand [list [file join $sd .. utils annot_mode.tcl] \
                     [file join $sd utils annot_mode.tcl]] {
    if {[file isfile $cand]} {
      catch {uplevel #0 [list source $cand]}
      if {[llength [info commands ::cadence::annot_tran]]} { return 1 }
    }
  }
  return 0
}

# The two visibility checkbuttons' -command: PUSH the clicked bit into the
# DESIGN's mask. (The third entry, issue 0868, takes the request arm below.)
#
# ⚠ BIT-WISE FROM THE DESIGN'S LIVE VALUE (decision D6), never composed from
# both ticks. The ticks were painted by a PULL that ran BEFORE any context
# switch, so composing the whole mask from both of them can write a stale OTHER
# bit over the design's real value. The View pair this replaces could compose
# from both because pair and mask lived in the same context; this one does not.
#
# ⚠ ON A REFUSAL, THE TICK IS SNAPPED BACK. Tk has ALREADY flipped the variable
# by the time -command runs, so a refusal that merely writes nothing leaves the
# user looking at a ticked box over an un-annotated schematic.
#
# The mask is written THROUGH `xschem set` (S7 decision D4): a bare
# `set ::annot_show` leaves the C field stale until the next bulk sync. The bbox
# pass is not optional either -- an annotation block changes the instance's own
# bbox (select.c:709), the same reason `Show hidden texts` carries one.
#
# ⚠ THE DESIGN IS LEFT CURRENT ON PURPOSE -- this is NOT the wave_viewer
# enter_ctx/leave_ctx LOAN (issue 0173), and it must not be "fixed" into one.
# That bracket exists because switching into a VIEWER rewrites the viewer's wm
# title from its nameless read-only buffer; here the destination is the user's
# own design, and the gesture means "show me these numbers on that schematic".
# Putting the context back would leave the annotated sheet behind whatever was
# current when the user clicked.
proc ase::ui::annot_apply {key which} {
  variable annot
  set bit [expr {$which eq {op} ? 1 : ($which eq {volt} ? 2 : 4)}]
  if {![ase::ui::annot_goto_design $key]} {
    catch {::ase::echo "ase: this session's design window is not open, or switching to it was refused, so there is nothing to annotate. Session > Design Window opens it." error}
    ase::ui::annot_menu_sync $key
    return
  }
  set cur 0
  if {[catch {xschem get annot_show} cur]} { set cur 0 }
  if {![string is integer -strict $cur]} { set cur 0 }
  set want 0
  if {[info exists annot($key,$which)] && $annot($key,$which)} { set want 1 }
  # ISSUE 0868 -- TICKING THE TRANSIENT ENTRY IS A REQUEST, NOT A VISIBILITY
  # TOGGLE, so this arm composes NO mask of its own (RULING D5-4). The other two
  # bits describe numbers that are already published; bit2's are not published
  # until somebody asks, at a time point that has to be resolved from the
  # waveform viewer's cursors. So the work is handed to `cadence::annot_tran`
  # (utils/annot_mode.tcl), which resolves the cursor, publishes, mints the ONE
  # sentence and arms bit2 ITSELF. The `Alt-Shift-6` chord in
  # src/cadence_style_rc is the other door onto that same body.
  #
  # ⚠ ON A REFUSAL THE TICK SNAPS BACK, and that is the sync call below doing it:
  # Tk has ALREADY flipped the variable by the time this -command runs, so a mode
  # that declines (no cursor on, no transient loaded) and writes nothing would
  # otherwise leave the user looking at a ticked box over a mask with no bit2 in
  # it. Same shape as the unreachable-design arm above.
  #
  # ⚠ UNTICKING IS NOT ROUTED HERE. Clearing bit2 is pure visibility and falls
  # through to the bit-wise write below, so `Ctrl-6`, this entry and the mask all
  # agree about how the mode goes off.
  #
  # ⚠ THE HELPER IS SOURCED ON DEMAND. `cadence::*` lives in
  # utils/annot_mode.tcl, which only the CADENCE profile's rc sources -- and this
  # menu belongs to every ASE-L user. The source is attempted ONLY when the proc
  # is absent, so a test spy or a user's own override is never clobbered.
  if {$which eq {tran} && $want} {
    ase::ui::annot_tran_helper
    if {![llength [info commands ::cadence::annot_tran]]} {
      ## ⚠ ISSUE 0886 -- IT CANNOT BE MINTED IN utils/annot_mode.tcl, and a
      ## reader tidying the surface would move it there first. This is the
      ## sentence for the session where that file is ABSENT; a mint inside it
      ## could never render. It also stops naming the file to the user: the
      ## path is a fact about the installation, not an action the user can take.
      catch {::ase::echo "ase: transient annotation is not available in this installation. The helper it needs was not installed." error}
      ase::ui::annot_menu_sync $key
      return
    }
    catch {::cadence::annot_tran}
    catch {xschem update_all_sym_bboxes}
    catch {xschem redraw}
    ase::ui::annot_menu_sync $key
    return
  }
  set new [expr {($cur & ~$bit) | ($want ? $bit : 0)}]
  xschem set annot_show $new
  if {$new != 0} { ase::ui::annot_ensure_loaded $key }
  catch {xschem update_all_sym_bboxes}
  catch {xschem redraw}
  ase::ui::annot_menu_sync $key
  return
}

# `~` strip button / raise-or-open the session's waveform viewer (item 13,
# D13): no traces added; headless / unknown-session safe via the catch.
proc ase::ui::open_viewer {key} {
  ## ⚠ 0930: THIS USED TO BE A BARE `catch {wviewer::open $key}` -- one line that
  ## discarded both halves of what the user needs to see. `wviewer::open` builds
  ## a real toplevel and its own comments record a past raise out of
  ## `build_menubar` when the new window's context did not follow; a raise on
  ## that path leaves a half-built or vanished window and, behind a bare catch,
  ## NO message anywhere. The user reported exactly that shape -- "it launched a
  ## window which disappeared soon" -- with nothing in the log to say which arm
  ## ran. Still caught, because a viewer failure must not take the ASE-L window
  ## down with it, but now REPORTED.
  if {[catch {wviewer::open $key} err]} {
    catch {::ase::echo "ase: the waveform viewer could not be opened: $err" error}
    return 0
  }
  return 1
}

# ===========================================================================
# RESULTS BATCH ITEM 7 -- `Results > Select...`, THE ASE-L DIALOG.
# doc/claude/specs/results_selection.md section 6 (R401-R407), section 4 (the
# resolver), section 10 (the sentences) and section 15 (why Loaded comes
# first). doc/claude/results_batch/receipts/07-results-select-dialog.md.
#
# THIS IS THE DOOR ITEMS 1-6 BUILT THE ROOM BEHIND. Item 1 made `raw read`
# re-stamp, item 2 wrote the resolver and the registry readers, item 3 added
# the `xschem raw select` sub-verb, item 4 built `results::select` -- the ONE
# place that selects (R303) -- item 5 re-expressed the viewer's Location bar on
# it and item 6 finally WROTE the persisted slot. Nothing here selects: every
# gesture below ends in `results::select` and every sentence below is either
# the resolver's own or this proc's refusal.
#
# ⚠ ASE-L ONLY (user ruling U5, DECISIONS.md). The schematic editor is not a
# results holder and is not given a second door to become one, and NO CASCADE
# IS ADDED TO THE WAVEFORM VIEWER'S MENUBAR (R504/D12 -- test_wave_viewer G2
# freezes that cascade set at {File View Graph Cursors Options}).
#
# ⚠ MODELESS (R402): no `grab`, no `tkwait`, no vwait latch. The ASE dialog
# doctrine is stated at the head of this file's dialog scaffold -- "no
# grab/tkwait, which is what keeps them test-drivable" -- and this dialog is a
# BROWSING window, not a blocking question: R406 requires it to stay open and
# refresh, because comparing two runs means selecting twice.
#
# ⚠ THE WIDGETS ARE THE ASE HOUSE MIX (R403): plain Tk chrome (toplevel,
# labelframe, label, entry, button) painted by `ase::ui::apply_theme` from the
# locked `ase::palette`, plus `ttk::treeview -style Ase.Treeview` where a table
# is needed. NO COLOUR IS SPELLED HERE: every one comes through that single
# accessor, per the Calculator's RULING-1.
# ===========================================================================

# ---------------------------------------------------------------------------
# R407a -- CREW RULING (item 7, 2026-08-20). WHICH CONTEXT THE DIALOG READS,
# AND WHAT IT SAYS WHEN IT CANNOT.
#
# The registry is per-`Xschem_ctx` and tabs do not share one (F2, measured:
# src/xinit.c:1938/:2204/:2209), so "the loaded results" is only a question
# once you have said WHOSE. An ASE session's results live in ITS WAVEFORM
# VIEWER'S context: `wviewer::attach_raw` (src/wave_viewer.tcl:3888) does
# `switch_ctx $token` before `ase::attach_dbs` reads, and the viewer token IS
# the session key. So:
#
#   viewer arm -- the session HAS a viewer window: borrow it, the 0173 way
#                 (`enter_ctx $key 1` / `leave_ctx`), exactly as
#                 `wviewer::selected_rawfile` (:4072) does. A dialog is a
#                 browsing window and must not leave the user's context moved,
#                 which is why this is a LOAN and not `rawbar_load`'s move.
#   here arm   -- the session has NO viewer window (nothing has ever been
#                 attached for it): there is no other context to borrow, so
#                 the dialog reads the CURRENT one and SAYS SO, in the Loaded
#                 region's own title. Refusing to work before the first run
#                 would break the dialog's main use -- "I want to evaluate
#                 against last night's raw" happens before a run, not after.
#   refused    -- the ticket came back refused (F6): REPORTED AS REFUSED
#                 (R407), never as an empty list. That is the whole of F6's
#                 defect: a refusal that reads like an answer.
#
# Returns {ok 0|1 ticket <enter_ctx ticket or {}> where viewer|here msg <one
# sentence, only when refused>}. Never throws.
proc ase::ui::rsel_borrow {key} {
  set r [dict create ok 1 ticket {} where here msg {}]
  if {[catch {wviewer::window_for $key} wv]} { set wv {} }
  if {$wv eq {}} { return $r }
  if {[catch {wviewer::enter_ctx $key 1} t]} { set t {0 {}} }
  if {![lindex $t 0]} {
    dict set r ok 0
    dict set r where viewer
    dict set r msg "Could not read this session's loaded results: the\
 waveform viewer's context is busy — that is a refused context switch, not an\
 empty result list."
    return $r
  }
  dict set r ticket $t
  dict set r where viewer
  return $r
}

# The other half. A `here` borrow has no ticket and nothing to give back.
proc ase::ui::rsel_release {key b} {
  if {[catch {ase::state_get $b ticket} t]} { return 0 }
  if {$t eq {}} { return 1 }
  if {[catch {wviewer::leave_ctx $key $t} ok]} { return 0 }
  return $ok
}

# ---------------------------------------------------------------------------
# R404's two lists, as DATA. Widget-free on purpose: everything the dialog
# shows is computable and assertable without a DISPLAY, and `rsel_fill` below
# is the only proc that needs one.
#
#   Loaded  -- `results::list` (R304), one row per registry SLOT, the current
#              one marked. LISTED FIRST, DELIBERATELY INVERTING CADENCE
#              (R405/section 15): xschem already accumulates databases (F7's
#              declared cost), so "switch back to the one I had" is the common
#              case AND it is free; a file chooser is the fallback, not the
#              primary control.
#   Recent  -- `wviewer::rawhist_get` (src/wave_viewer.tcl:8389), newest first
#              (`rawhist_add` prepends), entries ALREADY IN THE REGISTRY
#              distinguished -- here by the same bullet the current slot
#              carries plus a tag, never by dropping them from the list.
#
# ⚠ R407c's clause (2) LIVES HERE: a Recent entry whose path normalises onto a
# loaded slot INHERITS THAT SLOT'S sim_type, so the select that follows is
# never typeless for a file the engine can already name. See rsel_type_for.
#
# ⚠ `results::_same_path` IS USED DELIBERATELY, private underscore and all.
# "Are these two spellings the same file?" is ruled ONCE, in R302a and R302h:
# `file normalize` decides it, an intermediate symlink converges and a
# FINAL-COMPONENT one does not, on purpose. A second copy of that predicate
# here would be a second place for the ruling to drift -- and drift is
# precisely how this file ends up marking a Recent entry "not loaded" while
# `results::select` lands on the slot it already has. The alternative (a public
# alias in `src/results.tcl`) was declined as a wider edit than item 7's fence
# allows; the coupling is named here instead of being hidden.
#
# Returns {ok .. where .. msg .. loaded {..} recent {..}}; on a refused ticket
# both lists are EMPTY and `ok 0` with the sentence -- the caller must render
# the refusal, not the emptiness (R407/F6).
proc ase::ui::rsel_rows {key} {
  set b [ase::ui::rsel_borrow $key]
  set out [dict create ok [ase::state_get $b ok 0] \
                       where [ase::state_get $b where here] \
                       msg [ase::state_get $b msg] loaded {} recent {}]
  if {![dict get $out ok]} { return $out }
  set loaded {}
  if {[catch {results::list} rows]} { set rows {} }
  foreach row $rows {
    set p [ase::state_get $row path]
    set t [ase::state_get $row type]
    lappend loaded [dict create kind loaded idx [ase::state_get $row idx] \
                      path $p type [ase::ui::rsel_type_norm $t] \
                      cur [ase::state_get $row cur 0] \
                      label [ase::state_get $row label]]
  }
  ase::ui::rsel_release $key $b
  # the MRU is a GLOBAL disk-backed list, not a per-context one, so it is read
  # outside the loan on purpose -- nothing about it depends on which context we
  # are standing in.
  set recent {}
  if {[catch {wviewer::rawhist_get} hist]} { set hist {} }
  foreach p $hist {
    if {[string trim $p] eq {}} continue
    set t {}
    set inreg 0
    foreach l $loaded {
      if {[results::_same_path [ase::state_get $l path] $p]} {
        set inreg 1
        set t [ase::state_get $l type]
        break
      }
    }
    set lab [file tail $p]
    if {$inreg} { catch {set lab [wviewer::db_label $p $t]} }
    lappend recent [dict create kind recent path $p type $t inreg $inreg label $lab]
  }
  dict set out loaded $loaded
  dict set out recent $recent
  return $out
}

# ---------------------------------------------------------------------------
# R407c -- CREW RULING (item 7, 2026-08-20). THE DIALOG NEVER SELECTS
# TYPELESSLY WHEN IT KNOWS A TYPE, AND IT DOES NOT GUESS ONE WHEN IT DOES NOT.
#
# THE QUESTION ITEM 4 LEFT OPEN (its receipt section 5): a TYPELESS select of a
# VCD or a table refuses, because with no type `read_rawfile_by_type()`
# dispatches to the SPICE parser and `extra_rawfile()` reports
# `no "<unspecified>" analysis` (src/save.c:2110). The MRU and the persistence
# slot store A PATH AND NOTHING ELSE, so a non-spice database that reaches the
# Recent list can never be re-read through R303's door. Item 7 is the first
# caller that can put such an entry in front of a user, so item 7 rules it.
#
# THE RULING, in three clauses:
#   (1) A LOADED ROW CARRIES ITS OWN TYPE and that type is what is passed. It
#       is the ENGINE's own token, from `results::list`, and it is per SLOT --
#       which matters, because one file read as `dc` and as `tran` is TWO rows
#       and one result (U11), and a by-path lookup would silently select the
#       wrong analysis of the right file. This is why the type travels with the
#       ROW and is not recomputed from the path at commit time.
#   (2) A RECENT OR TYPED PATH THAT NORMALISES ONTO A LOADED SLOT inherits that
#       slot's type (rsel_rows above). So a VCD is re-selectable by name for as
#       long as it is loaded -- which is the entire window in which R102 says
#       it is a database at all.
#   (3) OTHERWISE NO TYPE IS PASSED, AND NONE IS INVENTED. The engine then
#       means "first analysis found in the file", which is right for the spice
#       raws that are ~all of the MRU, and refuses a non-spice file that is not
#       loaded -- reported by `results::select`'s own refusal sentence, which
#       names the file and says the previous result is unchanged (T-D).
#
# TWO ALTERNATIVES WERE CONSIDERED AND REJECTED, and the reasons are the
# ruling's evidence:
#   * SNIFF THE TYPE FROM THE EXTENSION (`.vcd` -> `vcd`). That is a guess
#     dressed as knowledge: the reader table (`raw_reader_table[]`,
#     src/save.c:1660) is keyed by a TYPE TOKEN a caller declares, never by a
#     filename, and `table` databases carry no distinguishing extension at all.
#     A wrong guess is worse than no guess here, because passing an explicit
#     non-spice type makes `raw_select()` REFUSE a file that is loaded under
#     another analysis (R301b's guard, src/save.c:2466) -- so a sniff that got
#     it wrong would break the case clause (2) gets right.
#   * SHOW SUCH AN ENTRY DISABLED WITH A REASON. It cannot be identified
#     without the same sniff, so "disabled" would either be wrong or would grey
#     out every Recent entry that is not currently loaded -- which is most of
#     them, and every one of the spice ones would have worked.
# The residual case is therefore ONE MRU ENTRY of a digital database that is no
# longer loaded, refused with a sentence. That is inside section 16's declared
# non-goal ("independently selecting a VCD or table database"), not a gap this
# dialog opened: R102 says a VCD is not a result, and clause (2) keeps it
# reachable for exactly as long as it is a database.
#
# `rows` is `rsel_rows`'s loaded list (already read, under the loan). Returns
# the engine's sim_type or {}.
proc ase::ui::rsel_type_for {rows path} {
  if {[string trim $path] eq {}} { return {} }
  foreach l $rows {
    if {[catch {results::_same_path [ase::state_get $l path] $path} same]} continue
    if {$same} { return [ase::ui::rsel_type_norm [ase::state_get $l type]] }
  }
  return {}
}

# `<NULL>` IS NOT A TYPE TOKEN. It is `xschem raw info`'s rendering of a NULL
# `sim_type` (src/save.c's registry dump), so `results::list` hands it back
# verbatim and `wviewer::db_label` / `results::_is_result_type` both map it.
# Passing it on to `xschem raw select` would ask the engine for an analysis
# literally called `<NULL>`: `raw_type_is_non_spice()` says no, the spice dedupe
# loop compares it against every stored sim_type and matches none, and the verb
# falls through to a READ with a type no reader knows. Every type this dialog
# hands the door goes through here first, and an empty type is exactly L6's
# "any analysis of this file" -- which is also the only thing that can be meant
# by a slot with no sim_type at all (both name-lookup loops in
# `extra_rawfile()` skip such a slot, src/save.c:1934/:1985).
proc ase::ui::rsel_type_norm {t} {
  set t [string trim $t]
  if {$t eq {<NULL>}} { return {} }
  return $t
}

# ---------------------------------------------------------------------------
# THE ARMED CANDIDATE -- what `Select` acts on, and there is exactly one.
#
# Picking a row FILLS THE PATH ENTRY with that row's full path and records the
# row's own type (R407c clause 1). So the Path region is not a third source
# competing with the two lists: it is the single readout of the armed
# candidate, and `Select` always acts on what the user can see. When the entry
# has been edited away from the armed row the entry wins, and the type is
# re-derived by path (clause 2) -- an edited path is a different candidate.
proc ase::ui::rsel_arm {key path type kind} {
  variable dlg; variable wins
  set dlg($key,rselcand) [dict create path $path type \
                            [ase::ui::rsel_type_norm $type] kind $kind]
  if {[dict exists $wins $key]} {
    set e [dict get $wins $key].rsel.path.e
    if {[winfo exists $e]} {
      $e delete 0 end
      $e insert 0 $path
    }
  }
  return $dlg($key,rselcand)
}

# The candidate `Select`/double-click acts on: the armed row when the Path
# entry still shows it, else whatever the entry now holds. Widget-free when the
# dialog is not up (the armed record alone), so the whole gesture is drivable
# headlessly.
proc ase::ui::rsel_candidate {key {rows {}}} {
  variable dlg; variable wins
  set armed {}
  if {[info exists dlg($key,rselcand)]} { set armed $dlg($key,rselcand) }
  set typed {}
  set have_entry 0
  if {[dict exists $wins $key]} {
    set e [dict get $wins $key].rsel.path.e
    if {[winfo exists $e]} {
      set have_entry 1
      catch {set typed [string trim [$e get]]}
    }
  }
  if {!$have_entry} { return $armed }
  if {$armed ne {} && [ase::state_get $armed path] eq $typed} { return $armed }
  if {$typed eq {}} { return [dict create path {} type {} kind path] }
  return [dict create path $typed type [ase::ui::rsel_type_for $rows $typed] \
                     kind path]
}

# ---------------------------------------------------------------------------
# R407e -- CREW RULING (item 7, 2026-08-20). THE RESOLVER INPUTS THE DIALOG
# CAN HONESTLY SUPPLY, AND THE ONE IT REFUSES TO CREATE.
#
# R201a's input keys are all optional and this dialog can fill three of them:
# `rawfile` (the candidate), `key` (the session -- which supplies `derived` via
# `ase::last_rawfile`, already existence-gated) and `rundir`, so a RELATIVE
# path typed into the Path entry resolves the same way a stored one does.
#
# `netlist` -- the input that enables the MTIME half of `stale` (R201a, "older
# than the netlist it was produced from") -- is DERIVED, but only where doing
# so writes nothing: `ase::netlist` (src/ase.tcl:1663) is a REGENERATOR (it
# deletes the artifact, re-netlists and can `xschem load` the design) and
# `ase::rundir` (:1643) is a create-and-default helper that `file mkdir`s and
# rewrites the global `::netlist_dir` -- R602e already ruled that a READ may
# call neither. So the state's OWN `rundir` is read directly, `<rundir>/
# <cell>.spice` is the name `ase::netlist` writes (:1691), and it is passed
# ONLY when that file already exists. A session with no rundir simply gets the
# content half of `stale`, which is R201a's documented "absent" behaviour.
#
# THAT HALF IS WORTH THE SIX LINES: "this result is older than the netlist it
# was produced from" is exactly the question a Select dialog exists to answer,
# and it is the one verdict a user cannot reach by looking at the file list.
#
# ⚠ AND THE INPUT THIS DIALOG DELIBERATELY DOES *NOT* PASS: `key`. R201a says a
# `key` supplies the resolver's `derived` fallback via `ase::last_rawfile`, and
# `ase::last_rawfile` (src/ase.tcl:1952) reaches the ngspice backend's
# `raw_file` hook (:4777), which calls `ase::rundir` -- THE CREATE-AND-DEFAULT
# HELPER R602e was ruled about: it `file mkdir`s the state's rundir, and for an
# EMPTY rundir it falls through to `set_netlist_dir 0`, which creates
# `$USER_CONF_DIR/simulations` and rewrites the global `::netlist_dir`. A
# preview fires on every row click and (debounced) on typing, so passing `key`
# would make merely LOOKING at a candidate create a directory and move a global.
# Second reason, independent of the first: with no `derived` there is no
# fallback, and R407g means this dialog never takes one anyway -- a resolver
# answer promising a fall-back the dialog will refuse to perform would be a
# sentence that lies. `results::select` is handed the same dict for the same two
# reasons; R802's ASE channel is named by `host ase` outright, not inferred from
# a `key`.
proc ase::ui::rsel_resolve_input {key path} {
  set st [ase::session_state $key]
  set inp [dict create rawfile $path]
  set rd [ase::state_get $st rundir]
  if {[string trim $rd] ne {}} {
    dict set inp rundir $rd
    set cell [ase::ui::design_cell_name $key]
    if {$cell ne {}} {
      if {[catch {file join $rd $cell.spice} nl] == 0 && [file isfile $nl]} {
        dict set inp netlist $nl
      }
    }
  }
  return $inp
}

# ...and THE SAME RESOLUTION, ON ITS OWN, for the one caller that has to ask a
# question about the file rather than hand it to the resolver.
#
# ⚠ FIXER ROUND (item 7). `rsel_commit`'s R407g guard used to ask
# `file isfile $path` -- i.e. it tested a RELATIVE candidate against the
# PROCESS CWD while `rsel_preview`, one region above it, tested the same
# candidate against the session's `rundir` (through `results::resolve`, which
# joins the two: src/results.tcl's "relative paths resolve against the rundir").
# So a Loaded row the engine holds under a relative spelling -- `xschem raw
# read an.raw tran` keeps the spelling it was handed -- previewed as
# `Using an.raw.` and was then REFUSED by `Select` with `No such result file
# 'an.raw'`, while `results::select` handed the identical path selected it. The
# dialog's preview and its own button contradicted each other on one candidate,
# and R407g's own header says the guard exists so the resolver's DERIVED
# fallback cannot substitute a different file -- not to refuse files that are
# there. The guard now asks the preview's question.
#
# The ORIGINAL SPELLING is still what `results::select` is handed: R302a's "one
# spelling per run" is the door's ruling to make, and `results::_engine_spelling`
# is where it is made. This proc answers only "is the thing the user pointed at
# on disk?".
proc ase::ui::rsel_abs {key path {inp {}}} {
  if {[string trim $path] eq {}} { return $path }
  if {$inp eq {}} { set inp [ase::ui::rsel_resolve_input $key $path] }
  if {[catch {dict exists $inp rundir} hasrd] || !$hasrd} { return $path }
  if {[catch {file pathtype $path} pt]} { return $path }
  if {$pt eq {absolute}} { return $path }
  if {[catch {file join [dict get $inp rundir] $path} j]} { return $path }
  return $j
}

# R404's Status region: ONE SENTENCE, and for a highlighted candidate it is THE
# RESOLVER'S, IN THE RESOLVER'S OWN WORDS (section 10). It is deliberately not
# re-worded here: R805 fixes one sentence form per status and R803a made the
# resolver name the file by `file tail` precisely so this one-line region can
# hold it.
proc ase::ui::rsel_preview {key} {
  set rows {}
  set cand [ase::ui::rsel_candidate $key]
  set p [ase::state_get $cand path]
  if {[string trim $p] eq {}} {
    return [ase::ui::rsel_status $key "Pick a result, or type the path of one."]
  }
  if {[catch {results::resolve [ase::ui::rsel_resolve_input $key $p]} res]} {
    return [ase::ui::rsel_status $key "Could not resolve [file tail $p]."]
  }
  # R407h -- CREW RULING (item 7). THREE STATUSES SPEAK IN THE RESOLVER'S OWN
  # WORDS; `invalid` DOES NOT, AND THE PRECEDENT IS R501's ARM 3.
  # The resolver's two `invalid` sentences describe A FALL-BACK -- "no longer on
  # disk — falling back to X", or "and there is no other result to fall back
  # to". Both are right for a stored selection being restored, which is what
  # R202 wrote them for, and both are wrong here: R407g refuses a missing file
  # outright rather than substituting another one, so quoting them would promise
  # the user something the very next click will not do. `wviewer::rawbar_load`
  # made exactly this call for exactly this reason (its ARM 3 keeps its own
  # "no such file" ahead of the door, "because its sentence is about a stored
  # selection that has gone missing, and this one is about a typo in an entry
  # box the user is looking at"). `default`, `ok` and `stale` are quoted
  # verbatim -- R805 fixes one form per status and R803a shortened them to
  # `file tail` precisely so this one-line region could hold them.
  if {[ase::state_get $res status] eq {invalid}} {
    if {[ase::state_get $res reason] eq {unreadable}} {
      return [ase::ui::rsel_status $key \
                "The result file '[file tail $p]' cannot be read."]
    }
    return [ase::ui::rsel_status $key "No such result file '[file tail $p]'."]
  }
  return [ase::ui::rsel_status $key [ase::state_get $res msg]]
}

# ...and the same preview, DEBOUNCED, for the one caller that fires per
# keystroke. `results::resolve` stats the file AND asks
# `ase::raw_content_verdict` for the content half, which opens it and parses
# the first plot header -- bounded work, but not per-character work. The
# pending id is cancelled on close so no balloon or sentence can arrive after
# the window is gone.
#
# ⚠ FIXER ROUND (item 7). TWO CALLERS CANCEL AND ONE OF THEM IS THE COMMIT, so
# the cancel is a proc and not three copies of three lines. The defect it
# closes: `<Return>` on the Path entry fires `rsel_commit`, and the SAME
# keystroke then fires `<KeyRelease>` -- one physical Return is a KeyPress and
# a KeyRelease -- so 250 ms after the commit the debounced preview overwrote the
# door's own sentence (`Selected an.raw (tran).`) with the resolver's
# (`Using an.raw.`), in the Status region and in `dlg($key,rselstatus)`. That
# breaks R407b/R805b outright ("what the user just did was select, not
# resolve") on a shipped gesture, and after a REFUSED Return it erased the
# refusal and left a sentence that says the opposite of what happened.
#
# Both halves are closed, because they are two different races:
#   * the keystroke that COMMITS schedules nothing -- Return/KP_Enter/Escape
#     are the dialog's own gestures, not edits to the path, and there is
#     nothing to re-preview after them;
#   * a preview already pending from an EARLIER keystroke (type a character,
#     press Return 100 ms later) is cancelled by `rsel_commit` itself.
# Neither alone is enough: the first does not reach a pending timer, and the
# second cannot reach a timer scheduled after it returned.
proc ase::ui::rsel_preview_cancel {key} {
  variable dlg
  if {![info exists dlg($key,rselprevid)]} { return 0 }
  catch {after cancel $dlg($key,rselprevid)}
  unset dlg($key,rselprevid)
  return 1
}

proc ase::ui::rsel_preview_soon {key {keysym {}}} {
  variable dlg
  ase::ui::rsel_preview_cancel $key
  if {[lsearch -exact {Return KP_Enter Escape} $keysym] >= 0} { return {} }
  set dlg($key,rselprevid) [after 250 [list ase::ui::rsel_preview $key]]
  return $dlg($key,rselprevid)
}

# The Status region, and the record behind it. The record is kept whether or
# not a widget exists so the sentence is assertable headlessly -- the same
# reason `results::select` returns its `msg` instead of only emitting it.
proc ase::ui::rsel_status {key msg} {
  variable dlg; variable wins
  set dlg($key,rselstatus) $msg
  if {[dict exists $wins $key]} {
    set l [dict get $wins $key].rsel.status
    if {[winfo exists $l]} { catch {$l configure -text $msg} }
  }
  return $msg
}

# ---------------------------------------------------------------------------
# R406 -- ONE GESTURE, ONE COMMIT PATH. Double-click and the `Select` button
# both end here (searchbar_fire's rule: no route may apply a policy another
# route skips), and THE DIALOG STAYS OPEN AND REFRESHES, because comparing two
# runs means selecting twice.
#
# THE ORDER, and every step of it is somebody else's ruling being obeyed:
#   1. the armed candidate, read ONCE (rsel_candidate);
#   2. R407g's own arm -- a path that is not a file is refused HERE, ahead of
#      the door. `results::resolve` would answer `invalid` and hand back the
#      DERIVED result instead (R202's "never make a session unopenable"), which
#      is right for a session restore and wrong for a browsing gesture: the
#      user picked THIS file and must not be given a different one. This is
#      `wviewer::rawbar_load`'s ARM 3 (:8640) and its reasoning, verbatim in
#      shape;
#   3. the borrow (R407a) -- a refused ticket is reported as refused;
#   4. `capture_live_view_state` before the door, issue 0194's rule: a
#      selection replaces the DATA, not the plot, so the regenerate below owes
#      the fold and skip_ranges is what re-autozooms the incoming raw;
#   5. THE DOOR (R303) -- `results::select`, with the type R407c ruled and
#      `host ase` (R802: ASE-L's channel is `ase::echo`);
#   6. the regenerate, INSIDE the loan (R407f below);
#   7. the sentence -- the door's own `msg`, in this dialog's Status region as
#      well as on the session channel, and a refill so the marks move.
#
# ⚠ R407f -- CREW RULING (item 7). THE REDRAW HAPPENS INSIDE THE LOAN.
# `wviewer::regenerate` goes through `with_edit`, which does its own
# `switch_ctx` and deliberately does NOT restore the context -- that is right
# for `rawbar_load`, whose gesture belongs to the viewer window, and wrong
# here: this dialog belongs to the ASE window and R407's borrow idiom exists so
# that reading and selecting from it cannot leave the user's current context
# somewhere else. Run inside the bracket, the switch is a no-op (we are already
# there) and `leave_ctx` still puts everything back. It runs AFTER the door
# returns, so nothing redraws while the current-database pointer is moving
# (L7), and it is `catch`ed because a dialog may not throw (R801).
#
# Returns 1 when the engine selected something, 0 on any refusal.
proc ase::ui::rsel_commit {key} {
  variable wins
  # the door's sentence is the LAST word on this gesture -- no debounced
  # preview scheduled before it may land on top of it (see rsel_preview_soon).
  ase::ui::rsel_preview_cancel $key
  set b [ase::ui::rsel_borrow $key]
  if {![ase::state_get $b ok 0]} {
    ase::ui::rsel_status $key [ase::state_get $b msg]
    return 0
  }
  set rows {}
  if {[catch {results::list} rl] == 0} {
    foreach row $rl {
      lappend rows [dict create path [ase::state_get $row path] \
                     type [ase::ui::rsel_type_norm [ase::state_get $row type]]]
    }
  }
  set cand [ase::ui::rsel_candidate $key $rows]
  set path [string trim [ase::state_get $cand path]]
  if {$path eq {}} {
    ase::ui::rsel_release $key $b
    ase::ui::rsel_status $key "Pick a result, or type the path of one."
    return 0
  }
  # R407g, asked the way the PREVIEW asks it: a relative candidate is resolved
  # against the session's rundir first (rsel_abs), so the guard and the Status
  # region can no longer disagree about the same file.
  set opts [ase::ui::rsel_resolve_input $key $path]
  set abs [ase::ui::rsel_abs $key $path $opts]
  if {![file isfile $abs]} {
    ase::ui::rsel_release $key $b
    ase::ui::rsel_status $key "No such result file '[file tail $path]' —\
 nothing was selected."
    return 0
  }
  # R407c clause (2): a candidate that carries no type of its own -- a Recent
  # entry that was not loaded when the list was built, a Browse result, a typed
  # path -- inherits the type of the slot it normalises onto, if any. Clause
  # (1)'s row type is already set and is NOT re-derived: one file read as `dc`
  # and as `tran` is two rows and one result (U11), and a by-path lookup would
  # answer the first row for both.
  # clause (2) is asked of the RESOLVED path for the same reason the guard is:
  # `results::_same_path` normalises both sides against the CWD, so a relative
  # candidate would otherwise match no loaded slot and be passed typeless.
  set type [ase::ui::rsel_type_norm [ase::state_get $cand type]]
  if {$type eq {}} { set type [ase::ui::rsel_type_for $rows $abs] }
  dict unset opts rawfile
  dict set opts host ase
  set haswin [expr {[wviewer::window_for $key] ne {}}]
  if {$haswin} {
    dict set opts token $key
    catch {wviewer::capture_live_view_state $key}
  }
  if {[catch {results::select $path $type $opts} res]} { set res {} }
  set how [ase::state_get $res how refused]
  if {$how ne {refused} && $haswin} { catch {wviewer::regenerate $key} }
  ase::ui::rsel_release $key $b
  set msg [ase::state_get $res msg]
  if {$msg eq {}} {
    set msg "Could not select [file tail $path] — nothing was loaded and the\
 previous result is unchanged."
  }
  ase::ui::rsel_status $key $msg
  # R406: the dialog STAYS OPEN and refreshes -- the current-slot mark has
  # moved, and a first select of a new file has added a row to both lists.
  ase::ui::rsel_fill $key
  return [expr {$how eq {refused} ? 0 : 1}]
}

# ---------------------------------------------------------------------------
# The two list widgets, filled from `rsel_rows`. Every row's data is recorded
# under `dlg($key,rselmap,<which>,<item>)` so a click reaches the row's PATH
# and its own TYPE (R407c clause 1) without re-deriving either from the text a
# treeview cell happens to show.
proc ase::ui::rsel_fill {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return 0 }
  set w [dict get $wins $key].rsel
  if {![winfo exists $w]} { return 0 }
  set data [ase::ui::rsel_rows $key]
  array unset dlg $key,rselmap,*
  foreach which {loaded recent} {
    set tv $w.$which.tv
    if {![winfo exists $tv]} continue
    catch {$tv delete [$tv children {}]}
  }
  # R405: Loaded first, and its title says WHOSE registry it is (R407a).
  set ttl {Loaded}
  switch -- [ase::state_get $data where here] {
    viewer { set ttl {Loaded — this session's viewer} }
    here   { set ttl {Loaded — current window} }
  }
  if {![ase::state_get $data ok 0]} { set ttl {Loaded — unavailable} }
  catch {$w.loaded configure -text $ttl}
  if {![ase::state_get $data ok 0]} {
    ase::ui::rsel_status $key [ase::state_get $data msg]
    return 0
  }
  set i 0
  foreach row [ase::state_get $data loaded] {
    set id L$i; incr i
    set mark [expr {[ase::state_get $row cur 0] ? "\u2022" : {}}]
    $w.loaded.tv insert {} end -id $id \
      -values [list $mark [ase::state_get $row label]] \
      -tags [expr {[ase::state_get $row cur 0] ? {cur} : {plain}}]
    set dlg($key,rselmap,loaded,$id) $row
  }
  set i 0
  foreach row [ase::state_get $data recent] {
    set id R$i; incr i
    set mark [expr {[ase::state_get $row inreg 0] ? "\u2022" : {}}]
    $w.recent.tv insert {} end -id $id \
      -values [list $mark [ase::state_get $row label]] \
      -tags [expr {[ase::state_get $row inreg 0] ? {inreg} : {plain}}]
    set dlg($key,rselmap,recent,$id) $row
  }
  # first fill of a session: arm the CURRENT result, so the Status region has
  # something true to say the moment the dialog opens.
  if {![info exists dlg($key,rselcand)]} {
    foreach row [ase::state_get $data loaded] {
      if {[ase::state_get $row cur 0]} {
        ase::ui::rsel_arm $key [ase::state_get $row path] \
          [ase::state_get $row type] loaded
        ase::ui::rsel_preview $key
        break
      }
    }
  }
  return 1
}

# <<TreeviewSelect>>: arm the clicked row and preview its verdict. The other
# list's selection is cleared so the armed candidate is never ambiguous; the
# suppress flag is `pane_selected`'s (libmgr::suppress_select) idiom, because
# clearing re-fires this handler.
proc ase::ui::rsel_pick {key which} {
  variable wins; variable dlg
  if {[info exists dlg($key,rselsupp)] && $dlg($key,rselsupp)} { return {} }
  if {![dict exists $wins $key]} { return {} }
  set w [dict get $wins $key].rsel
  set tv $w.$which.tv
  if {![winfo exists $tv]} { return {} }
  set sel [$tv selection]
  if {$sel eq {}} { return {} }
  set dlg($key,rselsupp) 1
  set other [expr {$which eq {loaded} ? {recent} : {loaded}}]
  if {[winfo exists $w.$other.tv]} { catch {$w.$other.tv selection set {}} }
  set dlg($key,rselsupp) 0
  set id [lindex $sel 0]
  if {![info exists dlg($key,rselmap,$which,$id)]} { return {} }
  set row $dlg($key,rselmap,$which,$id)
  ase::ui::rsel_arm $key [ase::state_get $row path] [ase::state_get $row type] \
    [ase::state_get $row kind $which]
  ase::ui::rsel_preview $key
  return $row
}

# R406's other half of the ONE gesture. Binding <Double-1> is legal; only
# `event generate <Double-1>` is refused, which is why the tests replay two
# press/release pairs.
proc ase::ui::rsel_dblclick {key which} {
  if {[ase::ui::rsel_pick $key $which] eq {}} { return 0 }
  return [ase::ui::rsel_commit $key]
}

# ---------------------------------------------------------------------------
# R404's balloon: THE FULL PATH, on the row under the pointer.
#
# `balloon` (src/xschem.tcl:14826) is the tree's ONE tooltip mechanism and it
# BAKES its string into a widget's <Enter> binding at attach time, so it cannot
# carry a PER-ROW string. The renderer underneath it, `balloon_show`, can --
# it takes the text as an argument -- so this is that renderer driven from a
# <Motion> handler rather than a second tooltip mechanism.
#
# ⚠ DECLARED LIMIT: `balloon_show` returns early unless the X pointer is
# physically over the widget (`winfo containing [winfo pointerxy .]`), so the
# rendered balloon is not drivable from a script; what IS driven is the text
# the handler resolves and schedules (recorded in `dlg($key,rseltip)`) and the
# binding that reaches it. The pixels are part of item 7's eyeball debt.
proc ase::ui::rsel_tip_text {key which item} {
  variable dlg
  if {![info exists dlg($key,rselmap,$which,$item)]} { return {} }
  return [ase::state_get $dlg($key,rselmap,$which,$item) path]
}

proc ase::ui::rsel_tip_show {W txt} {
  catch {balloon_show $W $txt 0}
}

proc ase::ui::rsel_tip {key which W x y} {
  variable dlg
  set item {}
  catch {set item [$W identify row $x $y]}
  set txt {}
  if {$item ne {}} { set txt [ase::ui::rsel_tip_text $key $which $item] }
  if {[info exists dlg($key,rseltip)] && $dlg($key,rseltip) eq $txt} { return $txt }
  ase::ui::rsel_tip_cancel $key $W
  set dlg($key,rseltip) $txt
  if {$txt eq {}} { return {} }
  set dlg($key,rseltipid) [after 700 [list ase::ui::rsel_tip_show $W $txt]]
  return $txt
}

proc ase::ui::rsel_tip_cancel {key W} {
  variable dlg
  if {[info exists dlg($key,rseltipid)]} {
    catch {after cancel $dlg($key,rseltipid)}
    unset dlg($key,rseltipid)
  }
  set dlg($key,rseltip) {}
  catch {destroy $W.balloon}
  return 1
}

# ---------------------------------------------------------------------------
# R404's Path region. `select_raw` (src/xschem.tcl:16672) is REUSED, not
# reimplemented -- it is the tree's only `.raw` file chooser.
#
# ⚠ LANDMINE L1: it does NOT return {} headlessly. It computes a guessed
# default (`$netlist_dir/<current cell>.raw`) FIRST and only overwrites it with
# `tk_getOpenFile` inside `if {[info exists has_x]}`, so a script that calls it
# gets a plausible path and no cancel. Browse therefore only ARMS the entry --
# it never selects -- so even a bogus return costs the user a filled entry and
# nothing else, and the tests shim it.
proc ase::ui::rsel_browse {key} {
  variable wins
  if {![dict exists $wins $key]} { return {} }
  set p {}
  if {[catch {select_raw} p]} { return {} }
  set p [string trim $p]
  if {$p eq {}} { return {} }
  ase::ui::rsel_arm $key $p [ase::ui::rsel_type_for {} $p] path
  ase::ui::rsel_preview $key
  return $p
}

# ESC and the `Close` button, through ONE path (the listdlg_open rule): a bare
# destroy would leave the per-window records and a pending balloon behind.
proc ase::ui::rsel_close {key} {
  variable wins; variable dlg
  if {[dict exists $wins $key]} {
    set w [dict get $wins $key].rsel
    foreach which {loaded recent} {
      if {[winfo exists $w.$which.tv]} { ase::ui::rsel_tip_cancel $key $w.$which.tv }
    }
    catch {destroy $w}
  }
  ase::ui::rsel_preview_cancel $key
  array unset dlg $key,rselmap,*
  catch {unset dlg($key,rselcand)}
  catch {unset dlg($key,rselsupp)}
  catch {unset dlg($key,rseltip)}
  # ⚠ FIXER ROUND (item 7): `rselstatus` goes with them. This proc's own header
  # says a bare destroy "would leave the per-window records behind"; it was
  # leaving exactly one of them -- the sentence -- so a reopened dialog could
  # be read back holding the verdict of a candidate from the previous session
  # of the window before its first fill.
  catch {unset dlg($key,rselstatus)}
  return 1
}

# ---------------------------------------------------------------------------
# R401/R402/R403/R404 -- THE WINDOW. Modeless, ASE-themed, regions in R404's
# order top to bottom: Loaded, Recent, Path, Status, Buttons. Gridded, so the
# ORDER is a property of the window and not of the order the widgets happened
# to be created in -- and so a test can assert it (`grid info -row`), which is
# what R405/D2 needs.
#
# Re-invoking the menu entry RAISES and REFRESHES the existing window rather
# than rebuilding it: a modeless dialog the user has moved and sized must not
# jump back to the origin because they hit the menu twice.
proc ase::ui::rsel_dialog {key} {
  variable wins
  if {![dict exists $wins $key]} { return {} }
  if {![info exists ::has_x] || [info commands winfo] eq {}} { return {} }
  set w [dict get $wins $key].rsel
  if {[winfo exists $w]} {
    catch {raise $w}
    ase::ui::rsel_fill $key
    return $w
  }
  toplevel $w
  set cell [ase::ui::design_cell_name $key]
  wm title $w [expr {$cell eq {} ? {Select Results} : "Select Results — $cell"}]
  grid columnconfigure $w 0 -weight 1

  # --- R405: LOADED FIRST. This is the primary control, not the chooser.
  labelframe $w.loaded -text {Loaded}
  ase::ui::rsel_build_list $key $w loaded
  grid $w.loaded -row 0 -column 0 -sticky nsew -padx 6 -pady {6 2}
  grid rowconfigure $w 0 -weight 2

  labelframe $w.recent -text {Recent}
  ase::ui::rsel_build_list $key $w recent
  grid $w.recent -row 1 -column 0 -sticky nsew -padx 6 -pady 2
  grid rowconfigure $w 1 -weight 1

  frame $w.path
  label $w.path.l -text {Path:} -anchor w
  entry $w.path.e -width 44 -font AseEntryFont
  button $w.path.browse -text "Browse\u2026" \
    -command [list ase::ui::rsel_browse $key]
  pack $w.path.l -side left -padx {0 4}
  pack $w.path.browse -side right -padx {6 0}
  pack $w.path.e -side left -fill x -expand 1
  grid $w.path -row 2 -column 0 -sticky we -padx 6 -pady 2

  # R404's Status region: ONE line, and it is the resolver's sentence.
  label $w.status -anchor w -justify left -text {}
  grid $w.status -row 3 -column 0 -sticky we -padx 6 -pady 2

  # R404: `Select` and `Close`, and NO OK/Apply pair -- selecting is not a
  # form submission, and the dialog does not close on it (R406).
  frame $w.btns
  button $w.btns.select -text Select -command [list ase::ui::rsel_commit $key]
  button $w.btns.close -text Close -command [list ase::ui::rsel_close $key]
  pack $w.btns.select -side left -padx 5
  pack $w.btns.close -side right -padx 5
  grid $w.btns -row 4 -column 0 -sticky we -padx 6 -pady {2 6}

  bind $w.path.e <Return> [list ase::ui::rsel_commit $key]
  bind $w.path.e <KeyRelease> [list ase::ui::rsel_preview_soon $key %K]
  # R402: modeless -- ESC dismisses through the SAME path as Close, and there
  # is no grab and no tkwait anywhere in this proc.
  ase::ui::bind_dialog_esc $w [list ase::ui::rsel_close $key]
  wm protocol $w WM_DELETE_WINDOW [list ase::ui::rsel_close $key]
  ase::ui::apply_theme $w
  # tag colours AFTER apply_theme (which sets the Ase.Treeview style) and
  # through the single accessor only -- R403 / the Calculator's RULING-1.
  foreach which {loaded recent} {
    catch {$w.$which.tv tag configure cur -foreground [ase::theme accent]}
    catch {$w.$which.tv tag configure inreg -foreground [ase::theme accent]}
    catch {$w.$which.tv tag configure plain -foreground [ase::theme fieldfg]}
  }
  ase::ui::rsel_fill $key
  return $w
}

# One themed list: the ASE pane shape (ttk::treeview + scrollbar), two columns
# -- the current/loaded MARK and the `db_label` (file tail + analysis, R803).
proc ase::ui::rsel_build_list {key w which} {
  set f $w.$which
  ttk::treeview $f.tv -columns {mark result} -show headings \
    -selectmode browse -height [expr {$which eq {loaded} ? 6 : 5}] \
    -style Ase.Treeview -yscrollcommand [list $f.sb set]
  $f.tv heading mark -text {}
  $f.tv heading result -text {Result}
  # already the right SHAPE before issue 1398 — one fixed flag column, one
  # stretchy content column — so all it needed was the two pixel constants
  # derived from the font and a -minwidth on each.
  $f.tv column mark -width [ase::ui::colw 2 {}] \
                    -minwidth [ase::ui::colw 2 {}] -anchor center -stretch 0
  $f.tv column result -width [ase::ui::colw 34 Result] \
                      -minwidth [ase::ui::colw 0 Result] -anchor w -stretch 1
  scrollbar $f.sb -orient vertical -command [list $f.tv yview]
  pack $f.sb -side right -fill y
  pack $f.tv -side left -fill both -expand 1
  bind $f.tv <<TreeviewSelect>> [list ase::ui::rsel_pick $key $which]
  bind $f.tv <Double-1> [list ase::ui::rsel_dblclick $key $which]
  bind $f.tv <Motion> [list ase::ui::rsel_tip $key $which %W %x %y]
  bind $f.tv <Leave> [list ase::ui::rsel_tip_cancel $key %W]
  return $f.tv
}

# The Add/Edit Output dialog's "From Design…" button: flavor = the dialog's
# current Plot/Save checkboxes with save coerced to 1 when both are 0 (a
# plot-only row would be DEAD — render_deck emits .save/print only for rows
# with save 1), then the dialog closes (typed name/expr are DISCARDED —
# choose-from-design replaces manual entry) and the mode starts.
proc ase::ui::output_editor_from_design {key} {
  variable edchk
  set p [expr {[info exists edchk($key,plot)] && $edchk($key,plot) ? 1 : 0}]
  set s [expr {[info exists edchk($key,save)] && $edchk($key,save) ? 1 : 0}]
  if {!$p && !$s} { set s 1 }
  ase::ui::output_editor_cancel $key
  ase::ui::select_on_design $key [list save $s plot $p]
}

# Context Edit… on the variables pane: editor on the FIRST selected row.
proc ase::ui::edit_variable_first {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set tv [dict get $wins $key].body.vars.tv
  set sel {}
  if {[winfo exists $tv]} { set sel [$tv selection] }
  if {$sel eq {}} {
    catch {::ase::echo "ase: nothing selected"}
    return
  }
  ase::ui::variable_editor $key [lindex $sel 0]
}

# Context Edit… on the outputs pane: editor on the FIRST selected row.
proc ase::ui::edit_output_first {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set tv [dict get $wins $key].body.outs.tv
  set sel {}
  if {[winfo exists $tv]} { set sel [$tv selection] }
  if {$sel eq {}} {
    catch {::ase::echo "ase: nothing selected"}
    return
  }
  ase::ui::output_editor $key [lindex $sel 0]
}

# Context Edit… on the analyses pane: Choose Analyses preselected on the
# FIRST selected row's type (with several same-type rows the dialog
# addresses the first row of that type; extras remain X-deletable in the
# pane).
proc ase::ui::edit_analysis_first {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set tv [dict get $wins $key].body.ana.tv
  set sel {}
  if {[winfo exists $tv]} { set sel [$tv selection] }
  if {$sel eq {}} {
    catch {::ase::echo "ase: nothing selected"}
    return
  }
  set rows [ase::state_get [ase::session_state $key] analyses]
  set idx [lindex $sel 0]
  set type {}
  if {[string is integer -strict $idx] && $idx >= 0 && $idx < [llength $rows]} {
    set type [ase::state_get [lindex $rows $idx] type]
  }
  ase::ui::choose_analyses $key $type
}

# Variables > Edit… (menu): per-row editor on the first selected variables
# row, or the Add Variable dialog when nothing is selected.
proc ase::ui::edit_variables {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set tv [dict get $wins $key].body.vars.tv
  set sel {}
  if {[winfo exists $tv]} { set sel [$tv selection] }
  if {$sel ne {}} {
    ase::ui::variable_editor $key [lindex $sel 0]
  } else {
    ase::ui::add_variable_dialog $key
  }
}

# --- item 07 dialogs ---------------------------------------------------------
# The v2 menu-tree dialogs. Same doctrine as the item-06 editors: MODELESS,
# themed via apply_theme, deterministic widget paths, per-key records in the
# `dlg` array cleaned on proceed/cancel AND in ase::ui::close, every entry
# proc guarded on the session window's existence, Return = proceed.

# type-to-filter for a ttk::combobox (the copy_current_cell_dialog idiom):
# prefix-filter the stored FULL value list against the typed text;
# no matches -> offer the full list again.
proc ase::ui::combo_filter {cb full} {
  if {![winfo exists $cb]} { return }
  set typed [string trim [$cb get]]
  set matches {}
  foreach v $full {
    if {$typed eq {} || [string match -nocase ${typed}* $v]} {
      lappend matches $v
    }
  }
  if {![llength $matches]} { set matches $full }
  $cb configure -values $matches
}

# The first-selected value of a listbox, or {}.
proc ase::ui::lb_sel {lb} {
  set s [$lb curselection]
  if {$s eq {}} { return {} }
  return [$lb get [lindex $s 0]]
}

# Select `val` in listbox `lb` by exact match, make it active and scroll it
# into view. Returns 1 when the value was in the list, 0 when it was not --
# callers use the 0 to fall back rather than guess. Note this does NOT fire
# <<ListboxSelect>> (Tk raises that for user selection only), so a caller
# that depends on a selection handler must invoke it by hand.
proc ase::ui::lb_select_value {lb val} {
  if {$val eq {}} { return 0 }
  set i [lsearch -exact [$lb get 0 end] $val]
  if {$i < 0} { return 0 }
  $lb selection clear 0 end
  $lb selection set $i
  $lb activate $i
  $lb see $i
  return 1
}

# --- (h) shared confirm ------------------------------------------------------

# Modeless themed confirm (NOT tk_messageBox — a modal grab would kill test
# drivability, the item-06 modeless doctrine): label + OK/Cancel,
# Return = proceed. Proceed destroys the popup FIRST, then runs `oncmd` at
# global level; Cancel just destroys. Re-open replaces any live confirm.
proc ase::ui::confirm {key title msg oncmd} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].confirm
  catch {destroy $w}
  toplevel $w
  wm title $w $title
  label $w.msg -text $msg -font AseLabelFont -justify left -anchor w
  pack $w.msg -side top -fill x -padx 12 -pady 10
  frame $w.btns
  button $w.btns.proceed -text OK -command [list ase::ui::confirm_ok $w $oncmd]
  button $w.btns.cancel -text Cancel -command [list destroy $w]
  pack $w.btns.proceed -side left -padx 5
  pack $w.btns.cancel -side right -padx 5
  pack $w.btns -side bottom -fill x -padx 8 -pady 6
  bind $w <Return> [list ase::ui::confirm_ok $w $oncmd]
  # item 10: ESC = the Cancel destroy — oncmd must NOT run
  ase::ui::bind_dialog_esc $w [list destroy $w]
  ase::ui::apply_theme $w
  focus $w.btns.proceed
  return $w
}

proc ase::ui::confirm_ok {w oncmd} {
  catch {destroy $w}
  uplevel #0 $oncmd
}

# --- (a) Choose Analyses -----------------------------------------------------

# The dialog's quick fields per analysis type -- now ONE ORDERED LIST read from
# the registry, serving the form order, the Arguments-column order and the emit
# slot order at once. Two lists is exactly how `ac`'s `dec` drifted: this proc
# used to return `{points start stop}` while `anaargs` advertised a fourth field
# the deck hardwired and ignored.
proc ase::ui::chana_fields {type {sim {}}} {
  if {$sim eq {}} { set sim [ase::default_simulator] }
  return [ase::analysis_field_names $sim $type]
}

# The FIRST state row of `type` (the row the dialog addresses; extra
# same-type rows stay X-deletable in the pane), or a fresh disabled stub.
proc ase::ui::chana_row {key type} {
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    if {[ase::state_get $a type] eq $type} { return $a }
  }
  return [dict create type $type enabled 0]
}

# Choose Analyses (menu Analyses > Choose…, strip OP,TR, ana ctx Add…/Edit…,
# ana double-click): top radio section picks the analysis type, bottom form
# = Enable + the type's quick fields, `Options…` opens the extra-key editor.
# `type` {} preselects op.
# THE GLYPH THAT CARRIES A CELL'S STATE. Issue 1411.
#
# ⚠ A GLYPH AND NOT A COLOUR, AND NOT BY PREFERENCE. `ase::ui::_theme_widget`'s
# Radiobutton arm rewrites `-background` and `-foreground`, and
# `ase::ui::populate` ends in `apply_theme $top`, which recurses into this child
# toplevel on EVERY state mutation -- so a per-cell colour is wiped the first time
# anything changes. A glyph survives the theme pass, reads the same in light and
# dark, and needs no tenth key in the locked nine-key `ase::palette`.
#
# ⚠ `ok` GETS NO GLYPH. Marking the normal case is how a grid becomes noise; the
# mark is for the exceptions, and the status line carries the sentence.
#
# ⚠ `fatal` JOINED IN ISSUE 1435 AND IT IS NOT A FIFTH CELL STATE. No grid cell
# is ever `fatal` -- `ase::analysis_state` cannot answer it. It is a PRECONDITION
# verdict, and the banner under the form speaks it. It wears `blocked`'s glyph on
# purpose: to a reader they mean the same thing (this will not run), and minting
# a third mark for a distinction the user cannot act on differently is how a grid
# becomes noise. The two are kept apart in the VERDICT, where the gate acts on
# them differently, not in the glyph.
proc ase::ui::chana_glyph {state} {
  switch -exact -- $state {
    caution { return "⚠ " }
    blocked { return "⊘ " }
    fatal   { return "⊘ " }
    absent  { return "· " }
  }
  return {}
}

# DETECT: the one cold door, and it must PAINT BEFORE IT BLOCKS.
#
# ⚠ THE ORDER IS ase::ui::simdlg_detect's, LINE FOR LINE, AND IT IS THE WHOLE
# POINT. The measurement can take up to 31.2 s against a binary that exists, is
# executable and never answers, and Tk is frozen for all of it. Setting the
# sentence and then calling `update idletasks` BEFORE the blocking call is what
# puts it on screen; doing it the other way round shows the user nothing until
# after the wait is over, which is the same as not saying it.
proc ase::ui::chana_detect {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].chana
  if {![winfo exists $w]} { return }
  set sim [ase::ui::chana_sim $key]
  catch {$w.status configure -text [::ase::sim_why analyses_measuring {} \
           [dict get [::ase::sim_status $sim] resolved]]}
  catch {$w.detect configure -state disabled}
  update idletasks
  catch {::ase::analysis_detect $sim}
  # REBUILD FROM THE NEW ANSWER. The dialog is cheap to rebuild and the grid's
  # glyphs, the Detect gate and the status line all read the same cache, so
  # re-entering choose_analyses is what keeps them from drifting apart.
  set ty {}
  catch {set ty $::ase::ui::dlg($key,antype)}
  catch {destroy $w}
  ase::ui::choose_analyses $key $ty
}

# WHICH SIMULATOR THIS SESSION IS USING -- the ONE resolver on the dialog side,
# and the reason this commit exists (issue 1408).
#
# ⚠ BEFORE THIS, THE CHOOSE ANALYSES DIALOG DESCRIBED A SIMULATOR IT HAD NEVER
# BEEN TOLD ANYTHING ABOUT. `choose_analyses` asked `[ase::analysis_offered]`
# with NO argument and `[ase::analysis_entry [ase::default_simulator] $t]` for
# the label, and `chana_fields` / `arg_summary` both defaulted `sim` to
# `[ase::default_simulator]`. MEASURED against a bench whose state says
# `simulator zznoana`, a backend with no `analysis_types` hook:
#
#   ase::analysis_offered zznoana   ->  {}            the registry is RIGHT
#   ase::analysis_offered           ->  op dc ac tran what the dialog asked for
#   ase::ui::arg_summary $row       ->  dc V2 0 1.8 0.01
#
# -- four ngspice radio buttons, a committable `dc` form, and **an ngspice DECK
# LINE in the Arguments column** for a simulator that cannot render it. The
# machinery underneath was already correct; only the dialog never passed the
# session's simulator.
#
# ⚠ ONE COPY. Every other site takes the answer as an ARGUMENT. A second
# `$sim eq {}` default anywhere is a second place for the rule to drift, which
# is the defect Stage 1 spent itself deleting.
proc ase::ui::chana_sim {key} {
  set sim {}
  catch { set sim [ase::state_get [ase::session_state $key] simulator] }
  if {$sim eq {}} { set sim [ase::default_simulator] }
  return $sim
}

# THE TYPE THE DIALOG MAY COMMIT, OR `{}`. Membership in what THIS simulator
# offers -- never `[info exists]`, which is TRUE for an `antype` of `{}` and is
# how a bench with an empty grid gained a `{type {} enabled 0}` row.
proc ase::ui::chana_committable {key} {
  variable dlg
  if {![info exists dlg($key,antype)]} { return {} }
  set type $dlg($key,antype)
  if {$type eq {}} { return {} }
  if {[lsearch -exact [ase::analysis_offered [ase::ui::chana_sim $key]] $type] < 0} {
    return {}
  }
  return $type
}

proc ase::ui::choose_analyses {key {type {}}} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return }
  set w [ase::ui::dialog_frame [dict get $wins $key].chana {Choose Analyses}]
  set sim [ase::ui::chana_sim $key]
  set offered [ase::analysis_offered $sim]
  # ⚠ THE CACHE IS **PEEKED AT**, NEVER MEASURED. The free peek answers `{}` for a
  # cold cache; a cold PROBE would make opening this dialog take up to 31.2 s with
  # Tk frozen, which is the measured worst case for a binary that exists, is
  # executable and never answers. Detect is the only door to a cold measurement.
  set caps [ase::sim_caps_cached $sim]
  # ⚠ THE PRESELECT COMES FROM THE OFFERED LIST, NOT FROM THE LITERAL `op`.
  # An unconditional `op` is what made OK append `{type op enabled 1}` to a bench
  # whose backend cannot render `op`. With nothing offered this stays EMPTY and
  # every commit door refuses on MEMBERSHIP -- see ase::ui::chana_committable.
  if {$type eq {}} { set type [lindex $offered 0] }
  set dlg($key,antype) $type
  # top section: one radiobutton per analysis type; switching repopulates
  # the bottom form from state (D4: in-form edits of the previous type are
  # DISCARDED — deterministic, no hidden multi-type writes)
  frame $w.types
  # ── STAGE 1: THE RADIO ROW IS THE REGISTRY'S. ──────────────────────────────
  # `foreach t {op dc ac tran}` was the third copy. The order is `emitorder`
  # ascending and the text is the entry's `label`, which for these four IS
  # today's text -- a refactor may not mint user-facing copy, and promoting them
  # to human nouns is a ratified change under ⚖ R9, not a side effect.
  #
  # ── STAGE 2 (issue 1411): A WRAPPING GRID, FOUR PER ROW, ONE CELL PER
  # ── ANALYSIS THIS SIMULATOR DESCRIBES -- ELEVEN for ngspice, not four.
  #
  # ⚠ `$w.types.<type>` DOES NOT MOVE. Four committed rows in three suites drive
  # those paths (`$top.chana.types.tran invoke`, `$w.types.dc invoke`); adding
  # cells is safe, moving them is not, and issue 1405 is what that lesson cost.
  # `pack` becomes `grid` inside the SAME frame, so the children keep their names.
  #
  # ⚠ STATE IS A GLYPH ON THE LABEL, **NOT A COLOUR**, and that is forced rather
  # than chosen. `ase::ui::_theme_widget`'s Radiobutton arm rewrites `-background`
  # and `-foreground`, and `ase::ui::populate` ends in `apply_theme $top`, which
  # recurses into this child toplevel on EVERY state mutation -- so a per-cell
  # colour is wiped the first time anything changes. A glyph is also theme-proof
  # and needs no tenth key in the locked nine-key `ase::palette`.
  #
  # ⚠ EVERY CELL STAYS **SELECTABLE**, INCLUDING `blocked` AND `absent` ONES.
  # `invoke` on a `-state disabled` radiobutton is a SILENT no-op -- rc 0, the
  # variable unchanged, `-command` never fired -- so disabling the cell would make
  # a `.state` file carrying `{type pss enabled 1}` impossible to turn OFF in the
  # dialog, and would make a future test row written as
  # `$top.chana.types.pss invoke` pass while doing nothing. What is disabled is
  # the **Enable** checkbutton, which is the control that would actually commit.
  # Selecting a blocked cell is how its reason becomes readable.
  set _col 0 ; set _row 0
  foreach st [ase::analysis_states $sim $caps] {
    set t [lindex $st 0]
    set _lbl $t
    catch {set _lbl [dict get [ase::analysis_entry $sim $t] label]}
    radiobutton $w.types.$t -text "[ase::ui::chana_glyph [lindex $st 1]]$_lbl" \
      -value $t -variable ::ase::ui::dlg($key,antype) \
      -command [list ase::ui::chana_show $key]
    grid $w.types.$t -row $_row -column $_col -sticky w -padx 4
    incr _col
    if {$_col >= 4} { set _col 0 ; incr _row }
  }
  grid $w.types -row 0 -column 0 -columnspan 2 -sticky w -padx 8 -pady {8 4}
  checkbutton $w.enable -text Enable -variable ::ase::ui::dlg($key,anen)
  grid $w.enable -row 1 -column 0 -columnspan 2 -sticky w -padx 8 -pady 2
  # THE STATUS ROW IS RESERVED WHETHER OR NOT IT HAS TEXT, so the quick-field
  # rows below never move depending on which simulator is in force.
  label $w.status -text {} -anchor w -justify left
  grid $w.status -row 1 -column 1 -sticky w -padx 8 -pady 2
  # ── THE PRECONDITION BANNER, ISSUE 1435. ───────────────────────────────────
  # Stage 4's first user-visible surface, deferred into Stage 6 because it needs
  # netlist TEXT and a dialog may not produce one (see the slot's own header in
  # src/ase.tcl). It reads `ase::precheck_banner`, which PEEKS.
  #
  # ⚠ IT IS A NEW WIDGET AND NOT A SECOND TENANT OF `$w.status`, AND THAT WAS
  # MEASURED RATHER THAN PREFERRED. PLAN.md's Stage 4 says "there is no new
  # pixel ... No look debt is filed", on the grounds that everything reaches the
  # user through `ase::ui::dialog_status`. Measured on the dev display against
  # this dialog, 2026-09-12: `$w.status` is OCCUPIED ON ALL ELEVEN CELLS of a
  # fresh bench -- nine carry `baseline`'s "Offered because every build of this
  # simulator has it. Nothing was measured." and two carry `unrenderable`'s
  # sentence -- so a precondition sentence there would EVICT a capability
  # sentence that is equally true. And `$w.status` has `-wraplength 0`: putting
  # one 101-character precondition sentence in it took the dialog from 667 px to
  # 856 px wide. Two facts, two lines.
  #
  # ⚠ ROW 7, WHICH IS UNDER THE FORM AND ABOVE `Options…`. Rows 3-7 were free;
  # nothing existing moves, which is the rule issue 1405 cost 100 checks to
  # learn. The row is RESERVED whether or not the label has text, exactly as
  # `$w.status`'s is, so `Options…` and the button bar do not jump as the
  # sentence appears and goes.
  label $w.note -text {} -anchor w -justify left -wraplength 600
  grid $w.note -row 7 -column 0 -columnspan 2 -sticky w -padx 8 -pady 2
  # quick-field rows land on grid rows 2.. (chana_show); Options/buttons sit
  # on high fixed rows so the rebuilds never collide
  button $w.opts -text "Options…" -command [list ase::ui::chana_options $key]
  grid $w.opts -row 8 -column 0 -sticky w -padx 8 -pady 2
  # ⚠ DETECT IS OFFERED ONLY WHERE IT CAN CHANGE AN ANSWER -- a cell resting on an
  # assumption (`unmeasured` or `baseline`). A `noprobe` cell can never be
  # measured however often the button is pressed, and 2d's no-adapter grid gets no
  # button at all because the gap is in ASE-L rather than in the binary.
  button $w.detect -text Detect -command [list ase::ui::chana_detect $key]
  grid $w.detect -row 8 -column 1 -sticky e -padx 8 -pady 2
  if {![ase::analysis_detectable $sim $caps]} {
    $w.detect configure -state disabled
  }
  ase::ui::dialog_buttons $w 9 [list ase::ui::chana_ok $key] \
    [list ase::ui::chana_cancel $key]
  # ⚠ AN EMPTY GRID SAYS WHY IT IS EMPTY. This is NOT a fifth cell state: the
  # states are PER ANALYSIS and a simulator with no adapter contributes no rows
  # at all, so there is nothing to colour. It is also NOT a Detect button -- no
  # probe can help, because the gap is in ASE-L and not in the binary. The
  # sentence and this disable block are keyed on the SAME question
  # (`ase::analysis_offered` being empty), which ase::analysis_gap_msg
  # guarantees, so the dialog can never be blank AND silent.
  if {$offered eq {}} {
    $w.status configure -text [ase::analysis_gap_msg $sim]
    $w.enable configure -state disabled
    $w.opts   configure -state disabled
    catch {$w.btns.proceed configure -state disabled}
  }
  ase::ui::chana_show $key
  return $w
}

# (Re)build the bottom per-analysis form from the session state for the
# currently selected type: Enable + one dialog_row per quick field at the
# deterministic paths $w.<field>.
# ONE FIELD, AS THE WIDGET ITS DECLARED `kind` ASKS FOR. Issue 1417.
#
# ⚠ THE DEFAULT ARM IS AN ENTRY AND THAT IS DELIBERATE. A field table that
# declares a kind this proc has never heard of still produces a usable control
# rather than no control at all -- a form that silently omitted a field would be
# this stage's own defect (a value the user cannot reach) re-created by its fix.
proc ase::ui::chana_field_row {key parent type field r row} {
  variable dlg
  set sim [ase::ui::chana_sim $key]
  set fd  [ase::field_descriptor $sim $type $field]
  set kind {}
  if {[dict exists $fd kind]} { set kind [dict get $fd kind] }
  set lbl [ase::ui::form_label $sim $type $field]
  switch -exact -- $kind {
    bool {
      label $parent.l$field -text $lbl -font AseLabelFont -anchor w
      if {[ase::state_get $row $field 0] eq {1}} {
        set dlg($key,fld,$field) 1
      } else {
        set dlg($key,fld,$field) 0
      }
      checkbutton $parent.$field -text {} -onvalue 1 -offvalue 0 \
        -variable ::ase::ui::dlg($key,fld,$field)
      grid $parent.l$field -row $r -column 0 -sticky w -padx {8 6} -pady 2
      grid $parent.$field  -row $r -column 1 -sticky w -padx {0 8} -pady 2
    }
    mode {
      label $parent.l$field -text $lbl -font AseLabelFont -anchor w
      set vals {}
      if {[dict exists $fd values]} { set vals [dict get $fd values] }
      ttk::combobox $parent.$field -values $vals -state readonly -width 12
      # ⚠ THE DEFAULT IS RESOLVED HERE TOO, and it has to be: a bench storing no
      # sweep key must still SHOW `dec`, because the deck it renders carries
      # `dec`. A blank picker beside a deck line that says `dec` is the window
      # disagreeing with the file, which is the one thing this batch forbids.
      set cur [ase::state_get $row $field]
      if {$cur eq {}} { set cur [ase::field_default $fd] }
      catch {$parent.$field set $cur}
      bind $parent.$field <<ComboboxSelected>> \
        [list ase::ui::chana_mode_changed $key $type $field]
      grid $parent.l$field -row $r -column 0 -sticky w -padx {8 6} -pady 2
      grid $parent.$field  -row $r -column 1 -sticky w -padx {0 8} -pady 2
    }
    default {
      set e [ase::ui::dialog_row $parent $r $lbl $field]
      $e insert 0 [ase::state_get $row $field]
      bind $e <Return> [list ase::ui::chana_ok $key]
    }
  }
}

# ---------------------------------------------------------------------------
# THE FORM, ISSUE 1417. Stage 3's C3 gave the four analysis types real field
# tables; this is the surface that offers them.
#
# ⚠ ONE ADDRESS FOR THE FORM, AND EVERY READER GOES THROUGH IT. Before this,
# eight sites spelled `[dict get $wins $key].chana.form.$f` by hand, and issue
# 1405 is what that costs: Stage 1 moved `$w.$field` to `$w.form.$field` and a
# suite driving the old path through a VARIABLE was invisible to the survey, so
# the display arm raised `invalid command name` and silently lost nine rows
# while the headless arm read ALL PASS.
proc ase::ui::chana_form {key} {
  variable wins
  if {![dict exists $wins $key]} { return {} }
  set w [dict get $wins $key].chana.form
  if {![winfo exists $w]} { return {} }
  return $w
}

proc ase::ui::form_has {key field} {
  set w [ase::ui::chana_form $key]
  return [expr {$w ne {} && [winfo exists $w.$field]}]
}

# ⚠ A FORM VALUE IS READ BY WIDGET CLASS, NOT BY ASSUMING `get`. A checkbutton
# has no `get` at all -- reading one the old way raises, and the raise lands
# inside `chana_ok`'s commit path where the only visible symptom is an OK button
# that does nothing. The bool's answer lives in the array the checkbutton was
# given as its `-variable`, which is also what makes it survive a rebuild.
proc ase::ui::form_get {key field} {
  variable dlg
  set w [ase::ui::chana_form $key]
  if {$w eq {} || ![winfo exists $w.$field]} { return {} }
  switch -exact -- [winfo class $w.$field] {
    Checkbutton - TCheckbutton {
      if {[info exists dlg($key,fld,$field)] && $dlg($key,fld,$field) eq {1}} {
        return 1
      }
      return 0
    }
    default { return [string trim [$w.$field get]] }
  }
}

# THE WRITE-BACK RULE: A FIELD WRITES A KEY ONLY WHEN ITS VALUE DIFFERS FROM
# WHAT THE DECK WOULD HAVE SAID WITHOUT IT. Issue 1417.
#
# ⚠ THIS IS A BYTE-IDENTITY RULE, NOT A TIDINESS ONE, AND IT WAS MEASURED THE
# HARD WAY. Making `uic` a checkbutton made it answer `0` instead of the empty
# string an untouched entry answers, so the door stored `uic 0` -- a key NONE of
# the 104 committed benches carries. Making `sweep` a combobox has the same
# shape: it answers `dec` where a bench stores nothing, and `dec` is exactly
# what the emitter already resolves from the field's own `default`. Both keys
# change no deck line and both break the round trip this batch is measured
# against, the first time a user opens the dialog and presses OK.
#
# So "absent" is a per-field question: empty for a text field, OFF for a bool,
# and THE DECLARED DEFAULT for anything that has one.
proc ase::ui::form_is_absent {sim type field v} {
  if {$v eq {}} { return 1 }
  set fd [ase::field_descriptor $sim $type $field]
  set kind {}
  if {[dict exists $fd kind]} { set kind [dict get $fd kind] }
  if {$kind eq {bool}} {
    if {$v eq {0}} { return 1 }
    return 0
  }
  if {[dict exists $fd default] && $v eq [dict get $fd default]} { return 1 }
  return 0
}

# THE LABEL A FIELD WEARS. The field table's `label` if it declares one, else
# the old `[string totitle $f]` so a field table that has not been written yet
# still produces a readable form; plus the `unit` in parentheses when there is
# one, because `Stop time:` and `Stop time (s):` are different questions.
#
# ⚠ A `mode` FIELD CAN RELABEL ITS NEIGHBOUR, and the neighbour's text then
# comes from the neighbour's own `labels` table keyed by the mode's CURRENT
# value. That is the fix for ngspice's sharpest AC trap: `dec 10` is ten points
# PER DECADE while `lin 10` is ten points IN TOTAL, and the form said `Points:`
# for both.
proc ase::ui::form_label {sim type field {modeval {}}} {
  set fd [ase::field_descriptor $sim $type $field]
  set txt {}
  if {$modeval ne {} && [dict exists $fd labels] \
      && [dict exists [dict get $fd labels] $modeval]} {
    set txt [dict get [dict get $fd labels] $modeval]
  } elseif {[dict exists $fd label] && [dict get $fd label] ne {}} {
    set txt [dict get $fd label]
  } else {
    set txt [string totitle $field]
  }
  if {[dict exists $fd unit] && [dict get $fd unit] ne {}} {
    append txt " ([dict get $fd unit])"
  }
  return "$txt:"
}

# A MODE PICK RELABELS ITS DECLARED NEIGHBOUR. `relabels <field>` on the mode
# field names the one it governs; `dialog_row` names its label `$w.l$ename`, so
# the whole operation is one configure.
proc ase::ui::chana_mode_changed {key type field} {
  variable dlg
  set w [ase::ui::chana_form $key]
  if {$w eq {}} { return }
  set sim [ase::ui::chana_sim $key]
  set fd [ase::field_descriptor $sim $type $field]
  if {![dict exists $fd relabels]} { return }
  set tgt [dict get $fd relabels]
  if {![winfo exists $w.l$tgt]} { return }
  catch {$w.l$tgt configure \
    -text [ase::ui::form_label $sim $type $tgt [ase::ui::form_get $key $field]]}
}

# THE ADVANCED DISCLOSURE. Six controls on a tran form is the right number to
# OFFER and the wrong number to SHOW: `tstart`, `tmax` and `uic` are things a
# person reaches for deliberately, and putting them beside `Time step` makes the
# two required values harder to find rather than the three optional ones easier.
#
# ⚠ IT IS REMEMBERED FOR THE WINDOW, AND THAT IS A CHOICE. `advopen` is keyed by
# the window and outlives any one opening of the dialog, so a user who reaches
# for `tmax` once does not reach for the triangle again every time. The cost is
# that this proc TOGGLES -- anything driving it has to read the current state
# rather than assume a fresh dialog is closed.
proc ase::ui::chana_adv_toggle {key} {
  variable dlg
  set w [ase::ui::chana_form $key]
  if {$w eq {}} { return }
  set open 0
  if {[info exists dlg($key,advopen)] && $dlg($key,advopen) eq {1}} { set open 1 }
  set dlg($key,advopen) [expr {$open ? 0 : 1}]
  ase::ui::chana_show $key
}

# THE DIALOG'S OWN STATUS LINE. Generalised from ase::ui::rsel_status, which
# did exactly this for one dialog and was the only thing in the tree that did.
#
# ⚠ AND `ase::echo` STAYS. It is the action log and it is what a HEADLESS
# assertion can witness; the status line is what a PERSON reads. A refusal that
# went only to the log lands in another window, which is why OK appeared to "do
# nothing" -- the sentence existed and was nowhere the user was looking.
proc ase::ui::dialog_status {w key msg} {
  variable dlg
  set dlg($key,dlgstatus) $msg
  if {[winfo exists $w.status]} { catch {$w.status configure -text $msg} }
  return $msg
}

proc ase::ui::chana_show {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,antype)]} { return }
  set w [dict get $wins $key].chana
  if {![winfo exists $w]} { return }
  set type $dlg($key,antype)
  # ── STAGE 1: ONE CHILD FRAME, AND THE FIVE-NAME DESTROY LIST IS GONE. ───────
  # This used to be `foreach f {source start stop step points} {destroy $w.$f}`
  # -- a HARDCODED list of exactly the field names the four shipped types
  # happened to use. evidence/ase-ui.md calls it the single sharpest trap in the
  # analysis code, and it is: add a sixth field name to any type and the fifth
  # one's widget SURVIVES the rebuild, because nothing destroys what the list
  # does not name. There was a ceiling too -- quick fields gridded at rows 2..
  # while `Options…` sits at row 8 and the button bar at row 9, so a seventh
  # field collided with the buttons. `destroy $w.form` is exhaustive BY
  # CONSTRUCTION and the form owns its own row space, which is what lets a later
  # stage register an analysis with eight fields.
  #
  # ⚠ THIS MOVES `$w.<field>` TO `$w.form.<field>`, deliberately and in this
  # stage. `$top.chana.types.*`, `$top.chana.opts` and `$top.chana.btns.*` are
  # untouched -- adding paths is safe, moving them is not, and these are the
  # only ones moved.
  #
  # ⚠ THE SUITES THAT MOVE WITH IT ARE **TWO** FILES, NOT ONE, AND THE SECOND
  # COST A LATENT RED (issue 1405). Six lines of test_ase_dialogs.tcl drive the
  # paths literally. `tests/headless/test_ase_persist.tcl` row G2 drives them
  # through a VARIABLE -- `set w $top.chana` and then `$w.$fld` -- so the
  # `grep 'chana\.'` this stage's own survey rested on could not see it, and the
  # survey concluded "no other suite in the tree touches a Choose Analyses quick
  # field by path". It was wrong. G2 sits inside an `if {!$mainok}` skip, so the
  # HEADLESS arm reported ALL PASS while the display arm raised
  # `invalid command name ".ase4.chana.source"` and silently lost G3..G11 with
  # it. ⚠ A PATH SURVEY MUST SEARCH FOR THE VARIABLE TOO -- grep the widget
  # NAMES (`\$w\.source`, `\$w\.step`), not only the toplevel's spelling.
  catch {destroy $w.form}
  frame $w.form
  grid $w.form -row 2 -column 0 -columnspan 2 -sticky we
  grid columnconfigure $w.form 1 -weight 1
  set row [ase::ui::chana_row $key $type]
  set dlg($key,anen) [expr {[ase::state_get $row enabled 0] eq {1} ? 1 : 0}]
  # ⚠ THE STATUS LINE AND THE Enable GATE BOTH READ THE **SELECTED CELL'S** STATE,
  # which is what makes a blocked cell worth selecting: the cell stays clickable
  # (a disabled radiobutton's `invoke` is a silent no-op) and clicking it is how
  # its reason becomes readable. Issue 1411.
  if {[winfo exists $w.status] && $type ne {}} {
    set _sim [ase::ui::chana_sim $key]
    set _st [::ase::analysis_state $_sim $type [::ase::sim_caps_cached $_sim]]
    catch {$w.status configure -text [::ase::analysis_state_msg $_sim $type $_st]}
    # An analysis this simulator cannot run, or this adapter cannot set up, may
    # not be TURNED ON -- but a row already in the bench may still be turned OFF,
    # so the checkbutton is disabled only while the box is clear.
    set _ok [expr {$_st ne {} && [lsearch -exact {ok caution} [dict get $_st state]] >= 0}]
    if {$_ok || $dlg($key,anen)} {
      catch {$w.enable configure -state normal}
    } else {
      catch {$w.enable configure -state disabled}
    }
  }
  # ── THE TYPED FORM, ISSUE 1417. ────────────────────────────────────────────
  # Until this, every field of every type was an `entry` labelled
  # `[string totitle $f]:` -- no unit, no hint, and a bool the user had to know
  # to type `1` into. The field table C3 landed already says what each field IS;
  # this reads it.
  #
  # ⚠ THE `advanced` SPLIT IS NOT COSMETIC. Six controls on the tran form is the
  # right number to OFFER and the wrong number to SHOW: putting `tstart`, `tmax`
  # and `uic` beside `Time step` makes the two REQUIRED values harder to find,
  # not the three optional ones easier. It is CLOSED the first time and then
  # remembered for the window -- see ase::ui::chana_adv_toggle.
  set _sim2 [ase::ui::chana_sim $key]
  set _basic {} ; set _advf {}
  foreach f [ase::ui::chana_fields $type $_sim2] {
    set fd [ase::field_descriptor $_sim2 $type $f]
    if {[dict exists $fd advanced] && [dict get $fd advanced] eq {1}} {
      lappend _advf $f
    } else {
      lappend _basic $f
    }
  }
  set _advopen 0
  if {[info exists dlg($key,advopen)] && $dlg($key,advopen) eq {1}} { set _advopen 1 }
  set r 0
  set _shown $_basic
  foreach f $_basic {
    ase::ui::chana_field_row $key $w.form $type $f $r $row
    incr r
  }
  if {[llength $_advf]} {
    # ⚠ A GLYPH AND A WORD, not a glyph alone: the triangle says which way it
    # goes and the word says what is behind it.
    if {$_advopen} {
      set _glabel "▾ Advanced"
    } else {
      set _glabel "▸ Advanced"
    }
    button $w.form.advbtn -text $_glabel -font AseLabelFont -relief flat \
      -anchor w -command [list ase::ui::chana_adv_toggle $key]
    grid $w.form.advbtn -row $r -column 0 -columnspan 2 -sticky w \
      -padx {8 6} -pady 2
    incr r
    if {$_advopen} {
      foreach f $_advf {
        ase::ui::chana_field_row $key $w.form $type $f $r $row
        incr r
        lappend _shown $f
      }
    }
  }
  # ⚠ THE RELABEL RUNS AT BUILD TIME TOO, NOT ONLY ON A PICK. Otherwise the form
  # opens reading `Points per decade` for a bench that stored `lin`, which is the
  # exact sentence the relabel exists to stop being wrong.
  foreach f $_shown {
    set fd [ase::field_descriptor $_sim2 $type $f]
    if {[dict exists $fd relabels]} {
      ase::ui::chana_mode_changed $key $type $f
    }
  }
  # ⚠ AFTER THE FORM IS BUILT, BECAUSE IT READS THE FORM. `chana_merged_row`
  # overlays the widgets' live values on the stored row, so a banner refreshed
  # before the rebuild would describe the PREVIOUS type's widgets.
  ase::ui::chana_note $key
  ase::ui::apply_theme $w
}

# OK: D6 validation (an ENABLED analysis must satisfy ase::analysis_emit_check
# -- every REQUIRED slot filled, every bool 0/1/absent, every declared group
# all-or-none, every value readable in the simulator's own SI alphabet -- else
# render_deck would raise at run time; reject with the dialog kept up), then
# edit the FIRST state row of the shown type MERGED over its original dict
# (unknown/extra keys survive); an empty quick field deletes its key, no row of
# the type appends a fresh one.
# THE FORM'S LIVE VALUES, field -> value, for the fields this rebuild actually
# put on screen. Factored out of `ase::ui::chana_ok` in issue 1435 because the
# precondition banner needs the identical answer and a second copy of "read by
# widget class, never by assuming `get`" is a second place for it to drift.
proc ase::ui::chana_form_vals {key type sim} {
  set vals [dict create]
  foreach f [ase::ui::chana_fields $type $sim] {
    if {[ase::ui::form_has $key $f]} {
      dict set vals $f [ase::ui::form_get $key $f]
    }
  }
  return $vals
}

# THE ROW AS IT WOULD BE STORED IF OK WERE PRESSED NOW: the type's first stored
# row, with the form's live values overlaid and `ase::ui::form_is_absent`'s
# fields removed. `enabled` is NOT set here -- the banner does not care and
# `chana_ok` owns that key.
#
# ⚠ IT STARTS FROM THE STORED ROW AND NOT FROM THE FORM, and both halves matter.
# From the form alone it would lose every ADVANCED field the disclosure is
# hiding, because `form_has` is false for a widget that was never built. From the
# stored row alone it would judge the PREVIOUS answer -- `chana_ok`'s own comment
# on its `probe` says exactly that about the commit door, and the banner sits
# next to the widgets the user is typing into.
proc ase::ui::chana_merged_row {key type} {
  set sim [ase::ui::chana_sim $key]
  set row [ase::ui::chana_row $key $type]
  dict for {f v} [ase::ui::chana_form_vals $key $type $sim] {
    if {[ase::ui::form_is_absent $sim $type $f $v]} {
      set row [dict remove $row $f]
    } else {
      dict set row $f $v
    }
  }
  return $row
}

# (RE)PAINT THE PRECONDITION BANNER. Issue 1435.
#
# ⚠ IT PEEKS AND NEVER NETLISTS, and that constraint is the whole item. See the
# netlist-facts slot's header in src/ase.tcl for why `ase::netlist` is not a read
# and may not happen because a user opened a window.
#
# ⚠ IT REPORTS ON THE SELECTED TYPE WHETHER OR NOT IT IS ENABLED, which is where
# it parts company with `ase::analysis_precheck` (bench-wide, enabled-only). The
# commonest reason to be looking at this form is to decide whether to turn the
# analysis on; staying silent until after it is on would be silent at exactly
# the moment the advice is worth having.
proc ase::ui::chana_note {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return {} }
  set w [dict get $wins $key].chana
  if {![winfo exists $w] || ![winfo exists $w.note]} { return {} }
  set type {}
  if {[info exists dlg($key,antype)]} { set type $dlg($key,antype) }
  set txt {}
  catch {
    set txt [ase::precheck_banner_text \
      [ase::precheck_banner [ase::ui::chana_sim $key] \
        [ase::session_state $key] $type [ase::ui::chana_merged_row $key $type]]]
  }
  catch {$w.note configure -text $txt}
  return $txt
}

proc ase::ui::chana_ok {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,antype)]} { return }
  set w [dict get $wins $key].chana
  if {![winfo exists $w]} { return }
  # ⚠ MEMBERSHIP, NOT EXISTENCE. The guard above is `[info exists]`, which is
  # TRUE for an `antype` of `{}` -- the value an empty grid leaves behind. That
  # is how a bench whose backend lists no analyses gained a `{type {} enabled 0}`
  # row: a state key written for a type that does not exist, which then has to
  # round-trip through the .state file forever.
  set sim [ase::ui::chana_sim $key]
  set type [ase::ui::chana_committable $key]
  if {$type eq {}} {
    catch {::ase::echo [ase::analysis_commit_refusal $sim $dlg($key,antype)] error}
    return
  }
  set en [expr {[info exists dlg($key,anen)] && $dlg($key,anen) ? 1 : 0}]
  set vals [ase::ui::chana_form_vals $key $type $sim]
  if {$en} {
    # D6, ISSUE 1416 -- THE DOOR NO LONGER KNOWS WHAT A ROW NEEDS; IT ASKS.
    #
    # It used to demand that EVERY field of the type be non-empty, which was
    # only ever right because every field of every type happened to be
    # `required 1`. The moment a type declares an optional one -- tran gained
    # three in this commit -- that loop refuses a row ngspice would have run,
    # and refuses it with a sentence naming a field the user was never obliged
    # to fill. The one reader is `ase::analysis_emit_check`: it knows which
    # slots are required, that a bool cannot be "missing", that a group is all
    # or none, and that a value has to parse as a number in this simulator's
    # own alphabet.
    #
    # ⚠ THE PROBE ROW IS BUILT FROM `vals`, NOT FROM THE STORED ROW. The whole
    # point of a commit door is to judge what the user is about to store, and
    # the stored row is still the PREVIOUS answer at this moment. Judging the
    # stored row would pass a form the user has just emptied.
    set probe [dict create type $type]
    dict for {f v} $vals {
      if {$v ne {}} { dict set probe $f $v }
    }
    set bad [ase::analysis_emit_check $sim $probe]
    if {[llength $bad]} {
      # The FRAME is the caller's, the CLAUSE is the reader's -- issue 1404's
      # split. The first offence is the one reported; a field-by-field surface
      # would need a per-field marker language, which is its own ruling.
      set _fld    [lindex [lindex $bad 0] 1]
      set _clause [lindex [lindex $bad 0] 2]
      catch {::ase::echo "ase: enabled $type analysis $_clause" error}
      # ⚠ AND IN THE DIALOG, WHERE THE USER IS ACTUALLY LOOKING. Issue 1417.
      # Before this the sentence went ONLY to the action log, which lands in
      # ANOTHER WINDOW -- so from the user's seat OK "did nothing". The echo
      # stays because it is what a headless assertion can witness.
      set _msg "This $type analysis $_clause."
      if {$_fld ne {} && ![ase::ui::form_has $key $_fld]} {
        set _fd [ase::field_descriptor $sim $type $_fld]
        if {[dict exists $_fd advanced] && [dict get $_fd advanced] eq {1}} {
          append _msg " It is under Advanced."
        }
      }
      ase::ui::dialog_status $w $key $_msg
      # ⚠ FOCUS LANDS ON THE OFFENDING WIDGET, and there was no `focus` call
      # anywhere in this dialog before. ⚠ IT DOES NOT REBUILD THE FORM TO REACH
      # A HIDDEN FIELD: chana_show destroys and recreates every widget, so
      # opening the disclosure here would discard everything the user had typed
      # in order to show them what was wrong with it. The sentence says where it
      # is instead, and a GROUP offence names no widget at all.
      if {$_fld ne {} && [ase::ui::form_has $key $_fld]} {
        catch {focus [ase::ui::chana_form $key].$_fld}
      }
      return
    }
  }
  set st [ase::session_state $key]
  set rows [ase::state_get $st analyses]
  set idx -1
  for {set i 0} {$i < [llength $rows]} {incr i} {
    if {[ase::state_get [lindex $rows $i] type] eq $type} { set idx $i; break }
  }
  if {$idx >= 0} { set row [lindex $rows $idx] } \
  else           { set row [dict create type $type] }
  dict set row enabled $en
  dict for {f v} $vals {
    if {[ase::ui::form_is_absent $sim $type $f $v]} {
      set row [dict remove $row $f]
    } else {
      dict set row $f $v
    }
  }
  if {$idx >= 0} { lset rows $idx $row } else { lappend rows $row }
  dict set st analyses $rows
  ase::session_update $key $st
  ase::ui::populate $key
  ase::ui::chana_cancel $key
}

proc ase::ui::chana_cancel {key} {
  variable wins; variable dlg
  array unset dlg $key,antype
  array unset dlg $key,anen
  array unset dlg $key,anextra
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].chana}
  }
}

# D5: the `Options…` extra-key editor (toplevel $w.chana.x — a Tk child of
# the Choose Analyses dialog, so it dies with it): name/value keys of the
# current type's FIRST row beyond type/enabled + the quick fields. Return on
# the entry pair = Add (the pair's own proceed); the dialog OK writes the
# whole set straight into that state row (immediate commit — the main OK
# then merges only enabled + quick fields over the SAME row, so both
# compose). Extra keys round-trip through the state file and show in the
# Arguments summary. ⚠ THE SENTENCE THAT USED TO END THIS COMMENT -- "DECK
# emission of extra keys stays deferred (v1 limit, documented here)" -- WAS THE
# DEFECT, WRITTEN DOWN AND SHIPPED. Keys that round-trip and never emit are keys
# the window confirms and the simulator never sees. Issue 1418 closed this door:
# a name no template can spend is refused at `Add` and again at OK. Issue 1419
# opened the honest one: `x`, a verbatim list of `.control` lines that goes into
# the deck immediately above its own analysis.
proc ase::ui::chana_options {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,antype)]} { return }
  # ⚠ THE SAME MEMBERSHIP GUARD AS chana_ok, AND IT IS NEEDED HERE TOO. This
  # door writes the bench through the same ase::session_update, and its
  # `[info exists dlg($key,antype)]` test is TRUE for an `antype` of `{}`.
  # Through the GUI it is latent -- `$w.opts` is disabled on an empty grid and a
  # disabled Tk button's `invoke` returns `{}` -- which is exactly why only a row
  # can see it, and why the guard goes on the PROC rather than on the button.
  set _sim [ase::ui::chana_sim $key]
  if {[ase::ui::chana_committable $key] eq {}} {
    catch {::ase::echo [ase::analysis_commit_refusal $_sim $dlg($key,antype)] error}
    return
  }
  set w [dict get $wins $key].chana.x
  catch {destroy $w}
  toplevel $w
  set type $dlg($key,antype)
  wm title $w "Analysis Options ($type)"
  set row [ase::ui::chana_row $key $type]
  set skip [concat {type enabled} [ase::ui::chana_fields $type $_sim]]
  set ex [dict create]
  dict for {k v} $row {
    if {[lsearch -exact $skip $k] < 0} { dict set ex $k $v }
  }
  set dlg($key,anextra) $ex
  ttk::treeview $w.tv -columns {name value} -show headings -height 5 \
    -selectmode browse -style Ase.Treeview
  $w.tv heading name -text Name
  $w.tv heading value -text Value
  frame $w.row
  label $w.row.ln -text Name: -font AseLabelFont
  entry $w.row.name -width 10 -font AseEntryFont
  label $w.row.lv -text Value: -font AseLabelFont
  entry $w.row.value -width 10 -font AseEntryFont
  button $w.row.add -text Add -command [list ase::ui::chana_x_add $key]
  button $w.row.del -text Delete -command [list ase::ui::chana_x_del $key]
  pack $w.row.ln $w.row.name $w.row.lv $w.row.value $w.row.add $w.row.del \
    -side left -padx 2
  frame $w.btns
  button $w.btns.proceed -text OK -command [list ase::ui::chana_x_ok $key]
  button $w.btns.cancel -text Cancel -command [list ase::ui::chana_x_cancel $key]
  ## ⚠ §7c-4, THE SECOND SURFACE (issue 1441). `PLAN.md` asks for "per-analysis
  ## options behind the analysis form's `Options…`, filtered by
  ## `scope {analysis <type>}`" -- and this IS that dialog. The button opens the
  ## SAME sheet `Simulation > Options…` opens, with the scope preset to the type
  ## being edited, because a second sheet would be a second opinion about one
  ## `options` list. ngspice has no per-analysis option scope at all (§7e), so
  ## what the scope filters is the CATALOGUE, never the storage.
  button $w.btns.simopts -text "Simulator Options\u2026" \
    -command [list ase::ui::sim_options_dialog $key $type]
  pack $w.btns.proceed -side left -padx 5
  pack $w.btns.simopts -side left -padx 12
  pack $w.btns.cancel -side right -padx 5
  pack $w.btns -side bottom -fill x -padx 8 -pady 6
  pack $w.row -side bottom -fill x -padx 8 -pady 2
  pack $w.tv -side top -fill both -expand 1 -padx 8 -pady {8 2}
  bind $w.row.name  <Return> [list ase::ui::chana_x_add $key]
  bind $w.row.value <Return> [list ase::ui::chana_x_add $key]
  # item 10: ESC on the SUBDIALOG only — a nested toplevel's bindtags never
  # reach the parent dialog, so .chana's own ESC cannot fire from here
  ase::ui::bind_dialog_esc $w [list ase::ui::chana_x_cancel $key]
  ase::ui::chana_x_fill $key
  ase::ui::apply_theme $w
  focus $w.row.name
  return $w
}

proc ase::ui::chana_x_fill {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,anextra)]} { return }
  set tv [dict get $wins $key].chana.x.tv
  if {![winfo exists $tv]} { return }
  $tv delete [$tv children {}]
  dict for {k v} $dlg($key,anextra) {
    $tv insert {} end -id $k -values [list $k $v]
  }
}

proc ase::ui::chana_x_add {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,anextra)]} { return }
  set w [dict get $wins $key].chana.x
  if {![winfo exists $w]} { return }
  set n [string trim [$w.row.name get]]
  set v [string trim [$w.row.value get]]
  if {$n eq {}} {
    catch {::ase::echo "ase: option name must not be empty" error}
    return
  }
  # ⚠ THE DOOR CLOSES HERE. ISSUE 1418, AND IT IS THIS STAGE'S WHOLE SUBJECT.
  # This editor collected free-text name/value pairs, round-tripped them through
  # the .state file and showed them in the pane -- and NEVER EMITTED THEM. The
  # fix is not to make free text emit; it is to stop accepting a name nothing
  # can spend. Measured end to end before this: type `uic 1`, `tstart 5u`,
  # `tmax 1n` into a tran row, see all three confirmed, and the deck says
  # `tran 10n 200u`.
  #
  # ⚠ REFUSED AT `Add`, NOT AT OK. A pair the user has already seen land in the
  # list is a pair they believe they have set; taking it away at OK is a second
  # surprise on top of the first. The refusal belongs at the gesture that would
  # have created it.
  set _sim [ase::ui::chana_sim $key]
  set _ty  $dlg($key,antype)
  if {[lsearch -exact [ase::ui::chana_fields $_ty $_sim] $n] < 0} {
    set _c [ase::analysis_emit_msg unknownkey $n]
    catch {::ase::echo "ase: this $_ty analysis $_c" error}
    catch {ase::ui::dialog_status [dict get $wins $key].chana $key \
             "This $_ty analysis $_c."}
    return
  }
  dict set dlg($key,anextra) $n $v
  $w.row.name delete 0 end
  $w.row.value delete 0 end
  ase::ui::chana_x_fill $key
}

proc ase::ui::chana_x_del {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,anextra)]} { return }
  set tv [dict get $wins $key].chana.x.tv
  if {![winfo exists $tv]} { return }
  foreach id [$tv selection] {
    set dlg($key,anextra) [dict remove $dlg($key,anextra) $id]
  }
  ase::ui::chana_x_fill $key
}

# ESC / the Cancel button of the Options subdialog (item 10): discard the
# edited extra-key set. The bare-destroy Cancel it replaces left
# dlg($key,anextra) lingering until the PARENT Choose Analyses closed —
# exactly the record-leak class ESC-dismiss forbids. Dropping it loses
# nothing: chana_options re-derives anextra from the state row on every open
# (chana_cancel and ase::ui::close stay as backstops).
proc ase::ui::chana_x_cancel {key} {
  variable wins; variable dlg
  array unset dlg $key,anextra
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].chana.x}
  }
}

proc ase::ui::chana_x_ok {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,antype)] \
      || ![info exists dlg($key,anextra)]} { return }
  # ⚠ THE SAME MEMBERSHIP GUARD AS chana_ok, AND IT IS NEEDED HERE TOO. This
  # door writes the bench through the same ase::session_update, and its
  # `[info exists dlg($key,antype)]` test is TRUE for an `antype` of `{}`.
  # Through the GUI it is latent -- `$w.opts` is disabled on an empty grid and a
  # disabled Tk button's `invoke` returns `{}` -- which is exactly why only a row
  # can see it, and why the guard goes on the PROC rather than on the button.
  set _sim [ase::ui::chana_sim $key]
  if {[ase::ui::chana_committable $key] eq {}} {
    catch {::ase::echo [ase::analysis_commit_refusal $_sim $dlg($key,antype)] error}
    return
  }
  set type $dlg($key,antype)
  set st [ase::session_state $key]
  set rows [ase::state_get $st analyses]
  set idx -1
  for {set i 0} {$i < [llength $rows]} {incr i} {
    if {[ase::state_get [lindex $rows $i] type] eq $type} { set idx $i; break }
  }
  if {$idx >= 0} { set row [lindex $rows $idx] } \
  else           { set row [dict create type $type enabled 0] }
  # replace the row's extra-key set with the edited one (a Delete here must
  # really delete), keeping type/enabled + quick fields untouched
  set skip [concat {type enabled} [ase::ui::chana_fields $type $_sim]]
  foreach k [dict keys $row] {
    if {[lsearch -exact $skip $k] < 0} { set row [dict remove $row $k] }
  }
  # ⚠ AND AGAIN AT OK, BECAUSE `anextra` IS SEEDED FROM THE STORED ROW. A bench
  # written by an older ASE-L -- or edited by hand -- arrives here carrying keys
  # `Add` never saw, and writing them straight back would launder them through a
  # door that now refuses them at the front.
  foreach k [dict keys $dlg($key,anextra)] {
    if {[lsearch -exact [ase::ui::chana_fields $type $_sim] $k] < 0} {
      set _c [ase::analysis_emit_msg unknownkey $k]
      catch {::ase::echo "ase: this $type analysis $_c" error}
      catch {ase::ui::dialog_status [dict get $wins $key].chana $key \
               "This $type analysis $_c."}
      return
    }
  }
  dict for {k v} $dlg($key,anextra) { dict set row $k $v }
  if {$idx >= 0} { lset rows $idx $row } else { lappend rows $row }
  dict set st analyses $rows
  ase::session_update $key $st
  ase::ui::populate $key
  array unset dlg $key,anextra
  catch {destroy [dict get $wins $key].chana.x}
}

# --- (b) Setup > Design ------------------------------------------------------

# schematic views of lib/cell: those whose datafile resolves to a .sch (the
# mkinst::symbol_views mirror — a view's TYPE comes from its datafile
# extension, not its name).
proc ase::ui::design_sch_views {lib cell} {
  set out {}
  foreach v [xschem cell_views $lib $cell] {
    if {[string match {*.sch} [xschem cellview_path "$lib/$cell" $v]]} {
      lappend out $v
    }
  }
  return $out
}

# Setup > Design…: Library/Cell/View type-to-filter comboboxes; the View
# list holds ONLY schematic views once a Cell is chosen. Prefilled from the
# state's `design`; OK validates and writes it back.
proc ase::ui::design_dialog {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return }
  set w [ase::ui::dialog_frame [dict get $wins $key].design {Setup Design}]
  set dlg($key,dlib) [lsort [libmgr::lib_names]]
  foreach {r name lbl} [list 0 lib Library: 1 cell Cell: 2 view View:] {
    label $w.l$name -text $lbl -font AseLabelFont -anchor w
    ttk::combobox $w.$name -width 24 -font AseEntryFont -style Ase.TCombobox
    grid $w.l$name -row $r -column 0 -sticky w -padx {8 6} -pady 2
    grid $w.$name  -row $r -column 1 -sticky we -padx {0 8} -pady 2
    bind $w.$name <Return> [list ase::ui::design_ok $key]
    bind $w.$name <KeyRelease> [list ase::ui::design_filter $key $name]
  }
  bind $w.lib  <<ComboboxSelected>> [list ase::ui::design_refill $key 1]
  bind $w.cell <<ComboboxSelected>> [list ase::ui::design_refill $key 0]
  ase::ui::dialog_buttons $w 3 [list ase::ui::design_ok $key] \
    [list ase::ui::design_cancel $key]
  set d [ase::state_get [ase::session_state $key] design]
  foreach f {lib cell view} {
    if {[dict exists $d $f]} { $w.$f set [dict get $d $f] }
  }
  $w.lib configure -values $dlg($key,dlib)
  ase::ui::design_lists $key
  ase::ui::apply_theme $w
  focus $w.lib
  return $w
}

# Recompute the dependent Cell/View full-value lists from the current
# Library/Cell text (prefill and selection changes both land here).
proc ase::ui::design_lists {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].design
  if {![winfo exists $w]} { return }
  set l [string trim [$w.lib get]]
  set c [string trim [$w.cell get]]
  set dlg($key,dcell) {}
  if {$l ne {}} { catch {set dlg($key,dcell) [lsort [xschem lib_cells $l]]} }
  $w.cell configure -values $dlg($key,dcell)
  set dlg($key,dview) {}
  if {$l ne {} && $c ne {}} {
    set dlg($key,dview) [ase::ui::design_sch_views $l $c]
  }
  $w.view configure -values $dlg($key,dview)
}

# A Library pick invalidates the Cell + View texts; a Cell pick the View.
proc ase::ui::design_refill {key libchanged} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].design
  if {![winfo exists $w]} { return }
  if {$libchanged} { $w.cell set {} }
  $w.view set {}
  ase::ui::design_lists $key
}

proc ase::ui::design_filter {key f} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,d$f)]} { return }
  set w [dict get $wins $key].design
  if {![winfo exists $w.$f]} { return }
  ase::ui::combo_filter $w.$f $dlg($key,d$f)
}

proc ase::ui::design_ok {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].design
  if {![winfo exists $w]} { return }
  set l [string trim [$w.lib get]]
  set c [string trim [$w.cell get]]
  set v [string trim [$w.view get]]
  if {$l eq {} || $c eq {} || $v eq {}} {
    catch {::ase::echo "ase: Library, Cell and View are all required" error}
    return
  }
  if {[lsearch -exact [ase::ui::design_sch_views $l $c] $v] < 0} {
    catch {::ase::echo "ase: '$v' is not a schematic view of $l/$c" error}
    return
  }
  set st [ase::session_state $key]
  dict set st design [list lib $l cell $c view $v]
  ase::session_update $key $st
  ase::ui::populate $key
  ase::ui::design_cancel $key
}

proc ase::ui::design_cancel {key} {
  variable wins; variable dlg
  array unset dlg $key,dlib
  array unset dlg $key,dcell
  array unset dlg $key,dview
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].design}
  }
}

# --- (c)+(g) Model Files / Simulation Options: the shared list dialog --------

# Setup > Model Files…: one row per `models` entry {file section} — the
# corner/section entry per row (e.g. tt). Deletion is DIALOG-LOCAL (ctx
# Delete + the Delete key on the treeview, D1): the main action-strip X
# keeps scanning only the three panes.
proc ase::ui::model_files_dialog {key} {
  return [ase::ui::listdlg_open $key models {Model Files}]
}

# ═══ §7c: THE OPTIONS SHEET -- FINDING ONE OPTION AMONG 247 (issue 1441) ══════
#
# Simulation > Options… used to be the shared two-column list dialog: the rows
# THIS BENCH STORES, and nothing else. That is a fine editor and a hopeless
# finder -- the catalogue behind it has 247 rows and the dialog could not show
# you one of them until you had already typed its name.
#
# ⚠ THE DEFAULT VIEW IS STILL EXACTLY THOSE ROWS, IN EXACTLY THAT ORDER, WITH
# EXACTLY THOSE TREEVIEW IDS. That is not nostalgia: `PLAN.md` §7c-2 asks for
# "changed only" as the DEFAULT view, and the bench's own stored rows ARE that
# view (see `ase::opt_stored_verdict`'s header for why storage and not the
# `default` column decides visibility). So the Add…/Edit…/Delete gestures, the
# `$w.optrow` row editor and the integer row ids are the ones this tree already
# had, driven by the very same `ase::ui::listdlg_*` procs -- one editor, not two.
#
# WHAT IS NEW IS EVERYTHING AROUND THEM:
#
#   Find:      one entry filtering NAME, GROUP and HELP, live and by substring
#   Show all   the other ~240 rows, in groups rather than in an alphabet
#   Scope:     Global (everything) or one analysis type (§7c-4)
#   RESULTS    the ⚠ badge, and it says whether the claim was MEASURED (§7c-5)
#   the deck preview -- the exact lines this bench will emit, and WHERE (§7c-6)
#
# ⚠ THE PREVIEW IS THE POINT OF THE SHEET AND IT IS NOT DRAWN FROM A SECOND
# OPINION. `ase::opt_preview` reads `ase::opt_deck_plan`, which is the body
# `ase::backend::ngspice::render_deck` itself now runs. A setting with no line
# in the preview is a setting that does nothing; a setting whose line is there
# but cannot take effect gets a NOTE saying so, which is the half people forget.
#
# ⚠ AND NO SENTENCE IS COMPOSED IN THIS FILE THAT ASE-L'S CORE ALREADY MINTS.
# The delivery reasons, the refusals and the measurement behind a badge all come
# from src/ase.tcl; what is written here is the sheet's own chrome -- column
# headings, the two badge phrases, the four slot labels and the verdict words.

# The sheet's own per-session widgets state: the live search text, the Show-all
# tick and the scope pick. ⚠ PER KEY, LIKE `simuse`: two open sessions are two
# benches, and one shared variable would make their sheets fight.
namespace eval ase::ui { variable optsheet; array set optsheet {} }

# The scope the sheet is filtering on: `global`, or `{analysis <type>}`.
proc ase::ui::optsheet_scope {key} {
  variable optsheet
  if {![info exists optsheet($key,scope)]} { return global }
  set v $optsheet($key,scope)
  if {$v eq {} || $v eq [ase::ui::optsheet_global_label]} { return global }
  return [list analysis $v]
}

# The combobox line that means "every option this simulator has".
proc ase::ui::optsheet_global_label {} { return {Global} }

# THE BADGE, AND IT IS THREE-VALUED BECAUSE THE EVIDENCE IS (§7c-5).
#
# ⚠ `PLAN.md` ASKS FOR "a ⚠ badge on every `results 1` row -- the 21 options
# that change numbers", and issue 1437 shipped that column TRANSCRIBED, 0/247
# verified. Measuring all 22 on both binaries (issue 1441) refuted three of
# them: `warn` and `maxwarns` are SOA diagnostics that print more and compute
# the same, and `num_threads` is an OpenMP thread count. Those three now draw
# NO badge. Ten more could not be made to fire on any probe deck, and they draw
# a badge that says so rather than one that claims a measurement nobody took.
proc ase::ui::optsheet_badge {sim name} {
  switch -- [ase::opt_results $sim $name] {
    yes        { return "⚠ CHANGES RESULTS" }
    unverified { return "⚠ MAY CHANGE RESULTS — UNVERIFIED" }
  }
  return {}
}

# What the `where` column says: the slot this row's line goes into, in ASE-L's
# own vocabulary. `ase::opt_door` is the simulator-independent answer; these are
# the four words the user reads.
proc ase::ui::optsheet_where {sim name {state {}}} {
  ## §7e: A ROW THE BENCH STORES AGAINST ONE ANALYSIS IS WRITTEN INSIDE THAT
  ## ANALYSIS'S BLOCK, WHICHEVER DOOR ITS CATALOGUE ROW WOULD OTHERWISE USE --
  ## `ase::opt_deck_plan` skips it and `ase::opt_scope_plan` writes it. The
  ## column has to say so or the sheet and the deck disagree about one row.
  if {$state ne {}} {
    foreach o [ase::state_get $state options] {
      if {![dict exists $o name]} { continue }
      if {![string equal -nocase [dict get $o name] $name]} { continue }
      set an [ase::opt_row_analysis $o]
      if {$an ne {}} { return "[string toupper $an] BLOCK" }
    }
  }
  if {[ase::sim_option_entry $sim $name] eq {}} { return {} }
  set d {}
  if {[catch {ase::opt_door $sim $name} d]} {
    if {[catch {ase::opt_door $sim $name control} d]} { return {NO DOOR} }
  }
  switch -- $d {
    options      { return {DECK} }
    control      { return {ANALYSIS BLOCK} }
    predeck      { return {COMMAND LINE} }
    predeck-file { return {START-UP FILE} }
    cmdline      { return {COMMAND LINE} }
  }
  return {}
}

# ⚠ §7e: THE PER-ANALYSIS SHEET WRITES A PER-ANALYSIS ROW. Until issue 1442 the
# analysis form's `Simulator Options…` button opened the same sheet with the
# scope preset and then wrote into the SAME global list -- so a value the user
# set "for this tran" was set for the whole run, which is the lie §7e exists to
# stop. `options` is still ONE list; the scope is a key on the row.
#
# ⚠ IT STAMPS ONLY WHAT THE SCOPE CAN ACTUALLY DELIVER. A row scoped to an
# analysis that cannot be put back afterwards still LEAKS -- that is measured,
# not arguable -- but the stamp is still right: the line is written where the
# user asked, and `ase::opt_scope_plan` reports `leaks` so the preview and the
# detail line both say it outlives the analysis. Refusing the stamp instead
# would put the value in the global list, which is the same leak with nothing
# said about it.
proc ase::ui::optsheet_stamp {key} {
  set sc [ase::ui::optsheet_scope $key]
  if {[lindex $sc 0] ne {analysis}} { return {} }
  return [list analysis [lindex $sc 1]]
}

# Simulation > Options…: the options sheet. ⚠ SAME TOPLEVEL PATH, SAME
# TREEVIEW PATH, SAME CONTEXT MENU AND SAME ROW EDITOR as the list dialog it
# grew out of, so every gesture that worked before works now.
proc ase::ui::sim_options_dialog {key {scope {}}} {
  variable wins; variable listdlg; variable optsheet
  if {![dict exists $wins $key]} { return }
  set cfg [dict get $listdlg simopt]
  set w [dict get $wins $key].[dict get $cfg win]
  catch {destroy $w}
  toplevel $w
  wm title $w {Simulation Options}
  set sim [ase::ui::chana_sim $key]
  if {![info exists optsheet($key,needle)]}  { set optsheet($key,needle) {} }
  if {![info exists optsheet($key,showall)]} { set optsheet($key,showall) 0 }
  set optsheet($key,scope) [expr {$scope eq {} ? [ase::ui::optsheet_global_label] : $scope}]

  ## ── the finder bar ────────────────────────────────────────────────────────
  frame $w.bar
  label $w.bar.lf -text {Find:} -font AseLabelFont
  entry $w.bar.find -width 18 -font AseEntryFont \
    -textvariable ase::ui::optsheet($key,needle)
  checkbutton $w.bar.all -text {Show all} \
    -variable ase::ui::optsheet($key,showall) \
    -command [list ase::ui::optsheet_fill $key]
  label $w.bar.ls -text {Scope:} -font AseLabelFont
  ttk::combobox $w.bar.scope -width 10 -state readonly \
    -textvariable ase::ui::optsheet($key,scope) \
    -values [ase::ui::optsheet_scopes $key]
  pack $w.bar.lf $w.bar.find $w.bar.all $w.bar.ls $w.bar.scope -side left -padx 3
  ## LIVE, not on Return: the whole point is that the list narrows as you type.
  bind $w.bar.find <KeyRelease> [list ase::ui::optsheet_fill $key]
  bind $w.bar.scope <<ComboboxSelected>> [list ase::ui::optsheet_fill $key]

  ## ── the rows ──────────────────────────────────────────────────────────────
  ## `-show {tree headings}` because §7c-3 asks for GROUPS rather than an
  ## alphabet, and a group is a parent row. In the default (changed) view there
  ## are no parents and the tree column is empty, which is what keeps that view
  ## shaped exactly like the list dialog it replaces.
  set cols {name value results where}
  ttk::treeview $w.tv -columns $cols -show {tree headings} -selectmode extended \
    -height 9 -style Ase.Treeview -yscrollcommand [list $w.sb set]
  set heads {Name Value Results Written}
  set first 1
  foreach c $cols h $heads {
    $w.tv heading $c -text $h
    $w.tv column $c -width [ase::ui::colw 16 $h] \
                    -minwidth [ase::ui::colw 0 $h] -anchor w -stretch $first
    set first 0
  }
  $w.tv column #0 -width [ase::ui::colw 12 {Group}] -stretch 0
  scrollbar $w.sb -orient vertical -command [list $w.tv yview]

  ## ── what the selected row is, in words ────────────────────────────────────
  label $w.detail -text {} -anchor w -justify left -wraplength 620 -font AseBodyFont
  bind $w.tv <<TreeviewSelect>> [list ase::ui::optsheet_detail $key]

  ## ── the live deck preview ─────────────────────────────────────────────────
  labelframe $w.prev -text {Deck preview}
  text $w.prev.t -height 8 -width 60 -wrap none -font AseMonoFont \
    -yscrollcommand [list $w.prev.sb set]
  scrollbar $w.prev.sb -orient vertical -command [list $w.prev.t yview]
  pack $w.prev.sb -side right -fill y
  pack $w.prev.t -side left -fill both -expand 1

  frame $w.btns
  button $w.btns.close -text Close -command [list destroy $w]
  pack $w.btns.close -side right -padx 5

  grid $w.bar    -row 0 -column 0 -columnspan 2 -sticky w   -padx 8 -pady 4
  grid $w.tv     -row 1 -column 0 -sticky nsew -padx {8 0} -pady 2
  grid $w.sb     -row 1 -column 1 -sticky ns   -padx {0 8} -pady 2
  grid $w.detail -row 2 -column 0 -columnspan 2 -sticky w -padx 8 -pady 2
  grid $w.prev   -row 3 -column 0 -columnspan 2 -sticky nsew -padx 8 -pady 4
  grid $w.btns   -row 4 -column 0 -columnspan 2 -sticky ew -padx 8 -pady 6
  grid rowconfigure $w 1 -weight 3
  grid rowconfigure $w 3 -weight 2
  grid columnconfigure $w 0 -weight 1

  menu $w.ctx -tearoff 0
  $w.ctx add command -label "Add…" \
    -command [list ase::ui::listdlg_editor $key simopt -1]
  $w.ctx add command -label "Edit…" \
    -command [list ase::ui::listdlg_edit_first $key simopt]
  $w.ctx add command -label Delete \
    -command [list ase::ui::listdlg_delete $key simopt]
  bind $w.tv <Button-3> [list ase::ui::listdlg_ctx $key simopt %X %Y]
  bind $w.tv <Delete> [list ase::ui::listdlg_delete $key simopt]
  ## A catalogue row the bench has NOT stored: double-click opens the row editor
  ## with the name already in it, which is the gesture that turns "I found it"
  ## into "I set it".
  bind $w.tv <Double-Button-1> [list ase::ui::optsheet_pick $key]
  ase::ui::bind_dialog_esc $w [list destroy $w]
  ase::ui::optsheet_fill $key
  ase::ui::apply_theme $w
  return $w
}

# The scope combobox's values: Global plus the analysis types THIS BENCH
# carries. ⚠ THE BENCH'S OWN TYPES, not the simulator's whole registry -- a
# scope for an analysis this bench does not have is a filter that can only ever
# return rows the user cannot act on.
proc ase::ui::optsheet_scopes {key} {
  set out [list [ase::ui::optsheet_global_label]]
  catch {
    foreach row [ase::state_get [ase::session_state $key] analyses] {
      set t [ase::state_get $row type]
      if {$t ne {} && [lsearch -exact $out $t] < 0} { lappend out $t }
    }
  }
  return $out
}

# ⚠ THE ROW IDS ARE THE CONTRACT. A stored option's id is its INTEGER index in
# the bench's `options` list, in both views, because that is what
# `ase::ui::listdlg_editor`, `listdlg_ok` and `listdlg_delete` index with -- one
# editor for both surfaces, and the gestures this dialog already had keep
# working. A catalogue row the bench does not store gets `opt:<name>`, which
# `listdlg_delete`'s `string is integer -strict` guard skips, and a group header
# gets `grp:<group>`.
proc ase::ui::optsheet_fill {key} {
  variable wins; variable optsheet
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simopt
  if {![winfo exists $w.tv]} { return }
  set tv $w.tv
  $tv delete [$tv children {}]
  set sim [ase::ui::chana_sim $key]
  set st [ase::session_state $key]
  set needle {} ; set showall 0
  if {[info exists optsheet($key,needle)]}  { set needle $optsheet($key,needle) }
  if {[info exists optsheet($key,showall)]} { set showall $optsheet($key,showall) }
  set scope [ase::ui::optsheet_scope $key]
  ## Which index in the bench's own list each stored name has.
  set idx [dict create] ; set i 0
  foreach o [ase::state_get $st options] {
    if {[dict exists $o name]} { dict set idx [dict get $o name] $i }
    incr i
  }
  if {![ase::opt_truthy $showall]} {
    foreach n [ase::opt_browse $sim -needle $needle -scope $scope \
                                    -state $st -changed 1] {
      ase::ui::optsheet_row $key $tv {} $n $idx
    }
  } else {
    foreach {grp names} [ase::opt_group_index $sim \
          [ase::opt_browse $sim -needle $needle -scope $scope]] {
      set gid grp:$grp
      $tv insert {} end -id $gid -open 1 \
        -text "[string toupper $grp] ([llength $names])"
      foreach n $names { ase::ui::optsheet_row $key $tv $gid $n $idx }
    }
  }
  ase::ui::optsheet_preview $key
  ase::ui::optsheet_detail $key
}

proc ase::ui::optsheet_row {key tv parent name idx} {
  set sim [ase::ui::chana_sim $key]
  set st [ase::session_state $key]
  set id opt:$name
  set val {}
  if {[dict exists $idx $name]} {
    set id [dict get $idx $name]
    set m [ase::state_option_map $st]
    if {[dict exists $m $name]} { set val [dict get $m $name] }
  }
  $tv insert $parent end -id $id -values [list $name $val \
    [ase::ui::optsheet_badge $sim $name] [ase::ui::optsheet_where $sim $name $st]]
}

# The selected row, in words: what it is, whether the bench has changed it,
# whether it is offered at all, and -- for a badge -- the measurement behind it.
proc ase::ui::optsheet_detail {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simopt
  if {![winfo exists $w.detail]} { return }
  set sim [ase::ui::chana_sim $key]
  set st [ase::session_state $key]
  set sel {}
  catch {set sel [lindex [$w.tv selection] 0]}
  if {$sel eq {} || [string match grp:* $sel]} {
    $w.detail configure -text {}
    return
  }
  set name [lindex [$w.tv item $sel -values] 0]
  set bits {}
  set h [ase::opt_help $sim $name]
  if {$h ne {}} { lappend bits $h }
  switch -- [ase::opt_offer $sim $name] {
    no        { lappend bits "NOT OFFERED: [ase::opt_inert $sim $name]" }
    elsewhere { lappend bits "SET ELSEWHERE: [ase::opt_owner $sim $name]" }
    clamp     { lappend bits "CLAMPED: [ase::ui::optsheet_key $sim $name clamp]" }
    caveat    { lappend bits "CAVEAT: [ase::ui::optsheet_key $sim $name defect][ase::ui::optsheet_key $sim $name caveat]" }
  }
  set why [ase::opt_results_why $sim $name]
  if {$why ne {}} { lappend bits $why }
  ## --- §7g rule 5 (issue 1442): a capability-gated row is LISTED, never hidden
  set gw [ase::opt_gate_why $sim $name [ase::sim_caps_cached $sim]]
  if {$gw ne {}} { lappend bits "GATED: $gw" }
  ## --- §7e (issue 1442): what a per-analysis scope can actually promise -----
  set _sc [ase::ui::optsheet_scope $key]
  if {[lindex $_sc 0] eq {analysis}} {
    set v [ase::opt_analysis_verdict $sim $name [lindex $_sc 1]]
    switch -exact -- [lindex $v 0] {
      scoped { lappend bits "SCOPED: set for this analysis and put back after it" }
      global { lappend bits {GLOBAL: this option is not offered per analysis} }
      leaks  { lappend bits "LEAKS: [ase::opt_leak_why $sim $name]" }
    }
  }
  ## ⚠ NO `dict exists` GUARD HERE. `ase::opt_stored_verdict` answers `unset`
  ## for a row the bench does not store, which is the honest answer for the ~240
  ## rows Show-all lists, and a guard in this file would be a second place that
  ## decides what "not set" means.
  switch -- [ase::opt_stored_verdict $sim $st $name] {
    changed   { lappend bits "CHANGED from the default [ase::opt_default $sim $name]" }
    default   { lappend bits {SET to this simulator's own default} }
    nodefault { lappend bits {SET; this simulator declares no default to compare with} }
    unknown   { lappend bits {SET; this simulator's catalogue has no such option} }
  }
  $w.detail configure -text [join $bits {  |  }]
}

# One catalogue key of a row, or {} -- so the detail line can quote a reason the
# adapter wrote without this file knowing which rows carry which keys.
proc ase::ui::optsheet_key {sim name key} {
  set d [ase::sim_option_entry $sim $name]
  if {$d eq {} || ![dict exists $d $key]} { return {} }
  return [dict get $d $key]
}

# ⚠ THE LIVE DECK PREVIEW. Four slots and a notes block, straight out of
# `ase::opt_preview` -- which reads the body `render_deck` runs, so a line here
# IS a line there. An empty slot prints nothing but its own heading, because
# "there is no line for this" is the answer the pane exists to give.
proc ase::ui::optsheet_preview {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simopt
  if {![winfo exists $w.prev.t]} { return }
  set sim [ase::ui::chana_sim $key]
  set pv {}
  if {[catch {ase::opt_preview $sim [ase::session_state $key]} pv]} {
    set pv [dict create deck {} control {} cmdline {} prefile {} \
                        notes [list [list {} error [ase::ui::simdlg_plain $pv]]]]
  }
  set t {}
  foreach {slot head} {deck    {above the analysis block}
                       control {inside the analysis block}
                       cmdline {on the command line}
                       prefile {in the run-directory start-up file}} {
    append t "$head\n"
    set any 0
    foreach e [dict get $pv $slot] {
      append t "    [lindex $e 1]\n" ; set any 1
    }
    if {!$any} { append t "    (nothing)\n" }
  }
  if {[llength [dict get $pv notes]]} {
    append t "not delivered\n"
    foreach n [dict get $pv notes] {
      append t "    [lindex $n 0] — [ase::ui::simdlg_plain [lindex $n 2]]\n"
    }
  }
  $w.prev.t configure -state normal
  $w.prev.t delete 1.0 end
  $w.prev.t insert end $t
  $w.prev.t configure -state disabled
}

# Double-click. A stored row edits; a catalogue row the bench has not stored
# opens the Add editor with the name already filled in.
proc ase::ui::optsheet_pick {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simopt
  if {![winfo exists $w.tv]} { return }
  set sel [lindex [$w.tv selection] 0]
  if {$sel eq {} || [string match grp:* $sel]} { return }
  if {[string is integer -strict $sel]} {
    ase::ui::listdlg_editor $key simopt $sel
    return
  }
  set ed [ase::ui::listdlg_editor $key simopt -1]
  if {$ed ne {} && [winfo exists $ed.name]} {
    $ed.name delete 0 end
    $ed.name insert 0 [lindex [$w.tv item $sel -values] 0]
    catch {focus $ed.value}
  }
}

# --- Setup > Simulators… : the front door of the simulator registry -------
# ISSUE 0937. Issue 0931 built a working registry -- register a simulator of
# your own by name, say which one is in force, save the list so it comes back
# next start -- and shipped it with no way into it: nine menus walked on the
# real session window at 439d1087 and not one entry anywhere mentioned a
# simulator program. The only lever was typing Tcl into the CIW, and even that
# forgot itself, because nothing in the tree called the writer.
#
# ONE WRITER, TWO FRONT DOORS. Everything below drives the SAME procs the CIW
# route drives -- ase::sim_register / sim_unregister / sim_entry / sim_list /
# sim_status / sim_entry_why. No validation, no path resolution and no
# persistence is re-implemented here; a second copy of any of them is how the
# two doors would start disagreeing.
#
# AND AS OF ISSUE 1395 THERE IS NO PERSISTENCE HERE AT ALL, not even one line.
# The write lives on the mutation (ase::sim_register / sim_unregister call
# ase::sim_touch), which is what makes the OTHER door stick too; see the
# tombstone where ase::ui::simdlg_commit used to be. The in-force combobox
# writes to the SESSION rather than to the file, because which simulator is the
# one to use is ASE-L state and the user must save it on purpose --
# ase::ui::simdlg_use carries the ruling in full.
#
# AND NO SENTENCE IS WRITTEN HERE. Ruling D5-4: every user-facing sentence
# about a simulator is minted in ase::sim_why (src/ase.tcl) and only RENDERED
# here, and where the dialog has to show what a gesture just said it reads
# ase::sim_said back rather than composing its own version. Row R9 of
# tests/headless/test_ase_simreg_0931.tcl greps THIS file for the minted
# phrases and reds if one appears; rows S7/S17 compare the label text against
# the mint byte for byte.
#
# NOTHING HERE LOGS. The 0930 menu interceptor already records the pick from
# the Setup entry's own -command; row S13 greps these bodies for a second log
# call.

# The combobox line that means "none of mine". Minted once so the suite can
# ask for it instead of hardcoding a string that would drift (row S4).
proc ase::ui::simdlg_none_label {} {
  return "(none — use the program my system finds on the PATH)"
}

# The backend the session will run, which is what "the program on your PATH"
# is the name of. Defaulted rather than raised: this feeds a label.
proc ase::ui::simdlg_backend {key} {
  set b {}
  catch {set b [ase::state_get [ase::session_state $key] simulator]}
  if {$b eq {}} { set b ngspice }
  return $b
}

# A refusal raised by the registry, made fit to show in a dialog: the internal
# "ase: " prefix is a CIW convention and means nothing to someone reading a
# label three inches from the field they just got wrong.
proc ase::ui::simdlg_plain {msg} {
  if {[string first {ase: } $msg] == 0} { return [string range $msg 5 end] }
  return $msg
}

# Setup > Simulators…
proc ase::ui::simulators_dialog {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simdlg
  catch {destroy $w}
  toplevel $w
  wm title $w {Simulators}
  ttk::treeview $w.tv -columns {name path problem} -show headings \
    -selectmode browse -height 8 -style Ase.Treeview \
    -yscrollcommand [list $w.sb set]
  # Column policy (issue 1398). Measured on the shipped dialog: 420 px of
  # `Problem` — a column that is empty whenever the registry is healthy — while
  # the ngspice path it sits beside measured 370 px in a 300 px `Program`. The
  # room goes to the one column anybody reads, and Program is the only stretchy
  # one, so the three no longer ratchet against each other on a drag.
  foreach c {name path problem} h {Name Program Problem} \
          policy {{14 0 w} {36 1 w} {26 0 w}} {
    lassign $policy glyphs stretch anchor
    $w.tv heading $c -text $h
    $w.tv column $c -width [ase::ui::colw $glyphs $h] \
                    -minwidth [ase::ui::colw 0 $h] \
                    -anchor $anchor -stretch $stretch
  }
  scrollbar $w.sb -orient vertical -command [list $w.tv yview]
  label $w.usel -text {Use this one:} -anchor w
  ttk::combobox $w.use -state readonly -font AseEntryFont \
    -style Ase.TCombobox -textvariable ase::ui::simuse($key)
  bind $w.use <<ComboboxSelected>> [list ase::ui::simdlg_use $key]
  # THE IN-DIALOG FEEDBACK SURFACE, and it is the point of the dialog rather
  # than decoration. Silence is this area's failure mode: Setup > Design and
  # the shared list dialog behind Model Files report their refusals to the
  # CIW only, so the user sits looking at a dialog that did nothing and says
  # nothing. Every sentence that lands here is minted in ase.tcl.
  label $w.status -anchor w -justify left -wraplength 560 -text {}
  set cf {}
  catch {set cf [ase::sim_conf_file]}
  if {$cf ne {}} {
    label $w.where -anchor w -justify left -wraplength 560 \
      -text "Your list is saved in $cf and comes back the next time xschem starts."
  } else {
    label $w.where -anchor w -justify left -wraplength 560 \
      -text {This list cannot be saved in this session, so it will be gone when xschem closes.}
  }
  frame $w.btns
  button $w.btns.add -text {Add…} -command [list ase::ui::simdlg_editor $key {}]
  button $w.btns.edit -text {Edit…} -command [list ase::ui::simdlg_edit $key]
  button $w.btns.remove -text Remove -command [list ase::ui::simdlg_remove $key]
  button $w.btns.close -text Close -command [list ase::ui::simdlg_close $key]
  pack $w.btns.add -side left -padx 5
  pack $w.btns.edit -side left -padx 5
  pack $w.btns.remove -side left -padx 5
  pack $w.btns.close -side right -padx 5
  grid $w.tv     -row 0 -column 0 -sticky nsew -padx {8 0} -pady {8 2}
  grid $w.sb     -row 0 -column 1 -sticky ns   -padx {0 8} -pady {8 2}
  grid $w.usel   -row 1 -column 0 -columnspan 2 -sticky w  -padx 8 -pady {6 0}
  grid $w.use    -row 2 -column 0 -columnspan 2 -sticky we -padx 8
  grid $w.status -row 3 -column 0 -columnspan 2 -sticky we -padx 8 -pady {6 2}
  grid $w.where  -row 4 -column 0 -columnspan 2 -sticky we -padx 8
  grid $w.btns   -row 5 -column 0 -columnspan 2 -sticky we -padx 8 -pady 6
  grid rowconfigure $w 0 -weight 1
  grid columnconfigure $w 0 -weight 1
  # item 10: ESC = the Close button, through the same path, so the per-key
  # records go with it
  ase::ui::bind_dialog_esc $w [list ase::ui::simdlg_close $key]
  ase::ui::simdlg_fill $key
  ase::ui::apply_theme $w
  return $w
}

# Re-read the registry into the list, the combobox and the status line. Called
# after every gesture: the registry is the truth, the widgets are a view of it.
proc ase::ui::simdlg_fill {key} {
  variable wins; variable dlg; variable simuse
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simdlg
  if {![winfo exists $w]} { return }
  $w.tv delete [$w.tv children {}]
  set names {}
  set i 0
  foreach e [ase::sim_list] {
    set n [dict get $e name]
    lappend names $n
    # The Problem cell is ase::sim_entry_why VERBATIM -- the same sentence
    # the user was given when they registered it, worked out fresh now rather
    # than read back from the entry's `ok` flag, which is a boolean with no
    # words in it and answers a question about the past.
    $w.tv insert {} end -id $i \
      -values [list $n [dict get $e path] [ase::sim_entry_why $n]]
    incr i
  }
  set dlg($key,simnames) $names
  set none [ase::ui::simdlg_none_label]
  $w.use configure -values [linsert $names 0 $none]
  ## 1395: THE COMBOBOX SHOWS THIS SESSION'S CHOICE, NOT THE PROCESS-GLOBAL ONE.
  ## ase::sim_selected answers what is in force RIGHT NOW, which is one answer
  ## for every open window; the choice is per-session state (the user's ruling
  ## -- it dirties, it is saved with the bench, it is prompted for on quit) and
  ## this dialog belongs to exactly one session. Reading the global here would
  ## show window two's pick in window one's dialog, and would show it again
  ## after the pick was abandoned unsaved.
  ##
  ## A SESSION THAT HAS EXPRESSED NO CHOICE SHOWS THE INSTALLATION DEFAULT, not
  ## a blank: the blank line in this combobox is the "none of mine" one, and a
  ## bench that has never been asked would then read as a deliberate PATH
  ## choice everywhere a default is registered. ase::sim_choice_of and
  ## ase::sim_default_choice are the only readers of the encoding; no value of
  ## the state key is ever spelled here (an entry genuinely called `none` is
  ## why).
  set choice [ase::sim_choice_of [ase::session_state $key]]
  if {[lindex $choice 0] eq {unset}} { set choice [ase::sim_default_choice] }
  if {[lindex $choice 0] eq {entry}} {
    set simuse($key) [lindex $choice 1]
  } else {
    set simuse($key) $none
  }
  ase::ui::simdlg_status $key
  ## 1370: AND THE BOTTOM BAR OF EVERY OPEN SESSION FOLLOWS, from HERE and not
  ## from the five gestures. Add, Edit, Remove and both arms of the "Use this
  ## one:" combobox all funnel through this proc -- it is the dialog's own
  ## "the registry is the truth, the widgets are a view of it" line -- so one
  ## call covers every path with no duplication and none can be added later
  ## that misses it. Without it the bar goes stale the moment the user changes
  ## the choice and stays stale until the run they were trying to predict
  ## actually starts (`set_status running`), which is exactly the question they
  ## opened this dialog to answer.
  ase::ui::refresh_status_all
}

# THE ONE WRITER OF THE STATUS LABEL. A non-empty `msg` wins -- that is a
# caller handing over the sentence a gesture just said. Otherwise the line
# describes the state, and every branch of it is a rendered mint.
#
# THE ORDER OF THE THREE BRANCHES IS THE PART A READER WOULD GET WRONG. Asking
# "is there anything to say" first looks right and is not: with two simulators
# registered and the user's choice deliberately cleared, the resolver's `why`
# carries the "more than one is registered and none is picked" sentence, which
# is true but is an answer to a question this dialog is the answer to -- the
# list is right there. So a problem is shown only when the resolver could NOT
# honour what is in force (row S4 pins the cleared-choice case).
proc ase::ui::simdlg_status {key {msg {}}} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simdlg
  if {![winfo exists $w]} { return }
  if {$msg ne {}} {
    $w.status configure -text $msg
    return
  }
  set backend [ase::ui::simdlg_backend $key]
  set st [ase::sim_status $backend]
  if {![dict get $st ok]} {
    $w.status configure -text [dict get $st why]
  } elseif {[dict get $st source] eq {registry}} {
    $w.status configure -text \
      [ase::sim_why in_force [dict get $st entry] [dict get $st exe]]
  } else {
    $w.status configure -text [ase::sim_why path_in_force $backend {}]
  }
}

# THERE IS NO simdlg_commit ANY MORE, AND ITS ABSENCE IS THE FIX (issue 1395).
# It used to be this dialog's one line about persistence -- `catch
# {ase::sim_write_conf}` after Add, Edit, Remove and both arms of the combobox
# -- and it was the ONLY caller of the writer in the whole tree. That is what
# made the dialog the only door that stuck: the same registration typed into
# the Command window, which is how this user's own entry was first made, was
# gone at the next start (src/ase_window.tcl:288).
#
# THE WRITE MOVED TO THE MUTATION. ase::sim_register and ase::sim_unregister
# call ase::sim_touch themselves now, origin-gated so the reader of the saved
# list cannot rewrite the file it is sourcing. Every door persists, including
# the ones nobody has written yet, and this file's own rule at the head of the
# section -- no persistence is re-implemented here -- finally has nothing to
# except. A second write from the gesture would be a second writer of the
# user's file for one gesture: the same bytes twice on the good path, and on a
# failing path a second sentence about a save that already reported itself
# (row S8 of tests/headless/test_ase_simreg_0931.tcl pins that count at one).
#
# AND THE CHOICE DOES NOT REACH DISK AT ALL. ase::ui::simdlg_use sets the
# session's state key; see its own header.

# The name of the row the user clicked, or {} with the status line telling
# them to click one. Two buttons need it, so the sentence is written once.
proc ase::ui::simdlg_selected_name {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return {} }
  set w [dict get $wins $key].simdlg
  if {![winfo exists $w]} { return {} }
  set sel [$w.tv selection]
  if {$sel eq {}} {
    ase::ui::simdlg_status $key \
      {Click the simulator you want in the list above first, then press that button again.}
    return {}
  }
  set names {}
  if {[info exists dlg($key,simnames)]} { set names $dlg($key,simnames) }
  set i [lindex $sel 0]
  if {![string is integer -strict $i] || $i < 0 || $i >= [llength $names]} { return {} }
  return [lindex $names $i]
}

# --- THE CASE CHOOSER (issue 1371) ------------------------------------------
#
# WHAT WAS BROKEN. ase::sim_capabilities MEASURES which spellings of a net name
# the user's build can hand back, ase::sim_casemode_requested reads the request
# off the registry entry, and ase::run_casemode_flag turns it into
# `-D casemode=`. Every link worked except the one that lets a person ask: this
# editor built exactly two rows, Name and Program, so the `casemode` field could
# only be set by hand-editing the saved list. The user's own build was measured
# `fold preserve distinguish`, their entry carried `casemode {}`, the request
# fell to the global floor `fold`, and their VBG net came back as `v(vbg)`.
# `fluid-editing` HAD this door -- a second line per simulator row, Exe / Args /
# Case / -n / Test -- and it was deleted at the annotate merge on the promise
# that these fields are registry-entry properties now and this dialog is their
# one door. The store moved; the door was never built. See the tombstone at
# src/xschem.tcl (simconf), which records the promise.
#
# RULE A1 IS THE WHOLE POINT: never offer a mode the binary was not measured to
# deliver. So the chooser's values come from the measurement and from nowhere
# else, and ase::ui::simdlg_case_values is the only place in this file that
# asks -- row S31 of tests/headless/test_ase_simdlg_0937.tcl pins that, so a
# second copy of the rule cannot appear behind the dialog. (This line named
# "row S20f" until issue 1371's adversary read it: there is no such row.)
#
# THE LABELS ARE THE ENGINE'S OWN WORDS, DELIBERATELY. `fold`, `preserve` and
# `distinguish` are what the user types into their saved simulator list and
# what ase::sim_register validates; prettifying them here would make the dialog
# and the file disagree about the same setting.

# label <-> stored value, both directions, so nothing has to guess. `{}` is the
# entry's "no request of my own", which is NOT the same as `fold`: it defers to
# the global floor, and the label names whichever mode that floor currently is.
# A mode stored on the entry that the program was not measured to deliver is
# shown MARKED rather than dropped -- opening this dialog must never silently
# change what the user hand-wrote.
#
# ⚠ THERE ARE TWO MARKS, NOT ONE, AND ISSUE 1371's ADVERSARY IS WHY. The mark
# used to be `(NOT measured)` for both of the states below, and both are
# reachable:
#
#   `not tried yet`  nobody has measured this program, so nothing is known
#                    about this mode either way. That is the legacy shape row
#                    S30 is about -- until this item landed, hand-editing the
#                    saved list was the ONLY way to ask for a case mode -- and
#                    it is ALSO what the user sees the moment after they press
#                    OK, because ase::sim_register's look-again (issue 0950,
#                    row D10 of tests/headless/test_ase_simcaps_0948.tcl)
#                    forgets every measurement on every registry edit,
#                    deliberately and by a ratified rule.
#   `NOT supported`  the program at the location in the Program field WAS
#                    measured and does not deliver this mode. Measured, not
#                    unknown -- upper case, because the user is looking at a
#                    setting their own program has already contradicted.
#
# Calling the second one `(NOT measured)` was a false statement about a
# measurement taken 449 ms earlier, and it is the one a user reaches by
# retyping the Program field -- the A1 breach this door exists to prevent.
proc ase::ui::simdlg_case_label {mode {state ok}} {
  if {$mode eq {}} { return "global default ([ase::sim_casemode_floor])" }
  switch -- $state {
    untried     { return "$mode (not tried yet)" }
    unsupported { return "$mode (NOT supported)" }
  }
  return $mode
}

proc ase::ui::simdlg_case_value {label} {
  if {[string first {global default} $label] == 0} { return {} }
  return [lindex [split [string trim $label] { }] 0]
}

# WHAT THIS ROW MAY OFFER. Keyed on the program named in the PROGRAM FIELD, not
# on the simulator in force and not on the entry's stored path: the user may
# have just typed a different location into that field, and offering the old
# program's modes would be the same A1 breach as offering the in-force row's.
#
# ⚠ CACHED ANSWERS ONLY -- ase::sim_caps_have_path is a peek and starts
# nothing. The accessor it guards LAUNCHES the program when the answer is not
# in hand: measured 447 ms cold on the user's own build, 0 ms warm, and 31.2
# seconds for a program that exists and never answers, with Tk frozen
# throughout. Opening a row editor must not be a gesture that starts the user's
# simulator -- for a licensed tool it would check out a licence. Detect is the
# door to the other case, and it says what it is doing before it blocks.
# WHAT THE PROCS BELOW ALL NEED, WORKED OUT ONCE: which backend, which program,
# which extra arguments it would really be started with, what the entry has
# stored, and whether a fresh measurement of that program is already in hand.
# The last term decides both which mark a mode gets and whether the offer may
# be anything other than `fold`.
#
# THE ARGUMENTS COME FROM THE ENTRY AND THE LOCATION FROM THE FIELD, because
# that pair is what OK is about to register. It is also the pair the capability
# cache is keyed on since this item's repair (ase::cap_key): asking about a
# file with somebody else's argv used to overwrite the in-force answer, and the
# peek below could answer about one argv while the offer was built from
# another.
proc ase::ui::simdlg_case_ctx {key name} {
  variable wins
  set path {}
  if {[dict exists $wins $key]} {
    set w [dict get $wins $key].simrow
    if {[winfo exists $w]} { set path [string trim [$w.path get]] }
  }
  set backend [ase::ui::simdlg_backend $key]
  set stored {}
  set eargs {}
  set e [ase::sim_entry $name]
  if {$e ne {}} {
    set stored [ase::state_get $e casemode {}]
    set eargs [ase::state_get $e args {}]
    set eb [ase::state_get $e backend {}]
    if {$eb ne {}} { set backend $eb }
  }
  return [list $backend $path $eargs $stored \
            [ase::sim_caps_have_path $backend $path $eargs]]
}

# WHICH MARK A MODE OUTSIDE THE OFFER GETS -- measured-and-cannot, or nobody
# asked. One place decides, because the chooser's values and the live pick have
# to agree about the same program.
proc ase::ui::simdlg_case_mark {key name} {
  if {[lindex [ase::ui::simdlg_case_ctx $key $name] 4]} { return unsupported }
  return untried
}

proc ase::ui::simdlg_case_values {key name} {
  lassign [ase::ui::simdlg_case_ctx $key $name] backend path eargs stored have
  set sel fold
  if {$have} {
    set sel [ase::sim_casemode_selectable_path $backend $path $eargs]
  }
  set out [list [ase::ui::simdlg_case_label {}]]
  foreach m $sel { lappend out [ase::ui::simdlg_case_label $m] }
  if {$stored ne {} && [lsearch -exact $sel $stored] < 0} {
    lappend out [ase::ui::simdlg_case_label $stored \
                   [ase::ui::simdlg_case_mark $key $name]]
  }
  return $out
}

# Fill the chooser and put `mode` in it. A mode that is in neither the measured
# set nor the entry's own record is APPENDED rather than dropped -- that is the
# user's live pick surviving a Detect that no longer offers it, and silently
# moving their selection would be worse than showing it marked.
proc ase::ui::simdlg_case_show {key name mode} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simrow
  if {![winfo exists $w] || ![winfo exists $w.casemode]} { return }
  set vals [ase::ui::simdlg_case_values $key $name]
  set lbl [ase::ui::simdlg_case_label $mode]
  if {[lsearch -exact $vals $lbl] < 0} {
    set lbl [ase::ui::simdlg_case_label $mode \
               [ase::ui::simdlg_case_mark $key $name]]
    if {[lsearch -exact $vals $lbl] < 0} { lappend vals $lbl }
  }
  $w.casemode configure -values $vals
  $w.casemode set $lbl
}

# THE PROGRAM FIELD CHANGED, SO THE OFFER CHANGES WITH IT -- issue 1371's own
# refutation, measured end to end. The item claimed the chooser was keyed on
# the program named in the FIELD "because the user may have just typed a
# different location in". It was -- but it was only ever BUILT at editor-open
# and by Detect, and NOTHING REBUILT IT WHEN THE FIELD CHANGED. Measured
# through the real widgets on 2026-09-06: an entry whose program measures
# `fold preserve distinguish`, the location of a build measuring `fold` alone
# typed into the Program field, and the chooser still offered `preserve`; OK
# then saved `casemode preserve` for that build, `ase::sim_casemode_requested`
# answered `preserve` and `ase::run_casemode_flag` emitted
# `-D casemode=preserve` for a program measured not to deliver it. That is rule
# A1 broken by the door built to enforce A1, through the exact gesture the
# claim cited -- and by Browse…, with no typing at all.
#
# THE PICK IS KEPT AND MARKED, NEVER SILENTLY MOVED. Half a location typed into
# the field names no program at all, so a rebuild that reset the selection
# would destroy the user's choice one keystroke at a time. It stays, and its
# mark becomes `(NOT supported)` the moment the field names a program that was
# measured and cannot deliver it -- a statement in front of the user, before
# they press OK.
#
# ⚠ VALIDATION, NOT A KEY BINDING, and the `after idle` is not decoration. A
# validate command runs BEFORE the entry's own content changes, so reading
# $w.path inside it returns the text as it WAS; the rebuild is deferred to the
# idle point, by which time the widget holds what the user is looking at.
# Validation also fires for a programmatic delete/insert, which is how
# simdlg_browse writes the field -- one mechanism covers the typing and the
# file browser both, and neither can be forgotten separately.
proc ase::ui::simdlg_path_changed {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return 1 }
  set w [dict get $wins $key].simrow
  if {![winfo exists $w] || ![winfo exists $w.casemode]} { return 1 }
  set name {}
  if {[info exists dlg($key,simrow)]} { set name $dlg($key,simrow) }
  ase::ui::simdlg_case_show $key $name \
    [ase::ui::simdlg_case_value [$w.casemode get]]
  return 1
}

proc ase::ui::simdlg_path_validate {key} {
  after idle [list ase::ui::simdlg_path_changed $key]
  return 1
}

# WHAT THE EDITOR SAYS ABOUT THE PROGRAM IT IS LOOKING AT, WITHOUT TRYING IT.
# The sentence is ase::casemode_status's -- this file composes none (ruling
# D5-4) -- and the reason it exists is the COLD SESSION. The chooser correctly
# offers `fold` alone until something has been measured, and until this line
# nothing told the user that Detect is what changes that: the four-click
# gesture this item's own issue file described ("Edit… -> pick preserve -> OK")
# is a six-click gesture on a fresh xschem, and a user following the short one
# finds no `preserve` and concludes nothing was fixed. That is the very
# confusion the item was filed about.
#
# SILENT ON AN EMPTY FIELD, deliberately: an untouched Add form makes no claim
# about a program the user has not named yet. Detect pressed on one answers for
# itself.
proc ase::ui::simdlg_case_status {key name} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simrow
  if {![winfo exists $w] || ![winfo exists $w.status]} { return }
  lassign [ase::ui::simdlg_case_ctx $key $name] backend path eargs stored have
  if {$path eq {}} { return }
  $w.status configure -text [ase::casemode_status $backend $path $eargs]
}

# Detect. THE ONLY PLACE IN THIS DIALOG THAT MAY START A PROCESS, and it says
# so first: the sentence is painted and the display flushed BEFORE the launch,
# because the launch blocks Tk and a status line that arrived afterwards would
# only ever be read as a report about something that had already finished.
#
# IT MEASURES WHAT IS IN THE PROGRAM FIELD, which is what the user is looking
# at -- so it works on Add, where there is no entry yet, as well as on Edit.
proc ase::ui::simdlg_detect {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simrow
  if {![winfo exists $w]} { return }
  set name {}
  if {[info exists dlg($key,simrow)]} { set name $dlg($key,simrow) }
  set path [string trim [$w.path get]]
  set backend [ase::ui::simdlg_backend $key]
  set eargs {}
  set e [ase::sim_entry $name]
  if {$e ne {}} {
    set eargs [ase::state_get $e args {}]
    set eb [ase::state_get $e backend {}]
    if {$eb ne {}} { set backend $eb }
  }
  set mode [ase::ui::simdlg_case_value [$w.casemode get]]
  # NOTHING NAMED, NOTHING STARTED, AND NOTHING CLAIMED. Add… then Detect is
  # two clicks from a menu, and it used to print "Trying  now, to find out
  # which spellings of a net name it can hand back." followed by " has not been
  # tried yet ...": two sentences with no subject and a leading space, about no
  # program. ase::sim_capabilities_path guarded the LAUNCH against an empty
  # path; the sentences were painted either side of it and were guarded by
  # nothing.
  if {$path eq {}} {
    $w.status configure -text [ase::casemode_status $backend $path $eargs]
    return
  }
  $w.status configure -text [ase::sim_why casemode_measuring {} $path]
  update idletasks
  set caps [dict create known 0]
  catch {set caps [ase::sim_capabilities_path $backend $path $eargs]}
  if {![winfo exists $w]} { return }
  ase::ui::simdlg_case_show $key $name $mode
  $w.status configure -text [ase::casemode_report $backend $path $caps]
}

# The four-field row editor. An empty `name` is the Add flavor; anything else
# is Edit, and then the Name field is READ-ONLY -- a rename here would have to
# be a remove plus an add, which moves the entry to the end of the list and
# fires the "you removed X" sentence in the middle of what the user
# experienced as a rename.
#
# ROW ORDER IS PART OF THE WIDGET CONTRACT the suite asserts, but the suite
# addresses every widget by PATH, never by grid row, so adding rows here does
# not move anything it can see: Name 0, Program 1 (+ Browse in column 2),
# Case 2 (+ Detect in column 2), -n 3, status 4, buttons 5.
proc ase::ui::simdlg_editor {key name} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  set title {Add Simulator}
  if {$name ne {}} { set title {Edit Simulator} }
  set w [ase::ui::dialog_frame $top.simrow $title]
  set dlg($key,simrow) $name
  set en [ase::ui::dialog_row $w 0 {Name:} name]
  set ep [ase::ui::dialog_row $w 1 {Program:} path]
  button $w.browse -text {Browse…} -command [list ase::ui::simdlg_browse $key]
  grid $w.browse -row 1 -column 2 -sticky w -padx {6 8} -pady 2
  label $w.lcasemode -text {Case:} -font AseLabelFont -anchor w
  ttk::combobox $w.casemode -width 24 -state readonly -font AseEntryFont \
    -style Ase.TCombobox
  grid $w.lcasemode -row 2 -column 0 -sticky w  -padx {8 6} -pady 2
  grid $w.casemode  -row 2 -column 1 -sticky we -padx {0 8} -pady 2
  button $w.detect -text Detect -command [list ase::ui::simdlg_detect $key]
  grid $w.detect -row 2 -column 2 -sticky w -padx {6 8} -pady 2
  label $w.lnospiceinit -text {-n:} -font AseLabelFont -anchor w
  set dlg($key,simns) 0
  checkbutton $w.nospiceinit -text {--no-spiceinit} -anchor w \
    -variable ase::ui::dlg($key,simns)
  grid $w.lnospiceinit -row 3 -column 0 -sticky w  -padx {8 6} -pady 2
  grid $w.nospiceinit  -row 3 -column 1 -sticky we -padx {0 8} -pady 2
  # the editor's OWN feedback surface: a refusal about what was just typed
  # belongs where the typing is, not only in the CIW behind the dialog. Empty
  # until there is something to say, so an untouched editor makes no claim.
  label $w.status -anchor w -justify left -wraplength 420 -text {}
  grid $w.status -row 4 -column 0 -columnspan 3 -sticky we -padx 8 -pady {4 0}
  set mode {}
  if {$name ne {}} {
    $en insert 0 $name
    set e [ase::sim_entry $name]
    if {$e ne {}} {
      $ep insert 0 [ase::state_get $e path {}]
      set mode [ase::state_get $e casemode {}]
      set dlg($key,simns) [expr {[ase::state_get $e nospiceinit 0] ? 1 : 0}]
    }
    $en configure -state readonly
  }
  ase::ui::simdlg_case_show $key $name $mode
  # THE OFFER FOLLOWS THE FIELD FROM HERE ON. Wired AFTER the initial insert
  # above, so opening the editor does not schedule a rebuild of what was just
  # built. The status line is repainted when the field is left rather than on
  # every keystroke: a half-typed location names no file, and a sentence about
  # it flickering under the user's hands would be noise, while the OFFER has to
  # follow every character or A1 is only true between gestures.
  $ep configure -validate key \
    -validatecommand [list ase::ui::simdlg_path_validate $key]
  bind $ep <FocusOut> [list ase::ui::simdlg_case_status $key $name]
  ase::ui::simdlg_case_status $key $name
  bind $en <Return> [list ase::ui::simdlg_ok $key]
  bind $ep <Return> [list ase::ui::simdlg_ok $key]
  ase::ui::dialog_buttons $w 5 [list ase::ui::simdlg_ok $key] \
    [list ase::ui::simdlg_cancel $key]
  ase::ui::apply_theme $w
  if {$name eq {}} { focus $en } else { focus $ep }
  return $w
}

# Edit… on the clicked row.
proc ase::ui::simdlg_edit {key} {
  set n [ase::ui::simdlg_selected_name $key]
  if {$n eq {}} { return }
  ase::ui::simdlg_editor $key $n
}

# Browse… beside the Program field.
#
# NOT COVERED BY ANY SUITE, AND THAT IS A PROPERTY OF tk_getOpenFile, NOT AN
# OVERSIGHT: it grabs the display and waits for a human, so no headless or
# Xvfb run can press OK in it (wviewer::rawbar_browse declares the same
# limit). Row S14a asserts this body instead -- that it really opens a file
# browser and really writes the answer into the Program field.
proc ase::ui::simdlg_browse {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simrow
  if {![winfo exists $w]} { return }
  set init [string trim [$w.path get]]
  if {$init ne {}} { set init [file dirname $init] }
  if {$init eq {} || ![file isdirectory $init]} { set init [pwd] }
  set f {}
  catch {set f [tk_getOpenFile -parent $w -initialdir $init \
                  -title {Choose the simulator program to run}]}
  if {$f eq {}} { return }
  $w.path delete 0 end
  $w.path insert 0 $f
  # The Case offer follows through the entry's own validation (see
  # ase::ui::simdlg_path_validate); the status line is the half that is bound
  # to leaving the field, and nobody leaves a field they never typed in.
  set name {}
  variable dlg
  if {[info exists dlg($key,simrow)]} { set name $dlg($key,simrow) }
  ase::ui::simdlg_case_status $key $name
}

# OK in the row editor.
#
# A BAD PATH IS RECORDED, NOT REFUSED -- that is the registry's own rule, and
# the dialog must not quietly tighten it: refusing would throw the user's
# typing away mid-gesture and leave them nothing to fix. What the dialog adds
# is that the reason lands where they are looking, in the row's Problem cell
# and on the status line, in the same words the CIW got.
#
# A malformed CALL is different and does keep the editor up: an entry with no
# name cannot be stored, looked up or removed, so there is nothing to record.
#
# EVERY FIELD OF THE ENTRY IS WRITTEN, THE SHOWN ONES FROM THE FORM AND THE
# REST CARRIED THROUGH UNCHANGED. An entry also carries extra arguments and the
# backend it was registered for; they have no fields here, and an editor that
# rebuilt the entry from its visible fields alone would silently delete them.
#
# ⚠ THIS COMMENT USED TO SAY "EVERYTHING THE DIALOG DOES NOT SHOW IS CARRIED
# THROUGH", AND IT WAS THE THING THAT MISLED THE LAST READER (issue 1371). The
# proc did not do that: it rebuilt the entry from `args` and `backend` only, so
# opening Edit… on an entry with a case mode and pressing OK WITHOUT TYPING
# ANYTHING erased `casemode` and `nospiceinit` and saved the erasure -- measured
# through the real widgets, and it survived the restart because the erased list
# is what got written. Row S9 asserted the claim for `args` and `backend` alone,
# so the suite was green over the hole; it now covers all four.
proc ase::ui::simdlg_ok {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].simrow
  if {![winfo exists $w]} { return }
  set editing {}
  if {[info exists dlg($key,simrow)]} { set editing $dlg($key,simrow) }
  set name [string trim [$w.name get]]
  set path [string trim [$w.path get]]
  set eargs {}
  set backend {}
  if {$editing ne {}} {
    set name $editing
    set e [ase::sim_entry $editing]
    if {$e ne {}} {
      set eargs [ase::state_get $e args {}]
      set backend [ase::state_get $e backend {}]
    }
  }
  set casemode {}
  if {[winfo exists $w.casemode]} {
    set casemode [ase::ui::simdlg_case_value [$w.casemode get]]
  }
  set nospiceinit 0
  if {[info exists dlg($key,simns)]} {
    set nospiceinit [expr {$dlg($key,simns) ? 1 : 0}]
  }
  ase::sim_said_clear
  if {[catch {ase::sim_register $name $path -args $eargs -backend $backend \
                -casemode $casemode -nospiceinit $nospiceinit} err]} {
    $w.status configure -text [ase::ui::simdlg_plain $err]
    return
  }
  array unset dlg $key,simrow
  array unset dlg $key,simns
  destroy $w
  ## NO WRITE HERE (1395): ase::sim_register has already saved the list, and
  ## the sentence a failed save leaves is still inside this gesture's
  ## sim_said_clear / sim_said bracket, which spans the register call.
  ase::ui::simdlg_fill $key
  set said [ase::sim_said]
  if {$said ne {}} { ase::ui::simdlg_status $key $said }
}

proc ase::ui::simdlg_cancel {key} {
  variable wins; variable dlg
  array unset dlg $key,simrow
  array unset dlg $key,simns
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].simrow}
  }
}

# Remove. WORKS ON THE ENTRY CURRENTLY IN FORCE, by construction -- and says
# what happens next, which is the half that did not exist before issue 0937:
# removing the one in force silently promoted the survivor, or silently handed
# control back to the program on the PATH, and printed nothing at all.
proc ase::ui::simdlg_remove {key} {
  set n [ase::ui::simdlg_selected_name $key]
  if {$n eq {}} { return }
  ase::sim_said_clear
  if {[catch {ase::sim_unregister $n} err]} {
    ase::ui::simdlg_status $key [ase::ui::simdlg_plain $err]
    return
  }
  ## NO WRITE HERE (1395): ase::sim_unregister has already saved the list.
  ase::ui::simdlg_fill $key
  set said [ase::sim_said]
  if {$said ne {}} { ase::ui::simdlg_status $key $said }
}

# The in-force combobox. "None of mine" is a choice like any other -- without
# recording it the next start silently puts the first entry back in charge and
# the gesture is undone (issue 0932).
#
# ⚠ THIS GESTURE WRITES NOTHING TO DISK, AND THAT IS THE USER'S RULING, NOT AN
# OVERSIGHT (issue 1395). Verbatim, 2026-09-08: *whether* a registered
# simulator "gets assigned as 'the one to use' is an option that is part of the
# ASE-L state. If changed, that results in dirtiness. User must explicitly save
# and, if user initiates an Xschem shutdown, then she must get a warning and a
# prompt to save." Before this, the pick went straight to
# ~/.xschem/ase_simulators with no save gesture behind it -- from a window the
# user might be about to abandon, and overwriting the installation default with
# one bench's opinion. REGISTERING is environment and lands at once
# (ase::sim_register calls ase::sim_touch); CHOOSING is state and waits.
#
# SO THE PICK GOES THREE PLACES AND NO FURTHER:
#   1. the session's own state, through ase::sim_choice_set -- which is what
#      makes ase::session_dirty answer 1, the title grow its marker and the
#      quit sweep stop and ask;
#   2. ase::session_update, the one write path the panes share, whose notify
#      is what repaints both of those;
#   3. ase::sim_apply_choice, so what is IN FORCE this instant agrees with what
#      the user just picked -- the bottom bar and the next run read that, and a
#      dialog whose combobox and whose bar disagreed would be issue 1370 again.
#
# `key` IS LOAD-BEARING NOW. It always named the session whose widgets are
# being refreshed; as of 1395 it also names the session whose state is being
# changed, which is why the choice can differ between two open windows while
# the registry cannot.
#
# NO ENCODING IS SPELLED HERE. ase::sim_choice_set is the only writer of the
# state key, for the reason its header gives: a dialog that stored the bare
# name would work for every entry except one called `none`.
proc ase::ui::simdlg_use {key} {
  variable simuse
  set v {}
  if {[info exists simuse($key)]} { set v $simuse($key) }
  ase::sim_said_clear
  if {$v eq [ase::ui::simdlg_none_label] || $v eq {}} {
    set st [ase::sim_choice_set [ase::session_state $key] path]
  } elseif {[ase::sim_entry $v] eq {}} {
    ## A NAME NOBODY HAS REGISTERED. The widget goes back to showing the truth
    ## and the session's choice is left alone -- storing it would dirty the
    ## bench with a pick that cannot run and would then show it back as the
    ## truth. THE REFUSAL IS THE REGISTRY'S OWN WORDS: ase::sim_apply_choice
    ## never raises, so the sentence is asked of ase::sim_select, which refuses
    ## exactly this and changes nothing while doing it (ruling D5-4 -- no
    ## sentence is minted in this file).
    set err {}
    catch {ase::sim_select $v} err
    ase::ui::simdlg_fill $key
    ase::ui::simdlg_status $key [ase::ui::simdlg_plain $err]
    return
  } else {
    set st [ase::sim_choice_set [ase::session_state $key] entry $v]
  }
  ase::session_update $key $st
  ## ON $st, NOT ON THE SESSION: ase::session_update answers 0 for a key it does
  ## not know, and applying the session's state then would put the OLD choice in
  ## force while the widget showed the new one.
  ase::sim_apply_choice $st
  ase::ui::simdlg_fill $key
  set said [ase::sim_said]
  if {$said ne {}} { ase::ui::simdlg_status $key $said }
}

# Close / ESC. The row editor goes with it: it is a child dialog of this one
# in everything but Tk parentage.
proc ase::ui::simdlg_close {key} {
  variable wins; variable dlg; variable simuse
  array unset dlg $key,simnames
  array unset dlg $key,simrow
  array unset dlg $key,simns
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].simrow}
    catch {destroy [dict get $wins $key].simdlg}
  }
  catch {unset simuse($key)}
}

proc ase::ui::listdlg_open {key which title} {
  variable wins; variable listdlg
  if {![dict exists $wins $key]} { return }
  set cfg [dict get $listdlg $which]
  set w [dict get $wins $key].[dict get $cfg win]
  catch {destroy $w}
  toplevel $w
  wm title $w $title
  set cols [dict get $cfg cols]
  ttk::treeview $w.tv -columns $cols -show headings -selectmode extended \
    -height 8 -style Ase.Treeview -yscrollcommand [list $w.sb set]
  # Column policy (issue 1398). Both configured tables are two columns whose
  # FIRST holds the long value — a model-file path, a simulation-option name —
  # so the first stretches and the rest are fixed at their own content width.
  set first 1
  foreach c $cols h [dict get $cfg heads] {
    $w.tv heading $c -text $h
    $w.tv column $c -width [ase::ui::colw 20 $h] \
                    -minwidth [ase::ui::colw 0 $h] \
                    -anchor w -stretch $first
    set first 0
  }
  scrollbar $w.sb -orient vertical -command [list $w.tv yview]
  frame $w.btns
  button $w.btns.close -text Close -command [list destroy $w]
  pack $w.btns.close -side right -padx 5
  pack $w.btns -side bottom -fill x -padx 8 -pady 6
  pack $w.sb -side right -fill y
  pack $w.tv -side left -fill both -expand 1
  menu $w.ctx -tearoff 0
  $w.ctx add command -label "Add…" \
    -command [list ase::ui::listdlg_editor $key $which -1]
  $w.ctx add command -label "Edit…" \
    -command [list ase::ui::listdlg_edit_first $key $which]
  $w.ctx add command -label Delete \
    -command [list ase::ui::listdlg_delete $key $which]
  bind $w.tv <Button-3> [list ase::ui::listdlg_ctx $key $which %X %Y]
  bind $w.tv <Delete> [list ase::ui::listdlg_delete $key $which]
  # item 10: ESC = the Close button (the list dialog keeps no records —
  # every mutation commits immediately, D15)
  ase::ui::bind_dialog_esc $w [list destroy $w]
  ase::ui::listdlg_fill $key $which
  ase::ui::apply_theme $w
  return $w
}

proc ase::ui::listdlg_fill {key which} {
  variable wins; variable listdlg
  if {![dict exists $wins $key]} { return }
  set cfg [dict get $listdlg $which]
  ## ⚠ ONE EDITOR, TWO SURFACES (§7c, issue 1441). `listdlg_ok` and
  ## `listdlg_delete` repaint through here, and the options sheet is not a
  ## two-column list any more -- it has groups, a badge column and a deck
  ## preview to refresh. A cfg that names its own painter keeps the EDITOR
  ## shared, which is the half that must not fork: two Add… paths writing the
  ## same state key is how the two doors start disagreeing.
  if {[dict exists $cfg fill]} { return [[dict get $cfg fill] $key] }
  set tv [dict get $wins $key].[dict get $cfg win].tv
  if {![winfo exists $tv]} { return }
  $tv delete [$tv children {}]
  set i 0
  foreach row [ase::state_get [ase::session_state $key] [dict get $cfg skey]] {
    set vals {}
    foreach f [dict get $cfg cols] { lappend vals [ase::state_get $row $f] }
    $tv insert {} end -id $i -values $vals
    incr i
  }
}

proc ase::ui::listdlg_ctx {key which X Y} {
  variable wins; variable listdlg
  if {![dict exists $wins $key]} { return }
  set m [dict get $wins $key].[dict get $listdlg $which win].ctx
  if {![winfo exists $m]} { return }
  tk_popup $m $X $Y
}

# The two-entry row editor (Add flavor: idx -1). OK merges the fields over
# the row's ORIGINAL dict and commits immediately (D15).
proc ase::ui::listdlg_editor {key which idx} {
  variable wins; variable listdlg; variable dlg
  if {![dict exists $wins $key]} { return }
  set cfg [dict get $listdlg $which]
  set rows [ase::state_get [ase::session_state $key] [dict get $cfg skey]]
  set row {}
  if {$idx >= 0} {
    if {![string is integer -strict $idx] || $idx >= [llength $rows]} { return }
    set row [lindex $rows $idx]
  } else {
    set idx -1
  }
  set w [ase::ui::dialog_frame [dict get $wins $key].[dict get $cfg ed] \
    [expr {$idx >= 0 ? "Edit [dict get $cfg edtitle]" : "Add [dict get $cfg edtitle]"}]]
  set dlg($key,$which) $idx
  set r 0
  foreach f [dict get $cfg cols] h [dict get $cfg heads] {
    set e [ase::ui::dialog_row $w $r "$h:" $f]
    $e insert 0 [ase::state_get $row $f]
    bind $e <Return> [list ase::ui::listdlg_ok $key $which]
    incr r
  }
  ase::ui::dialog_buttons $w $r [list ase::ui::listdlg_ok $key $which] \
    [list ase::ui::listdlg_editor_cancel $key $which]
  ase::ui::apply_theme $w
  focus $w.[lindex [dict get $cfg cols] 0]
  return $w
}

proc ase::ui::listdlg_edit_first {key which} {
  variable wins; variable listdlg
  if {![dict exists $wins $key]} { return }
  set tv [dict get $wins $key].[dict get $listdlg $which win].tv
  set sel {}
  if {[winfo exists $tv]} { set sel [$tv selection] }
  if {$sel eq {}} {
    catch {::ase::echo "ase: nothing selected"}
    return
  }
  ase::ui::listdlg_editor $key $which [lindex $sel 0]
}

# ⚠ WHAT A ROW BEING ADDED FROM **THIS** SURFACE SHOULD REMEMBER, as `{key value
# ...}` pairs. Empty for an edit, and empty for a dialog whose config declares no
# stamp.
#
# ⚠ THE STAMP IS FOR NEW ROWS ONLY. Editing a row must not silently move it
# between scopes because of which sheet happened to be open -- the user opened
# the tran sheet to change a number, not to re-scope a global. Un-scoping is a
# Delete and a re-Add, which is visible.
#
# ⚠ AND IT IS A PROC RATHER THAN TWO LINES INSIDE `listdlg_ok` BECAUSE OF A
# SABOTAGE. `listdlg_ok` runs off a live dialog's entry widgets, so a headless
# row cannot drive it, and the new-row guard was therefore unreachable: the
# respelling *"stamp every row, new or edited"* SURVIVED a campaign against it.
# This is the shape issue 1441 found for the same problem -- if a guard cannot
# be reached, the API is wrong before the test is.
proc ase::ui::listdlg_stamp_pairs {cfg key idx} {
  if {$idx >= 0} { return {} }
  if {![dict exists $cfg stamp]} { return {} }
  set pairs {}
  catch {set pairs [[dict get $cfg stamp] $key]}
  return $pairs
}

proc ase::ui::listdlg_ok {key which} {
  variable wins; variable listdlg; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,$which)]} { return }
  set cfg [dict get $listdlg $which]
  set w [dict get $wins $key].[dict get $cfg ed]
  if {![winfo exists $w]} { return }
  set cols [dict get $cfg cols]
  set first [string trim [$w.[lindex $cols 0] get]]
  if {$first eq {}} {
    catch {::ase::echo "ase: '[lindex [dict get $cfg heads] 0]' must not be empty" error}
    return
  }
  set idx $dlg($key,$which)
  set st [ase::session_state $key]
  set rows [ase::state_get $st [dict get $cfg skey]]
  if {$idx < 0} {
    set row [dict create]
  } elseif {$idx < [llength $rows]} {
    set row [lindex $rows $idx]
  } else {
    ase::ui::listdlg_editor_cancel $key $which
    return
  }
  foreach f $cols { dict set row $f [string trim [$w.$f get]] }
  ## --- §7e (issue 1442): A NEW ROW REMEMBERS WHICH SURFACE ADDED IT ---------
  foreach {sk sv} [ase::ui::listdlg_stamp_pairs $cfg $key $idx] {
    dict set row $sk $sv
  }
  if {$idx < 0} { lappend rows $row } else { lset rows $idx $row }
  dict set st [dict get $cfg skey] $rows
  ase::session_update $key $st        ;# D15: every mutation commits at once
  array unset dlg $key,$which
  destroy $w
  ase::ui::listdlg_fill $key $which
}

proc ase::ui::listdlg_editor_cancel {key which} {
  variable wins; variable listdlg; variable dlg
  array unset dlg $key,$which
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].[dict get $listdlg $which ed]}
  }
}

# ctx Delete / the Delete key on the dialog treeview (D1: dialog-local —
# never coupled to the main panes' selection model).
proc ase::ui::listdlg_delete {key which} {
  variable wins; variable listdlg
  if {![dict exists $wins $key]} { return }
  set cfg [dict get $listdlg $which]
  set tv [dict get $wins $key].[dict get $cfg win].tv
  if {![winfo exists $tv]} { return }
  set sel [$tv selection]
  if {$sel eq {}} {
    catch {::ase::echo "ase: nothing selected"}
    return
  }
  set st [ase::session_state $key]
  set rows [ase::state_get $st [dict get $cfg skey]]
  foreach i [lsort -integer -decreasing $sel] {
    if {[string is integer -strict $i] && $i >= 0 && $i < [llength $rows]} {
      set rows [lreplace $rows $i $i]
    }
  }
  dict set st [dict get $cfg skey] $rows
  ase::session_update $key $st        ;# D15
  ase::ui::listdlg_fill $key $which
}

# --- (d) Outputs > Save All --------------------------------------------------

# Outputs > Save All…: the THREE blanket checkboxes writing save_all_v /
# save_all_i / save_op_params (deck mapping in ase.tcl: allv -> `.save all`,
# alli -> `.options savecurrents`, opparams -> the op_annot device
# operating-point `.save` card block, plan step S4 / issue 0617); the Levels
# entry is present-but-DISABLED and backed by NO state key (D11 — a schema
# addition would ripple into the protected byte-identity fixture).
#
# ⚠ THE GRID ROWS ARE HARDCODED. opparams takes row 2, so Levels moved to 3
# and the button bar to 4. The widget PATHS (.allv .alli .levels
# .btns.proceed) are what the dialog suites drive, and they are unchanged.
# --- 0650 / R-0653-d req 2: ONE SOURCE FOR THE THREE LABELS ------------------
# "The menu path must be derived from the live menu, or asserted against it --
# never hardcoded prose. Real labels carry ellipses: `Save All\u2026`. A hardcoded
# 'Outputs > Save All' that drops the ellipsis or misses a cascade level is a
# wrong direction printed with authority, which is worse than printing none."
#
# The SHIPPED gate-off nudge was exactly that failure -- it said
# "Tick Outputs > Save All > Save device OP parameters", dropping both the
# ellipsis and the parenthetical the checkbutton actually carries. So the menu
# entry (:502), the dialog checkbutton (:2879) and the printed remedy are now all
# built from these three procs: invariant I1 applied to a LABEL rather than to a
# vector name. W1r/W1u/W1t in tests/headless/test_ase_window.tcl read the labels
# back off the REAL widgets, so a constant-compared-to-constant tautology cannot
# pass.
#
# ⚠ "ONE SOURCE" IS NOT YET TRUE OF THE WHOLE FILE, and the heading overclaimed
# until this line was added. `ase::ui::save_all_report_discard` (below)
# STILL hardcodes both labels and both spellings have already DRIFTED -- measured
# in one process: the nudge prints `Outputs > Save All… > Save device OP
# parameters (gm, gds, vth, ...)` while the discard prints `Outputs > Save All`
# and `'Save device OP parameters'`, i.e. `string match` against BOTH constants
# returns 0. The discard is one of the four messages issue 0650's acceptance A3
# names by name. Filed as issue 0661; the older `*Outputs*Save All*` matcher rows
# do NOT catch it (SAB-N7 proved that), so the fix needs a W1t-shaped row.
proc ase::ui::lbl_outputs {}        { return {Outputs} }
proc ase::ui::lbl_save_all {}       { return "Save All\u2026" }
proc ase::ui::lbl_save_op_params {} { return {Save device OP parameters (gm, gds, vth, ...)} }

# The remedy path a notice prints, composed from those three. `>`-separated
# because that is what the shipped sentence used and what the user reads as a
# menu path; nothing else in the path may contain a `>`.
proc ase::ui::remedy_op_params_menu {} {
  return "[ase::ui::lbl_outputs] > [ase::ui::lbl_save_all] > [ase::ui::lbl_save_op_params]"
}

# --- 1391: THE ACTION-STRIP LABELS, SAME SECTION, SAME REASON ----------------
# The right vertical strip (`ase::ui::build`, ~:749) is EIGHT glyph buttons --
# `OP,TR = --> X N&> > ! ~` -- and until this issue not one of them carried a
# tooltip.
#
# ⚠ NOT the first tip in this file, and the plan for this issue said it was.
# MEASURED: `ase::ui::rsel_tip` (~:3724) has driven `balloon_show` from a
# <Motion> handler since R404, for the per-row full path in Results > Select.
# That one is per-ROW so it cannot use `balloon`, which bakes ONE string in at
# attach time; these eight are per-BUTTON and fixed, which is exactly the shape
# `balloon` is for. Two shapes, two call sites, no second mechanism.
#
# FIVE of the eight have a menubar twin -- counted off the shipped table,
# not off the brief, which listed three: `OP,TR` is `Analyses > Choose…`. A tip
# written by hand would have
# been a SECOND description of an action the menu already names, and the drift
# the block above records
# (`Outputs > Save All` vs `Outputs > Save All… > Save device OP parameters
# (gm, gds, vth, ...)`, string match 0, issue 0661) would have been rebuilt one
# widget over.
#
# So the twinned five are minted HERE, the menubar is BUILT from these procs,
# and the tip is the composed menu path -- the tip and the entry are the same
# string and cannot drift because they are the same string.
#
# ⚠ ISSUE 1389 (the run guard) READS `menu_path_stop`. Its refusal has to name
# the way out of a refused second launch, and the way out is the Stop entry the
# user can actually see. Renaming that entry moves the refusal with it; that is
# the whole point of the mint and the reason item B landed before item A.
#
# ⚠ THE ROWS THAT KEEP THESE HONEST are W1s1/W1s2 in
# tests/headless/test_ase_window.tcl: each tip is read back off the LIVE widget
# (`bind $b <Enter>`) and compared to the constant AND to a literal golden, the
# W1t discipline -- a constant-compared-to-constant tautology cannot pass.
proc ase::ui::lbl_analyses         {} { return {Analyses} }
proc ase::ui::lbl_choose           {} { return "Choose\u2026" }
proc ase::ui::lbl_simulation       {} { return {Simulation} }
proc ase::ui::lbl_netlist          {} { return {Netlist} }
proc ase::ui::lbl_netlist_recreate {} { return {Recreate} }
proc ase::ui::lbl_netlist_and_run  {} { return {Netlist and Run} }
proc ase::ui::lbl_run              {} { return {Run} }
proc ase::ui::lbl_stop             {} { return {Stop} }
proc ase::ui::lbl_tools            {} { return {Tools} }
proc ase::ui::lbl_waveform_viewer  {} { return {Waveform Viewer} }

# The THREE strip buttons with no menubar twin (`=`, `-->`, `X`), plus the
# temperature entry, which is not a strip button at all -- four constants, three
# of them tips on the strip. `=` and `-->` open a dialog, so
# the constant is the dialog's own `wm title` and the tip names the window the
# click produces (built at :1684 / :1800). `X` opens nothing and `OP,TR`'s
# dialog is titled `Choose Analyses` while its menu entry reads `Choose…` --
# that second spelling is SHIPPED and pre-dates this issue; it is recorded in
# doc/claude/issues/1391-*.md and deliberately NOT renamed here, because a
# ratified dialog title is not this issue's to change.
proc ase::ui::lbl_add_variable     {} { return {Add Variable} }
proc ase::ui::lbl_add_output       {} { return {Add Output} }
proc ase::ui::lbl_delete_selection {} { return {Delete Selection} }
proc ase::ui::lbl_sim_temperature  {} { return {Simulation temperature} }

# --- THE TWO OVERWRITE SENTENCES (batch ase_l_ux, decision S-7) --------------
# `Session > Save State` is ALWAYS a Save-As (:6357), so OK can land on a file
# that is already somebody's state. There are TWO reasons to stop and ask, and
# until 2026-09-09 only the first of them existed at all:
#   * the target is MY OWN file and it is read-only -> save_as_needs_confirm
#   * the target is SOMEBODY ELSE'S existing state  -> save_as_overwrites_other
# (:6422 and :6471; the chain that asks them is save_state_ok, :6481).
#
# Both sentences live HERE, in the lbl_* family, for the reason the block at
# :5466 gives at length: `ase::ui::save_all_report_discard` kept its two labels
# as inline literals and both spellings DRIFTED from the menu's own -- issue
# 0661, where `string match` against BOTH constants returns 0. A sentence typed
# inline in `save_state_ok` is that same defect pre-staged, and this arm now has
# two of them a dozen lines apart.
#
# ⚠ THE READ-ONLY SENTENCE IS MOVED, NOT REWRITTEN. It is the shipped string
# byte for byte, embedded `\n` included, so this mint changes zero pixels on the
# arm it did not come to change. Only `lbl_overwrite_state` is new copy, and it
# is the USER'S ruling (their words: "Just confirm if overwriting an existing
# state"), recorded on the ledger as a rule debt, not a crew's wording.
proc ase::ui::lbl_overwrite_state {lib cell view} {
  return "State $lib/$cell/$view exists. Overwrite?"
}
proc ase::ui::lbl_overwrite_readonly {lib cell view} {
  return "The state $lib/$cell/$view was opened read-only.\nOverwrite it?"
}

# `>`-separated menu paths, the shipped convention for a printed menu path in
# this file (ase::ui::remedy_op_params_menu, above) and in xschem.tcl
# (annot_remedy_menu, :17745). Nothing in these labels contains a `>`.
proc ase::ui::menu_path_choose_analyses {} {
  return "[ase::ui::lbl_analyses] > [ase::ui::lbl_choose]"
}
proc ase::ui::menu_path_netlist_and_run {} {
  return "[ase::ui::lbl_simulation] > [ase::ui::lbl_netlist_and_run]"
}
# Issue 1435: the door the precondition banner sends the user to for a netlist.
# THREE segments, because this one is a cascade -- the only path in this family
# that is.
proc ase::ui::menu_path_netlist_recreate {} {
  return "[ase::ui::lbl_simulation] > [ase::ui::lbl_netlist] > [ase::ui::lbl_netlist_recreate]"
}
proc ase::ui::menu_path_run {} {
  return "[ase::ui::lbl_simulation] > [ase::ui::lbl_run]"
}
proc ase::ui::menu_path_stop {} {
  return "[ase::ui::lbl_simulation] > [ase::ui::lbl_stop]"
}
proc ase::ui::menu_path_waveform_viewer {} {
  return "[ase::ui::lbl_tools] > [ase::ui::lbl_waveform_viewer]"
}

# THE STRIP'S TIPS, ONE TABLE, KEYED BY THE BUTTON'S OWN WIDGET SUFFIX. The
# builder walks this and so does the suite, which is what makes "a button with
# no tip is a red row, not a gap" enforceable: a ninth button added without an
# entry here reds W1s2 instead of quietly shipping bare.
#
# ⚠ MIXED FORM ON PURPOSE. FIVE tips are a menu path and THREE are a bare
# action name -- the split the table below actually ships, verified by walking
# it. That difference is information: it tells the reader whether the action has
# a MENUBAR route at all. Inventing a path for the three that have none would be
# prose, which is what the block above exists to forbid.
#
# ⚠ AND IT IS ONLY ABOUT THE MENUBAR. All three of the bare-named actions DO sit
# on a per-pane CONTEXT menu (`Add…` at :854/:866, `Delete` at :872), spelled
# differently there -- `Add Variable` vs `Add…`, `Delete Selection` vs `Delete`.
# Those are not built from these constants and the reader hovering a glyph
# cannot tell menubar from context. Recorded in doc/claude/issues/1391-*.md as
# the coverage this mint does not yet reach; sweeping the context menus into it
# is the follow-up, not a silent widening of this item.
proc ase::ui::strip_tips {} {
  return [list \
    ana    [ase::ui::menu_path_choose_analyses] \
    var    [ase::ui::lbl_add_variable] \
    out    [ase::ui::lbl_add_output] \
    del    [ase::ui::lbl_delete_selection] \
    netrun [ase::ui::menu_path_netlist_and_run] \
    run    [ase::ui::menu_path_run] \
    stop   [ase::ui::menu_path_stop] \
    plot   [ase::ui::menu_path_waveform_viewer]]
}

# --- 0650 / R-0653-d req 3: ONE WRITER FOR THE THREE BLANKETS ----------------
# "The command must invoke THE SAME PROC THE MENU INVOKES, not poke the state
# underneath it." The menu's own entry is `Save All\u2026` -> save_all_dialog, which
# is a DIALOG and commits nothing; the proc that actually commits the tick was
# save_all_ok, which reads dlg() and therefore cannot be run headlessly or pasted
# into the CIW. So the commit is extracted HERE, and both paths call it:
#   * save_all_ok  -- reads the checkbutton records, then calls this;
#   * save_op_params_on -- the pasteable remedy: reads the CURRENT blankets, then
#     calls this with opparams forced on.
# SAB-N6 is the discriminator that keeps them honest: neutralizing this one proc
# must redden the existing Save All OK rows TOO, not only the remedy row.
#
# ⚠ THE EMPTY VALUE IS `ON`, NOT `OFF` (issue 0927, 2026-08-29 — the user's
# call). `save_op_params` is in ase::omit_if_empty, and an empty value is what
# keeps the key OUT of ase::state_serialize -- which is what keeps the 104
# committed .state files byte-identical (F3/G3/R4/V4/R2). Before the flip that
# empty value meant off; now it means "the default", and the default is on. So
# OFF is the value that costs a key. Nothing here invents the mapping: it is
# `ase::op_gate_value`, the one writer paired with `ase::op_gate_on`, the one
# reader (invariant I1).
proc ase::ui::save_all_apply {key allv alli opparams} {
  set st [ase::session_state $key]
  dict set st save_all_v [expr {$allv ? 1 : 0}]
  dict set st save_all_i [expr {$alli ? 1 : 0}]
  dict set st save_op_params [ase::op_gate_value $opparams]
  ## ⚠ 0679: THE RETURN IS MEASURED, NOT MANUFACTURED. This line used to be a
  ## bare `ase::session_update $key $st` with the answer discarded and the proc
  ## ending in a hardcoded `return 1`.
  set rc [ase::ui::save_all_commit $key $st]
  ase::ui::populate $key    ;# the Save Options auto-cells react (item 06); no-op with no window
  return $rc
}

# THE ONE WRITE, AND IT IS ALLOWED TO FAIL (issue 0679).
#
# `ase::session_update` is honest -- its docstring says "Returns 1, or 0 for an
# unknown key" (ase.tcl:2714-2715) and it does exactly that. save_all_apply
# used to throw that answer away and return a hardcoded `1`. That fabricated 1
# is what the user read in the CIW after pasting the printed remedy, and it is
# why they trusted a command that had changed nothing:
#   update_rc 0   <- ase::session_update: "unknown key"
#   apply_rc  1   <- ase::ui::save_all_apply: "success"
#   gate_real 0   <- the gate never moved
# A witness that cannot fail is not a witness (issue 0652's class, third
# occurrence after 0664 and 0677).
#
# Its OWN named proc, not an inline `return [ase::session_update ...]`: the
# honesty has to be independently neutralizable, and an inline return offers no
# callee to stub short of session_update itself, which reddens the whole
# session model and discriminates nothing (SAB-0679-B / -B2).
#
# ON FAILURE, ONE SENTENCE (issue 0635's rule), tagged `error`, naming the key
# it could not find. `ciw_exec` echoes a command's value as a bare result
# (ciw.tcl:602-605), so an honest `0` alone is barely better than the lie for
# the user at the keyboard. The remedy still RETURNS 0 rather than RAISING --
# raising would red-tag it through `ciw_echo $res error` but turns a
# value-returning proc into a throwing one and needs `catch` at every caller;
# that choice is user-visible and unratified, so it is recorded as a `rule`
# debt on 0679 rather than taken silently. The echo is caught because issue
# 0666 records the echo family raising into its caller.
proc ase::ui::save_all_commit {key st} {
  set rc [ase::session_update $key $st]
  if {!$rc} {
    catch {::ase::echo "ase: no ASE-L session is open under '$key'; the Save\
 All settings were NOT applied." error}
  }
  return $rc
}

# The printed remedy itself. Takes ONLY the session key, because that is all a
# notice can name -- and it goes through the shared writer above, so the other
# two blankets keep the values the user left them at (F19r).
proc ase::ui::save_op_params_on {key} {
  set cur [ase::ui::save_all_current $key]
  return [ase::ui::save_all_apply $key [dict get $cur allv] [dict get $cur alli] 1]
}

proc ase::ui::save_all_dialog {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return }
  set w [ase::ui::dialog_frame [dict get $wins $key].saveall {Save All}]
  ## 0648: initialised from the SAME normaliser save_all_cancel diffs against.
  ## Two independent readings of the three blankets would report a phantom
  ## discard for a box the user never touched (invariant I1).
  set cur [ase::ui::save_all_current $key]
  set dlg($key,allv)     [dict get $cur allv]
  set dlg($key,alli)     [dict get $cur alli]
  set dlg($key,opparams) [dict get $cur opparams]
  ## 0695: THE TOUCH SET, CLEARED EXPLICITLY AT OPEN — not merely at close.
  ## `ase::ui::dialog_frame` (:1391) DESTROYS an existing toplevel of this name
  ## with NO cancel, so re-opening Save All from the menu while one is already
  ## up runs no teardown at all. A touch record that survived that would make
  ## the fresh dialog believe a box was hand-ticked, and a box the dialog
  ## believes was hand-ticked is exactly the box that must NOT follow an
  ## external write. Guarded by GE10j (this clear) and W1zb/GE10i (the close).
  ## It REPLACES 0692's as-opened `seed` record — see save_all_mark_touched.
  set dlg($key,touched) {}
  ## 0695: EACH BOX REPORTS ITS OWN HAND TICK. Before this the three
  ## checkbuttons carried `command={}` — there was no touch EVENT at all, which
  ## is why "the user changed this box" had to be a value diff, and a value diff
  ## cannot survive a box that follows the live value (save_all_mark_touched
  ## carries the measurement). Pinned structurally by GE10k, which is the only
  ## row that fails loudly if a later edit re-adds a box without its -command.
  checkbutton $w.allv -text {Save all voltages} \
    -variable ::ase::ui::dlg($key,allv) \
    -command [list ase::ui::save_all_mark_touched $key allv]
  checkbutton $w.alli -text {Save all terminal currents} \
    -variable ::ase::ui::dlg($key,alli) \
    -command [list ase::ui::save_all_mark_touched $key alli]
  checkbutton $w.opparams -text [ase::ui::lbl_save_op_params] \
    -variable ::ase::ui::dlg($key,opparams) \
    -command [list ase::ui::save_all_mark_touched $key opparams]
  grid $w.allv -row 0 -column 0 -columnspan 2 -sticky w -padx 8 -pady 2
  grid $w.alli -row 1 -column 0 -columnspan 2 -sticky w -padx 8 -pady 2
  grid $w.opparams -row 2 -column 0 -columnspan 2 -sticky w -padx 8 -pady 2
  set le [ase::ui::dialog_row $w 3 Levels: levels]
  ase::ui::dialog_buttons $w 4 [list ase::ui::save_all_ok $key] \
    [list ase::ui::save_all_cancel $key]
  bind $w <Return> [list ase::ui::save_all_ok $key]
  ## ⚠ 0648: WITHOUT THIS, A WINDOW-MANAGER CLOSE NEVER RUNS save_all_cancel.
  ## Measured at HEAD under a real WM: `wm protocol $w WM_DELETE_WINDOW` is ''
  ## for every ASE dialog (the only WM_DELETE_WINDOW in this file is :277, the
  ## session toplevel), so Tk's built-in default destroys the toplevel, the
  ## cancel path never runs and the ticked box vanishes with its dlg record
  ## still set. Issue 0648's own text says the WM close "reaches
  ## save_all_cancel"; it does not. Registered HERE and NOT in the shared
  ## ase::ui::dialog_frame — that would change WM-close semantics for ~8
  ## dialogs at once, none of them covered by a test (filed as issue 0651).
  ase::ui::dialog_close_protocol $w [list ase::ui::save_all_cancel $key]
  ase::ui::apply_theme $w
  $le configure -state disabled       ;# after theming: inert v1 field
  return $w
}

# ⚠ 0679 AUDITED THIS CALLER, which the issue named specifically: it discarded
# save_all_apply's return too, so making the writer honest without touching OK
# would have left the MENU'S OWN path closing the dialog silently on a failed
# apply -- R-0653-d req 3 guaranteeing only that both paths lie identically.
# It now RETURNS the apply's answer, and its two early guards return a real 0
# instead of falling off the end. THE DIALOG STILL CLOSES ON FAILURE: a user
# cannot repair a session that is gone from inside that dialog, so holding it
# open would only strand them; the non-silence lives in the shared writer's one
# error line, which this path inherits precisely because it shares the writer.
proc ase::ui::save_all_ok {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return 0 }
  if {![winfo exists [dict get $wins $key].saveall]} { return 0 }
  ## 0650 / R-0653-d req 3: the three blankets are written by ONE proc, which the
  ## printed remedy (ase::ui::save_op_params_on) also calls. This path's only job
  ## is to turn the checkbutton records into that call.
  ## ⚠ 0692: RECONCILED, NOT COPIED. These three arguments used to be the raw
  ## dlg records, which made an OPEN dialog a snapshot that overwrote anything
  ## that had moved behind it — the pasted remedy included. save_all_resolve
  ## takes the user's value for a box they TOUCHED and the LIVE value for one
  ## they did not. save_all_ok's `1` was honest before and still is; what it
  ## writes is no longer stale.
  ## ⚠ 0695, THE ORDER ON THIS PATH, AND WHY IT IS SAFE:
  ##   resolve -> apply -> save_all_commit -> session_update -> session_notify
  ##   -> ase::ui::save_all_refresh -> (back here) save_all_close
  ## So a refresh DOES fire against this dialog one statement before it is
  ## destroyed. It is idempotent BY CONSTRUCTION, not by luck: it recomputes the
  ## same `save_all_resolve`, whose touched fields answer the boxes' own values
  ## and whose untouched fields answer the live state apply has just written —
  ## the same dict, painted back onto the same boxes. Reordering resolve AFTER
  ## apply would break exactly that, and would also make OK depend on the follow
  ## having fired; keep them in this order.
  set vals [ase::ui::save_all_resolve $key]
  set rc [ase::ui::save_all_apply $key \
    [dict get $vals allv] [dict get $vals alli] [dict get $vals opparams]]
  ## 0648: the CLOSE half, never save_all_cancel. The OK path must not be able
  ## to emit a discard notice by accident, and "the diff happens to be empty by
  ## now" is not a thing to depend on.
  ase::ui::save_all_close $key
  return $rc
}

# --- 0648: the three blankets AS THE STATE HOLDS THEM, normalised to 0/1 -----
# ONE normaliser, FOUR consumers (invariant I1) — still one builder, which is
# the half of I1 that matters. ⚠ CORRECTED 2026-08-25 (0692): this said "TWO
# consumers ... save_all_cancel diffs the pending records against it", and after
# 0692 that second clause is FALSE — save_all_cancel does not diff this at all
# any more. ⚠ CORRECTED AGAIN 2026-08-25 (0695/0696), because the 0692 wording
# ("diffs against the AS-OPENED seed, through save_all_touched") went stale in
# its turn: there is no seed. The live call sites are now THREE —
#   save_op_params_on (the pasted remedy)   save_all_dialog's three records
#   save_all_resolve's live read            save_all_discarded's live compare
# — four readers, still ONE reading. A stale docstring surviving the very commit
# that fixed one is exactly how the 0692 window opened; that has now happened to
# this same comment twice, which is itself the argument for one normaliser.
proc ase::ui::save_all_current {key} {
  set st [ase::session_state $key]
  return [list \
    allv     [expr {[ase::state_get $st save_all_v 0] eq {1} ? 1 : 0}] \
    alli     [expr {[ase::state_get $st save_all_i 0] eq {1} ? 1 : 0}] \
    opparams [ase::op_gate_on [ase::state_get $st save_op_params {}]]]
}

# --- 0692/0695: WHAT "THE USER TOUCHED THIS BOX" MEANS ----------------------
# `dlg($key,allv|alli|opparams)` are the three checkbuttons' linked variables.
# Until 0695 they were written in exactly ONE place — the three lines in
# save_all_dialog — at dialog CREATION time, and `ase::ui::populate` never
# touched them. So an OPEN Save All dialog was a frozen snapshot of the three
# blankets and nothing in the product could refresh it. After 0679 the pasted
# CIW remedy became a writer aimed straight at one of those blankets, and
# `Session > Load State` was always another, so the 0679 fix is what opened the
# window. 0692 made OK and ESC correct about the STATE, by diffing the records
# against an as-opened SEED. 0695 is the residual that left, measured through
# two SHIPPED menu items on :99 with openbox 3.6.1 live:
#   WU-B2 box_at_open=1 load_rc=1 live_after_load=0 box_still=1 ok_rc=1
#         gate_after_ok=0   <- the user SEES a ticked box and OK writes it OFF
# Read that carefully: before 0692 the dialog was WYSIWYG-but-stale; after it
# the WIDGET AND THE ACTION DISAGREE, which is the worse failure of the two.
# The repair is `save_all_refresh` below — the box follows the live value, so
# what the user sees is what OK will write.
#
# ⚠ AND THE MOMENT THE BOX CAN MOVE UNDERNEATH THE USER, A VALUE DIFF CANNOT
# MEAN "THE USER CHANGED THIS BOX" ANY MORE. That is measured on this binary,
# in BOTH directions, with src/ untouched and the follow simulated by writing
# the linked variable (which is provably what a follow does):
#   H2  the box follows to 0, the user hand-ticks it back to 1 -> dlg(1) eq
#       seed(1) -> touched={} -> resolve answers 0 -> gate_after_ok=0:
#       THE USER'S OWN TICK IS SILENTLY DISCARDED (0695 inverted, and worse)
#   H1  an untouched box follows an external write -> touched={opparams} ->
#       ESC prints a discard for a box nobody touched: 0692 REINSTATED
# So the touch is an EVENT ON THE WIDGET, recorded by the three checkbuttons'
# own `-command`, and never a diff. Measured Tk seam (TK1/TK2/TK3, in the
# array-element `-variable` shape ASE actually uses): writing the linked
# variable moves the DISPLAY and does NOT fire `-command`, while `invoke` DOES.
# A programmatic follow is therefore invisible here, and every existing suite
# hand tick — all of which use `invoke` — still registers as a hand tick.
#
# ⚠ THE AS-OPENED SEED IS DELETED. `ase::ui::save_all_seed` / `dlg($key,seed)`
# had exactly two readers and both are replaced above. Its own docstring said
# the no-seed fallback existed for "a dlg record poked in directly with no
# dialog, which several suites do" — measured FALSE: no product path and no
# suite writes those three records without a dialog (the only direct pokes are
# `dlg($key,anen|antype)`, for Choose Analyses). A fallback documented as live
# and measured as dead is the family of defect this branch keeps meeting, so it
# goes rather than staying as a speculative branch. COST ACCEPTED: SAB-0692-B
# ("stub save_all_seed to a no-op" as an exact revert-0692 discriminator) no
# longer exists; SAB-0695-A/B/E replace it, and W1zb's 5th term pins the
# deletion itself so this cannot quietly grow back.
#
# ⚠ A TOUCHED FIELD STAYS TOUCHED, even when the live value later drifts to
# equal what the user set. The box the user put their hand on must never move
# again under that hand. "Re-cleaning" a field once live catches up reads well
# for the ESC notice and re-opens H2 for OK, because the field would go back to
# following. The ESC half is solved at the CONSUMER instead, by
# `save_all_discarded`, which changes nothing about what OK writes.
proc ase::ui::save_all_mark_touched {key field} {
  variable dlg
  ## ONLY while a dialog is up: a stray `invoke` arriving after teardown must
  ## not resurrect the record `save_all_close` has just dropped.
  if {![info exists dlg($key,touched)]} { return {} }
  if {[lsearch -exact $dlg($key,touched) $field] < 0} {
    lappend dlg($key,touched) $field
  }
  ## ⚠ RETURNS THE EMPTY STRING, AND THAT IS A CONTRACT. A checkbutton's
  ## `invoke` returns its -command's result, and every hand-tick gesture in the
  ## suites is written as a bare `$w.opparams invoke`. GE10k pins it.
  ## It also writes NOTHING to the session state — GE10h's byte-identical
  ## contract (tick + WM close leaves the state untouched) depends on that.
  return {}
}

# THE ONE DEFINITION OF "THE USER CHANGED THIS BOX", with TWO consumers
# (invariant I1): `save_all_resolve`'s OK reconcile, and `save_all_discarded`'s
# cancel notice. Two independent readings are exactly how the ESC arm drifted
# into reporting a phantom discard for a box nobody touched.
#
# The recorded list, FILTERED to fields that still have a dlg record, so a
# half-torn-down dialog cannot name a box that no longer exists. Its evidence
# changed with 0695 — from "differs from the as-opened seed" to "the widget's
# own -command fired" — but its name, signature and role did not.
proc ase::ui::save_all_touched {key} {
  variable dlg
  if {![info exists dlg($key,touched)]} { return {} }
  set out {}
  foreach f {allv alli opparams} {
    if {![info exists dlg($key,$f)]} { continue }
    if {[lsearch -exact $dlg($key,touched) $f] >= 0} { lappend out $f }
  }
  return $out
}

# What OK should write: the user's value for every box they TOUCHED, the LIVE
# value for every box they did not. A fix that simply re-read the live state
# would lose a hand tick; the shipped snapshot lost the external write; this
# loses neither, per field.
#
# ⚠ THE VALUES HERE ARE 0/1 BOOLEANS, NOT STATE VALUES. They round-trip through
# `save_all_current` / `ase::op_gate_on` and land in `save_all_apply`, which is
# the only place that turns a boolean back into what the state stores — via
# `ase::op_gate_value`, where ON is `{}` and OFF is `0` (issue 0927). Nothing in
# this proc may spell either literal.
#
# ⚠ ON A CONFLICT THE USER'S HAND WINS, SILENTLY (hand-untick vs external tick).
# That is user-visible and unratified: recorded as `rule` debt [0692].
proc ase::ui::save_all_resolve {key} {
  variable dlg
  if {[catch {ase::ui::save_all_current $key} live]} {
    set live [list allv 0 alli 0 opparams 0]
  }
  set touched [ase::ui::save_all_touched $key]
  set out {}
  foreach f {allv alli opparams} {
    if {[lsearch -exact $touched $f] >= 0} {
      lappend out $f [expr {$dlg($key,$f) ? 1 : 0}]
    } elseif {[dict exists $live $f]} {
      lappend out $f [dict get $live $f]
    } else {
      lappend out $f 0
    }
  }
  return $out
}

# --- 0695: THE BOX FOLLOWS, BY PAINTING THE SAME DICT OK WILL WRITE ----------
# INVARIANT I1 IN ITS EXACT SHAPE: ONE builder (`save_all_resolve`), TWO
# consumers — the widget and the OK write (`save_all_ok`) — so what the user is
# looking at and what OK will write CANNOT drift silently. That is the whole
# point: 0695's failure was two answers to one question.
#
# ⚠ IT PAINTS `save_all_resolve`, NOT `save_all_current`. Painting the raw live
# state would give the widget a second, independent definition of what the
# dialog means (I1's silent-failure mode, and how the ESC arm drifted in the
# first place) and it would MOVE A BOX THE USER HAD TOUCHED. With resolve, a
# touched box is left alone for free — resolve answers that box's own value for
# it — and an untouched box lands on exactly the value OK is going to write.
#
# ⚠ THE REFRESH CANNOT MARK ANYTHING TOUCHED. It writes the linked variables,
# and a variable write provably does NOT fire a checkbutton's `-command`
# (measured TK1/TK3); only `invoke` does. That is the property that keeps H1
# (a followed box read as a hand tick -> 0692's phantom discard) impossible.
#
# TOTAL NO-OP unless a Save All dialog for THIS key is really up:
# `ase::ui::session_changed` is reached from EVERY `ase::session_update` of
# EVERY key — pane edits, the temperature FocusOut, toggle_flag — so the guards
# are the proc's main body, not paranoia.
proc ase::ui::save_all_refresh {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return }
  if {[catch {winfo exists [dict get $wins $key].saveall} ex] || !$ex} { return }
  foreach f {allv alli opparams} {
    if {![info exists dlg($key,$f)]} { return }
  }
  if {[catch {ase::ui::save_all_resolve $key} vals]} { return }
  foreach f {allv alli opparams} {
    if {[dict exists $vals $f]} { set dlg($key,$f) [dict get $vals $f] }
  }
  return
}

# --- 0696: WHAT THE CANCEL ARM IS ALLOWED TO CALL "DISCARDED" ----------------
# Measured at HEAD, i.e. AFTER 0692 narrowed the cancel diff to the as-opened
# seed — this notice is NEW as of that commit:
#   WU-B1 seedbox=0 remedy_rc=1 gate=1 pending={opparams} notices=1
#         gate_after_esc=1
#   "ASE: Save All was closed without OK — 'Save device OP parameters' was NOT
#    applied. Reopen Outputs > Save All and press OK."
# The gesture: the user hand-ticks the box AND an external write sets the same
# blanket to the SAME value; ESC. Nothing was lost — the gate IS on and STAYS
# on — and the dialog tells the user to redo work that is already done, and
# re-arms the OP-card nudge on the way out. A notice that reports the OPPOSITE
# of what happened is worse than no notice at all.
#
# 0648's diff/cancel model is NOT reworked (that model is the scope fence):
# `save_all_report_discard` and the nudge re-arm are untouched, only the
# PREDICATE feeding them changes. 0648's own sentence already said it — "a
# change THE USER MADE and LOST is stated" — and the missing half is that a
# change the user made and the WORLD AGREED WITH was not lost. So: TOUCHED
# **AND** still differing from the LIVE value.
#
# Its OWN named proc rather than an inline filter in save_all_cancel, so the
# narrowing is independently neutralizable — SAB-0696-D is exactly "return the
# raw touched list", and it must redden W1zd and nothing else. That is the
# 0679/0691 precedent for honesty living in a stub-able callee.
#
# The contrast arms this must NOT move, both measured: a plain hand tick with
# the live value still 0, dropped by ESC, is STILL reported exactly once
# (GE10c/GE10d/GE10f/GE10g, W1za's hand arm); an UNTOUCHED dialog with an
# external write behind it is STILL silent (0692's fix, W1za's ext arm).
proc ase::ui::save_all_discarded {key} {
  variable dlg
  if {[catch {ase::ui::save_all_current $key} live]} { return {} }
  set out {}
  foreach f [ase::ui::save_all_touched $key] {
    ## no live reading for this field -> cannot prove it survived; say so.
    if {![dict exists $live $f]} { lappend out $f; continue }
    if {$dlg($key,$f) ne [dict get $live $f]} { lappend out $f }
  }
  return $out
}

# One-line registrar for a dialog's window-manager close button. Called ONLY
# from save_all_dialog (see the comment there for why not from dialog_frame).
proc ase::ui::dialog_close_protocol {w cmd} {
  catch {wm protocol $w WM_DELETE_WINDOW $cmd}
}

# The pure teardown: drop the dialog's records and destroy it. Shared by the
# OK path and the cancel path; it says nothing and decides nothing.
proc ase::ui::save_all_close {key} {
  variable wins; variable dlg
  array unset dlg $key,allv
  array unset dlg $key,alli
  array unset dlg $key,opparams
  ## 0695: AND THE PER-KEY TOUCH SET (this replaced 0692's as-opened seed). A
  ## leaked touch record would outlive OK, ESC and the WM close with zero rows
  ## red and then make the NEXT dialog for this key believe a box was
  ## hand-ticked — and a box the dialog believes was hand-ticked is exactly the
  ## box that must NOT follow an external write, i.e. 0695 wearing the fix's
  ## clothes. Guarded by W1zb and GE10i, which are the only rows that will ever
  ## see it; save_all_dialog clears it at OPEN too, for the re-open path that
  ## runs no teardown at all (GE10j).
  array unset dlg $key,touched
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].saveall}
  }
}

# 0648: SAY SO WHEN A TICK IS THROWN AWAY. This dialog's entire content is
# three checkboxes, so a user who ticks one has expressed the whole intent and
# a visibly-toggled checkbutton reads as applied — the user's 2026-08-23 report
# is exactly that trap ("I went to Outputs > Save and checked the 'Save device
# OP parameters'. I re-ran the sim and still don't get OP info."). Plain tag,
# not `error`: a deliberate ESC is not an error. Precedent for both the wording
# and the tag: ase::ui::close's "closed $key with unsaved state edits
# (discarded)".
proc ase::ui::save_all_report_discard {key pending} {
  set names {}
  foreach {f label} {allv     {Save all voltages}
                     alli     {Save all terminal currents}
                     opparams {Save device OP parameters}} {
    if {[lsearch -exact $pending $f] >= 0} { lappend names '$label' }
  }
  if {$names eq {}} { return }
  set verb [expr {[llength $names] > 1 ? {were} : {was}}]
  ase::echo "ASE: Save All was closed without OK — [join $names {, }] $verb NOT applied. Reopen Outputs > Save All and press OK."
}

# The cancel path — ESC, the Cancel button, and (0648) the window-manager close
# button. It DIFFS the pending checkbutton records against the state before
# tearing them down: a change the user made and lost is stated, and a discarded
# OP-card tick gives the gate-off nudge its turn back so the user's NEXT
# card-less run is not silent too (that silence is the whole of issue 0648).
# Keeps its name and its one-argument signature: dialog_buttons wires ESC and
# the Cancel button to it centrally.
proc ase::ui::save_all_cancel {key} {
  variable dlg
  ## ⚠ 0692: DIFFED AGAINST THE AS-OPENED SEED, NOT AGAINST THE LIVE STATE.
  ## This block used to read `save_all_current` here and call any difference
  ## "pending". That was equivalent to "the user changed it" only while nothing
  ## could change the live state behind an open dialog — and after 0679 the
  ## pasted remedy does exactly that. Measured at HEAD: an untouched dialog
  ## dismissed with ESC printed "'Save device OP parameters' was NOT applied"
  ## about a gate that WAS applied (gate_after_esc=1) and re-armed the nudge,
  ## telling the user to redo work already done.
  ## This is not a rework of 0648's diff/cancel model (that model is the scope
  ## fence): it is the sentence 0648 already wrote — "a change THE USER MADE and
  ## lost is stated" — finally measured as written. GE10c/GE10d/GE10f/GE10g,
  ## which all drive a REAL hand tick, are untouched by it.
  ##
  ## ⚠ 0696: AND "TOUCHED" IS NOT ENOUGH EITHER. The seed diff above still
  ## reported a hand-ticked box as discarded when an external write had set the
  ## same blanket to the SAME value — a NEW false notice, measured
  ## `WU-B1 pending={opparams} notices=1 gate_after_esc=1`: told the user their
  ## setting was NOT applied about a gate that IS applied. `save_all_discarded`
  ## is the narrowing: touched AND still differing from the LIVE value.
  ##
  ## ⚠ THE NUDGE RE-ARM READS THE SAME NARROWED LIST. Keying the re-arm off the
  ## raw touched set would silence the sentence and still fire the nudge, which
  ## is 0696 half-fixed and arguably more confusing than not fixing it.
  set pending {}
  catch { set pending [ase::ui::save_all_discarded $key] }
  ## D6: only the OP-card box re-arms the nudge. A discarded allv/alli tick is
  ## reported but must not re-nudge — the nudge is about this gate and nothing
  ## else, and re-nudging for an unrelated blanket is 0636 noise for nothing.
  if {[lsearch -exact $pending opparams] >= 0} {
    catch {ase::op_cards_nudge_rearm [ase::session_state $key]}
  }
  if {$pending ne {}} {
    catch {ase::ui::save_all_report_discard $key $pending}
  }
  ase::ui::save_all_close $key
}

# --- (e) Session > Load State ------------------------------------------------

# simulation-state views of lib/cell: those whose datafile resolves to a
# .state (the design_sch_views sibling).
proc ase::ui::state_views {lib cell} {
  set out {}
  foreach v [xschem cell_views $lib $cell] {
    if {[string match {*.state} [xschem cellview_path "$lib/$cell" $v]]} {
      lappend out $v
    }
  }
  return $out
}

# Session > Load State: the Create Instance browser shape (3 listbox
# columns, -exportselection 0) with the View column filtered to
# simulation-state views. OK resolves the target; a dirty session gets the
# discard confirm first (D10).
proc ase::ui::load_state_dialog {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].loadst
  catch {destroy $w}
  toplevel $w
  wm title $w {Load State}
  ttk::panedwindow $w.pw -orient horizontal
  foreach {col title} {lib Library cell Cell view View} {
    set f [ttk::frame $w.pw.$col]
    ttk::label $f.h -text $title -anchor w -padding {4 2}
    listbox $f.lb -exportselection 0 -activestyle dotbox \
            -yscrollcommand [list $f.sb set] -width 16 -height 14 \
            -background [ase::theme table] -font AseEntryFont
    ttk::scrollbar $f.sb -orient vertical -command [list $f.lb yview]
    grid $f.h  -row 0 -column 0 -columnspan 2 -sticky we
    grid $f.lb -row 1 -column 0 -sticky nsew
    grid $f.sb -row 1 -column 1 -sticky ns
    grid rowconfigure $f 1 -weight 1
    grid columnconfigure $f 0 -weight 1
    $w.pw add $f -weight 1
  }
  label $w.status -anchor w \
    -text {pick a Library / Cell / simulation-state View}
  frame $w.b
  button $w.b.ok -text OK -command [list ase::ui::load_state_ok $key]
  button $w.b.cancel -text Cancel -command [list destroy $w]
  pack $w.b.ok -side left -padx 5
  pack $w.b.cancel -side right -padx 5
  pack $w.b -side bottom -fill x -padx 8 -pady 6
  pack $w.status -side bottom -fill x -padx 8
  pack $w.pw -side top -fill both -expand 1
  bind $w.pw.lib.lb  <<ListboxSelect>> [list ase::ui::loadst_on_lib $key]
  bind $w.pw.cell.lb <<ListboxSelect>> [list ase::ui::loadst_on_cell $key]
  # item 10: ESC = the Cancel button (the browser keeps no records)
  ase::ui::bind_dialog_esc $w [list destroy $w]
  foreach n [lsort [libmgr::lib_names]] { $w.pw.lib.lb insert end $n }
  ase::ui::apply_theme $w
  ase::ui::loadst_default_to_session $key
  return $w
}

# Open the browser on the session's OWN cell. The states worth loading are
# nearly always the other states of the cell being simulated, so Library and
# Cell arrive already chosen and the View column -- the filtered list of this
# cell's saved states -- is the only pick left. The session's l/c comes from
# `meta`, which ase::ui::open records for both the open-a-state-view route
# and the untitled Launch route (there it is the DESIGN's lib/cell), so the
# default is right in both.
#
# The View column is deliberately left UNSELECTED: choosing one is the point
# of the dialog, and a default pick would put "discard this session's edits
# for a state the user never chose" one OK press away. Focus goes to the View
# listbox so the pick needs no mouse trip -- but note the Tk quirk, MEASURED,
# not assumed: a listbox with no selection has active == 0, and <Down> moves
# active BEFORE selecting, so the first Down lands on the SECOND view. Home
# (or Up, or a click) reaches the first. Do not "fix" that by preselecting
# index 0 -- that is the default pick this comment just ruled out.
#
# Degrades one column at a time when the session's l/c is not in the
# browser's lists (a library dropped from the search path, say): an unknown
# library leaves the browser exactly as it was before this defaulting
# existed, and a known library with an unknown cell still leaves the Library
# chosen and its Cell column filled, which is strictly more useful than
# clearing it. Preselection is a convenience, never a precondition, and
# load_state_ok already refuses an incomplete l/c/v with a status message.
# Programmatic `selection set` does not fire <<ListboxSelect>>, hence the
# explicit loadst_on_lib / loadst_on_cell calls (they also set the status
# line and apply the state-view filter). Returns 1 when the cell defaulted.
proc ase::ui::loadst_default_to_session {key} {
  variable wins; variable meta
  if {![dict exists $wins $key] || ![dict exists $meta $key]} { return 0 }
  set w [dict get $wins $key].loadst
  if {![winfo exists $w]} { return 0 }
  lassign [dict get $meta $key] mlib mcell
  if {![ase::ui::lb_select_value $w.pw.lib.lb $mlib]} { return 0 }
  ase::ui::loadst_on_lib $key
  if {![ase::ui::lb_select_value $w.pw.cell.lb $mcell]} { return 0 }
  ase::ui::loadst_on_cell $key
  if {[$w.pw.view.lb size] > 0} { catch {focus $w.pw.view.lb} }
  return 1
}

proc ase::ui::loadst_on_lib {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].loadst
  if {![winfo exists $w]} { return }
  set lib [ase::ui::lb_sel $w.pw.lib.lb]
  $w.pw.cell.lb delete 0 end
  $w.pw.view.lb delete 0 end
  # the status line described the cell whose columns were just deleted. Stale
  # text here used to need two clicks to reach; now that the browser opens
  # already defaulted to a cell, the very first Library click exposes it.
  $w.status configure -text {pick a Library / Cell / simulation-state View}
  if {$lib eq {}} { return }
  foreach c [lsort [xschem lib_cells $lib]] { $w.pw.cell.lb insert end $c }
}

proc ase::ui::loadst_on_cell {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].loadst
  if {![winfo exists $w]} { return }
  set lib  [ase::ui::lb_sel $w.pw.lib.lb]
  set cell [ase::ui::lb_sel $w.pw.cell.lb]
  $w.pw.view.lb delete 0 end
  if {$lib eq {} || $cell eq {}} { return }
  set sv [ase::ui::state_views $lib $cell]
  foreach v $sv { $w.pw.view.lb insert end $v }
  if {[llength $sv] == 0} {
    $w.status configure -text "no simulation-state view for $lib/$cell"
  } else {
    $w.status configure -text "$lib/$cell — choose a state View"
  }
}

proc ase::ui::load_state_ok {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].loadst
  if {![winfo exists $w]} { return }
  set lib  [ase::ui::lb_sel $w.pw.lib.lb]
  set cell [ase::ui::lb_sel $w.pw.cell.lb]
  set view [ase::ui::lb_sel $w.pw.view.lb]
  if {$lib eq {} || $cell eq {} || $view eq {}} {
    # name what is actually missing: since the browser opens defaulted, the
    # usual incomplete pick is "Library and Cell are set, no View chosen",
    # and telling that user to pick a Library reads as a bug.
    if {$lib ne {} && $cell ne {}} {
      $w.status configure -text "$lib/$cell — choose a state View"
    } else {
      $w.status configure -text {pick a Library / Cell / simulation-state View}
    }
    return
  }
  set path [xschem cellview_path "$lib/$cell" $view]
  if {$path eq {}} {
    $w.status configure -text "no $view view for $lib/$cell"
    return
  }
  destroy $w
  if {[ase::session_dirty $key]} {
    ase::ui::confirm $key {Load State} \
      "Discard unsaved edits of this session\nand load $lib/$cell/$view?" \
      [list ase::ui::do_load_state_from $key $path]
  } else {
    ase::ui::do_load_state_from $key $path
  }
}

# D10 worker (headless-testable): Load State is a CONTENT IMPORT into THIS
# session — replace the in-memory state with the chosen file's dict
# (state_load merges over defaults); the session's path/key/meta stay
# untouched, so the dirty marker appears whenever the import differs from
# the session's own file. No session retargeting, no key juggling.
proc ase::ui::do_load_state_from {key path} {
  if {[catch {ase::state_load $path} st]} {
    catch {::ase::echo $st error}
    return 0
  }
  ## ⚠ 0691: THE RETURN IS MEASURED, NOT MANUFACTURED. This line used to be a
  ## bare `ase::session_update $key $st` with the answer discarded and the proc
  ## ending in a hardcoded `return 1` — honest about the FILE (the arm above)
  ## and never about the KEY, so "Load State into a session that is gone"
  ## reported success, changed nothing and said nothing. Measured at HEAD, at
  ## the same commit as the twin 0679 had just repaired one proc over:
  ##   session_update(BOGUS)      = 0    <- honest
  ##   do_load_state_from(BOGUS)  = 1    <- fabricated
  ##   save_all_apply(BOGUS)      = 0    <- 0679's repair holding
  ## THE TWO ERROR ARMS ARE MUTUALLY EXCLUSIVE BY CONSTRUCTION (both return
  ## early), which is how "exactly one error-tagged sentence" is satisfied
  ## structurally rather than by luck — row H4d exists to keep it that way.
  ## populate/viewer_restore are SKIPPED on the failed arm on purpose:
  ## repopulating panes from a session that is gone would blank a live window
  ## as a side effect of a REFUSED import.
  if {![ase::ui::load_state_commit $key $st]} { return 0 }
  ase::ui::populate $key
  # item 14 (D7): an imported state with `viewer open 1` relaunches/rebuilds
  # the viewer; open 0 / absent leaves an already-open viewer exactly as it
  # is (minimal contract arm — viewer_restore gates internally)
  ase::ui::viewer_restore $key
  return 1
}

# THE ONE IMPORT WRITE, AND IT IS ALLOWED TO FAIL (issue 0691), the exact twin
# of `ase::ui::save_all_commit` (:3240) that 0679 introduced — same shape, same
# reasoning, so the two read alike.
#
# Its OWN named proc, not an inline `return [ase::session_update ...]`: the
# honesty has to be independently neutralizable, and an inline return offers no
# callee to stub short of session_update itself, which reddens the whole session
# model and discriminates nothing (SAB-0691-A / -A2, after 0679's SAB-B / -B2).
#
# ON FAILURE, ONE SENTENCE (issue 0635's rule), tagged `error`, naming the key
# it could not find — its own sentence and not save_all_commit's, whose wording
# is Save-All-specific and would be wrong for an import. Both production callers
# (:3564 as `ase::ui::confirm`'s detached oncmd, and :3566) discard the return,
# so this line IS the user-facing half; that is the same reasoning 0679 applied
# to save_all_ok, and making `confirm` rc-carrying would be a contract change to
# every confirm caller. Returning 0 rather than RAISING, and whether a caller
# should hold its dialog open on a failed apply, is the open `rule` debt [0679]
# — restated, not answered, here. The echo is caught because issue 0666 records
# the echo family raising into its caller.
proc ase::ui::load_state_commit {key st} {
  set rc [ase::session_update $key $st]
  if {!$rc} {
    catch {::ase::echo "ase: no ASE-L session is open under '$key'; the state\
 was NOT imported." error}
  }
  return $rc
}

# --- (f) Session > Save State ------------------------------------------------

# Session > Save State: ALWAYS Save-As — Library type-to-filter combobox +
# editable Cell/View entries prefilled with the session's own l/c/v (so a
# bare OK is the plain save).
proc ase::ui::save_state_dialog {key} {
  variable wins; variable meta; variable dlg
  if {![dict exists $wins $key]} { return }
  set w [ase::ui::dialog_frame [dict get $wins $key].saveas {Save State}]
  lassign [dict get $meta $key] mlib mcell mview
  set dlg($key,salib) [lsort [libmgr::lib_names]]
  label $w.llib -text Library: -font AseLabelFont -anchor w
  ttk::combobox $w.lib -width 24 -font AseEntryFont -style Ase.TCombobox \
    -values $dlg($key,salib)
  grid $w.llib -row 0 -column 0 -sticky w -padx {8 6} -pady 2
  grid $w.lib  -row 0 -column 1 -sticky we -padx {0 8} -pady 2
  $w.lib set $mlib
  bind $w.lib <KeyRelease> [list ase::ui::saveas_filter $key]
  set ce [ase::ui::dialog_row $w 1 Cell: cell]
  set ve [ase::ui::dialog_row $w 2 View: view]
  $ce insert 0 $mcell
  $ve insert 0 [ase::session_getattr $key saveview $mview]
  ase::ui::dialog_buttons $w 3 [list ase::ui::save_state_ok $key] \
    [list ase::ui::saveas_cancel $key]
  foreach e [list $w.lib $ce $ve] {
    bind $e <Return> [list ase::ui::save_state_ok $key]
  }
  ase::ui::apply_theme $w
  focus $ve
  return $w
}

proc ase::ui::saveas_filter {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,salib)]} { return }
  ase::ui::combo_filter [dict get $wins $key].saveas.lib $dlg($key,salib)
}

proc ase::ui::saveas_cancel {key} {
  variable wins; variable dlg
  array unset dlg $key,salib
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].saveas}
  }
}

# D8: pure predicate — the Save-As target needs a confirmation iff it
# resolves to the session's OWN state file AND that file is effectively
# read-only: the session was opened read-only (attr `readonly`, threaded by
# ase::open_state's trailing arg) or the file itself is unwritable (the
# LibMgr git-checkout discipline leaves non-checked-out files 0444).
#
# ⚠ D13 IS RETIRED, AND THE USER RETIRED IT (2026-09-09). D13 read
# "overwriting a DIFFERENT existing view needs NO confirm in v1 — the spec's
# only confirm trigger is read-only + same-target", and it was an accurate
# description of the shipped window: measured that day with session
# `ngspice_state1` open and the sibling view `debug_st1` present and writable,
# THIS proc answered 0 for `debug_st1`, so typing an existing sibling view into
# the Save-As form destroyed it with no warning at all. The user's ruling:
# "Just confirm if overwriting an existing state." Undo was explicitly NOT
# asked for; a confirm was.
#
# THIS PROC IS UNCHANGED ANYWAY (batch decision S-1,
# doc/claude/ase_l_ux_batch/DECISIONS.md). D8's contract is still exactly "the
# target IS my own file AND that file is effectively read-only"; the new case
# is `ase::ui::save_as_overwrites_other`, immediately below. The four rows at
# tests/headless/test_ase_dialogs.tcl section H2 still pins this one
# — including the fourth, which still reads 0 for a different target and now
# names the PREDICATE rather than the window's outcome (S-9), because the
# window itself no longer makes the promise that row's old name made.
proc ase::ui::save_as_needs_confirm {key lib cell view} {
  set target [xschem cellview_path "$lib/$cell" $view]
  if {$target eq {}} { return 0 }
  set own [ase::session_path $key]
  if {$own eq {} || [file normalize $target] ne [file normalize $own]} {
    return 0
  }
  if {[ase::session_getattr $key readonly 0] eq {1}} { return 1 }
  if {![file writable [file normalize $target]]} { return 1 }
  return 0
}

# THE SECOND REASON A SAVE-AS STOPS TO ASK: 1 iff the resolved target EXISTS
# and is NOT the session's own state file, else 0. The user's overrule of D13
# (see the block above) lands here and NOT inside `save_as_needs_confirm`
# (batch decision S-2, doc/claude/ase_l_ux_batch/DECISIONS.md).
#
# WHY A SECOND PREDICATE RATHER THAN ONE WIDENED BOOLEAN:
#  * `save_as_needs_confirm` is a DOCUMENTED predicate with four pinned rows
#    (tests/headless/test_ase_dialogs.tcl, section H2) and a spec paragraph.
#    Widening it moves those rows and, worse, leaves ONE boolean carrying TWO
#    sentences — the caller would then have to re-derive WHICH of the two
#    reasons it just got in order to word the popup, i.e. compute the answer a
#    second time, from the same inputs, in a different place. That is how a
#    confirm ends up naming the wrong cause.
#  * the two are MUTUALLY EXCLUSIVE BY CONSTRUCTION, not by luck: that one's
#    only 1-arm requires `target == own`, this one requires `target != own`.
#    So `save_state_ok` can ask them in order, show ONE popup, and never
#    compose a sentence out of two reasons.
#
# `xschem cellview_path` is the SAME resolver `do_save_state_as` (:6749) uses to
# choose the file it will write, so "exists" here is exactly "the bytes OK is
# about to destroy" — a `file exists` on a path composed by hand would be a
# second, drifting answer to the same question, and would disagree with the
# writer on the legacy flat-layout fallback (library_defs.tcl:303).
# S-3: an UNTITLED session owns no file — `ase::session_path` returns {}, issue
# 0141's marker — so EVERY existing target is somebody else's. That is the case
# where a clobber is most likely and least expected, so it is the case that
# must ask. S-4: saving onto your own state stays silent; that is what Save
# means. S-5: a target that does not exist is not an overwrite —
# `do_save_state_as` creates the view (D9, row H3) and says nothing.
# S-6: exists-but-unwritable still fires here (it exists) and the write then
# fails through the existing error path; a third sentence for it is a separate
# change.
#
# PURE, and it has to be: it is called from an OK handler that has not yet
# decided to do anything. It resolves and compares, nothing else — it creates
# no directory (contrast `ase::rundir`, which mkdirs and moves a global), writes
# nothing, and raises nothing.
proc ase::ui::save_as_overwrites_other {key lib cell view} {
  set target [xschem cellview_path "$lib/$cell" $view]
  if {$target eq {}} { return 0 }
  set own [ase::session_path $key]
  if {$own ne {} && [file normalize $target] eq [file normalize $own]} {
    return 0
  }
  return 1
}

proc ase::ui::save_state_ok {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set w [dict get $wins $key].saveas
  if {![winfo exists $w]} { return }
  set l [string trim [$w.lib get]]
  set c [string trim [$w.cell get]]
  set v [string trim [$w.view get]]
  if {$l eq {} || $c eq {} || $v eq {}} {
    catch {::ase::echo "ase: Library, Cell and View are all required" error}
    return
  }
  # ONE confirm, EITHER reason, NEVER both. The two predicates are mutually
  # exclusive by construction (target == own vs target != own, see
  # save_as_overwrites_other above), so this is a CHAIN, not a composition:
  # each arm hands `ase::ui::confirm` a whole sentence that already names its
  # own cause. Read-only is asked first because it is the narrower arm and its
  # cause is the one the user CANNOT see from the form — the form shows the
  # l/c/v, it does not show the file's mode.
  # One title for both arms: `Overwrite State`, the title the read-only arm has
  # always used (S-7). It is the same question about the same file.
  set title {Overwrite State}
  set go [list ase::ui::do_save_state_as $key $l $c $v]
  set cw {}
  if {[ase::ui::save_as_needs_confirm $key $l $c $v]} {
    set cw [ase::ui::confirm $key $title [ase::ui::lbl_overwrite_readonly $l $c $v] $go]
  } elseif {[ase::ui::save_as_overwrites_other $key $l $c $v]} {
    set cw [ase::ui::confirm $key $title [ase::ui::lbl_overwrite_state $l $c $v] $go]
  } else {
    ase::ui::do_save_state_as $key $l $c $v
    return
  }
  ase::ui::confirm_safe_default $cw
  ase::ui::confirm_owned_by $w $cw
}

# A DESTRUCTIVE confirm must not be armed by the keystroke that RAISED it.
#
# ⚠ MEASURED 2026-09-09 by this item's adversary, on the shipped gesture.
# `save_state_dialog` binds `<Return>` on all three of its fields (:6357), so
# "type the view name, press Return" is the sanctioned way to submit the form.
# `ase::ui::confirm` (:4039) then focuses OK and binds `<Return>` to
# `confirm_ok`. The two compose into: Return raises the popup, Return destroys
# the file — with the sentence on screen for the length of one keystroke. The
# gate the user asked for would have been real for the mouse and theatre for
# the keyboard.
#
# Fixed HERE and not in `ase::ui::confirm`, deliberately: that proc is shared
# (Load State discards unsaved edits through it too, :6288) and its
# "Return = proceed" contract is documented at :4036. Narrowing the change to
# the caller that can lose a file leaves every other confirm exactly as it was.
# Escape already destroyed; now Return does too, and OK is one click or one Tab.
proc ase::ui::confirm_safe_default {w} {
  if {$w eq {} || ![winfo exists $w]} { return }
  catch {focus $w.btns.cancel}
  catch {bind $w <Return> [list destroy $w]}
}

# Tie a confirm's life to the dialog that raised it.
#
# ⚠ ALSO MEASURED 2026-09-09. Escape on the Save-As form is the documented
# item-10 dismissal, and it left the overwrite confirm ALIVE and orphaned —
# a live destructive button pointed at a file, belonging to a form the user
# had just backed out of; its OK still wrote. Re-opening the form was the same
# defect wearing a second face: `dialog_frame` destroys the old form (:1666)
# and the screen was then a form naming one view above a confirm naming
# another, whose OK wrote the one the user could no longer see.
#
# `<Destroy>` fires for every descendant as well as for `$owner` itself, hence
# the `%W` guard. By the time an ACCEPTED confirm runs its command the popup is
# already gone (`confirm_ok` destroys first, then evals, :4064), so a successful
# save reaches this handler with nothing left to drop.
proc ase::ui::confirm_owned_by {owner w} {
  if {$owner eq {} || $w eq {} || ![winfo exists $owner]} { return }
  bind $owner <Destroy> [list ase::ui::confirm_drop $owner $w %W]
}
proc ase::ui::confirm_drop {owner w ev} {
  if {$ev ne $owner} { return }
  catch {destroy $w}
}

# --- viewer persistence (item 14) ---------------------------------------------
# Contract: doc/claude/specs/waveform_viewer.md "Item 14 notes (as shipped)".
# Snapshot-at-Save-only: viewer-layout edits never dirty the session until a
# Save State runs the snapshot; closing the session/viewer DISCARDS the
# in-memory layout like any unsaved edit (by ase::ui::close time the session
# is already unregistered when wviewer::close runs — a snapshot there would
# no-op anyway).

# Fold a fresh wviewer::snapshot of the session's viewer into the session
# state IFF it differs from the stored `viewer` value (so a plain save of a
# viewer-less session stays byte-identical and un-dirtied). Called FIRST by
# both Save State paths — do_save_state_as covers all three target arms
# (accepted side effect, documented in the spec notes: save-as to a DIFFERENT
# view leaves a TITLED session dirty-marked when the snapshot changed the
# in-memory state — honest, the session's own file now differs). CARVE-OUT
# (issue 0141): an UNTITLED session's first Save-As instead ADOPTS the target
# (do_save_state_as, own eq {}) and becomes CLEAN — do not "fix" it back to
# dirty. Returns 1 when a snapshot was folded in, else 0.
#
# ⚠ R602/R602a (results batch item 6) — THIS IS WHERE `viewer.rawfile` BECOMES
# RELATIVE, and the choice was ruled here rather than in `wviewer::snapshot` or
# in `results::persist`. `wviewer::snapshot` writes the SELECTED RESULT as an
# ABSOLUTE path; this proc turns it into a path relative to the state's rundir
# when it is under it, which is R602's stored form and is what makes a state
# file movable (test_ase_persist G11 already proved the relative form
# round-trips on the read side).
#
# Why here and not in `wviewer::snapshot`: a rundir is an ASE STATE concept and
# a viewer need not belong to an ASE session at all (`wviewer::echo` exists for
# exactly that reason), so making the viewer layer reach into `ase::` for its
# own inputs is the same mistake R201a rejected when it refused to let the
# resolver take an ASE state as its argument. Passing the rundir IN would change
# `wviewer::snapshot`'s arity for its one production caller and a dozen suite
# calls, and would only move the decision rather than remove it. Why not in
# `results::persist`: that proc is only reached through R303's door, and the
# acceptance flow T-F names — run, then Save State — never comes through it
# (`ase::attach_dbs` is section 18's deliberate bypass), so the relativisation
# would be absent exactly where the round trip has to hold.
#
# `ase::rundir` IS NOT ASKED AT ALL on this path (R602e, fix round): it is a
# create-and-default helper — it `file mkdir`s the state's rundir, and for an
# empty one falls into `set_netlist_dir 0`, which creates
# `$USER_CONF_DIR/simulations` AND rewrites the global `::netlist_dir`. A Save
# State must not make a directory or move a global as a side effect, so
# `ase::ui::viewer_rawfile_relative` reads the state's own `rundir` key and
# relativises against nothing else.
proc ase::ui::viewer_snapshot {key} {
  set st [ase::session_state $key]
  if {$st eq {}} { return 0 }
  set prev [ase::state_get $st viewer]
  set vd [wviewer::snapshot $key $prev]
  set vd [ase::ui::viewer_rawfile_relative $vd $st]
  if {$vd eq $prev} { return 0 }
  dict set st viewer $vd
  ase::session_update $key $st
  return 1
}

# R602's stored form, and nothing else: `viewer.rawfile` relative to the state's
# rundir when it is UNDER it, absolute otherwise. Component-wise, not a string
# prefix — `<rundir>bis/x.raw` is not under `<rundir>`, and a `string first`
# test would say it was. Never throws; an unrelativisable value is left exactly
# as it came in.
#
# ⚠⚠ TWO GUARDS, BOTH ADDED IN THE ITEM-6 FIX ROUND, BOTH WITH A REPRODUCER.
#
# R602d — AN ALREADY-RELATIVE VALUE IS A FIXED POINT, AND IS RETURNED
# UNTOUCHED. `file normalize` resolves a relative path against the PROCESS CWD,
# which is not the rundir and has nothing to do with it, so without this guard
# the proc re-relativised its own output: `ase::ui::viewer_snapshot` feeds it
# whatever `wviewer::snapshot` returned, INCLUDING the closed-viewer arm's
# `[dict replace $prev open 0]`, whose `rawfile` is already in this proc's own
# stored form. Measured with cwd = <rundir>/sub: `an.raw` -> `sub/an.raw` ->
# `sub/sub/an.raw` -> `sub/sub/sub/an.raw`, one component per Save State, until
# the state named a file that does not exist and the read side told the user
# their result had gone missing while it sat on disk. (It also made the dict
# differ from `prev` every time, so the session was marked dirty on every save.)
# Pinned by SEL353.
#
# R602e — THE RUNDIR IS *QUERIED*, NOT `ase::rundir`. `ase::rundir`
# (src/ase.tcl:1643) is a create-and-default helper, not a query: it `file
# mkdir`s the directory the state names, and for the far more common empty
# `rundir` it falls through to `set_netlist_dir 0` (src/xschem.tcl), which
# CREATES `$USER_CONF_DIR/simulations` and REWRITES the global `::netlist_dir`.
# A Save State may do neither. So the state's own `rundir` is read directly and
# an empty one means NO RELATIVISATION — the slot keeps the absolute path, which
# the read side has always resolved as-is. The cost is that a session which
# names no rundir stores a machine-specific path; the alternative (guessing the
# default from `::netlist_dir`) can disagree with what `viewer_restore` resolves
# against once `local_netlist_dir` re-points it per schematic, and a stored path
# that resolves to the wrong file is worse than one that is merely unportable.
# Pinned by SEL355 (no directory made, `::netlist_dir` unmoved, value unchanged).
proc ase::ui::viewer_rawfile_relative {vd st} {
  if {[catch {ase::state_get $vd rawfile} rf]} { return $vd }
  if {[string trim $rf] eq {}} { return $vd }
  # R602d: already in the stored form -> nothing to do. Never `file join
  # $rundir $rf` first either: that would silently re-absolutise a value whose
  # meaning was ALREADY rundir-relative, which is a different behaviour change.
  if {[catch {file pathtype $rf} pt]} { return $vd }
  if {$pt ne {absolute}} { return $vd }
  if {[catch {file normalize $rf} np]} { return $vd }
  # R602e: query only.
  if {[catch {ase::state_get $st rundir} rd]} { return $vd }
  if {[string trim $rd] eq {}} { return $vd }
  if {[catch {file normalize $rd} rd]} { return $vd }
  set rdl [file split $rd]
  set npl [file split $np]
  if {[llength $npl] <= [llength $rdl]} { return $vd }
  if {[lrange $npl 0 [expr {[llength $rdl] - 1}]] ne $rdl} { return $vd }
  set tail [lrange $npl [llength $rdl] end]
  if {[catch {eval [linsert $tail 0 file join]} rel]} { return $vd }
  if {[string trim $rel] eq {}} { return $vd }
  dict set vd rawfile $rel
  return $vd
}

# Relaunch/rebuild the session's viewer from the state's `viewer` dict. Acts
# ONLY when the dict carries `open 1` (open 0 / absent / `viewer {}` -> 0, no
# viewer action — an already-open viewer is left exactly as it is). Raw
# resolution (D4) is `results::resolve`'s, since the results batch's item 6: a
# non-{} `rawfile` in the dict is the SELECTED RESULT (item 6 is what finally
# WRITES it; until then it was only the hand-editable saved-results seam) —
# absolute used as-is, relative resolved against the state's rundir, attached
# IFF it exists AND is readable; else fall back to ase::last_rawfile (file
# existence == "has results"). Its status is reported once, through ase::echo,
# for `stale` and `invalid` only (R604/R604a). sim_type from ase::plot_sim_type (NO op-only gate: restoring an
# op raw is harmless, unlike plotting into it). No rawfile at all -> the
# viewer still opens with its layout, traces draw empty, ase::echo notice, no
# crash. Returns wviewer::restore's rc (0 headless: wviewer::open bails).
proc ase::ui::viewer_restore {key} {
  set st [ase::session_state $key]
  set vd [ase::state_get $st viewer]
  if {[ase::state_get $vd open 0] ne {1}} { return 0 }
  # --- R604 / R201: THE RESOLVER, NOT A SECOND COPY OF IT ------------------
  # doc/claude/specs/results_selection.md section 4. This block used to
  # implement the `ok` and `invalid` arms BY HAND — absolute-ise a relative
  # value against the rundir, gate on `file isfile`, fall back to
  # `ase::last_rawfile` — and that hand-written shape is precisely what
  # `results::resolve` was copied FROM (its own header says so). It is now
  # asked of the one resolver, so a restored selection runs exactly the
  # machinery a fresh one does (R604).
  #
  # OBSERVABLE BEHAVIOUR IS KEPT, with ONE ruled divergence: a named result
  # that EXISTS but cannot be READ used to be attached anyway (the old test was
  # `file isfile` alone) and now falls back to the derived path, because R201c
  # rules an unreadable file `invalid` rather than `stale` — a status the user
  # could still select would be offering a choice that cannot be honoured.
  #
  # `ase::rundir` is asked ONLY for a non-empty RELATIVE stored value, exactly
  # as before: it CREATES the directory the state names (src/ase.tcl:1643), and
  # opening a session must not make one on account of an absolute path.
  set vraw [ase::state_get $vd rawfile]
  set rd {}
  if {$vraw ne {} && [catch {file pathtype $vraw} pt] == 0 && $pt ne {absolute}} {
    set rd [ase::rundir $st]
  }
  set res [results::resolve [dict create rawfile $vraw rundir $rd key $key]]
  set rf [ase::state_get $res path]
  # R604 — THE STATUS IS REPORTED ONCE, ON RESTORE, THROUGH `ase::echo`, and it
  # EXTENDS the vocabulary of the no-results sentence below rather than adding a
  # channel.
  #
  # ⚠ CREW RULING R604a (item 6): `ok` and `default` say NOTHING; `stale` and
  # `invalid` speak. Reporting every status would put a line in the CIW on every
  # single session open — every state file written before item 6 carries
  # `rawfile {}`, which resolves `default`, and a successful restore reports
  # itself in the only way that matters, by drawing the waveforms. `stale` and
  # `invalid` are exactly the two where what the user GETS is not what the state
  # NAMED, which is the thing a sentence has to carry (R202's "the sentence says
  # why it looks old"; R201's "says which happened").
  #
  # Emitted BEFORE the restore, and unconditionally: it describes the
  # RESOLUTION, which happened before any attach, and `wviewer::restore` returns
  # 0 headlessly — gating it on the rc would make the one sentence T-E has to
  # assert unreachable in a headless suite.
  set said 0
  set rstat [ase::state_get $res status]
  if {$rstat eq {stale} || $rstat eq {invalid}} {
    set said 1
    catch {::ase::echo "ase: [ase::state_get $res msg]"}
  }
  set sim_t [ase::plot_sim_type $st]
  # spec §D1 (DEFECT 1, 2026-08-09): THE DIGITAL DATABASES GO IN TOO. This was
  # the ONE attach site of the three that did not pass them — `dp_finish`
  # (:2014) and `auto_plot` (:3570) both hand `ase::last_vcdfiles` to
  # `wviewer::attach_raw`, while `wviewer::restore` is the inline copy of that
  # attach shape and cleared the registry down to the analog raw alone. A saved
  # cross-DB trace then came back with its `%<rawfile> <sim_type>` intact and
  # nothing to switch to: legend listed, waveform blank, no message at any level
  # (`extra_rawfile()`'s switch failure is `dbg(1)`). `wviewer::restore` unions
  # this list with the databases the restored traces themselves name, and speaks
  # up for whatever it still cannot attach.
  set vcds {}
  foreach v [ase::last_vcdfiles $key] { lappend vcds [list $v vcd] }
  catch {wviewer::diag "viewer_restore  key=$key rawfile='$rf' sim_type=$sim_t"}
  set rc [wviewer::restore $key $vd $rf $sim_t $vcds]
  catch {wviewer::diag "viewer_restore  key=$key rc=$rc"}
  # ...and this one keeps the case it was written for, gated on `said` so R604's
  # "reported ONCE" holds: an `invalid` state with nothing to fall back to has
  # already been told which result went missing, and saying "no simulation
  # results for this state" after it would be the second sentence about one
  # event.
  if {$rc && $rf eq {} && !$said} {
    catch {::ase::echo "ase: no simulation results for this state — viewer\
 restored, traces will fill after a run"}
  }
  return $rc
}

# Save-As worker (headless-testable). Target arms:
#  - the session's OWN view -> ase::session_save (clears dirty);
#  - a MISSING view -> `library_new_view <l> <c> <v> ngspice_state1` (the
#    item-02 creation path; D9: the CELL must already exist — a nonexistent
#    cell errors cleanly, auto-creating cells would invent behavior), then
#    the seeded file is overwritten with THIS session's serialization;
#  - a DIFFERENT existing view -> plain state_save overwrite (D13's WRITE half,
#    which stands; D13's "and needs no confirm" half was overruled by the user
#    on 2026-09-09 and now goes through ase::ui::save_as_overwrites_other,
#    :6471 — on THAT arm this proc now runs only after the confirm is
#    accepted; the own-target and missing-view arms reach it directly, as
#    before, and so do the suites, which call this worker and not the OK).
# UNTITLED ADOPT (issue 0141): when this session was never saved (own eq {} —
# a Launch-ASE untitled session), the first successful Save-As ADOPTS the
# target as the session's real identity via ase::session_adopt (path set,
# saved<-state so dirty clears, `untitled` attr dropped) + meta view update, so
# the still-open window loses its "(unsaved)"/"*" cues and shows "State: <v>".
# This is gated on own eq {}, so a TITLED different-view save-as still stays
# dirty (D5/D13, deliberate) and the own-view save (first arm) is untouched.
# (D13's no-confirm half is retired — see save_as_overwrites_other, :6471 —
# but its dirty half, the part cited here, is unchanged.)
# On success: LibMgr pane refresh (headless-safe catch), notice, the Save-As
# dialog dies. Returns 1 on success, 0 on a reported error (dialog kept up).
# item 14 (D5): the viewer snapshot runs FIRST, so every arm writes the
# up-to-date `viewer` dict.
proc ase::ui::do_save_state_as {key l c v} {
  variable wins; variable dlg; variable meta
  ## ⚠ 0691, THE WEAKER SECOND ARM, REFUSED BEFORE ANY WRITE. `ase::session_path`
  ## returns {} for an unknown key — the SAME value that marks a registered but
  ## UNTITLED session (issue 0141) — so at HEAD an unknown key sailed past every
  ## `return 0` below, reached the `own eq {}` adopt arm, CREATED a view, wrote a
  ## defaults-state file into it, discarded `ase::session_adopt`'s 0 (:3804) and
  ## returned a hardcoded 1. Measured:
  ##   H3B catch=0 res=1
  ##   H3B viewpath = .../aselib/nfet_clean/ngspice_stateH3B/nfet_clean.state
  ## The lie and the litter arrive together, so one guard removes both — and it
  ## cannot touch a registered key, untitled ones included (an untitled session
  ## IS in the registry; only its path is {}). `ase::session_exists` is the
  ## registration predicate this layer never had; using session_path for it is
  ## the conflation that caused this.
  ## After this guard the discarded adopt rc genuinely cannot be 0, which is the
  ## same reasoning 0691 used to CLEAR `viewer_snapshot`.
  if {![ase::session_exists $key]} {
    catch {::ase::echo "ase: no ASE-L session is open under '$key'; the state\
 was NOT saved to $l/$c/$v." error}
    return 0
  }
  ase::ui::viewer_snapshot $key
  set target [xschem cellview_path "$l/$c" $v]
  set own [ase::session_path $key]
  if {$target ne {} && $own ne {} \
      && [file normalize $target] eq [file normalize $own]} {
    if {[catch {ase::session_save $key} err]} {
      catch {::ase::echo "ase: cannot save $l/$c/$v: $err" error}
      return 0
    }
  } else {
    if {$target eq {}} {
      if {[catch {library_new_view $l $c $v ngspice_state1} err]} {
        catch {::ase::echo "ase: cannot create view $l/$c/$v: $err" error}
        return 0
      }
      set target [xschem cellview_path "$l/$c" $v]
      if {$target eq {}} {
        catch {::ase::echo "ase: created view $l/$c/$v did not resolve" error}
        return 0
      }
    }
    if {[catch {ase::state_save $target [ase::session_state $key]} err]} {
      catch {::ase::echo "ase: cannot write $target: $err" error}
      return 0
    }
  }
  # First Save-As of a never-saved (untitled) launch session: adopt the target
  # as this session's real identity. `own eq {}` is the untitled marker — a
  # TITLED session (own ne {}) never reaches here, so its deliberate "save-as to
  # a DIFFERENT view stays dirty" behavior (item 14 D5) and the working own-view
  # save (the first if-arm above) are both untouched. meta is updated BEFORE the
  # adopt so session_adopt's notify repaints "State: <v>" in the status bar and
  # drops the title's "(unsaved)"/"*" cues. `target` here is the resolved real
  # path in both untitled arms (pre-existing view, or the just-created one).
  if {$own eq {}} {
    if {[dict exists $meta $key]} { dict set meta $key [list $l $c $v] }
    ase::session_adopt $key $target
  }
  catch {libmgr::refresh_after $l $c $v}
  catch {::ase::echo "ase: state saved to $l/$c/$v"}
  # item 16 (D3): signal a COMPLETED save to save_state_modal's tkwait. Guarded
  # by info-exists so the ordinary menu Save State path (which never seeds the
  # flag) is byte-identical.
  if {[info exists dlg($key,saveas_result)]} { set dlg($key,saveas_result) 1 }
  if {[dict exists $wins $key]} {
    catch {destroy [dict get $wins $key].saveas}
  }
  return 1
}

# --- title / status bar / notify ---------------------------------------------

# The design cell name shown in titles: state design.cell, falling back to
# the session's own cell when the design is not set.
proc ase::ui::design_cell_name {key} {
  variable meta
  set design [ase::state_get [ase::session_state $key] design]
  if {$design ne {} && [dict exists $design cell] && [dict get $design cell] ne {}} {
    return [dict get $design cell]
  }
  if {[dict exists $meta $key]} { return [lindex [dict get $meta $key] 1] }
  return {}
}

# UI v2 title: `Analog Sim Environment <design cell>` (+ ` *` when dirty —
# nothing in the v2 spec supersedes the dirty marker).
proc ase::ui::refresh_title {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  if {![winfo exists $top]} { return }
  set t "Analog Sim Environment [ase::ui::design_cell_name $key]"
  if {[ase::session_getattr $key untitled 0] eq {1}} { append t { (unsaved)} }
  if {[ase::session_dirty $key]} { append t { *} }
  wm title $top $t
}

# Refresh the non-status segments of the bottom bar (win# / T= / Simulator /
# State) from the session; the colored .stat segment is set_status's own.
#
# ⚠ THE `Simulator:` SEGMENT NAMES WHAT WILL RUN, NOT THE BACKEND (issue 1370).
# It used to render `[ase::state_get $st simulator]` and therefore carried zero
# registry information: measured on a live window, `Simulator: ngspice` with
# `ngspice-ver50` selected, with the choice cleared, and with it re-selected.
# ase::sim_label is the one place that decides what to call it; no sentence and
# no marker text is written in this file (ruling D5-4, row R9).
proc ase::ui::refresh_status {key} {
  variable wins; variable wnum; variable meta
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  if {![winfo exists $top.status]} { return }
  set st [ase::session_state $key]
  lassign [dict get $meta $key] lib cell view
  $top.status.win   configure -text [dict get $wnum $key]
  $top.status.temp  configure -text "T=[ase::state_get $st temperature 27] C"
  $top.status.sim   configure -text \
    "Simulator: [ase::sim_label [ase::state_get $st simulator]]"
  $top.status.state configure -text "State: $view"
}

# EVERY OPEN SESSION'S BAR, because the registry is PROCESS-GLOBAL while the
# Simulators dialog is per-session (issue 0937's own known-issues note, and the
# half of it 1370 closes). A gesture made in one window changes which program
# every open window would start, so every open window's bar has to follow it.
#
# ⚠ NO SECOND GUARD. ase::ui::refresh_status already returns quietly for a key
# whose toplevel has gone, and `wins` and `meta` are written and deleted
# together in ase::ui::open / ase::ui::close, so a key in one is a key in both.
proc ase::ui::refresh_status_all {} {
  variable wins
  dict for {k top} $wins { ase::ui::refresh_status $k }
}

# The assembled status-bar line (tests + scripting):
# `<win#> | Status: <S> | T=<T> C | Simulator: <sim> | State: <view>`
# `<sim>` is ase::sim_label's answer -- the registered simulator in force, with
# the "not going to run" marker where it applies -- and NOT the backend word
# (issue 1370).
proc ase::ui::status_text {key} {
  variable wins
  if {![dict exists $wins $key]} { return {} }
  set top [dict get $wins $key]
  if {![winfo exists $top.status]} { return {} }
  set segs {}
  foreach s {win stat temp sim state} {
    lappend segs [$top.status.$s cget -text]
  }
  return [join $segs { | }]
}

# ase::session_notify hook: title + status bar only. Repopulating the panes
# here would destroy the entry a FocusOut-driven commit is firing from; Load
# State / Revert repopulate explicitly instead.
proc ase::ui::session_changed {key} {
  ase::ui::refresh_title $key
  ase::ui::refresh_status $key
  ## 0695: AND AN OPEN Save All DIALOG FOLLOWS THE WRITE THAT LANDED BEHIND IT.
  ## LAST, so a broken refresh cannot cost the title/status their update. This
  ## hook is the ONE seam that covers BOTH external writers the issue names —
  ## the pasted CIW remedy (save_op_params_on -> save_all_commit) and
  ## `Session > Load State` (do_load_state_from -> load_state_commit) — because
  ## both funnel through `ase::session_update`, which fires it AFTER the state
  ## is stored. `save_all_refresh` is a total no-op when no such dialog is up.
  ## ⚠ `ase::session_notify` (ase.tcl:71, set at :277) is a SINGLE-SLOT
  ## variable: anything that overwrites it disables the follow with no other row
  ## red. W1zg asserts the slot and the callee structurally, for that reason.
  ## ⚠ KNOWN GAP, FILED AS 0697 rather than widened into here:
  ## `ase::session_open`'s re-open refresh arm (ase.tcl:2696) replaces a clean
  ## session's whole state from disk and fires nothing, so a re-launch onto the
  ## same cellview moves the live state without moving the box (or the dirty
  ## marker, or the status bar).
  ase::ui::save_all_refresh $key
}

# --- Session menu ------------------------------------------------------------
# v1 direct workers, kept as plain scripting/test seams (W7 uses
# revert_state); the Session MENU now routes through the item-07 dialogs
# (save_state_dialog / load_state_dialog above).

proc ase::ui::save_state {key} {
  # item 14 (D5): snapshot the viewer into the state before it hits disk
  ase::ui::viewer_snapshot $key
  ase::session_save $key
}
proc ase::ui::load_state {key} {
  ase::session_load $key
  ase::ui::populate $key
}
proc ase::ui::revert_state {key} {
  ase::session_revert $key
  ase::ui::populate $key
}

# The session design's resolved schematic path ({} when unresolvable);
# default view schematic, the ase::netlist idiom.
proc ase::ui::design_path {key} {
  set design [ase::state_get [ase::session_state $key] design]
  if {$design eq {} || ![dict exists $design lib] || ![dict exists $design cell]} {
    return {}
  }
  set view schematic
  if {[dict exists $design view] && [dict get $design view] ne {}} {
    set view [dict get $design view]
  }
  set p [xschem cellview_path [dict get $design lib]/[dict get $design cell] $view]
  if {$p eq {}} { return {} }
  return [file normalize $p]
}

# Raise the editor window already holding cellview `dpath`: deterministic
# context switch (does not rely on WM focus), then bring its owning toplevel
# ("." = the main window) to the front + activation logging. Returns 1 when a
# window held the design, else 0. WSLg/Weston drops bare `raise` restack
# requests, so this goes through the shared withdraw/deiconify re-map helper
# raise_activate_toplevel (issue 0054 lesson — LibMgr/CIW use it too).
#
# A window DESCENDED into the design counts (issue 0168). Its `current_name` is
# the child, so an exact-name scan alone declared the design "not open anywhere"
# and design_window re-loaded the top into another window — throwing away the
# hierarchy the user had navigated to, which is exactly where they wanted to
# Direct-Plot. The 7th `xschem windows` field is the window's whole stack, so a
# descended window is now matched on any level of it. Exact `current_name`
# matches still WIN (first loop): a window actually showing the design is the
# better answer, and that ordering keeps the shipped behavior byte for byte.
proc ase::ui::raise_design_editor {dpath {raise_mode always}} {
  set wins [xschem windows]
  foreach e $wins {
    if {[file normalize [lindex $e 4]] eq $dpath} {
      return [ase::ui::raise_window_entry $e $raise_mode]
    }
  }
  foreach e $wins {
    foreach s [lindex $e 6] {
      if {$s ne {} && [file normalize $s] eq $dpath} {
        return [ase::ui::raise_window_entry $e $raise_mode]
      }
    }
  }
  return 0
}

# Make the window described by an `xschem windows` entry current + frontmost.
# Always returns 1 (the caller has already decided this window is the one).
#
# TWO JOBS, and callers need them separately (issue 0616). Job 1 is the CONTEXT
# switch -- `xschem new_schematic switch` -- which is what makes ase::netlist's
# own "the design must BE the current schematic" guard (ase.tcl) pass. Job 2 is
# bringing the owning TOPLEVEL to the front, which on WSLg can only be done by
# re-MAPping it (raise_activate_toplevel = wm withdraw + wm deiconify, see its
# header and issue 0054). Job 2 is not free: that WM is documented to DROP a
# re-map outright, and each one costs a ~32px NW creep -- so a caller that only
# wants job 1 must not be made to pay for job 2. `raise_mode ifhidden` does job
# 1 always and job 2 only when the toplevel is NOT currently mapped, so a
# minimised (or already-lost) window is still brought back while a visible one
# is left exactly where the user put it. Anything that is not literally
# `ifhidden` means `always` -- the shipped behaviour -- so a typo or a future
# third mode degrades to raising rather than silently disabling every raise in
# the program. `vis` defaults to 0 so the headless path (no winfo) takes the
# always arm and raise_activate_toplevel's own has_x guard no-ops it, exactly
# as today.
#
# `ifhidden` on an ALREADY-MAPPED toplevel still does the CHEAP half of the
# raise -- a plain `raise` + `xschem activate_window`, the tail of
# raise_activate_toplevel (xschem.tcl) with only the withdraw/deiconify re-map
# ahead of it dropped. Measured (issue 0616): a bare `raise .` restacked the
# design above a pixel-coincident waveform viewer with Unmap/Map = 0/0, and
# issue 0054 records that a plain raise is an inert NO-OP on WSLg once a window
# is mapped -- so it cannot bring back the vanish, and it is what keeps
# "the design window is still VISIBLE after a run" true on every other X server
# (including the user's own, which is a Windows X server over TCP, not WSLg).
# Dropping it too was the first cut of this fix and it was REFUTED by
# measurement: the run left the schematic underneath the viewer that
# viewer_restore had opened over it, i.e. the reported symptom with a different
# mechanism. Do not "simplify" these two lines away.
proc ase::ui::raise_window_entry {e {raise_mode always}} {
  xschem new_schematic switch [lindex $e 0]
  set tp [lindex $e 1]
  if {$tp eq {}} { set tp . }
  set vis 0
  catch {set vis [winfo ismapped $tp]}
  if {$raise_mode ne {ifhidden} || !$vis} {
    raise_activate_toplevel $tp
  } else {
    catch {raise $tp}
    catch {xschem activate_window [winfo id $tp]}
  }
  catch {focus $tp}
  return 1
}

# Session > Design Window: raise the editor window already holding the design,
# else open it via the libmgr::open_view `-gui` load precedent (gated action
# log + deferred WSLg repaint) AND raise the window the load landed in — the
# v1 bug was loading into a stacked-under main window and never raising it,
# so nothing visibly happened. Returns 1 on success, 0 when the design does
# not resolve.
#
# `raise_mode` is forwarded to the already-open arm only (issue 0616): Session >
# Design Window, select_on_design/direct_plot and wave_viewer's browser descend
# all pass nothing and keep the shipped always-raise -- the Session menu item in
# particular IS the user's documented recovery when a window has gone missing,
# so it must keep re-mapping. do_run passes `ifhidden`. The post-load re-scan
# below always raises, for the v1 reason above.
proc ase::ui::design_window {key {raise_mode always}} {
  set dpath [ase::ui::design_path $key]
  if {$dpath eq {}} {
    catch {::ase::echo "ase: cannot resolve the session's design cellview" error}
    return 0
  }
  if {[ase::ui::raise_design_editor $dpath $raise_mode]} { return 1 }
  # not open anywhere: interactive open (reuses a pristine untitled window,
  # else opens a new one — load_window_routing), action-log dedup-gated
  xschem log_action -reset
  xschem load -gui $dpath
  if {![xschem log_action -emitted]} {
    xschem log_action "xschem load -gui {$dpath}"
  }
  # the design now lives in the reused untitled window or a routed new
  # window: re-scan + raise it above the ASE window
  ase::ui::raise_design_editor $dpath
  # WSLg deferred repaint (issue 0052)
  after 120 [list force_window_repaint [xschem get current_win_path] 0]
  return 1
}

# --- status segment ----------------------------------------------------------

# Mirror set_simulate_button semantics on the status bar's .stat segment:
# running=orange/Running, ok=Green/Ready, fail=red/Error, idle=the themed
# panel background/Ready. Also refreshes the passive segments so T=/Simulator
# are current whenever the status changes.
proc ase::ui::set_status {key what} {
  variable wins; variable idlebg
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  if {![winfo exists $top.status.stat]} { return }
  ase::ui::refresh_status $key
  switch -- $what {
    running { set bg orange;         set txt Running }
    ok      { set bg Green;          set txt Ready }
    fail    { set bg red;            set txt Error }
    default { set bg $idlebg($key);  set txt Ready }
  }
  catch {$top.status.stat configure -background $bg -text "Status: $txt"}
}

# --- log window (UI v2: a toplevel, NOT a pane) ------------------------------

# The log text widget of the session ({} when the log window is closed).
proc ase::ui::log_widget {key} {
  variable wins
  if {![dict exists $wins $key]} { return {} }
  set t [dict get $wins $key].logwin.t
  if {![winfo exists $t]} { return {} }
  return $t
}

# Open (or raise) the session's log toplevel. A CHILD of the session window
# (dies with it; and not a child of `.`, so `.ase*`-globbing helpers never
# mistake it for a session window). Ctrl-W closes it — bound on the toplevel,
# so bindtags fire it from any child widget.
proc ase::ui::log_open {key} {
  variable wins
  if {![dict exists $wins $key]} { return {} }
  set top [dict get $wins $key]
  set lw $top.logwin
  if {[winfo exists $lw]} {
    catch {wm deiconify $lw}
    catch {raise $lw}
    return $lw
  }
  toplevel $lw
  wm title $lw "Simulation Log \u2014 [ase::ui::design_cell_name $key]"
  text $lw.t -height 24 -width 84 -state disabled -wrap none \
       -yscrollcommand [list $lw.sb set]
  scrollbar $lw.sb -orient vertical -command [list $lw.t yview]
  pack $lw.sb -side right -fill y
  pack $lw.t -side left -fill both -expand 1
  bind $lw <Control-w> [list destroy $lw]
  bind $lw <Control-W> [list destroy $lw]
  ase::ui::apply_theme $lw
  return $lw
}

proc ase::ui::log_clear {key} {
  set t [ase::ui::log_widget $key]
  if {$t eq {}} { return }
  $t configure -state normal
  $t delete 1.0 end
  $t configure -state disabled
}

proc ase::ui::log_append {key text} {
  set t [ase::ui::log_widget $key]
  if {$t eq {}} { return }
  $t configure -state normal
  $t insert end $text
  $t configure -state disabled
  $t see end
}

# Simulation > Log: raise the log window if open; else recreate it and fill
# it from the live execute buffer (run in flight) or the backend's log file
# (the old view_log resolution idiom).
proc ase::ui::show_log {key} {
  variable wins; variable loglen
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  if {[winfo exists $top.logwin]} {
    catch {wm deiconify $top.logwin}
    catch {raise $top.logwin}
    return
  }
  ase::ui::log_open $key
  set id [ase::session_getattr $key run_id {}]
  if {$id ne {} && [info exists ::execute(data,$id)]} {
    # live run: show the buffer so far and resync the trace bookkeeping so
    # subsequent deltas continue from the right offset
    ase::ui::log_append $key $::execute(data,$id)
    set loglen($key) [string length $::execute(data,$id)]
    return
  }
  set st [ase::session_state $key]
  if {[catch {
    set sim [ase::state_get $st simulator]
    set f [[ase::backend_hook $sim log_file] $st]
  } err]} {
    catch {::ase::echo $err error}
    return
  }
  if {[file isfile $f]} {
    # ::open — inside ase::ui a bare `open` resolves to ase::ui::open
    set fh [::open $f r]
    set data [read $fh]
    close $fh
    ase::ui::log_append $key $data
  } else {
    catch {::ase::echo "ase: no simulation log yet: $f"}
  }
}

# Attach the live-log trace for run id: execute_fileevent appends 1024-byte
# chunks to execute(data,$id), each append fires this write trace, and the
# handler pushes only the DELTA into the log widget. The EOF unset of
# execute(data,$id) kills the trace automatically; drop_trace covers early
# window close.
proc ase::ui::attach_trace {key id} {
  variable loglen; variable tracecb
  ase::ui::drop_trace $key
  set loglen($key) 0
  set cb [list ase::ui::log_trace $key $id]
  trace add variable ::execute(data,$id) write $cb
  set tracecb($key) [list $id $cb]
}

proc ase::ui::drop_trace {key} {
  variable tracecb
  if {![info exists tracecb($key)]} { return }
  lassign $tracecb($key) id cb
  catch {trace remove variable ::execute(data,$id) write $cb}
  unset tracecb($key)
}

# write-trace handler (args = name1 name2 op, unused)
proc ase::ui::log_trace {key id args} {
  variable loglen
  if {![info exists ::execute(data,$id)]} { return }
  if {![info exists loglen($key)]} { return }
  set data $::execute(data,$id)
  set delta [string range $data $loglen($key) end]
  set loglen($key) [string length $data]
  if {$delta eq {}} { return }
  ase::ui::log_append $key $delta
}

# --- Simulation menu ---------------------------------------------------------

# Simulation > Netlist > Recreate: regenerate the circuit netlist artifact,
# report via ase::echo — no viewer (that is Display's job).
proc ase::ui::do_netlist_recreate {key} {
  if {[catch {ase::netlist [ase::session_state $key]} nl]} {
    catch {::ase::echo $nl error}
    return
  }
  catch {::ase::echo "ase: netlist written: $nl"}
}

# Auto-plot after a successful run (item 13, D5): every outputs row with
# plot==1 is rebuilt into the viewer's dedicated auto graph (the `auto 1`
# model marker) — v1 ALWAYS-REPLACE policy: the auto graph's traces are
# cleared and re-added each run, Direct-Plot graphs are never touched
# (clear-not-remove keeps their indices stable). Zero plot rows -> never
# opens a viewer to show nothing (but an already-open viewer's stale auto
# graph is emptied). op-only results -> notice (no sweep, nothing
# plottable). Row exprs go through plot_map_expr (D6); the row name is used
# as the trace name when it is a legal vector name (add_trace's rule), else
# auto. Reached from run_finished via auto_plot_idle (after idle + catch): a
# viewer failure must never break the status pipeline.
proc ase::ui::auto_plot {key} {
  set st [ase::session_state $key]
  set rows {}
  foreach o [ase::state_get $st outputs] {
    if {[ase::state_get $o plot 0] eq {1} && [dict exists $o expr]} {
      lappend rows $o
    }
  }
  if {![llength $rows]} {
    if {[wviewer::window_for $key] ne {}} {
      set gi [wviewer::auto_graph_index $key]
      if {$gi >= 0} {
        # issue 0194: this regenerate carries every OTHER strip forward, so it
        # owes the fold — clear_graph_traces drops the selection of the auto
        # strip alone, and without this the rebuild-from-model would take the
        # user's selection on every other strip with it. Same rule, and the
        # same helper, as the twelve sites inside wave_viewer.tcl; it is only
        # the FILE that differs. Must run BEFORE clear_graph_traces (that is
        # the model mutation) and it does its own verified switch_ctx.
        wviewer::capture_live_view_state $key
        wviewer::clear_graph_traces $key $gi
        wviewer::regenerate $key
      }
    }
    return
  }
  set sim_t [ase::plot_sim_type $st]
  if {$sim_t eq {op}} {
    catch {::ase::echo "ase: op results have no sweep — nothing to auto-plot"}
    return
  }
  if {![wviewer::open $key]} { return }
  set rf [ase::last_rawfile $key]
  if {$rf eq {}} {
    # the run just succeeded, so this is exceptional (raw write failed?)
    catch {::ase::echo "ase: no raw file from the run — nothing to auto-plot"}
    return
  }
  # spec E3: the run's digital VCDs ride along with the analog raw, so a
  # mixed-signal session's Signal Browser sees every DB the run produced.
  wviewer::attach_raw $key $rf $sim_t [ase::last_vcdfiles $key]
  set gi [wviewer::ensure_auto_graph $key]
  wviewer::clear_graph_traces $key $gi
  wviewer::regenerate $key   ;# reflect the clear even if every add fails
  # casemode item 12: map every row FIRST, then repair the batch in ONE pass —
  # wviewer::repair_currents reads the whole database inventory per call, so a
  # per-row call would pay that once per output row instead of once per attach.
  # plot_map_expr runs first so the `-i(v1)` -> `i(v1) -1 *` RPN is repaired in
  # the form add_trace will actually validate.
  set exs {}
  foreach o $rows { lappend exs [ase::ui::plot_map_expr [ase::state_get $o expr]] }
  set exs [ase::ui::repair_currents $key $exs]
  set ei 0
  foreach o $rows {
    set ex [lindex $exs $ei]
    incr ei
    set nm [ase::state_get $o name]
    if {![regexp {^[A-Za-z_][A-Za-z0-9_]*$} $nm]} { set nm {} }
    set err [wviewer::add_trace $key $gi $ex $nm]
    if {$err ne {}} {
      catch {::ase::echo "ase: cannot auto-plot '[ase::state_get $o expr]': $err" error}
    }
  }
}

# The deferred auto-plot entry run_finished schedules (item 13, D5). WHY
# `after idle`: run_finished fires from the execute fileevent, which can be
# dispatched INSIDE ase::wait's semaphore bracket (the vwait) — with the
# current window's semaphore raised, every `new_schematic switch` is a
# silent no-op (xinit.c switch_window), so running auto_plot right there
# would aim its viewer clear/read/regenerate at the DESIGN window
# (probe-verified: it emptied the design schematic). At idle time the
# bracket is balanced and switches work; wviewer::switch_ctx backstops any
# residual refusal loudly. The catch keeps an idle-time viewer failure out
# of Tk's bgerror modal.
proc ase::ui::auto_plot_idle {key} {
  catch {ase::ui::auto_plot $key}
}

# ase run completion callback (eval'd at #0 by ase::run_done AFTER the log
# file was flushed and results parsed): final log delta, status color, drop
# the live run id.
proc ase::ui::run_finished {key} {
  variable loglen
  if {[info exists loglen($key)]} {
    set data {}
    if {[info exists ::execute(data,last)]} { set data $::execute(data,last) }
    set delta [string range $data $loglen($key) end]
    if {$delta ne {}} { ase::ui::log_append $key $delta }
    unset loglen($key)
  }
  ase::ui::drop_trace $key
  # spec E7: a co-simulation desync exits 0 and produces wrong waveforms.
  # ase::run_done already echoed it to the CIW and the action log; put it at
  # the END of the log window too, where a user who opened the log to read the
  # tail cannot miss it. Before the exit-code branch, so it is said whichever
  # way the run ended.
  foreach d [ase::last_diagnostics] {
    lassign $d dsev dcode dn dmsg
    if {$dsev ne {error}} continue
    catch {ase::ui::log_append $key \
      "\n*** ASE-L: CO-SIMULATION PROBLEM ($dcode x$dn): $dmsg.\
 The results of this run cannot be trusted. ***\n"}
  }
  set ec -1
  if {[info exists ::execute(exitcode,last)]} { set ec $::execute(exitcode,last) }
  if {$ec == 0} {
    # UI v2 Value column: per-SESSION results (a global last_result would
    # bleed session A's numbers into session B); display-only, never
    # serialized to the state file
    ase::session_setattr $key results [ase::last_result]
    ase::ui::refresh_output_values $key
    ase::ui::set_status $key ok
    # item 13 (D5): Plot-checked rows -> the viewer's auto graph. Deferred:
    # this callback can run inside ase::wait's semaphore bracket where
    # window switches silently no-op — see auto_plot_idle.
    after idle [list ase::ui::auto_plot_idle $key]
    # ISSUE 0684 (GUARD G14): annotation was the ONLY consumer of new results
    # that was not on this event -- a finished run already re-reads the results,
    # refreshes the output values and re-plots, while the schematic went on
    # showing the PREVIOUS run's id / gm / gds until somebody pressed a key.
    # BELOW the auto-plot line deliberately: the viewer's own context borrow
    # runs first and balances itself, so ours reads a restored context rather
    # than the viewer's. Row F34 pins that order, row F31 the behaviour.
    after idle [list ase::ui::annot_refresh_idle $key]
  } else {
    ase::ui::set_status $key fail
  }
  ase::session_setattr $key run_id {}
}

# Wire a successfully started run into the window: run id bookkeeping, the
# log toplevel (opened + cleared), the live trace, the Running status.
proc ase::ui::run_started {key id} {
  ase::session_setattr $key run_id $id
  ase::ui::log_open $key
  ase::ui::log_clear $key
  ase::ui::attach_trace $key $id
  ase::ui::set_status $key running
}

# 1389: IS THIS SESSION'S RESULTS FILE ALREADY BEING WRITTEN? The lock key
# (the raw path) when a run is in flight, else {}.
#
# ⚠ THE DOORS ASK BEFORE THEY ACT, and that is not belt-and-braces over
# ase::run_deck's gate -- it is the only way to refuse WITHOUT
# `ase::ui::set_status $key fail`. Both doors below turn the status segment RED
# on any raise out of ase::run, and a refused second launch has nothing wrong
# with it: the first run is alive and the status must go on saying Running.
# Going through ase::run would also re-netlist the design (ase::netlist deletes
# and rebuilds <cell>.spice) before the authority ever saw the launch.
#
# ONE PREDICATE (ase::run_in_flight, src/ase.tcl:6042 -- the only reader of the
# lock table), THREE CONSUMERS: ase::run_deck's gate, this, and the lock
# fallback in ase::ui::do_stop that makes the refusal's remedy clause true.
# Three callers of one answer is invariant I1 kept; two procs each deciding
# what "running" means is what it forbids.
proc ase::ui::run_busy {key} {
  set lk {}
  if {[catch {ase::run_lock_key [ase::session_state $key]} lk]} { return {} }
  if {[ase::run_in_flight $lk] eq {}} { return {} }
  return $lk
}

# 1389: A RAISE OUT OF ase::run MAY BE THE REFUSAL ITSELF, and then it must not
# redden a session whose earlier run is alive and healthy.
#
# ⚠ THE DOOR'S PRE-CHECK IS NOT ENOUGH, AND THE GAP IS THE ORIGINATING GESTURE.
# ase::ui::do_run calls `update` in its design-window routing arm -- the arm
# whose own comment says it fires routinely while the design window is fully
# visible and front. Measured 2026-09-08 with the second press queued as a real
# X event so it dispatches inside that `update`: the inner press passes
# run_busy (no lock yet), launches and locks; the OUTER press then meets the
# lock in ase::run_deck and used to arrive here as an ordinary failure. One
# simulator started (the guard's core job held), but the status segment went
# `running` -> `fail` -- a red Error over a live run -- and the same sentence
# reached the CIW TWICE, once as `note` and once as `error`, which is also the
# opposite of the note-not-error decision this refusal was built on.
#
# The discriminator is the minted sentence itself, not a code or a flag: the
# gate returns exactly `ase::run_busy_msg` of the key it refused, and
# ase::run_lock_set is the last statement before run_deck returns, so nothing
# else can raise while this session's results file is locked. Anything that is
# not that sentence still reddens, exactly as before.
proc ase::ui::run_raised {key err} {
  set lk [ase::ui::run_busy $key]
  if {$lk ne {} && $err eq [ase::run_busy_msg $lk]} { return 0 }
  catch {::ase::echo $err error}
  ase::ui::set_status $key fail
  return 1
}

# Simulation > Netlist and Run: re-netlist the design, then run.
proc ase::ui::do_run {key} {
  ## 1389: FIRST STATEMENT, above the design-window routing. A refused launch
  ## must not withdraw+deiconify the schematic window on its way to saying no
  ## (issue 0616's cost), and must not re-netlist.
  set busy [ase::ui::run_busy $key]
  if {$busy ne {}} { ase::run_refuse $busy ; return }
  set dpath [ase::ui::design_path $key]
  if {$dpath eq {}} {
    catch {::ase::echo "ase: cannot resolve the session's design cellview" error}
    ase::ui::set_status $key fail
    return
  }
  ## THE DOOR ASKS "IS THE DESIGN REACHABLE", NOT "IS IT CURRENT" (issue 0643).
  ## The user, 2026-09-08: "I descend into x1 and again x1. Now, I click the N&>
  ## ... `ase: design is not the current schematic; open it via Session > Design
  ## Window first`. Where does this inane restriction come from? There is no such
  ## limitation in Cadence's ADE-L, which we want be better than."
  ##
  ## They were right, and the equality test was the whole of it. Standing two
  ## levels down inside the design's OWN hierarchy, `xschem get schname` is the
  ## op-amp, not the testbench, so `ne $dpath` fired and the sentence told them
  ## to do the very thing they had already done -- Session > Design Window
  ## brings that same descended window back and changes nothing about the
  ## comparison, so the button was simply unusable from depth. `ase::stack_level`
  ## (src/ase.tcl) answers the question that actually gates the netlist: is the
  ## design ON THIS WINDOW'S HIERARCHY STACK, at any level (>= 0), or nowhere
  ## (-1)? Making it current for the duration is `ase::netlist`'s job now
  ## (ase::with_design_current), and it puts the user back on the level they
  ## were standing on -- MEASURED 34 ms for a two-level trip, against the 66 ms
  ## the C netlister and the 177 ms op_annot::save_cards already spend making
  ## the same trip on every press, which is the "no added cost" the user asked
  ## for. It is NOT this door's job to walk the hierarchy: a door that ascended
  ## would have to unwind on every error arm below it, and ase::netlist is the
  ## one place that knows whether it got as far as needing to.
  ##
  ## ⚠ AND THE SAFETY IS DOWN THERE TOO, NOT HERE. This pre-check is a UX
  ## router, not the netlister's guard: `ase::netlist` refuses on its own for an
  ## unreachable design, so deleting this block would not netlist the wrong
  ## deck. What it WOULD lose is issue 0616's routing (below) and a refusal that
  ## can say no without going through `ase::run` -- see run_busy's header for why
  ## a raise out of there is the wrong shape for a refusal. The reason the batch
  ## did not simply DROP the old equality test is a different fact and it lives
  ## one layer down: global_spice_netlist() netlists `xctx->sch[xctx->currsch]`,
  ## the level you are STANDING on (src/spice_netlist.c:359-373), not the top, so
  ## "netlist from wherever the user happens to be" would silently simulate the
  ## op-amp alone -- no sources, no testbench, and a results file that looks
  ## perfectly healthy. The old guard was a symptom of that, not superstition;
  ## what changed is that the round trip now exists to satisfy it.
  ##
  ## `ifhidden`, NOT the default, and issue 0616's reasoning is UNCHANGED by the
  ## new predicate -- it only fires less often. This tests the xschem CONTEXT,
  ## not visibility, so it still fires while the design window is fully visible
  ## and front (a restored waveform viewer leaves the context on the viewer
  ## canvas -- the user's other reported case, and one the stack test does not
  ## absorb: the viewer canvas is a different WINDOW, so the design is not on
  ## its stack either). The default arm would then withdraw+deiconify the whole
  ## main toplevel for no reason, and on WSLg a dropped re-map is a schematic
  ## window that simply vanished -- issue 0616, "when I press Netlist and Run,
  ## the schematic window disappears". `ifhidden` still restores a design window
  ## that really IS hidden, and still `raise`s a visible one to the front (the
  ## cheap half of the raise -- see raise_window_entry), so the schematic ends
  ## up on screen either way and no user is left hunting the Session menu.
  if {[ase::stack_level $dpath] < 0} {
    ase::ui::design_window $key ifhidden
    update
    ## The surviving refusal is for a design that is genuinely NOWHERE on this
    ## window's stack -- and it is reached only AFTER the routing above has
    ## already tried and failed, so it must not send the user back to Session >
    ## Design Window as if that were untried (issue 0643, decision D5). It names
    ## the cell, because a session window carries no other clue which cellview
    ## it could not reach.
    if {[ase::stack_level $dpath] < 0} {
      ## D6: the HEAD is minted once (ase::design_unreachable_msg, src/ase.tcl),
      ## the TAIL is the caller's. `ase::netlist`'s copy of this refusal ends
      ## "open it via Session > Design Window first", which is true THERE -- a
      ## CIW or script caller has not tried the route. This arm has, one line
      ## up, and failed, so pointing the user back at that menu item would tell
      ## them to repeat a step that just silently did nothing. Two situations,
      ## two truthful remedies, one fact spelled in one place.
      catch {::ase::echo [ase::design_unreachable_msg \
        [ase::ui::design_cell_name $key] \
        "Session > Design Window did not open it"] error}
      ase::ui::set_status $key fail
      return
    }
  }
  if {[catch {ase::run [ase::session_state $key] [list ase::ui::run_finished $key]} id]} {
    ase::ui::run_raised $key $id
    return
  }
  ase::ui::run_started $key $id
}

# Simulation > Run: run on the EXISTING netlist artifact — never re-netlists
# (hand-edited decks survive), so it needs no current-schematic routing and
# works with the design window closed.
proc ase::ui::do_run_existing {key} {
  ## 1389: the same refusal, and the same reason it is not left to the catch
  ## below -- that arm calls `set_status $key fail`, which would recolour a
  ## session whose earlier run is still perfectly healthy.
  set busy [ase::ui::run_busy $key]
  if {$busy ne {}} { ase::run_refuse $busy ; return }
  if {[catch {ase::run_existing [ase::session_state $key] [list ase::ui::run_finished $key]} id]} {
    ase::ui::run_raised $key $id
    return
  }
  ase::ui::run_started $key $id
}

# Stop the session's live run: kill through the execute pipe pid
# (`kill_running_cmds <id> <sig>` numeric branch). SIGKILL for a deterministic
# abort — close() then reports CHILDKILLED -> nonzero exitcode -> the normal
# completion path (run_finished) turns the status segment red. Unix only: the
# kill(1) path cannot work on Windows.
#
# ⚠ 1389: THE SESSION ATTR IS NOT THE ONLY WAY IN, because the refusal SENDS
# people here. `run_id` is set by ase::ui::run_started, so only the session that
# pressed the button holds it -- and the lock the refusal is about is keyed on
# the RESULTS FILE, which several sessions share. Measured 2026-09-08, all three
# reachable and all three ending in "no simulation running for this session"
# over a run that was very much alive:
#   * two ASE-L sessions on one cellview (ngspice_state1 + ngspice_state2, one
#     rundir, one raw): B is refused, told to press Stop, and B's Stop is a
#     no-op. B can neither run nor stop -- a dead end the sentence created;
#   * a run started from the CIW or a script sets no run_id at all;
#   * closing and re-opening the ASE-L window mid-run: ase::session_close drops
#     every attr (ase.tcl:8588), so run_id goes 12 -> {} for the very session
#     that launched.
# So the attr is tried first (it is the exact run this session started) and the
# lock answers for the rest. Same predicate as the refusal, ase::run_in_flight,
# which is what makes "the sentence names a way out that works" checkable
# rather than hopeful.
proc ase::ui::do_stop {key} {
  global OS
  set id [ase::session_getattr $key run_id {}]
  if {$id eq {} || ![string is integer -strict $id] || ![info exists ::execute(pipe,$id)]} {
    set id {}
    if {![catch {ase::run_lock_key [ase::session_state $key]} lk]} {
      set id [ase::run_in_flight $lk]
    }
  }
  if {$id eq {}} {
    catch {::ase::echo "ase: no simulation running for this session"}
    return
  }
  if {[regexp -nocase {windows} $OS]} {
    catch {::ase::echo "ase: Stop is not available on Windows"}
    return
  }
  catch {kill_running_cmds $id -9}
  ## STAGE 2e: SAY WHAT THE STOP COST, AND ONLY ON THE PATH THAT KILLED
  ## SOMETHING. The two early returns above keep the sentences they have -- the
  ## nothing-to-stop path must not claim a run was discarded. The clause comes
  ## from the backend (ase::run_stop_cost); a backend that declares none says
  ## nothing, because "what a stop costs" is a run-model fact core does not know
  ## for a simulator it was never told about.
  ##
  ## ⚠ THIS MOVES ROW RG13 of tests/headless/test_ase_core.tcl, deliberately.
  ## RG13 asserted that a successful Stop says NOTHING to the CIW -- which was
  ## true, and is the defect: the Stop succeeded silently and the user went
  ## looking for a rawfile that was never written.
  ## ⚠ ABSOLUTELY QUALIFIED, and this file's own header says why: these procs
  ## run inside `namespace eval ase::ui`, where the relative name `ase::foo`
  ## resolves against ase::ui:: first. Written relative and wrapped in a catch,
  ## the lookup failed SILENTLY and row RG13 read an empty CIW -- the failure
  ## mode the catch exists to prevent, hiding the defect it was protecting.
  set stopmsg {}
  catch {set stopmsg [::ase::run_stopped_msg \
                        [::ase::state_get [::ase::session_state $key] simulator]]}
  if {$stopmsg ne {}} { catch {::ase::echo $stopmsg} }
}

# Simulation > Netlist > Display: the circuit netlist artifact in a read-only
# textwindow (shared infra — deliberately NOT ASE-themed).
proc ase::ui::view_netlist {key} {
  set st [ase::session_state $key]
  if {[catch {dict get $st design cell} cell]} {
    catch {::ase::echo "ase: state has no design cell" error}
    return
  }
  set f [file join [ase::rundir $st] $cell.spice]
  if {[file isfile $f]} { textwindow $f ro } \
  else { catch {::ase::echo "ase: no netlist yet: $f"} }
}
