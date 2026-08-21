# u7_label_forms.tcl — eyeball aid, NOT a test.
#
# Serves the look debt for results item 10: the Calculator's U7 refusal
# sentence, and the four forms the Results Dir row's LABEL takes depending on
# where the result came from.
#
# WHY IT IS NEEDED.  Three of the four label forms need a world you cannot
# reach by hand in one sitting (an ASE-L session, a busy context, a viewer
# token), so the four strings can never be compared side by side in real use.
# This puts a small pad on screen whose buttons force each form in turn, with a
# real file's path beside it, so you can read all four in a row.
#
# HOW TO RUN.  In the schematic window:  Tools > Execute TCL command
# (accelerator '=').  If the input box already holds text, press `Clear Input`
# first — the dialog reopens with whatever was last in it and a second line
# would run as well.  Enter
#
#     source /path/to/doc/claude/calculator_batch/eyeball/u7_label_forms.tcl
#
# then press **Evaluate** (there is no OK button; Shift-Return in the input box
# does the same).  It opens (or raises) the Calculator and puts the pad under
# it, or near the bottom of the screen if there is no room.  Close the pad
# window when you are done; nothing else changes.
#
# It writes NOTHING to disk and touches no tracked file.  The path it shows is
# an existing read-only fixture and is never opened — only displayed.
#
# ⚠ The `(waveform viewer):` form is SYNTHETIC.  No real sequence reaches it:
# calc::token_origin says `viewer` only for a token that is not in
# ::ase::sessions, and the viewer refuses to open an unknown token.  It is on
# the pad so the four strings can be compared, not because you should expect
# to meet it.  The pad says so on screen too — that warning must not live only
# in this comment, where the person doing the looking never sees it.
#
# ⚠ Pressing Eval RE-RESOLVES.  calc::require_result publishes the real
# world's answer before it speaks, so the row snaps back from whichever form
# you forced.  That is correct behaviour, not the pad misfiring.

if {![llength [info commands calc::open]]} {
    return "u7_label_forms: the Calculator code is not loaded in this xschem\
 (calc::open is undefined).  Nothing to show."
}

# The fixture, derived rather than hardcoded: this file lives at
# doc/claude/calculator_batch/eyeball/, the raw at doc/claude/casemode_batch/
# fixtures/.  `info script` is set by `source` even when the source runs from a
# Tk callback (Tools > Execute TCL command does `uplevel #0`), so it is the
# reliable anchor; XSCHEM_SHAREDIR is the fallback for a pasted body, and it
# points at src/ in a source tree.
set ::u7path {}
if {[info script] ne {}} {
    set ::u7path [file normalize \
        [file join [file dirname [file normalize [info script]]] \
             .. .. casemode_batch fixtures tr_fold.raw]]
}
if {![file exists $::u7path] && [info exists ::XSCHEM_SHAREDIR]} {
    set ::u7path [file normalize \
        [file join $::XSCHEM_SHAREDIR .. doc claude casemode_batch fixtures \
             tr_fold.raw]]
}
if {![file exists $::u7path]} {
    return "u7_label_forms: could not find the fixture raw file\
 (doc/claude/casemode_batch/fixtures/tr_fold.raw); last tried '$::u7path'.\
  Set ::u7path to any real file and source this again."
}

calc::open
update idletasks

catch {destroy .u7}
toplevel .u7
wm withdraw .u7
wm title .u7 {U7 label forms - eyeball aid}

label .u7.l -anchor w -text {Path shown in the row (edit it, then press a label button):}
entry .u7.e -textvariable ::u7path -width 90
frame .u7.b
pack .u7.l .u7.e -fill x -padx 6 -pady 2
pack .u7.b -fill x -padx 6 -pady 6

foreach {id txt} {ase {(ASE-L session):} viewer {(waveform viewer):}
                  refused {(unavailable):} none {plain Results Dir:}} {
    button .u7.b.$id -text $txt -command [list apply {{o} {
        calc::results_publish [list $o $::u7path SESSION-KEY tran 0]
        update idletasks
    }} $id]
    pack .u7.b.$id -side left -padx 3
}
button .u7.b.eval -text {press Eval} -command {calc::eval_click ; update idletasks}
pack .u7.b.eval -side left -padx 12

label .u7.n -anchor w -justify left -text \
"1. Press each of the four label buttons and read the Results Dir row.
   The (unavailable): form replaces the path with a sentence of its own -
   that is by design, not this pad misfiring.
   (waveform viewer): is SYNTHETIC - no real sequence in xschem reaches it.
   It is here only so the four label strings can be compared side by side.
2. Then press 'press Eval' and read the status line along the bottom of the
   Calculator - that is the U7 refusal sentence.
3. Drag the Calculator wider and repeat: the sentence needs a 778px-wide
   window to show whole (measured), and the path entry shows only about 45-50
   characters beside the longer labels.  Issue 0517 tracks the four sentences
   that overflow the status entry."
pack .u7.n -fill x -padx 6 -pady {0 8}

# Placed only now the widgets are built, so the requested height is known:
# directly UNDER the Calculator, so the row you are reading and the buttons
# that drive it are in one glance -- but lifted back up whenever that would put
# the pad off the bottom of the screen, and never off the left edge.
update idletasks
set _h [winfo reqheight .u7]
set _x 40
set _y [expr {[winfo screenheight .] - $_h - 80}]
if {[winfo exists .calc] && [winfo ismapped .calc]} {
    set _x [winfo rootx .calc]
    set _y [expr {[winfo rooty .calc] + [winfo height .calc] + 30}]
}
if {$_y + $_h + 60 > [winfo screenheight .]} {
    set _y [expr {[winfo screenheight .] - $_h - 80}]
}
if {$_y < 40} { set _y 40 }
if {$_x < 0}  { set _x 40 }
wm geometry .u7 +$_x+$_y
wm deiconify .u7
unset _x _y _h

return "u7 pad open; path = $::u7path"
