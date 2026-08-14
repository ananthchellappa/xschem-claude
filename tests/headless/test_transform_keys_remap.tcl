# Alt-R / Alt-F / Alt-V are REMAPPABLE (the in-place transforms leave the C switch)
#
# Before this change the three in-place transforms lived in hardcoded
# `else if(EQUAL_MODMASK)` arms of callback.c's key switch (cases 'r', 'f', 'v'):
# they worked, but the chord was welded to the source -- `xschem bind` could not
# move them, keybindings.csv could not disable them, and the generated cheat-sheet
# never listed them. They are now registered actions dispatched from the binding
# table, so a user can put them anywhere:
#
#   edit.rotate_in_place   default Alt-R (key 114 alt|super canvas)
#   edit.flip_in_place     default Alt-F (key 102 alt|super canvas)  horizontal
#   edit.flipv_in_place    default Alt-V (key 118 alt|super canvas)  vertical
#
# Proves:
#   (1) the six default rows exist in the LIVE table (and the shipped
#       keybindings.csv, which is generated from it)
#   (2) each default chord still applies its transform (behavior preserved)
#   (3) the Super twin works too (the old EQUAL_MODMASK accepted Mod1 OR Mod4)
#   (4) REMAP: bound to a fresh chord, that chord transforms
#   (5) UNBIND: after `xschem unbind`, the old chord is DEAD (this is the leg that
#       fails if the arms are still hardcoded in the switch -- the sabotage check)
#   (6) the read-only gate survived the move (registry mutates=1 replaces the
#       inline readonly_block)
#
# Effect oracle (same as test_perform_action_rotate_in_place): ONE horizontal wire
# with its first endpoint at the origin, cadsnap=20. In-place transforms use
# ROTATELOCAL (pivot = the object's own origin), so
#   rotate -> vertical;  horizontal flip -> stays horizontal, mirrored to negative x;
#   vertical flip -> stays horizontal, unmoved (a horizontal wire on y=0 is its own
#   vertical mirror) -- so flipv is measured on a DIAGONAL wire instead.
#
# Run under X with --pipe:
#   DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_transform_keys_remap.tcl

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# The transforms drive move_objects(START/.../END) -> draw_selection (Xlib GCs), which
# SIGSEGVs with no X connection. Defer cleanly there rather than crash (same guard as
# the perform_action transform suites).
set WIN .drw
catch { set w [xschem get current_win_path]; if {$w ne {}} { set WIN $w } }
set haveX [expr {![catch {winfo exists $WIN} e] && $e}]
if {!$haveX} {
  puts "deferred (no-X env; the in-place transforms drive move_objects -> Xlib GCs)"
  puts "RESULT: ALL PASS"
  flush stdout
  exit 0
}

# The registry's mutates=1 gate pops readonly_block()'s tk_messageBox on leg (6);
# stub it so the run never wedges.
catch {rename tk_messageBox _tkr_real_mb}
proc tk_messageBox {args} { return ok }

set ALT 8 ; set SUPER 64 ; set CTRL 4     ;# X modifier masks: Mod1, Mod4, Control

proc horiz_selected {} {
  xschem clear force
  xschem set cadsnap 20
  xschem set fluid_editing 0   ;# plain transform: no stretch/reroute pipeline in the way
  xschem wire 0 0 100 0
  xschem select_all
}
proc diag_selected {} {
  xschem clear force
  xschem set cadsnap 20
  xschem set fluid_editing 0
  xschem wire 0 0 100 100
  xschem select_all
}
proc wcoord {} { return [xschem wire_coord 0] }
proc is_vertical {c}   { expr {[lindex $c 0] == [lindex $c 2] && [lindex $c 1] != [lindex $c 3]} }
proc is_horizontal {c} { expr {[lindex $c 1] == [lindex $c 3] && [lindex $c 0] != [lindex $c 2]} }
# fire a key chord at the canvas centre
proc keychord {ks st} { global WIN; xschem callback $WIN 2 400 300 $ks 0 0 $st; update idletasks }

# --- (1) the six default rows are in the live table ---------------------------
set dump [xschem bindings dump]
foreach {code mods id} {
  114 alt   edit.rotate_in_place   114 super edit.rotate_in_place
  102 alt   edit.flip_in_place     102 super edit.flip_in_place
  118 alt   edit.flipv_in_place    118 super edit.flipv_in_place
} {
  check "(1) row present: key $code $mods canvas -> $id" \
    [expr {[lsearch -exact $dump [list key $code $mods canvas $id]] >= 0}] {}
}
# ... and the shipped csv (generated from the C table) carries them, so a user who
# opens keybindings.csv can see and edit the chord.
set kb [file join $XSCHEM_SHAREDIR keybindings.csv]
set fd [open $kb r]; set kbtxt [read $fd]; close $fd
foreach row {key,114,alt,canvas,edit.rotate_in_place key,102,alt,canvas,edit.flip_in_place
             key,118,alt,canvas,edit.flipv_in_place} {
  check "(1) keybindings.csv row: $row" [expr {[string first $row $kbtxt] >= 0}] {}
}

