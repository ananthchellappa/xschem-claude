# ase_window.tcl — the ASE-L session window (items 03+05 of
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
# Editing model: the panes are plain entry/checkbutton grids populated from
# `ase::session_state`; every commit event (Return/FocusOut on an entry,
# checkbox toggle, combobox selection) HARVESTS the widgets back into a state
# dict and calls `ase::session_update` — the one write path. Harvest merges
# each row's fields over the row's ORIGINAL dict (rowbase), so keys the
# widgets do not show (e.g. an output's `plot`) and absent optional args are
# preserved byte-for-byte: an untouched pane can never dirty the session.
# The `ase::session_notify` hook only refreshes the TITLE + status bar
# (repopulating panes from inside a FocusOut-driven commit would destroy the
# widget mid-event); Load State / Revert repopulate explicitly.
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
  # rowbase(key,pane,i): the row's original dict (harvest merges over it);
  # rowchk(key,pane,i): checkbutton var; lastrow(key,pane): last-focused row;
  # anaen(key,type): per-analysis enabled checkbutton var
  variable rowbase; array set rowbase {}
  variable rowchk;  array set rowchk {}
  variable lastrow; array set lastrow {}
  variable anaen;   array set anaen {}
  # analysis arg fields per type (the spec's v1 schema)
  variable anaargs [dict create op {} dc {source start stop step} \
                                ac {points start stop dec} tran {step stop}]
  # list panes: state key -> {frame-name field-list}; `save` is a checkbutton
  variable panes [dict create \
    variables {vars {name value}} \
    outputs   {outs {name expr save}} \
    models    {mods {file section}} \
    options   {opts {name value}}]
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
  variable loglen; variable rowbase; variable rowchk; variable lastrow
  variable anaen
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
  array unset rowbase $key,*
  array unset rowchk $key,*
  array unset lastrow $key,*
  array unset anaen $key,*
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
  # TODO(item06): variables editor dialog
  $top.mb.variables add command -label "Edit\u2026" \
    -command [list ase::ui::todo_stub {Edit Variables} 06]

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

  # 2x3 grid of panes (v1 layout — the ADE 3-pane rework is item 06)
  frame $top.body
  labelframe $top.body.vars  -text {Design Variables}
  labelframe $top.body.ana   -text {Analyses}
  labelframe $top.body.outs  -text {Outputs}
  labelframe $top.body.mods  -text {Model libs}
  labelframe $top.body.opts  -text {Options}
  labelframe $top.body.setup -text {Setup}
  grid $top.body.vars $top.body.ana   -sticky nsew -padx 2 -pady 2
  grid $top.body.outs $top.body.mods  -sticky nsew -padx 2 -pady 2
  grid $top.body.opts $top.body.setup -sticky nsew -padx 2 -pady 2
  grid columnconfigure $top.body 0 -weight 1
  grid columnconfigure $top.body 1 -weight 1
  foreach skey {variables outputs models options} {
    ase::ui::build_list_pane $key $top $skey
  }
  ase::ui::build_ana_pane $key $top
  ase::ui::build_setup_pane $key $top
  pack $top.body -side top -fill both -expand 1

  ase::ui::apply_theme $top
  # captured AFTER theming so "idle" restores the themed panel color
  variable idlebg
  set idlebg($key) [$top.status.stat cget -background]
}

proc ase::ui::build_list_pane {key top skey} {
  variable panes
  lassign [dict get $panes $skey] fname fields
  set pane $top.body.$fname
  frame $pane.rows
  pack $pane.rows -side top -fill both -expand 1 -anchor w
  frame $pane.btns
  button $pane.btns.add -text + -width 2 -command [list ase::ui::row_add $key $skey]
  button $pane.btns.del -text - -width 2 -command [list ase::ui::row_del $key $skey]
  pack $pane.btns.add $pane.btns.del -side left -padx 1
  pack $pane.btns -side bottom -anchor w
}

proc ase::ui::build_ana_pane {key top} {
  variable anaargs
  set pane $top.body.ana
  foreach type {op dc ac tran} {
    set f [frame $pane.$type]
    checkbutton $f.en -text $type -width 5 -anchor w \
      -variable ::ase::ui::anaen($key,$type) -command [list ase::ui::commit $key]
    pack $f.en -side left
    foreach arg [dict get $anaargs $type] {
      label $f.l$arg -text $arg
      entry $f.$arg -width 7
      bind $f.$arg <Return>   [list ase::ui::commit $key]
      bind $f.$arg <FocusOut> [list ase::ui::commit $key]
      pack $f.l$arg $f.$arg -side left -padx 1
    }
    pack $f -side top -anchor w
  }
}

