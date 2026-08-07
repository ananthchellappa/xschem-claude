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

# --- TP14: browser_level_names — R3's OWN-LEVEL selector ---------------------
#
# ⚠ THIS IS A SECOND PROC AND NOT A CHANGE TO `browser_leaf_names`, and that is
# ruling R6, not an accident. `browser_leaf_names` is RECURSIVE BY CONTRACT (its
# own header: "a group answers with every leaf beneath it, however deep") and
# the driver explicitly kept it that way: plotting everything under a block is
# how you find what is coupling into a signal you can see a kink on. MEASURED on
# tb_bandgap's `x1`: own-level 43, recursive 406. Two questions, two procs.
check {TP14 browser_level_names x1 -> only the signals AT x1, not below it} \
  [pcall ::wviewer::browser_level_names $tp_ents x1] \
  [list {v(x1.net1)} {i(v.x1.v1)}]
check {TP14 the ROOT level is the empty path — top-level signals} \
  [pcall ::wviewer::browser_level_names $tp_ents {}] [list {v(vbg)}]
check {TP14 a deeper level answers only for itself} \
  [pcall ::wviewer::browser_level_names $tp_ents x1.xr1.x0] \
  [list {v(x1.xr1.x0.t1)} {i(@r.x1.xr1.x0.r0[i])}]
# ⚠ A PURE ANCESTOR IS LEGITIMATELY EMPTY, and it must be `{}` rather than a
# throw or an error string. MEASURED: 18 of tb_bandgap's 128 nodes and 25 of
# tb_charge_pump's 316 own no signals at all — they exist only because a
# descendant does. §7.2 makes that state legible in the status line; here it
# just has to be an ANSWER.
check {TP15 a PURE ANCESTOR (x1.xr1) answers {} — an answer, not an error} \
  [pcall ::wviewer::browser_level_names $tp_ents x1.xr1] {}
check {TP15 a path that does not exist at all also answers {}} \
  [pcall ::wviewer::browser_level_names $tp_ents nosuch.node] {}
# ⚠ CASE-INSENSITIVE, and this is not decoration: ngspice lowercases, so the raw
# says `x1.x2` while the schematic says `X1`. Item 12's whole hierarchy sync
# turns on this (spec §10.3-10.4: exact-first, then -nocase, and the FINAL
# VERIFY must be -nocase too or a correct walk of `x1.x2` lands on `x1.X2` and
# is rejected by its own verify).
check {TP16 the level match is CASE-INSENSITIVE (X1 finds x1)} \
  [pcall ::wviewer::browser_level_names $tp_ents X1] \
  [list {v(x1.net1)} {i(v.x1.v1)}]
# ...and its control: a name that differs by more than case must NOT match.
check {TP16 positive control — x2 is not x1} \
  [pcall ::wviewer::browser_level_names $tp_ents x2] {}

# --- TP17-TP19: browser_label — R8's Cadence labels --------------------------
#
# ⚠⚠ THE INSTANCE HALF IS *NOT* SIMPLY THE LAST PATH SEGMENT. The spec said so
# in its first draft and its own worked examples contradicted it:
# `i(@c.x1.c1[i])` has last path segment `x1`, which gives `x1:i`, not the
# `c1:i` the table demands. Both rules were run over all 2656 corpus names:
#
#   last path segment  -> reproduces 6 of 7 spec rows, 29 label COLLISIONS
#   the hybrid (below) -> reproduces 7 of 7,            0 collisions
#
# THE RULE: the instance half is the LEAF'S BASE, unless that base is
# MODEL-SHAPED (contains `_`), in which case it is the LAST PATH SEGMENT.
# sky130 names the device inside a pcell wrapper after its model
# (`msky130_fd_pr__nfet_01v8`), so there the wrapper `xm1` is the instance the
# user drew; a discrete `c1`/`r1`/`q1` has no wrapper and IS its own instance.
# TP18 and TP19 are the two halves, and neither proves the rule alone.
proc tp_lbl {n} { return [pcall ::wviewer::browser_label [pcall ::wviewer::signal_entry $n]] }

