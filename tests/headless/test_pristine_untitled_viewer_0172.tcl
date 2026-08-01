# A waveform-viewer buffer must never be a "pristine untitled" reuse target (issue 0172).
#
# `is_pristine_untitled()` (src/scheduler.c) decides whether an open loads INTO the
# current buffer or opens a new window/tab. It tested only currsch / modified /
# instances / wires / basename -- and an ASE waveform-viewer window satisfies every
# one of them PERMANENTLY by construction:
#
#   * it is a top-level buffer (currsch == 0) named `untitled.sch`;
#   * its content is graph RECTS, so instances == 0 and wires == 0;
#   * `wviewer::with_edit` (contract D1) ends every mutation with `xschem set_modify 0`
#     before restoring readonly, so `modified` is 0 for the buffer's whole life. A
#     viewer never ages out of "pristine" the way a scratch buffer does the moment the
#     user draws in it.
#
# So a real schematic was loaded INTO the live viewer, destroying its graph rects, while
# the window kept its WaveViewer bindtag, viewer menubar and `wviewer::windows` registry
# entry -- after which `Ctrl-D` (wviewer::clear_all) wipes the loaded schematic, `u`
# drives the viewer's snapshot stack against a document it knows nothing about, and
# `Ctrl-E` strips `markers=` from its graph rects. See
# doc/claude/issues/0172-viewer-buffer-hijacked-by-pristine-untitled-reuse.md
#
# THIS REPRODUCES HEADLESS. `is_pristine_untitled()` never looks at the viewer, only at
# the buffer's SHAPE, so a buffer shaped like a viewer's is hijacked identically with no
# Tk, no DISPLAY and no `wviewer::open`. Pre-fix, measured:
#
#     before  rects2=1 inst=0 wires=0 modified=0 readonly=1 ntabs=0 sch=untitled.sch
#     after   rects2=0 inst=1 wires=1                        ntabs=0 sch=real.sch
#
# `ntabs` never moved and the graph rect is GONE: the schematic was loaded into the
# viewer's buffer. That is the whole defect.
#
# The fix is inside `is_pristine_untitled()` itself, so it closes all THREE doors at
# once -- `load_new_window <file>`, `load_new_window` via the file dialog, and the
# `xschem load -gui` routing the CIW rewrites a typed load into. Two of those three are
# gated on `has_x`, so only the first is reachable under --nogui; the shared-predicate
# fix is what makes the headless leg a guard on all of them. `test_load_window_routing`
# (needs X) covers the -gui door end to end.
#
# Two mechanisms, deliberately:
#   1. a per-context C flag `wave_viewer`, stamped by `wviewer::open` next to readonly /
#      no_grid / no_snap / graph_snap_cursor. The honest oracle: a viewer is excluded
#      because it IS a viewer, not because of what it happens to contain.
#   2. "pristine" hardened to mean actually EMPTY -- no rects on any layer, no lines,
#      polygons, arcs or texts either, not just no instances and no wires. A buffer with
#      content in it was never a safe reuse target, flag or no flag.
#
# `readonly` is deliberately NOT the guard (leg R): this branch opens ordinary
# schematics read-only in several places (descend read-only, the reopen shortcuts) and a
# read-only buffer is not in itself a bad reuse target.
#
# COVERAGE (2026-07-31 follow-up). Every clause of the predicate now has legs that go
# red when that clause alone is neutralised -- measured by rebuilding with each one
# constant-false in turn (table in the issue doc):
#
#   wave_viewer  -> F5 F6          modified   -> W-win W-tab M1
#   instances    -> S20 S21        wires      -> S17 S18
#   texts        -> S4 S5          rects      -> S1 S2
#   lines        -> S8 S9          polygons   -> S11 S12      arcs -> S14 S15
#   loop bound (`i < cadlayers`) -> S8 S9 S11 S12 S14 S15, because those legs place
#     their object on the TOP layer (sized from `xschem get cadlayers`, not hard-coded);
#     with the bound cut to 3 they all go red while the layer-2 legs stay green.
#   untitled basename -> test_pristine_untitled_basename UT1 (not this file).
#   currsch != 0 -> NOTHING goes red: an unreachable-in-practice clause, since a
#     descended buffer is named after a real file and the basename clause refuses it
#     anyway. Pre-existing, left alone, recorded rather than faked.
#
# Run either arm (X not required):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_pristine_untitled_viewer_0172.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_pristine_untitled_viewer_0172.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}