proc ase::ui::build_setup_pane {key top} {
  set pane $top.body.setup
  label $pane.rl -text {Run dir:}
  entry $pane.rundir -width 30
  bind $pane.rundir <Return>   [list ase::ui::commit $key]
  bind $pane.rundir <FocusOut> [list ase::ui::commit $key]
  label $pane.sl -text {Simulator:}
  ttk::combobox $pane.sim -values [ase::backend_names] -state readonly -width 12
  bind $pane.sim <<ComboboxSelected>> [list ase::ui::commit $key]
  grid $pane.rl $pane.rundir -sticky w -padx 2 -pady 2
  grid $pane.sl $pane.sim    -sticky w -padx 2 -pady 2
}

# --- rows (list panes) -------------------------------------------------------

# Numeric row indices present under a .rows frame, sorted (deleting a middle
# row leaves gaps, so never assume contiguity).
proc ase::ui::row_indices {rows} {
  set idx {}
  foreach c [winfo children $rows] {
    if {[regexp {\.r([0-9]+)$} $c -> n]} { lappend idx $n }
  }
  return [lsort -integer $idx]
}

proc ase::ui::row_build {key skey i row} {
  variable wins; variable panes; variable rowbase; variable rowchk
  set top [dict get $wins $key]
  lassign [dict get $panes $skey] fname fields
  set f [frame $top.body.$fname.rows.r$i]
  set rowbase($key,$skey,$i) $row
  foreach fld $fields {
    if {$fld eq {save}} {
      set rowchk($key,$skey,$i) [expr {[ase::state_get $row save 0] eq {1} ? 1 : 0}]
      checkbutton $f.$fld -text save -variable ::ase::ui::rowchk($key,$skey,$i) \
        -command [list ase::ui::commit $key]
    } else {
      entry $f.$fld -width 13
      $f.$fld insert 0 [ase::state_get $row $fld]
      bind $f.$fld <Return>   [list ase::ui::commit $key]
      bind $f.$fld <FocusOut> [list ase::ui::commit $key]
      bind $f.$fld <FocusIn>  [list set ::ase::ui::lastrow($key,$skey) $i]
    }
    pack $f.$fld -side left -padx 1
  }
  pack $f -side top -anchor w
}

# Append an empty row. Harvest skips all-empty fresh rows, so adding one does
# not dirty the state until it is filled in.
proc ase::ui::row_add {key skey} {
  variable wins; variable panes
  set top [dict get $wins $key]
  lassign [dict get $panes $skey] fname fields
  set rows $top.body.$fname.rows
  set i 0
  while {[winfo exists $rows.r$i]} { incr i }
  ase::ui::row_build $key $skey $i {}
  ase::ui::apply_theme $rows.r$i
}

# Delete the last-focused row of the pane (or the last row when none was
# focused yet), then commit the shrunken list.
proc ase::ui::row_del {key skey} {
  variable wins; variable panes; variable lastrow; variable rowbase; variable rowchk
  set top [dict get $wins $key]
  lassign [dict get $panes $skey] fname fields
  set rows $top.body.$fname.rows
  set target -1
  if {[info exists lastrow($key,$skey)]} {
    set t $lastrow($key,$skey)
    if {[winfo exists $rows.r$t]} { set target $t }
  }
  if {$target < 0} { set target [lindex [ase::ui::row_indices $rows] end] }
  if {$target eq {} || $target < 0} { return }
  destroy $rows.r$target
  catch {unset rowbase($key,$skey,$target)}
  catch {unset rowchk($key,$skey,$target)}
  catch {unset lastrow($key,$skey)}
  ase::ui::commit $key
}

# The value-entry widget of the named design variable ({} if absent) — used by
# the tests and handy for scripting.
proc ase::ui::variable_entry {key name} {
  variable wins
  if {![dict exists $wins $key]} { return {} }
  set rows [dict get $wins $key].body.vars.rows
  foreach i [ase::ui::row_indices $rows] {
    if {[$rows.r$i.name get] eq $name} { return $rows.r$i.value }
  }
  return {}
}

# --- populate / harvest ------------------------------------------------------

proc ase::ui::populate_list_pane {key skey} {
  variable wins; variable panes; variable rowbase; variable rowchk; variable lastrow
  set top [dict get $wins $key]
  lassign [dict get $panes $skey] fname fields
  set rows $top.body.$fname.rows
  foreach c [winfo children $rows] { destroy $c }
  array unset rowbase $key,$skey,*
  array unset rowchk $key,$skey,*
  catch {unset lastrow($key,$skey)}
  set i 0
  foreach row [ase::state_get [ase::session_state $key] $skey] {
    ase::ui::row_build $key $skey $i $row
    incr i
  }
}

