# Cadence-style hierarchy navigation helpers for XSchem.
# Loaded from cadence_style_rc. Pure Tcl, no C changes. See
# doc/claude/specs/cadence_bindkey_plan.md.

namespace eval cadence {
  variable last_loc       ;# per-window: last_loc(<win_path>) = {inst1 inst2 ...}
  array set last_loc {}
}

# --- helpers --------------------------------------------------------------

# 1 iff exactly one instance (ELEMENT == type 8) is selected.
proc cadence::one_instance_selected {} {
  if {[xschem get lastsel] != 1} { return 0 }
  lassign [xschem get first_sel] type n col   ;# "type n col"
  return [expr {$type == 8}]
}

# Current location as a list of instance names, top -> here.
# sch_path looks like ".Xamp.Xstage1." ; top level is ".".
proc cadence::hier_instnames {} {
  set names {}
  foreach c [split [xschem get sch_path] .] {
    if {$c ne ""} { lappend names $c }
  }
  return $names
}

# Walk up to the top. `go_back 1` asks to save when a level is modified; if the
# user cancels, currsch stops decreasing and we abort. 1 = reached top, 0 = stopped.
proc cadence::ascend_to_top {} {
  while {[xschem get currsch] > 0} {
    set before [xschem get currsch]
    xschem go_back 1
    if {[xschem get currsch] >= $before} { return 0 }
  }
  return 1
}

# --- actions --------------------------------------------------------------

# Ctrl-Shift-N: schematic of selected instance, new window, read-only, always fresh.
proc cadence::open_inst_sch_readonly {} {
  if {![cadence::one_instance_selected]} {
    ciw_echo "select one instance to open its schematic (read-only)" error ; return
  }
  # 'force'  => open even if that schematic is already loaded.
  # 'window' => a real top-level OS window (draggable to another monitor), not a tab.
  if {[xschem schematic_in_new_window force window] == 0} {
    ciw_echo "selected instance has no schematic view" error ; return
  }
  xschem set readonly 1   ;# new window is now the current context
  ciw_echo "opened [xschem get schname] (read-only) in [xschem get current_win_path]"
}

# Ctrl-X: descend into selected instance's schematic; no-op if no instance selected.
# With descend_readonly set (the cadence default) this opens the child read-only.
proc cadence::descend_into_inst {} {
  if {![cadence::one_instance_selected]} { return }
  xschem descend
}

# "Descend schematic (edit)": descend, then force the child editable regardless of
# the read-only-by-default. Used by the canvas context menu and bindable to a key.
proc cadence::descend_into_inst_edit {} {
  if {![cadence::one_instance_selected]} { return }
  xschem descend
  cadence::make_editable
}

# Ctrl-2 / Ctrl-Shift-2: flip the CURRENT view's edit mode (Cadence "Make Editable"
# / "Make Read Only"). A read-only view becomes editable even if its file is
# write-protected (in-memory edits; saving may still be blocked). The action is
# logged so it replays, and echoed to the CIW.
proc cadence::make_editable {} {
  if {![xschem get readonly]} { ciw_echo "[xschem get current_name]: already editable" ; return }
  xschem set readonly 0
  xschem log_action "xschem set readonly 0"
  ciw_echo "[xschem get current_name]: now EDITABLE"
}
proc cadence::make_readonly {} {
  if {[xschem get readonly]} { ciw_echo "[xschem get current_name]: already read-only" ; return }
  xschem set readonly 1
  xschem log_action "xschem set readonly 1"
  ciw_echo "[xschem get current_name]: now READ-ONLY"
}

# Alt-E: return to top (with save warnings) and remember where we were.
proc cadence::return_to_top {} {
  set win [xschem get current_win_path]
  set loc [cadence::hier_instnames]
  if {[llength $loc] == 0} { ciw_echo "already at top level" error ; return }
  if {![cadence::ascend_to_top]} {
    ciw_echo "return-to-top stopped at [xschem get sch_path] (unsaved edits)" error
    return
  }
  set cadence::last_loc($win) $loc
  ciw_echo "at top; remembered: $loc  (Alt-X to return)"
}

# Alt-X: descend back into the location remembered by the last Alt-E for this window.
proc cadence::descend_to_last {} {
  set win [xschem get current_win_path]
  if {![info exists cadence::last_loc($win)] || $cadence::last_loc($win) eq ""} {
    ciw_echo "no remembered location for this window (use Alt-E first)" error ; return
  }
  set loc $cadence::last_loc($win)
  if {![cadence::ascend_to_top]} {
    ciw_echo "cannot return to top to begin descent" error ; return
  }
  foreach name $loc {
    xschem unselect_all
    if {[xschem select instance $name] == 0} {
      ciw_echo "instance '$name' not found while descending to $loc" error ; return
    }
    if {[xschem descend] == 0} {
      ciw_echo "cannot descend into '$name'" error ; return
    }
  }
  ciw_echo "descended back to: $loc"
}
