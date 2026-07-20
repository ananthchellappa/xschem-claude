#  File: utils/toggle_pins_netlabels.tcl        (sourced from cadence_style_rc)
#
#  Toggle the SELECTED objects between schematic PORTS and WIRE-LABELS.
#
#    wire-label  (symbol type=label: lab_pin.sym, lab_wire.sym, ...)
#                -> INPUT pin (devices/ipin.sym), canonically "pointing right"
#                   (rot 0, flip 0)
#    port  (symbol type=ipin|opin|iopin)
#                -> wire-label (devices/lab_pin.sym), label text kept on the SAME
#                   side the pin's @lab text was on.
#
#  Objects are classified by their SYMBOL TYPE (xschem getprop instance N cell::type),
#  not by filename, so every label flavour (lab_pin, lab_wire, ...) and every port
#  flavour is recognised. lab_show (type=show_label) and lab_generic (empty type) are
#  NOT connecting net-labels and are deliberately left alone.
#
#  Text-side rule (see the ROTATION macro in src/xschem.h and the @lab T lines in
#  the .sym files): a symbol's @lab text occupies a fixed side at rot0/flip0 --
#  type ipin=LEFT, label=LEFT, opin=RIGHT, iopin=RIGHT -- and rigidly transforms
#  with the instance. So to reproduce a pin's text side with a lab_pin:
#    ipin   : same default side as lab_pin  -> keep (rot, flip)
#    opin   : opposite default side          -> keep rot, toggle flip
#    iopin  : opposite default side          -> keep rot, toggle flip
#  The pin's connection node is the instance origin for all these symbols, so the
#  replacement is placed at the same (x0,y0) and the wiring stays attached.
#
#  The whole batch is ONE undo step (push_undo + no_undo), and the transformed
#  set stays selected.
#
#  Run it from the CIW / a script as:   toggle_pins_netlabels
#
# ---------------------------------------------------------------------------
#  BINDING NOTE -- why this is a `bind .drw`, not a keybindings.csv row
# ---------------------------------------------------------------------------
#  keybindings.csv rows are replayed through `xschem bind`, which only accepts an
#  action id that already exists in the COMPILED C action registry
#  (callback.c action_registry[] / find_action_def). There is no runtime "register
#  a Tcl proc as an action" path and no generic "run this Tcl" action, so a brand
#  new Tcl proc like this one CANNOT be dispatched from keybindings.csv without a
#  C-source change. The established no-C-change mechanism (used throughout
#  cadence_style_rc) is a Tk binding on the canvas `.drw` that ends in `break`, so
#  it captures the chord before the generic <KeyPress> -> `xschem callback` -> C
#  dispatcher can act on it. clone_canvas_bindings copies it to detached/new
#  canvases, so it works in child windows too.
#
#  Rebind / move the chord: edit the `bind .drw ...` line at the bottom of this
#  file (e.g. to <Control-Shift-Key-P>), or unbind with:  bind .drw <Control-Shift-Key-T> {}
#
# ---------------------------------------------------------------------------
#  This chord OVERRIDES the old Ctrl+Shift+T ("open last closed" = load -lastclosed).
#  Ctrl+Shift+O ("open most recent" = load -lastopened) is left untouched.
#  Both -lastopened/-lastclosed are handled directly in the C key switch
#  (src/callback.c case 'O'/'T'); they are NOT registered action ids, so they cannot
#  live in keybindings.csv. To recover "open last closed" on another chord, add a Tk
#  bind that calls the underlying command directly (here Ctrl+Shift+Y):
#
#      bind .drw <Control-Shift-Key-Y> {
#        global open_in_new_window
#        if {$open_in_new_window} { xschem load_new_window -lastclosed } \
#        else                     { xschem load -gui -lastclosed }
#        break
#      }
#
#  Or simply delete the `bind` line below to give Ctrl+Shift+T its old job back
#  (the C default resurfaces).
# ---------------------------------------------------------------------------

