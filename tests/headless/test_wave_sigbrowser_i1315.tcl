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
  check {BR20 the sidebar's children are exactly the item-13 set} \
    [lsort [winfo children $BRF]] \
    [lsort [list $BRF.ph $BRF.wvsearch $BRF.tb $BRF.tvf $BRF.wvfilter $BRF.loc]]
  check {BR21 the packing recipe is the six-slave stack with .loc FIRST} \
    [pack slaves $BRF] \
    [list $BRF.loc $BRF.wvsearch $BRF.tb $BRF.ph $BRF.wvfilter $BRF.tvf]
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

check {BP10 browser_state_default's key list is the snapshot shape} \
  [dict keys $bp_def] {shown width search filter dest open sel hist}
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
check {BP13 is_default is 0 for each field that counts} \
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
              {pattern {} syntax regexp case 0 type all}]]] \
  [list 0 0 0 0 0 0 0]
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

  # A raw with HIERARCHY: `v(x1.out)` -> group `g:x1`, leaf `s:v(x1.out)`.
  # The default tree is ALL-OPEN with an EMPTY selection (browser_populate
  # inserts every row -open 1 and clears the selection), so a COLLAPSED group
  # and a NON-EMPTY selection are the genuinely non-default values driver note
  # (d) demands. A flat raw has no groups at all and could not test either.
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
  set BPT $BPF.tvf.tv
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
  check {BP43 (FIXTURE) the sidebar shows and the tree carries the groups} \
    [list [pcall ::wviewer::browser_toggle 1 $tok] \
          [pcall $BPT exists g:x1] [pcall $BPT exists g:x1.x2] \
          [pcall $BPT exists g:y3] [pcall $BPT exists {s:v(x1.x2.n1)}]] \
    [list 1 1 1 1 1]
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
  pcall ::wviewer::set_plot_dest newstrip $tok
  set bpw [pcall ::wviewer::browser_width $tok 260]
  pcall $BPT item g:x1 -open 0
  pcall $BPT selection set {s:v(x1.x2.n1)}
  update

  set bs1 [pcall ::wviewer::browser_state $tok]
  check {BP43 the non-defaults TOOK: shown/dest/sel/collapse read back live} \
    [list [pcall dict get $bs1 shown] [pcall dict get $bs1 dest] \
          [pcall dict get $bs1 sel] \
          [expr {[lsearch -exact [pcall dict get $bs1 open] g:x1] < 0}] \
          [expr {[lsearch -exact [pcall dict get $bs1 open] g:y3] >= 0}]] \
    [list 1 newstrip {s:v(x1.x2.n1)} 1 1]
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
  foreach k {shown width search filter dest open sel hist} {
    lappend bpg $k [wviewer::dget $bsnap $k {NO-KEY}]
  }
  check {BP45 every field made it into the snapshot dict} \
    [list [dict get $bpg shown] [dict get $bpg width] [dict get $bpg dest] \
          [dict get $bpg sel] [dict get $bpg search] [dict get $bpg filter] \
          [expr {[dict get $bpg open] eq {NO-KEY} ? {NO-KEY} : {present}}] \
          [expr {[dict get $bpg hist] eq {NO-KEY} ? {NO-KEY} : {present}}]] \
    [list 1 $bpw newstrip {s:v(x1.x2.n1)} \
          {pattern .* syntax regexp case 1 type v alldbs 1} \
          {pattern .* syntax regexp case 1 type v} present present]

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

  # --- BP47-BP56: THE RESTORE ------------------------------------------------
  check {BP47 restore returns 1 and the viewer comes back up} \
    [pcall ::wviewer::restore $tok $snap1 $brP {}] 1
  set vtop [wviewer::window_for $tok]
  set BPF $vtop.wvbrowser ; set BPS $BPF.wvsearch
  set BPL $BPF.wvfilter   ; set BPT $BPF.tvf.tv
  check {BP47 ...on a mapped canvas} [viewer_ready $vtop] 1
  update

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
  check {BP52 the tree SELECTION round-tripped} \
    [pcall $BPT selection] {s:v(x1.x2.n1)}

  # --- BP53/BP54: the expanded set, and the ORDERING finding ----------------
  # BOTH LEGS, so "everything collapsed" and "everything open" are different
  # answers: the collapsed group and an open sibling are asserted together.
  check {BP53 the COLLAPSE round-tripped, while a sibling group stayed OPEN} \
    [list [pcall $BPT item g:x1 -open] [pcall $BPT item g:y3 -open]] \
    [list 0 1]
  # ⚠ THE NON-OBVIOUS ORDERING CLAIM. `$tv see` force-opens EVERY ANCESTOR of
  # the node it scrolls to (browser_reveal's central finding), so revealing the
  # selection AFTER applying the collapse would silently re-expand exactly the
  # group the user collapsed. The selected leaf lives under `g:x1`; if g:x1 is
  # open here, the open-set was applied too early. Sabotage (c) is this.
  check {BP54 the persisted collapse BEATS see's ancestor-expansion} \
    [list [pcall $BPT item g:x1 -open] [pcall $BPT parent {s:v(x1.x2.n1)}]] \
    [list 0 g:x1.x2]

  # --- BP55: SETTLED DECISION 11 --------------------------------------------
  # "A restored selection must be a LEGAL INPUT to item 12's sync, not just a
  # string that looks right." `browser_descend_here` does `$tv selection` then
  # `browser_descend_to $token $sel`, whose very first act is
  # `browser_target_path $token $sel`. That value is the gate, and it is what is
  # asserted here (see the group header for why the real descend is not driven).
  check {BP55 the RESTORED selection resolves to a hierarchy path (decision 11)} \
    [pcall ::wviewer::browser_target_path $tok [pcall $BPT selection]] \
    {ok x1.x2}
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
