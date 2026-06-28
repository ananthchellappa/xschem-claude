# Net-highlight style cursor navigation helper.
# Loaded from cadence_style_rc. Pure Tcl over the C `xschem decr_hilight_color`
# command. See doc/claude/specs/hilight_style_decrement.md.
#
# The highlight style cursor auto-advances after each net highlight, so each new
# highlight gets the next style. ALT-minus steps the cursor BACK one (wrapping) so
# a recently used style can be re-applied to the next highlight. Echoes the new
# index to the CIW so the user can see which style is now queued.

namespace eval cadence {}

proc cadence::prev_hilight_style {} {
  if {[catch {xschem decr_hilight_color} idx]} {
    ciw_echo "cannot step the highlight style cursor: $idx" error ; return
  }
  ciw_echo "net highlight style -> $idx (applies to next highlight)" result
}
