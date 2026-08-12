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

# --- §F item F6 (issue 0308): the COLLIDING pair -----------------------------
#
# ⚠⚠ THE TWO DATABASES CARRY THE SAME PATH AND ONE OF THE SAME LEAF NAMES, AND
# THAT IS THE ONLY FIXTURE THAT CAN SEE THIS DEFECT. `browser_id_path` stripped
# the `d:N|` prefix and the pane then looked the surviving path up in whichever
# inventory was current — so with DISTINCT names in each database the symptom is
# an EMPTY pane (visible, and what issue 0308 recorded), while with COLLIDING
# ones it is a FULL pane listing the wrong run's signals, same length, same
# caption, no cue anywhere. A check built on distinct names passes against the
# broken code for the wrong reason.
#
#   raw (current)  time  v(rootraw)  v(x1.same)  v(x1.onlyraw)
#   vcd (foreign)  time              x1.same     x1.onlyvcd
#
# `time` is in BOTH (the engine synthesises it for a VCD exactly as ngspice
# writes it into a raw) and `v(rootraw)` in only one, which is what makes the
# design ROOT — where `g:` and `d:N|g:` decode to the same empty path — tell the
# two databases apart at all.
#
# `x1` is deliberate: a subcircuit instance is hierarchy under ngspice's grammar
# and a plain module name under Verilog's, so BOTH databases really do own the
# path `x1` and the two panes differ only by their contents (RULING F4's
# single-letter case is FD41-FD48's subject and is kept out of this one).
proc fd_mkraw_x1 {path} {
  set body "Title: test\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 4\nNo. Points: 3\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(rootraw)\tvoltage\n"
  append body "\t2\tv(x1.same)\tvoltage\n\t3\tv(x1.onlyraw)\tvoltage\n"
  append body "Values:\n0\t0.0\n\t0.0\n\t0.0\n\t0.0\n\n"
  append body "1\t1e-09\n\t1.0\n\t1.0\n\t1.0\n\n"
  append body "2\t2e-09\n\t0.5\n\t0.5\n\t0.5\n\n"
  fd_wr $path $body
}
proc fd_mkvcd_x1 {path} {
  fd_wr $path "\$timescale 1ps \$end
\$scope module x1 \$end
 \$var wire 1 ! same \$end
 \$var wire 1 # onlyvcd \$end
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

# the LOWER PANE's drawn labels, in order — the one reader every pane check in
# this file uses, so "what the pane lists" is one expression and not five.
proc fd_pane {tok} {
  set o {}
  foreach p $::wviewer::browsersea($tok) { lappend o [lindex $p 0] }
  return $o
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

# --- FD59: §F ITEM F6 — THE DECODE STOPS THROWING THE DATABASE AWAY ----------
#
# ⚠⚠ THIS IS THE FIRST STEP OF ISSUE 0308's MECHANISM, ISOLATED. `browser_id_path`
# stripped `d:N|` and returned the bare path, so the one fact that said WHICH
# inventory to resolve in was gone before the lookup started; every caller then
# resolved in the only one there was. The decode now answers BOTH halves and the
# two shipped projections are that same decode read twice, so `browser_row_db`
# and `browser_id_path` cannot drift about what a prefix is (they were two copies
# of one regexp, with a comment asking the reader to keep them equal).
#
# Legs 5/6 are the projections' FROZEN meanings: `TP44` counts the one decoder's
# call sites in `browser_target_path` and `browser_show_path` as an exact 1/1, so
# `browser_id_path` had to keep its signature and its answer to the character.
# Leg 7 is the design-root case both prefixed and not — `d:0|g:` and `g:` decode
# to the same empty path, which is precisely why the pane needed the other half.
check {FD59 (F6) the row-id decode answers the DATABASE as well as the path, and
       the two shipped projections are that one decode read twice} \
  [list [pcall ::wviewer::browser_id_split {d:1|g:TOP.m}] \
        [pcall ::wviewer::browser_id_split {g:x1}] \
        [pcall ::wviewer::browser_id_split {d:12|s:v(a)}] \
        [pcall ::wviewer::browser_id_split {s:v(a)}] \
        [pcall ::wviewer::browser_id_path {d:1|g:TOP.m}] \
        [pcall ::wviewer::browser_row_db  {d:1|g:TOP.m}] \
        [pcall ::wviewer::browser_id_split {d:0|g:}] \
        [pcall ::wviewer::browser_id_split {g:}]] \
  [list {1 TOP.m} {{} x1} {12 v(a)} {{} v(a)} TOP.m 1 {0 {}} {{} {}}]

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
  # ⚠⚠ RESTATED BY §F ITEM F6, NOT DELETED, AND THE MOVEMENT IS THE POINT. As
  # shipped this check asserted the OPPOSITE — `{1 0 0}`: the scope is shown and
  # the lower pane lists NOTHING, because the pane was drawn from
  # `browserseaent`, the CURRENT database's entries alone (item 15's declared
  # limit, BD70d one file over), so a FOREIGN VCD's scope selected a real row and
  # listed nothing under the false caption "'TOP.m' has no signals of its own".
  # That was issue 0308. RULING F6 gives the pane a per-database dimension, and
  # the same row now lists the VCD's OWN two wires, drawn bare.
  #
  # It is the NAMES and not merely the count, because the count alone cannot
  # tell "the foreign database was read" from "the current one happened to have
  # two names at this path" — which is exactly the confusion FD59 below is built
  # to break. `siga`/`sigb` exist in the VCD and nowhere else in this fixture.
  check {FD19 (F5/F1e, RESTATED BY §F ITEM F6) the digital scope is shown AND the
         lower pane now lists that FOREIGN database's own two wires — issue
         0308's state is gone} \
    [list [pcall ::wviewer::browser_sea_empty $tok] \
          [fd_pane $tok] \
          [llength [$FDV.pw.sea.c find withtag cell]] \
          [pcall ::wviewer::browser_sea_own $tok {TOP.m} [lindex $fd_r 1]] \
          [pcall ::wviewer::browser_sea_own $tok {TOP.m}]] \
    [list 0 {siga sigb} 2 2 0]
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
  #
  # ⚠⚠ AND IT GOES BACK TO THE VCD's `TOP`, NOT TO ITS `TOP.m`, SINCE §F ITEM
  # F6. FD20/FD21 need a pane that is EMPTY, and until F6 every foreign row was
  # one; now `TOP.m` lists the VCD's two wires (FD19) and only a PURE ANCESTOR
  # is empty. `TOP` is that ancestor INSIDE THE FOREIGN DATABASE, which is a
  # stricter fixture than the one it replaces: it is empty because the VCD
  # really declares nothing at that level, not because the pane could not read
  # the VCD at all.
  pcall $FDV.pw.tvf.tv selection set [list "$fd_gid|g:TOP"]
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
  # ⚠⚠ `TOP`, NOT `TOP.m`, SINCE §F ITEM F6 — AND THE MOVE IS WHAT KEEPS THESE
  # TWO CHECKS ABOUT WHAT THEY CLAIM. Step 7b is gated on `browser_sea_empty`,
  # and F6 made that reader ask the ROW's OWN database, so `TOP.m` now lists two
  # wires (FD19), the arm correctly declines and there is no notice left to
  # measure the SETTLE with. `TOP` is the VCD's own pure ancestor: the show
  # succeeds, the pane is genuinely empty, the arm fires — so FD23/FD24 still
  # drive the exact ordering they were written for (RULING F1f's flush), and
  # they now also pin RULING F1g's re-caused sentence, which is the only place
  # in the suite that reads it end to end.
  set ::fd_dig [list ok $fd_vcd TOP]

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
  # ⚠ RULING F1g's sentence, verbatim. RULING F1e's original blamed the lower
  # pane's single-database reader — true then, false since §F item F6 — and the
  # arm was RE-CAUSED rather than deleted (spec RULING F1g): the predicate still
  # fires on a real empty pane, and the sentence now names the true reason while
  # still saying that the show SUCCEEDED and which database it landed in, which
  # the shipped `seaempty` caption does not.
  set fd_want "showing the digital scope 'TOP' of 'fd_dig.vcd' in the tree,\
 but that scope has no signals of its own - open one of its sub-scopes to see any"
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
  # ⚠ LEG 2 RESTATED BY §F ITEM F6. It used to read
  # `TOP.m has no signals of its own` — the falsehood issue 0308 quoted, which
  # is what the pane reverted to. The erasure this tombstone is about is
  # unchanged; what comes back is now the TRUE shipped caption for that scope,
  # `2 of 2 signals`, so the check still proves the notice was wiped and no
  # longer asserts a sentence the product has stopped producing.
  check {FD25 (F5/F1e TOMBSTONE) a notice written WITHOUT the settle is erased by
         the queued refresh, and the shipped caption comes back} \
    [list $fd_before [$FDV.pw.sea.st cget -text] $::wviewer::browserseanote($tok)] \
    [list {FD25 unflushed} {2 of 2 signals} {}]

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
  # FD70-FD75 — ISSUES 0314 AND 0313: THE GESTURE'S OWN CALLBACK FRAME.
  #
  # ⚠⚠ EVERY CHECK ABOVE READS THE VIEWER FROM A CIW-SHAPED CALL, AND THAT IS
  # THE ONE ROUTE THE DEFECT SPARED. `callback()` (src/callback.c ~9098) raises
  # `xctx->semaphore` for the whole of any key or button gesture, and
  # switch_window/switch_tab (src/xinit.c) refuse a context switch outright
  # while it is raised — so every viewer LOAN taken from inside a gesture was
  # refused, 100% of the time, while the identical call typed into the CIW
  # worked. Issue 0314: a VCD that was attached AND LISTED was reported as "not
  # among the loaded results databases: run the simulation". Issue 0313: the
  # same refusal emptied the whole sidebar.
  #
  # MEASURED, at a real Ctrl-Alt-V on the batch F fixture (receipt
  # doc/claude/batch_F/receipts/14-0314-0313-gesture-context-loan.md):
  #   >>> ENTRY sem=1 cur=.drw
  #   enter_ctx REFUSED-C(switch_ctx) inwin=1 prev='.drw' sem=1 ticket='0 {}'
  # and the same call at sem=0 answering 2 databases one statement later.
  #
  # ⚠ `xschem set semaphore 1` IS NOT A MODEL OF THE GESTURE, IT IS THE STATE
  # THE GESTURE HOLDS — measured equal at the Tcl entry point. FD73 then drives
  # the REAL C entry (`xschem callback`, the exact command string the canvas's
  # <KeyPress> binding runs) so the two routes are compared, not assumed.
  # ===========================================================================
  xschem new_schematic switch .drw
  update
  # ⚠ THE PRECONDITION IS A LEG, NOT AN ASSUMPTION (review finding). Everything
  # above this block runs with the VIEWER context current, and if the switch
  # back to `.drw` ever failed to take, `signal_list_all` would be answering
  # from inside the viewer — no loan needed, nothing under test, four green
  # legs. So the context is read here and again after the loan: cross-context
  # going in, and BACK where it started coming out.
  set fd_ctx0 [pcall xschem get current_win_path]
  set fd_sem0 [llength [pcall ::wviewer::signal_list_all $tok]]
  # THE GESTURE'S OWN SEMAPHORE, and the balance after it: a loan that lowered
  # the frame's semaphore and forgot to put it back would leave callback()'s
  # trailing `semaphore--` to reach -1.
  xschem set semaphore 1
  set fd_sem1 [llength [pcall ::wviewer::signal_list_all $tok]]
  set fd_sem1_after [pcall xschem get semaphore]
  set fd_ctx1 [pcall xschem get current_win_path]
  xschem set semaphore 0
  check {FD70 (0314) the viewer's registry is readable from inside a gesture's
         callback frame, and both the frame's semaphore and its context come
         back} \
    [list $fd_ctx0 $fd_sem0 $fd_sem1 $fd_sem1_after $fd_ctx1] \
    [list .drw 2 2 1 .drw]
  # ⚠ THE OTHER HALF OF THE RETRY: lowered, and STILL refused. Nothing else in
  # the suite stands in that window — FD71 returns at the `sem != 1` gate and so
  # does the ASE arm's dead-window token, so the lowering was under test and its
  # matching restore was not (review finding). A live `windows` entry whose
  # win_path is not a window forces exactly it: the retry lowers, switch_ctx
  # refuses again, and the frame's semaphore must still come back.
  dict set ::wviewer::windows fd_dead win_path .fd_no_such.drw
  xschem set semaphore 1
  set fd_dead_st ok
  set fd_dead_n [llength [pcall ::wviewer::signal_list_all fd_dead fd_dead_st]]
  set fd_dead_sem [pcall xschem get semaphore]
  set fd_dead_ctx [pcall xschem get current_win_path]
  xschem set semaphore 0
  dict unset ::wviewer::windows fd_dead
  check {FD70b (0314) a loan that lowers the semaphore and is refused ANYWAY
         gives the frame its semaphore back and does not move the context} \
    [list $fd_dead_n $fd_dead_st $fd_dead_sem $fd_dead_ctx] \
    [list 0 refused 1 .drw]
  # ⚠⚠ AND THE RESTORE THAT ITSELF FAILS. The borrowed value must come back even
  # when leave_ctx's context restore is REFUSED, because the owning frame's
  # `xctx->semaphore--` lands on whatever context is current at that moment: a
  # value dropped here would decrement the wrong context to -1, which reads as a
  # permanently raised semaphore and would refuse every switch that context is
  # ever asked for again (review finding — the first cut gated the restore on
  # `$ok` and had exactly that hole). Driven with a hand-made ticket naming a
  # window that does not exist, the same shape test_wave_modes.tcl's M-group
  # uses for the refused-restore path.
  xschem set semaphore 0
  set fd_lv [pcall ::wviewer::leave_ctx $tok {1 .no.such.drw 1}]
  set fd_lv_sem [pcall xschem get semaphore]
  xschem set semaphore 0
  check {FD70c (0314) a REFUSED context restore still hands the borrowed
         semaphore back, to the context that will decrement it} \
    [list $fd_lv $fd_lv_sem] [list 0 1]
  # ⚠ THE BORROW IS OPT-IN, AND ONLY THE TWO READ-ONLY REGISTRY READERS ASK.
  # `semaphore == 1` is NOT proof of a gesture frame — `ase::wait` holds exactly
  # 1 across a `vwait` that pumps the event loop, and a menu-raised modal dialog
  # holds it around `tk_messageBox` — so a bracket whose body is caller-supplied
  # (`in_ctx`, at uplevel #0) must keep the refusal it has always had.
  xschem set semaphore 1
  set fd_noborrow [pcall ::wviewer::enter_ctx $tok]
  set fd_borrow [pcall ::wviewer::enter_ctx $tok 1]
  pcall ::wviewer::leave_ctx $tok $fd_borrow
  xschem set semaphore 0
  check {FD70d (0314) at a raised semaphore the loan is granted to a caller that
         opts in and refused to one that does not} \
    [list [lindex $fd_noborrow 0] [lindex $fd_borrow 0] [lindex $fd_borrow 2] \
          [pcall xschem get current_win_path]] \
    [list 0 1 1 .drw]
  # ⚠ THE CONSERVATIVE HALF, AND IT IS NOT DECORATION. `semaphore >= 2` is
  # callback.c's own "busy" convention (a recursive callback, a modal dialog, a
  # placement in flight) and those keep the refusal they have always had. A fix
  # that simply switched regardless would pass FD70 and lose this.
  xschem set semaphore 2
  set fd_sem2_st ok
  set fd_sem2 [llength [pcall ::wviewer::signal_list_all $tok fd_sem2_st]]
  xschem set semaphore 0
  check {FD71 (0314) a GENUINELY busy editor still refuses the loan, and says
         `refused` rather than answering an empty registry} \
    [list $fd_sem2 $fd_sem2_st \
          [llength [pcall ::wviewer::signal_list_all $tok]]] \
    [list 0 refused 2]
  # --- issue 0313: THE REFUSAL MUST NOT EMPTY THE SIDEBAR ---------------------
  # The browser's whole model is `browsersigs`; a refused reload used to
  # overwrite it with the refusal's empty answer, collapsing the tree to its
  # bare design root and the pane to nothing — and the root being already
  # selected, no <<TreeviewSelect>> fired and no click brought it back.
  set fd_sigs_before [llength $::wviewer::browsersigs($tok)]
  xschem set semaphore 2
  set fd_reload_r [pcall ::wviewer::browser_reload $tok]
  xschem set semaphore 0
  set fd_sigs_after [llength $::wviewer::browsersigs($tok)]
  pcall ::wviewer::browser_refresh $tok 0
  update
  check {FD72 (0313) a REFUSED reload leaves the browser's model and its lower
         pane exactly as they were — a refusal falls through, it does not
         strand the user (RULING F1b)} \
    [list $fd_sigs_before $fd_sigs_after $fd_reload_r \
          [llength $::wviewer::browsersea($tok)]] \
    [list 2 2 2 2]
  # ⚠ THE RELOAD'S **SECOND** ENGINE READ IS THE SAME RULING (review finding).
  # `browsersigs` is not the whole model: the per-database groups, the design
  # root's label and the current DB's identity all come from a separate
  # `signal_list_all` pass in the same proc, and a refusal there wiped all three
  # while FD72 stayed green. Forced with a reader that answers `refused` while
  # the first read still succeeds — the shape a teardown produces between the
  # two calls.
  set fd_db_before [llength $::wviewer::browserdbsigs($tok)]
  set fd_raw_before $::wviewer::browserraw($tok)
  rename ::wviewer::signal_list_all ::wviewer::fd_saved_sla2
  proc ::wviewer::signal_list_all {token {statusVar {}}} {
    if {$statusVar ne {}} { upvar 1 $statusVar st ; set st refused }
    return {}
  }
  pcall ::wviewer::browser_reload $tok
  rename ::wviewer::signal_list_all {}
  rename ::wviewer::fd_saved_sla2 ::wviewer::signal_list_all
  check {FD72b (0313) a refusal in the reload's SECOND read leaves the tree's
         per-database groups and the design root's label alone too} \
    [list $fd_db_before [llength $::wviewer::browserdbsigs($tok)] \
          [expr {$::wviewer::browserraw($tok) eq $fd_raw_before}]] \
    [list 1 1 1]
  pcall ::wviewer::browser_reload $tok
  pcall ::wviewer::browser_refresh $tok 0
  update
  # --- THE TWO ROUTES, COMPARED --------------------------------------------
  #
  # ⚠⚠ THE WHOLE OF 0314 IS THAT THEY DISAGREED, so this drives the SAME command
  # both ways and asserts one answer. Leg 2 goes through `xschem callback` —
  # byte for byte the command `bind $topwin <KeyPress>` runs (src/xschem.tcl
  # ~14164), with keysym 118 and state 12 (Control+Mod1), i.e. the Ctrl-Alt-V
  # chord seeded in the C binding table. It is the gesture's own entry point,
  # semaphore raise included.
  #
  # ⚠⚠ AND THE DIGITAL PROBE IS **NOT** STUBBED HERE, WHICH IS THE WHOLE VALUE
  # OF THESE TWO CHECKS. The first cut of them kept `fd_drive_on`'s
  # `browser_digital_probe` stub, so both routes were handed a pre-decided
  # `{ok <vcd> TOP}` and never read the registry at all — MEASURED: with the fix
  # reverted (sabotage S1) FD70 went red and these two stayed GREEN. What runs
  # instead is the real probe -> ase::cosim_scope_for_f1 -> step 4's
  # `cosim_db_inventory` -> `wviewer::signal_list_all`, i.e. the loan that the
  # gesture's own semaphore used to refuse. Only `ase::cosim_f1` (the DESIGN
  # read, which this file has no schematic for) is stubbed, and a real
  # co-simulation map entry is written so f2 matches it.
  set ::fd_vf [file join $scratch fd_dcell.v]
  fd_wr $::fd_vf "module dcell(input clk, output q);\nendmodule\n"
  ase::cosim_save_map [ase::session_state $tok] \
    [list [dict create model dcell lib fdlib cell dcell vfile $::fd_vf \
             module dcell scope TOP vcd $fd_vcd multi 0 ninst 1]]
  proc fd_live_on {} {
    fd_drive_on
    catch {rename ::ase::browser_digital_probe {}}
    rename ::ase::browser_digital_probe_fdsaved ::ase::browser_digital_probe
    rename ::ase::cosim_f1 ::ase::cosim_f1_fdsaved
    proc ::ase::cosim_f1 {instpath} {
      return [dict create inst a1 symref fdlib/dcell lib fdlib cell dcell \
        vfile $::fd_vf module dcell model dcell]
    }
  }
  proc fd_live_off {} {
    catch {rename ::ase::cosim_f1 {}}
    rename ::ase::cosim_f1_fdsaved ::ase::cosim_f1
    rename ::ase::browser_digital_probe ::ase::browser_digital_probe_fdsaved
    fd_drive_off
  }
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  fd_live_on
  pcall ase::show_in_browser_for_current
  fd_live_off
  update
  set fd_route_ciw [$FDV.pw.sea.st cget -text]
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  fd_live_on
  xschem new_schematic switch .drw
  pcall xschem callback .drw 2 0 0 118 0 0 12
  # ⚠ READ THE BALANCE HERE, BEFORE ANYTHING ELSE RUNS (review finding). This is
  # the one route with a REAL callback() frame, so it is the only place the
  # frame's own trailing `xctx->semaphore--` can land on the wrong context — and
  # a rendered caption is far downstream of that. Captured before `fd_live_off`
  # and before `update`, either of which could perturb both values.
  set fd_key_sem [pcall xschem get semaphore]
  set fd_key_ctx [pcall xschem get current_win_path]
  fd_live_off
  update
  set fd_route_key [$FDV.pw.sea.st cget -text]
  check {FD73 (0314) the Ctrl-Alt-V CHORD, driven through the canvas binding's
         own C entry point and resolving its scope for real, reaches the same
         caption as the CIW-shaped call, and leaves the frame's semaphore and
         context balanced — it is the route that used to disagree} \
    [list $fd_route_ciw $fd_route_key $fd_key_sem $fd_key_ctx] \
    [list $fd_want $fd_want 0 .drw]
  # ⚠⚠ AND THE SENTENCE THE DEFECT PRODUCED, PINNED AS A PAIR, WHICH IS WHAT
  # MAKES IT A CHECK AND NOT A RESTATEMENT OF FD73 (review finding: as a bare
  # negative over FD73's own two strings it could not fail unless FD73 did).
  # Leg 1 is the gesture on the fixture's REAL map entry: never `notloaded`.
  # Leg 2 is the same gesture with the map pointing at a VCD that genuinely is
  # NOT attached — where `notloaded` and its "run the simulation" IS the truth,
  # and must still be said. A fix that simply deleted the sentence passes the
  # negative and fails the pair.
  ase::cosim_save_map [ase::session_state $tok] \
    [list [dict create model dcell lib fdlib cell dcell vfile $::fd_vf \
             module dcell scope TOP vcd [file join $scratch fd_never_attached.vcd] \
             multi 0 ninst 1]]
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  fd_live_on
  xschem new_schematic switch .drw
  pcall xschem callback .drw 2 0 0 118 0 0 12
  fd_live_off
  update
  set fd_route_absent [$FDV.pw.sea.st cget -text]
  check {FD74 (0314) the gesture says `not among the loaded results databases`
         when that is TRUE and never when it is false} \
    [list [regexp {not among the loaded results databases} \
             "$fd_route_ciw $fd_route_key"] \
          [regexp {not among the loaded results databases.*run the simulation} \
             $fd_route_absent]] \
    [list 0 1]
  # put the honest map back for anything downstream
  ase::cosim_save_map [ase::session_state $tok] \
    [list [dict create model dcell lib fdlib cell dcell vfile $::fd_vf \
             module dcell scope TOP vcd $fd_vcd multi 0 ninst 1]]
  xschem new_schematic switch .drw
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

  # ⚠⚠ ISSUE 0308's TOMBSTONE, RESTATED THE WAY THE ISSUE ITSELF PRESCRIBED —
  # NOT DELETED. As shipped by item 6 this check asserted the DEFECT as a value:
  # legs 2/3 were `{}` and `m.sub has no signals of its own`, because
  # `browser_sea_refresh` drew the pane out of `browserseaent`, the CURRENT
  # database's entries and only those (two-pane item 15's declared limit,
  # BD70d), so selecting a FOREIGN digital scope by hand selected a real row and
  # listed NOTHING under a caption that was a true sentence about the current
  # database and a false one about the node on screen.
  #
  # §F item F6 gives the sea a per-database dimension, and issue 0308 named the
  # restatement in advance: "leg 2 becomes the six names and leg 3 the ordinary
  # count". It does. Leg 1 is this check's own positive evidence and is FALSE on
  # a pre-RULING-F4 tree (the `devnode` rows are not there to select).
  #
  # ⚠ LEGS 4 AND 5 ARE THE PAIR THAT MAKES "PER-DATABASE" AN ASSERTION RATHER
  # THAN A COUNT. The SAME path, asked of the same viewer, twice: told the
  # foreign row it answers that VCD's six; told nothing it answers the CURRENT
  # analog raw's zero. A single-inventory reader cannot produce both.
  pcall $FDV.pw.tvf.tv selection set [list "$fd_mgid|g:m.sub"]
  update
  check {FD48 (F3, ISSUE 0308 — RESTATED BY §F ITEM F6) a FOREIGN digital scope
         selects a real row AND the lower pane now lists that database's own six
         signals under the ordinary count} \
    [list [expr {[lsearch -exact [fd_ids $tok] "$fd_mgid|s:m.sub.sig"] >= 0}] \
          [fd_pane $tok] \
          [$FDV.pw.sea.st cget -text] \
          [pcall ::wviewer::browser_sea_own $tok {m.sub} "$fd_mgid|g:m.sub"] \
          [pcall ::wviewer::browser_sea_own $tok {m.sub}]] \
    [list 1 [list sig count {count[0]} {count[1]} {count[2]} {count[3]}] \
          {6 of 6 signals} 6 0]

  # ⚠⚠ AND THE PANE'S OWN `Descend to here` RESOLVER FOLLOWS THE PANE, NOT THE
  # CURRENT DATABASE — the second half of §F item F6, and the one a count check
  # cannot see. `browser_sea_target_path` splits the pane's names with a grammar,
  # and until F6 it asked `browser_curtype`: correct while the pane could only
  # ever hold the current database's names, wrong the moment it can hold a
  # foreign VCD's. With the ANALOG raw current and this VCD's `m.sub` pane drawn,
  # the shipped reader answers `ok sub` — the single-letter scope declassed away,
  # the menu entry built ENABLED against a node this tree never showed, which is
  # FD52's defect one database over.
  #
  # ⚠ LEG 1 IS ASSERTED, NOT ASSUMED: index 0 must really be `m.sub.sig`, or leg
  # 2 would answer the right path for the wrong row. Leg 3 is the CONTROL in the
  # same viewer moments later — the pane redrawn from the CURRENT analog raw
  # still splits as ngspice, so this is not "the resolver now always says vcd".
  set fd_sp_f [list [pcall ::wviewer::browser_sea_name $tok 0] \
                    [pcall ::wviewer::browser_sea_target_path $tok 0]]
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  check {FD56 (F6, REAL PANE) with the ANALOG raw CURRENT the lower pane's
         Descend-to resolver splits a FOREIGN VCD's name with that VCD's own
         grammar, while the current raw's own pane still splits as ngspice} \
    [list $fd_sp_f \
          [pcall ::wviewer::browser_sea_name $tok 0] \
          [pcall ::wviewer::browser_sea_target_path $tok 0]] \
    [list [list {m.sub.sig} {ok m.sub}] {time} [list ok {}]]

  # ⚠⚠ FD65 — AND THE GESTURE THAT USES THAT PATH WALKS THE ROW'S OWN
  # ---        DATABASE'S SUBTREE (batch F item 07 FIX PASS) -------------------
  #
  # FD56 asserts only what the RESOLVER RETURNS. Its one consumer,
  # `browser_sea_descend_to`, then looked the path up with
  # `browser_node_for $rows $segs [browser_root_id $rows]` — and `browser_root_id`
  # is hard-wired to the CURRENT database's root. So the database identity item 7
  # rescued was thrown away one proc later, and the item made it WORSE than it
  # found it: before the item `browser_sea_target_path` errored on a foreign pane
  # and the `Descend to here` entry was DISABLED, after it the entry is ENABLED
  # and the walk starts in the wrong tree.
  #
  # MEASURED on this very fixture, which is the honest one for it: `fd_anlg.raw`
  # is CURRENT and has no `m` node at all, so the walk found nothing and the user
  # was told `'m.sub' is not in the Signal Browser tree` — about `d:N|g:m.sub`,
  # which leg 1 shows IS a row of that tree. (Where the two databases collide the
  # walk finds the CURRENT database's namesake instead and says nothing at all;
  # that half is FD66.)
  #
  # ⚠ THE ORACLE IS THE ID HANDED ON, NOT THE STATUS TEXT. `browser_descend_to`
  # is the tree's own command and it takes a ROW ID; a spy on it records exactly
  # which row the pane's gesture resolved to, and `NEVER` records the arm that
  # returns 0 without calling it at all — so "descended to the wrong node" and
  # "refused with a false sentence" are different values here, and the shipped
  # code produces the second.
  # ⚠ THE SPY TAKES TWO PARAMETERS, `browser_descend_to`'s exact signature.
  pcall $FDV.pw.tvf.tv selection set [list "$fd_mgid|g:m.sub"]
  update
  # ⚠ AND THE ENTRY IS REALLY REACHABLE, which is what makes the wrong landing a
  # DEFECT rather than a theory: the pane's own context menu carries
  # `Descend to here`, ENABLED, on this foreign pane. (Before item 7 the resolver
  # errored here and the entry was DISABLED — so the item created the gesture and
  # owed it a correct walk.)
  set fd_dt_m [pcall ::wviewer::browser_sea_menu_build $tok 0]
  set fd_dt_ent {NO-MENU}
  catch {set fd_dt_ent [list [$fd_dt_m entrycget end -label] \
                             [$fd_dt_m entrycget end -state]]}
  rename ::wviewer::browser_descend_to ::wviewer::fd_dt_saved
  proc ::wviewer::browser_descend_to {token ids} { set ::fd_dt_ids $ids ; return 1 }
  set ::fd_dt_ids {NEVER}
  set fd_dt_rc  [pcall ::wviewer::browser_sea_descend_to $tok 0]
  set fd_dt_for [list $fd_dt_rc $::fd_dt_ids]
  set fd_dt_root [pcall ::wviewer::browser_sea_root_id $tok \
                    $::wviewer::browserrows($tok)]
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  set fd_dt_croot [pcall ::wviewer::browser_sea_root_id $tok \
                     $::wviewer::browserrows($tok)]
  rename ::wviewer::browser_descend_to {}
  rename ::wviewer::fd_dt_saved ::wviewer::browser_descend_to
  check {FD65 (F6 FIX) `Descend to here` out of a FOREIGN pane resolves inside
         THAT database's own subtree and hands its real row on, instead of
         failing with a sentence that denies a row the tree is showing} \
    [list [expr {[lsearch -exact [fd_ids $tok] "$fd_mgid|g:m.sub"] >= 0}] \
          $fd_dt_ent $fd_dt_root $fd_dt_croot $fd_dt_for] \
    [list 1 [list {Descend to here} normal] \
          "$fd_mgid|g:" {g:} [list 1 [list "$fd_mgid|g:m.sub"]]]

  # ⚠⚠ THE DEGRADATION DIRECTION, AS A VALUE. A `d:N|` row naming a slot the
  # snapshot does not carry lists NOTHING and counts 0 — never the current
  # database's entries. That is the whole lesson of issue 0308 read in the right
  # direction: absent is a state the caption can describe truthfully, someone
  # else's signals is not. Legs 3/4 are the positive control in the same call,
  # so "it answers {} for everything" is not the same picture.
  check {FD57 (F6) an unknown foreign registry slot lists NOTHING and counts 0,
         never the current database's inventory} \
    [list [pcall ::wviewer::browser_sea_ent $tok {d:99|g:m.sub}] \
          [pcall ::wviewer::browser_sea_own $tok {m.sub} {d:99|g:m.sub}] \
          [expr {[llength [pcall ::wviewer::browser_sea_ent $tok {g:}]] > 0}] \
          [pcall ::wviewer::browser_sea_own $tok {} {}]] \
    [list {} 0 1 2]

  # ⚠⚠ AND THE `has no signals of its own` CAPTION NAMES THE ROW'S OWN DESIGN.
  # This is where BD70d's declared limit lives one file over: `g:` and `d:N|g:`
  # decode to the SAME empty path, so a foreign design root used to be captioned
  # with the CURRENT run's name — one run's name on another run's pane. Leg 2 is
  # the control (the current DB still names itself), leg 3 the degradation (a
  # slot the snapshot has lost floors at `design`, never at the current design's
  # name), leg 4 the untouched non-root case.
  check {FD58 (F6) the empty-pane caption names the design of the ROW's OWN
         database, and floors at `design` rather than borrowing the current
         one's} \
    [list [pcall ::wviewer::browser_sea_label $tok {} "$fd_mgid|g:"] \
          [pcall ::wviewer::browser_sea_label $tok {}] \
          [pcall ::wviewer::browser_sea_label $tok {} {d:99|g:}] \
          [pcall ::wviewer::browser_sea_label $tok {m.sub} "$fd_mgid|g:m.sub"]] \
    [list fd_dig_m fd_anlg design {m.sub}]

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

  # =========================================================================
  # FD60-FD62 — §F ITEM F6 ON THE CASE THAT ACTUALLY DISCRIMINATES: TWO
  # DATABASES THAT COLLIDE.
  #
  # ⚠⚠ EVERYTHING ABOVE THIS LINE COULD HAVE BEEN GREEN FOR THE WRONG REASON.
  # `fd_anlg.raw` and the two VCDs share no path at all, so the SHIPPED,
  # single-inventory pane answered EMPTY for every foreign row — visible, and
  # what issue 0308 recorded. The state nobody could see is the one where the
  # two databases DO carry the same path: the pane then filled up with the
  # CURRENT run's signals under a foreign node, with the same length and the
  # same caption as the right answer. This fixture is that state, and it is the
  # only place in the file where a wrong answer and a right one are the same
  # shape.
  #
  #   raw (CURRENT, d:0)   time  v(x1.same)  v(x1.onlyraw)
  #   vcd (FOREIGN, d:1)         x1.same     x1.onlyvcd
  #
  # Both own the path `x1`; both own a leaf that draws as `same`; each owns
  # exactly one leaf the other does not. Two of two, either way.
  # =========================================================================
  set fd_rawc [file join $scratch fd_coll.raw]
  set fd_vcdc [file join $scratch fd_coll.vcd]
  fd_mkraw_x1 $fd_rawc
  fd_mkvcd_x1 $fd_vcdc
  wviewer::switch_ctx $tok
  set fd_atc [pcall ase::attach_dbs $fd_rawc tran [list $fd_vcdc]]
  wviewer::browser_refresh $tok 1
  update
  lassign [pcall ::wviewer::browser_db_group_id $tok $fd_vcdc] fd_cgid fd_ciscur
  # ⚠ THE LAST LEG IS THE STALENESS GUARD. The previous fixture held THREE
  # databases and this one holds two, so the registry slot `$fd_mgid` no longer
  # exists. The per-DB sea map is emptied at the top of every refresh and
  # refilled from the All-DBs loop; carried over instead, it would answer a
  # closed database's entries for a row id that can be persisted and restored
  # (`browser_tree_state`), which is the wrong-answer shape this item removes,
  # one refresh later.
  check {FD60 (F6 FIXTURE) the colliding pair attaches with the RAW current and
         the VCD foreign, the All-DBs box is on, BOTH databases really carry the
         path `x1` — and the departed database's slot carries nothing} \
    [list [wviewer::dget $fd_atc n NONE] $fd_ciscur \
          $::wviewer::sballdb($FDB) \
          [pcall ::wviewer::browser_curtype $tok] \
          [pcall ::wviewer::browser_sea_own $tok {x1}] \
          [pcall ::wviewer::browser_sea_own $tok {x1} "$fd_cgid|g:x1"] \
          [pcall ::wviewer::browser_sea_ent $tok "$fd_mgid|g:m.sub"]] \
    [list 2 0 1 tran 2 2 {}]

  # ⚠⚠ THE CHECK THE ITEM EXISTS FOR. Same viewer, same path, two rows: the
  # foreign row must list the VCD's pair and the current row the raw's, and the
  # ONLY thing that separates the two answers is the `d:1|` the shipped decode
  # threw away. `onlyvcd` exists in no other database in this process and
  # `onlyraw` in no other; `same` is in both, so leg-by-leg equality — not set
  # size, not the caption — is what carries the evidence. Against the shipped
  # code leg 1 reads `{same onlyraw}`: the right length, the right caption, the
  # wrong run.
  pcall $FDV.pw.tvf.tv selection set [list "$fd_cgid|g:x1"]
  update
  set fd_c_for [list [fd_pane $tok] [$FDV.pw.sea.st cget -text]]
  pcall $FDV.pw.tvf.tv selection set [list {g:x1}]
  update
  set fd_c_cur [list [fd_pane $tok] [$FDV.pw.sea.st cget -text]]
  check {FD61 (F6) THE COLLISION: the FOREIGN `x1` lists the VCD's own two names
         and the CURRENT `x1` lists the raw's own two, in one viewer, at one
         path, under captions that are word for word the same} \
    [list $fd_c_for $fd_c_cur] \
    [list [list {same onlyvcd} {2 of 2 signals}] \
          [list {same onlyraw} {2 of 2 signals}]]

  # ⚠⚠ THE SAME QUESTION AT THE DESIGN ROOT — BD70d's case, one file over, and
  # the one two-pane item 15 filed as a declared limit because `g:` and `d:N|g:`
  # decode to the SAME empty path. The raw carries a root net the VCD does not,
  # so the two roots are finally distinguishable: the foreign root lists the
  # VCD's `time` alone, the current root lists the raw's `time` and `rootraw`.
  # Against the shipped code BOTH read `{time rootraw}`.
  pcall $FDV.pw.tvf.tv selection set [list "$fd_cgid|g:"]
  update
  set fd_r_for [list [fd_pane $tok] [$FDV.pw.sea.st cget -text]]
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  check {FD63 (F6) the FOREIGN design ROOT lists that database's own top level,
         not the current database's — issue 0308's BD70d half} \
    [list $fd_r_for [fd_pane $tok] [$FDV.pw.sea.st cget -text]] \
    [list [list {time} {1 of 1 signals}] {time rootraw} {2 of 2 signals}]

  # ⚠⚠ AND A PLOT OUT OF THE FOREIGN PANE LANDS AGAINST THE FOREIGN DATABASE.
  # This is the same silent wrong answer one gesture further on: `plot_signals`
  # resolves a bare name through `resolve_signal_db`, which matches by NAME and
  # whose documented tie-break is THE CURRENT DATABASE WINS (`signal_list_all`
  # yields the current DB first and the first hit is returned — wave_viewer.tcl's
  # ⚠ at `resolve_signal_db`, and `db_by_index`'s, which exists for exactly this
  # reason). This fixture is a collision, so `x1.same` is in both: an unarmed
  # plot of the foreign one draws the CURRENT raw's `v(x1.same)` instead, with no
  # error and no cue. (`lowest-index` is the rule only AFTER the current database
  # has refused the name — the §D1 case, two VCDs under an analog current DB.) The
  # tree's plot route has carried the database since spec §D1's DEFECT 2; the
  # pane's could not, because until F6 it could only ever hold current-DB names.
  #
  # ⚠ THE SPY TAKES FOUR PARAMETERS — the signature `BM05` pins by literal
  # string one file over. It reads the armed list through the product's own
  # `plot_dbs_take`, which is where `plot_signals` itself reads it.
  rename ::wviewer::plot_signals ::wviewer::fd_ps_saved
  proc ::wviewer::plot_signals {token exprs {colors {}} {destover {}}} {
    set ::fd_pl_dbs   [wviewer::plot_dbs_take $token]
    set ::fd_pl_names $exprs
    return {}
  }
  set ::fd_pl_dbs {NEVER} ; set ::fd_pl_names {}
  pcall $FDV.pw.tvf.tv selection set [list "$fd_cgid|g:x1"]
  update
  set fd_pl_n [pcall ::wviewer::browser_sea_plot_idx $tok [list 0 1]]
  set fd_pl_for [list $fd_pl_n $::fd_pl_names $::fd_pl_dbs]
  set ::fd_pl_dbs {NEVER} ; set ::fd_pl_names {}
  pcall $FDV.pw.tvf.tv selection set [list {g:x1}]
  update
  pcall ::wviewer::browser_sea_plot_idx $tok [list 0 1]
  set fd_pl_cur [list $::fd_pl_names $::fd_pl_dbs]
  rename ::wviewer::plot_signals {}
  rename ::wviewer::fd_ps_saved ::wviewer::plot_signals
  check {FD62 (F6) plotting from the FOREIGN pane arms that database's registry
         slot for every name, while the CURRENT pane arms none — the per-signal
         database spec §D1 already gives the tree's plot route} \
    [list $fd_pl_for $fd_pl_cur] \
    [list [list 2 {x1.same x1.onlyvcd} [list [string range $fd_cgid 2 end] \
                                             [string range $fd_cgid 2 end]]] \
          [list {v(x1.same) v(x1.onlyraw)} {{} {}}]]

  # ⚠⚠ FD66 — THE COLLISION, ONE GESTURE ON: `Descend to here` (item 07 FIX).
  # FD65 is the case where the current database has no such node, which SHOWS as
  # a refusal. This is the case that shows as NOTHING: both databases own `x1`,
  # so the walk that started at the CURRENT database's root found `g:x1` and
  # descended against it with no error and no cue, out of a pane whose cells came
  # from the VCD. Same length, same success, wrong run — the exact shape issue
  # 0308 is about, which is why the discriminating fixture has to be this one.
  # ⚠ THE TWO LEGS ARE THE SAME CALL ON THE SAME PATH, so a reader cannot mistake
  # this for "the resolver now always prefixes": the CURRENT pane still hands on
  # the bare `g:x1`. Against the shipped code BOTH legs read `{1 g:x1}`.
  rename ::wviewer::browser_descend_to ::wviewer::fd_dt2_saved
  proc ::wviewer::browser_descend_to {token ids} { set ::fd_dt2_ids $ids ; return 1 }
  set ::fd_dt2_ids {NEVER}
  pcall $FDV.pw.tvf.tv selection set [list "$fd_cgid|g:x1"]
  update
  set fd_d2_for [list [pcall ::wviewer::browser_sea_descend_to $tok 0] $::fd_dt2_ids]
  set ::fd_dt2_ids {NEVER}
  pcall $FDV.pw.tvf.tv selection set [list {g:x1}]
  update
  set fd_d2_cur [list [pcall ::wviewer::browser_sea_descend_to $tok 0] $::fd_dt2_ids]
  rename ::wviewer::browser_descend_to {}
  rename ::wviewer::fd_dt2_saved ::wviewer::browser_descend_to
  check {FD66 (F6 FIX) with the two databases COLLIDING at `x1`, the pane's
         Descend-to hands on the row of the database the user is looking at —
         the foreign one out of the foreign pane, the current one out of the
         current pane} \
    [list $fd_d2_for $fd_d2_cur] \
    [list [list 1 [list "$fd_cgid|g:x1"]] [list 1 {g:x1}]]

  # ⚠⚠ FD67 — AND THE **OTHER** ENTRY IN THE SAME CONTEXT MENU (item 07 FIX).
  # The item armed the pane's `Plot` with the row's database (FD62) and left its
  # sibling `Send to Add Trace…` handing a bare name to a dialog whose OK
  # resolves names through `resolve_signal_db` — whose tie-break is THE CURRENT
  # DATABASE WINS (`signal_list_all` yields the current DB first). So on this
  # colliding fixture one menu entry landed on the run the user pointed at and
  # the one below it on the current run, silently. Newly reachable: before §F
  # item F6 the pane could only hold current-DB names and the bare hand-off was
  # right by construction.
  #
  # ⚠ THE ARM CARRIES THE NAME AS WELL AS THE INDEX, and leg 4 is why: the
  # dialog is modeless and its Expression field is meant to be EDITED, so an
  # index that outlived the text it was armed for would retarget whatever the
  # user typed. Leg 3 is the untouched text (the index is used), leg 4 the edited
  # text (it is not), leg 5 the CURRENT pane (nothing is ever armed).
  # ⚠ THE SPY TAKES SIX PARAMETERS, `add_trace`'s exact signature.
  set fd_atw [wviewer::window_for $tok].wvadd
  pcall $FDV.pw.tvf.tv selection set [list "$fd_cgid|g:x1"]
  update
  set fd_at_rc [pcall ::wviewer::browser_sea_send_to_add_trace $tok 0]
  set fd_at_arm {NONE}
  catch {set fd_at_arm $::wviewer::atddb($tok)}
  rename ::wviewer::add_trace ::wviewer::fd_at_saved
  proc ::wviewer::add_trace {token gi rpn {name {}} {color {}} {db {}}} {
    set ::fd_at_call [list $rpn $db] ; return {}
  }
  set ::fd_at_call {NEVER}
  pcall ::wviewer::add_trace_ok $tok
  set fd_at_kept $::fd_at_call
  # …the same gesture, then the user TYPES OVER the prefill: the arm is dropped.
  pcall ::wviewer::browser_sea_send_to_add_trace $tok 0
  catch {$fd_atw.expr delete 0 end ; $fd_atw.expr insert end {x1.onlyvcd}}
  set ::fd_at_call {NEVER}
  pcall ::wviewer::add_trace_ok $tok
  set fd_at_edit $::fd_at_call
  # …and the CURRENT pane arms nothing at all, so every pre-F6 path is unmoved.
  pcall $FDV.pw.tvf.tv selection set [list {g:x1}]
  update
  pcall ::wviewer::browser_sea_send_to_add_trace $tok 0
  set fd_at_curarm {ARMED}
  if {![info exists ::wviewer::atddb($tok)]} { set fd_at_curarm {NONE} }
  set ::fd_at_call {NEVER}
  pcall ::wviewer::add_trace_ok $tok
  set fd_at_cur $::fd_at_call
  rename ::wviewer::add_trace {}
  rename ::wviewer::fd_at_saved ::wviewer::add_trace
  # ⚠ FD68's material, gathered here so it rides the SAME live dialog: an arm
  # that outlived the dialog it was made for would hand a database to whatever
  # the user typed into the NEXT one, which is plot_dbs_take's discipline in this
  # form's terms. Leg 1 is the positive control — armed, and still armed while
  # the dialog is up — so "dropped" and "never armed" are different values.
  pcall $FDV.pw.tvf.tv selection set [list "$fd_cgid|g:x1"]
  update
  pcall ::wviewer::browser_sea_send_to_add_trace $tok 0
  set fd_at_live [info exists ::wviewer::atddb($tok)]
  catch {destroy $fd_atw}
  update
  set fd_at_dead [info exists ::wviewer::atddb($tok)]
  # …and REOPENING the form the way the Graph menu does starts unarmed, whatever
  # an abandoned earlier dialog left behind. ⚠ THAT IS THE SAME ONE OWNER, not a
  # second: `ase::ui::dialog_frame` opens with an unconditional
  # `catch {destroy $w}`, so the reopen fires the <Destroy> that drops the arm.
  # An explicit clear inside `add_trace_dialog` was written first and then
  # REMOVED — deleting it reddened nothing, which is this file's definition of a
  # line that is not there. Legs 3/4 are here to keep the OBSERVABLE property
  # pinned however that plumbing is arranged later; both move under the same
  # sabotage as leg 2.
  pcall ::wviewer::browser_sea_send_to_add_trace $tok 0
  set fd_at_live2 [info exists ::wviewer::atddb($tok)]
  pcall ::wviewer::add_trace_dialog $tok
  set fd_at_fresh [info exists ::wviewer::atddb($tok)]
  catch {destroy $fd_atw}
  update
  check {FD68 (F6 FIX) the lower pane's one-shot database dies with the dialog it
         was armed for, and a REOPENED dialog is never born armed} \
    [list $fd_at_live $fd_at_dead $fd_at_live2 $fd_at_fresh] \
    [list 1 0 1 0]
  check {FD67 (F6 FIX) `Send to Add Trace…` out of a FOREIGN pane carries that
         row's database to the OK, for the name it prefilled and no other, while
         the CURRENT pane arms nothing} \
    [list $fd_at_rc $fd_at_arm $fd_at_kept $fd_at_edit \
          $fd_at_curarm $fd_at_cur] \
    [list 1 [list {x1.same} [string range $fd_cgid 2 end]] \
          [list {x1.same} [string range $fd_cgid 2 end]] \
          [list {x1.onlyvcd} {}] \
          {NONE} [list {v(x1.same)} {}]]

  # ⚠⚠ FD69 — THE SAME GESTURE WITH NO SPY AT ALL, READ OFF THE TRACE THE
  # PRODUCT ACTUALLY BUILT. FD67 proves the ARGUMENT `add_trace` is handed;
  # this proves the RESULT, because an argument that some later arm discards is
  # exactly the shape of defect this fix pass exists to remove. A trace with no
  # `rawfile`/`sim_type` is `db_suffix`'s "ordinary current-DB trace" — i.e. the
  # raw — so the CONTROL and the claim are told apart by presence, not by count.
  proc fd_tr {tok} {
    set o {}
    foreach g [dict get [wviewer::layout_for $tok] graphs] {
      foreach t [wviewer::dget $g traces {}] {
        lappend o [list [wviewer::dget $t expr {}] \
                        [file tail [wviewer::dget $t rawfile {}]] \
                        [wviewer::dget $t sim_type {}]]
      }
    }
    return $o
  }
  pcall ::wviewer::clear_all $tok
  update
  pcall $FDV.pw.tvf.tv selection set [list "$fd_cgid|g:x1"]
  update
  pcall ::wviewer::browser_sea_send_to_add_trace $tok 0
  pcall ::wviewer::add_trace_ok $tok
  set fd_tr_for [fd_tr $tok]
  pcall ::wviewer::clear_all $tok
  update
  pcall $FDV.pw.tvf.tv selection set [list {g:x1}]
  update
  pcall ::wviewer::browser_sea_send_to_add_trace $tok 0
  pcall ::wviewer::add_trace_ok $tok
  set fd_tr_cur [fd_tr $tok]
  check {FD69 (F6 FIX, END TO END) the trace the product really builds from a
         FOREIGN pane's `Send to Add Trace…` names that database's file and its
         sim_type, while the CURRENT pane's carries neither} \
    [list $fd_tr_for $fd_tr_cur] \
    [list [list [list {x1.same} [file tail $fd_vcdc] vcd]] \
          [list [list {v(x1.same)} {} {}]]]

  catch {wviewer::close $tok}
  update
  # ⚠ THE TEARDOWN, AS A VALUE. §F item F6 adds two per-token arrays, and an
  # undeclared `variable` in `browser_forget` leaks one entry per closed window
  # forever — the rule that block's own comment states four times over. Leg 3 is
  # the shipped control, so "forget dropped everything" and "forget was never
  # reached" are not the same picture.
  check {FD64 (F6) closing the viewer drops the sea's two per-database arrays,
         beside the ones item 11 already dropped} \
    [list [info exists ::wviewer::browserseadbent($tok)] \
          [info exists ::wviewer::browserseadbid($tok)] \
          [info exists ::wviewer::browserseaent($tok)]] \
    [list 0 0 0]
  }
  }
} else {
  puts "SKIPPED: group FD1x (Tk/X arm only)"
}

wvbs_finish
