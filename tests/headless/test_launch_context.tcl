# Launch-context smoke (issue 0001). DELIBERATELY NON-HERMETIC: unlike the
# rest of this suite it runs against the REAL user environment (~/.xschem
# geometry/config) and the user's actual launch recipe, because issue 0001
# was invisible to every hermetic layer — a poisoned per-filename entry in
# ~/.xschem/geometry opened a 1x1 window only when launching from the repo
# root, while all sandboxed tests stayed green. This asserts the invariants
# that must hold in ANY healthy launch context:
#   (1) the main window comes up at a usable size,
#   (2) sourcing src/cadence_style_rc post-init (the --script recipe,
#       `src/xschem --script src/cadence_style_rc`) succeeds,
#   (3) its `xschem bind wheel ...` remaps actually land in the C table.
# Run under X with --pipe (any cwd):
#   ./src/xschem --pipe --script tests/headless/test_launch_context.tcl
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

proc has_row {row} {
  expr {[lsearch -exact [xschem bindings dump] $row] >= 0}
}

# 1) usable main-window size, as restored from the REAL ~/.xschem/geometry
set geom [wm geometry .]
set n [scan $geom {%dx%d} w h]
check "main window has a usable size" [expr {$n == 2 && $w >= 300 && $h >= 200}] "(geom=$geom)"

# 2) the user's post-init script sources cleanly (--script semantics: the
#    xschem command exists, unlike rc-style sourcing which predates it)
set repo [file dirname [file dirname [file dirname [file normalize [info script]]]]]
set rc $repo/src/cadence_style_rc
check "src/cadence_style_rc exists" [file exists $rc] $rc
set rcerr [catch {source $rc} msg]
check "cadence_style_rc sources without error" [expr {!$rcerr}] [expr {$rcerr ? $msg : {}}]

# 3) its wheel remaps landed in the live binding table
check "Ctrl+wheel-up -> view.zoom_in"    [has_row {wheel up ctrl canvas view.zoom_in}] {}
check "Ctrl+wheel-down -> view.zoom_out" [has_row {wheel down ctrl canvas view.zoom_out}] {}
check "plain wheel-up -> view.pan_up"    [has_row {wheel up 0 canvas view.pan_up}] {}
check "plain wheel-down -> view.pan_down" [has_row {wheel down 0 canvas view.pan_down}] {}

# 4) S8's three OP-annotation chords (doc/claude/specs/op_annotation.md, step S8).
#    `bind` and `winfo` do NOT exist under --nogui -- measured, `info commands`
#    is empty for both -- so src/cadence_style_rc cannot even be sourced there
#    and these six rows are the ONLY place the keys themselves can be pressed.
#    Every moving part of `cadence::annot_mode` is tested headless instead, in
#    tests/headless/test_op_annot.tcl section N; this is the seam between them.
#
#      6       -> cadence::annot_mode op       annot_show |= 1
#      Ctrl-6  -> cadence::annot_mode none     annot_show  = 0
#      Alt-6   -> cadence::annot_mode opvolt   annot_show |= 2
#
#    ⚠ THE USER'S RULING OF 2026-08-22 (doc/claude/issues/0614-*.md) MADE THE
#    TWO ON-CHORDS ADDITIVE, AND THE NEW READING IS NOT THE OBVIOUS ONE. `6`
#    never turns anything off and is not a toggle; `Alt-6` leaves bit0 exactly
#    as it found it, so from a clean start it gives mask 2 -- node voltages
#    ALONE, no OP blocks, a state the old three-state cascade could not reach;
#    `Ctrl-6` is the only off switch. Rows LC1-LC3 below are that ruling driven
#    through REAL key presses; its pure-function half is
#    tests/headless/test_op_annot.tcl rows N1/N1b/N23.
#
#    ⚠ EACH CHORD IS ASSERTED SEPARATELY, AND THAT IS NOT REDUNDANCY. Tk matches
#    a pattern whose modifiers are a SUBSET of the event's, so with only
#    <Key-6> bound BOTH Ctrl-6 and Alt-6 fire it -- measured -- and a typo in
#    one chord silently turns the OFF key into an ON key. (Measured too:
#    <Control-Alt-Key-6> falls into <Alt-Key-6>, while <Shift-Key-6> does not
#    match at all, its keysym being `asciicircum`.)
#
#    ⚠ THE TRAILING `break` IS THE OVERRIDE, AND rectcolor IS HOW IT IS SEEN.
#    Ctrl-<digit> is "select drawing layer <digit>" in the C dispatcher
#    (callback.c:7272, which acts only when state == ControlMask -- plain 6 and
#    Alt-6 are true no-ops there). Measured on this tree BEFORE S8: Ctrl-6 moved
#    `xschem get rectcolor` from 4 to 6. G5 pins that it no longer does, which
#    is the only way to tell a real override from a bind that merely also ran.