proc toggle_pins_netlabels {} {
  # ---- guards --------------------------------------------------------------
  if {[xschem get readonly]} {
    ciw_echo "toggle pins/labels: schematic is read-only"
    return
  }
  # symbol view holds pin RECTS, not port/label INSTANCES -> nothing to toggle
  if {[string match {*.sym} [xschem get current_name]]} {
    ciw_echo "toggle pins/labels: not available in symbol view"
    return
  }

  # ---- snapshot the selected ports / wire-labels ---------------------------
  # `xschem instance_coord` prints one line per selected instance:
  #     {instname} {symref} x0 y0 rot flip
  set jobs {}
  set seen {}
  foreach line [split [xschem instance_coord] "\n"] {
    set line [string trim $line]
    if {$line eq {}} continue
    set instname [lindex $line 0]
    set x        [lindex $line 2]
    set y        [lindex $line 3]
    set rot      [lindex $line 4]
    set flip     [lindex $line 5]
    # classify by SYMBOL TYPE, robust to every label / port filename
    set type [xschem getprop instance $instname cell::type]
    switch -exact -- $type {
      label {
        # wire-label -> input pin pointing right (canonical rot 0, flip 0)
        set tsym devices/ipin.sym ; set trot 0 ; set tflip 0
      }
      ipin {
        # ipin default @lab side == lab_pin default side -> keep orientation
        set tsym devices/lab_pin.sym ; set trot $rot ; set tflip $flip
      }
      opin -
      iopin {
        # opin/iopin default @lab side is opposite lab_pin's -> toggle flip so
        # the label text lands on the same absolute side as the pin's name text
        set tsym devices/lab_pin.sym ; set trot $rot ; set tflip [expr {$flip ^ 1}]
      }
      default {
        lappend seen "[file tail [lindex $line 1]](type=$type)"
        continue
      }
    }
    set lab [xschem getprop instance $instname lab]
    lappend jobs [list $instname $tsym $x $y $trot $tflip $lab]
  }

  if {[llength $jobs] == 0} {
    # Actionable diagnostic: distinguish "nothing selected" from "wrong things
    # selected" (the CIW line is the only feedback -- ciw_echo writes to the CIW
    # widget, NOT to any log file).
    set nsel [xschem get lastsel]
    if {$nsel == 0} {
      ciw_echo "toggle pins/labels: nothing selected -- select the ports/wire-labels first"
    } elseif {[llength $seen]} {
      ciw_echo "toggle pins/labels: $nsel selected, none are ports/wire-labels: [join $seen {, }]"
    } else {
      ciw_echo "toggle pins/labels: $nsel object(s) selected but none are instances (wires/text?)"
    }
    return
  }

  # ---- apply as ONE undo transaction + ONE log line ------------------------
  # The mutating sub-verbs below are wrapped in `log_action -suppress push/pop`
  # so their own self-logs do NOT leak a partial, misleading record: today only
  # `xschem delete` self-logs (at the perform_action boundary, scheduler.c:1534),
  # which alone would replay as "delete the selection" and never re-create the
  # replacements. `-suppress` is a DEPTH COUNTER (scheduler.c:6317), so a replay
  # that already holds the scope nests cleanly and never re-logs. On success we
  # emit ONE replayable line, `toggle_pins_netlabels`, via the log_action bridge
  # (scheduler.c:6324) -- the proc IS the action. Both the pop and `no_undo 0`
  # ALWAYS run (the catch captures errors), keeping the suppress scope balanced.
  xschem push_undo                  ;# the single slot Ctrl-Z restores to
  xschem set no_undo 1              ;# suppress the per-op undo pushes below
  xschem log_action -suppress push  ;# silence sub-verb self-logs; one named line below
  set newidx {}
  set failed [catch {
    # delete the originals: select exactly them (nothing else), then one delete
    xschem unselect_all
    foreach j $jobs {
      xschem select instance [lindex $j 0] nodraw
    }
    xschem delete
    # place the replacements; each is appended, so its index is (count - 1)
    foreach j $jobs {
      lassign $j instname tsym x y trot tflip lab
      xschem instance $tsym $x $y $trot $tflip "name=p1 lab=$lab"
      lappend newidx [expr {[xschem get instances] - 1}]
    }
  } emsg]
  xschem log_action -suppress pop   ;# ALWAYS balance the push, even on error
  xschem set no_undo 0              ;# ALWAYS re-enable undo, even on error

  if {$failed} {
    ciw_echo "toggle pins/labels: aborted ($emsg)"
    xschem redraw
    return
  }

  # ---- keep the transformed set selected -----------------------------------
  xschem unselect_all
  foreach i $newidx { xschem select instance $i nodraw }

  xschem set_modify 1
  xschem redraw
  # ONE replayable line for the whole gesture (the sub-verbs were suppressed
  # above). No `xschem` prefix: this is a Tcl proc, re-run directly when the log
  # is sourced. Suppressed to a no-op during replay (counter still >0), so it is
  # never double-logged.
  xschem log_action toggle_pins_netlabels
  ciw_echo "toggle pins/labels: converted [llength $jobs] object(s)"
}

# Default chord: Ctrl+Shift+T (Shift makes the 't' key emit the capital "T"
# keysym, so bind Key-T -- same idiom as the other Control-Shift binds in
# cadence_style_rc). Ends in `break` to override the C-side default (open last
# closed). See the BINDING NOTE above to rebind or to recover that behaviour.
bind .drw <Control-Shift-Key-T> {toggle_pins_netlabels; break}
