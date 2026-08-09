# Alt-2 "toggle the view type (schematic <-> symbol) in the same window".
# Sourced unconditionally from xschem.tcl (next to library_defs.tcl) so the default
# key binding view.toggle_view_type works with the stock keymap, independent of
# cadence_style_rc. Pure Tcl over existing xschem subcommands -- the only C change is
# the keybinding scaffolding (an ActionDef row + a default InputBinding).
# See doc/claude/specs/alt2_toggle_view.md.
#
# Behavior: current schematic-type view -> open the cell's symbol view (and vice
# versa), in the SAME window (save-prompt if modified). Multiple views of the target
# type -> a drop-down chooser (default = the canonically-named symbol/schematic view).
# If another window already shows the target view -> activate that window. First open
# of a view this session is read-only; a view already seen in edit mode opens editable.

namespace eval alt2 {
  variable edited        ;# session set: edited(<normalized datafile path>) = 1
  array set edited {}
  variable dlg_done
}

# ---- pure helpers --------------------------------------------------------
# Target extension: the OTHER type from the current file. Still the sch<->sym
# binary — with four view types "the other one" stops being well-defined, so
# this now serves only as the chooser's DEFAULT preference and the wording of
# the nothing-to-toggle message. The candidate SET comes from
# alt2::toggle_types below.
proc alt2::other_ext {curpath} {
  return [expr {[string match {*.sym} $curpath] ? ".sch" : ".sym"}]
}

# The view types Alt-2 toggles between. Deliberately NOT "every type":
#   in  schematic symbol   the canvas pair this feature was built for
#   in  verilog veriloga   a cell whose implementation IS source code — the
#                          case with no schematic to descend into, so toggling
#                          to it is the only way to reach it from the canvas
#   out state              has its own window (ase::open_state), reached from
#                          the Library Manager; Alt-2 never offered it and
#                          silently widening into it would be a surprise
#   out data               unknown extension, no opener we can promise
proc alt2::toggle_types {} { return {schematic symbol verilog veriloga} }

# The view type of a datafile path, via the one table in library_defs.tcl.
proc alt2::path_type {path} { return [view_type_of_ext [file extension $path]] }

# Canonically-named view for an extension (the chooser's default selection).
proc alt2::default_view {ext} {
  return [expr {$ext eq ".sym" ? "symbol" : "schematic"}]
}

# From an `xschem windows` list, the win_path (other than $curwin) already showing
# $targetpath, else "". Each row is {win_path top_path group xwindow current_name number}.
proc alt2::find_window_for {targetpath curwin windowslist} {
  set t [file normalize $targetpath]
  foreach w $windowslist {
    if {[lindex $w 0] eq $curwin} continue
    set cn [lindex $w 4]
    if {$cn ne "" && [file normalize $cn] eq $t} { return [lindex $w 0] }
  }
  return {}
}

# ---- registry-backed resolution (needs the running engine) ---------------
# View names of <lib>/<cell> whose datafile matches $ext (".sym" / ".sch"), sorted.
proc alt2::views_of_ext {lib cell ext} {
  set out {}
  foreach v [xschem cell_views $lib $cell] {
    if {[string match *$ext [xschem cellview_path "$lib/$cell" $v]]} { lappend out $v }
  }
  return [lsort $out]
}

# Views of <lib>/<cell> whose datafile is of type $type, sorted.
proc alt2::views_of_type {lib cell type} {
  set out {}
  foreach v [xschem cell_views $lib $cell] {
    set p [xschem cellview_path "$lib/$cell" $v]
    if {$p ne {} && [alt2::path_type $p] eq $type} { lappend out $v }
  }
  return [lsort $out]
}

# Candidate target views for toggling away from $curpath -> list of
# {view abspath type}.
#
# Registered cell: every view of the cell whose type is in alt2::toggle_types
# and differs from the current view's type. With only schematic/symbol views on
# disk that is exactly the old other-ext answer; a `verilog` view now joins the
# list instead of being invisible. Ordering puts the classic other-ext type
# first so the chooser's default selection stays the top entry.
#
# Flat/unregistered: the same-dir sibling of the other type (empty view name),
# plus a same-rootname source sibling if one is lying there (upstream's loose
# `counter.v` convention, §B8), or {} if neither exists.
proc alt2::target_candidates {curpath} {
  set curtype [alt2::path_type $curpath]
  set ext [alt2::other_ext $curpath]
  set cv [schematic_cellview [file normalize $curpath]]
  if {$cv ne {}} {
    lassign $cv lib cell
    # classic partner type first, then the rest, so the default stays on top
    set order [list [view_type_of_ext $ext]]
    foreach t [alt2::toggle_types] { if {[lsearch -exact $order $t] < 0} { lappend order $t } }
    set out {}
    foreach t $order {
      if {$t eq $curtype} continue
      set vs [alt2::views_of_type $lib $cell $t]
      if {[llength $vs]} {
        foreach v $vs {
          lappend out [list $v [file normalize [xschem cellview_path "$lib/$cell" $v]] $t]
        }
      } elseif {[view_type_opener $t] eq {text}} {
        # A registered library can still be FLAT, and cell_views only knows
        # <cell>.sym / <cell>.sch there — so a loose <cell>.v beside the symbol
        # (upstream's own convention, §B8) enumerates as no view at all. Probe
        # for it directly; cellview_sibling_path already knows both layouts.
        set p [cellview_sibling_path "$lib/$cell" $t]
        if {$p ne {}} { lappend out [list {} [file normalize $p] $t] }
      }
    }
    return $out
  }
  set out {}
  set sib [file rootname $curpath]$ext
  if {[file exists $sib]} {
    lappend out [list {} [file normalize $sib] [view_type_of_ext $ext]]
  }
  foreach t [alt2::toggle_types] {
    if {$t eq $curtype || $t eq [view_type_of_ext $ext]} continue
    foreach e [view_exts_of_type $t] {
      set s [file rootname $curpath]$e
      if {[file isfile $s]} { lappend out [list {} [file normalize $s] $t]; break }
    }
  }
  return $out
}