## The bind body of <seq> names <needle> AND ends in `break`.
proc bind_calls {seq needle} {
  set b [bind .drw $seq]
  expr {[string first $needle $b] >= 0 && [regexp {break\s*$} [string trim $b]] ? 1 : 0}
}
## Press one chord on the canvas and let the binding run to completion.
proc press_drw {seq} {
  catch {focus -force .drw}
  event generate .drw $seq
  update
}

check "6 -> cadence::annot_mode op, ending in break" \
  [bind_calls <Key-6> {cadence::annot_mode op}] "(bind={[bind .drw <Key-6>]})"
check "Ctrl-6 -> cadence::annot_mode none, ending in break" \
  [bind_calls <Control-Key-6> {cadence::annot_mode none}] "(bind={[bind .drw <Control-Key-6>]})"
check "Alt-6 -> cadence::annot_mode opvolt, ending in break" \
  [bind_calls <Alt-Key-6> {cadence::annot_mode opvolt}] "(bind={[bind .drw <Alt-Key-6>]})"

catch {xschem set rectcolor 4}
catch {xschem set annot_show 0}
press_drw <Key-6>
check "pressing 6 turns device OP info ON (annot_show 1) and selects no layer" \
  [expr {[xschem get annot_show] == 1 && [xschem get rectcolor] == 4}] \
  "(annot_show=[xschem get annot_show] rectcolor=[xschem get rectcolor], want 1 / 4)"

press_drw <Control-Key-6>
check "pressing Ctrl-6 turns annotation OFF, and `break` suppresses select-layer-6" \
  [expr {[xschem get annot_show] == 0 && [xschem get rectcolor] == 4}] \
  "(annot_show=[xschem get annot_show] rectcolor=[xschem get rectcolor], want 0 / 4)"

# LC1. ⚠ THE ROW THE RULING MOVED, AND IT WAS ALL-PASS BEFORE IT. Pressed
#      straight after the Ctrl-6 above, i.e. from mask 0, `Alt-6` must give 2 --
#      node voltages ALONE. It gave 3 until 0614, because `cadence::_annot_mask`
#      force-set bit0 for `opvolt`; a red here reporting annot_show=3 is that
#      hard three-state set still in place.
press_drw <Alt-Key-6>
check "pressing Alt-6 from OFF turns node voltages ON ALONE (annot_show 2)" \
  [expr {[xschem get annot_show] == 2 && [xschem get rectcolor] == 4}] \
  "(annot_show=[xschem get annot_show] rectcolor=[xschem get rectcolor], want 2 / 4)"

# LC2. ⚠ "`6` PRESSED WHILE VOLTAGES ARE ON DOES NOT REMOVE THEM" -- 0614's
#      acceptance, and the half a cascade cannot satisfy. From the mask 2 LC1
#      just produced, `6` must ADD bit0 and answer 3. Before the ruling the same
#      press answered 1: it took the voltages away.
press_drw <Key-6>
check "pressing 6 ADDS device OP info without removing the voltages (annot_show 3)" \
  [expr {[xschem get annot_show] == 3 && [xschem get rectcolor] == 4}] \
  "(annot_show=[xschem get annot_show] rectcolor=[xschem get rectcolor], want 3 / 4)"

# LC3. ⚠ "`6` PRESSED TWICE IN A ROW LEAVES THE MASK UNCHANGED" -- 0614 again.
#      GREEN BEFORE THE CHANGE TOO, because the old `6` was a hard set to 1
#      rather than a toggle; it is here so that an implementation which reached
#      "additive" by writing `^= 1` reds a named row instead of passing LC1 and
#      LC2. rectcolor is re-asserted on both presses because the trailing
#      `break` has to survive the rewrite as well.
catch {xschem set annot_show 0}
press_drw <Key-6>
set lc3_a [list [xschem get annot_show] [xschem get rectcolor]]
press_drw <Key-6>
set lc3_b [list [xschem get annot_show] [xschem get rectcolor]]
check "pressing 6 twice is not a toggle (annot_show 1 both times)" \
  [expr {$lc3_a eq {1 4} && $lc3_b eq {1 4}}] \
  "(first=$lc3_a second=$lc3_b, want {1 4} / {1 4})"
catch {xschem set annot_show 0}

puts [expr {$fail ? "RESULT: $fail FAILED" : "RESULT: ALL PASS"}]
flush stdout
exit 0
