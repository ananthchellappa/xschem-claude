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

# --- cross-window descend chain (issue 0053) ------------------------------
# A descend into a NEW window/tab links the child to the window it was opened
# from. hi_descend_newwin records ::descend_parent_win()/::descend_entry_level()
# keyed by the child's win_path; these helpers read them so a "return" can walk
# back to the PARENT window instead of ascending the child in place.

# The window this one was descended from ("" if it is not a descend-child).
proc cadence::parent_window {win} {
  if {[info exists ::descend_parent_win($win)]} { return $::descend_parent_win($win) }
  return {}
}
# The level this window was born at (0 if it is not a descend-child). Acts as the
# floor for in-place ascend: at this level the next return steps out to the parent.
proc cadence::entry_level {win} {
  if {[info exists ::descend_entry_level($win)]} { return $::descend_entry_level($win) }
  return 0
}
# Drop a (now stale) link, e.g. when the parent window was closed.
proc cadence::forget_window {win} {
  catch {unset ::descend_parent_win($win)}
  catch {unset ::descend_entry_level($win)}
}
# Is win_path still a live tab/window?
proc cadence::win_live {win} {
  foreach w [xschem windows] { if {[lindex $w 0] eq $win} { return 1 } }
  return 0
}
# Make win the active context AND bring the user's pointer/focus to it. The engine
# context is switched synchronously (so return_to_top's loop sees it); then the pointer
# is WARPED into the target canvas.
#
# Why the warp (issue 0054): with mouse_follows_focus on (the default) the engine
# context follows the POINTER and only switches on EnterNotify. Switching the context
# to $win while the pointer is still over the OLD window desyncs them -- the old
# window's clicks/hover keep acting on $win's context, and hover highlighting in the
# old window stops, until the pointer next crosses a window boundary. Warping the
# pointer into $win makes pointer, Tk focus and context all agree immediately, which is
# the honest meaning of "this window is now active" under focus-follows-mouse. (The WM
# title-bar "active" tint is the window manager's own call -- on WSLg it only updates on
# a click -- so that cosmetic may lag; the schematic itself is fully live.)
proc cadence::focus_window {win} {
  if {$win eq [xschem get current_win_path]} return
  xschem new_schematic switch $win
  catch {
    set top [winfo toplevel $win]
    if {[winfo exists $top]} { raise $top }
    if {[winfo exists $win]} {
      event generate $win <Motion> -warp 1 \
        -x [expr {[winfo width $win] / 2}] -y [expr {[winfo height $win] / 2}]
      focus -force $win
    }
  }
}

# Ctrl-E: return one level. Inside a window, ascend in place until it is back at the
# level it was descended-into-new-window at (its entry level); then the next return
# moves focus to the PARENT window (the child stays open). A window with no descend
# link ascends in place, exactly like the default xschem go_back. (issue 0053)
proc cadence::return_one_level {} {
  set win    [xschem get current_win_path]
  set cur    [xschem get currsch]
  set entry  [cadence::entry_level $win]
  set parent [cadence::parent_window $win]
  if {$cur > $entry} {
    xschem go_back            ;# unwind in-place descents made within this window
    return
  }
  if {$parent ne {} && [cadence::win_live $parent]} {
    cadence::focus_window $parent   ;# step out to the parent window; leave this child open
    return
  }
  if {$parent ne {}} { cadence::forget_window $win }   ;# stale link: parent gone -> fall back
  if {$cur > 0} {
    xschem go_back            ;# root / plain window: ascend in place
  } else {
    ciw_echo "already at top level"
  }
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

# Alt-E: return to the TOP of the descend chain. Repeatedly return one level --
# unwinding in-place descents within a window, then hopping to its parent window --
# until the ROOT window (no live parent) is at its top, and leave focus there. The
# intermediate child windows stay open (return is a focus move, not a close, issue
# 0053). Remembers the deepest location for Alt-X (descend_to_last) on the root window.
proc cadence::return_to_top {} {
  set start [xschem get current_win_path]
  if {[xschem get currsch] == 0 && [cadence::parent_window $start] eq {}} {
    ciw_echo "already at top level" error ; return
  }
  # the deepest window carries the full top->here hierarchy path (copy_hierarchy),
  # so capture it here for Alt-X before we start walking back up.
  set loc [cadence::hier_instnames]
  set guard 0
  while {1} {
    set win [xschem get current_win_path]
    set cur [xschem get currsch]
    set parent [cadence::parent_window $win]
    set live [expr {$parent ne {} && [cadence::win_live $parent]}]
    if {!$live && $cur == 0} break               ;# root window at its top -> done
    if {[incr guard] > 500} break                ;# safety net
    cadence::return_one_level
    # nothing moved (e.g. a save prompt was cancelled in go_back) -> stop
    if {[xschem get current_win_path] eq $win && [xschem get currsch] == $cur} break
  }
  set root [xschem get current_win_path]
  if {[xschem get currsch] != 0} {
    ciw_echo "return-to-top stopped at [xschem get sch_path] (unsaved edits)" error
    return
  }
  set cadence::last_loc($root) $loc
  ciw_echo "at top in $root; remembered: $loc  (Alt-X to return)"
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
