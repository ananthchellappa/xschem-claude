# Cadence-style "capture lib/cell/view to clipboard" helper (ALT-SHIFT-C).
# Loaded from cadence_style_rc. Pure Tcl, no C changes.
# See doc/claude/specs/cadence_capture_lcv.md.
#
# ALT-SHIFT-C branches on the current selection (same model as Ctrl-Alt-S):
#   - one instance selected -> its master's lib/cell/view (xschem get_inst_lcv);
#   - one text note selected -> the first "a/b/c" slash path found in the note;
#   - nothing selected       -> the cell currently being viewed (schematic_cellview).
# In every success case the "lib/cell/view"-style string is placed on the X
# clipboard AND echoed to the CIW so the user can paste it later.

namespace eval cadence {}

# Put $s on the clipboard and echo it to the CIW with a "copied" note.
proc cadence::clip_put {s} {
  clipboard clear
  clipboard append $s
  ciw_echo "copied to clipboard: $s" result
}

# First "a/b/c..." (two or more \w components joined by "/") found anywhere in
# $text, or {} if none. Distinct from cadence::deeppath_from_text, which anchors
# at the start of the note for the descend chord; here we want the first path
# wherever it appears.
proc cadence::first_slashpath {text} {
  if {[regexp {(\w+(?:/\w+)+)} $text -> path]} { return $path }
  return {}
}

# ALT-SHIFT-C entry point.
proc cadence::capture_lcv {} {
  set k [cadence::selkind]
  switch -- [lindex $k 0] {
    inst {
      if {[catch {xschem get_inst_lcv} lcv] || [llength $lcv] < 3} {
        ciw_echo "cannot resolve the selected instance's lib/cell/view ($lcv)" error ; return
      }
      cadence::clip_put [join [lrange $lcv 0 2] /]
    }
    text {
      set p [cadence::first_slashpath [lindex $k 2]]
      if {$p eq {}} { ciw_echo "no a/b/c slash path in the selected text note" error ; return }
      cadence::clip_put $p
    }
    none {
      set lcv [schematic_cellview [xschem get schname]]
      if {$lcv eq {}} { ciw_echo "current cell is not in a registered library" error ; return }
      cadence::clip_put [join [lrange $lcv 0 2] /]
    }
    default {
      ciw_echo "Capture L/C/V: select one instance, one slash-path text note, or nothing (current cell)" error
    }
  }
}
