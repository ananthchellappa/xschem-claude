## File: ciw.tcl
##
## CIW (Command Interpreter Window, after Virtuoso's) -- a standalone toplevel
## with a live view of the action log plus a command entry evaluated by the
## xschem Tcl interpreter (starts at one line; dragging the sash grows it).
## Spec: specs/action_logging.md section 3.
##
## Sourced from xschem.tcl at startup; ciw_create is called automatically for
## interactive sessions (spec decision 8). The C action-log sink (log_action()
## in util.c) mirrors every line it writes to Xschem.log into the upper pane
## by calling ciw_echo. Commands typed in the lower entry are echoed here
## (input tag), recorded in Xschem.log via `xschem log_action -noecho`, and
## evaluated at global scope; their result or error is shown in the pane only,
## never written to the file, so the file stays source-able (decision 7).

## Build (or re-show) the CIW. The two panes sit in a vertical panedwindow so
## the split is user-adjustable by dragging the sash (spec decision 9); the
## entry pane starts at its natural one-line height and stays fixed on window
## resize (the log pane takes the extra space).
proc ciw_create {} {
  if {[winfo exists .ciw]} {
    wm deiconify .ciw
    raise .ciw
    return
  }
  toplevel .ciw
  wm title .ciw {xschem CIW}
  ## closing the CIW must not exit xschem: withdraw, keeping the accumulated
  ## log so a later ciw_create just re-shows it
  wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}

  ## fat raised sash: the default is a near-invisible few-pixel strip that is
  ## both undiscoverable and a poor drag target (8px was still too thin on a
  ## HiDPI display -- user feedback). Darker background makes the sash band
  ## read as a control, and the cursor signals draggability on hover.
  panedwindow .ciw.p -orient vertical -sashwidth 14 -sashrelief raised \
    -background gray55 -sashcursor sb_v_double_arrow

  # upper pane: read-only log display, fed by ciw_echo
  frame .ciw.l
  text .ciw.l.t -width 80 -height 14 -font {Monospace 10} -state disabled \
    -yscrollcommand {.ciw.l.yscroll set}
  scrollbar .ciw.l.yscroll -command {.ciw.l.t yview}
  .ciw.l.t tag configure input  -foreground blue
  .ciw.l.t tag configure result -foreground gray30
  .ciw.l.t tag configure error  -foreground red
  pack .ciw.l.yscroll -side right -fill y
  pack .ciw.l.t -side top -fill both -expand yes

  # lower pane: command entry. A text widget (not an entry) so its height
  # actually FOLLOWS the sash: dragging the sash up gives a taller entry area
  # where long commands wrap visibly. It still starts at one line (decision 9)
  # and Return executes instead of inserting a newline ('break' stops the
  # class binding that would).
  frame .ciw.c
  text .ciw.c.e -height 1 -font {Monospace 10} -wrap char -undo 1
  bind .ciw.c.e <Return>   {ciw_exec; break}
  bind .ciw.c.e <KP_Enter> {ciw_exec; break}
  pack .ciw.c.e -side top -fill both -expand yes -padx 3 -pady 5

  .ciw.p add .ciw.l .ciw.c
  ## -stretch needs Tk >= 8.5; without it the default (last pane stretches)
  ## merely makes resizes grow the entry pane instead of the log pane.
  ## -minsize keeps either pane from being collapsed to nothing by the sash.
  catch {
    .ciw.p paneconfigure .ciw.l -stretch always -minsize 60
    .ciw.p paneconfigure .ciw.c -stretch never  -minsize 34
  }
  pack .ciw.p -side top -fill both -expand yes
}

## Append one line to the CIW log pane. 'tag' selects the style: {} for
## mirrored action-log lines, input/result/error for CIW command traffic.
## Called from C (the log_action mirror) and from ciw_exec; safe no-op when
## the CIW does not exist.
proc ciw_echo {line {tag {}}} {
  if {![winfo exists .ciw.l.t]} return
  .ciw.l.t configure -state normal
  .ciw.l.t insert end $line\n $tag
  .ciw.l.t configure -state disabled
  .ciw.l.t see end
}

## Run the command in the entry: echo it (visually distinct), evaluate at
## global scope, show the result or error in the pane, and record it in the
## action log file. Recording happens AFTER evaluation so the file stays
## source-able: a command that errored is written as a '# failed:' comment
## (replaying it would abort the source), a successful one is written raw.
proc ciw_exec {} {
  set cmd [string trim [.ciw.c.e get 1.0 end-1c]]
  if {$cmd eq {}} return
  .ciw.c.e delete 1.0 end
  ciw_echo "> $cmd" input
  if {[catch {uplevel #0 $cmd} res]} {
    ciw_echo $res error
    xschem log_action -noecho "# failed: $cmd"
  } else {
    if {$res ne {}} {ciw_echo $res result}
    xschem log_action -noecho $cmd
  }
}
