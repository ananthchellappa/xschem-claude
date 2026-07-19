#  File: utils/toggle_pins_netlabels.tcl        (sourced from cadence_style_rc)
#
#  Toggle the SELECTED objects between schematic PORTS and WIRE-LABELS.
#
#    wire-label (devices/lab_pin.sym)  ->  INPUT pin (devices/ipin.sym),
#                                          canonically "pointing to the right"
#                                          (rot 0, flip 0)
#    port (ipin/opin/iopin.sym)        ->  wire-label (devices/lab_pin.sym),
#                                          label text kept on the SAME side the
#                                          pin's @lab text was on.
#
#  Text-side rule (see the ROTATION macro in src/xschem.h and the @lab T lines in
#  the .sym files): a symbol's @lab text occupies a fixed side at rot0/flip0 --
#  ipin=LEFT, lab_pin=LEFT, opin=RIGHT, iopin=RIGHT -- and rigidly transforms with
#  the instance. So to reproduce a pin's text side with a lab_pin:
#    ipin   : same default side as lab_pin  -> keep (rot, flip)
#    opin   : opposite default side          -> keep rot, toggle flip
#    iopin  : opposite default side          -> keep rot, toggle flip
#  The pin's connection node is the instance origin for all four symbols, so the
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
#  file (e.g. to <Control-Shift-Key-P>), or unbind with:  bind .drw <Control-Shift-Key-O> {}
#
# ---------------------------------------------------------------------------
#  Recovering the OLD Ctrl+Shift+O (and the related Ctrl+Shift+T)
# ---------------------------------------------------------------------------
#  Ctrl+Shift+O used to "reopen the most-recently-OPENED file" (load -lastopened);
#  Ctrl+Shift+T still "reopens the most-recently-CLOSED file" (load -lastclosed).
#  Both are handled directly in the C key switch (src/callback.c case 'O'/'T'); they
#  are NOT registered action ids, so they cannot be put in keybindings.csv either.
#  The only way to (re)home them is a Tk bind that calls the underlying command
#  directly. To give "reopen last opened" another chord (here Ctrl+Shift+Y):
#
#      bind .drw <Control-Shift-Key-Y> {
#        global open_in_new_window
#        if {$open_in_new_window} { xschem load_new_window -lastopened } \
#        else                     { xschem load -gui -lastopened }
#        break
#      }
#
#  For "reopen last closed" use -lastclosed instead of -lastopened. To simply give
#  Ctrl+Shift+O back its old job, delete the `bind` line below (the C default
#  resurfaces) or point that chord at the -lastopened snippet above.
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
  foreach line [split [xschem instance_coord] "\n"] {
    set line [string trim $line]
    if {$line eq {}} continue
    set instname [lindex $line 0]
    set base     [file tail [lindex $line 1]]
    set x        [lindex $line 2]
    set y        [lindex $line 3]
    set rot      [lindex $line 4]
    set flip     [lindex $line 5]
    switch -exact -- $base {
      lab_pin.sym {
        # wire-label -> input pin pointing right (canonical rot 0, flip 0)
        set tsym devices/ipin.sym ; set trot 0 ; set tflip 0
      }
      ipin.sym {
        # ipin default @lab side == lab_pin default side -> keep orientation
        set tsym devices/lab_pin.sym ; set trot $rot ; set tflip $flip
      }
      opin.sym  -
      iopin.sym {
        # opin/iopin default @lab side is opposite lab_pin's -> toggle flip so
        # the label text lands on the same absolute side as the pin's name text
        set tsym devices/lab_pin.sym ; set trot $rot ; set tflip [expr {$flip ^ 1}]
      }
      default { continue }
    }
    # (any non-port, non-wire-label instance is skipped by the default arm above)
    set lab [xschem getprop instance $instname lab]
    lappend jobs [list $instname $tsym $x $y $trot $tflip $lab]
  }

  if {[llength $jobs] == 0} {
    ciw_echo "toggle pins/labels: no ports or wire-labels selected"
    return
  }

  # ---- apply as ONE undo transaction ---------------------------------------
  xschem push_undo        ;# the single slot Ctrl-Z restores to
  xschem set no_undo 1     ;# suppress the per-op undo pushes below
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
  xschem set no_undo 0     ;# ALWAYS re-enable undo, even on error

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
}

# Default chord: Ctrl+Shift+O (Shift makes the 'o' key emit the capital "O"
# keysym, so bind Key-O -- same idiom as the other Control-Shift binds in
# cadence_style_rc). Ends in `break` to override the C-side default. See the
# BINDING NOTE above to rebind or to recover the old Ctrl+Shift+O behavior.
bind .drw <Control-Shift-Key-O> {toggle_pins_netlabels; break}
