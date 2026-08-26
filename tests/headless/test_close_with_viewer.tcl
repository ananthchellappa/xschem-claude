# Closing a schematic while a WAVEFORM VIEWER is open must not hand the viewer's buffer
# to the closing window, and must not destroy the viewer (issue 0847).
#
# The field report, from the user's own window_report census (2026-08-26, log.4): one
# Ctrl-W in the tb_bandgap window turned `.` from
#   'xschem [3] - tb_bandgap.sch (read-only)'   into   'xschem [5] - untitled.sch (read-only)'
# and `.x1` -- the viewer's own toplevel -- disappeared. Mechanism: swap_tabs() (and its
# non-tabbed twin swap_windows()) took `the first non-NULL save_xctx[j]`, which with a
# viewer open IS the viewer.
#
# ⚠ COVERAGE GAP, STATED RATHER THAN GLOSSED: this session runs with the shipped
# tabbed_interface=1, so only the TABBED arm of scheduler.c's exit handler is exercised
# here (swap_tabs + its caller guard). The non-tabbed twin (swap_windows + the guard in
# the other branch) is symmetric by inspection and shares first_swappable_ctx(), but it
# is NOT measured by this file: removing its caller guard leaves every row below green.
# Issue 0847 records that.
#
# Needs Tk:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_close_with_viewer.tcl

set ::fail 0
proc check {n ok {d {}}} {
  if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d" ; incr ::fail }
}
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; real toplevels are the subject)" ; flush stdout ; exit 0 }

source [file join [file dirname [info script]] scratch.tcl]
set dir [test_scratch cwv]
set lib [lindex [glob -nocomplain [file join [pwd] xschem_library *.sch]] 0]
if {$lib eq {}} { set lib [lindex [glob -nocomplain [file join [pwd] xschem_library * *.sch]] 0] }
set fa [file join $dir a.sch] ; set fb [file join $dir b.sch]
file copy -force $lib $fa ; file copy -force $lib $fb

# --- a helper that makes a REAL second toplevel context, the way wviewer::open does
proc new_top {} {
  set before [winfo children .]
  xschem load_new_window -window {}
  foreach t [winfo children .] {
    if {[lsearch -exact $before $t] >= 0} continue
    if {[winfo exists $t.drw]} { return $t }
  }
  return {}
}

# ===== case 1: the ONLY other window is a viewer ==============================
xschem load $fa
check "V1 the design is loaded in the main window" [expr {[file tail [xschem get current_name]] eq {a.sch}}] \
  "(=> [xschem get current_name])"
set vtop [new_top]
check "V2 a second toplevel was created" [expr {$vtop ne {} && [winfo exists $vtop]}] "(=> $vtop)"
xschem set wave_viewer 1
check "V3 ... and branded a waveform viewer" [expr {[xschem get wave_viewer] == 1}]
catch {xschem new_schematic switch .drw}
check "V4 back in the main window with the design" \
  [expr {[xschem get current_win_path] eq {.drw} && [file tail [xschem get current_name]] eq {a.sch}}] \
  "(=> [xschem get current_win_path] [xschem get current_name])"

xschem exit          ;# == Ctrl-W, closewindow=0
update idletasks
check "V5 the VIEWER TOPLEVEL SURVIVES the close (it was not the swap target)" \
  [expr {[winfo exists $vtop]}] "(=> $vtop exists=[winfo exists $vtop])"
check "V6 the main window did NOT adopt the viewer's context" \
  [expr {[xschem get wave_viewer] == 0}] "(wave_viewer=[xschem get wave_viewer])"
check "V7 the main window is a cleared schematic, not the viewer's buffer" \
  [expr {[xschem get current_win_path] eq {.drw}}] "(=> [xschem get current_win_path])"
# ⚠ AND THE CLOSE MUST ACTUALLY CLOSE. Refusing to swap is only half an answer: the
# caller has to notice and take the CLEAR arm instead, or Ctrl-W silently does nothing
# and the schematic the user asked to close is still sitting there. This is the row that
# proves the guard in scheduler.c's exit arm carries weight -- without it swap_tabs
# declines, the follow-up destroy of the primary window is itself refused, and a.sch
# survives its own close.
# (the cleared buffer comes back as untitled-1.sch, not untitled.sch: the viewer already
# holds the plain `untitled.sch` name, so xschem iterates -- which is the right behaviour
# and is why this asserts the FAMILY rather than one literal name.)
check "V7b the schematic really WAS closed -- the window is blank, not still a.sch" \
  [expr {[string match {untitled*} [file tail [xschem get current_name]]]}] "(=> [xschem get current_name])"

# ===== case 2: POSITIVE TWIN -- a real second schematic IS still swapped in ====
# The guard must skip viewers, not stop swapping. Without this row a fix that simply
# never swaps would pass every check above.
catch {xschem new_schematic switch $vtop.drw}
catch {xschem new_schematic destroy $vtop.drw}
update idletasks
catch {xschem new_schematic switch .drw}
xschem load $fa
set stop [new_top]
check "V8 a second REAL schematic window exists" [expr {$stop ne {} && [winfo exists $stop]}] "(=> $stop)"
xschem load $fb
check "V9 ... holding b.sch, and it is NOT branded a viewer" \
  [expr {[file tail [xschem get current_name]] eq {b.sch} && [xschem get wave_viewer] == 0}] \
  "(=> [xschem get current_name] wv=[xschem get wave_viewer])"
catch {xschem new_schematic switch .drw}
xschem exit
update idletasks
check "V10 closing a.sch DOES pull the other real schematic into the main window" \
  [expr {[file tail [xschem get current_name]] eq {b.sch}}] "(=> [xschem get current_name])"
check "V11 ... and the now-empty sub-window is gone" [expr {![winfo exists $stop]}] "(=> $stop exists=[winfo exists $stop])"

puts [expr {$::fail == 0 ? "RESULT: ALL PASS (12 checks)" : "RESULT: $::fail FAILED"}]
flush stdout
exit [expr {$::fail != 0}]
