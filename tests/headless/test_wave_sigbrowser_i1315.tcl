# tests/headless/test_wave_sigbrowser_i1315.tcl — Signal Browser PLAN items
# 13-15. ITEM 13 IS THE ONLY ONE IMPLEMENTED SO FAR: the LOCATION BAR + the
# last-20 raw history (ViVA §3.1) — an editable path entry at the top of the
# sidebar whose <Return> loads that raw, a newest-first deduped capped dropdown
# of the raws opened, persisted to its OWN store, and `select_raw` kept as the
# Browse... button beside it.
# doc/claude/signal_browser_batch/PLAN.md item 13; receipts/13_receipt.md.
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
  }

} else {
  puts "SKIPPED: BR4x group (Tk/X arm only)"
}

} err]} { puts "FATAL: $err\n$::errorInfo" ; incr fail }

wvbs_finish
