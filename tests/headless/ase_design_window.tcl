#
#  File: ase_design_window.tcl   -- test helper, not shipped
#
#  This file is part of XSCHEM,
#  a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
#  simulation.
#  Copyright (C) 1998-2023 Stefan Frederik Schippers
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#
# ---------------------------------------------------------------------------
# BIND THE DESIGN WINDOW BEFORE THE FIRST ase::netlist (issue 0698).
#
# THE DEFECT THIS RETIRES. test_ase_final, test_ase_final_gf180 and test_ase_core
# all passed under --nogui and ABORTED under X, and that asymmetry was carried in
# crew briefs as a warning rather than fixed -- folklore, which is exactly what a
# test suite is supposed to replace. Measured 2026-08-25 on :99: 78/33/172 checks
# ALL PASS headless; 1 FAILED (9 passed) / (10 passed) / (103 passed) under X,
# every one of them dying on the same refusal from ase::netlist.
#
# WHICH SIDE IS WRONG: THE SUITE. src/ase.tcl:848-874 guards its netlist with
# three arms -- (a) the design already IS the current schematic, netlist in
# place; (b) headless, self-load then netlist; (c) a display exists and some
# OTHER schematic is current, clean error. Arm (c) is CORRECT and deliberate: a
# GUI window may hold unsaved edits and reloading over it would destroy them.
# The suites simply never opened the design window that arm (a) documents (the
# product's own Session > Design Window flow), so under X they walked into (c).
# Nothing in src/ moves for this; the guard is also adjacent to the OPEN 0683 /
# 0684 ruling and must not be pre-empted.
#
# GATED ON has_x, NOT UNCONDITIONAL. src/xinit.c:3135-3138 sets ::has_x to "1"
# only inside `if(has_x)` and nothing ever unsets it, so `[info exists ::has_x]`
# is precisely "a display is available" (doctrine restated at src/ase.tcl:100).
# Binding unconditionally would work, and would silently stop exercising arm (b)
# -- the headless self-load would never again be reached by any suite. So the
# headless arm keeps testing the guard, and the X arm tests the GUI flow.
#
# THE PATH COMES FROM `xschem cellview_path`, the SAME accessor ase::netlist
# compares against (src/ase.tcl:862). Re-deriving a <lib>/<cell>/<view>/<cell>.sch
# shape here would be a second builder of one path, which is how a caller and a
# guard drift into disagreeing about which file "the design" is.
#
# ORDERING IS LOAD-BEARING, and the trap is quiet. Call this AFTER the suite has
# installed its scratch library.defs and inside its own catch. Bound earlier, the
# symbol resolves against the AMBIENT registry, arm (a) then netlists the
# mis-resolved buffer, and the failure surfaces as a wrong XM1 line -- measured
# 77 passed / 1 failed, a red that looks nothing like the one being fixed.
# ---------------------------------------------------------------------------

# Make the state's design cellview the current schematic when a display exists.
# No-op headless. Returns the normalized path it bound, or {} if it did nothing.
proc ase_bind_design_window {state} {
  if {![info exists ::has_x]} { return {} }
  set design [ase::state_get $state design]
  if {$design eq {} || ![dict exists $design lib] || ![dict exists $design cell]} {
    return -code error "ase_bind_design_window: state has no usable design"
  }
  set view schematic
  if {[dict exists $design view] && [dict get $design view] ne {}} {
    set view [dict get $design view]
  }
  set path [xschem cellview_path [dict get $design lib]/[dict get $design cell] $view]
  if {$path eq {}} {
    return -code error "ase_bind_design_window: cannot resolve\
 [dict get $design lib]/[dict get $design cell] view '$view'"
  }
  set path [file normalize $path]
  if {[file normalize [xschem get schname]] ne $path} { xschem load $path }
  return $path
}

# ---------------------------------------------------------------------------
# RUN A NEGATIVE-PATH LEG THAT WOULD OTHERWISE POP A MODAL DIALOG (issue 0803).
#
# src/xschem.tcl:352 `execute` reports a failed launch two ways: `puts stderr`
# always, and -- only `if {[info exists has_x]}` -- a MODAL tk_messageBox with an
# OK button. That dialog is right for a user and fatal for a suite: nobody clicks
# it, so a test whose whole point is "the binary is missing" HANGS FOREVER under
# X instead of failing.
#
# MEASURED 2026-08-25 on :99, and only visible because the 0698 bind above let
# test_ase_core reach the leg at all: 121 checks pass, then the suite hangs at
# E2 (`ase_definitely_missing_binary_xyz`) with `Proc execute error:` as its last
# line. It does not time out and it does not fail; it sits there. Headless the
# same leg is 3.5 seconds and green.
#
# So the dialog is suppressed for the DURATION OF ONE LEG, not the suite: a
# blanket suppression would silently swallow a dialog some other leg is entitled
# to raise. Restored on every exit path including the error path, and the
# script's own result/error is passed through untouched -- the leg is still
# asserting on the clean `ase:` error it always did, in BOTH arms, with the same
# check count. Headless this is a bare uplevel: there is no Tk, nothing to
# suppress, and the caller must see no difference.
# ---------------------------------------------------------------------------
proc ase_no_modal {script} {
  if {![info exists ::has_x]} { return [uplevel 1 $script] }
  if {[info commands ::tk_messageBox] eq {}} { return [uplevel 1 $script] }
  rename ::tk_messageBox ::ase_no_modal_saved_mb
  proc ::tk_messageBox {args} { return ok }
  set rc [catch {uplevel 1 $script} res opts]
  rename ::tk_messageBox {}
  rename ::ase_no_modal_saved_mb ::tk_messageBox
  return -options $opts $res
}
