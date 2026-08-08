# tests/headless/test_wave_sigbrowser_i14.tcl — Signal Browser PLAN item 14:
# ALL DBs SEARCH. The `All DBs` checkbox from ViVA §3.2: with it ticked the
# Search bar searches EVERY open results database, not just the current one, and
# a row that came from another DB is labelled with its source in the tree.
# doc/claude/signal_browser_batch/PLAN.md item 14; receipts/14_receipt.md.
#
# ============================================================================
# ⚠⚠ WHY THIS FILE EXISTS AND IS NOT AN APPEND TO `_i1315.tcl`
# ============================================================================
# DRIVER RULING 30 (commit 18c45a16) split the browser checks BY ITEM RANGE
# after the pre-split 489-check file completed 0 of 9 standalone runs on this
# degraded box, with ZERO check failures — which made every later item's
# verification unmeasurable. The rule ruling 30 was cut on: EVERY
# DESIGN-WINDOW-COUPLED ITEM GETS ITS OWN PROCESS.
#
# Item 13 states EXPLICITLY that its own footprint claim does NOT cover item 14:
# item 14 holds TWO LIVE RAW DATABASES AT ONCE, an axis nobody had measured. A
# new axis under a rule about process footprint is exactly the case where the
# cheap, reversible answer is a new process — appending would have put a new,
# unmeasured load on the file that carries items 13 AND (later) 15, so a death
# there would take three items' evidence with it instead of one.
#
#   test_wave_sigbrowser.tcl       items 8, 9, 10   BS BT BM   (FROZEN)
#   test_wave_sigbrowser_i11.tcl   item 11          BH
#   test_wave_sigbrowser_i12.tcl   item 12          BX
#   test_wave_sigbrowser_i1315.tcl items 13, 15     BR      BP
#   test_wave_sigbrowser_i14.tcl   item 14          BD         <- THIS FILE
#
# GROUP PREFIX `BD`, reserved for item 14 by item 13's header. Numbers blocked
# by arm, so a fail name says which arm died:
#   BD01-BD09  SOURCE greps            both arms
#   BD10-BD25  PURE Tcl algebra        both arms
#   BD30-BD36  THE ENGINE CONTRACT     both arms — two real raws, NO viewer,
#                                      NO Tk: `raw info` / `raw switch` /
#                                      `raw list` are the whole mechanism this
#                                      item rests on, and pinning them on the
#                                      arm that always completes is deliberate
#   BD40-BD59  REAL viewer + REAL raws Tk/X only
#   BD60-BD66b TWO-PANE item 15 (R7), PURE Tcl algebra   both arms
#   BD67-BD70d TWO-PANE item 15 (R7), the CALLER + tree  Tk/X only
#
# ⚠ TWO-PANE ITEM 15 LIVES IN THIS FILE, not in `_i1315.tcl`, because R7's tree
# shape is only observable on a fixture holding TWO live raws — which is this
# file's whole footprint and nobody else's. `_i1315.tcl` owns the PERSISTENCE
# half (BP43a and the BP4x/BP5x re-keys); the two halves are cross-referenced.
# NEXT FREE IN THIS FILE: BD71.
#
# ⚠ THE FOOTPRINT STATEMENT FOR THIS FILE. The X group holds ONE viewer, TWO
# hand-written 3-point ASCII raws and NO DESIGN WINDOW — no `xschem load` of a
# design, no hierarchy walk, no second toplevel. That is item 13's BR4x
# footprint plus ONE extra ~400-byte raw kept resident, i.e. strictly less than
# the BH5x/BX4x groups ruling 30 was cut on. MEASURED, not asserted: see
# receipts/14_receipt.md for the standalone completion count.
#
# ============================================================================
# CONVENTIONS — SHARED (tests/headless/wvbs_common.tcl)
# ============================================================================
# `check`, `check_true`, `pcall`, the counting `::bgerror`, `wvproc_body`,
# `viewer_ready`, `$wsrc` and `wvbs_finish` come from wvbs_common.tcl, which is
# deliberately NOT named `test_*.tcl` (full_audit.sh globs `test_*.tcl` and
# would run a prelude as a zero-check case and score it FAIL forever).
#
# ⚠ SKIP-BANNER WORDING IS LOAD-BEARING: `SKIPPED: <group> (Tk/X arm only)`.
# NEVER `RESULT: SKIP`, never `skipped: no X`, never `SKIP: no X connection` —
# full_audit.sh's `is_skip` matches those and would score the WHOLE FILE as SKIP.
#
# ============================================================================
# ⚠⚠ THE NEGATIVE CLAIM AND ITS POSITIVE CONTROLS (ruling 29, driver note (d))
# ============================================================================
# The PLAN's ONE named sabotage targets a NEGATIVE check — "v(alpha) is excluded
# when the box is off". That picture is IDENTICAL to four other worlds: the
# second DB was never loaded; All-DBs never worked at all; the search returned
# nothing; the fixture's raws are unreadable. A check that cannot tell them
# apart is worth nothing, and this batch has caught that shape three times
# (items 11, 11 again, 12).
#
# So the negative NEVER stands alone here. Every one of them is paired:
#   BD30/BD42  both raws really read (engine arm AND viewer arm)
#   BD43       signal_list_all really sees TWO inventories
#   BD46 (OFF, no v(alpha))   is paired with BD47 (OFF, v(beta) IS there)
#                             and    BD48 (ON,  v(alpha) IS there, labelled)
#   BD51 (no empty A header)  is paired with BD48b (the A header DOES appear
#                             when A matches, on the same bar, same fixture)
#   BD55 (show_path restores) is paired with its own positive control: a plain
#                             refresh DOES overwrite the sentinel
#   BD56 (close unsets)       is paired with "it existed immediately before"
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_i14.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_i14.tcl

set ::wvbs_tag  wvsigbrowser_i14
set ::wvbs_name test_wave_sigbrowser_i14
source [file join [file dirname [info script]] wvbs_common.tcl]

# THE USER'S REAL FILES, recorded up front. Item 13's sabotage (b) reproduced
# issue 0119 LIVE and wrote /home/qflow/.xschem/raw_history — the user's real
# home directory — so every file in this batch now states what it could touch
# and proves it did not. This file never calls rawhist_push, but the raw HISTORY
# is one `rawbar_load` away from every viewer fixture, so BD59 checks it.
set bd_conf0     $::USER_CONF_DIR
set bd_home_file [file join $bd_conf0 raw_history]
set bd_home_pre  [file exists $bd_home_file]
set bd_home_txt  {}
if {$bd_home_pre} {
  set fd [::open $bd_home_file r] ; set bd_home_txt [read $fd] ; ::close $fd
}

# --- the fixture writer ------------------------------------------------------
# Item 13's `br_mkraw`, copied VERBATIM in shape (it is file-local there, and a
# shared copy in wvbs_common.tcl would be a third file to keep in step for two
# users). MEASURED to read cleanly: `points=3, vars=3, datasets=1 sim_type=tran`.
#
# ⚠ THE TRAILING EMPTY LINE AFTER EACH POINT IS MANDATORY. A `Values:` block
# whose points are not terminated that way drives `read_raw_ascii_point`
# (src/save.c:406, call sites :504 and :531) past the end of the buffer
# `read_raw_data_block` allocated for it and xschem dies. That is a PRE-EXISTING
# C defect — issue 0213, filed by item 13 — and settled decision 8 forbids
# fixing it here. This file therefore hand-writes only WELL-FORMED raws and
# tests no malformed-raw case at all; item 13 already covers that, safely, with
# a plain-text file.
proc bd_mkraw {path names npts} {
  set f [::open $path w]
  puts $f "Title: signal browser item 14 fixture"
  puts $f "Date: Wed Jan 1 00:00:00 2026"
  puts $f "Plotname: Transient Analysis"
  puts $f "Flags: real"
  puts $f "No. Variables: [llength $names]"
  puts $f "No. Points: $npts"
  puts $f "Variables:"
  set i 0
  foreach n $names {
    puts $f "\t$i\t$n\t[expr {$i == 0 ? {time} : {voltage}}]"
    incr i
  }
  puts $f "Values:"
  for {set p 0} {$p < $npts} {incr p} {
    set j 0
    foreach n $names {
      if {$j == 0} {
        puts $f "$p\t[expr {$p * 1e-9}]"
      } else {
        puts $f "\t[expr {$p * 0.1 + $j}]"
      }
      incr j
    }
    puts $f ""
  }
  ::close $f
}

# The `text` of the row that is `id`'s PARENT, or a distinct sentinel for each
# way it can fail — so "the leaf is at top level" and "there is no such leaf"
# can never masquerade as each other in a label assertion.
proc bd_parent_text {rows id} {
  set par {NO-SUCH-ROW}
  foreach r $rows {
    if {[dict get $r id] eq $id} { set par [dict get $r parent] ; break }
  }
  if {$par eq {NO-SUCH-ROW}} { return {NO-SUCH-ROW} }
  if {$par eq {}} { return {TOP-LEVEL} }
  foreach r $rows {
    if {[dict get $r id] eq $par} { return [dict get $r text] }
  }
  return {DANGLING-PARENT}
}

# --- TWO-PANE ITEM 15's row-model readers ------------------------------------
# Same rule as bd_parent_text above, one level up: every one of these answers a
# STABLE SENTINEL rather than throwing or returning {}, because "the row is
# gone" and "the row is there and its parent is top level" must never both read
# as the empty string. TWO-PANE item 15 moves whole id families at once
# (`s:v(beta)` -> `d:1|s:v(beta)`), so a reader that collapses absence into {}
# would let a HALF-DONE re-key read as a correct one.
proc bd_id_of {rows id} {
  foreach r $rows { if {[dict get $r id] eq $id} { return $id } }
  return {NO-SUCH-ROW}
}
proc bd_parent_of {rows id} {
  foreach r $rows {
    if {[dict get $r id] ne $id} { continue }
    set p [dict get $r parent]
    return [expr {$p eq {} ? {TOP-LEVEL} : $p}]
  }
  return {NO-SUCH-ROW}
}
proc bd_text_of {rows id} {
  foreach r $rows { if {[dict get $r id] eq $id} { return [dict get $r text] } }
  return {NO-SUCH-ROW}
}
proc bd_has {rows id} {
  foreach r $rows { if {[dict get $r id] eq $id} { return 1 } }
  return 0
}
# The text of the row TWO levels up. TWO-PANE item 15 inserts a design root
# BETWEEN a DB header and its leaves, so the leg that used to read the header's
# text off `bd_parent_text` now reads the ROOT's — and the header claim has to
# be restated one level higher rather than deleted.
proc bd_grandparent_text {rows id} {
  set par {NO-SUCH-ROW}
  foreach r $rows {
    if {[dict get $r id] eq $id} { set par [dict get $r parent] ; break }
  }
  if {$par eq {NO-SUCH-ROW}} { return {NO-SUCH-ROW} }
  if {$par eq {}} { return {TOP-LEVEL} }
  return [bd_parent_text $rows $par]
}
# `-open` off the WIDGET, with bd_tv_parent's three sentinels: `no-tree` /
# `absent` / 0 / 1. A bare `$tv item $id -open` THROWS on a missing id, which
# would abort the file instead of failing one check.
proc bd_tv_open {tv id} {
  if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
  if {[catch {$tv exists $id} ex]}         { return no-tree }
  if {!$ex}                                { return absent }
  if {[catch {$tv item $id -open} o]}      { return no-tree }
  if {[string is boolean -strict $o]} { return [expr {$o ? 1 : 0}] }
  return $o
}
# The tree's SELECTION as three distinguishable answers — `{}` from a bare
# `$tv selection` is BOTH "nothing selected" and "the widget is gone", and R4's
# whole claim is that the first of those never happens.
proc bd_tv_sel {tv} {
  if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
  if {[catch {$tv selection} s]}           { return no-tree }
  if {![llength $s]}                       { return none }
  return $s
}

# Every row id whose `name` is $n, in row order.
proc bd_ids_for {rows n} {
  set out {}
  foreach r $rows {
    if {[dict get $r kind] eq {leaf} && [dict get $r name] eq $n} {
      lappend out [dict get $r id]
    }
  }
  return $out
}

