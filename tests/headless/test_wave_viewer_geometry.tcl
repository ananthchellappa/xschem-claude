# The waveform viewer must not share the `untitled.sch` geometry slot, and must
# not open exactly on top of the window it was launched from — issue 0840.
#
#   ./src/xschem --pipe -q --script tests/headless/test_wave_viewer_geometry.tcl
#
# WHAT BROKE, reported by the user: "the schematic window appears to get replaced
# by a Waveform Window". MEASURED on Xvfb + openbox — two mapped toplevels at
# pixel-for-pixel identical geometry:
#
#     NEW .x1  mapped=1  geom=1110x761+404+132  'Waveforms tb_bandgap …'
#     MAIN .   mapped=1  geom=1110x761+404+132  'xschem [3] - tb_bandgap.sch'
#
# store_geom/set_geom key a window's saved geometry by `[xschem get
# current_name]`, and the viewer is built on a buffer named `untitled.sch`. So
# the viewer shares ONE slot in $USER_CONF_DIR/geometry with every untitled
# scratch buffer — and the numbers in that slot are THE MAIN WINDOW'S OWN, which
# is why the overlap is exact rather than merely likely:
#
#   1. xschem starts with `untitled.sch` in the main window;
#   2. loading a schematic stores the geometry FIRST — scheduler.c:7656 runs
#      `store_geom [xschem get topwindow] [xschem get current_name]` with
#      current_name still `untitled.sch`, so the MAIN WINDOW's geometry lands in
#      the untitled slot;
#   3. wviewer::open's buffer is `untitled.sch` too, so set_geom hands it back.
#
# So the READ half (group K3) is the load-bearing one. The WRITE half (K1) only
# fires in the non-tabbed window model — under the tabbed interface store_geom
# is main-window-only, which K0 pins so nobody "fixes" K1 by widening it.

set failed 0
set checks 0
proc ck {name cond} {
  global failed checks
  incr checks
  if {[uplevel 1 [list expr $cond]]} { puts "ok:   $name" } else { puts "FAIL: $name"; incr failed }
}

set TMP [file normalize [file join /tmp xschem_wvgeom_[pid]]]
file mkdir $TMP
set ::USER_CONF_DIR $TMP
set GF [file join $TMP geometry]
proc geomfile {} { global GF
  if {![file exists $GF]} { return {} }
  set f [open $GF]; set d [read $f]; close $f; return $d
}

# ------------------------------------------------------------------- group G
# geom_key: the identity question, asked of the TOPLEVEL PATH. store_geom runs
# from C at moments when the current context belongs to somebody else, so a
# per-context flag cannot answer "whose window is this".
set ::wviewer::windows [dict create tok/a [dict create top .zz1 win_path .zz1.drw]]
ck "G1  a registered viewer toplevel gets the viewer key" \
   {[wviewer::geom_key .zz1] eq {__waveviewer__}}
ck "G2  POSITIVE TWIN: an ordinary toplevel gets {} — no false positives, so\
 every non-viewer window keeps its own filename key" \
   {[wviewer::geom_key .] eq {} && [wviewer::geom_key .zz9] eq {}}
ck "G3  and {} for an empty path" \
   {[wviewer::geom_key {}] eq {}}

