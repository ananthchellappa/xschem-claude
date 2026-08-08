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
  set bd_status_off [$BVF.ph cget -text]

  # --- the tree, box ON: THE POSITIVE ---------------------------------------
  set ::wviewer::sballdb($BSB) 1
  check {BD48 (THE POSITIVE) box ON: v(alpha), present ONLY in the other DB, appears AND its parent row NAMES ITS SOURCE} \
    [list [pcall ::wviewer::browser_refresh $tok] \
          [bd_ids_for [bd_rows $tok] {v(alpha)}] \
          [bd_parent_text [bd_rows $tok] {d:0|s:v(alpha)}]] \
    [list 1 {d:0|s:v(alpha)} {bd_a.raw (tran)}]
  # the current DB is not demoted by the box: its rows stay top-level.
  check {BD49 box ON: the CURRENT DB's rows stay top-level and unprefixed} \
    [list [bd_ids_for [bd_rows $tok] {v(beta)}] \
          [bd_parent_text [bd_rows $tok] {s:v(beta)}]] \
    [list {s:v(beta)} {TOP-LEVEL}]
  # a name in BOTH DBs shows up ONCE PER DB — the compare-two-runs case.
  check {BD50 box ON: v(shared) appears twice, once under each DB} \
    [list [bd_ids_for [bd_rows $tok] {v(shared)}] \
          [bd_parent_text [bd_rows $tok] {d:0|s:v(shared)}]] \
    [list {s:v(shared) d:0|s:v(shared)} {bd_a.raw (tran)}]
  # THE WIDGET, not just the model: the header and the foreign leaf are really
  # in the treeview, with the header as the leaf's ttk parent.
  # ⚠ `parent`/`item` THROW on a missing ttk id, so they go through pcall: a
  # regression that removes the row must FAIL THIS CHECK, not abort the file and
  # take the nine checks after it with it (the S2 lesson, twice over).
  # ⚠ TWO-PANE ITEM 10 MEETS ITEM 14, AND THE RULING IS A NEGATIVE: with the box
  # ON, browser_refresh passes NO design root, because giving each DB its own
  # root is ITEM 15's change (spec R7) and landing it here would make item 15's
  # reds unattributable. So there is no `g:` row at all and the tree's top level
  # is the DB headers alone. PAIRED WITH BD47c, which shows the SAME fixture
  # grows a root the moment the box goes off — so "no root" here cannot be
  # "roots never worked", and this check's `{}` cannot be a browser_root_id that
  # always answers `{}`.
  check {BD48c box ON: NO design root is emitted — neither in the row model nor in the tree (item 15 owns per-DB roots)} \
    [list [pcall ::wviewer::browser_root_id [bd_rows $tok]] \
          [bd_tv_parent $BVF.pw.tvf.tv {g:}]] \
    [list {} absent]
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
  check {BD50b box ON: the treeview holds the DB HEADER at top level with its label, the foreign LEAF is projected OUT of the tree (item 10), and the MODEL still parents that leaf under the header} \
    [list [bd_tv_parent $BVF.pw.tvf.tv {d:0}] \
          [bd_tv_text   $BVF.pw.tvf.tv {d:0}] \
          [bd_tv_parent $BVF.pw.tvf.tv {d:0|s:v(alpha)}] \
          [bd_parent_text [bd_rows $tok] {d:0|s:v(alpha)}]] \
    [list top-level {bd_a.raw (tran)} absent {bd_a.raw (tran)}]
  # ⚠ THE SET, NOT JUST THE TWO IDS. `absent` above is one id; this is the WHOLE
  # upper pane, and it is what stops "the projection dropped the leaf" being
  # confused with "the projection dropped everything and happened to keep d:0",
  # or with a tree that grew a node nobody asked for. Both fixture raws are FLAT
  # so neither inventory mints a hierarchy node, and item 10 emits no design
  # root while All-DBs is on (BD48c) — so the correct answer is exactly one id.
  # ⚠ DECLARED: this also records that a DB header currently has NO ttk children
  # at all here — its only children were leaves. Item 11 (the lower pane) and
  # item 15 (per-DB roots) both have to answer for that, and this is the check
  # that will red when they do.
  check {BD50c box ON: the upper pane's ENTIRE id set is the one DB header — every leaf really left the tree, and no node left with them} \
    [bd_tv_ids $BVF.pw.tvf.tv] [list {d:0}]

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
  check {BD51 (THE NEGATIVE) ON + `*beta*`: the other DB matched nothing so it gets NO header row at all — and after item 10 the tree is legitimately EMPTY, which is asserted rather than assumed} \
    [list [bd_tv_parent $BVF.pw.tvf.tv {d:0}] \
          [bd_tv_ids $BVF.pw.tvf.tv] \
          [bd_ids_for [bd_rows $tok] {v(beta)}]] \
    [list absent empty {s:v(beta)}]
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
  check {BD51b (POSITIVE CONTROL) ON + `*alpha*`: the FOREIGN DB's row appears and it alone MATCHED; the current DB matched nothing yet KEEPS its rows (§7.1 — the bars narrow the lower pane, never the tree)} \
    [list [bd_tv_parent $BVF.pw.tvf.tv {d:0}] \
          [bd_ids_for [bd_rows $tok] {v(alpha)}] \
          [bd_ids_for [bd_rows $tok] {v(beta)}] \
          [pcall ::wviewer::browser_match $tok]] \
    [list top-level {d:0|s:v(alpha)} {s:v(beta)} {ok {}}]
  # ⚠⚠ BD57 (TWO-PANE ITEM 16) — THE FOREIGN INVENTORIES ARE KEYED TOO, AND THIS
  # IS THE ONLY PLACE IT IS REACHABLE. `browser_and` has TWO production callers,
  # not one: `browser_match` (the current DB) and `browser_refresh`'s All-DBs
  # loop at wave_viewer.tcl:8110 (each FOREIGN DB). Item 16's work order names
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
  check {BD57 (ITEM 16) ON + the LABEL-ONLY `alpha`: the FOREIGN DB's header still appears, so browser_refresh's All-DBs loop keys the bars the same way browser_match does} \
    [list [bd_tv_parent $BVF.pw.tvf.tv {d:0}] \
          [bd_ids_for [bd_rows $tok] {v(alpha)}]] \
    [list top-level {d:0|s:v(alpha)}]
  check {BD57 (ITS NEGATIVE CONTROL) the same pattern against the RAW name would have matched nothing at all — which is what the header appearing proves did not happen} \
    [list [lindex [pcall ::wviewer::sig_match {v(alpha)} {alpha}] 1] \
          [lindex [pcall ::wviewer::sig_match {v(alpha)} {alpha} \
                     -key wviewer::browser_label_of] 1]] \
    [list {} {v(alpha)}]
  bd_pat $BSB {}
  check {BD51c (CONTROL) clearing the pattern brings everything back} \
    [list [$BVF.pw.tvf.tv exists {d:0}] [llength [bd_rows $tok]]] [list 1 7]

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
  check {BD56 (CONTROL) the inventory entry AND item 10's raw-path capture exist while the window does} \
    [list [info exists ::wviewer::browserdbsigs($tok)] \
          [info exists ::wviewer::browserraw($tok)]] \
    [list 1 1]
  set bd_sbpath $BSB
  catch {wviewer::close $tok}
  update
  check {BD56b close unsets BOTH: no per-token leak, item 10's array included} \
    [list [info exists ::wviewer::browserdbsigs($tok)] \
          [info exists ::wviewer::browserraw($tok)]] \
    [list 0 0]
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