# --- TWO-PANE ITEM 10: reading the TREE WIDGET without ever throwing ----------
# Item 10 takes LEAF rows out of the treeview (`browser_tree_rows` keeps only
# `kind group`), so this file's widget assertions must be able to say
# "correctly not there" OUT LOUD. `$tv parent` / `$tv item` THROW on a missing
# id, and `pcall` turns that throw into ttk's own wording — not this item's
# claim, and IDENTICAL to what a destroyed widget would produce.
# Three NAMED states instead (the wvbs_common rule, spec §13.2):
#   no-tree   the widget is gone
#   absent    the widget is there and the id is not in it
#   <value>   the answer
# `top-level` is the THIRD state of `parent`: `{}` is an ANSWER (a top-level
# row), not an absence, and the two must never both read as the empty string.
proc bd_tv_parent {tv id} {
  if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
  if {[catch {$tv exists $id} ex]}         { return no-tree }
  if {!$ex}                                { return absent }
  if {[catch {$tv parent $id} p]}          { return no-tree }
  if {$p eq {}}                            { return top-level }
  return $p
}
proc bd_tv_text {tv id} {
  if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
  if {[catch {$tv exists $id} ex]}         { return no-tree }
  if {!$ex}                                { return absent }
  if {[catch {$tv item $id -text} t]}      { return no-tree }
  return $t
}
# The WHOLE upper pane as a SET, never a count: "1 node" is the same number for
# a tree holding the DB header and for one holding a stray leaf instead.
# `bs_tree_ids` (wvbs_common.tcl, item 10's own addition) is the shared
# depth-first walk; this adds the two sentinels it folds together — it answers
# `{}` both for "no widget" and for "empty tree".
proc bd_tv_ids {tv} {
  if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
  if {[catch {bs_tree_ids $tv} ids]}       { return no-tree }
  if {![llength $ids]}                     { return empty }
  return $ids
}

