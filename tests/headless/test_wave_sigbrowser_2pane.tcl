# tests/headless/test_wave_sigbrowser_2pane.tcl — the TWO-PANE Signal Browser.
# Spec: doc/claude/specs/waveform_signal_browser_two_pane.md.
# Parent spec: doc/claude/specs/waveform_signal_browser.md (the single-pane
# browser this rebuilds). Prerequisite defect: issue 0217 (FIXED, item 1).
#
# ⚠⚠ WHY THIS IS A NEW FILE AND NOT AN EXTENSION OF test_wave_sigbrowser.tcl.
# Ruling 30: every design-window-coupled item gets its OWN PROCESS. The rule was
# not written for tidiness — at 489 checks the merged browser file was killed
# mid-run by WSLg in 9 of 9 runs with ZERO check failures, which made every
# later item's verification unmeasurable while the file still printed a
# plausible-looking count. test_wave_sigbrowser.tcl already carries ~135
# `--nogui` + ~189 X-arm checks; the two-pane work is a NEW FOOTPRINT AXIS (a
# real viewer holding a panedwindow, a canvas and a tree at once), and ruling
# 30's own guidance is to measure a new axis over >=6 runs before appending it
# to an existing group rather than assuming it is free.
#
# GROUP PREFIX: `TP`, never reused. Numbers are BLOCKED by arm, matching the
# convention declared at test_wave_sigbrowser.tcl:41-42:
#   01-19  source greps and PURE Tcl        — BOTH arms
#   20-39  the throwaway toplevel fixture   — Tk/X only
#   40-59  the REAL viewer                  — Tk/X only
#
# ⚠ THE ARM STATEMENT. The `--nogui` arm runs TP01-TP19 only. Every claim about
# geometry, flow, scrolling, selection or gestures needs real Tk, so A GREEN
# `--nogui` RUN PROVES NOTHING ABOUT THE PANES THEMSELVES — only about the pure
# row/class logic underneath them.
#
# ⚠ SKIP-BANNER WORDING IS LOAD-BEARING. X-gated groups print
# `SKIPPED: <group> (Tk/X arm only)`. NEVER `RESULT: SKIP`, never
# `skipped: no X`, never `SKIP: no X connection` — full_audit.sh's `is_skip`
# matches those three strings and would score the WHOLE FILE as SKIP, silently
# discarding every check that did run.
#
# `check`, `check_true`, `pcall`, the counting `::bgerror`, `wvproc_body`,
# `bs_packed`, `bs_order`, `bs_wait_mapped`, `send_key`, `viewer_ready`, `$wsrc`
# and `wvbs_finish` come from `tests/headless/wvbs_common.tcl`, which is
# deliberately NOT named `test_*.tcl` (full_audit.sh selects cases with
# `ls test_*.tcl`, so a prelude with that name would run as a case, report zero
# checks, print no RESULT line and score FAIL forever).
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_2pane.tcl
#   env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_2pane.tcl

set ::wvbs_tag  wvsigbrowser_2pane
set ::wvbs_name test_wave_sigbrowser_2pane
source [file join [file dirname [info script]] wvbs_common.tcl]

