# ase_window.tcl — the ASE-L session window (items 03+05+06 of
# doc/claude/ase_l_batch, spec doc/claude/specs/ase_l.md — UI v2 "ADE-L
# parity rework" is the authoritative chrome contract): ALL Tk widget code of
# the ASE-L feature. ase.tcl (the headless core + session model) stays
# Tk-free; its has_x-guarded `ase::open_state` is the ONE seam that reaches
# into this file.
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
}

# --- theme (UI v2 "Window chrome": USER-LOCKED palette + named fonts) --------

# The central ASE look: named fonts (created once — the
# references/copy_current_cell_dialog.tcl idiom), the combobox listbox font +
# white-field style, and the locked palette: panels #f2f2f2, tables/entries
# white, header strips #e8e8e8, dark-red pane-title accent. Returns the whole
# palette dict, or one color when `name` is given.
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
  catch {ttk::style configure Ase.TCombobox -fieldbackground #ffffff}
  # pane tables (UI v2): white rows in the entry font, the USER-LOCKED
  # header-strip color on the column headings
  catch {
    ttk::style configure Ase.Treeview -font AseEntryFont \
      -background #ffffff -fieldbackground #ffffff \
      -rowheight [expr {[font metrics AseEntryFont -linespace] + 4}]
    ttk::style configure Ase.Treeview.Heading -font AseLabelFont \
      -background #e8e8e8
  }
  set pal [dict create panel #f2f2f2 table #ffffff header #e8e8e8 \
                       accent #8b0000]
  if {$name ne {}} { return [dict get $pal $name] }
  return $pal
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
  wm protocol $top WM_DELETE_WINDOW [list ase::ui::close $key]
  ase::ui::build $key $top
  ase::ui::populate $key
  return $top
}

# Session > Close / WM close: drop trace bookkeeping, unregister the session
# (v1 contract: close DISCARDS unsaved edits — a ciw_echo notice, no modal
# save-nag), destroy the toplevel and every per-key record. The log toplevel
# is a child of the session toplevel, so it dies with it.
proc ase::ui::close {key} {
  variable wins; variable wnum; variable meta; variable idlebg
  variable loglen; variable selclear; variable edrow; variable edchk
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  ase::ui::drop_trace $key
  if {[ase::session_dirty $key]} {
    catch {ciw_echo "ase: closed $key with unsaved state edits (discarded)"}
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
  catch {destroy $top}
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
  # TODO(item07): Load State grows the state-view library browser and Save
  # State the Save-As form; until then both wire to the existing working
  # procs (stubbing them would regress working save/load for an item-cycle).
  $top.mb.session add command -label {Load State} \
    -command [list ase::ui::load_state $key]
  $top.mb.session add command -label {Save State} \
    -command [list ase::ui::save_state $key]
  $top.mb.session add separator
  $top.mb.session add command -label Close -command [list ase::ui::close $key]

  menu $top.mb.setup -tearoff 0
  $top.mb add cascade -label Setup -menu $top.mb.setup
  # TODO(item07): Design L/C/V dialog + Model Files dialog
  $top.mb.setup add command -label "Design\u2026" \
    -command [list ase::ui::todo_stub {Setup Design} 07]
  $top.mb.setup add command -label "Model Files\u2026" \
    -command [list ase::ui::todo_stub {Model Files} 07]

  menu $top.mb.analyses -tearoff 0
  $top.mb add cascade -label Analyses -menu $top.mb.analyses
  # TODO(item07): Choose Analyses dialog
  $top.mb.analyses add command -label "Choose\u2026" \
    -command [list ase::ui::todo_stub {Choose Analyses} 07]

  menu $top.mb.variables -tearoff 0
  $top.mb add cascade -label Variables -menu $top.mb.variables
  # Variables > Edit...: the per-row variable editor on the first selected
  # variables row, or the Add Variable dialog when nothing is selected (the
  # minimal honest reading of the spec's "variables editor" within item 06)
  $top.mb.variables add command -label "Edit\u2026" \
    -command [list ase::ui::edit_variables $key]

  menu $top.mb.outputs -tearoff 0
  $top.mb add cascade -label Outputs -menu $top.mb.outputs
  menu $top.mb.outputs.saved -tearoff 0
  # TODO(item08): Select On Design command mode (click wires/terminals)
  $top.mb.outputs.saved add command -label {Select On Design} \
    -command [list ase::ui::todo_stub {Outputs To Be Saved} 08]
  $top.mb.outputs add cascade -label {To Be Saved} -menu $top.mb.outputs.saved
  menu $top.mb.outputs.plotted -tearoff 0
  $top.mb.outputs.plotted add command -label {Select On Design} \
    -command [list ase::ui::todo_stub {Outputs To Be Plotted} 08]
  $top.mb.outputs add cascade -label {To Be Plotted} \
    -menu $top.mb.outputs.plotted
  # TODO(item07): Save All dialog (allv/alli)
  $top.mb.outputs add command -label "Save All\u2026" \
    -command [list ase::ui::todo_stub {Save All} 07]

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
  # TODO(item07): simulator-specific options dialog
  $top.mb.sim add command -label "Options\u2026" \
    -command [list ase::ui::todo_stub {Simulator Options} 07]

  # Results: deferred — the cascade posts, its entries are disabled (spec:
  # "Menu entries may exist disabled")
  menu $top.mb.results -tearoff 0
  $top.mb add cascade -label Results -menu $top.mb.results
  $top.mb.results add command -label {Direct Plot} -state disabled
  menu $top.mb.results.annotate -tearoff 0
  $top.mb.results.annotate add command -label {Operating Point info} \
    -state disabled
  $top.mb.results.annotate add command -label {DC Node Voltages} \
    -state disabled
  $top.mb.results add cascade -label Annotate -menu $top.mb.results.annotate

  # Tools: deferred entirely -> disabled menubar entry
  menu $top.mb.tools -tearoff 0
  $top.mb.tools add command -label {(deferred)} -state disabled
  $top.mb add cascade -label Tools -menu $top.mb.tools -state disabled

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
  # top-down in spec order; ~ (Plot waveforms) is a disabled placeholder.
  # Packed AFTER the toolbar + status bar and BEFORE the expanding body (the
  # item-05 packing lesson: the expanding widget must be packed last).
  frame $top.strip
  button $top.strip.ana -text {OP,TR} -width 5 \
    -command [list ase::ui::todo_stub {Choose Analyses} 07]
  button $top.strip.var -text = -width 5 \
    -command [list ase::ui::add_variable_dialog $key]
  button $top.strip.out -text --> -width 5 \
    -command [list ase::ui::todo_stub {Setup Outputs} 07]
  button $top.strip.del -text X -width 5 \
    -command [list ase::ui::delete_selection $key]
  button $top.strip.netrun -text {N&>} -width 5 \
    -command [list ase::ui::do_run $key]
  button $top.strip.run -text > -width 5 \
    -command [list ase::ui::do_run_existing $key]
  button $top.strip.stop -text ! -width 5 \
    -command [list ase::ui::do_stop $key]
  button $top.strip.plot -text ~ -width 5 -state disabled
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
      # TODO(item07): route to Choose Analyses with the row preselected
      $pf.ctx add command -label "Add\u2026" \
        -command [list ase::ui::todo_stub {Choose Analyses} 07]
      $pf.ctx add command -label "Edit\u2026" \
        -command [list ase::ui::todo_stub {Choose Analyses} 07]
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
# model). Analyses rows route to Choose Analyses — TODO(item07): preselect
# the double-clicked analysis when that dialog lands.
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
    ana  { ase::ui::todo_stub {Choose Analyses} 07 }
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
  catch {ciw_echo "ase: nothing selected"}
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
      [list [ase::state_get $row name] [ase::state_get $row value]]
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
      [list [ase::ui::output_display_name $row] $val \
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
    catch {$tv set $i value $val}
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
    catch {ciw_echo "ase: temperature must be numeric" error}
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
    catch {ciw_echo "ase: variable name must not be empty" error}
    return
  }
  set st [ase::session_state $key]
  set rows [ase::state_get $st variables]
  foreach v $rows {
    if {[ase::state_get $v name] eq $name} {
      catch {ciw_echo "ase: variable '$name' already exists" error}
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
    catch {ciw_echo "ase: variable name must not be empty" error}
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
    catch {ciw_echo "ase: output expression must not be empty" error}
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

# Context Edit… on the variables pane: editor on the FIRST selected row.
proc ase::ui::edit_variable_first {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set tv [dict get $wins $key].body.vars.tv
  set sel {}
  if {[winfo exists $tv]} { set sel [$tv selection] }
  if {$sel eq {}} {
    catch {ciw_echo "ase: nothing selected"}
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
    catch {ciw_echo "ase: nothing selected"}
    return
  }
  ase::ui::output_editor $key [lindex $sel 0]
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
}

# --- Session menu ------------------------------------------------------------

proc ase::ui::save_state {key} {
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

# Menu entries whose real dialog lands in a later batch item: honest
# one-line notice instead of a dead click.
proc ase::ui::todo_stub {what item} {
  catch {ciw_echo "ase: '$what' dialog lands in item $item"}
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
proc ase::ui::raise_design_editor {dpath} {
  foreach e [xschem windows] {
    if {[file normalize [lindex $e 4]] eq $dpath} {
      xschem new_schematic switch [lindex $e 0]
      set tp [lindex $e 1]
      if {$tp eq {}} { set tp . }
      raise_activate_toplevel $tp
      catch {focus $tp}
      return 1
    }
  }
  return 0
}

# Session > Design Window: raise the editor window already holding the design,
# else open it via the libmgr::open_view `-gui` load precedent (gated action
# log + deferred WSLg repaint) AND raise the window the load landed in — the
# v1 bug was loading into a stacked-under main window and never raising it,
# so nothing visibly happened. Returns 1 on success, 0 when the design does
# not resolve.
proc ase::ui::design_window {key} {
  set dpath [ase::ui::design_path $key]
  if {$dpath eq {}} {
    catch {ciw_echo "ase: cannot resolve the session's design cellview" error}
    return 0
  }
  if {[ase::ui::raise_design_editor $dpath]} { return 1 }
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
    catch {ciw_echo $err error}
    return
  }
  if {[file isfile $f]} {
    # ::open — inside ase::ui a bare `open` resolves to ase::ui::open
    set fh [::open $f r]
    set data [read $fh]
    close $fh
    ase::ui::log_append $key $data
  } else {
    catch {ciw_echo "ase: no simulation log yet: $f"}
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
# report via ciw_echo — no viewer (that is Display's job).
proc ase::ui::do_netlist_recreate {key} {
  if {[catch {ase::netlist [ase::session_state $key]} nl]} {
    catch {ciw_echo $nl error}
    return
  }
  catch {ciw_echo "ase: netlist written: $nl"}
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
  set ec -1
  if {[info exists ::execute(exitcode,last)]} { set ec $::execute(exitcode,last) }
  if {$ec == 0} {
    # UI v2 Value column: per-SESSION results (a global last_result would
    # bleed session A's numbers into session B); display-only, never
    # serialized to the state file
    ase::session_setattr $key results [ase::last_result]
    ase::ui::refresh_output_values $key
    ase::ui::set_status $key ok
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
    catch {ciw_echo "ase: cannot resolve the session's design cellview" error}
    ase::ui::set_status $key fail
    return
  }
  # ase::netlist's GUI guard requires the design to BE the current schematic:
  # route through Design Window first when it is not
  if {[file normalize [xschem get schname]] ne $dpath} {
    ase::ui::design_window $key
    update
    if {[file normalize [xschem get schname]] ne $dpath} {
      catch {ciw_echo "ase: design is not the current schematic; open it via Session > Design Window first" error}
      ase::ui::set_status $key fail
      return
    }
  }
  if {[catch {ase::run [ase::session_state $key] [list ase::ui::run_finished $key]} id]} {
    catch {ciw_echo $id error}
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
    catch {ciw_echo $id error}
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
    catch {ciw_echo "ase: no simulation running for this session"}
    return
  }
  if {[regexp -nocase {windows} $OS]} {
    catch {ciw_echo "ase: Stop is not available on Windows"}
    return
  }
  catch {kill_running_cmds $id -9}
}

# Simulation > Netlist > Display: the circuit netlist artifact in a read-only
# textwindow (shared infra — deliberately NOT ASE-themed).
proc ase::ui::view_netlist {key} {
  set st [ase::session_state $key]
  if {[catch {dict get $st design cell} cell]} {
    catch {ciw_echo "ase: state has no design cell" error}
    return
  }
  set f [file join [ase::rundir $st] $cell.spice]
  if {[file isfile $f]} { textwindow $f ro } \
  else { catch {ciw_echo "ase: no netlist yet: $f"} }
}
