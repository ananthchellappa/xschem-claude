# tests/headless/test_wave_sigbrowser_i1315.tcl — Signal Browser PLAN items
# 13-15, MINUS item 14 (which measured its own axis and took its own file).
#
#   ITEM 13 (`BR`): the LOCATION BAR + the last-20 raw history (ViVA §3.1) — an
#   editable path entry at the top of the sidebar whose <Return> loads that raw,
#   a newest-first deduped capped dropdown of the raws opened, persisted to its
#   OWN store, and `select_raw` kept as the Browse... button beside it.
#   doc/claude/signal_browser_batch/PLAN.md item 13; receipts/13_receipt.md.
#
#   ITEM 15 (`BP`): the browser's slice of snapshot/restore — sidebar
#   shown/width, both searchbars, the plot destination, the tree's expanded set
#   and selection, and the raw-file history, carried under ONE `browser` key
#   that is emitted ONLY when it is non-default (test_wave_modes.tcl MG9 pins
#   snapshot's key list, so an unconditional key breaks a file this one does not
#   own). doc/claude/signal_browser_batch/PLAN.md item 15; receipts/15_receipt.md.
#
# ⚠⚠ WHY THIS FILE EXISTS AT ALL — DRIVER RULING 30, commit 18c45a16.
# Settled decision 9 put items 8-15 in ONE file. At 489 checks that file was
# killed mid-run by WSLg with ZERO check failures (0 of 9 completions), so every
# later item's verification became unmeasurable. Ruling 30 split the checks BY
# ITEM RANGE and FROZE the original:
#
#   test_wave_sigbrowser.tcl       items 8, 9, 10   BS BT BM   (FROZEN)
#   test_wave_sigbrowser_i11.tcl   item 11          BH
#   test_wave_sigbrowser_i12.tcl   item 12          BX
#   test_wave_sigbrowser_i1315.tcl items 13-15      BR BD BP   <- THIS FILE
#
# GROUP PREFIX: item 13 is `BR`, and `BD` (14) / `BP` (15) are RESERVED here so
# a later item cannot collide. Numbers are BLOCKED by arm:
#   01-18  SOURCE + PURE      both arms
#   19     one `--nogui` CHILD PROCESS (the startup restore), both arms
#   20-39  throwaway toplevels Tk/X only
#   40-59  REAL viewer + REAL raw files, Tk/X only
#
# ⚠ AMENDMENT, TWO-PANE ITEM 14 (`sash`/`devint`/`srccur` persistence). The
# scheme above is AT CAPACITY: BP60/BP61 are the teardown pair and already
# overflowed out of 01-18 into the real-viewer block, so squeezing item 14's ids
# back into 01-18 would renumber checks that exist. The band is EXTENDED instead,
# and the arm is carried in the id rather than in the block:
#   62-68  SOURCE + PURE      both arms   (item 14)
#   69-74  REAL viewer        Tk/X only   (item 14)
#   75     SOURCE             both arms   (item 14's verification FIXUP)
#   76-77  REAL viewer        Tk/X only   (item 14's verification FIXUP)
#   47b    REAL viewer        Tk/X only   (TWO-PANE item 15's prefix control)
#   78     REAL viewer        Tk/X only   (TWO-PANE item 19 — the store guard)
# Next free after this item: BP79. TWO-PANE ITEM 15 OWNS `BD60`-`BD70` — the
# fixup did NOT take them, and item 15 did not take a BP number either: its own
# checks are `BD60`-`BD70d` in test_wave_sigbrowser_i14.tcl (the only fixture
# holding two live raws). What item 15 does HERE is RESTATE — BP43a inverts from
# a tombstone into a positive, and BP43/BP45/BP52/BP53/BP54/BP55 re-key onto the
# `d:<registry idx>|` prefix — plus ONE new check, `BP47b`, which is the control
# that stops those re-keys going green on a re-derived WRONG prefix.
#
# ⚠ THE FOOTPRINT CLAIM, MADE EXPLICITLY BECAUSE RULING 30 WAS CUT ON IT.
# Ruling 30's split point was NOT the check count: across 8 pre-split runs the
# deaths landed in `BH5x` and `BX4x/BX5x` — the only two groups holding a REAL
# VIEWER AND THE REAL DESIGN WINDOW alive at once — and not one landed in
# BS/BT/BM. Item 13's heaviest group (BR40-BR54) holds a real viewer, two
# three-point ASCII raws and NO DESIGN WINDOW: no `xschem load` of a design, no
# hierarchy walk, no second toplevel. That is item 8's BSV footprint plus two
# 400-byte files, i.e. strictly less than BH5x/BX4x. RAW LOADS ARE A NEW AXIS
# NOBODY HAD MEASURED, which is why the raws are hand-written 3-point files
# rather than a simulator run.
# ⚠ TWO SMALL ADDITIONS TO THAT FOOTPRINT, both deliberate and both OUTSIDE the
# real-viewer group: BR19 spawns ONE `--nogui` child (no X connection at all,
# ~1 s, the only way to observe a STARTUP read), and BR28/BR29 raise a SECOND
# THROWAWAY TOPLEVEL — 400x300, no canvas traffic, destroyed in the same block —
# because a per-window widget fanned out from a GLOBAL list cannot be checked
# with one window. Neither touches the real viewer or a design window.
# ⚠ ITEMS 14 AND 15 MUST RE-MEASURE BEFORE APPENDING HERE. Item 14 holds two
# raw DBs open at once and item 15 adds destroy/restore cycles; both are new
# axes on the very dimension ruling 30 was cut on, and neither inherits this
# file's claim.
# ⚠ ITEM 14 MEASURED AND WENT ELSEWHERE (`_i14.tcl`). ITEM 15 MEASURED AND
# STAYED: its `BP4x` group adds FIVE destroy/restore cycles and ONE more
# three-point ASCII raw (hierarchical names, so there are GROUP rows to
# collapse), holds at most ONE viewer alive at a time and opens NO DESIGN
# WINDOW — the axis, and the completion rate that settled it, are in
# receipts/15_receipt.md. It also declines to drive a REAL descend for its
# decision-11 leg for exactly this reason; see BP55's comment.
#
# ============================================================================
# CONVENTIONS — SHARED WITH EVERY OTHER BROWSER FILE (wvbs_common.tcl)
# ============================================================================
# `check`, `check_true`, `pcall`, the counting `::bgerror`, `wvproc_body`,
# `bs_packed`, `bs_order`, `bs_wait_mapped`, `send_key`, `viewer_ready`, `$wsrc`
# and `wvbs_finish` come from `tests/headless/wvbs_common.tcl`, which is
# deliberately NOT named `test_*.tcl` (full_audit.sh selects its cases with
# `ls "$HERE"/test_*.tcl`, so a prelude with that name would run as a case,
# score zero checks, print no RESULT and be a permanent FAIL).
#
# Item 15's own numbering follows the same blocking: BP01-BP09 SOURCE and
# BP10-BP19 PURE run in BOTH arms; BP40-BP61 need the real viewer.
#
# ⚠ THE ARM STATEMENT. The `--nogui` arm runs BR01-BR19 only — the source greps,
# the pure-Tcl history algebra and the child-process startup restore. Every
# WIDGET claim (the row, the entry text, the balloon, the dropdown fanout, the
# real load, the tree refresh, the 0119 gate end to end) needs real Tk and real
# X, so A GREEN `--nogui` RUN PROVES ALMOST NOTHING ABOUT THE LOCATION BAR.
#
# ⚠ SKIP-BANNER WORDING IS LOAD-BEARING. The X-gated groups print
# `SKIPPED: <group> (Tk/X arm only)`. NEVER `RESULT: SKIP`, never
# `skipped: no X`, never `SKIP: no X connection` — full_audit.sh's `is_skip`
# matches those three strings and would score the WHOLE FILE as SKIP, silently
# discarding every check that did run.
#
# ============================================================================
# ⚠⚠ THE NEGATIVE CLAIM AND ITS POSITIVE CONTROL (ruling 29, driver note (d))
# ============================================================================
# "A --script load does NOT append to the raw history" is TRIVIALLY TRUE in this
# process — the gate is already 0 — and is indistinguishable from four other
# worlds: the load never happened, the store was never created, `rawhist_push`
# was deleted, or appending is broken for everybody. A check that cannot tell
# them apart is worth nothing, and this batch has now caught that shape three
# times (items 11, 11 again, 12).
#
# So BR50/BR51 come FIRST and are the POSITIVE CONTROL: with the gate OPEN and
# `::USER_CONF_DIR` repointed at the scratch dir, an interactive load really
# does move the in-memory list AND really does write a file whose SOURCED
# CONTENT names the path (asserted in a separate `interp`, so the read cannot be
# satisfied by the variable already in this process — driver note (e): assert on
# the WORLD, never on "the command returned without throwing"). Only then does
# BR52 close the gate, and its FIRST leg asserts `xschem raw rawfile` MOVED,
# which is what kills "the load never happened".
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_i1315.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_i1315.tcl

set ::wvbs_tag  wvsigbrowser_i1315
set ::wvbs_name test_wave_sigbrowser_i1315
source [file join [file dirname [info script]] wvbs_common.tcl]

# THE GATE AS THIS PROCESS FOUND IT, read BEFORE anything touches it — BR53
# asserts on this, not on a value the test itself installed.
set br_gate0 {UNSET}
if {[info exists ::update_recent_files]} { set br_gate0 $::update_recent_files }
set br_conf0 $::USER_CONF_DIR
# THE USER'S REAL STORE, recorded up front — EXISTENCE AND CONTENT: BR54 asserts
# this test never created or touched it (issue 0119 is exactly a verification run
# polluting a user file). Content, not just existence, because on a machine where
# the file already exists an existence check alone would pass over a rewrite.
set br_home_file [file join $br_conf0 raw_history]
set br_home_pre  [file exists $br_home_file]
set br_home_txt  {}
if {$br_home_pre} {
  set fd [open $br_home_file r] ; set br_home_txt [read $fd] ; close $fd
}

# --- the fixture writer -----------------------------------------------------
# A WELL-FORMED ASCII rawfile, hand-written. MEASURED to read cleanly
# (`points=3, vars=3, datasets=1 sim_type=tran`), which means item 13's real-raw
# group needs NO simulator. File-local rather than in wvbs_common.tcl: no other
# browser item reads a raw off disk.
#
# ⚠ THE TRAILING EMPTY LINE AFTER EACH POINT IS MANDATORY, and not cosmetically:
# a `Values:` block whose points are not terminated that way drives
# `read_raw_ascii_point` (src/save.c:406) past the end of the `tmp` buffer
# `read_raw_data_block` allocated for it, and xschem dies — `FATAL: signal 11`,
# or `double free or corruption` on the next `free_rawfile`, depending on what
# the overflow lands on. That is a PRE-EXISTING C defect this item found while
# probing and must not fix (settled decision 8: no new C code); it is filed as
# **issue 0213** (`doc/claude/issues/0213-read-raw-ascii-point-overruns-its-
# buffer.md`), which carries the standalone repro. BR46 therefore uses a PLAIN
# TEXT file for the malformed case — measured SAFE, returns 0 cleanly — never a
# truncated Values: block.
proc br_mkraw {path names npts} {
  set f [open $path w]
  puts $f "Title: signal browser item 13 fixture"
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
  close $f
}

# Read a raw_history store back THE WAY THE PRODUCT WILL: `source` it. In a
# FRESH SLAVE INTERP, which is the whole point — the store line is fully
# qualified (`set ::wviewer::rawhist {...}`), so sourcing it in THIS interpreter
# would both clobber the live variable and make the read satisfiable by state
# that was already in memory. A slave has neither.
proc br_store_read {path} {
  if {![file exists $path]} { return {NO-FILE} }
  set ip [interp create]
  set got {NO-VAR}
  catch {
    # the namespace has to exist before a qualified `set` can land in it
    $ip eval {namespace eval ::wviewer {}}
    $ip eval [list source $path]
    set got [$ip eval {set ::wviewer::rawhist}]
  }
  catch {interp delete $ip}
  return $got
}

# The ENGINE's current raw, read INSIDE the viewer's context. Never throws: the
# three assertable failures ("could not get there", "the engine refused",
# "there is no raw") are distinct strings, so a refusal can never masquerade as
# a path that happens to match.
proc br_rawfile {token} {
  if {![wviewer::switch_ctx $token]} { return {SWITCH-REFUSED} }
  set r {}
  if {[catch {xschem raw rawfile} r]} { return "ERR:$r" }
  return $r
}

# --- TWO-PANE ITEM 10: three assertable-sentinel readers ---------------------
# ⚠ ALL THREE ANSWER STRINGS, NEVER A COUNT AND NEVER A BOOLEAN. Item 10 can make
# a row VANISH (leaf rows left the tree; with All-DBs ticked the design root is
# not minted until two-pane item 15), and "the row is gone" must be a value a
# check can PRINT — not a `0` that reads as "closed", and not a throw.
#
# ⚠⚠ THE DEFECT THESE REPLACE IS A SILENT GREEN, NOT A THROW, and getting that
# backwards is how someone "fixes" it with a catch and keeps the vacuity. `pcall`
# answers the STRING `ERR:<msg>`; `lsearch -exact ERR:... g:x1` does NOT throw —
# it answers -1 — so the shipped leg `[expr {[lsearch -exact [pcall dict get
# $bs1 open] g:x1] < 0}]` evaluates `-1 < 0` = 1 and GOES GREEN when the read
# failed outright. Its twin `>= 0` reds, so the pair failed asymmetrically and
# only the honest half ever said so.

# The tree's selection: `no-tree` / `none` / the id list.
proc bp_sel {tv} {
  if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
  set s {}
  if {[catch {$tv selection} s]} { return no-tree }
  if {![llength $s]} { return none }
  return $s
}

# The CURRENT DB's design-root id, computed by the PRODUCT: `no-rows` /
# `no-root` / `ERR:...` / the id. `no-root` is item 10's All-DBs state and BP43a
# asserts it as such; two-pane item 15 turns it into `d:0|g:` and reds BP43a on
# purpose.
# ⚠ THE ARRAY IS READ INSIDE THE PROC, never substituted into a pcall argument:
# `$::wviewer::browserrows($tok)` on a token with no rows throws BEFORE pcall can
# see it.
proc bp_rootid {token} {
  if {![info exists ::wviewer::browserrows($token)]} { return no-rows }
  set r {}
  if {[catch {::wviewer::browser_root_id $::wviewer::browserrows($token)} r]} {
    return "ERR:$r"
  }
  if {$r eq {}} { return no-root }
  return $r
}

# ONE node's -open AFTER applying ONE tree state:
# `no-tree` / `absent` / `ERR:...` / `odd:<v>` / 0 / 1. bp_order_probe only —
# it MUTATES the tree, and only bp_order_probe restores what it changed.
# ⚠ THE BOOLEAN NORMALISATION IS NOT DECORATION. ttk's `see` force-opens an
# ancestor by writing a fresh boolean object, and the raw read is whatever ttk
# stored; `string is true -strict` makes `1`, `true` and `yes` one value.
proc bp_apply_read {token tv id d} {
  if {[catch {::wviewer::browser_tree_apply $token $d} r]} { return "ERR:$r" }
  catch {update idletasks}
  if {[catch {$tv exists $id} ex] || !$ex} { return absent }
  set o {}
  if {[catch {$tv item $id -open} o]} { return absent }
  if {![string is boolean -strict $o]} { return "odd:$o" }
  return [expr {[string is true -strict $o] ? 1 : 0}]
}

# BP54's ORDERING PROBE — three values, one tree, and it RESTORES what it
# changed: its last act re-applies {open $open sel $sel}, which is byte-for-byte
# the state `restore` produced, so BP55 still reads the RESTORED selection.
#   leg 1  the SELECTION ALONE. `browser_tree_apply` skips its open pass entirely
#          when the state carries no `open` key, so this is `$tv see` on its own
#          — the POSITIVE CONTROL that `see` really force-opens $anc on THIS tree.
#          ⚠ ITEM 10 MADE THIS LEG MANDATORY: the tree is now born COLLAPSED, so
#          a lone "$anc reads 0" is the DEFAULT and asserts nothing.
#   leg 2  the SAME selection WITH the persisted open set: $anc reads 0 only if
#          the open pass ran AFTER `see` and beat it.
#   leg 3  the selection survived both applies.
proc bp_order_probe {token tv anc sel open} {
  if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
  set a [bp_apply_read $token $tv $anc [dict create sel $sel]]
  set b [bp_apply_read $token $tv $anc [dict create open $open sel $sel]]
  return [list $a $b [bp_sel $tv]]
}

# --- SOURCE ORDERING AS AN ASSERTABLE STRING (two-pane item 14) --------------
# ⚠ NEVER A BOOLEAN AND NEVER A THROW, for the reason the whole file is built
# on: "the needle I am ordering vanished" and "the needles are in the wrong
# order" are DIFFERENT DEFECTS and must be different values. A boolean collapses
# them, and `string first` answering -1 makes `-1 < 5` read TRUE — i.e. a
# DELETED first step would report correct order.
#   ok                the three needles appear once each, in the order given
#   missing:<needle>  the FIRST one that is not in the body at all
#   wrong:<i> <j> <k> all three present, but not in that order
# --- WHICH FIELDS A STATE DICT DEPARTS IN (two-pane item 14) ------------------
# ⚠ A LIST OF KEY NAMES, NOT A BOOLEAN, and the difference is the whole value of
# it: `browser_state_is_default` answers 0 for "the sash leaked into every
# window" and 0 for "the sidebar is open, which is what the test asked for", and
# a check built on the boolean cannot tell a real defect from its own fixture.
# `hist` is excluded for the same reason `browser_state_is_default` excludes it
# (divergence D-A: a global disk-backed store would make the answer depend on
# the developer's home directory). `no-state` when there is no window at all.
proc bp_nondefault_keys {d} {
  if {$d eq {} || [string range $d 0 3] eq {ERR:}} { return no-state }
  if {[catch {wviewer::browser_state_default} def]} { return no-default }
  set out {}
  foreach k [dict keys $def] {
    if {$k eq {hist}} { continue }
    if {[wviewer::dget $d $k {NO-KEY}] ne [dict get $def $k]} { lappend out $k }
  }
  if {![llength $out]} { return none }
  return $out
}