if {[catch {

# ============================================================================
# TP01-TP19 — THE PURE LAYER: signal class -> what the panes may show
# ============================================================================
#
# ⚠⚠ THE FIXTURE IS THE WHOLE POINT OF THIS BLOCK, so it is spelled out rather
# than generated. It is a MINIATURE OF THE REAL CORPUS, and every entry earns
# its place by discriminating a rule that a plausible wrong implementation gets
# wrong:
#
#   v(x1.net1)              net        x1            a design net at x1
#   v(m.x1.xm1.mod#body)    devnode    x1.xm1        a MOSFET internal node
#   i(@m.x1.xm1.mod[id])    devmeas    x1.xm1        a device measurement
#   v(x1.xr1.x0.t1)         net        x1.xr1.x0     ⚠ THE MIXED NODE
#   i(@r.x1.xr1.x0.r0[i])   devmeas    x1.xr1.x0     ⚠ ...sharing its level
#   i(v.x1.v1)              srcbranch  x1            a source inside x1
#   v(vbg)                  net        {}            a top-level net
#
# ⚠ `x1.xr1.x0` IS THE ENTRY THAT KILLS THE OBVIOUS IMPLEMENTATION. sky130
# pcell-wraps MOSFETs but NOT capacitors, and resistor/bipolar parasitic
# sub-devices sit at a level SHARED with real nets — measured, 32 such signals
# across 5 of the 22 corpus designs. A "hide every node that has any device
# signal under it" rule deletes `x1.xr1.x0` and takes the real net `t1` with it.
# Spec §3.3's rule is `EVERY signal at or under it`, and TP11 is its oracle.
#
# ⚠ AND `x1.xm1` IS THE ENTRY THAT KILLS THE OPPOSITE MISTAKE — a rule that
# only ever hides a LEAF-level node, or that requires the node to have no
# children, would keep it. TP10 is that oracle.

set tp_names {
  {v(x1.net1)}
  {v(m.x1.xm1.mod#body)}
  {i(@m.x1.xm1.mod[id])}
  {v(x1.xr1.x0.t1)}
  {i(@r.x1.xr1.x0.r0[i])}
  {i(v.x1.v1)}
  {v(vbg)}
}
set tp_ents {}
foreach tp_n $tp_names { lappend tp_ents [pcall ::wviewer::signal_entry $tp_n] }

proc tp_classes {ents} {
  set r {}
  foreach e $ents { lappend r [pcall dict get $e class] }
  return $r
}
proc tp_names_of {ents} {
  set r {}
  foreach e $ents { lappend r [pcall dict get $e name] }
  return $r
}

# --- TP01-TP04: sig_is_device, the predicate every consumer shares -----------
#
# It exists so `devnode`/`devmeas` is written down ONCE. Two call sites that
# each spell out the set drift the first time a class is added, and the drift is
# invisible: the tree and the signal list simply start disagreeing about what a
# device is, which reads as a display bug rather than a logic one.
check {TP01 sig_is_device devnode -> 1}   [pcall ::wviewer::sig_is_device devnode]   1
check {TP02 sig_is_device devmeas -> 1}   [pcall ::wviewer::sig_is_device devmeas]   1
# ⚠ srcbranch is NOT a device class. It is governed by its OWN checkbox (R11b),
# because a source you placed inside a subcircuit to measure a current is a
# thing you drew, not a thing the model generated. Fold it in here and the two
# checkboxes collapse into one and R11 is silently unimplemented.
check {TP03 sig_is_device srcbranch -> 0} [pcall ::wviewer::sig_is_device srcbranch] 0
check {TP04 sig_is_device net -> 0}       [pcall ::wviewer::sig_is_device net]       0

# --- TP05: the fixture itself, asserted before anything is built on it -------
# A fixture that silently classified wrongly would make every check below
# vacuous while they all still passed.
check {TP05 (FIXTURE) the seven entries carry the expected classes} \
  [tp_classes $tp_ents] \
  [list net devnode devmeas net devmeas srcbranch net]

# --- TP06-TP09: browser_class_filter, the two independent checkboxes ---------
#
# R11: (a) `Show device internals` defaults OFF; (b) `Show source currents`
# defaults ON. The two are INDEPENDENT — all four combinations are pinned,
# because a filter wired as a single tri-state passes any three of them.
check {TP06 devint 1 srccur 1 -> everything, in the SAME order (7)} \
  [tp_names_of [pcall ::wviewer::browser_class_filter $tp_ents 1 1]] \
  [tp_names_of $tp_ents]
check {TP07 devint 0 srccur 1 -> the DEFAULT: no devnode, no devmeas (4)} \
  [tp_names_of [pcall ::wviewer::browser_class_filter $tp_ents 0 1]] \
  [list {v(x1.net1)} {v(x1.xr1.x0.t1)} {i(v.x1.v1)} {v(vbg)}]
check {TP08 devint 1 srccur 0 -> no srcbranch (6)} \
  [tp_names_of [pcall ::wviewer::browser_class_filter $tp_ents 1 0]] \
  [list {v(x1.net1)} {v(m.x1.xm1.mod#body)} {i(@m.x1.xm1.mod[id])} \
        {v(x1.xr1.x0.t1)} {i(@r.x1.xr1.x0.r0[i])} {v(vbg)}]
check {TP09 devint 0 srccur 0 -> design nets only (3)} \
  [tp_names_of [pcall ::wviewer::browser_class_filter $tp_ents 0 0]] \
  [list {v(x1.net1)} {v(x1.xr1.x0.t1)} {v(vbg)}]
# ⚠ ORDER IS PRESERVED, AND A PASS-THROUGH DOES NOT PROVE IT. D7: "row order"
# means RAW-FILE order, not the tree's visual order, and every gesture
# downstream resolves an INDEX into this list — so a filter built on a dict, or
# ending in `lsort -unique`, keeps every count check green while silently
# reordering the user's plots.
#
# TP06 only exercises the `devint && srccur -> return $entries` fast path, which
# cannot reorder anything; it therefore proves NOTHING about the real loop. This
# check runs a filter that actually DROPS entries and asserts the survivors are
# not in sorted order — measured: `lsort` of TP07's result is
# {i(v.x1.v1) v(vbg) v(x1.net1) v(x1.xr1.x0.t1)}, a different list.
set tp_f07 [tp_names_of [pcall ::wviewer::browser_class_filter $tp_ents 0 1]]
check {TP09 a filter that DROPS entries still does not sort the survivors} \
  [expr {$tp_f07 ne [lsort $tp_f07]}] 1

# --- TP10-TP13: browser_device_paths, spec §3.3 ------------------------------
#
# Returns the dotted paths of nodes the TREE hides while R11(a) is off. The rule
# is `EVERY signal at or under it is device-classed`.
#
# ⚠ THE `x` PREFIX IS NOT A DISCRIMINATOR AND MUST NOT BE USED AS ONE. MEASURED
# over the 22-raw corpus: ALL 85 distinct post-declass path segments begin with
# `x`, because sky130 wraps its MOSFETs in pcell SUBCIRCUITS — so `xm1` is
# grammatically a real X-instance and lexically indistinguishable from `x2`. The
# class tag captured at declass time is the only evidence. TP12 pins that.
# ⚠⚠ MEMBERSHIP MUST NOT BE ASSERTED WITH A BARE `lsearch`, AND THIS HELPER IS
# WHY. `pcall` turns a missing proc into the STRING `ERR:invalid command name
# ...`, and `lsearch` on that string returns -1 — so every ABSENCE check below
# would pass VACUOUSLY against code that does not exist. Caught by running this
# file before the procs were written: four checks went green on nothing.
# Making "the set could not be computed" its own assertable value is the fix,
# and it is the same rule the batch already paid for twice: assert on the
# WORLD, never on "the command returned without throwing".
proc tp_in {ents p} {
  set s [pcall ::wviewer::browser_device_paths $ents]
  if {[string match {ERR:*} $s]} { return $s }
  return [expr {[lsearch -exact $s $p] >= 0}]
}

check {TP10 x1.xm1 is a device node — every signal under it is device-classed} \
  [tp_in $tp_ents x1.xm1] 1
# ⚠ THE MIXED-NODE ORACLE (see the fixture note). x1.xr1.x0 carries a real net
# AND a device measurement at the SAME level.
check {TP11 x1.xr1.x0 is NOT a device node — it carries a real net too} \
  [tp_in $tp_ents x1.xr1.x0] 0
# ...and its ANCESTOR must survive with it, or the net is unreachable anyway.
check {TP11 x1.xr1 is NOT a device node either — a real net is under it} \
  [tp_in $tp_ents x1.xr1] 0
check {TP12 the whole device-path set is exactly {x1.xm1}} \
  [lsort [pcall ::wviewer::browser_device_paths $tp_ents]] [list x1.xm1]
# ⚠ POSITIVE CONTROL for TP11/TP12: remove the one real net at x1.xr1.x0 and the
# node MUST become a device node. Without this, TP11 would also pass on an
# implementation that never classifies anything as a device.
set tp_ents_nonet {}
foreach tp_e $tp_ents {
  if {[pcall dict get $tp_e name] ne {v(x1.xr1.x0.t1)}} { lappend tp_ents_nonet $tp_e }
}
check {TP12 positive control — drop the real net and x1.xr1.x0 IS a device node} \
  [lsort [pcall ::wviewer::browser_device_paths $tp_ents_nonet]] \
  [list x1.xm1 x1.xr1 x1.xr1.x0]
# `x1` itself has a design net at its own level and must never be hidden.
check {TP13 x1 is never a device node — it owns a design net} \
  [tp_in $tp_ents x1] 0
# An empty inventory is an ANSWER, not an error — and it must not throw, or it
# deletes every check after it in this file.
check {TP13 browser_device_paths {} -> {} and does not throw} \
  [pcall ::wviewer::browser_device_paths {}] {}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

wvbs_finish
