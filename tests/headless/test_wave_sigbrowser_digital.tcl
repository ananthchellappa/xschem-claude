# tests/headless/test_wave_sigbrowser_digital.tcl — §F items F1 and F5 of
# doc/claude/specs/mixed_signal_signal_browser.md, THE VIEWER HALF.
#
# Ctrl-Alt-V on a code block scopes the Signal Browser to that instance's
# DIGITAL database (F1), and when there is no digital data to show it says WHY
# instead of leaving a blank pane (F5).
#
# ⚠⚠ WHY THIS FILE EXISTS SEPARATELY FROM test_ase_cosim.tcl's FV GROUP. FV
# proves the BRANCH — which cell enters it, which sentence each cause produces,
# and that the design is read before the viewer is raised — and every one of
# those claims is pure Tcl, so FV lives in the `--nogui` arm where it can never
# be killed by a display. What FV cannot reach is the other half: a treeview, a
# checkbutton, a canvas and a status label. `wviewer::browser_show_db_scope` and
# `wviewer::browser_notice` touch all four, so a green `--nogui` run proves
# NOTHING about them. That is this file, and it is Tk/X only by construction.
#
# GROUP PREFIX: `FD`, never reused (FV is the engine-arm twin in
# test_ase_cosim.tcl).
#
# ⚠ SKIP-BANNER WORDING IS LOAD-BEARING. The X-gated group prints
# `SKIPPED: <group> (Tk/X arm only)`. NEVER `RESULT: SKIP`, never
# `skipped: no X`, never `SKIP: no X connection` — full_audit.sh's `is_skip`
# matches those three strings and would score the WHOLE FILE as SKIP, silently
# discarding every check that did run.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_digital.tcl

set ::wvbs_tag  wvsigbrowser_digital
set ::wvbs_name test_wave_sigbrowser_digital
source [file join [file dirname [info script]] wvbs_common.tcl]

proc fd_wr {path body} {
  file mkdir [file dirname $path]
  set fp [::open $path w]; puts -nonewline $fp $body; ::close $fp
}

# the mkraw/mkvcd idiom of test_ase_cosim.tcl — a valid ASCII ngspice raw and a
# valid VCD in fifteen lines each, so this file runs no simulator.
proc fd_mkraw {path} {
  set body "Title: test\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: 3\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n"
  append body "Values:\n0\t0.0\n\t0.0\n\n1\t1e-09\n\t1.0\n\n2\t2e-09\n\t0.5\n\n"
  fd_wr $path $body
}
proc fd_mkvcd {path} {
  fd_wr $path "\$timescale 1ps \$end
\$scope module TOP \$end
 \$scope module m \$end
  \$var wire 1 ! siga \$end
  \$var wire 1 # sigb \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
0#
#100
1!
1#
#200
"
}

# ⚠ THE SINGLE-LETTER TOP SCOPE, AND IT IS THE WHOLE OF RULING F4's EVIDENCE.
# `module m` is legal Verilog and `$scope module m` is legal VCD; the name that
# comes out is `m.sub.sig`, which ngspice's device-class grammar reads as "the
# internal node `sub.sig` of MOSFET `m`". A four-bit bus rides along because
# `count[3]` is the OTHER shape the analog label formatter destroys.
proc fd_mkvcd_m {path} {
  fd_wr $path "\$timescale 1ps \$end
\$scope module m \$end
 \$scope module sub \$end
  \$var wire 1 ! sig \$end
  \$var wire 4 # count \[3:0\] \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
b0000 #
#100
1!
b0001 #
#200
"
}

# --- source-arm checks (BOTH arms) -------------------------------------------
# The formatter rule this file's X arm then exercises: the eleventh outcome
# sentence is spelled in browser_msg and NOWHERE else, exactly as the tenth is.
check {FD01 (SOURCE) the digital branch's outcome sentence is spelled once, in
       the one formatter} \
  [list [regexp -all {every results database to reach} $wsrc] \
        [regexp -all {every results database to reach} \
           [wvproc_body $wsrc wviewer::browser_msg]]] \
  [list 1 1]
# ⚠ THE NOTICE IS A RENDERER: it must not know any cause. A `switch` on a code
# inside it would be a second author of F5's sentence, free to drift from the
# resolver's (RULING 5f-3).
check {FD02 (SOURCE) browser_notice composes nothing — no cause code, no switch} \
  [regexp -all {nomap|notraced|notloaded|noscope|switch} \
     [wvproc_body $wsrc wviewer::browser_notice]] 0
# and the notice's lifetime: set in one place, cleared in one place
check {FD03 (SOURCE) the notice is cleared by the sea refresh and set by the
       notice writer, one site each} \
  [list [regexp -all {set browserseanote\(\$token\) \{\}} \
           [wvproc_body $wsrc wviewer::browser_sea_refresh]] \
        [regexp -all {set browserseanote\(\$token\) \$msg} \
           [wvproc_body $wsrc wviewer::browser_notice]] \
        [regexp -all {browserseanote} [wvproc_body $wsrc wviewer::browser_sea_draw]]] \
  [list 1 1 4]

# =============================================================================
# FD30-FD39 — SPEC §F ITEM F4: A DIGITAL NAME IS ITS OWN SIGNAL CLASS.
# BOTH ARMS: every claim here is pure Tcl over `wviewer`'s classifier, its two
# class boxes, its label formatter and its row builder, so none of it needs a
# display and none of it may be lost when one dies.
#
# ⚠⚠ THE RULING IN ONE SENTENCE, because every check below is a leg of it: the
# `class` field (issue 0217 Ruling A) gains a FIFTH value, `digital`, minted from
# the DATABASE a name came from and never from the name's shape; it is not a
# device class, so Ruling B's default-off `Show device internals` box does not
# touch it; and the two panes still RELOCATE analog noise exactly as they did,
# because nothing an analog raw produces changes value.
#
# ⚠⚠ WHY REUSING `net` WAS NOT AVAILABLE, MEASURED RATHER THAN ARGUED. `sig_declass`
# is sound BY SPICE GRAMMAR ONLY — a one-letter path segment cannot be a subckt
# instance because SPICE requires those to begin with `X`. Verilog has no such
# rule. On `m.sub.sig` (from `fd_mkvcd_m`, a legal VCD) the shipped classifier
# answered class `devnode`, path `sub` — the `m` LEVEL DELETED from the tree —
# and label `sig:i`; and because `devnode` is what Ruling B hides by default the
# wire disappeared from the browser altogether, leaving `time` alone in the tree.
# Every FD3x check below has its analog twin in the SAME tuple, so a green here
# is "the two namespaces are told apart", never "the classifier answers digital
# to everything".
# =============================================================================

# THE GATE. `vcd_read()` stamps sim_type "vcd" itself (src/vcd_read.c:831) and is
# the only reader that does, so this one string is the whole test. `<NULL>` is the
# engine's spelling for "no analysis" and must NOT read as digital.
check {FD30 (F4) db_is_digital keys on the engine's own sim_type, case-folded,
       and nothing else answers yes} \
  [list [pcall ::wviewer::db_is_digital vcd] [pcall ::wviewer::db_is_digital VCD] \
        [pcall ::wviewer::db_is_digital { vcd }] \
        [pcall ::wviewer::db_is_digital tran] [pcall ::wviewer::db_is_digital {}] \
        [pcall ::wviewer::db_is_digital {<NULL>}] [pcall ::wviewer::db_is_digital dc]] \
  [list 1 1 1 0 0 0 0]

# THE CLASSIFICATION ITSELF, BOTH DIRECTIONS IN ONE TUPLE. Legs 1-2 are the
# ruling; legs 3-4 are the shipped analog reading of the SAME string, which is
# what makes legs 1-2 a measurement instead of an assertion.
#
# ⚠ EVERY READ GOES THROUGH `pcall`, INCLUDING THE `dict get`. wvbs_common's rule
# is that a sabotage which makes the code under test THROW must fail ONE check,
# not abort the file — and the pre-feature run is exactly that case: with no
# `dbtype` parameter `signal_entry` raises "wrong # args", whose message has an
# ODD word count, so a bare `dict get`/`dict exists` on it throws out of the
# check and kills every check after it. MEASURED: the first cut of this block
# died at FD31 and reported four checks instead of twenty.
proc fd_key {n t k} { return [pcall dict get [pcall ::wviewer::signal_entry $n $t] $k] }
check {FD31 (F4) a VCD name is class `digital` and keeps its top scope; the same
       string read as an ngspice name is still `devnode` with the scope stripped} \
  [list [fd_key {m.sub.sig} vcd class] [fd_key {m.sub.sig} vcd path] \
        [fd_key {m.sub.sig} {} class]  [fd_key {m.sub.sig} {} path]] \
  [list digital {m.sub} devnode {sub}]