proc bp_order3 {body a b c} {
  foreach n [list $a $b $c] {
    if {[string first $n $body] < 0} { return "missing:$n" }
  }
  set i [string first $a $body]
  set j [string first $b $body]
  set k [string first $c $body]
  if {$i < $j && $j < $k} { return ok }
  return "wrong:$i $j $k"
}

if {[catch {

# ============================================================================
# BR01-BR09 — SOURCE arm, BOTH arms. Structure only: what the shipped bodies
# contain and in what ORDER. Every behavioural claim is in BR20+/BR40+.
# ============================================================================
set br_add   [wvproc_body $wsrc wviewer::rawhist_add]
set br_push  [wvproc_body $wsrc wviewer::rawhist_push]
set br_pathb [wvproc_body $wsrc wviewer::rawhist_path]
set br_loadb [wvproc_body $wsrc wviewer::rawhist_load]
set br_writeb [wvproc_body $wsrc wviewer::rawhist_write]
set br_bar   [wvproc_body $wsrc wviewer::rawbar_load]
set br_sync  [wvproc_body $wsrc wviewer::rawbar_sync]
set br_brows [wvproc_body $wsrc wviewer::rawbar_browse]
set br_commit [wvproc_body $wsrc wviewer::rawbar_commit]
set br_build [wvproc_body $wsrc wviewer::browser_build]

# ⚠ EVERY BODY MUST HAVE BEEN FOUND FIRST. `wvproc_body` returns {} on a rename
# or a reformatted signature, and `regexp -all` over {} is 0 — without this leg
# a rename would make half the greps below VACUOUSLY GREEN (test_wave_grid's
# GX2 lesson, and the trap ruling 29 names).
check {BR01 every item-13 proc body was found in the source} \
  [list [expr {$br_add   ne {}}] [expr {$br_push  ne {}}] \
        [expr {$br_pathb ne {}}] [expr {$br_loadb ne {}}] \
        [expr {$br_writeb ne {}}] [expr {$br_bar ne {}}] \
        [expr {$br_sync  ne {}}] [expr {$br_brows ne {}}] \
        [expr {$br_commit ne {}}] [expr {$br_build ne {}}]] \
  [list 1 1 1 1 1 1 1 1 1 1]

# PURITY IS THE PROPERTY THAT LETS BR10-BR18 RUN IN THE --nogui ARM AT ALL.
# A rawhist_add that reached a widget, the engine or the disk could not be
# exercised without X, and the ordering/dedup/cap claims would then rest solely
# on the X arm — i.e. on the arm the degraded box keeps killing.
check {BR01 rawhist_add is PURE: no widget, no xschem, no file I/O} \
  [regexp -all {winfo |xschem |\bopen |puts |variable } $br_add] 0

# ORDER, NOT PRESENCE. A guard placed AFTER the write reads as installed and
# gates nothing — the same failure mode GX1 exists to catch.
set br_gi [string first {update_recent_files} $br_push]
set br_wi [string first {wviewer::rawhist_write} $br_push]
check {BR02 rawhist_push carries the 0119 gate, spelled update_recent_files} \
  [expr {$br_gi >= 0}] 1
check {BR02 ...and the gate comes BEFORE the write, not after it} \
  [expr {$br_gi >= 0 && $br_wi >= 0 && $br_gi < $br_wi}] 1
# THE GATE IS THE SHARED FLAG, NOT A PRIVATE ONE. A private flag would be 1 in
# a --script BODY inside an ungated GUI session and would reopen 0119, because
# only update_recent_files is toggled around source_tcl_file (xinit.c).
#
# ⚠ THE PATTERN IS DELIBERATELY NARROW. `recent_files` is a SUBSTRING of the
# gate's own name, so grepping for it here would count the gate and the check
# could never go green — a check that can only fail measures nothing. What is
# actually claimed is that the raw history has its OWN store: the push must
# never reach the recent-files list (`tctx::recentfile`) or its writer.
check {BR02 ...and the store is its OWN, never the recent-files list} \
  [regexp -all {tctx::recentfile|write_recent_file|setup_recent_menu} $br_push] 0

check {BR03 rawhist_path derives the store from USER_CONF_DIR at call time} \
  [expr {[regexp -all {::USER_CONF_DIR} $br_pathb] > 0 &&
         [regexp -all {raw_history} $br_pathb] > 0}] 1
# A corrupt half-written store must not stop xschem starting.
check {BR03 rawhist_load's source is guarded by catch} \
  [regexp -all {catch \{source } $br_loadb] 1
check {BR03 rawhist_write emits a sourceable fully-qualified set line} \
  [regexp -all {set ::wviewer::rawhist} $br_writeb] 1
# ⚠ A REAL DEFECT THIS FILE CAUGHT, now pinned so it cannot come back silently.
# The namespace defines `wviewer::open {token}` and `wviewer::close {token}`, and
# Tcl resolves an unqualified command in the CURRENT NAMESPACE FIRST — so a bare
# `open $f w` here called `wviewer::open` with two arguments, threw, and the
# `catch` swallowed it: nothing was ever written while every structural check
# stayed green. Item 10's `clipboard clear` defect, verbatim.
check {BR03 ...and it qualifies open/close, which this namespace SHADOWS} \
  [list [regexp {catch \{::open \$f w\}} $br_writeb] \
        [regexp {catch \{::close \$fd\}} $br_writeb]] \
  [list 1 1]

check {BR04 browser_build creates the Location row and its two children} \
  [list [regexp -all {frame \$f\.loc} $br_build] \
        [regexp -all {ttk::combobox \$f\.loc\.cb} $br_build] \
        [regexp -all {button \$f\.loc\.br} $br_build]] \
  [list 1 1 1]
# THE PACKING ORDER IS THE CLAIM: the Location row sits ABOVE the Search bar.
set br_pl [string first "pack \$f.loc" $br_build]
set br_ps [string first "pack \$f.wvsearch" $br_build]
check {BR04 the Location row is packed BEFORE the search bar} \
  [expr {$br_pl >= 0 && $br_ps >= 0 && $br_pl < $br_ps}] 1
# ⚠ BROWSE REUSES select_raw — it does NOT reimplement it (the PLAN's
# "replaces nothing"). A second hand-rolled tk_getOpenFile would drift from the
# one the legacy Graph dialog and load_raw use.
check {BR04 Browse routes to select_raw and rolls no second file dialog} \
  [list [regexp -all {tk_getOpenFile} "$br_build$br_brows"] \
        [regexp -all {select_raw} $br_brows]] \
  [list 0 1]

# THE GX1 RULE, RESTATED LOCALLY so a deletion fails THIS file too and not only
# test_wave_grid's: a regenerate that carries the current strips forward must
# fold the live rect state FIRST (issue 0194).
set br_ci [string first {wviewer::capture_live_view_state $token} $br_bar]
set br_ri [string first {wviewer::regenerate $token} $br_bar]
check {BR05 rawbar_load folds the live view state BEFORE it regenerates} \
  [expr {$br_ci >= 0 && $br_ri >= 0 && $br_ci < $br_ri}] 1
# ⚠ THE ATOMICITY CLAIM, AND IT IS A DELIBERATE DIVERGENCE FROM attach_raw,
# whose first act is `catch {xschem raw clear}`. The engine's read is atomic
# only while nothing cleared the old data first; clearing would turn a typo in
# an editable path entry into "your waveforms are gone". BR45/BR46 assert the
# behaviour, this leg pins the mechanism.
check {BR05 rawbar_load reads ADDITIVELY: it never clears the current raw} \
  [regexp -all {raw clear} $br_bar] 0

# THE HISTORY IS ONLY TOUCHED ON SUCCESS. A path that could not be read is not
# a raw the user opened, and must not take a slot in a twenty-deep list.
set br_rci [string first {if {$rc != 1}} $br_bar]
set br_hpi [string first {wviewer::rawhist_push} $br_bar]
check {BR06 the history push sits AFTER the failed-read bail-out} \
  [expr {$br_rci >= 0 && $br_hpi >= 0 && $br_rci < $br_hpi}] 1
check {BR06 ...and after the read itself} \
  [expr {[string first {xschem raw read} $br_bar] < $br_hpi}] 1

# ITEM 9's DECLARED LIMIT D6: the inventory is a SNAPSHOT taken when the sidebar
# is SHOWN, and browser_show's pack branch was its ONLY caller. A Location-bar
# load that omits this leaves the NEW raw's waveforms under the OLD raw's signal
# list. BR44 asserts the behaviour; this pins the call.
check {BR07 rawbar_load refreshes the browser inventory after a good read} \
  [regexp -all {wviewer::browser_refresh \$token 1} $br_bar] 1
check {BR07 ...and it is inside the success path, after the bail-out} \
  [expr {$br_rci < [string first {wviewer::browser_refresh} $br_bar]}] 1

# THE LONG-PATH ANSWER, pinned as the two mechanisms it really is.
check {BR08 the combobox is fixed-width and right-justified} \
  [expr {[regexp {ttk::combobox \$f\.loc\.cb -width 18 -justify right} $br_build] ? 1 : 0}] 1
# ⚠ `balloon` BAKES ITS STRING IN AT BIND TIME (xschem.tcl builds the <Enter>
# script by substitution), so a tooltip attached once at build time would show
# the path the bar held when the sidebar was built, forever. It has to be
# RE-ATTACHED on every load — which is why it lives in rawbar_sync.
check {BR08 the full-path balloon is re-attached in rawbar_sync, not at build} \
  [list [regexp -all {balloon } $br_sync] [regexp -all {balloon } $br_build]] \
  [list 1 0]
# ONE COMMIT PATH (searchbar_fire's rule): no route may apply a policy another
# route skips.
check {BR08 both bindings and Browse end in the SAME loader} \
  [list [regexp -all {wviewer::rawbar_commit \$token} $br_build] \
        [regexp -all {wviewer::rawbar_load} $br_commit] \
        [regexp -all {wviewer::rawbar_load} $br_brows]] \
  [list 2 1 1]

# BT09's no-bump claim, restated for item 13's own bodies: no key, no menu
# entry, so test_wave_grid's guide literals (16 sequences / 11 accelerators)
# need no bump.
set br_binds 0; set br_menus 0
foreach b [list $br_add $br_push $br_pathb $br_loadb $br_writeb $br_bar \
                $br_sync $br_brows $br_commit $br_build] {
  incr br_binds [regexp -all {bind WaveViewer} $b]
  incr br_menus [regexp -all {\$mb\.[a-z]+ add } $b]
}
check {BR09 item 13 adds no WaveViewer key binding and no menu entry} \
  [list $br_binds $br_menus] [list 0 0]

# ============================================================================
# BR10-BR19 — PURE arm, BOTH arms. `rawhist_add` is the whole of the history
# algebra: newest-first, deduped on the NORMALISED path, capped.
# ============================================================================
check {BR10 an empty history plus one path is that one path} \
  [pcall ::wviewer::rawhist_add {} /tmp/br/a.raw] [file normalize /tmp/br/a.raw]

set br_h [pcall ::wviewer::rawhist_add {} /tmp/br/a.raw]
set br_h [pcall ::wviewer::rawhist_add $br_h /tmp/br/b.raw]
check {BR11 the SECOND path lands FIRST — newest first} \
  $br_h [list [file normalize /tmp/br/b.raw] [file normalize /tmp/br/a.raw]]

# ⚠ THE DEDUP CLAIM AND SABOTAGE (a)'s TARGET.
set br_h2 [pcall ::wviewer::rawhist_add $br_h /tmp/br/a.raw]
check {BR12 re-adding an existing path MOVES it to the front, no duplicate} \
  $br_h2 [list [file normalize /tmp/br/a.raw] [file normalize /tmp/br/b.raw]]
check {BR12 ...and the length is unchanged} [llength $br_h2] 2

# the cap, at the shipping value
set br_c {}
for {set i 1} {$i <= 25} {incr i} {
  set br_c [pcall ::wviewer::rawhist_add $br_c /tmp/br/f$i.raw 20]
}
check {BR13 the cap holds at 20} [llength $br_c] 20
check {BR13 ...the NEWEST is still first} [lindex $br_c 0] [file normalize /tmp/br/f25.raw]
# f1..f25 added in order -> the list is f25..f6: f5 is GONE, f6 is the LAST
# survivor. Naming both ends is what makes "the oldest were dropped" a claim
# rather than a length assertion.
check {BR13 ...and the OLDEST were dropped, not the newest} \
  [list [lsearch -exact $br_c [file normalize /tmp/br/f5.raw]] \
        [lsearch -exact $br_c [file normalize /tmp/br/f6.raw]]] \
  [list -1 19]
check {BR14 a cap of N keeps exactly N} \
  [llength [pcall ::wviewer::rawhist_add {a b c d e} /tmp/br/z.raw 3]] 3

check {BR15 an empty path is REFUSED and the history is unchanged} \
  [pcall ::wviewer::rawhist_add {/x /y} {}] {/x /y}

check {BR16 rawhist_max reads ::raw_history_max} \
  [list [expr {[info exists ::raw_history_max] ? $::raw_history_max : {UNSET}}] \
        [pcall ::wviewer::rawhist_max]] \
  [list 20 20]
set br_save_max $::raw_history_max
set ::raw_history_max {twenty}
check {BR16 ...and a garbage cap falls back to 20 rather than throwing} \
  [pcall ::wviewer::rawhist_max] 20
set ::raw_history_max -3
check {BR16 ...as does a non-positive one} [pcall ::wviewer::rawhist_max] 20
set ::raw_history_max $br_save_max

# ⚠ TWO SPELLINGS OF ONE FILE ARE ONE ENTRY. A literal `ne` dedup would let the
# same raw occupy all twenty slots; this is the second leg sabotage (a) kills.
set br_n [pcall ::wviewer::rawhist_add {/a/b} {/a/./b/}]
check {BR17 two spellings of one path collapse to ONE entry} [llength $br_n] 1
check {BR17 ...and it is the normalised form} $br_n [list [file normalize /a/b]]

set br_in {/p /q}
pcall ::wviewer::rawhist_add $br_in /r
check {BR18 rawhist_add does not mutate its input list} $br_in {/p /q}

# ============================================================================
# BR19 — THE OTHER HALF OF PERSISTENCE: THE PRODUCT READS THE STORE BACK, and
# it is proven IN A FRESH PROCESS, both arms.
#
# ⚠⚠ WHY A CHILD PROCESS AND NOT A CHEAPER CHECK. BR50/BR51 prove the WRITE by
# reading the file off disk; on their own they leave "the history is written
# every session and NEVER restored — the dropdown is empty at every startup"
# indistinguishable from a working feature. The read happens EXACTLY ONCE, at
# startup, before any test in this process could observe it, so nothing in this
# interpreter can assert it: by the time the file runs, `rawhist_load` has
# already been called (or has already not been). A verifier deleted the single
# `wviewer::rawhist_load` line from xschem.tcl's startup block and the whole
# file stayed green — this group is the answer, and it FAILS with that line gone
# because the child comes back with an EMPTY history.
#
# The lever is `HOME`: `xinit.c` :3035 derives `USER_CONF_DIR` from it, so a
# child started with HOME inside our scratch dir has a scratch config dir and
# CANNOT touch the user's (issue 0119's rule, applied to the child too). Leg 1
# is the control that proves exactly that redirection happened — without it, an
# empty history would be indistinguishable from "the override silently failed
# and the child read the real ~/.xschem".
# ============================================================================
set br_seed {/tmp/br/seed_one.raw /tmp/br/seed_two.raw}
set br_home  [file join $scratch fakehome]
set br_hconf [file join $br_home .xschem]
file mkdir $br_hconf
set fd [open [file join $br_hconf raw_history] w]
puts $fd "set ::wviewer::rawhist {$br_seed}"
close $fd

# ⚠ THE SITE, NAMED. The behavioural legs below say the restore HAPPENED; this
# says WHERE from, so a deletion localises in one line instead of a bisect. It
# must be at COLUMN 0 — inside a proc body it would be a definition nobody runs.
set fd [open [file join $repo src xschem.tcl] r] ; set br_xsrc [read $fd] ; close $fd
check {BR19 xschem.tcl calls rawhist_load ONCE, at top level (startup)} \
  [regexp -all -line {^wviewer::rawhist_load$} $br_xsrc] 1

set br_child [file join $scratch br_startup_probe.tcl]
set fd [open $br_child w]
puts $fd {
  puts "PROBE_CONF=$::USER_CONF_DIR"
  puts "PROBE_HIST=[wviewer::rawhist_get]"
  puts "PROBE_DONE"
  flush stdout
  exit 0
}
close $fd
set br_out [file join $scratch br_startup_probe.out]
set br_env_home $::env(HOME)
set ::env(HOME) $br_home
catch {exec timeout 60 [info nameofexecutable] --nogui --pipe -q --nolog \
         --script $br_child >& $br_out}
set ::env(HOME) $br_env_home
set br_body {}
if {[file exists $br_out]} { set fd [open $br_out r] ; set br_body [read $fd] ; close $fd }
set br_cconf {} ; regexp {PROBE_CONF=(\S*)}    $br_body -> br_cconf
set br_chist {} ; regexp {PROBE_HIST=([^\n]*)} $br_body -> br_chist

check {BR19 (CONTROL) the child ran and its USER_CONF_DIR is the scratch home} \
  [list [expr {[string first PROBE_DONE $br_body] >= 0}] \
        [expr {$br_cconf eq {} ? {} : [file normalize $br_cconf]}]] \
  [list 1 [file normalize $br_hconf]]
check {BR19 a FRESH xschem RESTORES the persisted history at startup} \
  $br_chist $br_seed

# ============================================================================
# BR20-BR29 — the THROWAWAY TOPLEVEL. Item 8's `.wvbs1` fixture shape: a real
# frame, a real canvas packed the way the viewer packs its own, a fake windows
# dict entry. No xschem context, no raw — widget structure only.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  catch {destroy .wvbr1}
  toplevel .wvbr1
  wm title .wvbr1 {item13 location bar fixture}
  wm geometry .wvbr1 700x420+90+90
  canvas .wvbr1.drw -background white -width 600 -height 380
  pack .wvbr1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbr [dict create top .wvbr1 win_path .wvbr1.drw]
  update
  set BRF .wvbr1.wvbrowser

  check {BR20 browser_build returns 1 and the Location row now exists} \
    [list [pcall ::wviewer::browser_build wvbr .wvbr1] [winfo exists $BRF.loc] \
          [winfo class $BRF.loc]] \
    [list 1 1 Frame]
  update
  # the LOCAL twin of the widened BS22/BT21 — this file must fail on its own if
  # the row is dropped, not only the frozen one.
  # ⚠ WIDENED BY THE TWO-PANE ITEM 9 in lockstep with BS22/BT21: `.tvf` moved
  # inside the new `ttk::panedwindow` `.pw`, and `.opt` (R11's two INERT
  # checkbuttons) joined the sidebar. Widened, not deleted — the Location row
  # this check exists for is still named in both lists.
  check {BR20 the sidebar's children are exactly the two-pane set} \
    [lsort [winfo children $BRF]] \
    [lsort [list $BRF.ph $BRF.wvsearch $BRF.tb $BRF.opt $BRF.pw $BRF.wvfilter \
                 $BRF.loc]]
  check {BR21 the packing recipe is the seven-slave stack with .loc FIRST} \
    [pack slaves $BRF] \
    [list $BRF.loc $BRF.wvsearch $BRF.tb $BRF.ph $BRF.wvfilter $BRF.opt $BRF.pw]
  check {BR21 ...and the Location row is packed -side top -fill x} \
    [list [dict get [pack info $BRF.loc] -side] \
          [dict get [pack info $BRF.loc] -fill]] \
    [list top x]

  check {BR22 the entry is an EDITABLE combobox, right-justified, fixed width} \
    [list [winfo class $BRF.loc.cb] [$BRF.loc.cb cget -state] \
          [$BRF.loc.cb cget -justify] [$BRF.loc.cb cget -width]] \
    [list TCombobox normal right 18]
  # ⚠ `-side right` FIRST is forced by item 9's D1, not taste: browser_width
  # sets `pack propagate` 0 and FIXES the frame width, so a child wider than
  # that is CLIPPED, never accommodated. The packer serves slaves in packing
  # order, so the fixed-width Browse button must claim its slot before the
  # stretchy entry or it is what disappears off the right edge.
  check {BR23 Browse... exists, is packed FIRST and to the RIGHT} \
    [list [winfo exists $BRF.loc.br] [$BRF.loc.br cget -text] \
          [lindex [pack slaves $BRF.loc] 0] \
          [dict get [pack info $BRF.loc.br] -side]] \
    [list 1 {Browse...} $BRF.loc.br right]
  check {BR23 ...and the entry takes the remaining width} \
    [list [dict get [pack info $BRF.loc.cb] -side] \
          [dict get [pack info $BRF.loc.cb] -expand]] \
    [list left 1]

  # -values MIRRORS the history. Asserted through a real rawhist_get, and the
  # variable is put back afterwards so nothing later inherits a fake history.
  set br_hsave $::wviewer::rawhist
  set ::wviewer::rawhist [list /tmp/br/one.raw /tmp/br/two.raw]
  check {BR24 rawbar_sync mirrors the history into the dropdown -values} \
    [list [pcall ::wviewer::rawbar_sync wvbr /tmp/br/one.raw] \
          [$BRF.loc.cb cget -values] [$BRF.loc.cb get]] \
    [list 1 {/tmp/br/one.raw /tmp/br/two.raw} /tmp/br/one.raw]
  set ::wviewer::rawhist $br_hsave

  # PROC-SPY on the commit path. `rawbar_commit` is renamed, so what is being
  # observed is the BINDING actually reaching it — not a re-implementation of
  # what the binding is believed to say.
  # MAP THE ROW before generating events. `event generate` on an unmapped widget
  # is not a reliable delivery under WSLg (the same class of trap as the bare
  # key-delivery flake), and the sidebar is deliberately built HIDDEN. Packed
  # directly rather than through browser_toggle so this group stays free of the
  # toggle's context loan and its replay line.
  pack $BRF -side left -fill y -before .wvbr1.drw
  bs_wait_mapped $BRF.loc.cb
  set ::br_commit_calls {}
  rename ::wviewer::rawbar_commit ::wviewer::__br_real_commit
  proc ::wviewer::rawbar_commit {token} { lappend ::br_commit_calls $token ; return 1 }
  focus $BRF.loc.cb
  update
  event generate $BRF.loc.cb <Return>
  update
  check {BR25 <Return> in the Location entry reaches the commit path} \
    $::br_commit_calls {wvbr}
  set ::br_commit_calls {}
  event generate $BRF.loc.cb <<ComboboxSelected>>
  update
  check {BR26 <<ComboboxSelected>> reaches the SAME commit path} \
    $::br_commit_calls {wvbr}
  rename ::wviewer::rawbar_commit {}
  rename ::wviewer::__br_real_commit ::wviewer::rawbar_commit

  # THE NO-WINDOW ANSWERS. Every entry point must ANSWER 0 for an unknown
  # token, never throw — they ride bindings, and a throw there pops bgerror,
  # which is modal under X and hangs a headless run.
  check {BR27 every entry point answers 0 for an unknown token, never throws} \
    [list [pcall ::wviewer::rawbar_load nosuch /tmp/br/a.raw] \
          [pcall ::wviewer::rawbar_commit nosuch] \
          [pcall ::wviewer::rawbar_browse nosuch] \
          [pcall ::wviewer::rawbar_sync nosuch]] \
    [list 0 0 0 0]

  # ==========================================================================
  # BR28/BR29 — TWO WINDOWS, ONE HISTORY. `rawhist` is a single GLOBAL list but
  # the dropdown is a PER-WINDOW widget whose `-values` are set once at
  # browser_build time, so a second viewer built earlier would keep its
  # build-time (usually empty) dropdown for the rest of the session while the
  # user opens raw after raw in the first. That is why `rawbar_sync` fans the
  # -values out; these two checks are the only thing that can see it, since one
  # window cannot distinguish "fanned out" from "refreshed itself".
  #
  # ⚠ AND THE LIMIT OF THE FANOUT IS ASSERTED TOO (BR29): the ENTRY TEXT and the
  # balloon stay per-window. Window 2 did not load that raw, and a dropdown
  # refresh that also rewrote its Location bar would be telling the user window
  # 2 is showing a raw it is not.
  # ==========================================================================
  catch {destroy .wvbr2}
  toplevel .wvbr2
  wm title .wvbr2 {item13 second viewer fixture}
  wm geometry .wvbr2 400x300+520+90
  canvas .wvbr2.drw -background white -width 300 -height 260
  pack .wvbr2.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbr2 [dict create top .wvbr2 win_path .wvbr2.drw]
  set BRF2 .wvbr2.wvbrowser
  set br_h2save $::wviewer::rawhist
  set ::wviewer::rawhist {}
  check {BR28 (FIXTURE) a second window's sidebar builds with an EMPTY dropdown} \
    [list [pcall ::wviewer::browser_build wvbr2 .wvbr2] \
          [$BRF2.loc.cb cget -values] [$BRF2.loc.cb get]] \
    [list 1 {} {}]
  update
  # the history moves (as an ungated load would move it) and window ONE syncs
  set ::wviewer::rawhist [list /tmp/br/three.raw /tmp/br/four.raw]
  check {BR28 a sync in window 1 fans the shared history out to window 2's dropdown} \
    [list [pcall ::wviewer::rawbar_sync wvbr /tmp/br/three.raw] \
          [$BRF2.loc.cb cget -values] [$BRF.loc.cb cget -values]] \
    [list 1 {/tmp/br/three.raw /tmp/br/four.raw} {/tmp/br/three.raw /tmp/br/four.raw}]
  check {BR29 ...but window 2 keeps its OWN (blank) Location text and balloon} \
    [list [$BRF2.loc.cb get] [bind $BRF2.loc.cb <Enter>] [$BRF.loc.cb get]] \
    [list {} {} /tmp/br/three.raw]
  set ::wviewer::rawhist $br_h2save
  dict unset ::wviewer::windows wvbr2
  destroy .wvbr2

  dict unset ::wviewer::windows wvbr
  destroy .wvbr1

} else {
  puts "SKIPPED: BR2x group (Tk/X arm only)"
}

# ============================================================================
# BP01-BP09 — ITEM 15, SOURCE arm, BOTH arms. Structure and ORDER only; every
# behavioural claim lives in BP10+/BP40+.
# ============================================================================
set bp_snap   [wvproc_body $wsrc wviewer::snapshot]
set bp_rest   [wvproc_body $wsrc wviewer::restore]
set bp_state  [wvproc_body $wsrc wviewer::browser_state]
set bp_apply  [wvproc_body $wsrc wviewer::browser_state_apply]
set bp_defb   [wvproc_body $wsrc wviewer::browser_state_default]
set bp_isdef  [wvproc_body $wsrc wviewer::browser_state_is_default]
set bp_tstate [wvproc_body $wsrc wviewer::browser_tree_state]
set bp_tapply [wvproc_body $wsrc wviewer::browser_tree_apply]
set bp_tnodes [wvproc_body $wsrc wviewer::browser_tree_nodes]
set bp_width  [wvproc_body $wsrc wviewer::browser_width]
set bp_sbset  [wvproc_body $wsrc wviewer::searchbar_set]
set bp_merge  [wvproc_body $wsrc wviewer::rawhist_merge]

# ⚠ THE SAME GUARD BR01 CARRIES, AND FOR THE SAME REASON: `wvproc_body` answers
# {} on a rename, `regexp -all` over {} is 0, and half the greps below would go
# VACUOUSLY GREEN (ruling 29; test_wave_grid's GX2 lesson).
check {BP01 every item-15 proc body was found in the source} \
  [list [expr {$bp_snap   ne {}}] [expr {$bp_rest   ne {}}] \
        [expr {$bp_state  ne {}}] [expr {$bp_apply  ne {}}] \
        [expr {$bp_defb   ne {}}] [expr {$bp_isdef  ne {}}] \
        [expr {$bp_tstate ne {}}] [expr {$bp_tapply ne {}}] \
        [expr {$bp_tnodes ne {}}] [expr {$bp_width  ne {}}] \
        [expr {$bp_sbset  ne {}}] [expr {$bp_merge  ne {}}]] \
  [list 1 1 1 1 1 1 1 1 1 1 1 1]

# --- BP02: THE EMISSION GATE, which is load-bearing OUTSIDE this file --------
# test_wave_modes.tcl MG9 pins `[dict keys $snap]` to exactly
# {open sharedx rawfile graphs mode target}. An unconditional `browser` key
# breaks it, and would also make ase::ui::viewer_snapshot's difference test mark
# every session dirty. BP42 is the local behavioural twin; sabotage (d) removes
# the gate and both go red together.
check {BP02 snapshot emits `browser` from exactly ONE site} \
  [regexp -all {dict set d browser \$bs} $bp_snap] 1
check {BP02 ...and only through the non-default gate} \
  [regexp -all {wviewer::browser_state_is_default} $bp_snap] 1
set bp_bi [string first {dict set d browser} $bp_snap]
set bp_ci [string first {dict replace $prev open 0} $bp_snap]
check {BP02 ...inside the OPEN arm, never in the closed one (R4's shape)} \
  [expr {$bp_bi >= 0 && $bp_ci >= 0 && $bp_bi < $bp_ci}] 1

# --- BP03: restore applies it ONCE, and LAST -------------------------------
# AFTER the regenerate, not before: packing the sidebar resizes the canvas and
# that already goes <Configure> -> on_configure -> configure_apply, which
# captures and regenerates (browser_toggle's own ⚠).
check {BP03 restore applies the browser state exactly once} \
  [regexp -all {wviewer::browser_state_apply} $bp_rest] 1
set bp_ai [string first {wviewer::browser_state_apply} $bp_rest]
set bp_ri [string last  {wviewer::regenerate $token} $bp_rest]
check {BP03 ...and AFTER the final regenerate, not before it} \
  [expr {$bp_ai >= 0 && $bp_ri >= 0 && $bp_ri < $bp_ai}] 1

# --- BP04: driver note (f) made ASSERTABLE ----------------------------------
# The reader composes ONLY through the owning item's accessor. A reader that
# went to `sbcase(`/`sbcfg(`/`dest(` would be a second spelling of state those
# items own, and would drift from them silently.
check {BP04 browser_state reads through the owners' accessors only} \
  [list [regexp -all {wviewer::searchbar_get} $bp_state] \
        [regexp -all {wviewer::plot_dest} $bp_state] \
        [regexp -all {wviewer::browser_shown} $bp_state] \
        [regexp -all {wviewer::rawhist_get} $bp_state]] \
  [list 2 1 1 1]
check {BP04 ...and reaches into NO other item's internals} \
  [regexp -all {sbcase\(|sbcfg\(|sballdb\(|dest\(} $bp_state] 0

# --- BP05: settled decision 13 ----------------------------------------------
# Browser state derives from the raw verbs, NEVER from the rect model — issue
# 0186 is open and blanks the document under a CIW `xschem reload`.
check {BP05 neither the reader nor the writer reads the RECT model (decision 13)} \
  [regexp -all {getprop|get rects|xschem rect} "$bp_state$bp_apply"] 0

# --- BP06: the SECOND gated history site ------------------------------------
# BR02's shape, restated for the merge: the 0119 gate must come BEFORE the
# write, or it reads as installed and gates nothing.
set bp_gi [string first {update_recent_files} $bp_merge]
set bp_wi [string first {wviewer::rawhist_write} $bp_merge]
check {BP06 rawhist_merge carries the 0119 gate, spelled update_recent_files} \
  [expr {$bp_gi >= 0}] 1
check {BP06 ...and the gate comes BEFORE the write} \
  [expr {$bp_gi >= 0 && $bp_wi >= 0 && $bp_gi < $bp_wi}] 1
# it REUSES item 13's pure adder rather than re-implementing normalise/dedup/cap
check {BP06 ...and it folds through rawhist_add, re-implementing no dedup} \
  [list [regexp -all {wviewer::rawhist_add} $bp_merge] \
        [regexp -all {file normalize} $bp_merge]] \
  [list 1 0]
# `lreverse` is Tcl 8.5+; this repo targets 8.4-8.6 (rawhist_add's own note).
check {BP06 ...with an index loop, not the 8.5-only lreverse} \
  [regexp -all {lreverse} $bp_merge] 0

# --- BP07: THE LOCAL TWIN OF BT08 -------------------------------------------
# test_wave_sigbrowser.tcl is FROZEN (ruling 30) and greps four literals inside
# browser_width's body. The `{want {}}` widening must not disturb any of them —
# which is also why the clamp may NOT be factored out into a shared helper.
# Restated here so a later change fails THIS file too.
check {BP07 the width widening keeps all four BT08 literals in place} \
  [list [expr {[string first {pack propagate $f 0} $bp_width] >= 0}] \
        [expr {[string first {[winfo reqwidth $f.wvsearch] -} $bp_width] >= 0}] \
        [expr {[string first {[winfo reqwidth $f.wvsearch.err]} $bp_width] >= 0}] \
        [expr {[string first {0.45 * [winfo width $top]} $bp_width] >= 0}]] \
  [list 1 1 1 1]
check {BP07 browser_width grew an OPTIONAL want, so every old caller is unchanged} \
  [regexp -all {proc wviewer::browser_width \{token \{want \{\}\}\} \{} $wsrc] 1
set bp_wd [string first {[winfo reqwidth $f.wvsearch] -} $bp_width]
set bp_ww [string first {string is integer -strict $want} $bp_width]
set bp_wc [string first {0.45 * [winfo width $top]} $bp_width]
check {BP07 ...and want REPLACES the derived base, then takes the SAME cap} \
  [expr {$bp_wd >= 0 && $bp_ww > $bp_wd && $bp_wc > $bp_ww}] 1

# --- BP08: the missing twin writes THROUGH the widgets ----------------------
# `sbcase($w)` / `sballdb($w)` ARE the checkbuttons' -variable, so setting them
# is what a click does; everything else goes through the entry and the combos.
check {BP08 searchbar_set writes through the bar's own widgets} \
  [list [expr {[string first "\$w.pat delete 0 end" $bp_sbset] >= 0}] \
        [expr {[string first "\$w.pat insert 0" $bp_sbset] >= 0}] \
        [expr {[string first "\$w.syntax set" $bp_sbset] >= 0}] \
        [expr {[string first "\$w.type   set" $bp_sbset] >= 0}] \
        [expr {[string first "set sbcase(\$w)" $bp_sbset] >= 0}] \
        [expr {[string first "set sballdb(\$w)" $bp_sbset] >= 0}]] \
  [list 1 1 1 1 1 1]
check {BP08 ...and fires the one handler exactly once at the end} \
  [regexp -all {wviewer::searchbar_fire \$w} $bp_sbset] 1

# --- BP09: D-A, and the WH9j rule restated locally --------------------------
check {BP09 is_default EXCLUDES hist (divergence D-A)} \
  [regexp -all {dict remove \$d hist} $bp_isdef] 1
check {BP09 ...while the default value still CARRIES a hist field} \
  [regexp -all {hist } $bp_defb] 1
# test_wave_hilight.tcl WH9j greps snapshot's body for `wavehl` and wants 0.
# The deliberate exclusions (D4 highlights, undo/redo, the per-tab view cache)
# stay excluded — the PLAN's "do not fix that here".
check {BP09 no item-15 body serialises the wave-highlight set (WH9j, D4)} \
  [regexp -all {wavehl|undo_hist|redo_hist} \
     "$bp_snap$bp_state$bp_apply$bp_defb"] 0

# ============================================================================
# BP10-BP19 — ITEM 15, PURE arm, BOTH arms. No Tk, no xschem, no window.
# ============================================================================
set bp_def [wviewer::browser_state_default]

# ⚠⚠ RESTATED BY TWO-PANE ITEM 14, WHICH APPENDED THREE KEYS. `sash devint
# srccur` go on the END and nowhere else: `browser_state_is_default` is a
# whole-dict STRING compare, so an INSERTED key makes the default dict and the
# reader's build order disagree forever and the gate can never close again
# (BP41/BP42 and test_wave_modes.tcl MG9 all go red with a confusing diff). The
# append rule exists to make that mistake loud, and this is where it is loud.
check {BP10 browser_state_default's key list is the snapshot shape} \
  [dict keys $bp_def] \
  {shown width search filter dest open sel hist sash devint srccur}
# ⚠ THE SUB-DICT SHAPES MUST MATCH searchbar_get's OUTPUT EXACTLY, key order
# included — the equality test in is_default is a STRING compare, so a reordered
# default would make the gate permanently false and `browser` would be emitted
# for every window (i.e. MG9 red).
check {BP10 the SEARCH sub-dict carries item 14's conditional alldbs} \
  [dict get $bp_def search] {pattern {} syntax shell case 0 type all alldbs 0}
check {BP10 ...and the FILTER sub-dict does NOT (BAR11's 4-key contract)} \
  [dict get $bp_def filter] {pattern {} syntax shell case 0 type all}
# item 7 has no open-time seed: plot_dest answers `append` for an unseen token,
# so `append` IS the default and the default value must spell it.
check {BP10 the destination default is item 7's harmless policy} \
  [dict get $bp_def dest] append

check {BP11 is_default is 1 on the canonical default} \
  [pcall wviewer::browser_state_is_default $bp_def] 1
check {BP11 ...and 1 on {} (a window with no sidebar)} \
  [pcall wviewer::browser_state_is_default {}] 1
# THE MG9-STABILITY RULE (divergence D-A): the history is a GLOBAL disk-backed
# store, so counting it would make the snapshot's key set depend on the
# developer's home directory.
check {BP12 is_default stays 1 when ONLY hist differs (D-A)} \
  [pcall wviewer::browser_state_is_default \
     [dict replace $bp_def hist {/tmp/a.raw /tmp/b.raw}]] 1

# ...and 0 for every field that DOES count. One list, so a single field slipping
# out of the comparison is one visible element, not a silently passing check.
#
# ⚠⚠ RESTATED BY TWO-PANE ITEM 14: seven legs became TEN. ⚠ `srccur`'s
# NON-DEFAULT VALUE IS 0, NOT 1 — R11's two boxes have OPPOSITE defaults (device
# internals OFF, source currents ON), so `[dict replace $bp_def srccur 1]` would
# replace the default with itself, `is_default` would answer 1, and the leg would
# red on correct code. The asymmetry is the ruling, not a typo to be tidied.
#
# ⚠⚠ THE LAST THREE LEGS ARE `1`, AND THEY ARE THE ANTI-VACUITY LEGS — MEASURED
# ON THE RED RUN. A `dict replace` on a key the dict does not HAVE is an INSERT,
# so before item 14 existed the three `0` legs above were already green: they
# were reporting "the dict grew a key", not "the field counts". Replacing each
# field with its OWN DEFAULT must answer 1, which is only possible once the key
# is really in the default dict — so the six legs together say "this field is
# present, and it counts", which neither half says alone.
check {BP13 is_default is 0 for each field that counts, and 1 when that same field is at its default} \
  [list [pcall wviewer::browser_state_is_default [dict replace $bp_def shown 1]] \
        [pcall wviewer::browser_state_is_default [dict replace $bp_def width 260]] \
        [pcall wviewer::browser_state_is_default [dict replace $bp_def dest newstrip]] \
        [pcall wviewer::browser_state_is_default [dict replace $bp_def sel {s:v(out)}]] \
        [pcall wviewer::browser_state_is_default [dict replace $bp_def open {g:x1}]] \
        [pcall wviewer::browser_state_is_default \
           [dict replace $bp_def search \
              {pattern v* syntax shell case 0 type all alldbs 0}]] \
        [pcall wviewer::browser_state_is_default \
           [dict replace $bp_def filter \
              {pattern {} syntax regexp case 0 type all}]] \
        [pcall wviewer::browser_state_is_default [dict replace $bp_def sash 0.6]] \
        [pcall wviewer::browser_state_is_default [dict replace $bp_def devint 1]] \
        [pcall wviewer::browser_state_is_default [dict replace $bp_def srccur 0]] \
        [pcall wviewer::browser_state_is_default [dict replace $bp_def sash 0]] \
        [pcall wviewer::browser_state_is_default [dict replace $bp_def devint 0]] \
        [pcall wviewer::browser_state_is_default [dict replace $bp_def srccur 1]]] \
  [list 0 0 0 0 0 0 0 0 0 0 1 1 1]
# a torn state must be an ANSWER, never a throw (driver note (e))
check {BP14 is_default answers 0 on garbage rather than throwing} \
  [pcall wviewer::browser_state_is_default {this is not a dict at all}] 0

# --- BP15/BP16: the two label inverses --------------------------------------
# `sb_*_label [sb_*_code $x]` must be the identity on EVERY label the readonly
# comboboxes can hold — those are the only values searchbar_get can report.
set bp_rt {}
foreach l {Shell RegExp} {
  lappend bp_rt [wviewer::sb_syntax_label [wviewer::sb_syntax_code $l]]
}
foreach l {All Voltage Current Other} {
  lappend bp_rt [wviewer::sb_type_label [wviewer::sb_type_code $l]]
}
check {BP15 label/code are exact inverses on every combobox value} \
  $bp_rt {Shell RegExp All Voltage Current Other}
# a hand-edited state file must restore a USABLE bar, not throw
check {BP16 an unrecognised code falls back to the settled defaults} \
  [list [wviewer::sb_syntax_label posix] [wviewer::sb_type_label zz] \
        [wviewer::sb_syntax_label {}] [wviewer::sb_type_label {}]] \
  {Shell All Shell All}

# --- BP17: R4's closed arms, re-pinned locally -------------------------------
# test_ase_persist.tcl R4 owns these; restated here because item 15 restructured
# snapshot's open arm and a botched restructure would take the closed arm with
# it. `tokBP` is a token with no window in EITHER arm.
check {BP17 snapshot closed arm: no window + no prev -> {}} \
  [pcall wviewer::snapshot tokBP {}] {}
set bp_prev [dict create open 1 sharedx 0 rawfile {} graphs {} mode single target 0]
check {BP17 snapshot closed arm: no window + prev -> open flipped to 0} \
  [pcall wviewer::snapshot tokBP $bp_prev] [dict replace $bp_prev open 0]
check {BP17 ...and the closed arm adds NO browser key} \
  [dict exists [pcall wviewer::snapshot tokBP $bp_prev] browser] 0

# --- BP18/BP19: no window is an ANSWER, never a throw ------------------------
# The writer runs after a DESTROY, so "there is no window" and "there is no key"
# are ordinary inputs. `pcall` turns a throw into `ERR:...`, which is a DIFFERENT
# assertable value from {} and from 0 (driver note (e)).
check {BP18 the reader answers {} for a token with no window} \
  [pcall wviewer::browser_state tokBP] {}
check {BP18 the tree reader answers {} for a token with no window} \
  [pcall wviewer::browser_tree_state tokBP] {}
check {BP19 the writer answers 0 for an EMPTY dict (pre-item-15 back-compat)} \
  [pcall wviewer::browser_state_apply tokBP {}] 0
check {BP19 ...and 0 for a real dict on a token with no window} \
  [pcall wviewer::browser_state_apply tokBP $bp_def] 0
check {BP19 ...and the tree writer likewise} \
  [list [pcall wviewer::browser_tree_apply tokBP {}] \
        [pcall wviewer::browser_tree_apply tokBP {open {} sel {}}]] \
  [list 0 0]

# ============================================================================
# BP62-BP68 — TWO-PANE ITEM 14, PURE + SOURCE, BOTH ARMS.
#
# The item persists three fields the browser already had but threw away on every
# window build: the SASH fraction between the two panes and R11's two class
# checkboxes. Spec doc/claude/specs/waveform_signal_browser_two_pane.md §9 and
# R11; PLAN doc/claude/signal_browser_2pane_batch/PLAN.md two-pane item 14.
#
# ⚠⚠ THE ONE THING THAT MAKES THIS ITEM HARD IS ALSO THE ONE THING THAT MAKES IT
# SILENTLY GREEN, so it is asserted from three sides below. `browser_sash`'s READ
# arm is not a getter: it APPLIES the split and answers the LAYOUT default 0.55
# on a window nobody has ever touched. Read THAT from the state writer and the
# whole-dict compare in `browser_state_is_default` can never be true again —
# every viewer's snapshot grows a `browser` key, and MG9 (a file this batch does
# not own), BP41 and BP42 all go red at once. The cure is a SEPARATE pure reader
# whose answer is "nobody chose a split" (0), never the layout default; BP63 and
# BP67 are its source and behaviour halves and BP69 is its live one.
# ============================================================================
set bp_pref [wvproc_body $wsrc wviewer::browser_sash_pref]
set bp_drop [wvproc_body $wsrc wviewer::browser_sash_drop]

# ⚠ A `{NO-KEY}` READ, NOT `dict get` (driver note (e)): before the item lands
# the keys do not exist, and `dict get` would THROW past the check into the
# file's outer catch and delete every check after it.
check {BP62 (PURE) the three new defaults are R11's ASYMMETRIC pair plus a ZERO sash} \
  [list [wviewer::dget $bp_def sash   {NO-KEY}] \
        [wviewer::dget $bp_def devint {NO-KEY}] \
        [wviewer::dget $bp_def srccur {NO-KEY}]] \
  [list 0 0 1]

# THE SILENT-GREEN TWIN, ASSERTED IN THE SOURCE. Legs 2 and 3 are ZERO both
# before and after the item, so they carry NO evidence on their own — leg 1 is
# what makes the tuple mean something, which is why all three are ONE check.
check {BP63 (SOURCE) the reader takes the PREFERENCE, never the live split} \
  [list [regexp -all {wviewer::browser_sash_pref} $bp_state] \
        [regexp -all {sashpos} $bp_state] \
        [regexp -all {winfo height} $bp_state]] \
  [list 1 0 0]

# BP04's rule, extended to the three new fields: each goes through ITS OWNER's
# accessor exactly once, and the three `dict set` lines are in spec §9's order —
# which is load-bearing, because the string compare in `browser_state_is_default`
# tests this build order against `browser_state_default`'s.
check {BP64 (SOURCE) the three go through their OWN accessors, in spec §9's order} \
  [list [regexp -all {wviewer::browser_sash_pref} $bp_state] \
        [regexp -all {wviewer::browser_devint} $bp_state] \
        [regexp -all {wviewer::browser_srccur} $bp_state] \
        [bp_order3 $bp_state {dict set d sash} {dict set d devint} {dict set d srccur}]] \
  [list 1 1 1 ok]

# THE WRITER'S STEP ORDER, and it is forced rather than tidy: the two boxes are
# CLASS FILTERS, so restoring them AFTER `browser_show` would populate the tree
# and the sea once with the wrong set and once with the right one; the SASH can
# only be applied to a MAPPED panedwindow, which is what `browser_show`'s pack
# branch (and its `after idle` re-apply) produces, so it goes last.
check {BP65 (SOURCE) apply restores the boxes BEFORE browser_show and the sash AFTER the width} \
  [bp_order3 $bp_apply {wviewer::browser_devint} {wviewer::browser_show} \
                       {wviewer::browser_sash $token}] \
  ok

# §7.4 / divergence D-F. ⚠ LEG 4 ALONE IS VACUOUS — it is 0 on a writer that
# does nothing at all, which is exactly the pre-item state. Legs 1-3 are the
# positive evidence that the writer HAD three chances to log and took none.
check {BP66 (SOURCE, §7.4) apply writes all three DIRECTLY and reaches no logging path} \
  [list [regexp -all {wviewer::browser_devint} $bp_apply] \
        [regexp -all {wviewer::browser_srccur} $bp_apply] \
        [regexp -all {wviewer::browser_sash \$token} $bp_apply] \
        [regexp -all {log_action|browser_toggle|set_plot_dest} $bp_apply]] \
  [list 1 1 1 0]

# ⚠ LEG 1 IS THE ANTI-VACUITY LEG: `wvproc_body` answers {} for a proc that does
# not exist, and `regexp -all` over {} is 0 — so without it leg 2 is green before
# a line of the item is written. Leg 3 also pins that the reader is usable on a
# HIDDEN sidebar: BP57 snapshots one, and the accessor's `$h <= 1` guard would
# answer 0 there and silently drop a real preference.
check {BP67 (PURE) the preference reader exists, touches NO widget, and answers 0 for an unknown token} \
  [list [expr {$bp_pref ne {}}] \
        [regexp -all {winfo|sashpos|windows} $bp_pref] \
        [pcall ::wviewer::browser_sash_pref nosuchtok]] \
  [list 1 0 0]

# ⚠⚠ THE CHECK THAT PROVES THE FEATURE CAN EVER FIRE FOR A USER. Without a
# gesture writing the preference, item 14 ships a field nobody can set and every
# round trip below is a round trip of a constant. Leg 3 is the `break` ban, and
# it is MEASURED rather than stylistic: a ttk::panedwindow's bindtags are
# {<pw> TPanedwindow <top> all}, so the widget binding runs FIRST and ttk's own
# Release still has to run after it — `break` would kill sash dragging outright.
check {BP68 (SOURCE) the sash DROP is a real proc, bound on the panedwindow, and NOT break-ed} \
  [list [regexp -all {proc wviewer::browser_sash_drop } $wsrc] \
        [regexp -all {bind \$f\.pw <ButtonRelease-1>} $wsrc] \
        [regexp -all {ButtonRelease-1>[^\n]*break} $wsrc]] \
  [list 1 1 0]

# ⚠⚠ BP75 — ADDED BY THE ITEM'S VERIFICATION FIXUP, AND IT CLOSES A MEASURED
# COVERAGE HOLE, not a hypothetical one. The verifier SWAPPED the two fallback
# constants in `browser_state_apply` (`dget $d devint 0` -> 1 and
# `dget $d srccur 1` -> 0) and every suite in the batch stayed green: i1315 184,
# panes 81, modes 488, sea 79 — zero reds anywhere. That is not defensive
# padding being unreachable: `ase_window.tcl`'s Save State / Load State writes
# the session `viewer` dict, `browser` sub-dict included, to a FILE, so EVERY
# state file written before two-pane item 14 has no `devint`/`srccur` key and
# lands on exactly this branch. A swap would restore a legacy session with
# device internals ON and source currents OFF — inverted from R11, and silent.
# The reason the batch could not see it is stated in BP74's own comment and is
# the same shape: every behavioural round trip in this file supplies all three
# keys, so the key-ABSENT path was never exercised.
#
# THIS IS THE SOURCE HALF and it runs in BOTH arms; BP76 is the behavioural half
# and needs the real viewer. Both exist because either alone is weak: the source
# check cannot prove the constants are the ones the window lands on, and the
# behavioural one runs in one arm only.
#
# ⚠ IT EXTRACTS THE CONSTANTS AS VALUES rather than asserting two booleans, so a
# swap prints `1 0` against `0 1` and reads as the defect it is. Both start at
# `{NO-MATCH}`, which is what a deleted line or a renamed accessor produces —
# so the check cannot go green by failing to find anything.
set bp_fb_dev {NO-MATCH}
set bp_fb_src {NO-MATCH}
regexp {browser_devint \$token \[wviewer::dget \$d devint ([^\]]*)\]} $bp_apply -> bp_fb_dev
regexp {browser_srccur \$token \[wviewer::dget \$d srccur ([^\]]*)\]} $bp_apply -> bp_fb_src
check {BP75 (SOURCE, R11) a state file with NEITHER box key falls back to the
       ASYMMETRIC shipped pair, and to the SAME pair browser_state_default ships} \
  [list $bp_fb_dev $bp_fb_src \
        [wviewer::dget $bp_def devint {NO-KEY}] [wviewer::dget $bp_def srccur {NO-KEY}]] \
  [list 0 1 0 1]

# ============================================================================
# BR40-BR54 — the REAL VIEWER + REAL RAW FILES. `wviewer::open` on the sky130A
# ngspice_state1 fixture (item 8's BSV recipe verbatim) plus two hand-written
# three-point ASCII raws. NO DESIGN WINDOW — see the footprint note in the
# header.
# ============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
  set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
  set f [open [file join $scratch library.defs] w]
  puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
  puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
  puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
  close $f
  set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
  set ::library_registry_defs_only 1
  set ::XSCHEM_LIBRARY_PATH {}

  set brA [file normalize [file join $scratch br_a.raw]]
  set brB [file normalize [file join $scratch br_b.raw]]
  set brJ [file normalize [file join $scratch br_junk.txt]]
  set brN [file normalize [file join $scratch br_nonexistent.raw]]
  br_mkraw $brA {time v(out) v(in)} 3
  br_mkraw $brB {time v(zzz) v(qqq)} 3
  set f [open $brJ w] ; puts $f "this is not a raw file at all" ; close $f
  catch {file delete $brN}

  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check {BR40 (FIXTURE) wviewer::open returns 1} [pcall ::wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: BR4x group (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  set BVF $vtop.wvbrowser
  # ⚠ A NAMED FIXTURE CHECK, so a dead prologue FAILS A CHECK instead of
  # vanishing into a silent skip that scores green.
  check {BR40 (FIXTURE) the sidebar toggles on and the Location row is real} \
    [list [pcall ::wviewer::browser_toggle 1 $tok] [winfo exists $BVF.loc.cb] \
          [winfo exists $BVF.loc.br]] \
    [list 1 1 1]
  update

  # ⚠ POSITIVE CONTROL FOR THE WHOLE REAL-RAW GROUP. Everything below claims
  # something about loading these files; this proves the hand-written raws are
  # readable AT ALL before any of it. Without it, "the tree changed to B's
  # signals" and "neither file was ever a raw" are the same picture.
  wviewer::switch_ctx $tok
  check {BR41 (POSITIVE CONTROL) the hand-written raw A really reads} \
    [list [pcall xschem raw read $brA] [pcall xschem raw list]] \
    [list 1 "time\nv(out)\nv(in)"]

  # ⚠⚠ THE CONTROL FOR EVERY LOCATION-BAR ASSERTION BELOW, taken BEFORE the
  # first load: the bar is blank and carries NO balloon at all. Without it,
  # "the bar shows A" cannot be told from "the bar was showing A all along",
  # and "the balloon names A" cannot be told from a tooltip baked in at build
  # time — which is the exact bug BR08's grep exists to prevent and which only
  # these legs can actually observe.
  check {BR42 (CONTROL) before any load the bar is blank and has no balloon} \
    [list [$BVF.loc.cb get] [bind $BVF.loc.cb <Enter>]] [list {} {}]

  # a fresh window state: back to A through the product's own path
  check {BR42 rawbar_load A returns 1} [pcall ::wviewer::rawbar_load $tok $brA] 1
  wviewer::switch_ctx $tok
  check {BR42 ...and the ENGINE's current raw is A} [pcall xschem raw rawfile] $brA
  # ⚠⚠ THE WIDGET THE ITEM *IS*. rawbar_load's LAST act is `rawbar_sync`, and a
  # verifier deleted that single call with the whole suite staying green: the
  # engine still loaded, the tree still refreshed, and the Location bar simply
  # never followed. These two legs are what fails when it goes. Leg 2 reads the
  # BALLOON off the real <Enter> binding — `balloon` substitutes its string in
  # at bind time, so a full path present here is a full path in the tooltip,
  # which is the whole of the long-path Eyeball answer (the entry shows the tail
  # only).
  check {BR42 ...and the LOCATION BAR followed the load: it now reads A} \
    [$BVF.loc.cb get] $brA
  check {BR42 ...and the full-path balloon now names A} \
    [expr {[string first $brA [bind $BVF.loc.cb <Enter>]] >= 0}] 1
  # D6: the inventory the sidebar shows must be the raw that is loaded.
  check {BR43 ...and the browser inventory is A's signal set} \
    [lsort $::wviewer::browsersigs($tok)] [lsort {time v(out) v(in)}]

  # ⚠⚠ THE DISCRIMINATOR AGAINST A SHOW-ONCE SNAPSHOT (item 9's D6). With
  # `browser_refresh` missing from rawbar_load, B loads, the waveforms change
  # and the tree still lists A's signals — which is exactly sabotage (c).
  check {BR44 rawbar_load B returns 1 and the engine's raw is B} \
    [list [pcall ::wviewer::rawbar_load $tok $brB] \
          [br_rawfile $tok]] \
    [list 1 $brB]
  check {BR44 ...and the inventory FOLLOWED it to B's signal set} \
    [lsort $::wviewer::browsersigs($tok)] [lsort {time v(zzz) v(qqq)}]
  # ⚠ RE-ATTACHED, NOT ATTACHED ONCE. A balloon bound at build time would still
  # name A here; asserting B's presence AND A's absence is what makes this a
  # claim about re-attachment rather than about A ever having been there.
  check {BR44 ...and so did the bar and its balloon: B now, A gone} \
    [list [$BVF.loc.cb get] \
          [expr {[string first $brB [bind $BVF.loc.cb <Enter>]] >= 0}] \
          [expr {[string first $brA [bind $BVF.loc.cb <Enter>]] >= 0}]] \
    [list $brB 1 0]

  # THE TWO REFUSALS. Each asserts the SAME three legs, so "it refused" can
  # never be confused with "it wiped the window".
  check {BR45 a NONEXISTENT path is refused and changes nothing} \
    [list [pcall ::wviewer::rawbar_load $tok $brN] \
          [br_rawfile $tok] \
          [lsort $::wviewer::browsersigs($tok)]] \
    [list 0 $brB [lsort {time v(zzz) v(qqq)}]]
  # ⚠ A PLAIN TEXT FILE, NEVER A TRUNCATED `Values:` BLOCK — the latter SIGSEGVs
  # the engine (pre-existing C defect, see br_mkraw's note). This is the
  # engine-atomicity claim: a failed read leaves the previous raw current.
  check {BR46 a MALFORMED raw is refused and the previous raw survives} \
    [list [pcall ::wviewer::rawbar_load $tok $brJ] \
          [br_rawfile $tok] \
          [lsort $::wviewer::browsersigs($tok)]] \
    [list 0 $brB [lsort {time v(zzz) v(qqq)}]]
  # ⚠ AND THE BAR IS NOT REWRITTEN BY A REFUSAL — `rawbar_sync` is inside the
  # success path. A Location bar reading the path that FAILED, over waveforms
  # that are still B's, would be the widget lying about what is loaded.
  check {BR46 ...and the Location bar still names the raw that IS loaded} \
    [list [$BVF.loc.cb get] \
          [expr {[string first $brB [bind $BVF.loc.cb <Enter>]] >= 0}]] \
    [list $brB 1]
  check {BR47 the status line NAMES the failure instead of going silent} \
    [expr {[string first {could not read} [$BVF.ph cget -text]] >= 0 ||
           [string first {no such file} [$BVF.ph cget -text]] >= 0}] 1
  check {BR47 an EMPTY path is refused with its own message} \
    [list [pcall ::wviewer::rawbar_load $tok {}] \
          [expr {[string first {type the path} [$BVF.ph cget -text]] >= 0}]] \
    [list 0 1]

  # ==========================================================================
  # BR50-BR54 — ISSUE 0119. POSITIVE CONTROL FIRST (ruling 29, note (d)).
  # ==========================================================================
  set br_conf [file join $scratch conf]
  file mkdir $br_conf
  set br_store [file join $br_conf raw_history]
  set ::USER_CONF_DIR $br_conf
  set ::update_recent_files 1
  set ::wviewer::rawhist {}

  # THE GATE OPEN: an interactive load really appends AND really writes.
  # Asserted on the WORLD — the file exists and its SOURCED content names A —
  # never on "the command returned without throwing" (driver note (e)).
  check {BR50 (POSITIVE CONTROL) an UNGATED load appends to the history} \
    [list [pcall ::wviewer::rawbar_load $tok $brA] [wviewer::rawhist_get]] \
    [list 1 [list $brA]]
  check {BR50 ...and the store FILE now exists} [file exists $br_store] 1
  check {BR50 ...and SOURCING it yields a list headed by A} \
    [br_store_read $br_store] [list $brA]
  # ⚠ THE DROPDOWN IS THE DELIVERABLE, not the list variable. `-values` is set
  # at browser_build time and refreshed in ONE place — rawbar_sync — so with
  # that call gone the history would grow, be written, be restored, and the
  # user's dropdown would still be empty for the whole session.
  check {BR50 ...and the DROPDOWN now offers it} \
    [$BVF.loc.cb cget -values] [list $brA]

  check {BR51 a second ungated load rewrites the store, newest first} \
    [list [pcall ::wviewer::rawbar_load $tok $brB] [wviewer::rawhist_get]] \
    [list 1 [list $brB $brA]]
  check {BR51 ...and the file on disk says the same} \
    [br_store_read $br_store] [list $brB $brA]
  check {BR51 ...and the dropdown offers BOTH, newest first} \
    [$BVF.loc.cb cget -values] [list $brB $brA]

  # THE NEGATIVE CLAIM, now that its positive twin is proven on THIS fixture.
  set br_mem_pre [wviewer::rawhist_get]
  set br_fd [open $br_store r] ; set br_file_pre [read $br_fd] ; close $br_fd
  set ::update_recent_files 0
  set br_rc [pcall ::wviewer::rawbar_load $tok $brA]
  set br_fd [open $br_store r] ; set br_file_post [read $br_fd] ; close $br_fd
  # LEG 1 KILLS "the load never happened": the engine's current raw MOVED from
  # B back to A, so the gated call did everything except touch the history.
  check {BR52 a GATED (--script) load still LOADS the raw} \
    [list $br_rc [br_rawfile $tok]] [list 1 $brA]
  check {BR52 ...but the in-memory history is byte-identical} \
    [wviewer::rawhist_get] $br_mem_pre
  check {BR52 ...and the store file is byte-identical} \
    $br_file_post $br_file_pre
  # and the tree still followed the raw — the gate suppresses the HISTORY only
  check {BR52 ...while the inventory still followed the raw back to A} \
    [lsort $::wviewer::browsersigs($tok)] [lsort {time v(out) v(in)}]

  check {BR53 this --pipe --script process found the gate already CLOSED} \
    $br_gate0 0

  # TEARDOWN, AND ITS OWN CHECK: the user's real ~/.xschem/raw_history must be
  # exactly as this test found it. Issue 0119 is precisely a verification run
  # writing a user file.
  # ⚠ WHAT THIS LEG MAY NOT DO IS ASSERT A VALUE THE TEARDOWN JUST ASSIGNED —
  # `$::USER_CONF_DIR eq $br_conf0` two lines after setting it cannot fail and
  # measures nothing. The three legs below are all readings of the WORLD: the
  # user's store is exactly as this test found it (existence AND bytes), and
  # the writes it did make landed in the SCRATCH store — which is what stops
  # "nothing was ever written anywhere" from passing as "nothing was written to
  # the user's file".
  set br_home_post {}
  set br_home_now [file exists $br_home_file]
  if {$br_home_now} {
    set fd [open $br_home_file r] ; set br_home_post [read $fd] ; close $fd
  }
  set ::USER_CONF_DIR $br_conf0
  set ::update_recent_files $br_gate0
  set ::wviewer::rawhist {}
  check {BR54 (TEARDOWN) the user's real store is byte-for-byte as it was found} \
    [list $br_home_now $br_home_post] [list $br_home_pre $br_home_txt]
  check {BR54 ...while this run's writes DID land, in the scratch store} \
    [list [file exists $br_store] [expr {[file normalize $br_store] ne
                                         [file normalize $br_home_file]}]] \
    [list 1 1]

  catch {wviewer::close $tok}

  # ==========================================================================
  # BP40-BP61 — ITEM 15: snapshot -> DESTROY -> restore, on the REAL viewer.
  #
  # ⚠ THE FOOTPRINT AXIS RULING 30 WAS CUT ON, RE-MEASURED FOR THIS GROUP.
  # Item 13's claim (real viewer + small raws + NO DESIGN WINDOW) does NOT
  # transfer: this group adds DESTROY/RESTORE CYCLES, which nobody had measured.
  # It reuses item 13's ASE session and its raws, adds ONE more three-point
  # ASCII raw (hierarchical names, so there are GROUP rows to collapse), holds
  # at most ONE viewer at a time, and opens NO DESIGN WINDOW at any point.
  # Measured completion rate is recorded in receipts/15_receipt.md.
  #
  # ⚠ WHY DECISION 11's CLAUSE IS CHECKED THROUGH `browser_target_path` AND NOT
  # THROUGH A REAL DESCEND (BP55): `browser_descend_here` -> `browser_descend_to`
  # calls `ase::ui::design_window`, which OPENS THE DESIGN WINDOW — precisely
  # the "real viewer AND real design window at once" shape every pre-split death
  # landed in. `browser_target_path` is the exact value `browser_descend_to`
  # computes from `$tv selection` before it does anything else, so asserting on
  # it proves the restored selection is a LEGAL INPUT to that sync without
  # paying the footprint. Declared as a substitution, not renamed (ruling 23).
  # ==========================================================================

  # A raw with HIERARCHY: `v(x1.out)` -> node `g:x1`; `v(x1.x2.n1)` -> `g:x1.x2`;
  # `v(y3.q)` -> `g:y3`. After two-pane item 10 the LEAF rows (`s:...`) are not in
  # the tree at all — `browserrows($token)` still holds them (R6), the widget does
  # not — so every gesture in this block targets a NODE id.
  #
  # ⚠⚠ THE NON-DEFAULT PAIR IS INVERTED BY TWO-PANE ITEM 10, AND THE INVERSION IS
  # THE WHOLE POINT OF DRIVER NOTE (d). The tree used to be born ALL-OPEN with an
  # EMPTY selection, so a COLLAPSED group and any selection at all were the
  # departures. It is now born ALL-CLOSED (M11: only the design root opens) and
  # `browser_populate` never leaves the selection empty. So the genuinely
  # non-default values this block must set are the other way round:
  #   * an OPEN node                      -> `g:y3`, opened explicitly below;
  #   * a selection that is NOT the root  -> `g:x1.x2`.
  # A collapsed `g:x1` is now the DEFAULT and asserts nothing ON ITS OWN — it is
  # kept because BP54 needs an ancestor that `see` will try to re-open, and it is
  # always asserted PAIRED with the open node.
  #
  # ⚠ `g:y3` IS DELIBERATELY A NODE WITH NO CHILDREN after item 10 (its only child
  # was the leaf `v(y3.q)`), so carrying the open state on it also exercises the
  # node the deleted "rows with children" predicate would have dropped. That claim
  # is OWNED by BW52 in test_wave_sigbrowser_panes.tcl; here it is corroboration.
  #
  # ⚠⚠ THE All-DBs BOX GOES ON PART-WAY THROUGH THIS BLOCK, AND THE CHECKS EITHER
  # SIDE OF THAT LINE ASSERT DIFFERENT TREES:
  #   * BEFORE it (BP43's `browser_toggle 1`): the box is OFF — a fresh bar is
  #     built with `sballdb($w) 0` — so item 10 mints the design root `g:`,
  #     named `br_p` after the raw. That is what BP43 pins.
  #   * FROM the two `searchbar_fire` calls ON: the box is ON (BP49 needs
  #     `alldbs 1`, the field's only non-default value, so it cannot be turned
  #     off without making BP49 vacuous) and item 10 emits NO design root at all.
  # That second state is a DECLARED, ORDERED GAP owned by two-pane item 15 (spec
  # R7 / §4.3), asserted as a value by BP43a rather than suffered as five skipped
  # checks.
  set brP [file normalize [file join $scratch br_p.raw]]
  br_mkraw $brP {time v(x1.out) v(x1.x2.n1) v(y3.q)} 3

  check {BP40 (FIXTURE) a fresh viewer opens for the item-15 group} \
    [pcall ::wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: BP4x group (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  set BPF $vtop.wvbrowser
  set BPS $BPF.wvsearch
  set BPL $BPF.wvfilter
  set BPT $BPF.pw.tvf.tv
  check {BP40 (FIXTURE) the sidebar's two bars and its tree are real widgets} \
    [list [winfo exists $BPS] [winfo exists $BPL] [winfo exists $BPT]] \
    [list 1 1 1]

  # --- BP41: THE POSITIVE CONTROL FOR EVERY ROUND-TRIP BELOW ----------------
  # ⚠⚠ WITHOUT THIS CHECK THE WHOLE GROUP IS THE BD44/BD45 SHAPE (driver note
  # (d), ruling 29, caught four times in this batch). "It round-tripped" is
  # true of a field that NEVER CHANGED, whether or not snapshot/restore ever
  # touched it. This leg proves a FRESH window really is at the canonical
  # default, so every non-default set below is a real departure and every
  # value that comes back is a value the restore actually put there.
  set bs0 [pcall ::wviewer::browser_state $tok]
  check {BP41 (POSITIVE CONTROL) a FRESH window equals browser_state_default} \
    [pcall dict remove $bs0 hist] [dict remove $bp_def hist]
  check {BP41 ...so the gate calls it default} \
    [pcall ::wviewer::browser_state_is_default $bs0] 1

  # --- BP42: the LOCAL TWIN OF test_wave_modes.tcl MG9 ----------------------
  # If this ever disagrees with MG9, the gate is gone and every state file in
  # the wild grew a key. Sabotage (d) removes the gate and turns BOTH red.
  check {BP42 a default window's snapshot has MG9's exact key list, no browser} \
    [dict keys [pcall ::wviewer::snapshot $tok {}]] \
    {open sharedx rawfile graphs mode target}

  # --- BP43: SET THE NON-DEFAULTS AND PROVE THEY TOOK -----------------------
  # Two raws go into the engine registry (rawbar_load reads ADDITIVELY, BR05),
  # so the All-DBs box has something to find.
  check {BP43 (FIXTURE) both raws load and the hierarchical one is current} \
    [list [pcall ::wviewer::rawbar_load $tok $brA] \
          [pcall ::wviewer::rawbar_load $tok $brP] [br_rawfile $tok]] \
    [list 1 1 $brP]
  # ⚠ THE FULL SHAPE, BEFORE All-DBs IS TICKED: one design root named for the raw
  # (item 10 (C): basename without extension, `br_p`), the instance nodes hanging
  # off it, and the leaf row ABSENT — an assertable 0, never a dropped leg. The
  # root legs are here on purpose: they are what makes BP43a's `no-root` a
  # MEASURED CHANGE caused by ticking the box, not an unexplained void.
  # ⚠ EXPECTED IS BUILT WITH [list], NEVER A BRACED LITERAL: `[list g: 0]` has the
  # string rep `g: 0`; `{{g:} 0}` does not, and that over-bracing is an already
  # measured failure in this batch (see BW40's ⚠ in
  # test_wave_sigbrowser_panes.tcl).
  check {BP43 (FIXTURE) the sidebar shows: ONE design root, the instance nodes under it, and NO leaf row} \
    [list [pcall ::wviewer::browser_toggle 1 $tok] \
          [pcall $BPT exists {g:}] [pcall $BPT item {g:} -text] \
          [pcall $BPT parent g:x1] \
          [pcall $BPT exists g:x1] [pcall $BPT exists g:x1.x2] \
          [pcall $BPT exists g:y3] [pcall $BPT exists {s:v(x1.x2.n1)}]] \
    [list 1 1 br_p g: 1 1 1 0]
  update

  # the bars, driven the way a USER drives them: entry text, the two readonly
  # comboboxes, and the two checkbutton -variables (which ARE the widgets'
  # storage), then the ONE handler. `.*` matches everything, so the tree keeps
  # all of its groups and the collapse/selection claims stay reachable.
  foreach bp_w [list $BPS $BPL] {
    $bp_w.pat delete 0 end
    $bp_w.pat insert 0 {.*}
    $bp_w.syntax set RegExp
    $bp_w.type   set Voltage
    set ::wviewer::sbcase($bp_w) 1
  }
  set ::wviewer::sballdb($BPS) 1
  pcall ::wviewer::searchbar_fire $BPS
  pcall ::wviewer::searchbar_fire $BPL
  update
  # --- BP43a: THE GAP, CLOSED BY TWO-PANE ITEM 15 ---------------------------
  # ⚠⚠ FROM HERE ON THIS BLOCK RUNS WITH All-DBs TICKED (BP49 needs `alldbs 1`,
  # the field's only non-default value). Item 10 emitted NO design root in that
  # state and this check was its TOMBSTONE, asserting the gap as seven values:
  # `browser_root_id` answered {}, `browser_populate`'s R4 fallback could not
  # fire, and R4's "there is always exactly one node selected" DID NOT HOLD.
  #
  # TWO-PANE ITEM 15 (spec R7 / §4.3) CLOSES IT, and the check is INVERTED
  # rather than deleted: every DB — the current one included — now gets a
  # `d:<registry idx>` HEADER with its own design root beneath it. The CURRENT
  # DB's root and instance ids stay UNPREFIXED (§4.3's closing sentence), so
  # legs 2 and 5-7 keep their item-14 values and only legs 3-4 flip: the root id
  # goes `no-root` -> `g:` and the selection `none` -> `g:`.
  #
  # ⚠⚠ THE HEADER ID IS DERIVED FROM THE ENGINE, NOT FROM `browser_root_id` AND
  # NOT HARD-CODED. Which registry slot the current raw occupies depends on how
  # many raws this file's earlier groups already read into the same session, so a
  # literal `d:0` would be a guess. `signal_list_all`'s `cur` flag is an
  # INDEPENDENT source — the check does not read the proc it is testing — and
  # BP47b below re-derives it after the destroy/restore. It is MEASURED to MOVE
  # there (1 -> 0), which is precisely why the current DB's ROWS must not carry
  # it: BP52-BP55's persisted ids would otherwise name rows that no longer exist.
  # ⚠ LEG 1 IS THE PRECONDITION, through the PRODUCT's own reader: without it,
  # "the box is on and there is a root" and "the fire never ran" are only told
  # apart indirectly.
  # ⚠ THROUGH `signal_list_all`, WHICH CARRIES ITS OWN 0173 CONTEXT BRACKET, so
  # the index is read in the TOKEN's engine context and put back — a bare
  # `xschem raw info` here would report whichever context this file happens to
  # be sitting in. Answers -1 rather than throwing, and every check below then
  # names `d:-1|...` and reds by name.
  proc bp_curidx {tok} {
    set all {}
    if {[catch {wviewer::signal_list_all $tok} all]} { return -1 }
    foreach db $all {
      if {[wviewer::dget $db cur 0]} { return [wviewer::dget $db idx -1] }
    }
    return -1
  }
  set bp_cur [bp_curidx $tok]
  set bp_pfx "d:$bp_cur|"
  check {BP43a (THE GAP, CLOSED by two-pane item 15) with All-DBs ON every DB has its own header and its own design root, so R4's never-empty selection holds again} \
    [list [pcall ::wviewer::browser_alldbs $tok] \
          [pcall $BPT exists {g:}] [bp_rootid $tok] [bp_sel $BPT] \
          [pcall $BPT exists g:x1] [pcall $BPT exists g:x1.x2] \
          [pcall $BPT exists g:y3]] \
    [list 1 1 {g:} {g:} 1 1 1]
  # ⚠ BP43a's OWN NEGATIVE CONTROL, on the same tree, and it is what says the
  # current DB's ids did NOT move. Without it, legs 2 and 5-7 above are green
  # both under this design and under one that ALSO minted prefixed copies — and a
  # duplicated tree is exactly what a half-applied prefix looks like right up to
  # the point ttk throws. Leg 4 is the positive half: the current DB really does
  # sit under a header now, so "unprefixed" cannot be "R7 never ran".
  check {BP43a (ITS NEGATIVE CONTROL) no PREFIXED copy of the current DB exists — and its bare root really is a DB header's child} \
    [list [pcall $BPT exists "${bp_pfx}g:"] \
          [pcall $BPT exists "${bp_pfx}g:x1"] \
          [pcall $BPT exists "${bp_pfx}g:y3"] \
          [pcall $BPT parent {g:}]] \
    [list 0 0 0 "d:$bp_cur"]
  pcall ::wviewer::set_plot_dest newstrip $tok
  # TWO-PANE ITEM 14: the three persisted fields depart from their defaults HERE
  # so BP45's snapshot legs and the whole BP47+ restore group assert real
  # departures rather than constants. ⚠ ALL THREE, and `srccur` DOWN to 0 —
  # R11's defaults are asymmetric (0/1), so a fixture that set both boxes to 1
  # would leave `srccur` sitting on its default and half the round trip vacuous.
  # ⚠ SAFE, AND MEASURED: `brP`/`brA` are plain voltages with no device-classed
  # and no `srcbranch` names, so both boxes are BEHAVIOURAL NO-OPS on this
  # corpus — BP43a and BP47-BP56 keep their tree, sea and width values
  # byte-identically. The behavioural claim belongs to BW60-BW62 in
  # test_wave_sigbrowser_panes.tcl and is deliberately not re-litigated here.
  pcall ::wviewer::browser_devint $tok 1
  pcall ::wviewer::browser_srccur $tok 0
  pcall ::wviewer::browser_sash   $tok 0.35
  set bpw [pcall ::wviewer::browser_width $tok 260]
  # THE PRE CONTROL. Under item 10 the tree is born ALL-CLOSED with exactly one
  # exception, the design root (M11). TWO-PANE ITEM 15 makes that TWO under
  # All-DBs — the current DB's header AND its root — because the root R4 selects
  # would otherwise sit inside a collapsed header where nobody can see it, and
  # `browser_populate` may not call `see` (spec §4.2, BW53). NOTHING ELSE opens:
  # the foreign headers stay collapsed, which is what keeps "g:y3 is open" and
  # "the whole tree is open" different pictures.
  set bp_open0 [bs_open_set $BPT]
  # `g:x1` closed is now the DEFAULT, kept explicit because BP54 needs it stated;
  # `g:y3` OPEN and a NON-ROOT selection are the real departures (see the block
  # header). `g:x1.x2` is chosen so BP54 keeps an ancestor (`g:x1`) for `see` to
  # fight over and BP55 keeps its `{ok x1.x2}` byte-identical.
  # ⚠⚠ RE-KEYED BY TWO-PANE ITEM 15, AND THESE ARE POKES, NOT CHECKS — which is
  # exactly why they are dangerous. Through `pcall` a poke at an id that no
  # longer exists degrades to an `ERR:` STRING that nothing looks at, and
  # BP43-BP55 would then all assert an unset fixture while still failing for a
  # reason that reads like a persistence bug. BP43's legs below are what catch
  # a poke that silently missed.
  pcall $BPT item g:x1 -open 0
  pcall $BPT item g:y3 -open 1
  pcall $BPT selection set {g:x1.x2}
  update

  set bs1 [pcall ::wviewer::browser_state $tok]
  # ⚠ THE OPEN SET IS READ AS A SET, TWICE: once out of the state dict and once
  # off the widget, so "the reader agrees with the world" is part of the claim.
  # bs_open_set answers `no-tree` / `none` / the ids — never a count, which would
  # say "1" for both `{g:y3}` and `{g:x1}`, opposite states — and never an
  # [expr] over a pcall result, which is how the old `g:x1` leg went green on a
  # failed read.
  # ⚠ RESTATED BY TWO-PANE ITEM 14: the two class boxes and the sash join the
  # tuple, read back through the STATE DICT, so "the fixture set them" and "the
  # reader can see them" are one claim. `dget` with a `{NO-KEY}` sentinel, never
  # `dict get`, so an absent key is a value and not a throw.
  # ⚠ RESTATED BY TWO-PANE ITEM 15: leg 1 is no longer `none` (see the pre-control
  # comment above) and the sel/open ids carry the derived prefix. The open SET
  # legs now hold THREE ids — the two born open plus the poked `y3` — which is
  # strictly more evidence than `g:y3` alone: a populate that opened everything
  # and one that opened only what it should are still different values.
  check {BP43 the non-defaults TOOK: shown/dest/sel/open-set/boxes/sash read back live} \
    [list $bp_open0 \
          [pcall dict get $bs1 shown] [pcall dict get $bs1 dest] \
          [pcall dict get $bs1 sel] [pcall dict get $bs1 open] \
          [bs_open_set $BPT] \
          [wviewer::dget $bs1 devint {NO-KEY}] \
          [wviewer::dget $bs1 srccur {NO-KEY}] \
          [wviewer::dget $bs1 sash   {NO-KEY}]] \
    [list [list "d:$bp_cur" {g:}] 1 newstrip g:x1.x2 \
          [list "d:$bp_cur" {g:} {g:y3}] \
          [list "d:$bp_cur" {g:} {g:y3}] 1 0 0.35]
  check {BP43 ...and both bars read back exactly what was typed into them} \
    [list [pcall dict get $bs1 search] [pcall dict get $bs1 filter]] \
    [list {pattern .* syntax regexp case 1 type v alldbs 1} \
          {pattern .* syntax regexp case 1 type v}]
  # WM-INDEPENDENT: whatever browser_width clamped 260 to, the reader reports
  # THAT — so the persisted field is read from the widget the setter wrote.
  # (The pixel apply leg is BP56, and it is gated; see divergence D-B.)
  check {BP43 ...and the width the setter produced is the width the reader sees} \
    [list [pcall dict get $bs1 width] [expr {$bpw >= 240}]] [list $bpw 1]

  # --- BP44/BP45: the snapshot ----------------------------------------------
  set snap1 [pcall ::wviewer::snapshot $tok {}]
  check {BP44 a non-default browser makes the gate open} \
    [pcall ::wviewer::browser_state_is_default $bs1] 0
  check {BP44 ...so the snapshot's key list now ENDS with browser} \
    [lindex [dict keys $snap1] end] browser
  # ⚠ EVERY FIELD READ WITH A {NO-KEY} SENTINEL (driver note (e)): "the key is
  # absent" must be an ASSERTABLE VALUE, distinct from "present and empty" and
  # from "the widget is gone" — never an exception that deletes every check
  # after it.
  set bsnap [pcall dict get $snap1 browser]
  set bpg {}
  # ⚠ RESTATED BY TWO-PANE ITEM 14: eight sentinel reads became ELEVEN, and the
  # three new ones are read the same way for the same reason.
  foreach k {shown width search filter dest open sel hist sash devint srccur} {
    lappend bpg $k [wviewer::dget $bsnap $k {NO-KEY}]
  }
  # ⚠ `open` NOW ASSERTS ITS VALUE, NOT `present`. The `present` collapse is what
  # let an EMPTY open set through: two-pane item 10 turned the tree's default from
  # all-open to all-closed, the fixture's implicit "g:y3 is open" evaporated, and
  # this leg still printed `present`. The `NO-KEY` sentinel is unchanged — an
  # absent key reads `NO-KEY` and still reds — but a present-and-empty set now
  # reds too. `hist` keeps the present/NO-KEY shape: BP59 owns its value.
  check {BP45 every field made it into the snapshot dict} \
    [list [dict get $bpg shown] [dict get $bpg width] [dict get $bpg dest] \
          [dict get $bpg sel] [dict get $bpg search] [dict get $bpg filter] \
          [dict get $bpg open] \
          [expr {[dict get $bpg hist] eq {NO-KEY} ? {NO-KEY} : {present}}] \
          [dict get $bpg sash] [dict get $bpg devint] [dict get $bpg srccur]] \
    [list 1 $bpw newstrip g:x1.x2 \
          {pattern .* syntax regexp case 1 type v alldbs 1} \
          {pattern .* syntax regexp case 1 type v} \
          [list "d:$bp_cur" {g:} {g:y3}] present \
          0.35 1 0]

  # --- BP46: THE CONTROL FOR THE DESTROY ------------------------------------
  # ⚠ THE SECOND HALF OF THE ANTI-VACUITY PAIR. BP41 proved a fresh window is
  # default; this proves the DESTROY really resets THIS token — so when BP48+
  # find the non-defaults again, the restore is the only thing that can have
  # put them back.
  catch {wviewer::close $tok} ; update
  check {BP46 (CONTROL) the destroy really unregisters the window} \
    [list [pcall ::wviewer::browser_state $tok] \
          [info exists ::wviewer::browser($tok)]] \
    [list {} 0]
  check {BP46 (CONTROL) a re-opened window is back at the DEFAULT, not the state} \
    [pcall ::wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  viewer_ready $vtop
  set bs2 [pcall ::wviewer::browser_state $tok]
  check {BP46 ...every field of it} \
    [list [pcall ::wviewer::browser_state_is_default $bs2] \
          [pcall dict get $bs2 shown] [pcall dict get $bs2 dest] \
          [pcall dict get $bs2 sel] [pcall dict get $bs2 width]] \
    [list 1 0 append {} 0]
  catch {wviewer::close $tok} ; update

  # ==========================================================================
  # BP69-BP74 — TWO-PANE ITEM 14, the REAL VIEWER.
  #
  # ⚠ IT OPENS AND CLOSES ITS OWN WINDOW HERE, so BP47 below still starts from
  # exactly the closed token BP46 left behind. `$snap1` was taken above and
  # nothing in this block touches it.
  # ⚠ IT NEVER RE-SETS WHAT IT ASSERTS. Item 12 shipped a check whose helper
  # restored the values on the way out, so the check was about the helper and
  # survived the swap-the-defaults sabotage. Every value read below is read
  # BEFORE anything puts it back.
  # ==========================================================================
  check {BP69 (FIXTURE) a viewer opens for the item-14 group} \
    [pcall ::wviewer::open $tok] 1
  set vt14 [wviewer::window_for $tok]
  set BPF14 $vt14.wvbrowser
  set BPW14 $BPF14.pw
  viewer_ready $vt14
  pcall ::wviewer::browser_toggle 1 $tok
  update ; update idletasks
  set bp_frac0 [bs_wait_sash $BPW14]
  # ⚠⚠ LEG 2 IS THE ANTI-VACUITY LEG AND THE WHOLE POINT OF THE CHECK. `sash 0`
  # is ALSO what an unmapped, collapsed or broken pane reads, so leg 1 alone is
  # green on a build where nothing works. Leg 2 proves the widget really has a
  # live, non-zero split at this instant — so leg 1's 0 can only be "nobody
  # chose a split", which is the preference this item persists.
  # Leg 3 is the cross-file consequence: MG9 in test_wave_modes.tcl (a file this
  # batch does not own) is red the moment this stops being 1.
  # ⚠⚠ LEG 3 NAMES THE DEPARTING KEYS RATHER THAN ASKING FOR A BOOLEAN, and that
  # is the fix for two MEASURED wrong spellings of this leg rather than a style
  # preference. `browser_state_is_default` answers 0 both for "the sash leaked
  # into every window in the world" (the defect) and for "the sidebar is open,
  # which is what this check itself asked for" (the fixture) — the boolean
  # cannot tell them apart, and the first two spellings here were green-hunting
  # `dict replace` patches bolted on one measured surprise at a time. The key
  # list says exactly which fields moved, so a NEW departure is a NEW name and
  # is impossible to paper over. ALL FOUR NAMES BELOW WERE MEASURED, NOT
  # PREDICTED, and every one is a direct consequence of the toggle:
  #   shown  the toggle itself;
  #   width  `browser_show`'s pack branch runs `browser_width`, which writes a
  #          real pixel width where a hidden sidebar reports 0;
  #   sel    showing REPOPULATES, and item 10's R4 leaves exactly one node
  #          selected — the design root — where a hidden sidebar has no tree;
  #   open   `see` on that selection opens its ancestor chain.
  # Anything beyond those four — `sash`, `devint` or `srccur` above all — is the
  # defect this item exists to prevent. BP41 is the same claim on a sidebar that
  # was never shown at all, where the list is empty.
  check {BP69 (X) a FRESH window's sash reads 0 -- the preference, never the live split} \
    [list [wviewer::dget [pcall ::wviewer::browser_state $tok] sash {NO-KEY}] \
          [expr {[bs_num $bp_frac0] > 0.1}] \
          [bp_nondefault_keys [pcall ::wviewer::browser_state $tok]]] \
    [list 0 1 {shown width open sel}]

  # --- BP70: BP69's CONTROL, AND THE ONLY PROOF A USER CAN SET THIS ---------
  # A REAL press/drag/release on the sash, through the shipped binding. Without
  # it item 14 ships a preference nobody can reach and every round trip below is
  # a round trip of a constant that the test itself wrote.
  # ⚠ EXPLICITLY INCREASING `-time`: `event generate` stamps time 0, so two
  # presses at one spot collapse into a <Double-Button-1> (the 0152 lesson).
  set bp_py0 [bs_num [pcall $BPW14 sashpos 0]]
  set bp_py1 [expr {int($bp_py0) + 40}]
  catch {event generate $BPW14 <Button-1>        -x 5 -y [expr {int($bp_py0)}] -time 700000}
  catch {event generate $BPW14 <B1-Motion>       -x 5 -y $bp_py1 -time 700120}
  catch {event generate $BPW14 <ButtonRelease-1> -x 5 -y $bp_py1 -time 700240}
  update ; update idletasks
  set bp_frac1 [bs_wait_sash $BPW14]
  set bp_pref1 [bs_num [pcall ::wviewer::browser_sash_pref $tok]]
  set bp_read1 [bs_num [wviewer::dget [pcall ::wviewer::browser_state $tok] sash -1]]
  check {BP70 (X, BP69's CONTROL) a REAL sash drag moves the widget, writes the
         preference, and the reader then finds it} \
    [list [expr {[bs_num $bp_frac1] > [bs_num $bp_frac0] + 0.02}] \
          [expr {abs($bp_pref1 - [bs_num $bp_frac1]) < 0.03}] \
          [expr {abs($bp_read1 - [bs_num $bp_frac1]) < 0.03}]] \
    [list 1 1 1]

  # --- BP71: THE ROUND TRIP, ON NON-DEFAULT VALUES FOR ALL THREE -------------
  pcall ::wviewer::browser_devint $tok 1
  pcall ::wviewer::browser_srccur $tok 0
  pcall ::wviewer::browser_sash   $tok 0.35
  update ; update idletasks
  set bp_s14 [pcall ::wviewer::snapshot $tok {}]
  set bp_b14 [pcall dict get $bp_s14 browser]
  check {BP71 (PRE) all three departed from their defaults and rode into the snapshot} \
    [list [wviewer::dget $bp_b14 devint {NO-KEY}] \
          [wviewer::dget $bp_b14 srccur {NO-KEY}] \
          [wviewer::dget $bp_b14 sash   {NO-KEY}]] \
    [list 1 0 0.35]
  catch {wviewer::close $tok} ; update
  # THE OTHER HALF OF THE ANTI-VACUITY PAIR (BP41/BP46's shape): the destroy
  # really puts all three back at their defaults, so when they turn up again
  # after the restore the restore is the only thing that can have put them there.
  check {BP71 (CONTROL) the destroy really resets all three to their defaults} \
    [list [pcall ::wviewer::browser_devint $tok] \
          [pcall ::wviewer::browser_srccur $tok] \
          [pcall ::wviewer::browser_sash_pref $tok]] \
    [list 0 1 0]
  check {BP71 restore returns 1 and the viewer comes back up} \
    [pcall ::wviewer::restore $tok $bp_s14 $brP {}] 1
  set vt14 [wviewer::window_for $tok]
  set BPF14 $vt14.wvbrowser ; set BPW14 $BPF14.pw
  viewer_ready $vt14 ; update ; update idletasks
  set bp_st14 [pcall ::wviewer::browser_state $tok]
  check {BP71 (X) ROUND TRIP: all three came back, read off the RESTORED window} \
    [list [wviewer::dget $bp_st14 devint {NO-KEY}] \
          [wviewer::dget $bp_st14 srccur {NO-KEY}] \
          [wviewer::dget $bp_st14 sash   {NO-KEY}]] \
    [list 1 0 0.35]

  # --- BP72: A SHORTER WINDOW REPRODUCES THE FRACTION, NOT THE PIXEL ---------
  # ⚠⚠ MEASURED, AND IT IS WHY THIS CHECK HAS FOUR LEGS: ttk RE-PROPORTIONS the
  # sash on a resize ALL BY ITSELF (240/600 -> 90/300 with nothing helping it).
  # A two-leg "the fraction came back" check therefore goes green on the
  # widget's own arithmetic. Leg 1 is taken AFTER the window shrank and BEFORE
  # the apply and asserts the fraction is NOT yet the target, so a coincidence
  # is a visible value; leg 3 asserts the PIXEL really moved, which is what a
  # pixel-persisting implementation cannot do.
  set bp_h0  [bs_num [pcall winfo height $BPW14]]
  set bp_px0 [bs_num [pcall $BPW14 sashpos 0]]
  catch {wm geometry $vt14 520x340}
  update ; update idletasks ; after 150 ; update
  set bp_pre [bs_num [bs_wait_sash $BPW14]]
  pcall ::wviewer::browser_state_apply $tok [dict replace $bp_st14 sash 0.62]
  update ; update idletasks
  set bp_post [bs_num [bs_wait_sash $BPW14]]
  set bp_px1  [bs_num [pcall $BPW14 sashpos 0]]
  check {BP72 (X) restore into a SHORTER window reproduces the FRACTION, not the pixel} \
    [list [expr {abs($bp_pre  - 0.62) >= 0.03}] \
          [expr {abs($bp_post - 0.62) <  0.03}] \
          [expr {$bp_px1 != $bp_px0}] \
          [expr {[bs_num [pcall winfo height $BPW14]] < $bp_h0}]] \
    [list 1 1 1 1]

  # --- BP73: THE CROSS-FILE GUARD, LOCAL ------------------------------------
  # test_wave_modes.tcl MG18 is the twin in the file this batch does not own.
  # Three values, so "the key never appears" and "the key always appears" are
  # different pictures from "it appears exactly when a box is ticked".
  catch {wviewer::close $tok} ; update
  pcall ::wviewer::open $tok
  set vt14 [wviewer::window_for $tok]
  viewer_ready $vt14 ; update
  set bp_k0 [lsearch -exact [dict keys [pcall ::wviewer::snapshot $tok {}]] browser]
  pcall ::wviewer::browser_devint $tok 1
  set bp_k1 [lindex [dict keys [pcall ::wviewer::snapshot $tok {}]] end]
  pcall ::wviewer::browser_devint $tok 0
  set bp_k2 [lsearch -exact [dict keys [pcall ::wviewer::snapshot $tok {}]] browser]
  check {BP73 (X) a hidden all-default browser emits NO browser key; ONE ticked
         box makes it appear LAST; un-ticking takes it away again} \
    [list $bp_k0 $bp_k1 $bp_k2] [list -1 browser -1]

  # --- BP74: §7.4 / D-F, WITH A SPY THAT CAN COUNT --------------------------
  # ⚠⚠ A ZERO ONLY MEANS SOMETHING NEXT TO A LEG THAT MADE THE SPY TICK. Leg 1
  # alone is 0 on a writer that does nothing at all — which is the pre-item
  # state — so leg 2 asserts the writer DID apply all three (three chances to
  # log, none taken) and leg 4 fires a path that really does log.
  #
  # ⚠⚠ LEG 3 IS IDEMPOTENCE, AND IT WAS ADDED BECAUSE A SABOTAGE MEASURED A
  # HOLE. Restoring a checkbox by `$f.opt.dev invoke` — a RELATIVE toggle
  # instead of an absolute write — was caught only by this file's SOURCE checks
  # and by BW59: every behavioural round trip here happens to ask for the
  # OPPOSITE of the fresh window's default, so one flip lands on the right
  # answer by coincidence. Applying the SAME dict TWICE is where a toggle and a
  # write stop agreeing: a write is idempotent, a toggle flips back. It also
  # doubles the writer's chances to log, which leg 1 now covers for two applies.
  set ::bp_logn 0
  rename ::wviewer::log_action ::wviewer::__bp14_log
  proc ::wviewer::log_action {line} { incr ::bp_logn ; ::wviewer::__bp14_log $line }
  set bp_ln0 $::bp_logn
  set bp_d74 [dict replace $bp_st14 shown 1 devint 1 srccur 0 sash 0.42]
  pcall ::wviewer::browser_state_apply $tok $bp_d74
  update
  set bp_took [list [pcall ::wviewer::browser_devint $tok] \
                    [pcall ::wviewer::browser_srccur $tok] \
                    [pcall ::wviewer::browser_sash_pref $tok]]
  pcall ::wviewer::browser_state_apply $tok $bp_d74
  update
  set bp_again [list [pcall ::wviewer::browser_devint $tok] \
                     [pcall ::wviewer::browser_srccur $tok] \
                     [pcall ::wviewer::browser_sash_pref $tok]]
  set bp_ln1 $::bp_logn
  pcall ::wviewer::browser_toggle 0 $tok
  set bp_ln2 $::bp_logn
  rename ::wviewer::log_action {}
  rename ::wviewer::__bp14_log ::wviewer::log_action
  check {BP74 (X, §7.4) two full restores write NO log line, they really DID
         apply all three, the writer is ABSOLUTE and not a toggle, and the spy
         that says so CAN count} \
    [list [expr {$bp_ln1 - $bp_ln0}] $bp_took $bp_again [expr {$bp_ln2 - $bp_ln1}]] \
    [list 0 [list 1 0 0.42] [list 1 0 0.42] 1]
  catch {wviewer::close $tok} ; update

  # ==========================================================================
  # BP76/BP77 — TWO-PANE ITEM 14, THE VERIFICATION FIXUP. THE LEGACY-STATE AND
  # HIDDEN-SIDEBAR PATHS, BOTH OF WHICH WERE FULLY GREEN UNDER SABOTAGE.
  #
  # ⚠⚠ THESE TWO EXIST BECAUSE THE ITEM'S VERIFIER RAN TWO SABOTAGES THE ITEM
  # HAD NOT NAMED AND BOTH SURVIVED EVERY SUITE IN THE BATCH. They are recorded
  # here as measurements, not as prose:
  #   V1  swap the two fallbacks in `browser_state_apply` (`devint` 0 -> 1,
  #       `srccur` 1 -> 0)         -> i1315 184, panes 81, modes 488, sea 79.
  #                                   FOUR SUITES, ZERO REDS.
  #   V2  move `set browsersash($token) $want` in the sash accessor from BEFORE
  #       its `$h <= 1` guard to AFTER it, so a restore into a never-shown
  #       sidebar DROPS the preference
  #                                -> i1315 184, panes 81, sea 79. ZERO REDS.
  # BOTH are live user paths, not defensive code (see each check).
  #
  # ⚠ WHY THE WHOLE BLOCK USES A SIDEBAR THAT WAS NEVER SHOWN. That is the
  # condition both defects need, and it is a condition BP69-BP74 never produce:
  # BP69 toggles the sidebar ON as its very first act and every later restore
  # in that group lands on a window whose pane is already mapped. A fresh
  # viewer's `$f.wvbrowser` is BUILT but never `pack`ed, so `winfo height` on
  # its panedwindow is 1 and the accessor's guard is genuinely taken — asserted,
  # not assumed, by BP77's second leg.
  # ⚠ IT OPENS AND CLOSES ITS OWN WINDOW, like the BP69 group, so BP47 below
  # still starts from the closed token BP46 left behind.
  # ==========================================================================
  check {BP76 (FIXTURE) a viewer opens for the fixup group, with its sidebar
         BUILT but never shown} \
    [list [pcall ::wviewer::open $tok] \
          [bs_packed [wviewer::window_for $tok].wvbrowser] \
          [expr {[winfo exists [wviewer::window_for $tok].wvbrowser.pw] ? 1 : 0}]] \
    [list 1 0 1]
  set vt76 [wviewer::window_for $tok]
  set BPF76 $vt76.wvbrowser
  set BPW76 $BPF76.pw
  viewer_ready $vt76 ; update ; update idletasks

  # --- BP76: THE LEGACY STATE FILE ------------------------------------------
  # ⚠⚠ THE PATH IS LIVE AND THAT IS THE POINT. `ase_window.tcl`'s Save State /
  # Load State writes the session `viewer` dict — `browser` sub-dict and all —
  # to a FILE, so every state file written before two-pane item 14 has a
  # `browser` dict with NO `devint`, NO `srccur` and NO `sash`, and loading one
  # runs exactly the branch V1 mutated. R11's pair is ASYMMETRIC, so a legacy
  # session restored through a swapped fallback comes back with device
  # internals ON and source currents OFF and nothing says so.
  #
  # ⚠⚠ THE WINDOW IS FIRST DRIVEN TO THE OPPOSITE PAIR, WHICH IS WHAT MAKES THE
  # CHECK MEAN ANYTHING. Leg 1 asserts it really got there, so the `{0 1}` in
  # leg 3 cannot be "the window was already like that" and cannot be "the
  # writer did nothing" — both of those read `{1 0}` and are red. This is the
  # anti-vacuity shape BP41/BP46 and BP71 use, one layer in.
  # ⚠ NOTHING BELOW PUTS THE VALUES BACK before they are read (item 12's lesson:
  # a check that reads its own helper's restore is a check about the helper).
  pcall ::wviewer::browser_devint $tok 1
  pcall ::wviewer::browser_srccur $tok 0
  update
  set bp_pre76 [list [pcall ::wviewer::browser_devint $tok] \
                     [pcall ::wviewer::browser_srccur $tok]]
  set bp_leg76 [dict remove [pcall ::wviewer::browser_state $tok] devint srccur sash]
  set bp_has76 [list [expr {[dict exists $bp_leg76 devint] ? 1 : 0}] \
                     [expr {[dict exists $bp_leg76 srccur] ? 1 : 0}] \
                     [expr {[dict exists $bp_leg76 sash]   ? 1 : 0}]]
  pcall ::wviewer::browser_state_apply $tok $bp_leg76
  update ; update idletasks
  check {BP76 (X) a PRE-ITEM state dict — no devint, no srccur, no sash — restores
         a window that was driven to the OPPOSITE pair back onto R11's ASYMMETRIC
         shipped defaults} \
    [list $bp_pre76 $bp_has76 \
          [list [pcall ::wviewer::browser_devint $tok] \
                [pcall ::wviewer::browser_srccur $tok]]] \
    [list {1 0} {0 0 0} {0 1}]

  # --- BP77: A RESTORE INTO A SIDEBAR THAT WAS NEVER SHOWN ------------------
  # The declared design: `browser_state_apply` hands the sash to the accessor
  # UNCONDITIONALLY, outside the `$shown` arm, and the accessor STORES `$want`
  # BEFORE its own height guard. So "a snapshot taken with the browser closed"
  # keeps the split the user chose; the apply itself is a no-op and the show's
  # pack branch (plus its `after idle` re-apply) puts it in place the moment the
  # sidebar opens. V2 moved that store after the guard — the rejected
  # alternative, in which the preference is silently dropped — and three suites
  # could not tell the two apart.
  #
  # FOUR LEGS, AND EACH ONE KILLS A DIFFERENT WAY OF BEING GREEN:
  #   1  the preference was 0 BEFORE the apply, so the 0.44 below can only have
  #      come from the apply (this window has never been dragged and BP70's
  #      drag was on a different, since-closed window);
  #   2  the pane really was UNMAPPED at apply time — `winfo height` <= 1. This
  #      is the leg that proves the guard was taken; without it the whole check
  #      could be running on a mapped pane and testing nothing new;
  #   3  the preference is held ANYWAY. This is V2's oracle: with the store
  #      after the guard this reads 0;
  #   4  THE PAYOFF, and the leg a user would notice: open the sidebar and the
  #      split lands on the restored 0.44, not on the 0.55 LAYOUT DEFAULT. 0.44
  #      is chosen far from both 0.55 and BP74's 0.42 so no earlier value can
  #      impersonate it.
  set bp_pref77a [bs_num [pcall ::wviewer::browser_sash_pref $tok]]
  set bp_h77 [bs_num [pcall winfo height $BPW76]]
  pcall ::wviewer::browser_state_apply $tok [dict replace $bp_leg76 shown 0 sash 0.44]
  update ; update idletasks
  set bp_pref77b [bs_num [pcall ::wviewer::browser_sash_pref $tok]]
  pcall ::wviewer::browser_toggle 1 $tok
  update ; update idletasks
  set bp_frac77 [bs_num [bs_wait_sash $BPW76]]
  check {BP77 (X) a restore into a NEVER-SHOWN sidebar cannot APPLY the sash but
         STORES it anyway, and opening the sidebar then lands on the restored
         split instead of the layout default} \
    [list $bp_pref77a \
          [expr {$bp_h77 >= 0 && $bp_h77 <= 1}] \
          $bp_pref77b \
          [expr {abs($bp_frac77 - 0.44) < 0.03}]] \
    [list 0 1 0.44 1]

  # --- BP78: THE STORE GUARD ITSELF (TWO-PANE item 19) ----------------------
  # ⚠⚠ THE HOLE TWO-PANE ITEM 14 SHIPPED WITH, AND THE REASON THAT ITEM IS `[F]`
  # RATHER THAN `[x]`. `browser_sash`'s store arm is guarded
  # `$want > 0 && $want < 1` (`src/wave_viewer.tcl`), and `browser_sash_pref`'s
  # own header cites that lower bound BY NAME as the reason the sea suite's
  # capture/restore is safe and the restore needs no gate of its own. NOTHING
  # MEASURED IT: relaxing `> 0` to `>= 0` stores a 0, `$frac` becomes 0,
  # `sashpos 0 0` collapses the tree pane to nothing — and every suite in both
  # arms stayed green. `browser_sash_drop` cannot produce a 0 (it guards
  # `$frac <= 0` itself), so no other check can reach this.
  #
  # ⚠ IT RUNS HERE, ON BP76/BP77's FIXTURE, BECAUSE THE PANE MUST BE MAPPED —
  # an unmapped pane answers 0 for everything and every leg below goes green on
  # a build where nothing works. Leg 2 asserts the mapping rather than assuming
  # it, exactly as BP69 leg 2 and BP77 leg 2 do.
  #
  # ⚠ IT NEVER READS A VALUE ITS OWN RESTORE PUT BACK. Every leg is asserted
  # BEFORE the fraction is restored on the last line of the block, and the
  # restore is to BP77's OWN 0.44 — so what BP47 and everything after it inherit
  # is byte-identical to what BP77 left. (Restoring is not optional: `sash 0.30`
  # would otherwise leak into the rest of the file through `browsersash`, which
  # survives a window close.)
  set bp_pref78a [bs_num [pcall ::wviewer::browser_sash_pref $tok]]
  set bp_h78     [bs_num [pcall winfo height $BPW76]]
  set bp_r78z    [bs_num [pcall ::wviewer::browser_sash $tok 0]]
  update ; update idletasks
  set bp_pref78z [bs_num [pcall ::wviewer::browser_sash_pref $tok]]
  set bp_frac78z [bs_num [bs_wait_sash $BPW76]]
  # THE POSITIVE CONTROL, on the same fixture and the same proc: a LEGAL value
  # in the same call really is taken and really does move the widget. Without it
  # "0 was refused" is also what a dead accessor answers.
  pcall ::wviewer::browser_sash $tok 0.30
  update ; update idletasks
  set bp_pref78p [bs_num [pcall ::wviewer::browser_sash_pref $tok]]
  set bp_frac78p [bs_num [bs_wait_sash $BPW76]]
  check {BP78 (X) `sash 0` is REFUSED by the store guard — the preference and
         the live split are both untouched — while a legal value in the same
         call is taken and moves the pane} \
    [list [expr {abs($bp_pref78a - 0.44) < 0.03}] \
          [expr {$bp_h78 > 1}] \
          [expr {abs($bp_r78z - $bp_pref78a) < 0.03}] \
          [expr {abs($bp_pref78z - $bp_pref78a) < 0.03}] \
          [expr {$bp_frac78z > 0.05 && $bp_frac78z < 0.95}] \
          [expr {abs($bp_pref78p - 0.30) < 0.03}] \
          [expr {abs($bp_frac78p - 0.30) < 0.03}]] \
    [list 1 1 1 1 1 1 1]
  pcall ::wviewer::browser_sash $tok $bp_pref78a
  update ; update idletasks

  catch {wviewer::close $tok} ; update

  # --- BP47-BP56: THE RESTORE ------------------------------------------------
  check {BP47 restore returns 1 and the viewer comes back up} \
    [pcall ::wviewer::restore $tok $snap1 $brP {}] 1
  set vtop [wviewer::window_for $tok]
  set BPF $vtop.wvbrowser ; set BPS $BPF.wvsearch
  set BPL $BPF.wvfilter   ; set BPT $BPF.pw.tvf.tv
  check {BP47 ...on a mapped canvas} [viewer_ready $vtop] 1
  update

  # ⚠⚠ THIS IS THE MEASUREMENT THAT DECIDED TWO-PANE ITEM 15's ID SCHEME, AND IT
  # IS ASSERTED HERE SO NOBODY CAN UNDO THE RULING WITHOUT SEEING IT FAIL.
  # `browser_tree_state` persists sel/open as RAW IDS. PLAN item 15 asks for the
  # current DB's rows to be prefixed with `d:<its registry index>|` — and that
  # index is a property of the ENGINE REGISTRY, not of the design. MEASURED
  # RIGHT HERE: the fixture snapshotted with TWO raws loaded, where the current
  # one is slot 1; `restore` brings back ONE, where it is slot 0. Under the
  # PLAN's scheme every persisted `d:1|g:x1.x2` would name a row that no longer
  # exists, and the user's selection and open set would silently evaporate —
  # BP52, BP53, BP54 and BP55 would all go red with no defect in the persistence
  # code at all. Spec §4.3's "the current DB is ... unprefixed" is what avoids
  # it, and legs 3-4 are the proof that it did: the SAME bare ids the snapshot
  # recorded are still in the tree on the other side of a registry renumber.
  # ⚠ LEGS 1-2 ARE PINNED LITERALS, NOT `$bp_cur`-RELATIVE. A check that only
  # said "they are equal" would go green precisely when the drift stopped
  # happening, which is when this check has nothing left to say.
  set bp_cur2 [bp_curidx $tok]
  check {BP47b (ITEM 15's ID-SCHEME CONTROL) the current DB's REGISTRY SLOT really does move across a snapshot/restore — and the persisted UNPREFIXED ids survive it anyway} \
    [list $bp_cur $bp_cur2 \
          [pcall $BPT exists {g:}] [pcall $BPT exists g:x1.x2]] \
    [list 1 0 1 1]

  # THE WIDGET-STATE MASQUERADE ANSWER: "hidden" and "destroyed" both read 0
  # from bs_packed, so the pair is always asserted together.
  check {BP48 the sidebar came back SHOWN (packed, and really there)} \
    [list [pcall ::wviewer::browser_shown $tok] [bs_packed $BPF] \
          [winfo exists $BPF]] \
    [list 1 1 1]

  set bs3 [pcall ::wviewer::browser_state $tok]
  check {BP49 the SEARCH bar round-tripped, All-DBs included} \
    [list [pcall dict get $bs3 search] [pcall $BPS.pat get] \
          [pcall $BPS.syntax get] [pcall $BPS.type get]] \
    [list {pattern .* syntax regexp case 1 type v alldbs 1} {.*} RegExp Voltage]
  # item 14's CONDITIONAL-KEY contract, locally re-pinned: the Filter bar was
  # built without -alldbs, so it must carry NO alldbs key at all — not `0`.
  check {BP50 the FILTER bar round-tripped and grew NO alldbs key} \
    [list [pcall dict get $bs3 filter] [dict exists [pcall dict get $bs3 filter] alldbs]] \
    [list {pattern .* syntax regexp case 1 type v} 0]
  check {BP51 the plot destination round-tripped (ruling 24's accessor)} \
    [pcall ::wviewer::plot_dest $tok] newstrip
  # ⚠ THE SELECTION IS READ THROUGH bp_sel, so "the widget is gone", "nothing is
  # selected" and "this id is selected" are three distinguishable answers — a bare
  # [$BPT selection] makes the first two both read {}. Leg 2 states item 10's fact
  # at the RESTORE end: the leaf id is an ASSERTABLE ABSENCE, not a row that
  # merely failed to be selected.
  # ⚠ RE-KEYED BY TWO-PANE ITEM 15 (R7): the node id carries the current DB's
  # `d:<idx>|` prefix. Leg 2 is untouched — a LEAF id is an assertable absence
  # under BOTH spellings, so an unprefixed leaf cannot sneak back in either.
  check {BP52 the tree SELECTION round-tripped, onto a NODE id} \
    [list [bp_sel $BPT] [pcall $BPT exists {s:v(x1.x2.n1)}] \
          [pcall $BPT exists "${bp_pfx}g:x1.x2"]] \
    [list g:x1.x2 0 0]

  # --- BP53/BP54: the expanded set, and the ORDERING finding ----------------
  # BOTH LEGS, so "everything collapsed" and "everything open" are different
  # answers: the collapsed group and an open sibling are asserted together.
  # BOTH LEGS PLUS THE WHOLE SET, so three worlds are three values:
  #   {0 1 g:y3}                       the restore worked
  #   {0 0 none}                       nothing was restored (item 10's default)
  #   {1 1 {g:x1 g:x1.x2 g:y3}}        everything was opened
  # ⚠ `g:y3` IS CHILDLESS after item 10 (its only child was the leaf `v(y3.q)`),
  # so this also exercises the node the deleted "rows with children" predicate
  # would have dropped from `browser_tree_nodes`. That claim's OWNER is BW52 in
  # test_wave_sigbrowser_panes.tcl, which asserts the node list directly; here it
  # is corroboration from the persistence end, not the only coverage.
  # ⚠ RESTATED BY TWO-PANE ITEM 15, AND THE THREE-WORLD TABLE ABOVE GAINS ONE
  # MEMBER: the restored open set now also carries the current DB's design root
  # `g:`, which the populate opens because it is newly born (M11 / spec §4.2's
  # visibility rule) and which the persisted set then confirms. The
  # DISCRIMINATING legs are unchanged — a collapsed `x1` beside an open `y3`.
  #
  # ⚠⚠ THE DB HEADER IS **NOT** IN THIS SET, AND THAT IS A DECLARED LIMIT
  # MEASURED HERE RATHER THAN REASONED ABOUT. `browser_populate` inserts it open
  # (it is newly born and it is the root's parent), but `browser_tree_apply`
  # then applies the PERSISTED set and §4.2 rules that the persisted set WINS —
  # and the persisted set named `d:1`, the slot the current DB occupied when the
  # snapshot was taken. BP47b measures that slot moving to 0 across this very
  # restore, so `d:1` matches nothing and `d:0` is closed by the apply pass.
  # CONSEQUENCE, STATED: after a restore that renumbers the registry, the current
  # DB's header comes back COLLAPSED, so the restored selection is scrolled out
  # of sight until the user expands it. It is the LAST piece of state item 15's
  # unprefixed ids could not make index-independent — the header id is the one id
  # that must carry the index — and it is one click, not lost work. Fixing it
  # would mean either overriding §4.2 or teaching persistence about DB identity;
  # both are larger than R7 and neither is item 15's.
  check {BP53 the COLLAPSE round-tripped, while a sibling node stayed OPEN} \
    [list [pcall $BPT item g:x1 -open] [pcall $BPT item g:y3 -open] \
          [bs_open_set $BPT] \
          [pcall $BPT item "d:$bp_cur2" -open]] \
    [list 0 1 [list {g:} {g:y3}] 0]
  # ⚠ THE NON-OBVIOUS ORDERING CLAIM. `$tv see` force-opens EVERY ANCESTOR of
  # the node it scrolls to (browser_reveal's central finding), so revealing the
  # selection AFTER applying the collapse would silently re-expand exactly the
  # group the user collapsed. The selected leaf lives under `g:x1`; if g:x1 is
  # open here, the open-set was applied too early. Sabotage (c) is this.
  # BEFORE two-pane item 10 the tree was born ALL-OPEN, so a single `g:x1 == 0`
  # was self-evidently a departure. IT IS NOT ANY MORE — closed is the default —
  # so the claim is now made as a PAIR on the same tree:
  #   leg 1  the SELECTION ALONE (no `open` key -> browser_tree_apply's open pass
  #          is skipped): `see` on its own really does open `g:x1`     -> 1
  #   leg 2  the SAME selection WITH the persisted open set: the open pass ran
  #          after `see` and won                                       -> 0
  #   leg 3  the selection survived both applies
  # bp_order_probe RESTORES the post-restore state as its last act, so BP55 below
  # still reads the RESTORED selection.
  #
  # ⚠⚠ THIS CHECK'S PREDECESSOR COMMENT SAID "TWO-PANE ITEM 13 REDS THIS CHECK
  # BY DESIGN" — IT DOES NOT, AND THE CORRECTION IS THE RECORD OF A REFUSED PLAN
  # CLAUSE. PLAN item 13 asks `browser_tree_apply` to union the SELECTION's
  # ancestor chain into the applied open set, which would make `see`'s effect and
  # the open pass's effect coincide on that chain and red leg 2 below. Item 13
  # REFUSED the union, because spec §4.2 forbids it in so many words:
  #     "the persisted `open` set must beat it — BP54 already pins that a
  #      persisted collapse beats `see`'s ancestor-expansion, and that check
  #      stays green."
  # So this check is UNCHANGED and stays green, and the union is now a SABOTAGE
  # rather than a plan: injecting it reds leg 2 here, BP53 above, and BW76 in
  # test_wave_sigbrowser_panes.tcl — three files triangulating one proc.
  # ⚠ THE NUMBERS PLAN GIVES ITEM 13 (BW53/BW54/BW55) ARE ALREADY SPENT BY ITEM
  # 10 — BW53 is "(SOURCE) the populate path never calls see". Item 13 re-banded
  # onto BW15 + BW68-BW76; BW76 is the standing twin of this check.
  # ⚠ RE-KEYED BY TWO-PANE ITEM 15: the probe's three ids carry the prefix. The
  # ORDERING claim and its three expected values are byte-identical, which is the
  # record that item 15 moved the ids and nothing else about §4.2's ordering.
  check {BP54 the persisted collapse BEATS see's ancestor-expansion} \
    [bp_order_probe $tok $BPT g:x1 {g:x1.x2} {g:y3}] \
    [list 1 0 g:x1.x2]

  # --- BP55: SETTLED DECISION 11 --------------------------------------------
  # "A restored selection must be a LEGAL INPUT to item 12's sync, not just a
  # string that looks right." `browser_descend_here` does `$tv selection` then
  # `browser_descend_to $token $sel`, whose very first act is
  # `browser_target_path $token $sel`. That value is the gate, and it is what is
  # asserted here (see the group header for why the real descend is not driven).
  # ⚠ LEG 1 NAMES THE SELECTION THE ANSWER CAME FROM. Without it, `{ok x1.x2}`
  # and "some other selection happened to resolve" are the same picture — and the
  # id itself is now the load-bearing half: two-pane item 10 took the LEAF row out
  # of the tree, so decision 11's clause is only expressible on a NODE id, and
  # `g:x1.x2` is a group whose id IS the dotted path (settled decision 14), which
  # is why the expected value is byte-identical to the pre-item-10 one.
  # ⚠ RE-KEYED BY TWO-PANE ITEM 15, AND LEG 2 IS BYTE-IDENTICAL ON PURPOSE:
  # `browser_id_path` strips the `d:N|` prefix before decoding, so a prefixed
  # node id resolves to the SAME dotted path. That is what let item 15 leave
  # `browser_target_path` unedited, and this is where it is measured rather than
  # asserted in a receipt.
  check {BP55 the RESTORED selection resolves to a hierarchy path (decision 11)} \
    [list [bp_sel $BPT] \
          [pcall ::wviewer::browser_target_path $tok [pcall $BPT selection]]] \
    [list g:x1.x2 {ok x1.x2}]
  # the NEGATIVE control on the same fixture: an empty selection is the refusal,
  # so "ok x1.x2" cannot be what this proc says about anything.
  check {BP55 (CONTROL) an EMPTY selection is refused by the same gate} \
    [lindex [pcall ::wviewer::browser_target_path $tok {}] 0] err

  # --- BP56: the width, and the ONE inherited flake adjacent to this item ----
  # `browser_width` computes from the toplevel the WM has actually applied; at
  # top=400 the 45% cap loses to the 240 floor and a restored 260 and a derived
  # 480 both collapse to 240 (BT45's mechanism, ~1-in-6). The LOAD-BEARING legs
  # are BP43/BP45 at the DICT level, which are WM-independent. The PIXEL leg is
  # gated and prints a visible SKIPPED line rather than flapping (divergence
  # D-B: the dict field round-trips exactly, the pixels do not when the window
  # changed size).
  set bpwid [bs_wait_widths $vtop $BPF $vtop.drw]
  if {[lindex $bpwid 3] eq {settled} && [lindex $bpwid 0] >= 600} {
    check {BP56 the restored width was really applied to the frame} \
      [list [pcall $BPF cget -width] [pcall dict get $bs3 width]] [list $bpw $bpw]
  } else {
    puts "SKIPPED: BP56 pixel width leg (toplevel [lindex $bpwid 0] px, [lindex $bpwid 3])"
  }

  # --- BP57: THE PLAN'S SECOND NAMED ASSERTION, DE-VACUUMED -----------------
  # ⚠⚠ "a snapshot taken with the sidebar HIDDEN restores hidden" is the purest
  # form of the vacuous check (ruling 29): a fresh window is BORN hidden, so
  # `browser_shown == 0` is true whether or not the restore did anything. Two
  # things stop it being vacuous here:
  #   * BP48 above is the PROVEN POSITIVE CONTROL on the same code path — a
  #     restore really CAN show the sidebar, so `shown 0` is a choice, and
  #     sabotage (b) (shown forced to 1) turns THIS red and leaves BP48 green;
  #   * the second leg below asserts the restore DID run and DID apply the
  #     sub-dict, by finding a non-default FILTER pattern in a hidden sidebar.
  #     That kills "the restore did nothing at all", which is the one world a
  #     bare shown==0 cannot distinguish.
  pcall ::wviewer::browser_toggle 0 $tok
  update
  set bs4 [pcall ::wviewer::browser_state $tok]
  check {BP57 (FIXTURE) hidden, but still NON-default -> the key is emitted} \
    [list [pcall dict get $bs4 shown] \
          [pcall ::wviewer::browser_state_is_default $bs4]] \
    [list 0 0]
  set snap2 [pcall ::wviewer::snapshot $tok {}]
  check {BP57 (FIXTURE) the snapshot carries shown 0} \
    [wviewer::dget [pcall dict get $snap2 browser] shown {NO-KEY}] 0
  catch {wviewer::close $tok} ; update
  check {BP57 restore returns 1} [pcall ::wviewer::restore $tok $snap2 $brP {}] 1
  set vtop [wviewer::window_for $tok]
  set BPF $vtop.wvbrowser ; set BPL $BPF.wvfilter
  viewer_ready $vtop ; update
  check {BP57 a snapshot taken HIDDEN restores HIDDEN (built, unpacked, alive)} \
    [list [pcall ::wviewer::browser_shown $tok] [bs_packed $BPF] \
          [winfo exists $BPF]] \
    [list 0 0 1]
  check {BP57 ...and the restore DEMONSTRABLY RAN: the filter bar is non-default} \
    [pcall $BPL.pat get] {.*}

  # --- BP58: back-compat with every state file written before this item -----
  set bp_old [dict create open 1 sharedx 0 rawfile {} \
                graphs [list [wviewer::empty_graph]] mode single target 0]
  catch {wviewer::close $tok} ; update
  check {BP58 a pre-item-15 dict (no browser key) still restores} \
    [pcall ::wviewer::restore $tok $bp_old $brP {}] 1
  set vtop [wviewer::window_for $tok]
  viewer_ready $vtop ; update
  check {BP58 ...and leaves the window at browser_state_default} \
    [pcall ::wviewer::browser_state_is_default [pcall ::wviewer::browser_state $tok]] 1

  # --- BP59: ISSUE 0119, BOTH DIRECTIONS ------------------------------------
  # The restore is the SECOND write path into a file under the user's home, and
  # item 13's sabotage (b) really wrote the user's real one. Bracketed: the conf
  # dir points at the scratch tree for the whole leg and both globals go back.
  # POSITIVE FIRST (ruling 29) — with the gate OPEN the merge really lands, in
  # memory AND on disk, read back by `source` in a FRESH interp so the assertion
  # cannot be satisfied by the variable already in this process.
  set bp_conf [file join $scratch conf15]
  file mkdir $bp_conf
  set bp_store [file join $bp_conf raw_history]
  set ::USER_CONF_DIR $bp_conf
  set ::update_recent_files 1
  set ::wviewer::rawhist {}
  check {BP59 (POSITIVE) an UNGATED restore merges the saved history} \
    [list [pcall ::wviewer::browser_state_apply $tok \
             [dict replace $bp_def hist [list $brP $brA]]] \
          [wviewer::rawhist_get]] \
    [list 1 [list $brP $brA]]
  check {BP59 ...and the store on DISK says the same} \
    [br_store_read $bp_store] [list $brP $brA]
  # NEGATIVE, now that its positive twin is proven on this very fixture.
  set bp_mem_pre [wviewer::rawhist_get]
  set bp_fd [open $bp_store r] ; set bp_file_pre [read $bp_fd] ; close $bp_fd
  set ::update_recent_files 0
  set bp_rc [pcall ::wviewer::browser_state_apply $tok \
               [dict replace $bp_def hist [list $brB]]]
  set bp_fd [open $bp_store r] ; set bp_file_post [read $bp_fd] ; close $bp_fd
  check {BP59 a GATED (--script) restore still RUNS but moves no history} \
    [list $bp_rc [wviewer::rawhist_get] $bp_file_post] \
    [list 1 $bp_mem_pre $bp_file_pre]
  set ::USER_CONF_DIR $br_conf0
  set ::update_recent_files $br_gate0
  set ::wviewer::rawhist {}

  # --- BP60/BP61: teardown ---------------------------------------------------
  catch {wviewer::close $tok} ; update
  check {BP60 (TEARDOWN) the close leaves no per-token browser entry behind} \
    [list [info exists ::wviewer::browser($tok)] \
          [info exists ::wviewer::browsershow($tok)]] \
    [list 0 0]
  # item 14's BD59 discipline, at the END of the whole file: EVERY run —
  # including every sabotage run — proves the user's real store untouched.
  set bp_home_post {}
  set bp_home_now [file exists $br_home_file]
  if {$bp_home_now} {
    set fd [open $br_home_file r] ; set bp_home_post [read $fd] ; close $fd
  }
  check {BP61 (TEARDOWN) the user's REAL raw_history is still untouched (0119)} \
    [list $bp_home_now $bp_home_post] [list $br_home_pre $br_home_txt]
  check {BP61 ...while item 15's own writes DID land, in the scratch store} \
    [list [file exists $bp_store] \
          [expr {[file normalize $bp_store] ne [file normalize $br_home_file]}]] \
    [list 1 1]
  }
  }

} else {
  puts "SKIPPED: BR4x group (Tk/X arm only)"
  puts "SKIPPED: BP4x group (Tk/X arm only)"
}

} err]} { puts "FATAL: $err\n$::errorInfo" ; incr fail }

wvbs_finish
