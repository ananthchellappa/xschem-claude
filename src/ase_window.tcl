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
# LOCKED colors; no ASE widget left on Tk defaults).
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
  # analysis arg fields per type (the spec's v1 schema; also the Arguments
  # summary order of the Analyses pane)
  variable anaargs [dict create op {} dc {source start stop step} \
                                ac {points start stop dec} tran {step stop}]
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
  # combo full-value lists (dlib/dcell/dview/salib), and the list-dialog row
  # index (models/simopt). Cleaned on dialog proceed/cancel AND in close.
  variable dlg;     array set dlg {}
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
                        heads {Name Value} ed optrow edtitle {Simulation Option}]]
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
# does `option add *TCombobox*Listbox.font AseEntryFont`, which is
# PROCESS-GLOBAL and reaches the popdown of every ttk::combobox in xschem (33
# call sites, 15 of them in xschem.tcl) — including comboboxes created before
# the call, because the popdown listbox is built lazily. A caller that only
# wants to know what colour a panel is must not pay that. The Calculator's
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

# The central ASE look: named fonts (created once — the
# references/copy_current_cell_dialog.tcl idiom), the combobox listbox font +
# white-field style, and the locked palette applied to the shared styles.
# Returns the whole palette dict, or one color when `name` is given.
#
# ⚠ NOT a pure reader — see ase::palette. Call THIS when widgets are about to
# be created or themed; call ase::palette when only a colour is wanted.
proc ase::theme {{name {}}} {
  if {[lsearch -exact [font names] AseLabelFont] < 0} {
    font create AseLabelFont -family Arial -size 10 -weight bold
  }
  if {[lsearch -exact [font names] AseEntryFont] < 0} {
    font create AseEntryFont -family Arial -size 13
  }
  if {[lsearch -exact [font names] AseMonoFont] < 0} {
    font create AseMonoFont -family Courier -size 13
  }
  option add *TCombobox*Listbox.font AseEntryFont
  catch {ttk::style configure Ase.TCombobox -fieldbackground [ase::palette table]}
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
    ttk::style configure Ase.Treeview.Heading -font AseLabelFont \
      -background [ase::palette header]
  }
  return [ase::palette $name]
}

