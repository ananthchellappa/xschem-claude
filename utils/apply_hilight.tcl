# apply_hilight: one-shot "apply a favourite net-highlight style".
# Loaded from cadence_style_rc, AFTER bus_resize.tcl (uses busresize::is_label_type) and
# after src/xschem.tcl is up (uses net_hilight_apply / net_hilight_style_default_row).
# Pure Tcl, no C changes. See doc/claude/specs/apply_hilight.md.
#
#   apply_hilight {style}
#     style may be:
#       - named "key=value":  {color="blue" pattern={10 20} thickness=10}
#       - a native dict:      {color blue thickness 10 pattern {10 20}}
#       - a positional row:   {4 purple 3 {20 20} 0 1200 none 0}   (as net_hilight_apply)
#     If a net / wire / pin / net-label is selected, the style is applied to it at once.
#     If nothing applicable is selected, the user is prompted to click (or click-drag to
#     pick several) a net; the style is applied to that selection and the command ends
#     (Esc cancels). One favourite-style shortcut for any time.

namespace eval aphl {
  variable pending ""
  # field name (and aliases) -> style-row column index
  variable colmap {
    color 1  thickness 2  width 2  pattern 3  dash 3  angle 4
    blink 5  march 6  anim 6  animation 6  rate 7  speed 7
  }
}

# Strip one layer of surrounding "" or {} from a named value.
proc aphl::_strip {v} {
  if {[string match {"*"} $v]} { return [string range $v 1 end-1] }
  if {[string match "\{*\}" $v]} { return [string range $v 1 end-1] }
  return $v
}

# {key value key value ...} -> an 8-column style row (index placeholder 0), unknown keys
# ignored, omitted columns left at their defaults.
proc aphl::_from_fields {fields} {
  variable colmap
  set row [net_hilight_style_default_row 0]
  foreach {k v} $fields {
    set k [string tolower $k]
    if {[dict exists $colmap $k]} { lset row [dict get $colmap $k] $v }
  }
  return $row
}

# Parse any of the three accepted style forms into an 8-column row.
proc aphl::parse {style} {
  variable colmap
  if {[string first = $style] >= 0} {
    # named key=value (value optionally "quoted" or a {brace list})
    set fields {}
    foreach {whole key val} \
        [regexp -all -inline {(\w+)\s*=\s*(\{[^\}]*\}|"[^"]*"|[^\s]+)} $style] {
      lappend fields [string tolower $key] [aphl::_strip $val]
    }
    return [aphl::_from_fields $fields]
  }
  set first [string tolower [lindex $style 0]]
  if {[dict exists $colmap $first] && [llength $style] % 2 == 0} {
    return [aphl::_from_fields $style]      ;# native dict form
  }
  return [net_hilight_style_norm $style 0]  ;# positional row
}

# Does the current selection contain something `xschem hilight` acts on (a wire, or a
# pin/net-label instance)?
proc aphl::sel_has_net {} {
  if {[xschem get lastsel] == 0} { return 0 }
  foreach o [xschem objects -selected] {
    array unset d ; array set d $o
    if {$d(type) eq "wire"} { return 1 }
    if {$d(type) eq "instance" &&
        [busresize::is_label_type [xschem getprop instance $d(index) cell::type]]} { return 1 }
  }
  return 0
}

# --- one-shot prompt (verb-noun) ------------------------------------------

proc aphl::show_prompt {} {
  catch {.statusbar.10 configure -state active \
           -text {APPLY HIGHLIGHT! click or drag-select net(s), Esc to cancel}}
  ciw_echo "Apply highlight: click or drag-select net(s) to style them (Esc to cancel)"
}
proc aphl::clear_prompt {} {
  catch {.statusbar.10 configure -state normal -text { }}
}

# Appended (gated) to .drw <ButtonRelease>: after the normal selection settles, if it
# landed on a net, apply the pending style and finish.
proc aphl::on_release {} {
  variable pending
  if {$pending eq ""} return
  after idle aphl::try_apply
}
proc aphl::try_apply {} {
  variable pending
  if {$pending eq ""} return
  if {![aphl::sel_has_net]} return        ;# empty / non-net click: keep waiting
  set style $pending
  set pending ""
  aphl::clear_prompt
  net_hilight_apply $style
  # ATOM 15 (issue 0065 §4 / 0067 §5, the last live click-gesture hole): the click-to-apply
  # style lands on the click-selected net. A single-CLICK selection is already recorded by the
  # select_object() core self-log (`xschem select_at x y`, atom 1) BEFORE this deferred
  # `after idle` runs, so we owe only the style half: log the RESOLVED positional row and, on
  # replay, the preceding select_at re-selects the net and this line re-applies the style.
  # net_hilight_apply is the faithful verb for the STYLE COERCION axis by construction (NOT a
  # raw-preserving twin like nhse's set_live): it runs net_hilight_style_norm on its arg
  # identically at record and replay, so a sloppy row (e.g. width 2.5 -> 1) coerces the same way
  # both times -- the atom-8 divergence lock. (Two accepted 0005-class residuals, NOT closed
  # here: a rubber-band DRAG-select-several stashes no select_at [select_rect bypasses
  # select_object], and the APPLIED INDEX is resolved against the ambient net_hilight_style
  # table, which the log does not snapshot -- both replay against replay-time state, same class
  # as every selection/config-dependent verb.) Trailing unselect_all/redraw are UI cleanup, not
  # logged (issue 0065 §4).
  xschem log_action [list net_hilight_apply $style]
  xschem unselect_all
  xschem redraw
  ciw_echo "highlight style applied"
}
# Appended (gated) to .drw <KeyPress>: Esc cancels the pending prompt.
proc aphl::on_key {ks} {
  variable pending
  if {$pending eq ""} return
  if {$ks eq "Escape"} { set pending "" ; aphl::clear_prompt ; ciw_echo "highlight apply cancelled" }
}

# --- entry point ----------------------------------------------------------

proc apply_hilight {style} {
  set row [aphl::parse $style]
  if {[aphl::sel_has_net]} {
    net_hilight_apply $row
    # ATOM 15: this immediate arm is reached by the raw cadence F5 bind (cadence_style_rc,
    # `bind .drw <Key-F5> {... apply_hilight {...}}`) which bypasses dispatch_input_action ->
    # UNLOGGED, the 0067 class; AND by a CIW-typed `apply_hilight {..}` (channel-recorded).
    # Log the RESOLVED positional row so the F5 raw bind gets its sole record; on the typed
    # path `xschem log_action` sets actionlog_cmd_logged, so ciw_exec's `-emitted` dedup skips
    # its own `apply_hilight {..}` copy -> exactly one line either way (the atom-7/8 self-logging
    # Tcl-seam pattern). Disjoint from the click arm: this branch applies to an existing selection
    # and never stages a pending prompt, so aphl::try_apply is never reached for the same gesture.
    xschem log_action [list net_hilight_apply $row]
    ciw_echo "highlight style applied to selection"
  } else {
    set ::aphl::pending $row
    aphl::show_prompt
  }
}

# Install the two gated hooks on the main canvas (only when Tk + .drw exist; skipped
# headless). They are inert unless a prompt is pending, and use `+` so they never shadow
# the existing `xschem callback` bindings.
if {[llength [info commands bind]] && [llength [info commands winfo]] && [winfo exists .drw]} {
  bind .drw <ButtonRelease> +aphl::on_release
  bind .drw <KeyPress> +[list aphl::on_key %K]
}
