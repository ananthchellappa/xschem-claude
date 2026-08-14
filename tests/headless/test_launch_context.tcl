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

puts [expr {$fail ? "RESULT: $fail FAILED" : "RESULT: ALL PASS"}]
flush stdout
exit 0
