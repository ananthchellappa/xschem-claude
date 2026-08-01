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
set real [file join $scratch real.sch]
set fh [open $real w]
puts $fh "v {xschem version=3.4.5 file_version=1.2}"
puts $fh "G {}"
puts $fh "K {}"
puts $fh "V {}"
puts $fh "S {}"
puts $fh "E {}"
puts $fh "N 0 0 100 0 {lab=A}"
puts $fh "N 0 20 100 20 {lab=B}"
close $fh

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
xschem load_new_window $real      ;# not pristine (flagged) -> a new window
set nwin [xschem get current_win_path]
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
check "V0 the branded buffer looks exactly like is_pristine_untitled()'s target" \
  [expr {[xschem get instances] == 0 && [xschem get wires] == 0 &&
         [xschem get modified] == 0 && [xschem get rects 2] == 1 &&
         [string match {untitled*} [tail_of_current]]}] \
  "(inst=[xschem get instances] wires=[xschem get wires] modified=[xschem get modified] rects2=[xschem get rects 2] sch=[tail_of_current])"

xschem load_new_window $real

check "V1 the open created a NEW window/tab instead of reusing the viewer" \
  [expr {[xschem get ntabs] == $ntabs0 + 1}] "(ntabs $ntabs0 -> [xschem get ntabs])"
check "V2 the schematic landed in that new window" \
  [expr {[xschem get current_win_path] ne $vwin && [tail_of_current] eq "real.sch" &&
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
xschem load_new_window $real
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
xschem load_new_window $real
check "S4 a buffer holding only a TEXT is not reused" \
  [expr {[xschem get ntabs] == $ntabs0 + 1 && [xschem get current_win_path] ne $twin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] win=[xschem get current_win_path])"
catch {xschem new_schematic switch $twin}
check "S5 ...and its text survived" \
  [expr {[xschem get texts] == 1 && [xschem get wires] == 0}] \
  "(texts=[xschem get texts] wires=[xschem get wires])"

# ---- P: THE BEHAVIOUR THAT MUST NOT CHANGE -----------------------------------------
# A genuinely pristine untitled scratch buffer is still consumed in place: that is the
# specced editor behaviour (doc/claude/specs/load_window_routing.md), not an accident.
reset
set pwin [xschem get current_win_path]
set ntabs0 [xschem get ntabs]
check "P0 the buffer is genuinely empty" \
  [expr {[xschem get instances] == 0 && [xschem get wires] == 0 && [xschem get texts] == 0 &&
         [xschem get rects 2] == 0 && [xschem get modified] == 0}] \
  "(rects2=[xschem get rects 2] texts=[xschem get texts])"
xschem load_new_window $real
check "P1 a pristine untitled buffer is STILL reused in place (no new window)" \
  [expr {[xschem get ntabs] == $ntabs0 && [xschem get current_win_path] eq $pwin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs] win=[xschem get current_win_path])"
check "P2 ...and it now holds the opened schematic" \
  [expr {[tail_of_current] eq "real.sch" && [xschem get wires] == 2}] \
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
xschem load_new_window $real
check "R1 a read-only but genuinely pristine untitled buffer is still reused" \
  [expr {[xschem get ntabs] == $ntabs0 && [xschem get current_win_path] eq $rwin &&
         [tail_of_current] eq "real.sch"}] \
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
  xschem load_new_window $real
  set other [xschem get current_win_path]
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
xschem load_new_window $real
check "M1 a MODIFIED buffer is not reused (pre-existing behaviour, unchanged)" \
  [expr {[xschem get ntabs] == $ntabs0 + 1 && [xschem get current_win_path] ne $mwin}] \
  "(ntabs $ntabs0 -> [xschem get ntabs])"

} err]} { puts "FATAL: $err" ; incr fail }

# Trap 1: a wrong `xschem get <thing>` aborts the script and every leg after it
# "passes" by never running. 25 is the full count -- if the banner says fewer, legs
# were skipped, whatever they printed.
if {$npass + $fail != 25} {
  puts "FAIL: leg count is [expr {$npass + $fail}], expected 25 -- legs were skipped"
  incr fail
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