set here [file dirname [file normalize [info script]]]
source [file join $here scratch.tcl]
set scratch [test_scratch pristine_untitled_0172]

# A real schematic to open: two wires, so "did it land here?" is unambiguous.
#
# ONE FILE PER BLOCK, never a shared one (trap: `new_schematic create` switches to the
# window that already holds an open file instead of creating a new one, so a second block
# opening the SAME path can find no new window and read exactly like the defect). Under X
# that is not hypothetical: with every block sharing one real.sch the W-win fixture leg
# failed 3 runs out of 3 (and the pre-extension version 1 in 3) with `other=.drw
# main=.drw` -- no second window to swap with. Headless it never showed.
proc mkreal {tag} {
  global scratch
  set f [file join $scratch "real_$tag.sch"]
  set fh [open $f w]
  puts $fh "v {xschem version=3.4.5 file_version=1.2}"
  puts $fh "G {}"
  puts $fh "K {}"
  puts $fh "V {}"
  puts $fh "S {}"
  puts $fh "E {}"
  puts $fh "N 0 0 100 0 {lab=A}"
  puts $fh "N 0 20 100 20 {lab=B}"
  close $fh
  return $f
}

# Reset to ONE window holding a fresh untitled buffer, with every per-context flag this
# test touches cleared. The flags are sticky across `clear force` by design (measured:
# no_grid survives it), so a leg that forgets to clear them poisons the next one.
proc reset {} {
  catch {xschem new_schematic destroy_all {}}
  catch {xschem set no_grid 0}
  catch {xschem set no_snap 0}
  catch {xschem set wave_viewer 0}
  xschem set readonly 0
  xschem clear force
}

# Brand the current buffer as a waveform viewer, the way wviewer::open does
# (src/wave_viewer.tcl): one graph rect on layer 2, modified forced back to 0 (the D1
# with_edit contract), grid and snap off, read-only for the window's life.
proc brand_viewer {{flag 1}} {
  xschem set rectcolor 2
  xschem rect 0 0 100 100 -1 "flags=graph,unlocked" 0
  xschem set_modify 0
  xschem set no_grid 1
  catch {xschem set no_snap 1}
  if {$flag} { catch {xschem set wave_viewer 1} }
  xschem set readonly 1
}

proc tail_of_current {} { return [file tail [xschem get schname]] }

# Wait for the context to follow a freshly created window.
#
# Under X, `load_new_window` creates the toplevel and the context switch lands through Tk
# events, so a leg that reads `current_win_path` on the next line can still see the OLD
# window while `ntabs` has already gone up -- measured 2 runs in 6 (`W-win` fixture and
# `M1`, the two legs whose buffer is `modified`). Headless there are no events, the switch
# is synchronous, and this returns on the first pass. Never used where the leg expects the
# open to be reused IN PLACE (P1, R1): there the window must NOT change, and waiting for a
# change that must not happen would just burn the timeout.
proc wait_switch {oldwin {timeout 2000}} {
  set waited 0
  while {$waited < $timeout} {
    catch {update}
    if {[xschem get current_win_path] ne $oldwin} break
    after 25
    incr waited 25
  }
  catch {update}
  return [xschem get current_win_path]
}