# Voltages render BARE. The discriminator is `class net AND type ne i` -- NOT
# type alone, because a device internal node has type `v` and must not render
# bare (TP18's third leg is that oracle).
check {TP17 a top-level voltage renders bare}        [tp_lbl {v(vbg)}]      vbg
check {TP17 a hierarchical voltage renders its LEAF} [tp_lbl {v(x1.adj)}]   adj
# ⚠ a REAL design net ending in `#` renders BARE -- it is a net, not a device
# node (the 0217:44 backward trap, one layer up from DC25).
check {TP17 a real auto-named net ending in # renders bare} \
  [tp_lbl {v(x2.x1.a_27_47#)}] {a_27_47#}
check {TP17 the sweep variable renders bare (M8: not special-cased)} \
  [tp_lbl {time}] time

# Currents render <instance>:<param>.
check {TP18 a TOP-LEVEL source current -> v1:i} [tp_lbl {i(v1)}] {v1:i}
check {TP18 an INTERNAL source branch current -> v1:i} [tp_lbl {i(v.x1.v1)}] {v1:i}
# ⚠ THE MODEL-SHAPED LEG: the leaf is the model name, so the instance is the
# pcell WRAPPER one level up.
check {TP18 a device measurement -> the WRAPPER, not the model} \
  [tp_lbl {i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])}] {xm1:id}
check {TP18 a device internal NODE -> wrapper:#node, and NOT bare} \
  [tp_lbl {v(m.x1.xm1.msky130_fd_pr__nfet_01v8#body)}] {xm1:#body}
# ⚠ THE DISCRETE LEG -- the one the first rule got wrong. `c1` has no `_`, so it
# is its own instance and the path segment `x1` must NOT be used.
check {TP19 a discrete capacitor current -> c1:i, NOT x1:i} \
  [tp_lbl {i(@c.x1.c1[i])}] {c1:i}
check {TP19 a discrete resistor current -> r0:i, NOT x0:i} \
  [tp_lbl {i(@r.x2.xr4.x0.r0[i])}] {r0:i}
# every param observed in the corpus passes through verbatim -- only nine exist
# ([id] 356, [i] 114, [current] 11, [vth] 3, [is]/[ie]/[ic]/[ib] 2 each, [vbe] 2,
# [gm] 1) so no translation table is needed or wanted.
check {TP19 the param passes through verbatim (gm, not a translated name)} \
  [tp_lbl {i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[gm])}] {xm1:gm}
# ⚠ one leading `@` is stripped: 25 corpus names are untagged single-segment
# @-forms (11 in cmos_ac_sweep) and would otherwise render `@ibias:current`.
check {TP19 a leading @ is stripped from the instance half} \
  [tp_lbl {i(@ibias[current])}] {ibias:current}
# The FULL raw name stays reachable -- the label is a DISPLAY, never an identity.
# Two signals CAN render to the same label; every gesture resolves through the
# row index into this value, and the tooltip shows it.
check {TP19 browser_label_full returns the untouched raw name} \
  [pcall ::wviewer::browser_label_full \
     [pcall ::wviewer::signal_entry {i(@c.x1.c1[i])}]] {i(@c.x1.c1[i])}

# ⚠⚠ THE MEASURED COLLISION, PINNED SO IT IS DOCUMENTED BEHAVIOUR RATHER THAN A
# SURPRISE. Running this rule over all 2656 corpus names gives EXACTLY FOUR
# label collisions within one own-level node, and all four are the same shape:
# an element's `@`-form device measurement and its bare branch current render
# identically. Measured instances: `i(@be5[i])`/`i(be5)` in tb_bandgap_opamp,
# `i(@l1[i])`/`i(l1)` and `i(@l2[i])`/`i(l2)` in tb_ft_test_2, `i(@l1[i])`/`i(l1)`
# in test_ac.
#
# ⚠ The batch plan claimed this rule collides ZERO times. It does not — it
# collides four times, and the difference matters because a collision is only
# harmless while the label is a DISPLAY. Every gesture resolves through the row
# INDEX into browser_label_full, and TP19's `_full` check above is what keeps
# that true. Declared limit 2 in the spec.
check {TP19 the measured collision pair renders identically — declared, not fixed} \
  [list [tp_lbl {i(@be5[i])}] [tp_lbl {i(be5)}]] [list {be5:i} {be5:i}]
check {TP19 ...but their FULL names stay distinct, which is what gestures use} \
  [list [pcall ::wviewer::browser_label_full [pcall ::wviewer::signal_entry {i(@be5[i])}]] \
        [pcall ::wviewer::browser_label_full [pcall ::wviewer::signal_entry {i(be5)}]]] \
  [list {i(@be5[i])} {i(be5)}]

# --- TP20-TP26 are the flow arithmetic (M2/R3) — PURE, no canvas needed ------
#
# ⚠ THESE ARE NUMBERED IN THE PURE BAND ON PURPOSE. The flow is the one part of
# a canvas megawidget that CAN be tested without a display, and testing it here
# is what stops the X-arm checks having to prove arithmetic and geometry at the
# same time. Only the drawing needs Tk.
#
# Column-major: fill a column top to bottom, then start the next to the RIGHT.
# itemsPerColumn comes from the pane's height, so dragging the sash reflows.
check {TP20 flow_layout 10 items, rowh 20, pane 100 -> 5 per column, 2 columns} \
  [pcall ::wviewer::browser_flow_layout 10 20 100] [list 5 2]
check {TP20 a partial last column still counts as a column} \
  [pcall ::wviewer::browser_flow_layout 11 20 100] [list 5 3]
check {TP21 zero items -> 0 columns, and it does not divide by zero} \
  [pcall ::wviewer::browser_flow_layout 0 20 100] [list 5 0]
# ⚠ A PANE TOO SHORT FOR ONE ROW MUST STILL YIELD ONE PER COLUMN, or every
# subsequent division is by zero. IconList's own Arrange does this
# (/usr/share/tcltk/tk8.6/iconlist.tcl:370-373) and it is the reason it does.
check {TP21 a pane shorter than one row still gives 1 per column} \
  [pcall ::wviewer::browser_flow_layout 3 20 5] [list 1 3]
check {TP21 a zero-height pane does not divide by zero either} \
  [pcall ::wviewer::browser_flow_layout 3 20 0] [list 1 3]

# cell placement: index -> {x y}, column-major.
check {TP22 index 0 -> the origin}          [pcall ::wviewer::browser_flow_cell 0 5 80 20] [list 0 0]
check {TP22 index 4 -> bottom of column 0}  [pcall ::wviewer::browser_flow_cell 4 5 80 20] [list 0 80]
check {TP22 index 5 -> TOP of column 1 (column-major, not row-major)} \
  [pcall ::wviewer::browser_flow_cell 5 5 80 20] [list 80 0]
check {TP22 index 9 -> bottom of column 1}  [pcall ::wviewer::browser_flow_cell 9 5 80 20] [list 80 80]

# ⚠ HIT-TESTING IS ARITHMETIC, NOT `find closest`. IconList uses `find closest`,
# which is O(n) in canvas items AND cannot miss -- it always returns SOMETHING,
# so a click in the gutter between columns silently selects a neighbour. The
# grid is regular, so `col*itemsPerColumn + row` is O(1) and can honestly answer
# "nothing here". TP24 is that check and it is the whole reason for diverging.
check {TP23 a hit inside cell 0}            [pcall ::wviewer::browser_flow_hit 3 3 5 80 20 10] 0
check {TP23 a hit inside cell 5 (column 1)} [pcall ::wviewer::browser_flow_hit 83 3 5 80 20 10] 5
check {TP23 a hit inside the last cell}     [pcall ::wviewer::browser_flow_hit 83 83 5 80 20 10] 9
# ⚠ THE MISS CASES. Each is a DIFFERENT way to be outside, and `find closest`
# gets all three wrong in the same silent way.
check {TP24 below the last row of a full column -> MISS, not the nearest cell} \
  [pcall ::wviewer::browser_flow_hit 3 105 5 80 20 10] -1
check {TP24 right of the last column -> MISS} \
  [pcall ::wviewer::browser_flow_hit 200 3 5 80 20 10] -1
check {TP24 past the last item in a PARTIAL column -> MISS} \
  [pcall ::wviewer::browser_flow_hit 83 63 5 80 20 8] -1
check {TP24 positive control — the cell just before it IS a hit} \
  [pcall ::wviewer::browser_flow_hit 83 43 5 80 20 8] 7
check {TP24 negative coordinates -> MISS, never a wrapped index} \
  [list [pcall ::wviewer::browser_flow_hit -5 3 5 80 20 10] \
        [pcall ::wviewer::browser_flow_hit 3 -5 5 80 20 10]] [list -1 -1]

# ⚠ THE SCROLLREGION'S HEIGHT IS CLAMPED TO THE PANE, and that clamp is the
# ENTIRE mechanism behind R3's "horizontal scrollbar only". Let the height be
# the content height and Tk gives the canvas a vertical range to scroll, which
# is the one thing R3 forbids. IconList clamps it the same way
# (iconlist.tcl:359-368).
check {TP25 the scrollregion width is ncols*colw, height CLAMPED to the pane} \
  [pcall ::wviewer::browser_flow_scrollregion 3 80 100] [list 0 0 240 100]
check {TP25 an empty pane still has a valid, non-degenerate scrollregion} \
  [pcall ::wviewer::browser_flow_scrollregion 0 80 100] [list 0 0 0 100]
# ⚠ THE SABOTAGE ORACLE for the clamp: content taller than the pane must NOT
# raise the scrollregion's height.
check {TP26 content taller than the pane does NOT grow the scrollregion height} \
  [lindex [pcall ::wviewer::browser_flow_scrollregion 1 80 100] 3] 100

# --- TP27-TP33 — item 2: browser_rows gains `root` and `anypath` -------------
#
# R2: the tree has EXACTLY ONE root node, named for the design, and it is
# selected when the browser opens. That root is a GROUP ROW whose id is `g:`
# (the empty prefix) — chosen so the SHIPPED two-character strip in
# `browser_target_path` decodes it to the empty path, i.e. the legitimate
# sim-root ascend, with zero change to that proc. (`r:` and `root:` were both
# rejected: `root:` decodes to `ot:`.)
#
# ⚠ BOTH NEW ARGUMENTS ARE OPTIONAL, and that is what keeps BT10-BT13, BD19,
# BD22 and BX01-BX08 green BY CONSTRUCTION — every shipped caller passes a bare
# list. TP27's first check is the standing guard on exactly that, and it must be
# green from the first run and never move.

# ⚠ NEVER `foreach` A `pcall` RESULT WITHOUT THIS GUARD. `pcall` answers the
# STRING `ERR:<msg>` on a throw, and `dict get` on a word of that string throws
# again — into the file's outer catch, deleting every remaining check. The item-9
# sabotage runs measured that exact shape: 17 of 34 checks ran and the file
# printed a plausible `3 FAILED`. "The row list could not be computed" is
# therefore its own assertable value here, distinct from "an empty row list".
proc tp_rowsig {rows} {
  if {[string match {ERR:*} $rows]} { return $rows }
  set out {}
  foreach w $rows {
    if {[catch {dict get $w id} id]} { return NOT-A-ROW-LIST }
    lappend out "$id|[dict get $w parent]|[dict get $w text]|[dict get $w kind]"
  }
  return $out
}
proc tp_parent_of {rows id} {
  if {[string match {ERR:*} $rows]} { return $rows }
  foreach w $rows {
    if {[catch {dict get $w id} rid]} { return NOT-A-ROW-LIST }
    if {$rid eq $id} { return [dict get $w parent] }
  }
  return no-such-row
}
proc tp_kinds {rows} {
  if {[string match {ERR:*} $rows]} { return $rows }
  set out {}
  foreach w $rows {
    if {[catch {dict get $w kind} k]} { return NOT-A-ROW-LIST }
    lappend out $k
  }
  return $out
}
proc tp_ids {rows} {
  if {[string match {ERR:*} $rows]} { return $rows }
  set out {}
  foreach w $rows {
    if {[catch {dict get $w id} i]} { return NOT-A-ROW-LIST }
    lappend out $i
  }
  return $out
}

# THE FROZEN SHIPPED PROJECTION. Spelled out rather than digested: a digest that
# changed would say only "something moved", and the whole value of this check is
# naming WHAT. Built with `list` so its string form is canonical and the
# comparison cannot fail on whitespace instead of on content.
set tp_frozen [list \
  {g:x1||x1|group} \
  {s:v(x1.net1)|g:x1|net1|leaf} \
  {g:x1.xm1|g:x1|xm1|group} \
  {s:v(m.x1.xm1.mod#body)|g:x1.xm1|mod#body|leaf} \
  {s:i(@m.x1.xm1.mod[id])|g:x1.xm1|mod[id]|leaf} \
  {g:x1.xr1|g:x1|xr1|group} \
  {g:x1.xr1.x0|g:x1.xr1|x0|group} \
  {s:v(x1.xr1.x0.t1)|g:x1.xr1.x0|t1|leaf} \
  {s:i(@r.x1.xr1.x0.r0[i])|g:x1.xr1.x0|r0[i]|leaf} \
  {s:i(v.x1.v1)|g:x1|v1|leaf} \
  {s:v(vbg)||v(vbg)|leaf}]
check {TP27 (STANDING CONTROL) with NO root arg the row list is byte-identical
       to the shipped one — every existing caller is unchanged} \
  [tp_rowsig [pcall ::wviewer::browser_rows $tp_ents]] $tp_frozen

set tp_rooted [pcall ::wviewer::browser_rows $tp_ents tb_bandgap]
check {TP27 a root arg mints ONE row, id `g:`, parent {}, kind group, text the design} \
  [lindex $tp_rooted 0] \
  {id g: parent {} text tb_bandgap kind group name {}}
check {TP27 ...and it is exactly ONE extra row, prepended} \
  [list [llength $tp_rooted] [llength [pcall ::wviewer::browser_rows $tp_ents]]] {12 11}

# ⚠ THE DISCRIMINATING PAIR. An implementation that re-parents only the GROUPS
# passes the first leg and fails the second: `v(vbg)` has an EMPTY path, so it
# never enters the group-minting loop and keeps whatever parent it was seeded
# with. R2 says top-level SIGNALS are the root's own-level signals, so it must
# hang off the root too.
check {TP28 BOTH a former top-level group AND a former top-level LEAF hang off it} \
  [list [tp_parent_of $tp_rooted {g:x1}] [tp_parent_of $tp_rooted {s:v(vbg)}]] \
  {g: g:}
check {TP28 ...while a DEEPER row's parent is untouched} \
  [tp_parent_of $tp_rooted {g:x1.xr1.x0}] {g:x1.xr1}

# The behavioural consequence, and the reason TP28's second leg matters: R6's
# recursive plot on the ROOT must reach every name, including the top-level one.
# A root that adopted only the groups answers SIX here, not seven, and nothing
# else in the file would notice.
check {TP29 (R6, BEHAVIOURAL) browser_leaf_names on the root reaches EVERY name} \
  [pcall ::wviewer::browser_leaf_names $tp_rooted {g:}] \
  [tp_names_of $tp_ents]
check {TP29 (CONTROL) ...while g:x1 still answers only its own subtree (6 of 7)} \
  [llength [pcall ::wviewer::browser_leaf_names $tp_rooted {g:x1}]] 6
check {TP29 the root row is a GROUP, so browser_kind, browser_plot_at's
       `!$groups` guard and browser_menu_ids need no new vocabulary} \
  [pcall ::wviewer::browser_kind $tp_rooted {g:}] group

# R4 needs something to select AT ALL TIMES, including on an inventory that
# matched nothing. The no-root call is the control: without it this check is
# green on a proc that emits a root unconditionally, which would red BT10, BD19
# and BX01 in three other files.
check {TP30 an EMPTY inventory still emits the root — and without a root arg, nothing} \
  [list [llength [pcall ::wviewer::browser_rows {} tb_bandgap]] \
        [llength [pcall ::wviewer::browser_rows {}]]] {1 0}

# --- the `anypath` override (M6) ---------------------------------------------
#
# ⚠⚠ MEASURED, AND IT CONTRADICTS M6's STATED REMEDY IN ONE DIRECTION.
# The flat/hierarchical choice is gated PER ENTRY on `$anypath && $path ne {}`,
# so an entry with an EMPTY path takes the flat branch whatever the gate says.
# Therefore:
#   * forcing the gate to 0 on a PATHED set really does flatten it — groups gone,
#     full raw names as row text. That is the ONE observable direction, TP31.
#   * forcing it to 1 on a set whose entries all have empty paths changes
#     NOTHING — there are no segments to mint. TP32 pins that as a VALUE rather
#     than leaving it as an assumption, because M6's stated failure mode ("9 of
#     22 designs flip to flat mode if the gate is computed after the class
#     filter") cannot arise: when the filter leaves no pathed entry the rows are
#     identical either way, and when it leaves one the auto-gate already answers
#     1. Recorded here, not silently relied on.
set tp_p1   [list [pcall ::wviewer::signal_entry {v(x1.net5)}] \
                  [pcall ::wviewer::signal_entry {v(out)}]]
set tp_pre  [list [pcall ::wviewer::signal_entry {v(out)}] \
                  [pcall ::wviewer::signal_entry {v(m.x1.xm1.mod#body)}]]
set tp_post [pcall ::wviewer::browser_class_filter $tp_pre 0 1]

check {TP31 (FIXTURE CONTROL) the filter really does strip every PATHED entry} \
  [list [llength $tp_pre] [llength $tp_post] \
        [pcall dict get [lindex $tp_post 0] path]] {2 1 {}}
check {TP31 the gate FORCED 0 flattens a pathed set: no group rows, full raw text} \
  [list [tp_kinds [pcall ::wviewer::browser_rows $tp_p1 {} 0]] \
        [tp_rowsig [pcall ::wviewer::browser_rows $tp_p1 {} 0]]] \
  {{leaf leaf} {s:v(x1.net5)||v(x1.net5)|leaf s:v(out)||v(out)|leaf}}
check {TP31 (CONTROL) ...and with the gate AUTO the same set is hierarchical} \
  [list [tp_kinds [pcall ::wviewer::browser_rows $tp_p1]] \
        [tp_parent_of [pcall ::wviewer::browser_rows $tp_p1] {s:v(x1.net5)}]] \
  {{group leaf leaf} g:x1}
check {TP31 the override composes with the root: forced 0, the flat leaves still
       hang off `g:`} \
  [tp_parent_of [pcall ::wviewer::browser_rows $tp_p1 design 0] {s:v(x1.net5)}] {g:}
check {TP32 forcing the gate on a PATH-FREE set is a measured NO-OP, BOTH ways} \
  [list [expr {[tp_rowsig [pcall ::wviewer::browser_rows $tp_post {} 1]] eq \
               [tp_rowsig [pcall ::wviewer::browser_rows $tp_post]]}] \
        [expr {[tp_rowsig [pcall ::wviewer::browser_rows $tp_post {} 0]] eq \
               [tp_rowsig [pcall ::wviewer::browser_rows $tp_post]]}]] {1 1}
# ⚠ a NON-INTEGER anypath must fall back to the auto-computation, never be
# treated as false — `{}` is the default and it is not an integer.
check {TP32 a non-integer gate falls back to AUTO, it does not read as 0} \
  [tp_kinds [pcall ::wviewer::browser_rows $tp_p1 {} {}]] {group leaf leaf}

# --- browser_rows_multi threads the root (item 15's caller depends on it) -----
#
# The unlabelled group is the CURRENT DB: it stays flat and unprefixed, so its
# root is `g:`. A LABELLED group goes through browser_rows_reparent, which
# re-keys `g:` to `d:0|g:` and re-parents the root row (whose parent is {}) onto
# the DB header. That is what makes one design root PER DB possible without an
# id collision — and a shared `g:` THROWS in ttk (`Item ... already exists`).
set tp_multi [pcall ::wviewer::browser_rows_multi \
                [list [list {} {} $tp_ents] \
                      [list {d:0} {bd_a.raw (tran)} \
                        [list [pcall ::wviewer::signal_entry {v(x1.alpha)}]]]] \
                tb_bandgap]
check {TP33 the CURRENT DB's root is unprefixed and first} \
  [lindex [tp_rowsig $tp_multi] 0] {g:||tb_bandgap|group}
check {TP33 ...a FOREIGN DB gets its own root, prefixed, under its header} \
  [list [tp_parent_of $tp_multi {d:0|g:}] [tp_parent_of $tp_multi {d:0|g:x1}]] \
  {d:0 d:0|g:}
# ⚠ THIS CHECK WAS VACUOUS IN ITS FIRST FORM AND THE RED RUN IS WHAT SHOWED IT.
# Spelled `[llength [lsort -unique $ids]] == [llength $rows]`, it compared the
# `ERR:wrong # args` STRING against itself and went GREEN before the code
# existed. Naming the duplicates AND pinning the row count makes both halves
# assertable: the error string has neither 16 rows nor an empty duplicate set.
proc tp_dupes {ids} {
  if {[string match {ERR:*} $ids]} { return $ids }
  set out {} ; array set n {}
  foreach i $ids { if {[info exists n($i)]} { lappend out $i } ; set n($i) 1 }
  return $out
}
check {TP33 ...and every id in the rooted multi list is UNIQUE — a shared `g:`
       THROWS in ttk (`Item ... already exists`) on the searchbar's key pump} \
  [list [tp_dupes [tp_ids $tp_multi]] [llength [tp_ids $tp_multi]]] {{} 16}
# BD19's LOCAL TWIN and the guard that the multi arg is optional too.
check {TP33 (STANDING CONTROL) with no root, one unlabelled group == browser_rows} \
  [tp_rowsig [pcall ::wviewer::browser_rows_multi [list [list {} {} $tp_ents]]]] \
  [tp_rowsig [pcall ::wviewer::browser_rows $tp_ents]]

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

wvbs_finish