# ------------------------------------------------------------------- group K
# The key swap, both halves, without needing a real viewer window.
if {[info exists ::has_x]} {
  toplevel .zz1 ; wm geometry .zz1 300x200+10+10 ; update idletasks
  toplevel .zz9 ; wm geometry .zz9 300x200+20+20 ; update idletasks

  # K0 first, because it is why K1 needs its own window model. Under the TABBED
  # interface store_geom writes only for `.`; a non-main window is a silent
  # no-op. Pinned so a later reader does not "fix" K1 by widening store_geom.
  set _saved_tabbed $::tabbed_interface
  set ::tabbed_interface 1
  catch {file delete $GF}
  store_geom .zz1 untitled.sch
  ck "K0  under the TABBED interface store_geom is main-window-only, so a\
 viewer never writes this slot at all — the READ half is what fixes the bug" \
     {[geomfile] eq {}}

  set ::tabbed_interface 0
  catch {file delete $GF}
  store_geom .zz1 untitled.sch
  ck "K1  in the NON-tabbed model a viewer stores under the viewer key, NOT\
 untitled.sch (else it would move the next File > New window)" \
     {[string match {*__waveviewer__*} [geomfile]] &&
      ![string match {*untitled.sch*} [geomfile]]}

  # POSITIVE TWIN: an ordinary window is untouched by all of this.
  catch {file delete $GF}
  store_geom .zz9 untitled.sch
  ck "K2  POSITIVE TWIN: a NON-viewer window still stores under its real\
 filename" \
     {[string match {*untitled.sch*} [geomfile]] &&
      ![string match {*__waveviewer__*} [geomfile]]}
  set ::tabbed_interface $_saved_tabbed

  # the read half: a viewer must ignore an untitled.sch entry and read its own
  set fd [open $GF w]
  puts $fd "untitled.sch 111x111+7+7"
  puts $fd "__waveviewer__ 222x222+9+9"
  close $fd
  set_geom .zz1 untitled.sch
  update idletasks
  ck "K3  THE LOAD-BEARING ROW: set_geom on a viewer reads the VIEWER slot and\
 ignores untitled.sch — which holds the MAIN WINDOW's own geometry" \
     {[wm geometry .zz1] eq {222x222+9+9}}
  set_geom .zz9 untitled.sch
  update idletasks
  ck "K4  POSITIVE TWIN: set_geom on a non-viewer still reads untitled.sch" \
     {[wm geometry .zz9] eq {111x111+7+7}}

  # ----------------------------------------------------------------- group U
  # uncover: the deterministic backstop for the FIRST open, when no viewer
  # geometry is stored and placement falls to the window manager.
  wm geometry .zz1 400x300+100+100
  wm geometry .zz9 400x300+100+100
  update idletasks
  ck "U1  exact congruence is broken — the reported defect" \
     {[wviewer::uncover .zz1 .zz9] == 1 && [wm geometry .zz1] ne [wm geometry .zz9]}
  ck "U1b and the SIZE is preserved; only the position moves" \
     {[string match {400x300+*} [wm geometry .zz1]]}

  wm geometry .zz1 400x300+300+300
  wm geometry .zz9 400x300+100+100
  update idletasks
  set g_before [wm geometry .zz1]
  ck "U2  POSITIVE TWIN: a window that is merely NEAR another is LEFT ALONE —\
 congruence is the defect, proximity is not" \
     {[wviewer::uncover .zz1 .zz9] == 0 && [wm geometry .zz1] eq $g_before}

  ck "U3  a missing window is a no-op, not an error" \
     {![catch {wviewer::uncover .nosuch .zz9} r] && $r == 0 &&
      ![catch {wviewer::uncover {} {}} r2] && $r2 == 0}

  # bottom-right corner: step back toward the origin, never off the screen
  set sw [winfo screenwidth .]
  set sh [winfo screenheight .]
  set cx [expr {$sw - 400}]
  set cy [expr {$sh - 300}]
  wm geometry .zz1 400x300+$cx+$cy
  wm geometry .zz9 400x300+$cx+$cy
  update idletasks
  wviewer::uncover .zz1 .zz9
  scan [wm geometry .zz1] {%dx%d+%d+%d} uw uh ux uy
  ck "U4  at the bottom-right corner it steps BACK toward the origin, so the\
 title bar stays reachable" \
     {$ux <= $cx && $uy <= $cy && $ux >= 0 && $uy >= 0 &&
      [wm geometry .zz1] ne [wm geometry .zz9]}

  # ---- U5..U7: what the field log actually showed (2026-08-26) --------------
  # ⚠ ONE PIXEL IS CONGRUENT. Issue 0647's own measurement was 1000x800+13+89
  # against 1000x800+13+90. A string compare calls that "not congruent"; a human
  # calls it "my schematic is gone".
  wm geometry .zz1 400x300+101+100
  wm geometry .zz9 400x300+100+100
  update idletasks
  ck "U5  a ONE-PIXEL offset still counts as covered (issue 0647's own numbers)" \
     {[wviewer::uncover .zz1 .zz9] == 1 && [wm geometry .zz1] ne {400x300+101+100}}

  # ⚠ THE FIELD FAILURE. `wm geometry` reports the REQUESTED geometry until the
  # window is mapped, so deciding at creation time compares a not-yet-placed viewer,
  # sees a difference, and does nothing -- while the WM then places it exactly on top.
  # The user's window_report log caught precisely that: viewer and design both at
  # 1110x761+3597+340, shove never fired. So an unmapped window must DEFER, not decide.
  wm geometry .zz1 400x300+100+100
  wm geometry .zz9 400x300+100+100
  update idletasks
  wm withdraw .zz1
  update idletasks
  set g_unmapped [wm geometry .zz1]
  set rc_unmapped [wviewer::uncover .zz1 .zz9]
  set pending 0
  foreach id [after info] {
    set scr {} ; catch {set scr [lindex [after info $id] 0]}
    if {[string match {*wviewer::uncover*} $scr]} { set pending 1 }
  }
  ck "U6  an UNMAPPED window DEFERS instead of deciding, and schedules a retry" \
     {$rc_unmapped == 0 && $pending == 1}

  wm deiconify .zz1
  wm geometry .zz1 400x300+100+100
  update
  set moved 0
  for {set t 0} {$t < 2000} {incr t 60} {
    update
    after 60
    if {[wm geometry .zz1] ne {400x300+100+100}} { set moved 1 ; break }
  }
  ck "U7  ... and once it IS mapped the deferred shove fires" {$moved == 1}

  destroy .zz1 ; destroy .zz9
} else {
  puts "SKIP: no X connection (has_x=0) — groups K and U need real toplevels"
}

set ::wviewer::windows [dict create]
file delete -force $TMP
puts "test_wave_viewer_geometry: $checks checks"
if {$failed} { puts "RESULT: $failed FAILED" } else { puts "RESULT: ALL PASS" }
xschem exit closewindow force