if {[catch {

# ============================================================================
# BD01-BD09 — SOURCE arm, BOTH arms. What the shipped bodies contain, and in
# what ORDER. Every behavioural claim is in BD30+/BD40+.
# ============================================================================
set bd_parse   [wvproc_body $wsrc wviewer::rawinfo_parse]
set bd_lab     [wvproc_body $wsrc wviewer::db_label]
set bd_sla     [wvproc_body $wsrc wviewer::signal_list_all]
set bd_box     [wvproc_body $wsrc wviewer::browser_alldbs]
set bd_rep     [wvproc_body $wsrc wviewer::browser_rows_reparent]
set bd_multi   [wvproc_body $wsrc wviewer::browser_rows_multi]
set bd_reload  [wvproc_body $wsrc wviewer::browser_reload]
set bd_refresh [wvproc_body $wsrc wviewer::browser_refresh]
set bd_build   [wvproc_body $wsrc wviewer::browser_build]
set bd_sbforget [wvproc_body $wsrc wviewer::searchbar_forget]

# ⚠ EVERY BODY MUST HAVE BEEN FOUND FIRST. `wvproc_body` answers {} on a rename
# or a reformatted signature, and `regexp -all` over {} is 0 — without this leg
# a rename makes every grep below VACUOUSLY GREEN (test_wave_grid's GX2 lesson).
check {BD01 every item-14 proc body was found in the source} \
  [list [expr {$bd_parse ne {}}] [expr {$bd_lab ne {}}] [expr {$bd_sla ne {}}] \
        [expr {$bd_box ne {}}] [expr {$bd_rep ne {}}] [expr {$bd_multi ne {}}] \
        [expr {$bd_reload ne {}}] [expr {$bd_refresh ne {}}] \
        [expr {$bd_build ne {}}] [expr {$bd_sbforget ne {}}]] \
  [list 1 1 1 1 1 1 1 1 1 1]

# PURITY IS WHAT LETS BD10-BD25 RUN IN THE --nogui ARM AT ALL. A parser or a row
# builder that reached a widget or the engine could not be exercised without X,
# and every ordering/labelling claim would then rest solely on the arm the
# degraded box keeps killing.
check {BD01b the four pure procs touch no widget, no engine, no disk} \
  [regexp -all {winfo |xschem |::open |puts |after } \
     "$bd_parse$bd_lab$bd_rep$bd_multi"] 0

# THE 0173 BRACKET. signal_list_all is the only browser read that MOVES the
# engine's current-DB pointer, so it needs signal_list's context bracket AND the
# refused-ticket bail — a scan that ran in somebody else's window would enumerate
# somebody else's raws.
check {BD02 signal_list_all carries the 0173 enter/leave bracket} \
  [list [regexp -all {wviewer::enter_ctx \$token} $bd_sla] \
        [regexp -all {wviewer::leave_ctx \$token \$ticket} $bd_sla]] \
  [list 1 1]
check {BD02 ...and BAILS on a refused ticket instead of reading anyway} \
  [regexp -all {!\[lindex \$ticket 0\]} $bd_sla] 1

# ORDER, NOT PRESENCE. A restore placed inside the loop restores nothing after
# the last switch; one placed after leave_ctx restores the wrong window's DB.
set bd_li [string first {foreach db [dict get $pi dbs]} $bd_sla]
set bd_ri [string first {xschem raw switch $cur} $bd_sla]
set bd_xi [string first {wviewer::leave_ctx} $bd_sla]
check {BD03 the DB restore comes AFTER the scan loop and BEFORE leave_ctx} \
  [expr {$bd_li >= 0 && $bd_ri >= 0 && $bd_xi >= 0 &&
         $bd_li < $bd_ri && $bd_ri < $bd_xi}] 1

# item 13's atomicity rule, inherited: `rawbar_load` deliberately never clears,
# which is what makes a failed read non-destructive. A scan that cleared would
# undo that for every DB it visited.
check {BD04 signal_list_all never clears a raw} \
  [regexp -all {raw clear} $bd_sla] 0
# NOTHING that can let a redraw run while the current DB is swapped.
check {BD04 ...and it neither updates nor defers mid-scan} \
  [regexp -all {\bupdate\b|\bafter \d} $bd_sla] 0

# decision 13: browser state derives from the RAW verbs, never from the rect
# model (0186 stays open). And the SOURCE OF TRUTH is the engine registry, not
# item 13's history — `attach_raw` never enters the history, so a history-driven
# enumeration would miss every ASE re-run DB.
check {BD05 signal_list_all enumerates through `xschem raw info`} \
  [regexp -all {xschem raw info} $bd_sla] 1
check {BD05 ...and never through the raw history or the rect model} \
  [regexp -all {rawhist|rect 2} $bd_sla] 0

# THE ONE READER. If the checkbox were read in two places the scope could differ
# between the inventory and the tree, and no row count could see it.
check {BD06 the checkbox reader is defined once and called once, file-wide} \
  [regexp -all {browser_alldbs} $wsrc] 2
check {BD06 ...the one call is in browser_refresh} \
  [regexp -all {wviewer::browser_alldbs \$token} $bd_refresh] 1
check {BD06 ...and browser_reload does NOT read it: the snapshot is unconditional} \
  [regexp -all {browser_alldbs} $bd_reload] 0

# signal_list stays the authority for the CURRENT DB (decision 13's shipped
# claim, items 8-13). signal_list_all is an ADDITION, not a replacement.
check {BD07 browser_reload still reads the current DB through signal_list} \
  [list [regexp -all {wviewer::signal_list \$token} $bd_reload] \
        [regexp -all {wviewer::signal_list_all \$token} $bd_reload]] \
  [list 1 1]

# THE BOX IS ON THE SEARCH BAR ONLY. The bottom Filter bar narrows a list that
# has already been fetched, so a DB scope there would mean nothing.
check {BD08 `-alldbs` appears exactly once in browser_build} \
  [regexp -all -- {-alldbs} $bd_build] 1
set bd_alline {}
set bd_filtline {}
foreach line [split $bd_build "\n"] {
  if {[string match {*-alldbs*} $line]}  { set bd_alline $line }
  if {[string match {*-name wvfilter*} $line]} { set bd_filtline $line }
}
# ⚠ THE OPTION IS APPENDED AFTER `-command`, AND THAT ORDER IS DELIBERATE.
# searchbar_build parses options in a `foreach {o v}` loop, so the two orders
# are identical to the widget — but item 9's BT05
# (tests/headless/test_wave_sigbrowser.tcl:726) is a SOURCE grep pinned to the
# literal `searchbar_build $f -command [list wviewer::browser_search_cb`, and
# ruling 30 FROZE that file. Putting `-alldbs 1` in front of `-command` turned
# BT05 red for no behavioural reason (MEASURED: full_audit run 1,
# test_wave_sigbrowser 323 passed / 1 failed). Appending keeps item 9's coverage
# byte-for-byte and this check pins the order so it cannot silently drift back.
check {BD08 ...appended to the wvsearch build line (item 9's BT05 grep intact), and the wvfilter line has none} \
  [list [string match {*searchbar_build $f -command *browser_search_cb $token\] -alldbs 1*} $bd_alline] \
        [expr {$bd_filtline ne {}}] \
        [string match {*-alldbs*} $bd_filtline]] \
  [list 1 1 0]

# EXACT PARITY WITH `sbcase`: a per-widget array element that outlives its bar
# leaks one entry per closed viewer, forever (the `gridshow` defect, twice).
check {BD09 searchbar_forget detaches AND unsets the All-DBs element} \
  [list [regexp -all {\$w\.alldb configure -variable} $bd_sbforget] \
        [regexp -all {unset sballdb\(\$w\)} $bd_sbforget]] \
  [list 1 1]

# ============================================================================
# BD10-BD25 — PURE Tcl. No widget, no engine, no X.
# ============================================================================

# ⚠ THE BLOB IS THE ONE THIS ITEM MEASURED LIVE off `xschem raw info` with two
# raws loaded (scratchpad probe14.tcl), not one invented to suit the parser.
set bd_blob "1 current\n0 /tmp/wv14/bd_a.raw tran\n1 /tmp/wv14/bd_b.raw tran\n"
set bd_p [wviewer::rawinfo_parse $bd_blob]
check {BD10 rawinfo_parse reads the live two-DB blob: cur and count} \
  [list [dict get $bd_p cur] [llength [dict get $bd_p dbs]]] [list 1 2]
check {BD10 ...and each line's idx/path/type} \
  [list [lindex [dict get $bd_p dbs] 0] [lindex [dict get $bd_p dbs] 1]] \
  [list {idx 0 path /tmp/wv14/bd_a.raw type tran} \
        {idx 1 path /tmp/wv14/bd_b.raw type tran}]

check {BD11 one loaded DB parses to one entry, cur 0} \
  [wviewer::rawinfo_parse "0 current\n0 /x/a.raw op\n"] \
  {cur 0 dbs {{idx 0 path /x/a.raw type op}}}

# `xschem raw info` prints NOTHING AT ALL when no raw is loaded (src/save.c:1456
# guards the whole block on `xctx->raw`). That is the COMMON case, not an edge
# one, and it must answer rather than throw — browser_reload rides the refresh
# path, which must not throw.
check {BD12 no raw loaded -> empty text -> cur -1, no DBs, no throw} \
  [pcall wviewer::rawinfo_parse {}] {cur -1 dbs {}}

# ⚠ THE DELIBERATE IMPROVEMENT ON THE LEGACY PARSE. xschem.tcl:4801 reads the
# same blob BY WORD (`foreach {n f t} [lrange [xschem raw info] 2 end]`), so a
# path with a space shifts every field after it. Per-line and anchored gets it
# right, and this is the leg that proves it.
set bd_sp [wviewer::rawinfo_parse "0 current\n0 /home/my sims/a b.raw tran\n"]
check {BD13 a rawfile path CONTAINING SPACES parses whole} \
  [list [dict get [lindex [dict get $bd_sp dbs] 0] path] \
        [dict get [lindex [dict get $bd_sp dbs] 0] type]] \
  [list {/home/my sims/a b.raw} tran]

# A line the engine never emits must be SKIPPED, not fatal, and must not take
# the good lines with it.
check {BD14 an unparseable line is skipped, the good ones survive} \
  [wviewer::rawinfo_parse "1 current\n### garbage ###\n1 /x/b.raw dc\n"] \
  {cur 1 dbs {{idx 1 path /x/b.raw type dc}}}

check {BD15 db_label is `<file tail> (<analysis>)`} \
  [wviewer::db_label /a/very/long/path/bd_a.raw tran] {bd_a.raw (tran)}
check {BD16 db_label degrades: no analysis, engine <NULL>, no path} \
  [list [wviewer::db_label /x/a.raw {}] [wviewer::db_label /x/a.raw {<NULL>}] \
        [wviewer::db_label {} tran]] \
  [list a.raw a.raw ?]
# THE REAL CASE THE PARENS EXIST FOR: extra_rawfile() keys its switch on file
# AND sim_type, so the SAME rawfile can be registered twice under two analyses.
# Without the analysis the two headers would be indistinguishable.
check {BD16b the same rawfile under two analyses gets two distinct labels} \
  [expr {[wviewer::db_label /x/s.raw tran] ne [wviewer::db_label /x/s.raw ac]}] 1

set bd_r0 [list [dict create id {s:v(a)} parent {} text {v(a)} kind leaf name {v(a)}] \
                [dict create id {g:x1}   parent {} text x1 kind group name {}] \
                [dict create id {s:v(x1.n)} parent {g:x1} text n kind leaf name {v(x1.n)}]]
set bd_rp [wviewer::browser_rows_reparent $bd_r0 {d:0|} {d:0}]
check {BD17 reparent prefixes every id and adopts the top-level rows} \
  [list [dict get [lindex $bd_rp 0] id] [dict get [lindex $bd_rp 0] parent] \
        [dict get [lindex $bd_rp 1] id] [dict get [lindex $bd_rp 1] parent]] \
  [list {d:0|s:v(a)} {d:0} {d:0|g:x1} {d:0}]
# ⚠ THE HALF THAT IS EASY TO GET WRONG: an EXISTING parent must be prefixed too.
# Left bare it would point at a `g:x1` that exists only in the CURRENT DB's rows,
# and ttk would either steal that node or throw on insert.
check {BD18 ...and a row that already had a parent keeps it, PREFIXED} \
  [list [dict get [lindex $bd_rp 2] id] [dict get [lindex $bd_rp 2] parent]] \
  [list {d:0|s:v(x1.n)} {d:0|g:x1}]

# THE BOX-OFF GUARANTEE, stated as an identity: one unlabelled group is
# browser_rows, byte for byte. Items 8-10's row assertions keep meaning what
# they meant.
set bd_ents {}
foreach n {time v(beta) v(shared)} { lappend bd_ents [wviewer::signal_entry $n] }
check {BD19 ONE unlabelled group == browser_rows, byte-identical} \
  [wviewer::browser_rows_multi [list [list {} {} $bd_ents]]] \
  [wviewer::browser_rows $bd_ents]

set bd_fents {}
foreach n {time v(alpha) v(shared)} { lappend bd_fents [wviewer::signal_entry $n] }
set bd_two [wviewer::browser_rows_multi \
              [list [list {} {} $bd_ents] [list {d:0} {bd_a.raw (tran)} $bd_fents]]]
check {BD20 a labelled group emits ONE header row, carrying the label} \
  [list [llength [bd_ids_for $bd_two {v(alpha)}]] \
        [bd_parent_text $bd_two [lindex [bd_ids_for $bd_two {v(alpha)}] 0]]] \
  [list 1 {bd_a.raw (tran)}]
# THE HEADER'S KIND IS `group` ON PURPOSE: browser_plot_at's `!$groups` guard,
# browser_leaf_names' parent walk and browser_menu_ids then all work UNCHANGED.
# item 14 adds no new row vocabulary.
check {BD21 the header row's kind is `group`, not a new kind} \
  [wviewer::browser_kind $bd_two {d:0}] group
# CURRENT DB FIRST AND UNPREFIXED — this is what keeps item 12's hierarchy sync
# landing on the current DB (BD25) and item 9's ids stable.
check {BD22 the current DB's rows come FIRST and are UNPREFIXED} \
  [list [dict get [lindex $bd_two 0] id] [dict get [lindex $bd_two 0] parent] \
        [dict get [lindex $bd_two 3] id]] \
  [list {s:time} {} {d:0}]
check {BD23 browser_leaf_names on a HEADER answers that DB's names} \
  [wviewer::browser_leaf_names $bd_two {d:0}] {time v(alpha) v(shared)}
# The same signal in two DBs is TWO rows with TWO ids — not a collision, not a
# silent dedup. A user comparing runs needs to see both.
check {BD24 a name present in BOTH DBs yields two distinct row ids} \
  [bd_ids_for $bd_two {v(shared)}] [list {s:v(shared)} {d:0|s:v(shared)}]
# A group with NO matched entries emits NO header: an empty `bd_a.raw (tran)`
# node would claim a DB matched when it did not.
check {BD24b a group with zero entries emits no header at all} \
  [wviewer::browser_rows_multi [list [list {} {} {}] [list {d:0} {bd_a.raw (tran)} {}]]] \
  {}

# ⚠ RISK 4, PINNED WITH A POSITIVE **AND** A NEGATIVE LEG. A DB header is a
# top-level `kind group` row, which is exactly what browser_node_for scans for —
# so it could shadow item 12's hierarchy sync. Two mitigations, both measured
# here: the current DB's groups come FIRST (so an exact match breaks on them),
# and a header's text carries a space and brackets, which no hierarchy segment
# can equal.
set bd_h1 {}
foreach n {v(x1.out) v(x1.mid)} { lappend bd_h1 [wviewer::signal_entry $n] }
set bd_h2 {}
foreach n {v(x1.out) v(y9.deep)} { lappend bd_h2 [wviewer::signal_entry $n] }
set bd_hrows [wviewer::browser_rows_multi \
                [list [list {} {} $bd_h1] [list {d:0} {bd_a.raw (tran)} $bd_h2]]]
# POSITIVE: `x1` exists in BOTH DBs, and the walk lands on the CURRENT one's
# node — the unprefixed `g:x1`, never the foreign `d:0|g:x1`.
check {BD25 browser_node_for still lands on the CURRENT DB's node} \
  [wviewer::browser_node_for $bd_hrows {x1}] {g:x1 1}
# NEGATIVE: `y9` exists ONLY in the foreign DB, where it is nested UNDER the
# header — so it is not a top-level node and the hierarchy walk does not find
# it. A foreign DB's hierarchy cannot be descended into by mistake.
check {BD25b ...and a FOREIGN-only hierarchy node is not reachable at top level} \
  [wviewer::browser_node_for $bd_hrows {y9}] {{} 0}
# ⚠ DECLARED, because the mitigation is a PROPERTY OF THE TEXT, not a guard:
# `browser_node_for` would happily match a header asked for by its literal text.
# It cannot happen from the real caller — `hier_split` yields dot-separated
# instance names, and a header text always carries a space and brackets.
check {BD25c the header text is unreachable from any hier_split output} \
  [list [llength [wviewer::hier_split {bd_a.raw (tran)}]] \
        [regexp {[ ()]} [dict get [lindex $bd_hrows 3] text]]] \
  [list 2 1]

# ============================================================================
# BD60-BD66b — TWO-PANE ITEM 15 (spec R7 / §4.3), the PURE half. BOTH ARMS.
#
# R7: with the All-DBs box ticked the tree's TOP LEVEL is the per-DB headers —
# the CURRENT DB included — and EACH DB gets its OWN design root under its own
# header. Item 14 shipped the headers for the FOREIGN DBs only, with the current
# DB emitted flat and NO design root anywhere (BD48c is that state's tombstone).
#
# ⚠⚠ THE CURRENT DB GETS A HEADER BUT KEEPS ITS UNPREFIXED IDS, AND THAT SPLIT
# IS A MEASUREMENT, NOT A PREFERENCE. PLAN item 15 asks for `d:0|` on group 0
# too. Spec §4.3's own closing sentence rules the other way — "the current DB is
# always group 0, unlabelled and unprefixed, and that invariant is what makes
# 'current' well-defined" — and only the *unlabelled* half can survive R7. The
# measurement settles it: the prefix is the DB's REGISTRY INDEX, which is not a
# property of the design. `test_wave_sigbrowser_i1315.tcl`'s restore fixture
# MEASURES that index moving from 1 to 0 across a snapshot/restore (two raws in,
# one raw back), so every persisted `d:1|g:x1.x2` would name a row that no longer
# exists and the user's selection and open set would silently evaporate. Keeping
# the current DB unprefixed makes its persisted ids index-INDEPENDENT, and
# BP47b/BP52-BP55 over there are the checks that say so. R7's letter — "per-DB
# headers become the tree's top level, above each DB's design root" — is
# satisfied either way; BD68 is the check that says it.
#
# ⚠⚠ SO THE HELPER GAINS TWO OPTIONAL TUPLE ELEMENTS, both additive, and every
# 3-element call stays byte-identical (BD19-BD25c here, TP33/TP40/TP41 in
# test_wave_sigbrowser_2pane.tcl):
#     {gid glab entries ?root? ?prefix?}
#   * `root` — that group's OWN design-root label. PLAN item 15 says the helper
#     is unchanged and then prescribes a BD50 whose parent row reads `bd_a`, the
#     FOREIGN design's name. The unchanged helper CANNOT produce that: it threads
#     ONE root string into every group, so every DB's root would render `bd_b`,
#     the CURRENT design's name, under a `bd_a.raw (tran)` header — a
#     user-visible lie about which run a node came from. BD62b is that leg.
#   * `prefix` — supplied ONLY by the current DB, and only as `{}`. Absent, it
#     defaults to `$gid|`, which is exactly what item 14 shipped and what TP41's
#     `tp_multi2` (a 3-element all-labelled list) still measures.
#
# ⚠ THE SILENT-GREEN TRAP, NAMED (PLAN §3.2). BD19/BD21/BD22/BD25 call the helper
# DIRECTLY with a `{}`-labelled group and therefore stay green on a code path
# production no longer takes. Their staying green proves nothing about item 15 —
# BD67 in the X block is the check that watches the CALLER.
#
# ⚠ THE PURE FIXTURE NUMBERS ITS OWN GROUPS: the CURRENT DB is `d:0` and the
# foreign one `d:1`, so these ids are self-contained and readable. The LIVE i14
# fixture is the other way round (BD31 pins `cur` == registry slot 1), which is
# why every X check below takes its header id from the ENGINE instead of
# hard-coding one. The PLAN's literals assume `d:0` is the foreign DB in both
# places; measured, that is true in neither.
# ============================================================================

# THE ROOTED MULTI LIST, built the way browser_refresh will build it: every
# group labelled and carrying ITS OWN root label, the CURRENT one (group 0) also
# carrying an explicit EMPTY prefix, and NO shared `$root` argument at all.
set bd_rooted [wviewer::browser_rows_multi \
  [list [list {d:0} {bd_b.raw (tran)} $bd_ents  {bd_b} {}] \
        [list {d:1} {bd_a.raw (tran)} $bd_fents {bd_a}]]]
set bd_ids {}
foreach r $bd_rooted { lappend bd_ids [dict get $r id] }

# ⚠ LEG 2 IS THE ANTI-VACUITY LEG AND IT IS WHY THIS IS NOT BD19 TWICE. Leg 1
# alone is GREEN BEFORE ITEM 15 EXISTS (it is BD19's own claim), so on its own it
# is a check that cannot fail in the direction this item moves. Leg 2 is red
# until the per-group root lands. Together they are the "the new argument was
# made MANDATORY" detector: rooting every group unconditionally reds leg 1 while
# leaving leg 2 green, and that inversion is a signature no single leg has.
check {BD60 (PURE) the UNLABELLED arm is still browser_rows byte-for-byte, and a group's OWN root is honoured} \
  [list [expr {[wviewer::browser_rows_multi [list [list {} {} $bd_ents]]] eq
               [wviewer::browser_rows $bd_ents]}] \
        [bd_text_of $bd_rooted {d:1|g:}]] \
  [list 1 bd_a]

# The single-group rooted shape, both ways of asking for it. Legs 1-3 are item
# 2's shipped `$root` argument (green before this item); LEG 4 is the new one —
# the SAME list must come out when the root arrives as the group's own 4th
# element instead. Without leg 4 this check is green on the old code.
set bd_one  [wviewer::browser_rows_multi [list [list {} {} $bd_ents]] bd_b]
set bd_one2 [wviewer::browser_rows_multi [list [list {} {} $bd_ents bd_b]]]
check {BD61 (PURE) a ROOTED single group: the root is FIRST, unprefixed and kind group — and a per-group root builds the identical list} \
  [list [dict get [lindex $bd_one 0] id] [dict get [lindex $bd_one 0] kind] \
        [dict get [lindex $bd_one 1] parent] \
        [expr {$bd_one eq $bd_one2}]] \
  [list {g:} group {g:} 1]

# R7's own sentence: each DB gets its OWN design root, under its OWN header —
# the current DB included. LEG 5 IS THE ONE THAT SEPARATES THIS DESIGN FROM THE
# PLAN's: the current DB's root is the BARE `g:`, so `d:0|g:` must NOT exist. A
# prefixed current DB would satisfy legs 1-4 and fail here, and that is exactly
# the difference the persisted-id measurement forced (see the block header).
check {BD62 (PURE) each DB gets its OWN design root under its OWN header — the FOREIGN one prefixed, the CURRENT one bare} \
  [list [bd_id_of $bd_rooted {d:1|g:}] [bd_parent_of $bd_rooted {d:1|g:}] \
        [bd_id_of $bd_rooted {g:}]     [bd_parent_of $bd_rooted {g:}] \
        [bd_has   $bd_rooted {d:0|g:}]] \
  [list {d:1|g:} {d:1} {g:} {d:0} 0]
# ⚠⚠ THE LEG THE PLAN'S OWN BREAK-LIST IMPLIES AND ITS "no helper change" FORBIDS.
# A shared root string gives BOTH roots the text `bd_b` — the tree would then say
# `bd_a.raw (tran)` > `bd_b` > `v(alpha)`, naming the wrong run. Leg 3 is the
# grandparent, so "the root took the header's place" and "the root was inserted
# UNDER the header" are different values here.
check {BD62b (PURE) each root carries ITS OWN design's name, and the header is still one level above it} \
  [list [bd_text_of $bd_rooted {d:1|g:}] [bd_text_of $bd_rooted {g:}] \
        [bd_grandparent_text $bd_rooted {d:1|s:v(alpha)}] \
        [bd_parent_text      $bd_rooted {d:1|s:v(alpha)}]] \
  [list bd_a bd_b {bd_a.raw (tran)} bd_a]

# BD23 restated one level up: a header must still answer for every name beneath
# it now that a root sits in between. Leg 2 asks the ROOT the same question, so
# "the header reaches through" and "the root holds them" are asserted together.
check {BD63 (PURE) browser_leaf_names on a DB HEADER reaches THROUGH its design root} \
  [list [wviewer::browser_leaf_names $bd_rooted {d:1}] \
        [wviewer::browser_leaf_names $bd_rooted {d:1|g:}]] \
  [list {time v(alpha) v(shared)} {time v(alpha) v(shared)}]

# ⚠ A SHARED `g:` THROWS IN ttk (`Item g: already exists`) on the searchbar's
# <KeyRelease> pump — i.e. bgerror, i.e. a modal dialog under X. Leg 2 is the
# count, because "every id is unique" is also true of a row list with no rows.
check {BD64 (PURE) every id in a rooted multi list is UNIQUE, and there are the ten rows there should be} \
  [list [expr {[llength [lsort -unique $bd_ids]] == [llength $bd_ids]}] \
        [llength $bd_ids]] \
  [list 1 10]

# BD24b one level up: an empty group emits no header AND no root. Leg 3 is the
# positive control on the same list — the non-empty group DID get its root, so
# "the empty one was suppressed" cannot be "roots were never emitted".
set bd_empty [wviewer::browser_rows_multi \
  [list [list {d:0} {bd_b.raw (tran)} $bd_ents {bd_b} {}] \
        [list {d:1} {bd_a.raw (tran)} {}       {bd_a}]]]
check {BD65 (PURE) a group with zero entries emits NEITHER a header NOR a root} \
  [list [bd_has $bd_empty {d:1}] [bd_has $bd_empty {d:1|g:}] \
        [bd_has $bd_empty {d:0}] [bd_has $bd_empty {g:}]] \
  [list 0 0 1 1]

# BD25 restated for R7's tree. The current DB is no longer top-level, so the walk
# MUST be seeded with browser_root_id — which is exactly what browser_show_path
# passes (item 8). The NEGATIVE leg keeps BD25b's claim: a foreign-only node is
# still not reachable from the current DB's root.
set bd_hrooted [wviewer::browser_rows_multi \
  [list [list {d:0} {bd_b.raw (tran)} $bd_h1 {bd_b} {}] \
        [list {d:1} {bd_a.raw (tran)} $bd_h2 {bd_a}]]]
check {BD66 (PURE) browser_node_for seeded at the CURRENT DB's root lands on the CURRENT DB's node, and a foreign-only node stays unreachable} \
  [list [wviewer::browser_node_for $bd_hrooted {x1} \
           [wviewer::browser_root_id $bd_hrooted]] \
        [wviewer::browser_node_for $bd_hrooted {y9} \
           [wviewer::browser_root_id $bd_hrooted]]] \
  [list {g:x1 1} {{} 0}]
# ⚠⚠ LEG 3 IS THE ANTI-VACUITY LEG AND IT IS WHY THIS IS NOT "the root id never
# changed". A PREFIXED foreign root really is in the list; `browser_root_id` has
# to walk past it and answer the CURRENT DB's bare one, which leg 4 then shows
# is genuinely nested under a DB header rather than sitting at top level as it
# did before R7. Leg 2 is why `browser_target_path` needed no edit at all.
check {BD66b (PURE) browser_root_id answers the CURRENT DB's BARE root even though a prefixed foreign root exists beside it, and that root is now a header's child} \
  [list [wviewer::browser_root_id $bd_rooted] \
        [wviewer::browser_id_path [wviewer::browser_root_id $bd_rooted]] \
        [bd_has $bd_rooted {d:1|g:}] \
        [bd_parent_of $bd_rooted [wviewer::browser_root_id $bd_rooted]]] \
  [list {g:} {} 1 {d:0}]

# ============================================================================
# BD30-BD36 — THE ENGINE CONTRACT, BOTH ARMS. Two real raws in the CURRENT
# context, no viewer, no Tk. This is the mechanism signal_list_all is built on
# (`raw info` -> `raw switch <n>` -> `raw list` -> switch back); pinning it on
# the arm that always completes means a regression in the engine contract is
# still caught when the X arm dies.
# ============================================================================
set bdA [file normalize [file join $scratch bd_a.raw]]
set bdB [file normalize [file join $scratch bd_b.raw]]
bd_mkraw $bdA {time v(alpha) v(shared)} 3
bd_mkraw $bdB {time v(beta) v(shared)} 3

# ⚠ POSITIVE CONTROL FOR EVERYTHING BELOW. Without it, "All DBs found nothing"
# and "neither file was ever a raw" are the same picture.
check {BD30 (POSITIVE CONTROL) both hand-written raws really read} \
  [list [pcall xschem raw read $bdA] [pcall xschem raw read $bdB]] [list 1 1]
check {BD30b ...and the CURRENT one is B, the one read last} \
  [pcall xschem raw list] "time\nv(beta)\nv(shared)"

set bd_live [wviewer::rawinfo_parse [pcall xschem raw info]]
check {BD31 the LIVE `raw info` parses to two DBs with B current} \
  [list [llength [dict get $bd_live dbs]] \
        [dict get $bd_live cur] \
        [dict get [lindex [dict get $bd_live dbs] [dict get $bd_live cur]] path]] \
  [list 2 1 $bdB]
check {BD31b ...and both registry paths are the two fixtures, in read order} \
  [list [dict get [lindex [dict get $bd_live dbs] 0] path] \
        [dict get [lindex [dict get $bd_live dbs] 1] path]] \
  [list $bdA $bdB]

# THE WHOLE MECHANISM, in three lines: a non-current DB's inventory is reachable
# ONLY by moving the pointer and putting it back.
check {BD32 `raw switch 0` reaches the NON-current DB's signal list} \
  [list [pcall xschem raw switch 0] [pcall xschem raw list]] \
  [list 1 "time\nv(alpha)\nv(shared)"]
check {BD33 an out-of-range switch is REFUSED (0), not silently accepted} \
  [pcall xschem raw switch 99] 0
check {BD34 switching back restores both the pointer and the listing} \
  [list [pcall xschem raw switch 1] [pcall xschem raw rawfile] \
        [pcall xschem raw list]] \
  [list 1 $bdB "time\nv(beta)\nv(shared)"]
# A refused switch must leave the pointer alone, or the restore in
# signal_list_all would be restoring from an unknown place.
check {BD35 a REFUSED switch leaves the current DB where it was} \
  [list [pcall xschem raw switch 42] [pcall xschem raw rawfile]] [list 0 $bdB]
# item 9's D6 extended: `rawinfo_parse` of the live blob and `raw list` agree on
# who is current — the invariant signal_list_all's `cur` flag depends on.
check {BD36 the parsed `cur` index and `raw rawfile` name the same DB} \
  [expr {[dict get [lindex [dict get [wviewer::rawinfo_parse [xschem raw info]] dbs] \
                     [dict get [wviewer::rawinfo_parse [xschem raw info]] cur]] path] eq
         [xschem raw rawfile]}] 1

# ============================================================================
# BD40-BD59 — THE REAL VIEWER + THE REAL BROWSER. Tk/X only. `wviewer::open` on
# the sky130A ngspice_state1 fixture (item 8's BSV recipe verbatim) plus the two
# raws written above. NO DESIGN WINDOW.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

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

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check {BD40 (FIXTURE) wviewer::open returns 1} [pcall ::wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: BD4x group (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  set BVF $vtop.wvbrowser
  set BSB $BVF.wvsearch
  # A NAMED FIXTURE CHECK, so a dead prologue FAILS A CHECK instead of vanishing
  # into a silent skip that scores green.
  check {BD40 (FIXTURE) the sidebar toggles on and the tree is real} \
    [list [pcall ::wviewer::browser_toggle 1 $tok] [winfo exists $BVF.pw.tvf.tv]] \
    [list 1 1]
  update

  # ViVA §3.2: the box exists, is packed, and is OFF by default (decision 6's
  # sibling — searching every open database is opt-in).
  check {BD41 the All DBs box exists, is packed and defaults OFF} \
    [list [winfo exists $BSB.alldb] [expr {[catch {pack info $BSB.alldb}] ? 0 : 1}] \
          $::wviewer::sballdb($BSB) \
          [wviewer::dget [wviewer::searchbar_get $BSB] alldbs {NO-KEY}]] \
    [list 1 1 0 0]
  # THE FILTER BAR HAS NO BOX AND NO KEY. A DB scope on a bar that narrows an
  # already-fetched list would be a second answer to one question — and BAR11
  # pins the plain bar's dict to EXACTLY four keys, so the key must be
  # conditional, not merely the widget.
  check {BD41b the FILTER bar has no box and emits no alldbs key} \
    [list [winfo exists $BVF.wvfilter.alldb] \
          [wviewer::dget [wviewer::searchbar_get $BVF.wvfilter] alldbs {NO-KEY}]] \
    [list 0 {NO-KEY}]

  # --- the two DBs, loaded through the PRODUCT's own path --------------------
  check {BD42 (POSITIVE CONTROL) rawbar_load reads A then B into the viewer} \
    [list [pcall ::wviewer::rawbar_load $tok $bdA] \
          [pcall ::wviewer::rawbar_load $tok $bdB]] [list 1 1]
  wviewer::switch_ctx $tok
  check {BD42b ...and the viewer's engine now holds TWO DBs, B current} \
    [list [llength [dict get [wviewer::rawinfo_parse [xschem raw info]] dbs]] \
          [pcall xschem raw rawfile]] \
    [list 2 $bdB]

  # --- signal_list_all, the accessor ----------------------------------------
  # ⚠ READ THE ENTRIES THROUGH A TOTAL ACCESSOR, NOT `dict get`. Sabotage S2
  # (drop the foreign-DB loop) makes `[lindex $bd_all 1]` empty, and a bare
  # `dict get {} cur` THROWS — which took the file's outer catch and turned a
  # one-check regression into `FATAL` with 27 later checks never run. A
  # sabotage must fail checks, not delete the evidence for every check after
  # it, so a missing entry has to read as a WRONG VALUE (`NONE`) instead.
  proc bd_e {lst i key} {
    return [wviewer::dget [lindex $lst $i] $key NONE]
  }
  set bd_all [pcall ::wviewer::signal_list_all $tok]
  check {BD43 signal_list_all answers TWO inventories, CURRENT one first} \
    [list [llength $bd_all] \
          [bd_e $bd_all 0 cur] [bd_e $bd_all 0 path] \
          [bd_e $bd_all 1 cur] [bd_e $bd_all 1 path]] \
    [list 2 1 $bdB 0 $bdA]
  check {BD43b ...with each DB's OWN signal names and its own label} \
    [list [bd_e $bd_all 0 names] [bd_e $bd_all 1 names] \
          [bd_e $bd_all 1 label]] \
    [list {time v(beta) v(shared)} {time v(alpha) v(shared)} {bd_a.raw (tran)}]

  # ⚠ THE RESTORE, MEASURED — not reasoned about. This is the one hazard
  # signal_list_all has that signal_list does not: it MOVES the user's current
  # DB. Both legs are needed: the pointer AND what `raw list` actually answers.
  wviewer::switch_ctx $tok
  set bd_before [xschem raw rawfile]
  pcall ::wviewer::signal_list_all $tok
  wviewer::switch_ctx $tok
  check {BD44 a scan LEAVES the current DB exactly where it found it} \
    [list [pcall xschem raw rawfile] $bd_before] [list $bdB $bdB]
  check {BD45 ...and `raw list` after the scan is still B's} \
    [pcall xschem raw list] "time\nv(beta)\nv(shared)"

  # ⚠⚠ BD44/BD45 ON THEIR OWN ARE VACUOUS FOR THE RESTORE, AND SABOTAGE S3
  # MEASURED IT (ruling 29: run the sabotage, do not reason about the check).
  # B is registry slot 1, the LAST slot, so the scan's final stop is already the
  # current DB and deleting `xschem raw switch $cur` changes NOTHING those two
  # checks can see — S3 failed only the SOURCE grep BD03. The restore is only
  # load-bearing when the current DB is NOT the last one visited, so pin it in
  # exactly that arrangement: make slot 0 current and scan again.
  wviewer::switch_ctx $tok
  pcall xschem raw switch 0
  set bd_first [pcall xschem raw rawfile]
  pcall ::wviewer::signal_list_all $tok
  wviewer::switch_ctx $tok
  check {BD44b THE RESTORE IS LOAD-BEARING: with the FIRST registry slot current the scan still ends on it} \
    [list $bd_first [pcall xschem raw rawfile]] [list $bdA $bdA]
  check {BD45b ...and `raw list` after THAT scan is still A's} \
    [pcall xschem raw list] "time\nv(alpha)\nv(shared)"
  # put the fixture back: every tree check below assumes B is the current DB.
  pcall xschem raw switch 1
  wviewer::switch_ctx $tok
  check {BD45c (FIXTURE) the current DB is restored to B for the tree checks} \
    [pcall xschem raw rawfile] $bdB

  # --- TWO-PANE ITEM 15: THE PREFIX, TAKEN FROM THE ENGINE ------------------
  # ⚠⚠ NOT FROM `browser_root_id`, AND NOT HARD-CODED. R7 gives the CURRENT DB a
  # header of its own, `d:<its registry index>`, and in THIS fixture the current
  # DB is slot 1 (B was read second — BD31/BD31b/BD43 all pin it), so every
  # literal PLAN item 15 writes as `d:0` is the FOREIGN DB here. Deriving the id
  # from `rawinfo_parse` keeps the checks reading an INDEPENDENT source rather
  # than the proc under test; BD67's third leg asserts the derived index itself,
  # so a fixture that quietly reorders its raws FAILS LOUDLY instead of
  # re-deriving a wrong id and going green on it.
  # ⚠ `$bd_P` IS THE SPELLING THAT MUST NEVER APPEAR. The current DB's ROWS stay
  # UNPREFIXED (spec §4.3); only its HEADER carries the registry index. Several
  # checks below assert `${bd_P}...` rows are ABSENT, which is what stops the
  # PLAN's prefix-everything design landing here unnoticed.
  set bd_cur [dict get [wviewer::rawinfo_parse [pcall xschem raw info]] cur]
  set bd_H "d:$bd_cur"
  set bd_P "d:$bd_cur|"

  # --- the tree, box OFF: the PLAN's negative and its two controls -----------
  proc bd_rows {tok} { return $::wviewer::browserrows($tok) }
  check {BD46 (FIXTURE) a refresh with the box OFF succeeds} \
    [pcall ::wviewer::browser_refresh $tok 1] 1
  # ⚠ THE PLAN'S ONE NAMED SABOTAGE TARGETS THIS LINE, and on its own it proves
  # NOTHING — see BD47/BD48.
  check {BD46b (THE NEGATIVE) box OFF: the other DB's v(alpha) is NOT shown} \
    [bd_ids_for [bd_rows $tok] {v(alpha)}] {}
  # ⚠⚠ POSITIVE CONTROL #1, SAME FIXTURE, SAME REFRESH: the tree is NOT simply
  # empty, and the current DB's own signals are all there. This is what kills
  # "the search returned nothing at all".
  check {BD47 (POSITIVE CONTROL) box OFF: B's own signals ARE all shown} \
    [list [bd_ids_for [bd_rows $tok] {v(beta)}] \
          [bd_ids_for [bd_rows $tok] {v(shared)}] \
          [bd_ids_for [bd_rows $tok] {time}]] \
    [list {s:v(beta)} {s:v(shared)} {s:time}]
  # POSITIVE CONTROL #2: v(alpha) IS in the other DB's inventory right now, so
  # "not shown" means "excluded", not "never loaded".
  check {BD47b (POSITIVE CONTROL) v(alpha) IS in the snapshot, just not shown} \
    [list [llength $::wviewer::browserdbsigs($tok)] \
          [lsearch -exact [bd_e $::wviewer::browserdbsigs($tok) 0 names] \
             {v(alpha)}]] \
    [list 1 1]
  # ⚠ THE POSITIVE CONTROL FOR BD48c, and the only place in this batch where the
  # design root's TEXT is checked against a raw path THIS FILE WROTE ITSELF.
  # `bd_b.raw` is the current DB (BD45c), and `browser_root_label` is file tail
  # -> rootname, so item 10's root label is `bd_b`. A root reading `design`
  # would mean browser_reload never captured the raw path; a root reading `bd_a`
  # would mean it captured the WRONG DB's. Both fixture raws are FLAT (every
  # signal_entry `path` is {}), so the design root is the ONLY node either
  # inventory can mint: a one-element id set.
  # ⚠ LEG 2 IS BD48c's POSITIVE CONTROL ON THE SAME EXPRESSION. BD48c asserts
  # `browser_root_id` answers {} with the box ON; without this leg that {} is
  # green on a browser_root_id that always answers {}.
  # ⚠ THE EXPECTED LITERAL IS A STRING REP, NOT A NESTED LIST. `check` compares
  # STRINGS and `[list {g:} {g:} bd_b bd_b]` is `g: g: bd_b bd_b`.
  check {BD47c (POSITIVE CONTROL) box OFF: the tree is exactly ONE node — the design root, named for the CURRENT raw, and the leaves hang off it} \
    [list [bd_tv_ids $BVF.pw.tvf.tv] \
          [pcall ::wviewer::browser_root_id [bd_rows $tok]] \
          [bd_tv_text $BVF.pw.tvf.tv {g:}] \
          [bd_parent_text [bd_rows $tok] {s:v(beta)}]] \
    [list {g:} {g:} bd_b bd_b]
  # ⚠⚠ A CAPTURE, NOT A CHECK, AND THE RED RUN IS WHY. Asked as its own check
  # here — "box OFF: the top level is the single design root" — it PASSED BEFORE
  # ITEM 15 EXISTED, because it is item 10's shipped shape. A control that cannot
  # fail in the direction the item moves is not evidence; it becomes evidence
  # only when it sits in the SAME TUPLE as the value it is a control for. So it
  # is captured here and asserted as BD68's first leg, below.
  set bd_top_off [pcall $BVF.pw.tvf.tv children {}]
  set bd_status_off [$BVF.ph cget -text]

  # --- the tree, box ON: THE POSITIVE ---------------------------------------
  set ::wviewer::sballdb($BSB) 1
  # ⚠ RESTATED BY TWO-PANE ITEM 15 (R7): the DB header is no longer the leaf's
  # PARENT — that DB's own design root is, and the header is one level above it.
  # Leg 3 therefore moves to `bd_a` and leg 4 is NEW, carrying the old claim at
  # its new depth. Deleting leg 3 would have thrown away the only assertion that
  # a foreign leaf is labelled with its SOURCE at all.
  check {BD48 (THE POSITIVE) box ON: v(alpha), present ONLY in the other DB, appears under that DB's OWN design root, and its DB header is one level above that} \
    [list [pcall ::wviewer::browser_refresh $tok] \
          [bd_ids_for [bd_rows $tok] {v(alpha)}] \
          [bd_parent_text      [bd_rows $tok] {d:0|s:v(alpha)}] \
          [bd_grandparent_text [bd_rows $tok] {d:0|s:v(alpha)}]] \
    [list 1 {d:0|s:v(alpha)} bd_a {bd_a.raw (tran)}]
  # ⚠⚠ RESTATED BY TWO-PANE ITEM 15, AND THE TITLE IS REWRITTEN RATHER THAN
  # RE-VALUED, BECAUSE HALF THE INVARIANT IS INVERTED AND HALF IS LOAD-BEARING.
  # Item 14's claim was "the current DB is not demoted by the box: its rows stay
  # TOP-LEVEL and UNPREFIXED". R7 kills the first half — the current DB gets a
  # header and a design root of its own, so its rows are two levels down — and
  # spec §4.3 keeps the second: the ids stay UNPREFIXED, which is what makes a
  # persisted selection survive the DB registry being renumbered (see the block
  # header for the measurement). A check whose title still promised "top-level"
  # would be a lie; one that quietly re-keyed the ids would hide the ruling.
  # ⚠ LEG 5 IS THE NEGATIVE THAT SEPARATES THIS FROM THE PLAN's DESIGN: the
  # PREFIXED spelling of the same row must NOT exist.
  # ⚠ LEG 4 WAS PREDICTED AS ONE ID AND MEASURED AS TWO, AND THE MEASUREMENT IS
  # THE BETTER LEG. `time` is in BOTH fixture raws, so it resolves to the current
  # DB's UNPREFIXED id and the foreign DB's PREFIXED one — the two id schemes
  # side by side on one name, in row order, which is exactly the ruling this
  # check exists to state. The receipt records the corrected prediction.
  check {BD49 box ON: the CURRENT DB is under a header of its OWN too — but its ids stay UNPREFIXED and hang off its own bare design root (R7 inverts item 14's top-level half; §4.3 keeps the unprefixed half)} \
    [list [bd_ids_for [bd_rows $tok] {v(beta)}] \
          [bd_parent_text      [bd_rows $tok] {s:v(beta)}] \
          [bd_grandparent_text [bd_rows $tok] {s:v(beta)}] \
          [bd_ids_for [bd_rows $tok] {time}] \
          [bd_has [bd_rows $tok] "${bd_P}s:v(beta)"]] \
    [list {s:v(beta)} bd_b {bd_b.raw (tran)} [list {s:time} {d:0|s:time}] 0]
  # a name in BOTH DBs shows up ONCE PER DB — the compare-two-runs case.
  # ⚠ RESTATED BY TWO-PANE ITEM 15: the two ids are unchanged (the current DB's
  # stays bare — §4.3), but each leaf's parent is now ITS OWN DB's design root.
  # LEG 3 IS WHAT MAKES THIS CHECK SAY THE TWO COPIES CAME FROM DIFFERENT RUNS:
  # two roots reading the same design name would be the shared-root defect the
  # PLAN's "the helper is unchanged" clause would have shipped, and BD62b is its
  # pure twin.
  check {BD50 box ON: v(shared) appears twice, once under each DB — and each copy sits under ITS OWN design root, named for ITS OWN run} \
    [list [bd_ids_for [bd_rows $tok] {v(shared)}] \
          [bd_parent_text [bd_rows $tok] {d:0|s:v(shared)}] \
          [bd_parent_text [bd_rows $tok] {s:v(shared)}]] \
    [list [list {s:v(shared)} {d:0|s:v(shared)}] bd_a bd_b]
  # THE WIDGET, not just the model: the header and the foreign leaf are really
  # in the treeview, with the header as the leaf's ttk parent.
  # ⚠ `parent`/`item` THROW on a missing ttk id, so they go through pcall: a
  # regression that removes the row must FAIL THIS CHECK, not abort the file and
  # take the nine checks after it with it (the S2 lesson, twice over).
  # ⚠⚠ THIS WAS ITEM 15's TOMBSTONE AND IT IS NOW ITS RECEIPT. Item 14's text
  # here read "with the box ON, browser_refresh passes NO design root, because
  # giving each DB its own root is ITEM 15's change (spec R7) ... so there is no
  # `g:` row at all" — and said that a green version of it after item 15 would
  # mean item 15 never ran. TWO-PANE ITEM 15 INVERTS IT: `browser_root_id` now
  # answers the CURRENT DB's PREFIXED root, and the row really is in the widget.
  # ⚠ AND THE ROOT IS THE BARE `g:`, NOT A PREFIXED ONE — spec §4.3. What CHANGED
  # is where it hangs: leg 2 was `absent` and is now the current DB's HEADER, and
  # BD47c shows the SAME id at TOP LEVEL the moment the box goes off. So "the
  # root grew a parent" and "the root never existed" are different values, and
  # neither can be a browser_root_id that always answers the same thing.
  # ⚠ LEG 4 IS THE NEGATIVE FOR THE PLAN's DESIGN: no PREFIXED current-DB root
  # exists. A prefixed one would satisfy legs 1-3's shape and break every
  # persisted id (see the BD60 block header).
  check {BD48c box ON: the design root is the CURRENT DB's BARE `g:`, really in the tree and nested under that DB's header — and no PREFIXED current-DB root exists (R7; item 14's no-root gap is closed)} \
    [list [pcall ::wviewer::browser_root_id [bd_rows $tok]] \
          [bd_tv_parent $BVF.pw.tvf.tv {g:}] \
          [bd_tv_text   $BVF.pw.tvf.tv {g:}] \
          [bd_tv_parent $BVF.pw.tvf.tv "${bd_P}g:"]] \
    [list {g:} $bd_H bd_b absent]
  # THE WIDGET, not just the model — RESTATED BY TWO-PANE ITEM 10. HALF THE OLD
  # CLAIM IS NOW FALSE BY DESIGN: `browser_tree_rows` keeps only `kind group`,
  # so leaf rows never enter the treeview at all and `d:0|s:v(alpha)` is ABSENT
  # from the widget while still sitting in `browserrows` under its header. The
  # claim therefore splits into four legs that no failure this file fears can
  # satisfy together:
  #   * the HEADER is really in the widget, at top level   (item 14's own claim)
  #   * it carries its label                               (item 14's own claim)
  #   * the foreign LEAF is an ASSERTABLE ABSENCE          (item 10's projection)
  #   * the MODEL still parents that leaf under the header — so "the browser
  #     lost the signal entirely" and "the leaf moved to the lower pane" are
  #     different values HERE, rather than only in BD48.
  # ⚠ THE ABSENCE IS READ AS `absent`, NEVER AS AN `ERR:` STRING. `pcall $tv
  # parent {d:0|s:v(alpha)}` answers ttk's "Item ... not found" wording, which
  # would become this item's expected value and which reads IDENTICALLY if the
  # widget had been destroyed. `bd_tv_parent` answers three distinct stable
  # sentinels instead.
  # ⚠ RESTATED BY TWO-PANE ITEM 15: leg 4's model parent is now that DB's own
  # design root (`bd_a`), and a FIFTH leg carries the old value at its new depth
  # — the grandparent — so the "the model still knows which DB this leaf came
  # from" claim is not weakened, only re-anchored. Legs 1-3 are untouched.
  check {BD50b box ON: the treeview holds the DB HEADER at top level with its label, the foreign LEAF is projected OUT of the tree (item 10), and the MODEL parents that leaf under that DB's OWN root, one level below the header} \
    [list [bd_tv_parent $BVF.pw.tvf.tv {d:0}] \
          [bd_tv_text   $BVF.pw.tvf.tv {d:0}] \
          [bd_tv_parent $BVF.pw.tvf.tv {d:0|s:v(alpha)}] \
          [bd_parent_text      [bd_rows $tok] {d:0|s:v(alpha)}] \
          [bd_grandparent_text [bd_rows $tok] {d:0|s:v(alpha)}]] \
    [list top-level {bd_a.raw (tran)} absent bd_a {bd_a.raw (tran)}]
  # ⚠ THE SET, NOT JUST THE TWO IDS. `absent` above is one id; this is the WHOLE
  # upper pane, and it is what stops "the projection dropped the leaf" being
  # confused with "the projection dropped everything and happened to keep d:0",
  # or with a tree that grew a node nobody asked for. Both fixture raws are FLAT
  # so neither inventory mints a hierarchy node, and item 10 emits no design
  # root while All-DBs is on (BD48c) — so the correct answer is exactly one id.
  # ⚠⚠ RESTATED BY TWO-PANE ITEM 15, AND ITEM 14's OWN COMMENT PREDICTED IT: "a
  # DB header currently has NO ttk children at all here ... item 15 (per-DB
  # roots) has to answer for that, and this is the check that will red when they
  # do." It answers here. The set is now FOUR ids in depth-first order — each
  # header immediately followed by its own root — and the CURRENT DB comes first
  # because `browser_rows_multi` still emits group 0 first and `browser_populate`
  # inserts at `end`.
  # ⚠ THIS IS THE CHECK THAT CATCHES AN UNPREFIXED FOREIGN ROOT, because that
  # defect THROWS on insert (`Item g: already exists`), browser_refresh's catch
  # turns the throw into a status-line message, and the tree is then left holding
  # whatever was inserted before the throw — a SET, not a count, is what tells
  # that apart from a correct tree.
  check {BD50c box ON: the upper pane's ENTIRE id set is the two DB headers each followed by ITS OWN design root, current DB first} \
    [bd_tv_ids $BVF.pw.tvf.tv] \
    [list $bd_H {g:} {d:0} {d:0|g:}]

  # --- BD67-BD70b — TWO-PANE ITEM 15's CALLER-SIDE CLAIMS -------------------
  # ⚠⚠ BD67 IS THE ITEM'S WHOLE POINT AND THE ONE THE PLAN'S BREAK-LISTS WERE
  # MISSING. Everything item 15 changes about the PURE helper is already pinned
  # by BD60-BD66b — but BD19/BD21/BD22/BD25 call that helper DIRECTLY with a
  # hand-built `{}`-labelled group, so they would stay green forever on a code
  # path production no longer takes (silent-green trap §3.2). R7 changes the
  # CALLER: `browser_refresh` must now LABEL group 0. This check watches the
  # caller's own output — `browserrows` after a LIVE refresh — and nothing else
  # in either file does.
  # ⚠ LEG 3 IS THE FIXTURE ASSERTION FOR EVERY `$bd_P` ABOVE: if the current DB
  # ever stops being registry slot 1 the derived prefix would still be
  # self-consistent and every re-keyed check would go green on the wrong DB.
  # ⚠ `db_label` TAKES TWO ARGUMENTS (path AND analysis). PLAN item 15 writes it
  # with one, which throws `wrong # args` — measured, not predicted.
  check {BD67 (THE CALLER) box ON: browserrows' FIRST row is a `group` whose text is the CURRENT DB's own label — R7 labels group 0, which no direct-helper check can see} \
    [list [dict get [lindex [bd_rows $tok] 0] kind] \
          [dict get [lindex [bd_rows $tok] 0] text] \
          $bd_cur] \
    [list group [wviewer::db_label $bdB tran] 1]
  # R7's tree shape, at the level R7 rules on, WITH ITS OWN CONTROL IN THE SAME
  # TUPLE: leg 1 is the SAME reading taken on the SAME fixture with the box off,
  # so "the top level is the DB headers" is a measured CHANGE caused by ticking
  # the box rather than a shape the tree always had. `children {}` is asked
  # directly because that is the level R7 rules on; `bd_tv_ids` is the whole
  # depth-first set and belongs to BD50c.
  check {BD68 R7's TOP LEVEL: the single design root with the box OFF, the per-DB headers with it ON — CURRENT DB first} \
    [list $bd_top_off [pcall $BVF.pw.tvf.tv children {}]] \
    [list {g:} [list $bd_H {d:0}]]
  # R2/R4 through the new shape: the never-empty selection is the CURRENT DB's
  # design root, not a header and not a foreign root. `bd_tv_sel` so "nothing is
  # selected" (R4's violation, which BP43a recorded as the item-14 state) and
  # "the widget is gone" are two different values.
  check {BD70 box ON: the selection is the CURRENT DB's design root (R2/R4 hold again under All-DBs)} \
    [bd_tv_sel $BVF.pw.tvf.tv] {g:}
  # ⚠⚠ AND IT MUST BE VISIBLE. The selected root's PARENT is a header inserted
  # `-open 0`, so R4's selection would land on a row nobody can see — and
  # `browser_populate` may not call `see` (spec §4.2, BW53). So the current DB's
  # HEADER is opened too. Leg 3 is the negative that keeps it honest: the FOREIGN
  # header stays closed, so this is not "everything got opened".
  check {BD70b box ON: the CURRENT DB's header AND its root are open so the selected root is really visible, while the FOREIGN header stays collapsed} \
    [list [bd_tv_open $BVF.pw.tvf.tv $bd_H] \
          [bd_tv_open $BVF.pw.tvf.tv {g:}] \
          [bd_tv_open $BVF.pw.tvf.tv {d:0}]] \
    [list 1 1 0]

  # --- per-DB matching: the header only appears when that DB matched ---------
  proc bd_pat {w p} {
    $w.pat delete 0 end
    if {$p ne {}} { $w.pat insert 0 $p }
    wviewer::searchbar_fire $w
  }
  bd_pat $BSB {*beta*}
  # ⚠ AFTER ITEM 10 THIS TREE IS LEGITIMATELY EMPTY, AND THAT IS ASSERTED RATHER
  # THAN ASSUMED. `*beta*` matches one FLAT signal in the current DB — a LEAF,
  # which no longer enters the tree — and nothing in the foreign DB, so there is
  # no header either; the design root is suppressed while All-DBs is on (BD48c).
  # The old `exists {d:0}`=0 leg therefore stopped being able to tell "the
  # header was correctly omitted" from "the treeview was never populated", while
  # still passing. `absent` + `empty` are two different values for those two
  # worlds, and the model leg keeps the signal itself accounted for.
  # ⚠⚠ RESTATED BY TWO-PANE ITEM 15, AND HALF OF IT IS NOW ITS OPPOSITE. The
  # FOREIGN DB still matches nothing, so leg 1's `absent` stands — that is the
  # negative this check exists for. But the CURRENT DB's header and root are NOT
  # conditional on any DB matching (see BD70c), so the tree is no longer empty:
  # `empty` becomes the current DB's two ids. Leaving `empty` in place would have
  # made a correct tree look like a regression, and deleting the leg would have
  # thrown away the "the treeview was never populated" discriminator that leg was
  # added for — so it is RE-VALUED, not dropped.
  check {BD51 (THE NEGATIVE) ON + `*beta*`: the other DB matched nothing so it gets NO header row at all — while the CURRENT DB's own header and root are still there, which is asserted rather than assumed} \
    [list [bd_tv_parent $BVF.pw.tvf.tv {d:0}] \
          [bd_tv_ids $BVF.pw.tvf.tv] \
          [bd_ids_for [bd_rows $tok] {v(beta)}]] \
    [list absent [list $bd_H {g:}] {s:v(beta)}]
  # ⚠⚠ BD70c — TWO-PANE ITEM 15's FLICKER GUARD, and it is why the current DB's
  # header is gated on THE CHECKBOX ALONE and never on "how many foreign DBs
  # matched". `*beta*` is exactly the state where a `ndbs > 0` gate would look
  # right in every other check in this file and be wrong here: the foreign DB
  # drops out mid-keystroke, the header vanishes, every current-DB id re-keys
  # from `d:1|...` back to `s:...` and the whole open set evaporates — §7.1's
  # flicker, one item on. THE SAME THREE VALUES ARE ASSERTED HERE AS UNDER
  # `*alpha*` in BD51b below, which is what makes this a stability claim rather
  # than a restatement of BD51.
  check {BD70c (THE FLICKER GUARD) ON + a pattern NO foreign DB matches: the CURRENT DB's header, root and prefixed ids are unchanged — the header follows the checkbox, never the foreign match count} \
    [list [bd_tv_parent $BVF.pw.tvf.tv $bd_H] \
          [bd_tv_parent $BVF.pw.tvf.tv {g:}] \
          [bd_tv_text   $BVF.pw.tvf.tv $bd_H] \
          [bd_tv_sel    $BVF.pw.tvf.tv]] \
    [list top-level $bd_H [wviewer::db_label $bdB tran] {g:}]

  # --- BD69 — R5's GUARD ON THE ONE THING ITEM 15 ADDS TO browser_populate ---
  # ⚠⚠ THE HEADER AND ROOT ARE BORN OPEN, ONCE, WHEN THEY ARE BORN — NOT ON
  # EVERY POPULATE, and this is the check that says which. Item 15 has to open
  # the current DB's header or R4's selected root sits inside a collapsed node
  # nobody can see (`browser_populate` may not call `see` — spec §4.2, BW53).
  # The lazy spelling of that is "open it every time", which turns typing in the
  # Search bar into "the tree re-expands what you just collapsed" — R5's letter
  # ("the tree never auto-opens on a search") wearing the other sign, and exactly
  # the regression item 10's open-set carry-over exists to prevent.
  # THE GESTURE IS REAL: the header is collapsed by hand and then a PATTERN is
  # typed through the bar's own pump, which is what a user does.
  # ⚠ LEG 2 AND LEG 3 ARE THE POSITIVE CONTROLS. Without them "the header stayed
  # closed" is equally true of a refresh that destroyed the tree, or one that
  # collapsed everything: leg 2 says the ROOT is still open (so nothing did a
  # blanket collapse) and leg 3 says the root is still that header's child (so
  # the tree is still R7's).
  # ⚠ THE RESTORE HAPPENS AFTER ALL THREE READS. A check that read back what its
  # own restore had just written would be asserting the restore.
  pcall $BVF.pw.tvf.tv item $bd_H -open 0
  update
  bd_pat $BSB {*shared*}
  set bd_r5_hdr  [bd_tv_open   $BVF.pw.tvf.tv $bd_H]
  set bd_r5_root [bd_tv_open   $BVF.pw.tvf.tv {g:}]
  set bd_r5_par  [bd_tv_parent $BVF.pw.tvf.tv {g:}]
  pcall $BVF.pw.tvf.tv item $bd_H -open 1
  update
  check {BD69 (R5) a SEARCH KEYSTROKE never re-opens a DB header the user collapsed — the header and its root are born open ONCE, when they are born} \
    [list $bd_r5_hdr $bd_r5_root $bd_r5_par] [list 0 1 $bd_H]
  # ⚠ POSITIVE CONTROL for BD51 on the SAME bar and the SAME fixture: a pattern
  # the other DB DOES match brings the header straight back — and this is also
  # the PLAN's headline case, a signal found ONLY in the second database.
  bd_pat $BSB {*alpha*}
  # ⚠ RESTATED BY TWO-PANE ITEM 10 / SPEC §7.1, AND THE CLAIM MOVED RATHER THAN
  # WEAKENED. "The current DB matches NOTHING" used to be readable off the ROW
  # MODEL, because the model was built from the bar-matched set. It no longer
  # is: §7.1 scopes both bars to the LOWER pane, so the CURRENT DB's rows are
  # built from the unfiltered inventory and `v(beta)` stays in the model however
  # the bars are set. The matching claim is therefore read from
  # `browser_match` — the very proc `browser_refresh` calls, not a second
  # matcher — and the model leg becomes §7.1's own positive statement rather
  # than a casualty of it.
  # ⚠ THE FOREIGN DB IS STILL BAR-MATCHED: item 10's §7.1 change is scoped to
  # the CURRENT DB, because R7's tree shape belongs to item 15. Legs 1-3 pin
  # that asymmetry from both sides, so item 15 cannot close it silently.
  # ⚠ UNTOUCHED BY TWO-PANE ITEM 15, AND THAT IS THE POINT: the current DB's ids
  # do not move (§4.3) and the foreign side is exactly where item 14 left it, so
  # all four legs keep their item-14 values. That is what makes BD70c's stability
  # claim above readable as a PAIR with this one — same bar, same fixture, and
  # only the foreign header differs between them.
  check {BD51b (POSITIVE CONTROL) ON + `*alpha*`: the FOREIGN DB's row appears and it alone MATCHED; the current DB matched nothing yet KEEPS its rows (§7.1 — the bars narrow the lower pane, never the tree)} \
    [list [bd_tv_parent $BVF.pw.tvf.tv {d:0}] \
          [bd_ids_for [bd_rows $tok] {v(alpha)}] \
          [bd_ids_for [bd_rows $tok] {v(beta)}] \
          [pcall ::wviewer::browser_match $tok]] \
    [list top-level {d:0|s:v(alpha)} {s:v(beta)} {ok {}}]
  # ⚠⚠ BD57 (TWO-PANE ITEM 20) — THE FOREIGN INVENTORIES ARE KEYED TOO, AND THIS
  # IS THE ONLY PLACE IT IS REACHABLE. `browser_and` has TWO production callers,
  # not one: `browser_match` (the current DB) and `browser_refresh`'s All-DBs
  # loop at wave_viewer.tcl:8110 (each FOREIGN DB). Item 20's work order names
  # only the first. Keying one and not the other would make the SAME two bar
  # dicts mean two different things depending on which DB a name came from —
  # the user types one pattern, the current DB answers about labels and the
  # foreign one about raw names. That is exactly the failure `browser_match`'s
  # own ⚠ was written to prevent, one level up, so BOTH sites pass the key and
  # this check is what says so BEHAVIOURALLY rather than by reading the source.
  #
  # `alpha` — no wildcards, whole-name anchored — matches ZERO raw names
  # (`v(alpha)`) and exactly ONE label (`alpha`). Under the old raw-keyed loop
  # the foreign header cannot appear; it appears here only because the foreign
  # branch keys the same way the current DB does. The pair with BD51b above is
  # deliberate: same bar, same fixture, `*alpha*` (works either way) against
  # `alpha` (works only keyed).
  bd_pat $BSB {alpha}
  check {BD57 (ITEM 20) ON + the LABEL-ONLY `alpha`: the FOREIGN DB's header still appears, so browser_refresh's All-DBs loop keys the bars the same way browser_match does} \
    [list [bd_tv_parent $BVF.pw.tvf.tv {d:0}] \
          [bd_ids_for [bd_rows $tok] {v(alpha)}]] \
    [list top-level {d:0|s:v(alpha)}]
  check {BD57 (ITS NEGATIVE CONTROL) the same pattern against the RAW name would have matched nothing at all — which is what the header appearing proves did not happen} \
    [list [lindex [pcall ::wviewer::sig_match {v(alpha)} {alpha}] 1] \
          [lindex [pcall ::wviewer::sig_match {v(alpha)} {alpha} \
                     -key wviewer::browser_label_of] 1]] \
    [list {} {v(alpha)}]
  bd_pat $BSB {}
  # ⚠ RESTATED BY TWO-PANE ITEM 15: the row COUNT moves 7 -> 10, and the three
  # extra rows are named rather than left as an arithmetic surprise — one header
  # and one design root for the CURRENT DB (R7), plus one design root for the
  # foreign DB (item 14 already had its header). MEASURED, not predicted.
  check {BD51c (CONTROL) clearing the pattern brings everything back: 2 headers + 2 design roots + 6 leaves} \
    [list [$BVF.pw.tvf.tv exists {d:0}] [llength [bd_rows $tok]]] [list 1 10]

  # --- BD70d — A DECLARED LIMIT, ASSERTED AS A VALUE -------------------------
  # ⚠⚠ REACHABLE FOR THE FIRST TIME BECAUSE OF TWO-PANE ITEM 15. The lower pane
  # is drawn from `browserseaent`, which holds the CURRENT DB's entries and only
  # those — so a FOREIGN design root, which decodes to the empty path exactly
  # like the current one, shows the CURRENT DB's own-level names. Before item 15
  # there were no foreign roots to click, so the case did not exist. Item 15 does
  # NOT fix it: scoping the sea per DB is a two-pane change of its own (spec
  # §7.2's caption owns the wording), and a silent wrong answer is worse than a
  # recorded one. LEG 1 IS THE POSITIVE CONTROL taken BEFORE the foreign root is
  # selected, so "the sea shows the current DB" and "the sea never changed
  # because nothing is wired" are not the same picture.
  set bd_sea_own {}
  foreach p $::wviewer::browsersea($tok) { lappend bd_sea_own [lindex $p 1] }
  pcall $BVF.pw.tvf.tv selection set [list {d:0|g:}]
  update
  set bd_sea_for {}
  foreach p $::wviewer::browsersea($tok) { lappend bd_sea_for [lindex $p 1] }
  # put the fixture back BEFORE the check, and never read what this line writes.
  pcall $BVF.pw.tvf.tv selection set [list {g:}]
  update
  check {BD70d (DECLARED LIMIT) selecting a FOREIGN DB's design root shows the CURRENT DB's own-level names — the lower pane is built from the current DB's entries alone, and both roots decode to the same empty path} \
    [list $bd_sea_own $bd_sea_for \
          [wviewer::browser_id_path {d:0|g:}] \
          [wviewer::browser_id_path {g:}]] \
    [list {time v(beta) v(shared)} {time v(beta) v(shared)} {} {}]

  # --- BD58 (TWO-PANE ITEM 12) — R11's BOXES GOVERN THE FOREIGN DBs TOO ------
  #
  # ⚠⚠ THIS IS THE ONLY PLACE IT IS REACHABLE, which is exactly BD57's argument
  # one item over. `browser_class_filter` has TWO production callers inside
  # browser_refresh: the current DB's, and this All-DBs loop's — one per foreign
  # inventory. Item 12 wires the checkboxes; wiring the first call and leaving
  # the second at item 10's literal `0 1` gives a checkbox that governs the tree
  # the user is looking at and silently NOT the foreign inventory beside it, with
  # nothing on screen to say so. Spec §6's "one consistent set" is the ruling.
  # Every check in `test_wave_sigbrowser_panes.tcl`'s BW56 band drives the
  # CURRENT DB only and stays green through that half-wiring — this is the half
  # they cannot see.
  #
  # ⚠ THE FOREIGN INVENTORY IS HAND-SEEDED, not added to the fixture raws. The
  # real `bd_a.raw`/`bd_b.raw` are all `net`-classed, so a class filter cannot
  # move them; giving them a device signal would change `bd_rows`' length and red
  # BD50c, BD51c and the two status-line checks above for no gain.
  # `browser_refresh $tok` (reload 0) never re-enters browser_reload, so the seed
  # survives the refresh — the same property BW63 pins from the other side.
  #
  # ⚠ RESTORED AND ASSERTED. BD58c puts the real foreign inventory back and
  # checks it, because every check after this one runs against it.
  set bd_dbs_was $::wviewer::browserdbsigs($tok)
  set bd_devsig {v(m.x1.mn1#body)}
  set ::wviewer::browserdbsigs($tok) \
    [list [dict create id {d:9} label {bd_z.raw (tran)} \
             names [list {v(zeta)} $bd_devsig]]]
  set ::wviewer::sballdb($BSB) 1
  wviewer::browser_devint $tok 0
  wviewer::browser_refresh $tok
  update
  set bd_off_ids  [bd_ids_for [bd_rows $tok] $bd_devsig]
  set bd_off_zeta [bd_ids_for [bd_rows $tok] {v(zeta)}]
  set bd_off_node [bd_tv_parent $BVF.pw.tvf.tv {d:9|g:x1}]
  wviewer::browser_devint $tok 1
  wviewer::browser_refresh $tok
  update
  set bd_on_ids  [bd_ids_for [bd_rows $tok] $bd_devsig]
  set bd_on_node [bd_tv_parent $BVF.pw.tvf.tv {d:9|g:x1}]
  # THE CLAIM, as one tuple: the foreign DB's device signal is an ASSERTABLE
  # ABSENCE with the box off and really present with it on, the device-only NODE
  # it lives under appears and disappears with it IN THE WIDGET, and the foreign
  # DB's ordinary net is untouched throughout — so "the box works" and "the box
  # emptied the foreign DB" are different values here.
  # ⚠ RESTATED BY TWO-PANE ITEM 15: leg 4 moves from the DB HEADER `d:9` to that
  # DB's OWN design root `d:9|g:` — the device node hangs off the root now, not
  # off the header. `absent` on leg 2 is untouched, which is what keeps the
  # appear/disappear pair readable.
  # ⚠ THE SEEDED DICT CARRIES NO `path` KEY, DELIBERATELY: `browser_root_label`
  # floors an empty path at `design`, so this DB's root text is `design` while
  # its id is still `d:9|g:`. The check asserts the ID, never the text, so the
  # seed stays a two-key `{id label names}` dict and the "do not `browser_refresh
  # $tok 1`, it re-enters browser_reload and destroys the seed" rule below still
  # holds. Widening the seed would have been a control eating its own fixture.
  check {BD58 (ITEM 12) the device-internals box governs the FOREIGN inventories
         too — browser_refresh's All-DBs loop reads the SAME two values the
         current DB was filtered with} \
    [list $bd_off_ids $bd_off_node $bd_on_ids $bd_on_node $bd_off_zeta] \
    [list {} absent {d:9|s:v(m.x1.mn1#body)} {d:9|g:} {d:9|s:v(zeta)}]
  # THE NEGATIVE CONTROL, and it is the one that catches the half-wiring: with
  # the box ON the CURRENT DB's own inventory is unchanged, because it holds no
  # device signal at all. So BD58's movement cannot be "the whole tree got
  # rebuilt" — only the foreign side moved, which is what makes it evidence
  # about the SECOND class_filter call rather than the first.
  # ⚠ THE SEEDED FOREIGN DB DELIBERATELY DOES NOT CARRY `v(shared)`. The real
  # fixture's two raws share that name and BD50 uses it to prove a name shows up
  # once PER DB; here the point is the opposite one, so the current DB's two nets
  # must each resolve to exactly ONE id — their own.
  # ⚠ UNTOUCHED BY TWO-PANE ITEM 15: the current DB's ids do not move (§4.3), so
  # both legs keep their item-12 values on a tree that R7 has completely
  # re-shaped around them. That is evidence for the ruling, not an oversight.
  check {BD58b (NEGATIVE CONTROL) the CURRENT DB's rows are identical either way
         — it has no device signal, so only the foreign side could have moved} \
    [list [bd_ids_for [bd_rows $tok] {v(beta)}] \
          [bd_ids_for [bd_rows $tok] {v(shared)}]] \
    [list {s:v(beta)} {s:v(shared)}]
  wviewer::browser_devint $tok 0
  set ::wviewer::browserdbsigs($tok) $bd_dbs_was
  wviewer::browser_refresh $tok
  update
  check {BD58c (THE RESTORE, ASSERTED) the real foreign inventory and R11's
         shipped default are back — every check below runs against them} \
    [list [pcall ::wviewer::browser_devint $tok] \
          [$BVF.pw.tvf.tv exists {d:0}] [llength [bd_rows $tok]]] \
    [list 0 1 10]

  # --- the status line -------------------------------------------------------
  # ⚠ BYTE-IDENTICAL WITH THE BOX OFF. test_wave_sigbrowser.tcl:1173/1182/1199
  # match on this string; item 14 must not move it for anybody who did not tick
  # the box.
  set ::wviewer::sballdb($BSB) 0
  wviewer::browser_refresh $tok
  check {BD52 status with the box OFF is BYTE-IDENTICAL to item 9's} \
    [list [$BVF.ph cget -text] $bd_status_off] \
    [list "Signal Browser\n3 of 3 signals" "Signal Browser\n3 of 3 signals"]
  set ::wviewer::sballdb($BSB) 1
  wviewer::browser_refresh $tok
  check {BD52b ...and with it ON it SAYS how much came from elsewhere} \
    [$BVF.ph cget -text] "Signal Browser\n3 of 3 signals, +3 from 1 other DB"

  # --- THE REAL GESTURE ------------------------------------------------------
  # ⚠ NOT a variable poke: `invoke` is what the user's click runs, and it is the
  # only thing that proves the widget's -command reaches the refresh. It must
  # flip the tree BOTH WAYS, or "it re-searched" and "it happened to be right"
  # are the same observation.
  set ::wviewer::sballdb($BSB) 0
  wviewer::browser_refresh $tok
  check {BD53 (CONTROL) before the gesture the box is off and A is not shown} \
    [list $::wviewer::sballdb($BSB) [$BVF.pw.tvf.tv exists {d:0}]] [list 0 0]
  $BSB.alldb invoke
  update
  check {BD53b the real click turns All DBs ON and the other DB APPEARS} \
    [list $::wviewer::sballdb($BSB) [$BVF.pw.tvf.tv exists {d:0}] \
          [bd_ids_for [bd_rows $tok] {v(alpha)}]] \
    [list 1 1 {d:0|s:v(alpha)}]
  $BSB.alldb invoke
  update
  check {BD53c ...and clicking it again takes it straight back off} \
    [list $::wviewer::sballdb($BSB) [$BVF.pw.tvf.tv exists {d:0}] \
          [bd_ids_for [bd_rows $tok] {v(alpha)}]] \
    [list 0 0 {}]

  # --- plotting a foreign row: DECLARED LIMIT D5, MEASURED NOT ASSUMED -------
  # ⚠ THE PLAN PREDICTED A REFUSAL AND THE PRODUCT DOES NOT REFUSE. The scout's
  # D5 said add_trace's pre-existing validation would reject a foreign name;
  # measured, `browser_plot_ids` plots it exactly like any other row, and the
  # resulting trace resolves its expression against the CURRENT DB — so it draws
  # nothing (a name only the other DB has) or, worse, the CURRENT DB's data (a
  # name both DBs have, e.g. `v(shared)`).
  #
  # Item 14 does NOT add a guard: cross-DB plotting is out of this item's scope
  # and a refusal is not obviously the right answer either. What is NOT
  # acceptable is a receipt claiming a refusal that does not happen, so the
  # check pins the BEHAVIOUR THAT EXISTS and receipts/14_receipt.md carries it
  # as a declared limit for item 15 / a follow-up issue.
  $BSB.alldb invoke
  update
  # ⚠ UNTOUCHED BY TWO-PANE ITEM 15, AND IT IS THE CHECK THAT SHOWS WHY THE
  # UNPREFIXED CURRENT DB MATTERS BEYOND PERSISTENCE. Under the PLAN's
  # prefix-everything design `s:v(beta)` would stop existing, `browser_leaf_names`
  # would answer {} and `browser_plot_ids` would echo "nothing selected to plot"
  # and return 0 — a WRONG VALUE, not a throw, reading exactly like a real
  # cross-DB plotting regression. It stays green here because the id did not move.
  set bd_plot_cur [pcall ::wviewer::browser_plot_ids $tok [list {s:v(beta)}]]
  set bd_plot_for [pcall ::wviewer::browser_plot_ids $tok [list {d:0|s:v(alpha)}]]
  check {BD54 (DECLARED LIMIT) a FOREIGN row plots exactly like a current one - item 14 adds no cross-DB guard} \
    [list $bd_plot_cur $bd_plot_for] [list 1 1]
  check {BD54b ...and nothing in browser_plot_ids had to learn about DBs} \
    [regexp -all {alldbs|browserdbsigs|signal_list_all} \
     [wvproc_body $wsrc wviewer::browser_plot_ids]] 0

  # --- item 13's IMPROVE-OR-RESTORE covers the new array too -----------------
  # ⚠ THE POSITIVE CONTROL COMES FIRST (ruling 29): a sentinel that survives
  # proves nothing unless a plain refresh is shown to DESTROY it.
  set ::wviewer::browserdbsigs($tok) {SENTINEL}
  wviewer::browser_refresh $tok 1
  check {BD55 (POSITIVE CONTROL) an ordinary reload DOES replace the inventory} \
    [expr {$::wviewer::browserdbsigs($tok) eq {SENTINEL} ? {kept} : {replaced}}] \
    replaced
  set ::wviewer::browserdbsigs($tok) {SENTINEL}
  pcall ::wviewer::browser_show_path $tok {no.such.hier.path}
  check {BD55b a FAILED hierarchy sync RESTORES the foreign inventory} \
    $::wviewer::browserdbsigs($tok) {SENTINEL}

  # --- teardown --------------------------------------------------------------
  # ⚠ ITEM 10's `browserraw($token)` RIDES ALONG HERE, and it is the only live
  # teardown in the browser batch. The array is declared, set unconditionally by
  # browser_reload and unset in `forget`, but nothing anywhere under tests/ ever
  # named it — so its capture and its leak were both unasserted. A live teardown
  # leg is strictly better evidence than a source grep.
  # ⚠ RESTATED BY TWO-PANE ITEM 15: a THIRD per-token array rides along — the
  # current DB's header identity, captured by browser_reload in the same pass
  # that already captures item 10's raw path. A new per-token array with no
  # teardown leg is a per-window leak nothing else in the suite would see.
  check {BD56 (CONTROL) the inventory entry, item 10's raw-path capture AND item 15's current-DB header identity all exist while the window does} \
    [list [info exists ::wviewer::browserdbsigs($tok)] \
          [info exists ::wviewer::browserraw($tok)] \
          [info exists ::wviewer::browsercurdb($tok)]] \
    [list 1 1 1]
  set bd_sbpath $BSB
  catch {wviewer::close $tok}
  update
  check {BD56b close unsets ALL THREE: no per-token leak, item 10's and item 15's arrays included} \
    [list [info exists ::wviewer::browserdbsigs($tok)] \
          [info exists ::wviewer::browserraw($tok)] \
          [info exists ::wviewer::browsercurdb($tok)]] \
    [list 0 0 0]
  check {BD56c ...and the bar's checkbutton element goes with the bar} \
    [info exists ::wviewer::sballdb($bd_sbpath)] 0
  }

} else {
  puts "SKIPPED: BD4x group (Tk/X arm only)"
}

# ⚠ ISSUE 0119, RE-ASSERTED BY THIS FILE TOO. Item 13's sabotage (b) wrote the
# user's REAL ~/.xschem/raw_history during a verification run. This file loads
# raws through `rawbar_load`, which pushes to the history — so it must prove the
# 0119 gate held. Content, not just existence: on a machine where the file
# already exists an existence check alone would pass over a rewrite.
set bd_home_now [file exists $bd_home_file]
set bd_home_post {}
if {$bd_home_now} {
  set fd [::open $bd_home_file r] ; set bd_home_post [read $fd] ; ::close $fd
}
check {BD59 the user's REAL raw_history is byte-for-byte as it was found} \
  [list $bd_home_now $bd_home_post] [list $bd_home_pre $bd_home_txt]

} err]} { puts "FATAL: $err\n$::errorInfo" ; incr fail }

wvbs_finish