# Recursively re-skin an ASE widget tree: every widget class the ASE window
# uses gets the locked palette + a named font — no stock-Tk leftovers. The
# shared `textwindow` viewer (Netlist > Display) deliberately stays stock:
# restyling it would restyle every non-ASE use.
proc ase::ui::apply_theme {w} {
  set cls [winfo class $w]
  switch -- $cls {
    Toplevel - Frame - Labelframe - Menu - Button - Label - Checkbutton {
      catch {$w configure -background [ase::theme panel]}
      catch {$w configure -font AseLabelFont}
      if {$cls eq {Labelframe}} {
        catch {$w configure -foreground [ase::theme accent]}
      }
    }
    Entry {
      catch {$w configure -background [ase::theme table] -font AseEntryFont}
    }
    Text {
      catch {$w configure -background [ase::theme table] -font AseMonoFont}
    }
    TCombobox {
      catch {$w configure -font AseEntryFont -style Ase.TCombobox}
    }
    Treeview {
      # ttk widgets ignore -background/-font configure: style-based theming
      catch {$w configure -style Ase.Treeview}
    }
    Scrollbar {
      catch {$w configure -background [ase::theme panel]}
    }
  }
  foreach c [winfo children $w] { ase::ui::apply_theme $c }
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
# COMPLETED (1) or was cancelled (0). No grab (the RO-overwrite confirm is a
# nested child). Completion is flagged by do_save_state_as via
# dlg($key,saveas_result).
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
  $top.mb add cascade -label Analyses -menu $top.mb.analyses
  $top.mb.analyses add command -label "Choose\u2026" \
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
  $top.mb add cascade -label Simulation -menu $top.mb.sim
  menu $top.mb.sim.netlist -tearoff 0
  $top.mb.sim.netlist add command -label Recreate \
    -command [list ase::ui::do_netlist_recreate $key]
  $top.mb.sim.netlist add command -label Display \
    -command [list ase::ui::view_netlist $key]
  $top.mb.sim add cascade -label Netlist -menu $top.mb.sim.netlist
  $top.mb.sim add command -label {Netlist and Run} \
    -command [list ase::ui::do_run $key]
  $top.mb.sim add command -label Run \
    -command [list ase::ui::do_run_existing $key]
  $top.mb.sim add command -label Stop -command [list ase::ui::do_stop $key]
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
  $top.mb add cascade -label Tools -menu $top.mb.tools
  $top.mb.tools add command -label {Waveform Viewer} \
    -command [list ase::ui::open_viewer $key]
  $top.mb.tools add command -label Calculator -command calc::open

  # toolbar row under the menubar: the simulation-temperature entry (state
  # key `temperature`, commit-validated numeric -> `.temp <T>` in the deck)
  frame $top.tb
  entry $top.tb.temp -width 7
  bind $top.tb.temp <Return>   [list ase::ui::temp_commit $key]
  bind $top.tb.temp <FocusOut> [list ase::ui::temp_commit $key]
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
  ase::ui::build_pane $key $top vars {name value} {Name Value} \
    {name 140 value 120}
  ase::ui::build_pane $key $top ana {num type enable args} \
    [list # Type Enable Arguments] {num 30 type 60 enable 60 args 260}
  ase::ui::build_pane $key $top outs {name value plot save saveopts} \
    [list Name Value Plot Save {Save Options}] \
    {name 120 value 110 plot 50 save 50 saveopts 90}
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
proc ase::ui::build_pane {key top pane columns headings widths} {
  set pf $top.body.$pane
  ttk::treeview $pf.tv -columns $columns -show headings \
    -selectmode extended -height 8 -style Ase.Treeview \
    -yscrollcommand [list $pf.sb set]
  foreach c $columns h $headings {
    $pf.tv heading $c -text $h
    $pf.tv column $c -width [dict get $widths $c] -anchor w -stretch 1
  }
  scrollbar $pf.sb -orient vertical -command [list $pf.tv yview]
  pack $pf.sb -side right -fill y
  pack $pf.tv -side left -fill both -expand 1
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

# Analyses Arguments summary (view-only): the row's args in anaargs order as
# `key=value` joined by spaces, unknown extra keys appended in dict order;
# type/enabled excluded.
proc ase::ui::arg_summary {row} {
  variable anaargs
  set type [ase::state_get $row type]
  set order {}
  if {[dict exists $anaargs $type]} { set order [dict get $anaargs $type] }
  set out {}
  foreach a $order {
    if {[dict exists $row $a]} { lappend out "$a=[dict get $row $a]" }
  }
  dict for {k v} $row {
    if {$k eq {type} || $k eq {enabled}} { continue }
    if {[lsearch -exact $order $k] >= 0} { continue }
    lappend out "$k=$v"
  }
  return [join $out { }]
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
      [ase::ui::arg_summary $row]]
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
  set w [ase::ui::dialog_frame [dict get $wins $key].addvar {Add Variable}]
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
  set w [ase::ui::dialog_frame [dict get $wins $key].edout \
           [expr {$idx >= 0 ? {Edit Output} : {Add Output}}]]
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
# `balloon` (src/xschem.tcl:14917) is the tree's ONE tooltip mechanism and it
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
  $f.tv column mark -width 22 -anchor center -stretch 0
  $f.tv column result -width 320 -anchor w -stretch 1
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

# The dialog's quick fields per analysis type (spec "Choose Analyses
# dialog"; a subset of anaargs — `dec` for ac is render-hardwired and only
# reachable through the extra-options editor).
proc ase::ui::chana_fields {type} {
  switch -- $type {
    dc   { return {source start stop step} }
    ac   { return {points start stop} }
    tran { return {step stop} }
  }
  return {}
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
proc ase::ui::choose_analyses {key {type {}}} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return }
  set w [ase::ui::dialog_frame [dict get $wins $key].chana {Choose Analyses}]
  if {$type eq {}} { set type op }
  set dlg($key,antype) $type
  # top section: one radiobutton per analysis type; switching repopulates
  # the bottom form from state (D4: in-form edits of the previous type are
  # DISCARDED — deterministic, no hidden multi-type writes)
  frame $w.types
  foreach t {op dc ac tran} {
    radiobutton $w.types.$t -text $t -value $t \
      -variable ::ase::ui::dlg($key,antype) \
      -command [list ase::ui::chana_show $key]
    pack $w.types.$t -side left -padx 4
  }
  grid $w.types -row 0 -column 0 -columnspan 2 -sticky w -padx 8 -pady {8 4}
  checkbutton $w.enable -text Enable -variable ::ase::ui::dlg($key,anen)
  grid $w.enable -row 1 -column 0 -columnspan 2 -sticky w -padx 8 -pady 2
  # quick-field rows land on grid rows 2.. (chana_show); Options/buttons sit
  # on high fixed rows so the rebuilds never collide
  button $w.opts -text "Options…" -command [list ase::ui::chana_options $key]
  grid $w.opts -row 8 -column 0 -sticky w -padx 8 -pady 2
  ase::ui::dialog_buttons $w 9 [list ase::ui::chana_ok $key] \
    [list ase::ui::chana_cancel $key]
  ase::ui::chana_show $key
  return $w
}

# (Re)build the bottom per-analysis form from the session state for the
# currently selected type: Enable + one dialog_row per quick field at the
# deterministic paths $w.<field>.
proc ase::ui::chana_show {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,antype)]} { return }
  set w [dict get $wins $key].chana
  if {![winfo exists $w]} { return }
  set type $dlg($key,antype)
  foreach f {source start stop step points} {
    catch {destroy $w.$f}
    catch {destroy $w.l$f}
  }
  set row [ase::ui::chana_row $key $type]
  set dlg($key,anen) [expr {[ase::state_get $row enabled 0] eq {1} ? 1 : 0}]
  set r 2
  foreach f [ase::ui::chana_fields $type] {
    set e [ase::ui::dialog_row $w $r "[string totitle $f]:" $f]
    $e insert 0 [ase::state_get $row $f]
    bind $e <Return> [list ase::ui::chana_ok $key]
    incr r
  }
  ase::ui::apply_theme $w
}