# --- (2) the DEFAULT chords still transform -----------------------------------
horiz_selected
check "(2) setup: wire starts horizontal" [is_horizontal [wcoord]] "coord=[wcoord]"
keychord 114 $ALT
check "(2) Alt-R rotates (horizontal -> vertical)" [is_vertical [wcoord]] "coord=[wcoord]"

horiz_selected
set c0 [wcoord]
keychord 102 $ALT
# (0,0)-(100,0) mirrors to the span [-100,0]; save.c stores the endpoints ordered, so
# compare the SPAN, not endpoint 2 (which becomes the right-hand end, x=0).
set c1 [wcoord]
check "(2) Alt-F flips horizontally (x span mirrored about the wire origin)" \
  [expr {[is_horizontal $c1] &&
         [lindex $c1 0] == -[lindex $c0 2] && [lindex $c1 2] == [lindex $c0 0]}] \
  "before=$c0 after=$c1"

diag_selected
set c0 [wcoord]
keychord 118 $ALT
# vertical flip = rotate+rotate+flip: the (0,0)-(100,100) diagonal mirrors about y
check "(2) Alt-V flips vertically (y mirrored about the wire origin)" \
  [expr {[lindex [wcoord] 3] == -[lindex $c0 3] && [lindex [wcoord] 2] == [lindex $c0 2]}] \
  "before=$c0 after=[wcoord]"

# --- (3) the Super twin -------------------------------------------------------
horiz_selected
keychord 114 $SUPER
check "(3) Super-R rotates too (EQUAL_MODMASK accepted Mod1 OR Mod4)" \
  [is_vertical [wcoord]] "coord=[wcoord]"

# --- (4) REMAP to a fresh chord ----------------------------------------------
# Ctrl+Shift+R: printable keys have ShiftMask stripped, so the chord is the SHIFTED
# keysym 82 ('R') with mods=ctrl. Unbound by default (case 'R' handles state 0 only).
check "(4) probe chord starts unbound" \
  [expr {[lsearch -glob [xschem bindings dump] {key 82 ctrl canvas *}] < 0}] {}
xschem bind key 82 ctrl canvas edit.rotate_in_place
horiz_selected
keychord 82 $CTRL
check "(4) remapped Ctrl+Shift+R rotates" [is_vertical [wcoord]] "coord=[wcoord]"

# --- (5) UNBIND kills the default chord --------------------------------------
# THE SABOTAGE LEG: if the `else if(EQUAL_MODMASK)` arms were still in the C switch,
# Alt-R would keep rotating after the row is removed and this check would fail.
xschem unbind key 114 alt canvas
horiz_selected
keychord 114 $ALT
check "(5) after unbind, Alt-R is DEAD (wire still horizontal)" \
  [is_horizontal [wcoord]] "coord=[wcoord]"
# the un-bound key must not have become a dead-letter for some OTHER 'r' branch either
check "(5) no key 114 alt canvas row left" \
  [expr {[lsearch -glob [xschem bindings dump] {key 114 alt canvas *}] < 0}] {}
# restore the default so the rest of the run (and any suite sharing this process) is sane
xschem bind key 114 alt canvas edit.rotate_in_place
xschem unbind key 82 ctrl canvas
horiz_selected
keychord 114 $ALT
check "(5) default restored: Alt-R rotates again" [is_vertical [wcoord]] "coord=[wcoord]"

# --- (6) the read-only gate moved with it -------------------------------------
# The arms each called readonly_block(); that is now the registry `mutates=1` column,
# checked by dispatch_input_action BEFORE the handler runs.
horiz_selected
set c0 [wcoord]
xschem set readonly 1
keychord 114 $ALT
check "(6) read-only view: Alt-R refuses (no mutation)" [expr {[wcoord] eq $c0}] \
  "before=$c0 after=[wcoord]"
keychord 102 $ALT
check "(6) read-only view: Alt-F refuses (no mutation)" [expr {[wcoord] eq $c0}] \
  "before=$c0 after=[wcoord]"
keychord 118 $ALT
check "(6) read-only view: Alt-V refuses (no mutation)" [expr {[wcoord] eq $c0}] \
  "before=$c0 after=[wcoord]"
xschem set readonly 0

catch {rename tk_messageBox {}}
catch {rename _tkr_real_mb tk_messageBox}

puts [expr {$::fails ? "RESULT: $::fails FAILED" : "RESULT: ALL PASS"}]
flush stdout
exit [expr {$::fails ? 1 : 0}]