if {[catch {

# ---- F: the flag itself -------------------------------------------------------------
# Pre-fix `xschem get wave_viewer` answers with the EMPTY string (an unknown `get` is
# silently empty, it does not error), so these legs are honest RED, not vacuous.
reset
check "F1 a fresh buffer is not a waveform viewer" \
  [expr {[xschem get wave_viewer] eq "0"}] "(get=[xschem get wave_viewer])"

set setrc [catch {xschem set wave_viewer 1} seterr]
check "F2 `xschem set wave_viewer 1` is accepted" [expr {$setrc == 0}] "(err=$seterr)"
check "F3 the flag round-trips through `xschem get`" \
  [expr {[xschem get wave_viewer] eq "1"}] "(get=[xschem get wave_viewer])"
catch {xschem set wave_viewer 0}
check "F4 the flag clears again" \
  [expr {[xschem get wave_viewer] eq "0"}] "(get=[xschem get wave_viewer])"

# per-context, like no_grid / no_snap: branding one window must not brand another.
reset
catch {xschem set wave_viewer 1}
set vwin [xschem get current_win_path]
xschem load_new_window [mkreal f] ;# not pristine (flagged) -> a new window
set nwin [wait_switch $vwin]
check "F5 branding is per context: the NEW window is not a viewer" \
  [expr {$nwin ne $vwin && [xschem get wave_viewer] eq "0"}] \
  "(vwin=$vwin nwin=$nwin get=[xschem get wave_viewer])"
catch {xschem new_schematic switch $vwin}
# F5/F6 are the legs where the FLAG is load-bearing on its own: the buffer is empty, so
# the emptiness hardening cannot be what refuses the reuse. (A branded buffer that also
# holds a graph rect — V* below, and any real viewer — is refused by either mechanism.)
check "F6 ...and the branded window kept its own buffer" \
  [expr {[xschem get current_win_path] eq $vwin && [xschem get wave_viewer] eq "1" &&
         [string match {untitled*} [tail_of_current]] && [xschem get wires] == 0}] \
  "(win=[xschem get current_win_path] get=[xschem get wave_viewer] sch=[tail_of_current] wires=[xschem get wires])"

# ---- V: THE DEFECT -- a viewer-shaped, viewer-branded buffer ------------------------
reset
brand_viewer
set vwin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
set vreal [mkreal v]
check "V0 the branded buffer looks exactly like is_pristine_untitled()'s target" \
  [expr {[xschem get instances] == 0 && [xschem get wires] == 0 &&
         [xschem get modified] == 0 && [xschem get rects 2] == 1 &&
         [string match {untitled*} [tail_of_current]]}] \
  "(inst=[xschem get instances] wires=[xschem get wires] modified=[xschem get modified] rects2=[xschem get rects 2] sch=[tail_of_current])"

xschem load_new_window $vreal
wait_switch $vwin

check "V1 the open created a NEW window/tab instead of reusing the viewer" \
  [expr {[xschem get ntabs] == $ntabs0 + 1}] "(ntabs $ntabs0 -> [xschem get ntabs])"
check "V2 the schematic landed in that new window" \
  [expr {[xschem get current_win_path] ne $vwin && [tail_of_current] eq [file tail $vreal] &&
         [xschem get wires] == 2}] \
  "(win=[xschem get current_win_path] sch=[tail_of_current] wires=[xschem get wires])"

catch {xschem new_schematic switch $vwin}
check "V3 the viewer window still holds its own buffer" \
  [expr {[xschem get current_win_path] eq $vwin && [string match {untitled*} [tail_of_current]]}] \
  "(win=[xschem get current_win_path] sch=[tail_of_current])"
check "V4 the viewer's graph rect survived" \
  [expr {[xschem get rects 2] == 1 && [xschem get wires] == 0 && [xschem get instances] == 0}] \
  "(rects2=[xschem get rects 2] wires=[xschem get wires] inst=[xschem get instances])"
check "V5 the viewer kept its per-context branding" \
  [expr {[xschem get wave_viewer] eq "1" && [xschem get no_grid] eq "1" &&
         [xschem get readonly] == 1}] \
  "(wave_viewer=[xschem get wave_viewer] no_grid=[xschem get no_grid] readonly=[xschem get readonly])"

# ---- S: viewer SHAPE alone, unbranded -- the "pristine" hardening --------------------
# An old session, a viewer built by something other than wviewer::open, or any buffer a
# script drew into and then set_modify 0 on. Content is content: not a reuse target.
# Scope note: S* proves this for the doors that go through is_pristine_untitled() --
# load_new_window (here) and `xschem load -gui`. It says nothing about ask_new_file(),
# which never consults the predicate and is has_x-gated (see the CG10 legs in
# test_wave_clear_all.tcl, and the door table in the issue doc).
reset
brand_viewer 0                    ;# same shape, NO wave_viewer flag
set swin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
xschem load_new_window [mkreal s1]
wait_switch $swin
check "S1 an unbranded buffer holding a graph rect is not reused either" \
  [expr {[xschem get ntabs] == $ntabs0 + 1 && [xschem get current_win_path] ne $swin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] win=[xschem get current_win_path])"
catch {xschem new_schematic switch $swin}
check "S2 ...and its rect survived" \
  [expr {[xschem get rects 2] == 1 && [xschem get wires] == 0}] \
  "(rects2=[xschem get rects 2] wires=[xschem get wires])"

# same, with a TEXT instead of a rect: "empty" must mean every array, not rects only.
reset
xschem set rectcolor 2
xschem text "note" 0 0 0 0 0.4 0.4 {}
xschem set_modify 0
set twin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
check "S3 the text buffer is otherwise pristine-shaped" \
  [expr {[xschem get texts] == 1 && [xschem get instances] == 0 && [xschem get wires] == 0 &&
         [xschem get modified] == 0}] \
  "(texts=[xschem get texts] modified=[xschem get modified])"
xschem load_new_window [mkreal s3]
wait_switch $twin
check "S4 a buffer holding only a TEXT is not reused" \
  [expr {[xschem get ntabs] == $ntabs0 + 1 && [xschem get current_win_path] ne $twin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] win=[xschem get current_win_path])"
catch {xschem new_schematic switch $twin}
check "S5 ...and its text survived" \
  [expr {[xschem get texts] == 1 && [xschem get wires] == 0}] \
  "(texts=[xschem get texts] wires=[xschem get wires])"

# ---- S6..S15: the OTHER per-layer arrays, on the HIGHEST layer ----------------------
# The predicate scans rects/lines/polygons/arcs over `cadlayers` entries. S1/S2 (a graph
# rect) and S3/S5 (a text) between them covered rects and texts only, both on layer 2 --
# so the line, polygon and arc clauses shipped with NO leg, and nothing proved the loop
# bound was `cadlayers` rather than "whatever layer the legs happen to use". These legs
# place each remaining object type on the TOP layer, sized from `xschem get cadlayers`
# rather than hard-coded, and assert the object is STILL THERE after the open: "a new
# window appeared" alone also happens when the load fails outright.
set toplayer [expr {[xschem get cadlayers] - 1}]
check "S6 the top layer is a real, non-zero layer the older legs do not touch" \
  [expr {$toplayer > 2}] "(cadlayers=[xschem get cadlayers] toplayer=$toplayer)"

# LINE on the top layer (`xschem line` draws on `rectcolor`; draw=0, no X needed).
reset
xschem set rectcolor $toplayer
xschem line 0 0 100 0 -1 {} 0
xschem set_modify 0
set gwin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
check "S7 the line buffer is otherwise pristine-shaped" \
  [expr {[xschem get lines $toplayer] == 1 && [xschem get instances] == 0 &&
         [xschem get wires] == 0 && [xschem get texts] == 0 &&
         [xschem get rects $toplayer] == 0 && [xschem get modified] == 0}] \
  "(lines$toplayer=[xschem get lines $toplayer] modified=[xschem get modified])"
xschem load_new_window [mkreal g]
wait_switch $gwin
check "S8 a buffer holding only a LINE is not reused" \
  [expr {[xschem get ntabs] == $ntabs0 + 1 && [xschem get current_win_path] ne $gwin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] win=[xschem get current_win_path])"
catch {xschem new_schematic switch $gwin}
check "S9 ...and the line survived on layer $toplayer" \
  [expr {[xschem get current_win_path] eq $gwin && [xschem get lines $toplayer] == 1 &&
         [xschem get wires] == 0 && [string match {untitled*} [tail_of_current]]}] \
  "(lines$toplayer=[xschem get lines $toplayer] wires=[xschem get wires] sch=[tail_of_current])"

# POLYGON on the top layer (`xschem polygon` also draws on `rectcolor`).
reset
xschem set rectcolor $toplayer
xschem polygon 0 0 100 0 50 100
xschem set_modify 0
set hwin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
check "S10 the polygon buffer is otherwise pristine-shaped" \
  [expr {[xschem get polygons $toplayer] == 1 && [xschem get instances] == 0 &&
         [xschem get wires] == 0 && [xschem get texts] == 0 &&
         [xschem get lines $toplayer] == 0 && [xschem get modified] == 0}] \
  "(polygons$toplayer=[xschem get polygons $toplayer] modified=[xschem get modified])"
xschem load_new_window [mkreal h]
wait_switch $hwin
check "S11 a buffer holding only a POLYGON is not reused" \
  [expr {[xschem get ntabs] == $ntabs0 + 1 && [xschem get current_win_path] ne $hwin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] win=[xschem get current_win_path])"
catch {xschem new_schematic switch $hwin}
check "S12 ...and the polygon survived on layer $toplayer" \
  [expr {[xschem get current_win_path] eq $hwin && [xschem get polygons $toplayer] == 1 &&
         [xschem get wires] == 0 && [string match {untitled*} [tail_of_current]]}] \
  "(polygons$toplayer=[xschem get polygons $toplayer] wires=[xschem get wires] sch=[tail_of_current])"

# ARC on the top layer (`xschem arc x y r a b layer` takes its layer explicitly).
# The survival assertion needs `xschem get arcs <n>`, which did NOT exist -- an unknown
# `get` answers the empty string with rc 0 (trap 2), so this leg would have been silently
# vacuous. The getter was added next to `rects`/`lines`/`polygons` in the `case 'a'`
# group of `xschem get` (src/scheduler.c); this leg is also its only guard.
reset
xschem arc 0 0 50 0 180 $toplayer
xschem set_modify 0
set awin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
check "S13 the arc buffer is otherwise pristine-shaped, and `get arcs` answers" \
  [expr {[xschem get arcs $toplayer] == 1 && [xschem get instances] == 0 &&
         [xschem get wires] == 0 && [xschem get texts] == 0 &&
         [xschem get rects $toplayer] == 0 && [xschem get modified] == 0}] \
  "(arcs$toplayer=[xschem get arcs $toplayer] modified=[xschem get modified])"
xschem load_new_window [mkreal a]
wait_switch $awin
check "S14 a buffer holding only an ARC is not reused" \
  [expr {[xschem get ntabs] == $ntabs0 + 1 && [xschem get current_win_path] ne $awin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] win=[xschem get current_win_path])"
catch {xschem new_schematic switch $awin}
check "S15 ...and the arc survived on layer $toplayer" \
  [expr {[xschem get current_win_path] eq $awin && [xschem get arcs $toplayer] == 1 &&
         [xschem get wires] == 0 && [string match {untitled*} [tail_of_current]]}] \
  "(arcs$toplayer=[xschem get arcs $toplayer] wires=[xschem get wires] sch=[tail_of_current])"

# ---- S16..S21: the instances/wires clause, with `modified` cleared -------------------
# The ORIGINAL `instances != 0 || wires != 0` clause had no leg either: every other leg
# either leaves the buffer empty or trips a different clause, and once a real schematic
# is loaded the basename clause refuses anyway. Measured by deleting the line: nothing
# went red (Task 2). These two legs are the ones that hold it -- a wire, and an instance,
# in an *untitled* buffer with `modified` forced back to 0, which is exactly the state
# `xschem set_modify 0` (or the viewer's D1 contract) leaves behind.
reset
xschem wire 0 0 100 0
xschem set_modify 0
set dwin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
check "S16 the wire buffer is untitled, unmodified and holds exactly one wire" \
  [expr {[xschem get wires] == 1 && [xschem get instances] == 0 &&
         [xschem get modified] == 0 && [string match {untitled*} [tail_of_current]]}] \
  "(wires=[xschem get wires] modified=[xschem get modified] sch=[tail_of_current])"
xschem load_new_window [mkreal d1]
wait_switch $dwin
check "S17 a buffer holding only a WIRE is not reused" \
  [expr {[xschem get ntabs] == $ntabs0 + 1 && [xschem get current_win_path] ne $dwin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] win=[xschem get current_win_path])"
catch {xschem new_schematic switch $dwin}
check "S18 ...and the wire survived (still 1, not the 2 wires of real.sch)" \
  [expr {[xschem get current_win_path] eq $dwin && [xschem get wires] == 1 &&
         [string match {untitled*} [tail_of_current]]}] \
  "(wires=[xschem get wires] sch=[tail_of_current])"

reset
xschem instance devices/lab_pin.sym 0 0 0 0 {name=l1 lab=A}
xschem set_modify 0
set iwin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
check "S19 the instance buffer is untitled, unmodified and holds exactly one instance" \
  [expr {[xschem get instances] == 1 && [xschem get wires] == 0 &&
         [xschem get modified] == 0 && [string match {untitled*} [tail_of_current]]}] \
  "(inst=[xschem get instances] modified=[xschem get modified] sch=[tail_of_current])"
xschem load_new_window [mkreal d2]
wait_switch $iwin
check "S20 a buffer holding only an INSTANCE is not reused" \
  [expr {[xschem get ntabs] == $ntabs0 + 1 && [xschem get current_win_path] ne $iwin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] win=[xschem get current_win_path])"
catch {xschem new_schematic switch $iwin}
check "S21 ...and the instance survived" \
  [expr {[xschem get current_win_path] eq $iwin && [xschem get instances] == 1 &&
         [xschem get wires] == 0 && [string match {untitled*} [tail_of_current]]}] \
  "(inst=[xschem get instances] wires=[xschem get wires] sch=[tail_of_current])"

# ---- P: THE BEHAVIOUR THAT MUST NOT CHANGE -----------------------------------------
# A genuinely pristine untitled scratch buffer is still consumed in place: that is the
# specced editor behaviour (doc/claude/specs/load_window_routing.md), not an accident.
reset
set pwin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
set preal [mkreal p]
check "P0 the buffer is genuinely empty" \
  [expr {[xschem get instances] == 0 && [xschem get wires] == 0 && [xschem get texts] == 0 &&
         [xschem get rects 2] == 0 && [xschem get modified] == 0}] \
  "(rects2=[xschem get rects 2] texts=[xschem get texts])"
xschem load_new_window $preal
check "P1 a pristine untitled buffer is STILL reused in place (no new window)" \
  [expr {[xschem get ntabs] == $ntabs0 && [xschem get current_win_path] eq $pwin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] win=[xschem get current_win_path])"
check "P2 ...and it now holds the opened schematic" \
  [expr {[tail_of_current] eq [file tail $preal] && [xschem get wires] == 2}] \
  "(sch=[tail_of_current] wires=[xschem get wires])"

# ---- R: read-only is NOT the guard --------------------------------------------------
# Deliberate scope decision: refusing reuse for every read-only buffer would also fix
# 0172, but this branch opens ordinary schematics read-only (descend read-only, the
# reopen shortcuts) and those buffers are still fair reuse targets. If this leg ever
# flips, it was a decision, not a regression.
reset
xschem set readonly 1
set rwin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
set rreal [mkreal r]
xschem load_new_window $rreal
check "R1 a read-only but genuinely pristine untitled buffer is still reused" \
  [expr {[xschem get ntabs] == $ntabs0 && [xschem get current_win_path] eq $rwin &&
         [tail_of_current] eq [file tail $rreal]}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] sch=[tail_of_current])"

# ---- W: closing the MAIN window must not brand the surviving editor canvas ----------
# `xschem exit` on .drw with another window/tab open calls swap_windows() (windowed) or
# swap_tabs() (tabbed), which swap the two contexts BETWEEN slots and then re-swap
# top_path / current_win_path / window so the surviving document lands on .drw. The
# per-context flags travel with the DOCUMENT, but the viewer's Tk identity (WaveViewer
# bindtags, viewer menubar) stays on the widget -- so without the flag being swapped back
# the ordinary editor canvas came out branded `wave_viewer 1` for the rest of the
# session, and .drw could then never be a pristine-untitled reuse target again. Measured
# both ways: pre-fix `.drw` answered 1 here and P1's reuse stopped happening on it.
foreach {tag tabbed} {W-win 0 W-tab 1} {
  reset
  set ::tabbed_interface $tabbed
  set main [xschem get current_win_path]
  # the main buffer must be NON-pristine, or the open is reused in place and there is no
  # second window to swap with -- and `xschem exit force` with none would exit the process
  xschem set_modify 1
  xschem load_new_window [mkreal $tag]
  set other [wait_switch $main]
  if {$other eq $main} {
    check "$tag fixture: a second window/tab exists to swap with" 0 "(other=$other main=$main)"
  } else {
    catch {xschem set wave_viewer 1}    ;# brand the SECOND one, like wviewer::open does
    catch {xschem new_schematic switch $main}
    xschem set_modify 0                 ;# no save prompt on the close
    xschem exit force                   ;# closes .drw -> swap_windows() / swap_tabs()
    catch {xschem new_schematic switch $main}
    check "$tag the surviving .drw canvas is NOT branded a viewer" \
      [expr {[xschem get current_win_path] eq $main && [xschem get wave_viewer] eq "0"}] \
      "(win=[xschem get current_win_path] wave_viewer=[xschem get wave_viewer] swapped-from=$other)"
  }
}
set ::tabbed_interface 0

# ---- M: control -- proves the "a new window appeared" witness can actually fail ------
# `modified` ALONE, with nothing drawn: drawing something would also trip the emptiness
# hardening, and the leg would then pass without ever witnessing the `modified` clause
# it is named for.
reset
xschem set_modify 1
set mwin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
check "M0 the buffer is modified" [expr {[xschem get modified] == 1}] \
  "(modified=[xschem get modified])"
xschem load_new_window [mkreal m]
wait_switch $mwin
check "M1 a MODIFIED buffer is not reused (pre-existing behaviour, unchanged)" \
  [expr {[xschem get ntabs] == $ntabs0 + 1 && [xschem get current_win_path] ne $mwin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs])"

} err]} { puts "FATAL: $err" ; incr fail }

# Trap 1: a wrong `xschem get <thing>` aborts the script and every leg after it
# "passes" by never running. 41 is the full count -- if the banner says fewer, legs
# were skipped, whatever they printed.
if {$npass + $fail != 41} {
  puts "FAIL: leg count is [expr {$npass + $fail}], expected 41 -- legs were skipped"
  incr fail
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