# ...and the ordinary Verilator-shaped name, whose class moves even though its
# path never did — the half a path-only check would miss.
check {FD31b (F4) a name whose head is NOT one letter is classed `digital` too,
       so the class follows the DATABASE and not the name's shape} \
  [list [fd_key {TOP.counter.clk} vcd class] [fd_key {TOP.counter.clk} vcd path] \
        [fd_key {TOP.counter.clk} {} class]] \
  [list digital {TOP.counter} net]
# SB10's key set is not allowed to move: `digital` is a VALUE of the shipped
# fifth key, never a sixth key.
check {FD31c (F4) the entry dict gains no key — `digital` is a value of `class`} \
  [pcall lsort [pcall dict keys [pcall ::wviewer::signal_entry {TOP.m.siga} vcd]]] \
  {class leaf name path type}

# RULING B SURVIVES, AND DOES NOT REACH THE NEW CLASS. Leg 1 is the predicate,
# legs 2-3 are its positive controls, leg 4 is the filter with BOTH boxes off —
# the harshest state a user can select — which must still keep the digital name
# and must still drop all three analog noise classes.
set fd_cf [list [pcall ::wviewer::signal_entry {m.sub.sig} vcd] \
                [pcall ::wviewer::signal_entry {v(x1.adj)}] \
                [pcall ::wviewer::signal_entry {v(m.x1.xm1.mod#body)}] \
                [pcall ::wviewer::signal_entry {i(@m.x1.xm1.mod[id])}] \
                [pcall ::wviewer::signal_entry {i(v.x1.v1)}]]
proc fd_names {ents} {
  set o {}
  if {[catch {
    foreach e $ents { lappend o [wviewer::dget $e name {}] }
  } e]} { return "ERR:$e" }
  return $o
}
check {FD32 (F4) `digital` is NOT a device class, so Ruling B's default-off box
       cannot hide it — with BOTH boxes off the VCD wire and the design net
       survive and all three analog noise classes go} \
  [list [pcall ::wviewer::sig_is_device digital] \
        [pcall ::wviewer::sig_is_device devnode] \
        [pcall ::wviewer::sig_is_device devmeas] \
        [fd_names [pcall ::wviewer::browser_class_filter $fd_cf 0 0]]] \
  [list 0 1 1 [list {m.sub.sig} {v(x1.adj)}]]
# THE POSITIVE CONTROL FOR THE FILTER LEG: with both boxes ON nothing is dropped,
# so FD32's short list is the filter working rather than the fixture being short.
check {FD32b (F4 CONTROL) with both boxes ON the same five survive, in raw order} \
  [fd_names [pcall ::wviewer::browser_class_filter $fd_cf 1 1]] \
  [list {m.sub.sig} {v(x1.adj)} {v(m.x1.xm1.mod#body)} {i(@m.x1.xm1.mod[id])} \
        {i(v.x1.v1)}]

# THE LABEL. R8's `<instance>:<param>` formatter is about SPICE currents; a VCD
# has none, and its `type` is `other` for every name (no `v(`/`i(` wrapper), so
# the shipped `class eq net` test alone drops every digital name into it.
proc fd_lbl {n {t {}}} {
  return [pcall ::wviewer::browser_label [pcall ::wviewer::signal_entry $n $t]]
}
check {FD33 (F4) a digital wire and a digital BUS BIT both render BARE; read as
       ngspice names the same two render as currents, and the bit index is eaten
       out of the brackets} \
  [list [fd_lbl {m.sub.sig} vcd] [fd_lbl {m.sub.count[3]} vcd] \
        [fd_lbl {m.sub.sig}]     [fd_lbl {m.sub.count[3]}]] \
  [list sig {count[3]} {sig:i} {count:3}]
# ...and the analog labels the formatter exists for are untouched by the new arm.
check {FD33b (F4 CONTROL) every shipped analog label is byte-identical} \
  [list [fd_lbl {v(x1.adj)}] [fd_lbl {i(v1)}] [fd_lbl {v(m.x1.xm1.mod#body)}] \
        [fd_lbl {i(@m.x1.xm1.mod[id])}] [fd_lbl {i(v.x1.v1)}]] \
  [list adj {v1:i} {mod:#body} {mod:id} {v1:i}]

# THE MATCHER SUBJECT (two-pane item 20, one database KIND over). The bars match
# what the pane DRAWS, so the key has to be told which database a name came from.
# Leg 3 is the shipped one-argument form, which must keep answering the analog
# label for every direct unit test of the matcher.
check {FD34 (F4) the curried key answers the pane's own digital label, and the
       shipped one-argument form still answers the analog one} \
  [list [pcall ::wviewer::browser_label_of_db vcd {m.sub.sig}] \
        [pcall ::wviewer::browser_label_of_db {} {m.sub.sig}] \
        [pcall ::wviewer::browser_label_of {m.sub.sig}]] \
  [list sig {sig:i} {sig:i}]
# ...end to end through the matcher: `sig` is worth ZERO against the raw name and
# zero against the analog label, and exactly one against the digital one.
check {FD34b (F4) `sig`, anchored, finds the digital name ONLY when the key is
       told the database is digital} \
  [list [lindex [pcall ::wviewer::sig_match {m.sub.sig} {sig}] 1] \
        [lindex [pcall ::wviewer::sig_match {m.sub.sig} {sig} \
                   -key wviewer::browser_label_of] 1] \
        [lindex [pcall ::wviewer::sig_match {m.sub.sig} {sig} \
                   -key [list wviewer::browser_label_of_db vcd]] 1]] \
  [list {} {} {m.sub.sig}]

# `sig_split`'s NEW SECOND ARGUMENT IS OPTIONAL AND DEFAULTS TO ANALOG, and that
# is what keeps the whole DC/SB band meaning what it meant. Legs 3-4 are two of
# those shipped expectations, restated here as a guard rather than moved.
check {FD35 (F4) sig_split told `vcd` keeps the top scope; called with one
       argument it is byte-identical to what shipped} \
  [list [pcall ::wviewer::sig_split {m.sub.sig} vcd] \
        [pcall ::wviewer::sig_split {m.sub.sig}] \
        [pcall ::wviewer::sig_split {v(m.x1.x1.xm1.mod#body)}] \
        [pcall ::wviewer::sig_split {i(v.x1.v1)}]] \
  [list [list {m.sub} sig] [list {sub} sig] [list {x1.x1.xm1} {mod#body}] \
        [list x1 v1]]

# GROUPING — F3's other half, on the row builder the tree is drawn from. The VCD's
# `$scope` levels become one group row each, IN ORDER, and the top scope is
# present. Legs are {id text kind} triples so a blanked label or a re-parented
# node is visible, not just a count.
proc fd_rows3 {ents root} {
  set o {}
  if {[catch {
    foreach r [pcall ::wviewer::browser_rows $ents $root] {
      lappend o [list [wviewer::dget $r id {}] [wviewer::dget $r text {}] \
                      [wviewer::dget $r kind {}] [wviewer::dget $r parent {}]]
    }
  } e]} { return "ERR:$e" }
  return $o
}
set fd_dig_ents {}
foreach fd_n {time m.sub.sig {m.sub.count[3]}} {
  lappend fd_dig_ents [pcall ::wviewer::signal_entry $fd_n vcd]
}
check {FD36 (F3/F4) a digital inventory groups by its OWN scope levels — the top
       scope `m` is a node, `sub` hangs from it, and the leaves hang from `sub`} \
  [fd_rows3 [pcall ::wviewer::browser_class_filter $fd_dig_ents 0 1] dig] \
  [list [list {g:} dig group {}] \
        [list {s:time} time leaf {g:}] \
        [list {g:m} m group {g:}] \
        [list {g:m.sub} sub group {g:m}] \
        [list {s:m.sub.sig} sig leaf {g:m.sub}] \
        [list {s:m.sub.count[3]} {count[3]} leaf {g:m.sub}]]
# ⚠ THE SAME THREE NAMES READ AS NGSPICE NAMES — the tombstone for what the tree
# looked like before the ruling: `m` is gone, `sub` is re-parented onto the design
# root, and with the shipped DEFAULT box state (`devint 0`) the two wires are not
# in the tree at all. This is a VALUE, so it cannot rot into a comment.
set fd_ana_ents {}
foreach fd_n {time m.sub.sig {m.sub.count[3]}} {
  lappend fd_ana_ents [pcall ::wviewer::signal_entry $fd_n]
}
# ⚠ LEG 3 IS THIS CHECK'S OWN POSITIVE EVIDENCE, and it is not decoration: legs
# 1-2 describe behaviour that pre-dates the ruling, so on a tree without the
# ruling they pass and the check says nothing. Leg 3 asserts the two readings
# DIFFER, which is false exactly when `signal_entry` cannot be told the database.
check {FD36b (F3/F4 TOMBSTONE) read as ngspice names the same inventory loses the
       `m` level, and at the DEFAULT box state loses both wires entirely — and
       that reading is NOT the one a digital database gets} \
  [list [fd_rows3 [pcall ::wviewer::browser_class_filter $fd_ana_ents 1 1] dig] \
        [fd_rows3 [pcall ::wviewer::browser_class_filter $fd_ana_ents 0 1] dig] \
        [expr {[fd_rows3 [pcall ::wviewer::browser_class_filter $fd_dig_ents 0 1] dig] \
                 ne [fd_rows3 [pcall ::wviewer::browser_class_filter $fd_ana_ents 0 1] dig]}]] \
  [list [list [list {g:} dig group {}] \
              [list {s:time} time leaf {g:}] \
              [list {g:sub} sub group {g:}] \
              [list {s:m.sub.sig} sig leaf {g:sub}] \
              [list {s:m.sub.count[3]} {count[3]} leaf {g:sub}]] \
        [list [list {g:} dig group {}] \
              [list {s:time} time leaf {g:}]] \
        1]
# NEITHER BOX NARROWS A DIGITAL INVENTORY — the four box states give one tree.
# ⚠ THE LAST LEG IS AGAIN THE POSITIVE EVIDENCE: four equal counts are also what
# an inventory of three THROWN entries produces, so the classes are asserted in
# the same tuple.
proc fd_classes {ents} {
  set o {}
  if {[catch {
    foreach e $ents { lappend o [wviewer::dget $e class NONE] }
  } e]} { return "ERR:$e" }
  return $o
}
check {FD37 (F4) all four states of Ruling B's two boxes leave a digital
       inventory identical, and it really is digital} \
  [list [llength [pcall ::wviewer::browser_class_filter $fd_dig_ents 0 0]] \
        [llength [pcall ::wviewer::browser_class_filter $fd_dig_ents 0 1]] \
        [llength [pcall ::wviewer::browser_class_filter $fd_dig_ents 1 0]] \
        [llength [pcall ::wviewer::browser_class_filter $fd_dig_ents 1 1]] \
        [pcall ::wviewer::browser_device_paths $fd_dig_ents] \
        [fd_classes $fd_dig_ents]] \
  [list 3 3 3 3 {} [list digital digital digital]]

# THE HEADER TEXT F3's ROW NAMES. `db_label` needs no change and this says so as
# a value: a VCD names its file and its analysis, is distinguishable from the
# analog raw beside it, and (the property `db_label`'s own ⚠ block is about)
# carries a space and a bracket so it can never be mistaken for a scope segment.
check {FD38 (F3) a digital database's tree header names the file and says `(vcd)`,
       and its design root comes from its own file name} \
  [list [pcall ::wviewer::db_label {/tmp/run/counter.vcd} vcd] \
        [pcall ::wviewer::db_label {/tmp/run/tb_ase.raw} tran] \
        [pcall ::wviewer::browser_root_label {/tmp/run/counter.vcd}] \
        [regexp {[ (]} [pcall ::wviewer::db_label {/tmp/run/counter.vcd} vcd]]] \
  [list {counter.vcd (vcd)} {tb_ase.raw (tran)} counter 1]

# THE SNAPSHOT KEY THAT MAKES ALL OF THE ABOVE REACHABLE FROM THE PRODUCT.
# Without `type` on the browser's own per-DB dicts nothing downstream can tell a
# VCD from a raw, and every check above would be true of a proc nobody calls.
check {FD39 (SOURCE) browser_reload carries each database's `type` into the
       browser snapshot, and browser_refresh reads it per DB} \
  [list [regexp -all {type\s+\[wviewer::dget \$db type \{\}\]} \
           [wvproc_body $wsrc wviewer::browser_reload]] \
        [regexp -all {wviewer::browser_curtype \$token} \
           [wvproc_body $wsrc wviewer::browser_refresh]] \
        [regexp -all {set dbtype \[wviewer::dget \$db type \{\}\]} \
           [wvproc_body $wsrc wviewer::browser_refresh]]] \
  [list 2 1 1]

# =============================================================================
# FD49-FD53 — THE FIX PASS. Four defects RULING F4's FIRST LANDING carried in
# with it, each reproduced as a value here before it was fixed. They are in the
# BOTH-ARMS band because every one of them is a pure proc; FD54/FD55 are the same
# two questions asked of the real tree and the real pane.
# =============================================================================

# --- FD49/FD50: A DIGITAL NAMESPACE IS CASE-SENSITIVE, AND TWO PROCS THE RULING
# NEWLY POINTED AT VCD NAMES WERE FOLDING IT ---------------------------------
#
# `-nocase` is a fact about NGSPICE — it lowercases, so the raw says `x1.x2`
# while the schematic says `X1`, and they differ by case and ONLY by case.
# Verilog is case-SENSITIVE and `vcd_read.c` stores names verbatim, so `top.mod`
# and `top.MOD` are two LEGAL SIBLING SCOPES with different contents.
# MEASURED before the fix, on exactly this inventory: `browser_rows` built two
# DISTINCT groups (correctly, `g:top.mod` and `g:top.MOD`) while both procs below
# answered BOTH names for EITHER path — so selecting either scope drew the other
# scope's wires, under a caption that counted them.
#
# ⚠⚠ LEG 3 IS THE ANALOG CONTROL AND IT IS THE HALF THAT MAKES THIS A FIX RATHER
# THAN A SWAP. TP16 (test_wave_sigbrowser_2pane.tcl) pins `X1` finding `x1`, so
# "make the compare case-sensitive" reds a shipped check. The rule keys on the
# ENTRY's OWN class, and both directions are asserted in the same tuple.
set fd_cs_dig {}
foreach fd_n {top.mod.a top.MOD.b} {
  lappend fd_cs_dig [pcall ::wviewer::signal_entry $fd_n vcd]
}
set fd_cs_ana {}
foreach fd_n {v(x1.net1) i(v.x1.v1) v(vbg)} {
  lappend fd_cs_ana [pcall ::wviewer::signal_entry $fd_n]
}
check {FD49 (F4 FIX) two LEGAL SIBLING VCD SCOPES differing only in case keep
       their OWN signals, and the ngspice reading of the same question still
       folds case} \
  [list [pcall ::wviewer::browser_level_names $fd_cs_dig top.mod] \
        [pcall ::wviewer::browser_level_names $fd_cs_dig top.MOD] \
        [pcall ::wviewer::browser_level_names $fd_cs_ana X1]] \
  [list {top.mod.a} {top.MOD.b} [list {v(x1.net1)} {i(v.x1.v1)}]]
# ...and the CAPTION'S OWN DENOMINATOR, which is the same question asked by a
# second proc and must not drift from the first: it counts the unfiltered
# inventory at a level, so the folded compare made the pane say `2 of 2 signals`
# about a scope that owns one. Legs 3-4 are the ngspice control, both spellings.
set ::wviewer::browsersigs(fdcsD)  {top.mod.a top.MOD.b}
set ::wviewer::browsercurdb(fdcsD) [dict create id d:0 label {c.vcd (vcd)} type vcd]
set ::wviewer::browsersigs(fdcsA)  {v(x1.net1) i(v.x1.v1) v(vbg)}
set ::wviewer::browsercurdb(fdcsA) [dict create id d:0 label {a.raw (tran)} type tran]
check {FD50 (F4 FIX) the lower pane's own-level COUNT obeys the same case rule —
       each digital sibling scope owns ONE wire — and the ngspice count still
       answers the same for `X1` and `x1`} \
  [list [pcall ::wviewer::browser_sea_own fdcsD top.mod] \
        [pcall ::wviewer::browser_sea_own fdcsD top.MOD] \
        [pcall ::wviewer::browser_sea_own fdcsA X1] \
        [pcall ::wviewer::browser_sea_own fdcsA x1]] \
  [list 1 1 2 2]

# --- FD51/FD52: THE TWO `Descend to here` RESOLVERS THE RULING LEFT BEHIND ----
#
# RULING F4 moved a digital signal's `path` to the un-declassed form everywhere
# the TREE is built, but both resolvers still split a LEAF through the
# one-argument (analog) `sig_split`. MEASURED before the fix, on this very row
# set: the GROUP row answered `ok m.sub` while its OWN CHILD answered `ok sub` —
# a node the tree never showed — and the two together came back
# `err {those rows are in different parts of the hierarchy}`, which DISABLES the
# menu entry on a scope plus one of its own wires.
#
# ⚠⚠ THE CURRENT DATABASE'S KIND IS NOT THE ANSWER FOR THE TREE, AND LEG 4 IS
# WHY. The tree is the one surface that holds several databases at once, so the
# question is per-ROW. Here the ngspice raw is CURRENT and the VCD is foreign:
# the foreign row must NOT be declassed, and in the same tree, in the same call,
# the current raw's own device leaf MUST still be. One current-kind answer
# cannot be both, and picking it would have swapped this defect for its mirror.
set ::wviewer::browsercurdb(fdtp)  [dict create id d:0 label {a.raw (tran)} type tran]
set ::wviewer::browserdbsigs(fdtp) [list [dict create id d:1 \
  label {c.vcd (vcd)} path /tmp/fd_c.vcd type vcd names {m.sub.sig}]]
set fd_tp_rows [pcall ::wviewer::browser_rows \
  [list [pcall ::wviewer::signal_entry {v(m.x1.xm1.mod#body)}]] anlg]
foreach fd_r [pcall ::wviewer::browser_rows \
                [list [pcall ::wviewer::signal_entry {m.sub.sig} vcd]] dig] {
  dict set fd_r id "d:1|[wviewer::dget $fd_r id {}]"
  if {[wviewer::dget $fd_r parent {}] ne {}} {
    dict set fd_r parent "d:1|[wviewer::dget $fd_r parent {}]"
  }
  lappend fd_tp_rows $fd_r
}
set ::wviewer::browserrows(fdtp) $fd_tp_rows
check {FD51 (F4 FIX) a digital GROUP row and a LEAF under it resolve to the SAME
       path and select together as `ok`; in the SAME tree, in the same calls, the
       CURRENT ngspice raw's device leaf is still declassed} \
  [list [pcall ::wviewer::browser_target_path fdtp [list {d:1|g:m.sub}]] \
        [pcall ::wviewer::browser_target_path fdtp [list {d:1|s:m.sub.sig}]] \
        [pcall ::wviewer::browser_target_path fdtp \
           [list {d:1|g:m.sub} {d:1|s:m.sub.sig}]] \
        [pcall ::wviewer::browser_target_path fdtp [list {s:v(m.x1.xm1.mod#body)}]] \
        [pcall ::wviewer::browser_id_type fdtp {d:1|s:m.sub.sig}] \
        [pcall ::wviewer::browser_id_type fdtp {s:v(m.x1.xm1.mod#body)}]] \
  [list {ok m.sub} {ok m.sub} {ok m.sub} {ok x1.xm1} vcd tran]
# The LOWER PANE's twin resolver, whose answer is the same one database over: the
# pane draws the CURRENT database's entries and only those, so the current kind
# IS its whole answer. Leg 3 is its ngspice control.
set ::wviewer::browsercurdb(fdseaD) [dict create id d:0 label {c.vcd (vcd)} type vcd]
set ::wviewer::browsersea(fdseaD) \
  [list [list sig {m.sub.sig}] [list {count[3]} {m.sub.count[3]}]]
set ::wviewer::browsercurdb(fdseaA) [dict create id d:0 label {a.raw (tran)} type tran]
set ::wviewer::browsersea(fdseaA) [list [list {mod:#body} {v(m.x1.xm1.mod#body)}]]
check {FD52 (F4 FIX) the lower pane's Descend-to resolver keeps a digital top
       scope instead of deleting it, and still declasses an ngspice device leaf} \
  [list [pcall ::wviewer::browser_sea_target_path fdseaD 0] \
        [pcall ::wviewer::browser_sea_target_path fdseaD [list 0 1]] \
        [pcall ::wviewer::browser_sea_target_path fdseaA 0]] \
  [list {ok m.sub} {ok m.sub} {ok x1.xm1}]
# ...and the arm that used to swallow an unreachable node in silence now SAYS so.
# The menu entry is built ENABLED on `ok` alone, so a resolved path with no row
# left the user with a command that did nothing and explained nothing. A Filter
# that hides the scope is a real way to reach it, so it needs a sentence rather
# than a stricter gate. Leg 2 is the positive control: with the row present the
# arm is not taken and the status line is NOT written.
check {FD52b (F4 FIX) a resolved path with no row in the tree is SAID, not
       swallowed} \
  [list [regexp -all {is not in the Signal Browser tree} \
           [wvproc_body $wsrc wviewer::browser_sea_descend_to]] \
        [regexp -all {return 0\s*$} \
           [wvproc_body $wsrc wviewer::browser_sea_descend_to]]] \
  [list 1 0]

# --- FD53: A LABEL THAT CONTAINS A GLOB METACHARACTER (RULING F4b) -----------
#
# Two-pane item 20 made the bars match the LABEL THE PANE DRAWS. RULING F4 then
# made a digital bus bit draw `count[0]` — correctly; the pre-ruling label was
# `count:3`, with the index eaten. MEASURED after that landing and before this
# fix: `sig` found the wire and `count` found the bare bus, but `count[0]` — the
# exact string on screen — found NOTHING, because `[0]` is read as a character
# class. On a digital database that is the MAJORITY of names. It is not purely a
# digital problem either: an ngspice design net `v(x1.count[3])` has drawn
# `count[3]` since item 20 shipped, and typing it has never worked (leg 6).
#
# ⚠⚠ THE FIX DOES NOT CHANGE WHAT A GLOB MEANS, and legs 2-5 are what say so.
# Quoting the metacharacters — the obvious alternative — reds SM07, whose whole
# subject is that `[[]` is the escape for a literal `[`: MEASURED, with the
# subject quoted `*net_name[[]*` finds nothing. So the glob is tried first and
# UNCHANGED, and an exact whole-subject equality is tried second; the match set
# can only grow, and it grows by exactly the string the user can see.
set fd_bits {m.sub.sig m.sub.count m.sub.count[0] m.sub.count[1]}
set fd_key  [list wviewer::browser_label_of_db vcd]
proc fd_sm {names pat args} {
  return [lindex [pcall ::wviewer::sig_match $names $pat {*}$args] 1]
}
check {FD53 (F4b) typing the exact bus-bit label the pane draws finds THAT bit,
       while `*`, a bracket RANGE, the `[[]` escape and a lone `[` all keep the
       meanings SM06/SM07/SM19 pin} \
  [list [fd_sm $fd_bits {count[0]}   -key $fd_key] \
        [fd_sm $fd_bits {count*}     -key $fd_key] \
        [fd_sm $fd_bits {count[[]0]} -key $fd_key] \
        [fd_sm {net1 net5 tmp} {net[0-9]}] \
        [fd_sm {net1 net5 tmp} {[}] \
        [fd_sm {v(x1.count[3]) v(x1.net1)} {count[3]} \
           -key wviewer::browser_label_of]] \
  [list [list {m.sub.count[0]}] \
        [list {m.sub.count} {m.sub.count[0]} {m.sub.count[1]}] \
        [list {m.sub.count[0]}] \
        [list net1 net5] \
        {} \
        [list {v(x1.count[3])}]]

# =============================================================================
# FD10-FD48 — THE REAL VIEWER, THE REAL TREE, A REAL SECOND DATABASE. Tk/X only.
# (FD30-FD39 are the §F item F4 ruling's PURE half and sit ABOVE this gate, in
# the both-arms block, so a dead display cannot take them with it.)
# The session fixture is test_wave_sigbrowser_i14.tcl's BD40 recipe verbatim.
# =============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set fd_raw [file join $scratch fd_anlg.raw]
  set fd_vcd [file join $scratch fd_dig.vcd]
  fd_mkraw $fd_raw
  fd_mkvcd $fd_vcd

  set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
  set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
  set f [::open [file join $scratch library.defs] w]
  puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
  puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
  puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
  ::close $f
  set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
  set ::library_registry_defs_only 1
  set ::XSCHEM_LIBRARY_PATH {}

  if {![file isfile $statefile]} {
    puts "SKIPPED: group FD1x (the sky130A session fixture is absent)"
  } else {
  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check {FD10 (FIXTURE) wviewer::open returns 1} [pcall ::wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: group FD1x (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  set FDV $vtop.wvbrowser
  set FDB $FDV.wvsearch
  # ⚠ FD10b, NOT a second FD10. The draft shipped this id twice, which makes a
  # sabotage table unreadable (two rows can claim "FD10 went red" and mean
  # different checks). Restated, not renumbered: the assertion is byte-identical
  # and only the label moved.
  check {FD10b (FIXTURE) the sidebar toggles on and the tree is real} \
    [list [pcall ::wviewer::browser_toggle 1 $tok] [winfo exists $FDV.pw.tvf.tv]] \
    [list 1 1]
  update
  # ⚠ THE PRODUCT'S OWN ATTACH PATH, `ase::attach_dbs` (§E's E3), NOT
  # `rawbar_load`: the raw bar reads a file as SPICE, and a VCD handed to the
  # spice parser is not a database. E3 reads the analog raw first, then each
  # VCD, then switches back — so the VCD really is a FOREIGN slot here, which is
  # the arrangement the branch has to survive.
  wviewer::switch_ctx $tok
  set fd_at [pcall ase::attach_dbs $fd_raw tran [list $fd_vcd]]
  check {FD11 (FIXTURE) both databases attach, the analog one current} \
    [list [wviewer::dget $fd_at n NONE] [pcall xschem raw rawfile]] [list 2 $fd_raw]
  set fd_cur [pcall xschem raw rawfile]
  wviewer::browser_refresh $tok 1
  update
  check {FD11b (FIXTURE) the analog DB is current and the VCD is a FOREIGN slot} \
    [list $fd_cur [llength $::wviewer::browserdbsigs($tok)] \
          [wviewer::dget [lindex $::wviewer::browserdbsigs($tok) 0] path {}]] \
    [list $fd_raw 1 $fd_vcd]
  # ...and the scope box is OFF, which is what makes the next check a real one:
  # with it off, the VCD's rows are not in the tree at all.
  check {FD12 (FIXTURE) the All-DBs box starts OFF and the VCD has no rows} \
    [list $::wviewer::sballdb($FDB) \
          [pcall ::wviewer::browser_rows_headered $::wviewer::browserrows($tok)]] \
    [list 0 0]

  # --- F1: THE DIGITAL SCOPE IS SHOWN --------------------------------------
  lassign [pcall ::wviewer::browser_db_group_id $tok $fd_vcd] fd_gid fd_iscur
  set fd_r [pcall ::wviewer::browser_show_db_scope $tok $fd_vcd TOP.m]
  update
  check {FD13 (F1) the scope resolves to a row in the VCD's own subtree, and the
         result says the tree was re-scoped to reach it} \
    [list $fd_iscur $fd_r] [list 0 [list alldbs "$fd_gid|g:TOP.m" TOP.m]]
  check {FD14 (F1) the tree SELECTION is that row and the row belongs to the
         VCD's registry slot, not to the analog raw} \
    [list [$FDV.pw.tvf.tv selection] \
          "d:[pcall ::wviewer::browser_row_db [lindex [$FDV.pw.tvf.tv selection] 0]]"] \
    [list [list [lindex $fd_r 1]] $fd_gid]
  check {FD15 (F1) the landing decodes to the VCD's scope, with no database
         prefix left on it} \
    [pcall ::wviewer::browser_id_path [lindex $fd_r 1]] TOP.m
  # THE BOX WAS TICKED ON THE USER'S BEHALF, and the sentence says so — R12's
  # rule ("grew the tree without being asked, so say so"), one database over.
  check {FD16 (F1) the All-DBs box is now ON and the status line names what was
         done} \
    [list $::wviewer::sballdb($FDB) \
          [$FDV.ph cget -text]] \
    [list 1 "Signal Browser\nshowing every results database to reach TOP.m"]
  # --- RULING F1e: WHAT THE HAPPY PATH ACTUALLY LEAVES ON SCREEN -----------
  #
  # ⚠⚠ THE SCOPE IS SHOWN AND THE PANE IS STILL EMPTY. The lower pane is drawn
  # from `browserseaent`, the CURRENT database's entries alone (item 15's
  # declared limit, BD70d one file over), so a FOREIGN VCD's scope selects a
  # real row that lists nothing — and the shipped `seaempty` arm then captions
  # it "'TOP.m' has no signals of its own", about a scope that has two. This is
  # the state that makes `ase::show_in_browser_for_current`'s step 7b fire; FV41
  # owns the arm, this owns the FACT, and without the fact the arm is a guess.
  check {FD19 (F5/F1e) the digital scope is shown and the lower pane still lists
         NOTHING — the state the "shown but not listed" notice exists for} \
    [list [pcall ::wviewer::browser_sea_empty $tok] \
          [llength $::wviewer::browsersea($tok)] \
          [llength [$FDV.pw.sea.c find withtag cell]]] \
    [list 1 0 0]
  # THE POSITIVE CONTROL, and it is not optional: a reader that answered 1 for
  # everything would pass FD19 and be worthless. The CURRENT database's design
  # root lists its own signals, so the same reader must answer 0 there.
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  check {FD19b (F5/F1e CONTROL) the same reader answers 0 on the current
         database's own root, whose pane really does list signals} \
    [list [pcall ::wviewer::browser_sea_empty $tok] \
          [expr {[llength $::wviewer::browsersea($tok)] > 0}]] \
    [list 0 1]
  # ⚠ AND THE FIXTURE GOES BACK, WITH AN `update`, BEFORE ANYTHING ELSE READS
  # IT. `selection set` only QUEUES <<TreeviewSelect>>; without the flush the
  # pane below still holds the previous node's cells, and FD21 (which asserts
  # the canvas notice draws only on an EMPTY pane) then reads two stale cells
  # and fails for a reason that has nothing to do with the notice. Measured.
  pcall $FDV.pw.tvf.tv selection set [list [lindex $fd_r 1]]
  update
  # ⚠ A SCOPE THE DATABASE DOES NOT DECLARE. Measured, and the answer is the
  # analog path's: the walk lands on the deepest ancestor that DOES exist and
  # reports `partial`, naming what was asked. That is deliberate parity — a
  # digital scope that has moved one level (RULING 5c's inlining case) should
  # leave the user inside the right database rather than nowhere.
  set fd_bad [pcall ::wviewer::browser_show_db_scope $tok $fd_vcd TOP.nosuch]
  check {FD17 (F1) a scope the database does not declare lands on its deepest
         ancestor and says which scope was asked for} \
    [list [lindex $fd_bad 0] [pcall ::wviewer::browser_id_path [lindex $fd_bad 1]] \
          [lindex $fd_bad 3]] \
    [list partial TOP TOP.nosuch]
  # ...and a first segment that matches nothing is a refusal, not a landing
  set fd_bad2 [pcall ::wviewer::browser_show_db_scope $tok $fd_vcd NOSUCH.deep]
  check {FD17b (F1) a scope whose FIRST segment misses is refused, and the
         refusal names the scope and the database} \
    [list [lindex $fd_bad2 0] \
          [expr {[string first {NOSUCH.deep} [lindex $fd_bad2 1]] >= 0}] \
          [expr {[string first {fd_dig.vcd} [lindex $fd_bad2 1]] >= 0}]] \
    [list err 1 1]
  # a database this viewer does not hold is a different refusal
  set fd_nodb [pcall ::wviewer::browser_show_db_scope $tok \
                 [file join $scratch fd_absent.vcd] TOP.m]
  check {FD18 (F1) a database the viewer does not hold is refused by name} \
    [list [lindex $fd_nodb 0] \
          [expr {[string first {fd_absent.vcd} [lindex $fd_nodb 1]] >= 0}]] \
    [list err 1]

  # --- F5: THE NOTICE, ON THE PANE THE USER IS LOOKING AT -------------------
  set fd_msg {no digital signals to show: the last run promised no VCD for 'dcell'}
  check {FD20 (F5) the notice reaches the pane's caption AND the sidebar status
         line, verbatim} \
    [list [pcall ::wviewer::browser_notice $tok $fd_msg] \
          [$FDV.pw.sea.st cget -text] [$FDV.ph cget -text]] \
    [list 1 $fd_msg "Signal Browser\n$fd_msg"]
  # THE PANE ITSELF. The canvas arm draws the sentence only when there is
  # nothing else in the pane — which is the state F5's spec row is about.
  set fd_c $FDV.pw.sea.c
  set fd_cells [llength [$fd_c find withtag cell]]
  set fd_note  [$fd_c find withtag seanote]
  check {FD21 (F5) with an empty pane the sentence is DRAWN IN THE PANE, wrapped,
         and it is the same string} \
    [list $fd_cells [llength $fd_note] \
          [expr {[llength $fd_note] ? [$fd_c itemcget [lindex $fd_note 0] -text] : {NONE}}] \
          [expr {[llength $fd_note] && [$fd_c itemcget [lindex $fd_note 0] -width] > 0}]] \
    [list 0 1 $fd_msg 1]
  # ...and it does NOT survive the next thing the user does. A stale reason on a
  # pane that has since been repopulated is worse than none.
  wviewer::browser_sea_refresh $tok
  update
  check {FD22 (F5) the next sea refresh clears the notice from the state and
         from the canvas} \
    [list $::wviewer::browserseanote($tok) [llength [$fd_c find withtag seanote]]] \
    [list {} 0]

  # ===========================================================================
  # FD23-FD26 — THE ORDERING THE PRODUCT CANNOT AVOID (salvage pass, review
  # findings R1/R2/R2-D).
  #
  # ⚠⚠ EVERY CHECK ABOVE READS ITS SURFACE IN THE SAME EVENT-LOOP TURN THAT
  # WROTE IT, AND THAT IS THE ONE TURN THE PRODUCT NEVER GETS. `browser_reveal`
  # changes the treeview selection, which only QUEUES <<TreeviewSelect>>;
  # `browser_sea_refresh` is delivered on the NEXT turn — i.e. the instant the
  # Ctrl-Alt-V binding returns — and its first act is to clear the notice and
  # its last is to re-caption the pane from the shipped `seaempty` arm. So a
  # notice written before that flush lives for microseconds. Measured on the
  # real viewer, both arms, before step 6c existed: caption held the sentence on
  # return and read "TOP.m has no signals of its own" one `update` later.
  #
  # FD20/FD21 above cannot see any of it — they call `browser_notice` directly,
  # and this file's `update` calls all sit BEFORE the notice, never after it.
  # ===========================================================================

  # ⚠⚠ THE COMMAND ITSELF, NOT ITS PIECES. Only the five DESIGN-side reads are
  # stubbed (this file has no schematic and no session of its own); steps 4, 5,
  # 6, 6c, 7 and 7b are the shipped code running against the real treeview, the
  # real checkbutton, the real pane and the real canvas. Deleting step 6c's
  # `catch {update}` from src/ase.tcl reds this; so does moving it above step 6.
  proc fd_drive_on {} {
    foreach p {::ase::session_for_current ::wviewer::hier_now \
               ::ase::browser_sel_segment ::wviewer::browser_origin_drop \
               ::ase::browser_digital_probe} {
      if {[info commands $p] ne {}} { rename $p ${p}_fdsaved }
    }
    proc ::ase::session_for_current {} { return [list $::fd_tok 0] }
    proc ::wviewer::hier_now {} { return {} }
    proc ::ase::browser_sel_segment {} { return {ok a1} }
    proc ::wviewer::browser_origin_drop {level lv} { return 0 }
    proc ::ase::browser_digital_probe {key selname token} { return $::fd_dig }
  }
  proc fd_drive_off {} {
    foreach p {::ase::session_for_current ::wviewer::hier_now \
               ::ase::browser_sel_segment ::wviewer::browser_origin_drop \
               ::ase::browser_digital_probe} {
      if {[info commands ${p}_fdsaved] ne {}} {
        catch {rename $p {}}
        rename ${p}_fdsaved $p
      }
    }
  }
  set ::fd_tok $tok
  set ::fd_dig [list ok $fd_vcd TOP.m]

  # ⚠ THE PRE-STATE IS A SETTLED PANE THAT LISTS THINGS, and it is load-bearing
  # for the SECOND blocker. Step 7b's predicate reads the pane MODEL, which the
  # queued refresh has not rebuilt yet — so from here, without step 6c, it
  # answers about the design root the user is leaving (2 signals -> "not empty"
  # -> the arm refuses and writes nothing at all). Starting from an already
  # empty pane would hide that: the stale answer and the true answer would
  # coincide, and this check would pass with the flush deleted.
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  set fd_pre [list [llength $::wviewer::browsersea($tok)] \
                   [pcall ::wviewer::browser_sea_empty $tok]]
  fd_drive_on
  set fd_dr [pcall ase::show_in_browser_for_current]
  fd_drive_off
  # ⚠⚠ AND HERE IS THE TURN OF THE EVENT LOOP THAT TK ALWAYS TAKES. Everything
  # this item ships is judged after this line, never before it.
  update
  set fd_want "showing the digital scope 'TOP.m' of 'fd_dig.vcd' in the tree,\
 but the lower pane lists only the current results database, so this scope's\
 own signals are not in it yet"
  check {FD23 (F5/F1e) the real command's notice SURVIVES the refresh its own
         gesture queued — pane caption, one turn after the binding returns} \
    [list $fd_pre $fd_dr [$FDV.pw.sea.st cget -text]] \
    [list [list 2 0] $tok $fd_want]
  # the other two surfaces, same settled moment: the sidebar status line and the
  # pane canvas. The canvas arm draws only on an empty pane, which is exactly
  # the state this path produces — and it only reaches that state because 6c let
  # the refresh happen FIRST.
  check {FD24 (F5/F1e) the same sentence is on the sidebar status line and drawn
         in the pane canvas, one turn after the binding returns} \
    [list [$FDV.ph cget -text] \
          $::wviewer::browserseanote($tok) \
          [llength [$fd_c find withtag seanote]] \
          [llength [$fd_c find withtag cell]]] \
    [list "Signal Browser\n$fd_want" $fd_want 1 0]
  # ⚠ THE TOMBSTONE FOR WHY 6c EXISTS. The same two product calls in the same
  # order with NO flush between them: the notice is written, and one turn later
  # the queued refresh has cleared it and put the shipped `seaempty` falsehood
  # back. This is the state the feature shipped in before the salvage pass, kept
  # as a check so nobody re-derives it from first principles.
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  pcall ::wviewer::browser_show_db_scope $tok $fd_vcd TOP.m
  pcall ::wviewer::browser_notice $tok {FD25 unflushed}
  set fd_before [$FDV.pw.sea.st cget -text]
  update
  check {FD25 (F5/F1e TOMBSTONE) a notice written WITHOUT the settle is erased by
         the queued refresh, and the false shipped caption comes back} \
    [list $fd_before [$FDV.pw.sea.st cget -text] $::wviewer::browserseanote($tok)] \
    [list {FD25 unflushed} {TOP.m has no signals of its own} {}]

  # ⚠⚠ F5's OWN ROW, END TO END, ON THE PATH THAT SHIPPED THE DEFECT FIRST.
  # FD23/FD24 drive the SUCCESS path; this is the REFUSAL path, whose notice was
  # erased by exactly the same queued refresh. That half was inherited from
  # `fda9d5a8` — RULING F1e did not introduce it and nothing pinned it — so
  # without this check the flush could be removed from under F5's original row
  # and only the F1e rows would notice. Same five stubs, same real steps 4-7;
  # the probe answers a refusal, so step 7 writes and step 7b never runs.
  set fd_refuse {the last run promised no VCD for 'dcell' (tracing off)}
  set ::fd_dig [list none notraced $fd_refuse]
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  fd_drive_on
  pcall ase::show_in_browser_for_current
  fd_drive_off
  update
  check {FD27 (F5) the REFUSAL notice also survives the refresh its own gesture
         queued — caption and sidebar status line, one turn after the binding
         returns} \
    [list [$FDV.pw.sea.st cget -text] \
          $::wviewer::browserseanote($tok) \
          [$FDV.ph cget -text]] \
    [list "no digital signals to show: $fd_refuse" \
          "no digital signals to show: $fd_refuse" \
          "Signal Browser\nno digital signals to show: $fd_refuse"]

  # --- FD26: "the pane lists nothing" is not the same fact as "a bar is hiding
  # everything" ------------------------------------------------------------
  #
  # ⚠⚠ `browsersea` IS THE FILTERED SET, so an empty one has two causes and only
  # one of them is this reader's. With a no-match Filter pattern the design root
  # draws nothing while still HAVING two own-level signals, and the shipped
  # caption says so truthfully. A reader that called that "empty" would let step
  # 7b replace a true caption with a sentence blaming a foreign database — the
  # guessed yes its own ⚠⚠ block forbids. Leg 1 is the reader, legs 2/3 are the
  # state it is answering about, leg 4 is the shipped caption it must not
  # displace.
  pcall ::wviewer::searchbar_set $FDV.wvfilter \
    {pattern zzzznomatchzzzz syntax shell type all case 0}
  pcall ::wviewer::browser_refresh $tok 1
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  check {FD26 (F5/F1e) a Search/Filter bar that hides every name is NOT an empty
         scope: the reader declines and the shipped bar caption stands} \
    [list [pcall ::wviewer::browser_sea_empty $tok] \
          [llength $::wviewer::browsersea($tok)] \
          [pcall ::wviewer::browser_sea_own $tok {}] \
          [pcall ::wviewer::browser_bars_active $tok]] \
    [list 0 0 2 1]
  pcall ::wviewer::searchbar_set $FDV.wvfilter \
    {pattern {} syntax shell type all case 0}
  pcall ::wviewer::browser_refresh $tok 1
  update

  # ===========================================================================
  # FD40-FD48 — SPEC §F ITEM F3/F4 ON THE REAL VIEWER, THE REAL TREE AND THE
  # REAL LOWER PANE.
  #
  # ⚠⚠ FD30-FD39 ABOVE PROVE THE RULING ON THE PROCS. THEY PROVE NOTHING ABOUT
  # THE PRODUCT, and item 5 of this batch is the reason that sentence is here:
  # its feature shipped with 58 green unit checks around a notice that the very
  # next event-loop turn erased. So this block attaches a real VCD through the
  # product's own attach path, drives the product's own re-scope, and reads the
  # tree and the pane the user would be looking at.
  #
  # THE SECOND DATABASE IS `fd_mkvcd_m` — the single-letter top scope. Under the
  # shipped classifier every one of its wires is a MOSFET internal node, so with
  # `Show device internals` at its DEFAULT (off) the rows do not exist and the
  # walk below cannot land. That is what makes FD41 a measurement.
  # ===========================================================================
  set fd_vcdm [file join $scratch fd_dig_m.vcd]
  fd_mkvcd_m $fd_vcdm
  wviewer::switch_ctx $tok
  set fd_at3 [pcall ase::attach_dbs $fd_raw tran [list $fd_vcd $fd_vcdm]]
  wviewer::browser_refresh $tok 1
  update
  # THE SNAPSHOT KEY, ON THE LIVE PRODUCT. Without it every check after this one
  # is about a code path the browser never reaches.
  proc fd_dbtype {tok path} {
    foreach db $::wviewer::browserdbsigs($tok) {
      if {[wviewer::dget $db path {}] eq $path} { return [wviewer::dget $db type NONE] }
    }
    return ABSENT
  }
  check {FD40 (F3/F4 FIXTURE) three databases attach with the analog one current,
         and the browser's own per-DB snapshot records each foreign one's KIND} \
    [list [wviewer::dget $fd_at3 n NONE] [pcall xschem raw rawfile] \
          [llength $::wviewer::browserdbsigs($tok)] \
          [fd_dbtype $tok $fd_vcdm] [fd_dbtype $tok $fd_vcd] \
          [pcall ::wviewer::browser_curtype $tok]] \
    [list 3 $fd_raw 2 vcd vcd tran]

  # THE WALK, THROUGH THE PRODUCT'S OWN COMMAND, INTO THE SINGLE-LETTER SCOPE.
  # `Show device internals` is at its shipped default here — asserted, not
  # assumed, because the whole point is that the ruling does not need it.
  #
  # ⚠ THE EXPECTED OUTCOME IS `ok`, NOT `alldbs`, AND THE PRE-STATE IS WHY —
  # MEASURED, after this check was first written expecting `alldbs` and failing.
  # FD13 above already ticked the All-DBs box on the user's behalf and RULING F1c
  # leaves a tick that helped in place, so by the time this runs the foreign rows
  # are already in the tree and there is nothing for the arm to announce. Leg 1
  # asserts that pre-state rather than leaving it implicit; leg 2 is the device
  # box, still at its shipped default.
  set fd_devbox [pcall ::wviewer::browser_devint $tok]
  set fd_prebox $::wviewer::sballdb($FDB)
  set fd_m [pcall ::wviewer::browser_show_db_scope $tok $fd_vcdm {m.sub}]
  update
  lassign [pcall ::wviewer::browser_db_group_id $tok $fd_vcdm] fd_mgid fd_miscur
  check {FD41 (F3/F4) with device internals HIDDEN, the tree reaches `m.sub`
         inside the single-letter-top VCD, and the landing is that scope} \
    [list $fd_prebox $fd_devbox $fd_miscur $fd_m \
          [pcall ::wviewer::browser_id_path [lindex $fd_m 1]]] \
    [list 1 0 0 [list ok "$fd_mgid|g:m.sub" {m.sub}] {m.sub}]
  # THE NODES THEMSELVES, under that database's header — the group boundary the
  # ruling is about, read off the row model the treeview was populated from.
  proc fd_ids {tok} {
    set o {}
    foreach r $::wviewer::browserrows($tok) { lappend o [wviewer::dget $r id {}] }
    return $o
  }
  # the LOWER PANE's drawn labels, in order. Used by FD48 (where it must be
  # empty) and by FD45 (where it must be the six bare digital names).
  proc fd_pane {tok} {
    set o {}
    foreach p $::wviewer::browsersea($tok) { lappend o [lindex $p 0] }
    return $o
  }
  set fd_all [fd_ids $tok]
  check {FD42 (F3/F4) `m` and `m.sub` are both real rows of that database's
         subtree, and its wire and its bus bit hang from `m.sub`} \
    [list [expr {[lsearch -exact $fd_all "$fd_mgid|g:m"] >= 0}] \
          [expr {[lsearch -exact $fd_all "$fd_mgid|g:m.sub"] >= 0}] \
          [expr {[lsearch -exact $fd_all "$fd_mgid|s:m.sub.sig"] >= 0}] \
          [expr {[lsearch -exact $fd_all "$fd_mgid|s:m.sub.count\[3\]"] >= 0}] \
          [$FDV.pw.tvf.tv exists "$fd_mgid|g:m.sub"]] \
    [list 1 1 1 1 1]
  # THE CONTROL, IN THE SAME TREE: the analog raw beside it is still declassed and
  # still hides its device node, so the ruling did not simply switch declassing
  # off. `v(anlg)` is fd_mkraw's only signal and it is a design net at the root.
  check {FD42b (F3/F4 CONTROL) the analog database in the SAME tree is unchanged —
         its net is there and no `d:` prefix leaked onto the current DB's rows} \
    [list [expr {[lsearch -exact $fd_all {s:v(anlg)}] >= 0}] \
          [expr {[lsearch -exact $fd_all {g:}] >= 0}] \
          [pcall ::wviewer::browser_curtype $tok]] \
    [list 1 1 tran]

  # THE SEARCH BAR, ON THE FOREIGN DIGITAL INVENTORY. `sig` is worth zero against
  # the raw name `m.sub.sig` and zero against its analog label `sig:i`; it finds
  # the row only because browser_refresh's All-DBs loop keys that inventory with
  # its OWN database kind. This is BD57's argument one database KIND over.
  pcall ::wviewer::searchbar_set $FDB \
    [dict merge [pcall ::wviewer::searchbar_get $FDB] {pattern sig}]
  pcall ::wviewer::browser_refresh $tok 0
  update
  set fd_sig [fd_ids $tok]
  check {FD43 (F3/F4) the Search bar finds the digital wire by the label the pane
         draws for it, and drops the bus bits that do not match} \
    [list [expr {[lsearch -exact $fd_sig "$fd_mgid|s:m.sub.sig"] >= 0}] \
          [expr {[lsearch -exact $fd_sig "$fd_mgid|s:m.sub.count\[3\]"] >= 0}]] \
    [list 1 0]
  pcall ::wviewer::searchbar_set $FDB \
    [dict merge [pcall ::wviewer::searchbar_get $FDB] {pattern {}}]
  pcall ::wviewer::browser_refresh $tok 0
  update

  # ⚠⚠ ISSUE 0308's TOMBSTONE, FROM THE DIGITAL SIDE — A DECLARED LIMIT THIS
  # ITEM DOES **NOT** FIX, PINNED AS A VALUE SO IT CANNOT BE FORGOTTEN OR
  # QUIETLY "FIXED" WITHOUT THIS CHECK MOVING.
  #
  # The whole tree half above works: `m` and `m.sub` are real rows of the
  # foreign VCD's subtree (FD42) and the Search bar reaches them (FD43). The
  # LOWER PANE is a different surface with a different reader —
  # `browser_sea_refresh` draws it out of `browserseaent`, which is the CURRENT
  # database's entries and only those (two-pane item 15's declared limit,
  # BD70d). So selecting a FOREIGN digital scope by hand selects a real row and
  # lists NOTHING, under a caption that is a true sentence about the current
  # database and a false one about the node on screen. That is issue 0308
  # exactly, reproduced here from the case item 15 could not reach.
  #
  # RULING F4 does not touch it and was never able to: the classification is
  # right (FD42 proves the rows exist and are digital), and what is missing is
  # a per-ROW inventory reader. FD44-FD47 below are the half this item DOES
  # add — the same scope, listed and labelled correctly, once that database is
  # the CURRENT one. When 0308 is fixed this check must be restated, not
  # deleted: leg 2 becomes the six names and leg 3 the ordinary count. Leg 1 is
  # this check's own positive evidence and is FALSE on a pre-ruling tree (the
  # `devnode` rows are not there to select), which is what stops it being a
  # check that merely restates shipped behaviour. Oracle: sabotage S17.
  pcall $FDV.pw.tvf.tv selection set [list "$fd_mgid|g:m.sub"]
  update
  check {FD48 (F3, ISSUE 0308 DECLARED LIMIT) a FOREIGN digital scope selects a
         real row whose leaves are in the tree, and the lower pane still lists
         NOTHING under the current database's own `seaempty` caption} \
    [list [expr {[lsearch -exact [fd_ids $tok] "$fd_mgid|s:m.sub.sig"] >= 0}] \
          [fd_pane $tok] \
          [$FDV.pw.sea.st cget -text] \
          [pcall ::wviewer::browser_sea_own $tok {m.sub}]] \
    [list 1 {} {m.sub has no signals of its own} 0]

  # FD51's question asked of THE REAL TREE, on rows the product built, with the
  # analog raw CURRENT and the VCD foreign — the case a snapshot fixture cannot
  # prove, because `$fd_mgid` is the registry prefix the product minted.
  # Leg 3 is the state `Descend to here` is gated on (:8611 and :9824 both test
  # `[lindex $tp 0] eq {ok}`): before the fix it was `err`, so the entry was
  # DISABLED on a scope plus one of its own wires, while leg 2 alone answered
  # `sub` and descended to a node this tree never showed.
  # ⚠ LEG 4 IS THE CONTROL IN THE SAME TREE AND THE SAME CALL: the CURRENT
  # analog raw's own root net still resolves as ngspice, so this is not
  # "declassing switched off".
  check {FD54 (F4 FIX, REAL TREE) the foreign digital SCOPE row and its own WIRE
         row resolve to the SAME path through the product's own resolver and
         select together as `ok`, while the current analog raw is unaffected} \
    [list [pcall ::wviewer::browser_target_path $tok [list "$fd_mgid|g:m.sub"]] \
          [pcall ::wviewer::browser_target_path $tok [list "$fd_mgid|s:m.sub.sig"]] \
          [pcall ::wviewer::browser_target_path $tok \
             [list "$fd_mgid|g:m.sub" "$fd_mgid|s:m.sub.sig"]] \
          [pcall ::wviewer::browser_target_path $tok [list {s:v(anlg)}]] \
          [pcall ::wviewer::browser_id_type $tok "$fd_mgid|s:m.sub.sig"] \
          [pcall ::wviewer::browser_id_type $tok {s:v(anlg)}]] \
    [list {ok m.sub} {ok m.sub} {ok m.sub} [list ok {}] vcd tran]

  # ===========================================================================
  # THE DIGITAL DATABASE AS THE **CURRENT** ONE. Everything above rides the
  # foreign-inventory path; this is the other half, and it is the only path that
  # reaches the LOWER PANE — `browserseaent` is the current database's entries
  # alone (item 15's declared limit, RULING F1e). A pure-digital run has no analog
  # raw at all, so this is not a contrivance.
  # ===========================================================================
  wviewer::switch_ctx $tok
  set fd_sw 0
  catch {set fd_sw [xschem raw switch 2]}
  wviewer::browser_refresh $tok 1
  update
  check {FD44 (F3/F4) with the VCD CURRENT the browser knows its kind, and its
         own-level count at `m.sub` is the six wires it declares} \
    [list $fd_sw [pcall ::wviewer::browser_curtype $tok] \
          [pcall ::wviewer::browser_sea_own $tok {m.sub}] \
          [pcall ::wviewer::browser_sea_own $tok {sub}]] \
    [list 1 vcd 6 0]
  pcall $FDV.pw.tvf.tv selection set [list {g:m.sub}]
  update
  check {FD45 (F3/F4) the lower pane lists that scope's own signals and draws
         every one of them BARE — no `:i`, no eaten bus index} \
    [list [fd_pane $tok] \
          [expr {[llength [$FDV.pw.sea.c find withtag cell]] == \
                 [llength $::wviewer::browsersea($tok)]}]] \
    [list [list sig count {count[0]} {count[1]} {count[2]} {count[3]}] 1]
  # ...and the caption is the ordinary count, NOT the "has no signals of its own"
  # arm — which is what a declassed path would have produced here.
  check {FD46 (F3/F4) the pane's caption is the ordinary count for that scope} \
    [$FDV.pw.sea.st cget -text] {6 of 6 signals}

  # FD52's question asked of THE REAL PANE, with the VCD CURRENT — the only
  # configuration in which the lower pane's resolver is reachable at all. The
  # tree row and the pane row are two different resolvers reading two different
  # snapshots, and the fix is only a fix if they agree.
  # ⚠ LEG 1 IS `browser_sea_name 0`, ASSERTED RATHER THAN ASSUMED: the pane's
  # order is FD45's, so index 0 is `sig`, and a leg that resolved some other row
  # would answer the same path for the wrong reason.
  check {FD55 (F4 FIX, REAL PANE) with the VCD CURRENT the lower pane's own
         Descend-to resolver and the tree's agree on the real scope, and a group
         plus its own child is `ok` rather than a refusal} \
    [list [pcall ::wviewer::browser_sea_name $tok 0] \
          [pcall ::wviewer::browser_sea_target_path $tok 0] \
          [pcall ::wviewer::browser_target_path $tok [list {g:m.sub}]] \
          [pcall ::wviewer::browser_target_path $tok \
             [list {g:m.sub} {s:m.sub.sig}]]] \
    [list {m.sub.sig} {ok m.sub} {ok m.sub} {ok m.sub}]

  # ⚠⚠ THE **CURRENT** DATABASE'S MATCHER KEY, WHICH NOTHING ABOVE REACHES.
  # FD43 covers the All-DBs loop's key; `browser_match`'s own key is a SECOND
  # site, and every check above this one runs with an EMPTY pattern — which
  # `sig_match` short-circuits BEFORE it ever invokes the key. So reverting
  # browser_match to the bare `browser_label_of` reddened NOTHING until this
  # check existed. Found by running that sabotage, not by reading the code.
  # `sig`, anchored and whole-subject, is worth zero against the raw name
  # `m.sub.sig` and zero against its analog label `sig:i`.
  pcall ::wviewer::searchbar_set $FDB \
    [dict merge [pcall ::wviewer::searchbar_get $FDB] {pattern sig}]
  pcall ::wviewer::browser_refresh $tok 0
  update
  check {FD47 (F3/F4) with the VCD CURRENT the Search bar matches its OWN
         database by the label the pane draws — one name of seven} \
    [list [$FDV.ph cget -text] \
          [expr {[lsearch -exact [fd_ids $tok] {s:m.sub.sig}] >= 0}]] \
    [list "Signal Browser\n1 of 7 signals" 1]
  pcall ::wviewer::searchbar_set $FDB \
    [dict merge [pcall ::wviewer::searchbar_get $FDB] {pattern {}}]
  pcall ::wviewer::browser_refresh $tok 0
  update

  catch {wviewer::close $tok}
  }
  }
} else {
  puts "SKIPPED: group FD1x (Tk/X arm only)"
}

wvbs_finish