proc ase::ui::harvest_list_pane {key skey} {
  variable wins; variable panes; variable rowbase; variable rowchk
  set top [dict get $wins $key]
  lassign [dict get $panes $skey] fname fields
  set rows $top.body.$fname.rows
  set out {}
  foreach i [ase::ui::row_indices $rows] {
    set base {}
    if {[info exists rowbase($key,$skey,$i)]} { set base $rowbase($key,$skey,$i) }
    set row $base
    set allempty 1
    foreach fld $fields {
      if {$fld eq {save}} {
        set v [expr {[info exists rowchk($key,$skey,$i)] && $rowchk($key,$skey,$i) ? 1 : 0}]
        # include only when set or previously present: an untouched row must
        # serialize identically to its original
        if {$v || [dict exists $base save]} { dict set row save $v }
      } else {
        set v [$rows.r$i.$fld get]
        if {$v ne {}} { set allempty 0 }
        if {$v ne {} || [dict exists $base $fld]} { dict set row $fld $v }
      }
    }
    if {$allempty && $base eq {}} { continue }   ;# fresh, still-empty row
    lappend out $row
  }
  return $out
}

proc ase::ui::populate_ana {key} {
  variable wins; variable anaargs; variable anaen; variable rowbase
  set top [dict get $wins $key]
  set pane $top.body.ana
  # stash each type's original dict; unknown-type/duplicate entries are
  # preserved verbatim and re-appended by harvest_ana
  set extras {}
  foreach type {op dc ac tran} { set seen($type) 0 }
  foreach a [ase::state_get [ase::session_state $key] analyses] {
    set t [ase::state_get $a type]
    if {[lsearch -exact {op dc ac tran} $t] >= 0 && !$seen($t)} {
      set rowbase($key,ana,$t) $a
      set seen($t) 1
    } else {
      lappend extras $a
    }
  }
  set rowbase($key,ana,extra) $extras
  foreach type {op dc ac tran} {
    if {![info exists rowbase($key,ana,$type)] || !$seen($type)} {
      set rowbase($key,ana,$type) [list type $type enabled 0]
    }
    set a $rowbase($key,ana,$type)
    set anaen($key,$type) [expr {[ase::state_get $a enabled 0] eq {1} ? 1 : 0}]
    foreach arg [dict get $anaargs $type] {
      $pane.$type.$arg delete 0 end
      $pane.$type.$arg insert 0 [ase::state_get $a $arg]
    }
  }
}

proc ase::ui::harvest_ana {key} {
  variable wins; variable anaargs; variable anaen; variable rowbase
  set top [dict get $wins $key]
  set pane $top.body.ana
  set out {}
  foreach type {op dc ac tran} {
    set base [list type $type enabled 0]
    if {[info exists rowbase($key,ana,$type)]} { set base $rowbase($key,ana,$type) }
    set a $base
    dict set a type $type
    dict set a enabled [expr {[info exists anaen($key,$type)] && $anaen($key,$type) ? 1 : 0}]
    foreach arg [dict get $anaargs $type] {
      set v [$pane.$type.$arg get]
      if {$v ne {} || [dict exists $base $arg]} { dict set a $arg $v }
    }
    lappend out $a
  }
  if {[info exists rowbase($key,ana,extra)]} {
    foreach a $rowbase($key,ana,extra) { lappend out $a }
  }
  return $out
}

proc ase::ui::populate {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  set top [dict get $wins $key]
  if {![winfo exists $top]} { return }
  foreach skey {variables outputs models options} {
    ase::ui::populate_list_pane $key $skey
  }
  ase::ui::populate_ana $key
  set st [ase::session_state $key]
  $top.body.setup.rundir delete 0 end
  $top.body.setup.rundir insert 0 [ase::state_get $st rundir]
  catch {$top.body.setup.sim set [ase::state_get $st simulator]}
  $top.tb.temp delete 0 end
  $top.tb.temp insert 0 [ase::state_get $st temperature 27]
  ase::ui::refresh_title $key
  ase::ui::refresh_status $key
  ase::ui::apply_theme $top
}

# Widgets -> state dict, merged over the current session state so keys no pane
# shows (version/design/includes, unknown keys) ride through untouched.
proc ase::ui::harvest {key} {
  variable wins
  set top [dict get $wins $key]
  set st [ase::session_state $key]
  foreach skey {variables outputs models options} {
    dict set st $skey [ase::ui::harvest_list_pane $key $skey]
  }
  dict set st analyses [ase::ui::harvest_ana $key]
  dict set st rundir [$top.body.setup.rundir get]
  set sim [$top.body.setup.sim get]
  if {$sim ne {}} { dict set st simulator $sim }
  # temperature: only a valid number may enter the state — a commit fired
  # from another pane must never harvest a half-typed toolbar value
  # (temp_commit restores + reports garbage on the entry's own commit)
  set T [string trim [$top.tb.temp get]]
  if {[string is double -strict $T]} { dict set st temperature $T }
  return $st
}

# The ONE write path of every pane edit event.
proc ase::ui::commit {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  if {![winfo exists [dict get $wins $key]]} { return }
  ase::session_update $key [ase::ui::harvest $key]
}

# Return/FocusOut on the toolbar temperature entry: numeric -> normal commit;
# garbage -> restore the entry from the state + report, state untouched.
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
  ase::ui::commit $key
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
  if {$ec == 0} { ase::ui::set_status $key ok } else { ase::ui::set_status $key fail }
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
