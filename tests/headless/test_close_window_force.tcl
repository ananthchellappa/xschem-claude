# Closing the MAIN window (.drw) while a real SEPARATE window (a force-window, its own X window) is
# open must leave the surviving main window drawing into its OWN live canvas -- not the destroyed
# window. Repro of the user bug: open a schematic, open a second one in a NEW window
# (Ctrl+Shift+N -> cadence::open_inst_sch_readonly -> `schematic_in_new_window force window`), then
# close the main window (Ctrl+W) -> the second window vanishes and the main window shows the second
# schematic but is FROZEN (display stuck, resizing doesn't help).
#
# Root cause: in tabbed mode the close path calls swap_tabs(), which swaps top_path/current_win_path
# but NOT the X window id (unlike swap_windows). For genuine tabs (shared .drw X window) that is a
# no-op; for a force-window (separate X window) it leaves the surviving .drw context holding the
# DESTROYED window's id -> draws go to a dead drawable -> frozen.
#
# Detectable signal: after the close, `xschem get drawwindowid` (xctx->window) must equal
# [winfo id .drw]. Pre-fix it is the destroyed sub-window's id.
#
# GUI only (needs real windows). Run:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_close_window_force.tcl

if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; real separate windows required)"; flush stdout; exit 0 }

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }
proc drawmatch {} { expr {[xschem get drawwindowid] == [winfo id .drw]} }

set dir [file join [pwd] _cw_[pid]] ; file delete -force $dir ; file mkdir $dir
set lib [lindex [glob -nocomplain [file join [pwd] xschem_library *.sch] [file join [pwd] xschem_library * *.sch]] 0]
set fa [file join $dir a.sch] ; set fb [file join $dir b.sch]
file copy -force $lib $fa ; file copy -force $lib $fb
file attributes $fa -permissions 0644 ; file attributes $fb -permissions 0644

xschem load $fa ; xschem zoom_full ; update idletasks
check "C1 main draws into its own canvas" [drawmatch] "(draw=[xschem get drawwindowid] winfo=[winfo id .drw])"

# a REAL separate window (force-window), as cadence::open_inst_sch_readonly does via 'window'
xschem load_new_window -window $fb ; update idletasks
check "C2 a real separate window (.x1) was created" [expr {[winfo exists .x1]}] "(.x1 exists=[winfo exists .x1])"

xschem new_schematic switch .drw ; update idletasks
check "C3 back on main, still drawing into .drw (precondition)" [drawmatch] "(draw=[xschem get drawwindowid] winfo=[winfo id .drw])"

# close the MAIN window while the separate window is open (the Ctrl+W / xschem exit path)
# Capture the draw counter immediately around the close: the close path must SYNCHRONOUSLY redraw
# the surviving main window (no expose event fires -- the .drw canvas neither moved nor resized --
# so without an explicit draw() the canvas stays stale showing a.sch). Sample before/after the
# exit and BEFORE any update, so an async expose redraw cannot mask a missing synchronous draw.
set dc_before [xschem get drawcount]
catch {xschem exit force}
set dc_after [xschem get drawcount]
update idletasks

check "C4 main absorbed the other window's schematic (b.sch)" [string match {*b.sch} [xschem get schname]] "(=> [file tail [xschem get schname]])"
check "C5 the separate window was destroyed" [expr {![winfo exists .x1]}] "(.x1 exists=[winfo exists .x1])"
# THE FREEZE BUG (issue 0049): the surviving main window must draw into its OWN live canvas
check "C6 surviving main draws into the LIVE main canvas (not the destroyed window)" [drawmatch] \
  "(draw=[xschem get drawwindowid] winfo.drw=[winfo id .drw])"
# THE STALE-DISPLAY BUG (0049 follow-up): the close must redraw the absorbed schematic right away,
# not leave the canvas showing a.sch until a manual resize/zoom/pan.
check "C7 close synchronously redrew the surviving window" [expr {$dc_after > $dc_before}] \
  "(drawcount $dc_before -> $dc_after)"

file delete -force $dir
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