# OK: D6 validation (an ENABLED analysis needs every quick field non-empty,
# else render_deck's `dict get` would blow up at run time — reject with the
# dialog kept up), then edit the FIRST state row of the shown type MERGED
# over its original dict (unknown/extra keys survive); an empty quick field
# deletes its key, no row of the type appends a fresh one.
proc ase::ui::chana_ok {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,antype)]} { return }
  set w [dict get $wins $key].chana
  if {![winfo exists $w]} { return }
  set type $dlg($key,antype)
  set en [expr {[info exists dlg($key,anen)] && $dlg($key,anen) ? 1 : 0}]
  set vals [dict create]
  foreach f [ase::ui::chana_fields $type] {
    if {[winfo exists $w.$f]} {
      dict set vals $f [string trim [$w.$f get]]
    }
  }
  if {$en} {
    foreach f [ase::ui::chana_fields $type] {
      if {![dict exists $vals $f] || [dict get $vals $f] eq {}} {
        catch {::ase::echo "ase: enabled $type analysis needs a non-empty '$f'" error}
        return
      }
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
    if {$v eq {}} { set row [dict remove $row $f] } \
    else          { dict set row $f $v }
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
# Arguments summary (arg_summary's unknown-key arm); DECK emission of extra
# keys stays deferred (v1 limit, documented here).
proc ase::ui::chana_options {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key] || ![info exists dlg($key,antype)]} { return }
  set w [dict get $wins $key].chana.x
  catch {destroy $w}
  toplevel $w
  set type $dlg($key,antype)
  wm title $w "Analysis Options ($type)"
  set row [ase::ui::chana_row $key $type]
  set skip [concat {type enabled} [ase::ui::chana_fields $type]]
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
  pack $w.btns.proceed -side left -padx 5
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
  set skip [concat {type enabled} [ase::ui::chana_fields $type]]
  foreach k [dict keys $row] {
    if {[lsearch -exact $skip $k] < 0} { set row [dict remove $row $k] }
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

# Simulation > Options…: minimal simulator-options dialog on the state's
# `options` rows {name value}. render_deck semantics of a row (ase.tcl):
# value 0 = skipped, value 1 = bare `.options name`, anything else =
# `.options name=value`.
proc ase::ui::sim_options_dialog {key} {
  return [ase::ui::listdlg_open $key simopt {Simulation Options}]
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
# route drives -- ase::sim_register / sim_unregister / sim_select / sim_list /
# sim_status / sim_entry_why -- and saves through ase::sim_write_conf. No
# validation, no path resolution and no persistence is re-implemented here; a
# second copy of any of them is how the two doors would start disagreeing.
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
  foreach c {name path problem} h {Name Program Problem} width {140 300 420} {
    $w.tv heading $c -text $h
    $w.tv column $c -width $width -anchor w -stretch 1
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
  set sel [ase::sim_selected]
  if {$sel eq {}} { set simuse($key) $none } else { set simuse($key) $sel }
  ase::ui::simdlg_status $key
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

# SAVE, THROUGH THE ONE WRITER. Not "also save": ase::sim_write_conf is the
# whole of what this dialog does about persistence, and it reports its own
# failure through ase::sim_say, which is what leaves a sentence for the
# gesture that called it to show. `key` is unused on purpose -- the registry
# is process-global -- and is carried so every gesture below reads the same.
proc ase::ui::simdlg_commit {key} {
  catch {ase::sim_write_conf}
  return
}

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

# The two-field row editor. An empty `name` is the Add flavor; anything else
# is Edit, and then the Name field is READ-ONLY -- a rename here would have to
# be a remove plus an add, which moves the entry to the end of the list and
# fires the "you removed X" sentence in the middle of what the user
# experienced as a rename.
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
  # the editor's OWN feedback surface: a refusal about what was just typed
  # belongs where the typing is, not only in the CIW behind the dialog. Empty
  # until there is something to say, so an untouched editor makes no claim.
  label $w.status -anchor w -justify left -wraplength 420 -text {}
  grid $w.status -row 2 -column 0 -columnspan 3 -sticky we -padx 8 -pady {4 0}
  if {$name ne {}} {
    $en insert 0 $name
    foreach e [ase::sim_list] {
      if {[dict get $e name] eq $name} { $ep insert 0 [dict get $e path] }
    }
    $en configure -state readonly
  }
  bind $en <Return> [list ase::ui::simdlg_ok $key]
  bind $ep <Return> [list ase::ui::simdlg_ok $key]
  ase::ui::dialog_buttons $w 3 [list ase::ui::simdlg_ok $key] \
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
# EVERYTHING THE DIALOG DOES NOT SHOW IS CARRIED THROUGH. An entry can also
# carry extra arguments and the backend it was registered for; they have no
# fields here, and an editor that rebuilt the entry from its two visible
# fields would silently delete them (row S9).
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
    foreach e [ase::sim_list] {
      if {[dict get $e name] ne $editing} { continue }
      set eargs [dict get $e args]
      set backend [dict get $e backend]
    }
  }
  ase::sim_said_clear
  if {[catch {ase::sim_register $name $path -args $eargs -backend $backend} err]} {
    $w.status configure -text [ase::ui::simdlg_plain $err]
    return
  }
  array unset dlg $key,simrow
  destroy $w
  ase::ui::simdlg_commit $key
  ase::ui::simdlg_fill $key
  set said [ase::sim_said]
  if {$said ne {}} { ase::ui::simdlg_status $key $said }
}

proc ase::ui::simdlg_cancel {key} {
  variable wins; variable dlg
  array unset dlg $key,simrow
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
  ase::ui::simdlg_commit $key
  ase::ui::simdlg_fill $key
  set said [ase::sim_said]
  if {$said ne {}} { ase::ui::simdlg_status $key $said }
}

# The in-force combobox. "None of mine" clears the choice, which is a choice
# like any other and is written down as one (issue 0932): without that, the
# next start puts the first entry back in force and the gesture is undone.
proc ase::ui::simdlg_use {key} {
  variable simuse
  set v {}
  if {[info exists simuse($key)]} { set v $simuse($key) }
  ase::sim_said_clear
  if {$v eq [ase::ui::simdlg_none_label]} { set v {} }
  if {[catch {ase::sim_select $v} err]} {
    ase::ui::simdlg_fill $key
    ase::ui::simdlg_status $key [ase::ui::simdlg_plain $err]
    return
  }
  ase::ui::simdlg_commit $key
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
  foreach c $cols h [dict get $cfg heads] {
    $w.tv heading $c -text $h
    $w.tv column $c -width 170 -anchor w -stretch 1
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
# until this line was added. `ase::ui::save_all_report_discard` (below, ~:3016)
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
# D13: overwriting a DIFFERENT existing view needs NO confirm in v1 — the
# spec's only confirm trigger is read-only + same-target.
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
  if {[ase::ui::save_as_needs_confirm $key $l $c $v]} {
    ase::ui::confirm $key {Overwrite State} \
      "The state $l/$c/$v was opened read-only.\nOverwrite it?" \
      [list ase::ui::do_save_state_as $key $l $c $v]
    return
  }
  ase::ui::do_save_state_as $key $l $c $v
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
#  - a DIFFERENT existing view -> plain state_save overwrite (D13).
# UNTITLED ADOPT (issue 0141): when this session was never saved (own eq {} —
# a Launch-ASE untitled session), the first successful Save-As ADOPTS the
# target as the session's real identity via ase::session_adopt (path set,
# saved<-state so dirty clears, `untitled` attr dropped) + meta view update, so
# the still-open window loses its "(unsaved)"/"*" cues and shows "State: <v>".
# This is gated on own eq {}, so a TITLED different-view save-as still stays
# dirty (D5/D13, deliberate) and the own-view save (first arm) is untouched.
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
proc ase::ui::refresh_status {key} {
  variable wins; variable wnum; variable meta
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  if {![winfo exists $top.status]} { return }
  set st [ase::session_state $key]
  lassign [dict get $meta $key] lib cell view
  $top.status.win   configure -text [dict get $wnum $key]
  $top.status.temp  configure -text "T=[ase::state_get $st temperature 27] C"
  $top.status.sim   configure -text "Simulator: [ase::state_get $st simulator]"
  $top.status.state configure -text "State: $view"
}

# The assembled status-bar line (tests + scripting):
# `<win#> | Status: <S> | T=<T> C | Simulator: <sim> | State: <view>`
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

# Simulation > Netlist and Run: re-netlist the design, then run.
proc ase::ui::do_run {key} {
  set dpath [ase::ui::design_path $key]
  if {$dpath eq {}} {
    catch {::ase::echo "ase: cannot resolve the session's design cellview" error}
    ase::ui::set_status $key fail
    return
  }
  # ase::netlist's GUI guard requires the design to BE the current schematic:
  # route through Design Window first when it is not. `ifhidden`, NOT the
  # default: this guard tests the xschem CONTEXT, not visibility, so it fires
  # routinely while the design window is fully visible and front (a restored
  # waveform viewer leaves the context on the viewer canvas -- the user's
  # reported case). The default arm would then withdraw+deiconify the whole main
  # toplevel for no reason, and on WSLg a dropped re-map is a schematic window
  # that simply vanished -- issue 0616, "when I press Netlist and Run, the
  # schematic window disappears". `ifhidden` still restores a design window that
  # really IS hidden, and still `raise`s a visible one to the front (the cheap
  # half of the raise -- see raise_window_entry), so the schematic ends up on
  # screen either way and no user is left hunting the Session menu.
  if {[file normalize [xschem get schname]] ne $dpath} {
    ase::ui::design_window $key ifhidden
    update
    if {[file normalize [xschem get schname]] ne $dpath} {
      catch {::ase::echo "ase: design is not the current schematic; open it via Session > Design Window first" error}
      ase::ui::set_status $key fail
      return
    }
  }
  if {[catch {ase::run [ase::session_state $key] [list ase::ui::run_finished $key]} id]} {
    catch {::ase::echo $id error}
    ase::ui::set_status $key fail
    return
  }
  ase::ui::run_started $key $id
}

# Simulation > Run: run on the EXISTING netlist artifact — never re-netlists
# (hand-edited decks survive), so it needs no current-schematic routing and
# works with the design window closed.
proc ase::ui::do_run_existing {key} {
  if {[catch {ase::run_existing [ase::session_state $key] [list ase::ui::run_finished $key]} id]} {
    catch {::ase::echo $id error}
    ase::ui::set_status $key fail
    return
  }
  ase::ui::run_started $key $id
}

# Stop the session's live run: kill through the execute pipe pid
# (`kill_running_cmds <id> <sig>` numeric branch). SIGKILL for a deterministic
# abort — close() then reports CHILDKILLED -> nonzero exitcode -> the normal
# completion path (run_finished) turns the status segment red. Unix only: the
# kill(1) path cannot work on Windows.
proc ase::ui::do_stop {key} {
  global OS
  set id [ase::session_getattr $key run_id {}]
  if {$id eq {} || ![string is integer -strict $id] || ![info exists ::execute(pipe,$id)]} {
    catch {::ase::echo "ase: no simulation running for this session"}
    return
  }
  if {[regexp -nocase {windows} $OS]} {
    catch {::ase::echo "ase: Stop is not available on Windows"}
    return
  }
  catch {kill_running_cmds $id -9}
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