# Human label for a datafile path (lib/cell/view when registered, else basename).
proc alt2::label {path view} {
  set cv [schematic_cellview [file normalize $path]]
  if {$cv ne {}} {
    lassign $cv lib cell v
    return "$lib/$cell/[expr {$view ne {} ? $view : $v}]"
  }
  return [file tail $path]
}

proc alt2::mark_edited {path} {
  variable edited
  if {$path ne ""} { set edited([file normalize $path]) 1 }
}

# ---- GUI bits (guarded so headless degrades gracefully) ------------------
# Modal drop-down chooser. Returns the chosen view, or "" on cancel. Mirrors
# libmgr::newview_dialog. Headless (no Tk) picks the default silently.
proc alt2::choose_dialog {views default} {
  variable dlg_done
  if {![llength [info commands winfo]]} {
    return [expr {[lsearch -exact $views $default] >= 0 ? $default : [lindex $views 0]}]
  }
  set d .alt2choose
  catch {destroy $d}
  toplevel $d
  wm title $d "Open which view"
  catch {wm transient $d .}
  ttk::label $d.l -text "Open which view:"
  ttk::combobox $d.v -state readonly -values $views
  if {[lsearch -exact $views $default] >= 0} { $d.v set $default } else { $d.v set [lindex $views 0] }
  ttk::frame $d.b
  ttk::button $d.b.ok     -text OK     -command {set alt2::dlg_done 1}
  ttk::button $d.b.cancel -text Cancel -command {set alt2::dlg_done 0}
  pack $d.l $d.v -padx 8 -pady 4
  pack $d.b -pady 4
  pack $d.b.ok $d.b.cancel -side left -padx 4
  bind $d <Return> {set alt2::dlg_done 1}
  bind $d <Escape> {set alt2::dlg_done 0}
  set dlg_done -1
  catch {grab $d}; focus $d.v
  vwait alt2::dlg_done
  set res [expr {$dlg_done == 1 ? [$d.v get] : ""}]
  catch {destroy $d}
  return $res
}

# Bring an already-open window/tab to the front. For a tab it is a context switch;
# for a detached toplevel also raise+activate it (WSLg-aware helper).
proc alt2::activate {win_path top_path} {
  catch { xschem new_schematic switch $win_path }
  if {$top_path ne "." && [llength [info commands winfo]] && [winfo exists $top_path]} {
    catch { raise_activate_toplevel $top_path }
  }
}

# ---- the action entry point (global proc named by view.toggle_view_type) --
proc alt2_toggle_view {} {
  set cur [xschem get schname]
  if {$cur eq "" || [string match {*untitled.sch} $cur]} {
    ciw_echo "toggle view: open a real schematic or symbol first"
    return
  }
  # remember an editable current view before leaving it (so toggling back re-opens edit)
  if {![xschem get readonly]} { alt2::mark_edited $cur }

  set cands [alt2::target_candidates $cur]
  if {![llength $cands]} {
    set what [expr {[string match {*.sym} $cur] ? "schematic" : "symbol"}]
    ciw_echo "no $what view for [file tail [file rootname $cur]]" error
    return
  }
  if {[llength $cands] == 1} {
    lassign [lindex $cands 0] cview cpath ctype
  } else {
    set ext [alt2::other_ext $cur]
    set views {}
    foreach c $cands { lappend views [lindex $c 0] }
    set chosen [alt2::choose_dialog $views [alt2::default_view $ext]]
    if {$chosen eq ""} return
    set cview $chosen ; set cpath {} ; set ctype {}
    foreach c $cands {
      if {[lindex $c 0] eq $chosen && $cpath eq ""} { set cpath [lindex $c 1]; set ctype [lindex $c 2] }
    }
    if {$cpath eq ""} return
  }

  set tpath [file normalize $cpath]

  # A source-code view is not a schematic: it has no window to activate, no
  # read-only mode of ours to set, and `xschem load` on it would leave an empty
  # schematic named after the source (see libmgr::view_handler). Hand it to the
  # text editor and stop.
  if {[view_type_opener $ctype] eq {text}} {
    edit_file $tpath
    ciw_echo "opened [alt2::label $tpath $cview] in the text editor"
    return
  }

  # already open in ANOTHER window? -> just activate it
  set curwin [xschem get current_win_path]
  set win [alt2::find_window_for $tpath $curwin [xschem windows]]
  if {$win ne ""} {
    set top "."
    foreach w [xschem windows] { if {[lindex $w 0] eq $win} { set top [lindex $w 1] } }
    alt2::activate $win $top
    ciw_echo "activated existing window for [alt2::label $tpath $cview]"
    return
  }

  # open the alternate view in THIS window; read-only unless edited this session
  set ro [expr {[info exists ::alt2::edited($tpath)] ? 0 : 1}]
  set cmd "xschem load -gui -inplace"
  if {$ro} { append cmd " -readonly" }
  append cmd " {$cpath}"
  eval $cmd
  ciw_echo "opened [alt2::label $tpath $cview] ([expr {$ro ? {read-only} : {editable}}])"
}
