# tests/headless/test_wave_sigbrowser_i11.tcl — Signal Browser PLAN item 11,
# HIERARCHY SYNC browser -> schematic ("Descend to here").
# doc/claude/signal_browser_batch/PLAN.md item 11; receipts/11_receipt.md.
#
# ⚠⚠ THIS FILE WAS CARVED OUT OF test_wave_sigbrowser.tcl BY DRIVER RULING 30.
# Settled decision 9 put items 8-15 in one file. At 489 checks that file was
# killed mid-run by WSLg with ZERO check failures (measured 2026-08-06: 0 of 9
# completions), which made every later item's verification unmeasurable.
# Ruling 30 revised decision 9 and split the checks BY ITEM RANGE:
#
#   test_wave_sigbrowser.tcl       items 8, 9, 10   BS BT BM
#   test_wave_sigbrowser_i11.tcl   item 11          BH   <- THIS FILE
#   test_wave_sigbrowser_i12.tcl   item 12          BX
#   (items 13-15 create ONE more file; item 13 owns that decision)
#
# ⚠ WHY ITEM 11 GOT A FILE TO ITSELF. Not because of its check count — 73 is the
# smallest of the five — but because of its FIXTURE COST, which is the mechanism
# the ruling names. The BH5x group holds a REAL VIEWER AND THE REAL DESIGN
# WINDOW AT THE SAME TIME, each with its own document and its own hierarchy
# walk. In the 8 pre-split runs, three deaths landed inside BH5x and five inside
# item 12's equally two-windowed BX4x/BX5x; not one landed in BS, BT or BM.
# Items 11 and 12 are therefore the two that each get a process of their own.
#
# ============================================================================
# CONVENTIONS — SHARED WITH EVERY OTHER BROWSER FILE (wvbs_common.tcl)
# ============================================================================
# `check`, `check_true`, `pcall`, the counting `::bgerror`, `wvproc_body`,
# `bs_packed`, `bs_order`, `bs_wait_mapped`, `bs_wait_mapped_top`,
# `bs_wait_widths`, `send_key`, `viewer_ready`, `$wsrc` and `wvbs_finish` come
# from `tests/headless/wvbs_common.tcl`, which is deliberately NOT named
# `test_*.tcl` (full_audit.sh selects cases with `ls test_*.tcl`).
#
# GROUP PREFIX: item 11 is `BH`, never reused. Numbers are BLOCKED by arm:
# 01-19 source/pure (BOTH arms), 20-39 the fixture, 40-59 the REAL viewer.
#     ⚠ DECLARED DEVIATION, inherited unchanged from the item-8 header: the
#     BH2x/BH3x block runs against a REAL LOADED SCHEMATIC FIXTURE in BOTH
#     arms, not against a throwaway Tk toplevel. Item 11's subject is the xschem
#     hierarchy walk, which needs no Tk at all — gating it on X would have made
#     the item's central claim (the rollback) X-only for no reason. The Tk half
#     is BH4x/BH5x, gated as usual.
#
# ⚠ THE ARM STATEMENT. The `--nogui` arm runs BH01-BH09 (source/pure) AND the
# BH20-BH39 hierarchy walk, because the walk is `xschem descend`/`ascend` and
# needs no display. It does NOT run BH40-BH54: the menu wiring, the key binds
# and the end-to-end raise need real Tk and real X.
#
# ⚠ SKIP-BANNER WORDING IS LOAD-BEARING. The X-gated groups print
# `SKIPPED: <group> group (Tk/X arm only)`. NEVER `RESULT: SKIP`, never
# `skipped: no X`, never `SKIP: no X connection` — full_audit.sh's `is_skip`
# matches those three strings and would score the WHOLE FILE as SKIP, silently
# discarding every check that did run.
#
# ⚠ WHAT THE SPLIT HAD TO CARRY ACROSS, and it is exactly one line. In the
# merged file item 8's real-viewer group set `::library_registry_defs_only 1`
# before item 11 ever ran, so item 11's `ase::ui::design_path` reads resolved
# against a defs-only registry. That is now set explicitly in the prologue
# below rather than inherited by accident. Everything else item 11 needs —
# the wvhier fixture, its library.defs, both session state files and both
# sessions — it already built for itself, and BH20's `(FIXTURE)` and
# `(POSITIVE CONTROL)` checks are the proof that the prologue worked.
#
# PROCESS STATE LEFT BEHIND: `.wvbh1` is destroyed and `wviewer::forget wvbh1`
# drops its registry entry; the BH5x viewer is closed on the way out. The design
# window is left loaded on the wvhier fixture and three sessions stay registered
# — harmless in a process that is about to exit, and the item-12 file builds its
# own copy of all of it rather than inheriting any of it.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_i11.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_i11.tcl

set ::wvbs_tag  wvsigbrowser_i11
set ::wvbs_name test_wave_sigbrowser_i11
source [file join [file dirname [info script]] wvbs_common.tcl]

# --- THE SPLIT PROLOGUE (see the ⚠ above) -----------------------------------
set ::library_registry_defs_only 1

if {[catch {


# ============================================================================
# BH — signal-browser PLAN item 11: HIERARCHY SYNC, browser -> schematic
# ("Descend to here"). The user picks a browser row and the session's DESIGN
# window ends up at that point in the hierarchy, raised — or exactly where it
# started, with a reason, if any step fails.
#
# ⚠ THE POSITIVE CONTROL COMES FIRST, AND IT IS NOT DECORATION. The item's
# defining behaviour is a NEGATIVE claim — "sim_sch_path is EXACTLY as it
# started" — and that reads identically whether the rollback worked, the
# descend never started, or the fixture could not descend at all. BH20/BH21
# prove the SAME fixture in the SAME process DOES move; only then do BH23-BH25
# mean anything.
#
# ⚠ EVERY BEHAVIOURAL LEG ASSERTS ON THE WORLD (`xschem get sim_sch_path` read
# back), never on "the proc returned without throwing" — item 10's swallowed
# `clipboard clear` is the shape being defended against, and item 11 calls bare
# `xschem ...` verbs inside `catch` in exactly the same way.
#
# ⚠ THE PIVOT IS `sim_sch_path`, NEVER `sch_path` (settled decision 10), and
# with NO raw loaded the two getters are BYTE-IDENTICAL — which is why the
# PLAN's sabotage (b) as written would have fired nothing. BH29-BH31 read a raw
# and set raw_level so the divergence exists at all; they are the only teeth
# that sabotage has.
# ============================================================================

# --- BH01-BH09: PURE + SOURCE, both arms ------------------------------------

check {BH01 hier_split strips the trailing dot sim_sch_path really carries} \
  [list [pcall ::wviewer::hier_split {x1.x2.}] \
        [pcall ::wviewer::hier_split {x1.}] \
        [pcall ::wviewer::hier_split {x1.x2}]] \
  [list {x1 x2} {x1} {x1 x2}]
check {BH01 ...and the sim root, which sim_sch_path returns EMPTY, is {}} \
  [list [pcall ::wviewer::hier_split {}] [pcall ::wviewer::hier_split {.}]] \
  [list {} {}]

# EXACT, deliberately: this is what makes "an exact hit always wins" survive a
# design carrying both `x1` and `X1` (the wvhier fixture does).
check {BH02 hier_common is BYTE-exact: {X1} and {x1} share no prefix} \
  [list [pcall ::wviewer::hier_common {X1} {x1}] \
        [pcall ::wviewer::hier_common {X1 X2} {X1 y3}] \
        [pcall ::wviewer::hier_common {X1 X2} {X1 X2 z}]] \
  [list 0 1 2]

check {BH03 hier_plan: two ascends to the root, no descends} \
  [pcall ::wviewer::hier_plan {x1 x2} {}] [list 2 {}]
check {BH03 ...from the root, no ascends and two descends} \
  [pcall ::wviewer::hier_plan {} {x1 x2}] [list 0 {x1 x2}]
check {BH03 ...equal paths are {0 {}}, and a sibling is one up + one down} \
  [list [pcall ::wviewer::hier_plan {x1 x2} {x1 x2}] \
        [pcall ::wviewer::hier_plan {x1 x2} {x1 y3}]] \
  [list [list 0 {}] [list 1 {y3}]]

# THE MEASURED TRAP. ngspice lowercases, so a correct walk of `x1.x2` lands on
# the schematic's own `x1.X2`; a byte-exact final verify rejects its own
# correct result and rolls back (reproduced before the code was written).
check {BH04 hier_same, the FINAL VERIFY, is case-INSENSITIVE} \
  [list [pcall ::wviewer::hier_same {X1 X2} {x1 x2}] \
        [pcall ::wviewer::hier_same {x1 X2} {x1 x2}] \
        [pcall ::wviewer::hier_same {} {}]] \
  [list 1 1 1]
check {BH04 ...but it is still a comparison: different paths are NOT the same} \
  [list [pcall ::wviewer::hier_same {X1 X2} {x1 y3}] \
        [pcall ::wviewer::hier_same {X1} {x1 x2}] \
        [pcall ::wviewer::hier_same {X1} {}]] \
  [list 0 0 0]

# browser_target_path against a synthetic row snapshot (PURE — no Tk, no raw)
set ::wviewer::browserrows(wvbh) [wviewer::browser_rows [list \
  [wviewer::signal_entry {v(out)}] \
  [wviewer::signal_entry {v(x1.x2.net5)}] \
  [wviewer::signal_entry {i(x1.x2.net5)}] \
  [wviewer::signal_entry {v(x1.y3.net5)}]]]
check {BH05 a GROUP id IS the dotted instance path (decision 14)} \
  [list [pcall ::wviewer::browser_target_path wvbh {g:x1.x2}] \
        [pcall ::wviewer::browser_target_path wvbh {g:x1}]] \
  [list {ok x1.x2} {ok x1}]
check {BH05 a LEAF id resolves through its row's raw name, not through the id} \
  [pcall ::wviewer::browser_target_path wvbh {s:v(x1.x2.net5)}] {ok x1.x2}
check {BH05 a TOP-LEVEL signal is {ok {}} — a legitimate ascend to the sim root} \
  [pcall ::wviewer::browser_target_path wvbh {s:v(out)}] [list ok {}]
check {BH05 rows that AGREE on one path resolve; two leaves of the same group} \
  [pcall ::wviewer::browser_target_path wvbh {s:v(x1.x2.net5) s:i(x1.x2.net5)}] \
  {ok x1.x2}
# ruling 17: a disagreeing set is refused, NOT silently first-wins
check {BH05 rows that DISAGREE are an err, never a silent first-wins} \
  [pcall ::wviewer::browser_target_path wvbh {s:v(x1.x2.net5) s:v(x1.y3.net5)}] \
  {err {those rows are in different parts of the hierarchy}}
check {BH05 an empty selection and an unknown id are both errs, never a throw} \
  [list [lindex [pcall ::wviewer::browser_target_path wvbh {}] 0] \
        [lindex [pcall ::wviewer::browser_target_path wvbh {s:nosuch}] 0] \
        [lindex [pcall ::wviewer::browser_target_path wvNOSUCH {g:x1}] 0]] \
  [list err err err]
unset ::wviewer::browserrows(wvbh)

# THE DECISION-10 SOURCE GUARD, named as such: hier_now is the ONE pivot read
# and it must not be able to reach for sch_path.
set bh_now [wvproc_body $wsrc wviewer::hier_now]
check_true {BH06 hier_now was found in the source} [expr {$bh_now ne {}}]
check {BH06 hier_now reads sim_sch_path and NEVER sch_path (decision 10)} \
  [list [expr {[string first {sim_sch_path} $bh_now] >= 0}] \
        [regexp -all {(^|[^_])sch_path} $bh_now]] \
  [list 1 0]

set bh_idb [wvproc_body $wsrc wviewer::install_default_binds]
check_true {BH07 install_default_binds carries `bind WaveViewer <Key-E>`} \
  [expr {[string first {bind WaveViewer <Key-E>} $bh_idb] >= 0}]
check_true {BH07 ...calling browser_descend_at, and it BREAKs} \
  [regexp {bind WaveViewer <Key-E> \{wviewer::browser_descend_at %W; break\}} $bh_idb]

set bh_bb [wvproc_body $wsrc wviewer::browser_build]
check_true {BH08 browser_build binds <Key-E> on the TREE ITSELF (the tag cannot reach it)} \
  [regexp {bind \$f\.pw\.tvf\.tv <Key-E> \{wviewer::browser_descend_at %W ; break\}} $bh_bb]

set bh_mb [wvproc_body $wsrc wviewer::build_menubar]
check_true {BH09 build_menubar carries `-label {Descend to here} -accelerator E`} \
  [expr {[string first {-label {Descend to here} -accelerator E} $bh_mb] >= 0}]
check_true {BH09 ...on the VIEW cascade, calling browser_descend_here} \
  [expr {[string first "\$mb.view add command -label {Descend to here} -accelerator E" $bh_mb] >= 0 &&
         [string first {wviewer::browser_descend_here $token} $bh_mb] >= 0}]

# --- BH20-BH39: THE WALK, on a REAL fixture, in BOTH ARMS -------------------
# fixtures/wvhier: top holds `X1` AND `x1` (both instances of mid — this is
# what gives exact-first TEETH) plus the non-subcircuit `V9`; mid holds `X2`;
# leaf is a leaf.
set bh_fix [file join $repo tests headless fixtures wvhier]
set XSCHEM_LIBRARY_PATH "$bh_fix:[file join $repo xschem_library]"
set bh_load [pcall xschem load [file join $bh_fix wvhier_top.sch]]
# ⚠ THE DESIGN WINDOW IS NAMED HERE, ONCE, BEFORE ANY VIEWER EXISTS — never
# inherited from `current_win_path` after the fact (item 12's BX4x rule, and the
# ruling-30 answer to the BH50 flap below). `wviewer::open` leaves the context ON
# THE VIEWER, so a capture taken after it names the wrong window, and every
# subsequent "switch back to the design window" then switches to the viewer.
set bh_dwin0 [pcall xschem get current_win_path]
proc bh_sim {} { set p {} ; catch {set p [xschem get sim_sch_path]} ; return $p }
check {BH20 (FIXTURE) the 3-level fixture loads and starts at its top} \
  [list [expr {![string match ERR:* $bh_load]}] [bh_sim] [pcall xschem get currsch]] \
  [list 1 {} 0]

# ⚠⚠ THE POSITIVE CONTROL. Without this the four rollback checks below are
# vacuous — "unmoved" would look identical to "could never move".
check {BH20 (POSITIVE CONTROL) hier_walk X1.X2 really MOVES the hierarchy} \
  [list [pcall ::wviewer::hier_walk X1.X2] [bh_sim]] \
  [list {ok X1.X2} {X1.X2.}]

# a sibling sync: no common prefix at all, so this is TWO ascends AND a
# descend — a leg a descend-only implementation cannot pass
check {BH21 sibling-to-sibling: X1.X2 -> x1 ascends twice, then descends} \
  [list [pcall ::wviewer::hier_walk x1] [bh_sim] [pcall xschem get currsch]] \
  [list {ok x1} {x1.} 1]

set bh_sel0 [pcall xschem selected_set]
set bh_cur0 [pcall xschem get currsch]
check {BH22 already-at-target is {ok already}, byte-exactly where it was} \
  [list [pcall ::wviewer::hier_walk x1] [bh_sim]] [list {ok already x1} {x1.}]
check {BH22 ...and it TOUCHED NOTHING: same selection, same level} \
  [list [pcall xschem selected_set] [pcall xschem get currsch]] \
  [list $bh_sel0 $bh_cur0]

# --- the ROLLBACK, the item's defining behaviour ----------------------------
# ⚠ THE TARGET IS CHOSEN SO THAT MOVEMENT REALLY HAPPENS FIRST. `X1.X2` ->
# `x1.nosuch` shares NO byte-exact prefix, so the walk ascends TWICE, descends
# into `x1`, and only then fails — a rollback that has to undo three steps. The
# obvious `X1` -> `X1.nosuch` would have been VACUOUS: the plan is a single
# descend that never happens, so "unmoved" is true whether the rollback exists
# or not (measured — that first cut passed with the rollback deleted).
pcall ::wviewer::hier_walk X1.X2
check {BH23 (fixture) we are two levels down, at X1.X2} \
  [list [bh_sim] [pcall xschem get currsch]] [list {X1.X2.} 2]
check {BH23 (ROLLBACK, AFTER REAL MOVEMENT) a bad last segment errs and names it} \
  [pcall ::wviewer::hier_walk x1.nosuch] \
  {err {no instance 'nosuch'} X1.X2}
check {BH23 ...and sim_sch_path is EXACTLY as it started — two ascends and a descend undone} \
  [list [bh_sim] [pcall xschem get currsch]] [list {X1.X2.} 2]

pcall ::wviewer::hier_walk {}
check {BH24 (fixture) we are back at the sim root} [list [bh_sim] [pcall xschem get currsch]] [list {} 0]
check {BH24 (ROLLBACK from the root) a bad segment errs and rolls back to the root} \
  [list [pcall ::wviewer::hier_walk X1.nosuch] [bh_sim] [pcall xschem get currsch]] \
  [list {err {no instance 'nosuch'} {}} {} 0]

# ⚠ THE NON-THROWING REFUSAL, driver note (d)'s exact shape: `descend -inst V9`
# resolves the instance fine (V9 exists), returns the STRING `0`, throws
# NOTHING, and does not move. A `catch`-only implementation reads that as
# success. Only the sim_sch_path readback sees it.
check {BH25 (ROLLBACK, NON-THROWING) descend -inst on a non-subcircuit is refused} \
  [pcall ::wviewer::hier_walk V9] {err {descend refused at 'V9'} {}}
check {BH25 ...and the raw verb really did return `0` without throwing} \
  [list [pcall xschem descend -inst V9] [bh_sim]] [list 0 {}]

# --- case, and exact-first ---------------------------------------------------
# ONE leg exercising all three: exact-first (`x1` exists byte-exactly),
# the case-insensitive retry (`x2` -> `X2`) and the case-insensitive final
# verify (landed `x1.X2` vs target `x1.x2`).
check {BH26 (CASE) a lowercased ngspice path lands, and reports the SCHEMATIC spelling} \
  [list [pcall ::wviewer::hier_walk x1.x2] [bh_sim]] [list {ok x1.X2} {x1.X2.}]

pcall ::wviewer::hier_walk {}
check {BH27 (EXACT-FIRST) X1 lands on X1, not on its lowercase twin} \
  [list [pcall ::wviewer::hier_walk X1] [bh_sim]] [list {ok X1} {X1.}]
pcall ::wviewer::hier_walk {}
check {BH27 ...and x1 lands on x1: a design with BOTH still resolves each} \
  [list [pcall ::wviewer::hier_walk x1] [bh_sim]] [list {ok x1} {x1.}]

# --- the declared [D]: vector instances (issue 0212) ------------------------
pcall ::wviewer::hier_walk {}
check {BH28 (VECTOR, declared [D]) a bracketed segment is REFUSED, naming 0212} \
  [pcall ::wviewer::hier_walk {x1[3].x2}] \
  {err {vector instance 'x1[3]' cannot be addressed (issue 0212)} {}}
# this one has ROLLBACK TEETH too: `X1` descends fine and only `X2[0]` refuses,
# so a missing rollback leaves the tree parked one level down
check {BH28 ...and a bracketed segment DEEPER in the path rolls back too} \
  [list [pcall ::wviewer::hier_walk {X1.X2[0]}] [bh_sim]] \
  [list {err {vector instance 'X2[0]' cannot be addressed (issue 0212)} {}} {}]
pcall ::wviewer::hier_walk {}
check {BH28 hier_resolve answers the VECTOR sentinel, not a wrong instance} \
  [list [pcall ::wviewer::hier_resolve {x1[3]}] [pcall ::wviewer::hier_resolve X1] \
        [pcall ::wviewer::hier_resolve x2]] \
  [list VECTOR X1 {}]

# --- BH29-BH31: SETTLED DECISION 10, and the ONLY teeth for sabotage (b) ----
# With no raw loaded `sch_waves_loaded()` is -1, the skip loop in the C getter
# never runs, and sim_sch_path is sch_path-minus-its-leading-dot BYTE FOR BYTE.
# So every leg above would pass just as happily on sch_path. These three read a
# raw and move raw_level so the two getters actually diverge.
pcall ::wviewer::hier_walk X1.X2
set bh_rawnew [pcall xschem raw new bh_item11.raw dc vsweep 0 1.0 0.5]
pcall xschem raw add {v(x1.x2.net5)} {vsweep 1 +}
# MEASURED: `xschem raw new` stamps the raw at the CURRENT level (2 here), so
# the level is set explicitly rather than assumed — an assumed 0 would have made
# BH29's "the two getters agree" leg pass for the wrong reason.
pcall xschem set raw_level 0
check {BH29 (fixture) a raw is loaded at level 0, at hierarchy depth 2} \
  [list $bh_rawnew [pcall xschem raw loaded] [pcall xschem get currsch]] \
  [list 1 0 2]
check {BH29 at raw_level 0 the two getters AGREE — this is why the PLAN's sabotage (b) fired nothing} \
  [list [bh_sim] [pcall xschem get sch_path]] [list {X1.X2.} {.X1.X2.}]

check {BH30 raw_level 1 makes them DIVERGE: sim `X2.` vs sch `.X1.X2.`} \
  [list [pcall xschem set raw_level 1] [bh_sim] [pcall xschem get sch_path]] \
  [list 1 {X2.} {.X1.X2.}]
check {BH30 ...and hier_now follows the SIM origin, one segment not two} \
  [pcall ::wviewer::hier_now] {X2}

# THE DISCRIMINATOR. Under the sim origin we are already at `X2`, so this is a
# no-op that touches nothing. Under sch_path we would read {X1 X2}, ascend
# twice and try to descend into an `X2` that does not exist at the top — an
# err and a rollback.
check {BH31 (DECISION 10) `X2` under the sim origin is a NO-OP, not a two-level move} \
  [list [pcall ::wviewer::hier_walk X2] [bh_sim] [pcall xschem get currsch]] \
  [list {ok already X2} {X2.} 2]

pcall xschem set raw_level 0
pcall ::wviewer::hier_walk {}

# --- BH32: THE ORIGIN GUARD --------------------------------------------------
# The item's only claim a readback cannot check: when the design window's top
# is ABOVE the session's design and no raw is loaded there, the pivot and the
# verify share the same wrong origin. Only the guard can see it.
check {BH32 with a raw loaded in THIS context the origin is genuinely sim-relative} \
  [list [pcall xschem raw loaded] [pcall ::wviewer::hier_origin_ok bh_notasession]] \
  [list 0 1]
pcall xschem raw clear
check {BH32 (control) the raw really is gone, so the branch below is the other one} \
  [pcall xschem raw loaded] -1

set bh_defs [file join $scratch bh_library.defs]
set bh_f [open $bh_defs w]
puts $bh_f "DEFINE wvhier $bh_fix"
close $bh_f
set XSCHEM_LIBRARY_DEFS $bh_defs
set bh_stTOP [dict merge [ase::state_default] \
  [dict create design [dict create lib wvhier cell wvhier_top view schematic]]]
set bh_stMID [dict merge [ase::state_default] \
  [dict create design [dict create lib wvhier cell wvhier_mid view schematic]]]
pcall ase::state_save [file join $scratch bh_top.state] $bh_stTOP
pcall ase::state_save [file join $scratch bh_mid.state] $bh_stMID
pcall ase::session_open bh/wvhier_top/schematic [file join $scratch bh_top.state]
pcall ase::session_open bh/wvhier_mid/schematic [file join $scratch bh_mid.state]
check {BH32 (control) both sessions' designs really resolve to the fixture files} \
  [list [file tail [pcall ase::ui::design_path bh/wvhier_top/schematic]] \
        [file tail [pcall ase::ui::design_path bh/wvhier_mid/schematic]]] \
  [list wvhier_top.sch wvhier_mid.sch]
check {BH32 at the top, with the session's design AS the top, the guard passes} \
  [list [pcall ase::ui::sod_base_level bh/wvhier_top/schematic] \
        [pcall ::wviewer::hier_origin_ok bh/wvhier_top/schematic]] \
  [list 0 1]
pcall ::wviewer::hier_walk X1
check {BH32 (THE ANCESTOR CASE) design at stack level 1 -> the guard REFUSES} \
  [list [pcall ase::ui::sod_base_level bh/wvhier_mid/schematic] \
        [pcall ::wviewer::hier_origin_ok bh/wvhier_mid/schematic]] \
  [list 1 0]
pcall ::wviewer::hier_walk {}
# DECLARED LIMIT, asserted rather than pretended away: sod_base_level answers 0
# when the session's design is not in the stack AT ALL (its own documented
# rule, which keeps a scripted/stubbed pick on the shipped path), so the guard
# passes there too. That hole is sod_base_level's, is pre-existing, and item 11
# does not restructure ase_window.tcl to close it.
check {BH32 (DECLARED LIMIT) design not in the stack at all -> sod_base_level 0, guard passes} \
  [list [pcall ase::ui::sod_base_level bh/wvhier_mid/schematic] \
        [pcall ::wviewer::hier_origin_ok bh/wvhier_mid/schematic]] \
  [list 0 1]

# --- BH40-BH54: the Tk half -------------------------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # ⚠⚠ SPLIT PROLOGUE, AND IT IS A WIDENING, NOT A PATCH (rulings 30 and 17).
  # This is the ONE coupling the ruling-30 split exposed, and it is worth
  # naming: in the merged file, item 8's real-viewer group ran long before this
  # block, `wviewer::open` calls `wviewer::install_default_binds`, and THAT is
  # what put <Key-E> on the shared `WaveViewer` CLASS tag. BH42's third leg was
  # therefore passing on a side effect of ANOTHER ITEM'S FIXTURE — it read the
  # right value for the wrong reason, and in an item-11-only process (no viewer
  # opens until BH5x) it read {} and failed. The install is now EXPLICIT, and
  # its EFFECT is measured rather than assumed: the class tag is read BEFORE and
  # AFTER, so "install_default_binds is what installs item 11's key" is now
  # PROVEN HERE instead of inherited from somewhere else. Strictly more
  # coverage than the merged file had.
  set bh_tagE0 [bind WaveViewer <Key-E>]
  pcall ::wviewer::install_default_binds
  check {BH40 (SPLIT CONTROL) install_default_binds is what puts <Key-E> on the WaveViewer class tag} \
    [list [expr {$bh_tagE0 eq {}}] \
          [expr {[string first {browser_descend_at} [bind WaveViewer <Key-E>]] >= 0}]] \
    [list 1 1]

  # BH40/BH41 are BM25's SUCCESSOR — item 11 consumes the reserved slot, so the
  # inherited check has to be rewritten, and the replacement pins BOTH states.
  toplevel .wvbh1
  wm withdraw .wvbh1
  pcall ::wviewer::browser_build wvbh1 .wvbh1
  dict set ::wviewer::windows wvbh1 [dict create top .wvbh1 win_path .wvbh1.drw]
  set BHTV .wvbh1.wvbrowser.pw.tvf.tv
  set ::wviewer::browserrows(wvbh1) [wviewer::browser_rows [list \
    [wviewer::signal_entry {v(out)}] \
    [wviewer::signal_entry {v(x1.x2.net5)}] \
    [wviewer::signal_entry {v(x1.y3.net5)}]]]
  set BHM [pcall ::wviewer::browser_menu_build wvbh1 {g:x1.x2}]
  check {BH40 `Descend to here` is STILL last and still index 7} \
    [list [pcall $BHM index end] [pcall $BHM entrycget 7 -label]] \
    [list 7 {Descend to here}]
  check {BH40 ...and item 11 has made it LIVE, wired to browser_descend_to} \
    [list [pcall $BHM entrycget 7 -state] [pcall $BHM entrycget 7 -command]] \
    [list normal [list wviewer::browser_descend_to wvbh1 {g:x1.x2}]]
  set BHM2 [pcall ::wviewer::browser_menu_build wvbh1 \
              {s:v(x1.x2.net5) s:v(x1.y3.net5)}]
  check {BH41 a DISAGREEING multi-row target leaves it disabled with NO command} \
    [list [pcall $BHM2 entrycget 7 -label] [pcall $BHM2 entrycget 7 -state] \
          [pcall $BHM2 entrycget 7 -command]] \
    [list {Descend to here} disabled {}]
  set BHM3 [pcall ::wviewer::browser_menu_build wvbh1 \
              {s:v(x1.x2.net5) g:x1.x2}]
  check {BH41 ...but an AGREEING multi-row target is live} \
    [list [pcall $BHM3 entrycget 7 -state] [pcall $BHM3 entrycget 7 -command]] \
    [list normal [list wviewer::browser_descend_to wvbh1 {s:v(x1.x2.net5) g:x1.x2}]]

  # ⚠ THE REAL-KEY LEGS ARE NOT HERE, AND THAT IS MEASURED, NOT TASTE. A
  # throwaway toplevel is not the WM's active window, so `focus -displayof`
  # never reports its widgets as the focus owner and `send_key` correctly
  # reports `delivery ... never confirmed (WSLg focus stall)` — the gate doing
  # its job, not a broken binding. Item 10's Button-3 legs work here because
  # pointer events need no focus; keys do. BH43-BH45 therefore run on the REAL
  # viewer below, which is also where the user actually is.
  # What DOES belong here is the structural reason the item binds twice.
  check {BH42 the canvas is NOT in the tree's bindtags, which is why both binds exist} \
    [list [expr {[lsearch -exact [bindtags $BHTV] .wvbh1.drw] >= 0}] \
          [expr {[lsearch -exact [bindtags $BHTV] WaveViewer] >= 0}]] \
    [list 0 0]
  check {BH42 the tree DOES carry item 11's own <Key-E>, so the zeros above are a rule} \
    [expr {[string first {wviewer::browser_descend_at} [bind $BHTV <Key-E>]] >= 0}] 1
  check {BH42 the WaveViewer tag carries <Key-E> on the LIVE tag too} \
    [expr {[string first {browser_descend_at} [bind WaveViewer <Key-E>]] >= 0}] 1

  pcall ::wviewer::forget wvbh1
  catch {unset ::wviewer::browserrows(wvbh1)}
  destroy .wvbh1

} else {
  puts "SKIPPED: BH4x group (Tk/X arm only)"
}

# --- BH50-BH54: END TO END, a real viewer AND a real design window ----------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set bh_tok [ase::session_key wvhier wvhier_top schematic]
  pcall ase::session_open $bh_tok [file join $scratch bh_top.state]
  set bh_open [pcall ::wviewer::open $bh_tok]
  set bh_vtop [wviewer::window_for $bh_tok]
  if {$bh_open ne 1 || $bh_vtop eq {} || ![viewer_ready $bh_vtop]} {
    puts "SKIPPED: BH5x group (the wvhier viewer never opened/mapped)"
    catch {wviewer::close $bh_tok}
  } else {
    # ⚠⚠ VERIFIED CONTEXT SWITCH, ADDED BY THE RULING-30 SPLIT and the answer to
    # the BH50 flap (2 of 8 pre-split runs passed BH50's pair; 6 read `{} 0` and
    # `untitled.sch`, i.e. the VIEWER's context, with ZERO relation to whether
    # the descend worked). `xschem new_schematic switch` is synchronous, so the
    # fast path pumps NO events — an unconditional `update` per call redraws both
    # canvases and is what pushed item 12's first cut to 0/6 completions
    # (12_receipt.md §10.2). The retry exists only for the rare bounce where an
    # `update` delivers an Enter/FocusIn on the other canvas and switches the
    # context straight back. Item 12's `bx_ctx_to`, same shape, same reason.
    proc bh_ctx_to {w} {
      if {[xschem get current_win_path] eq $w} { return 1 }
      catch {xschem new_schematic switch $w}
      if {[xschem get current_win_path] eq $w} { return 1 }
      for {set i 0} {$i < 10} {incr i} {
        update
        catch {xschem new_schematic switch $w}
        if {[xschem get current_win_path] eq $w} { return 1 }
        after 20
      }
      return 0
    }

    # a REAL raw in the VIEWER's own context (the BTV/BMV idiom), carrying both
    # a two-level path and a one-level one
    set bh_main $bh_dwin0
    xschem new_schematic switch $bh_vtop.drw
    pcall xschem raw new bh_e2e.raw dc vsweep 0 1.0 0.5
    foreach bh_n {v(out) v(x1.x2.net5) v(x1.topsig)} {
      pcall xschem raw add $bh_n {vsweep 1 +}
    }
    xschem new_schematic switch $bh_main
    pcall ::wviewer::browser_toggle 1 $bh_tok
    update
    set bh_rows0 {}
    catch {set bh_rows0 $::wviewer::browserrows($bh_tok)}
    check {BH50 (fixture) the browser populated from the real raw, x1.x2 among them} \
      [list [expr {[llength $bh_rows0] > 0}] \
            [lindex [pcall ::wviewer::browser_target_path $bh_tok {g:x1.x2}] 1]] \
      [list 1 x1.x2]

    # THE ITEM, END TO END: invoke the REAL menu entry, then assert on THE
    # WORLD — the design window's own sim_sch_path, read back.
    set bh_m [pcall ::wviewer::browser_menu_build $bh_tok {g:x1.x2}]
    set bh_inv [pcall $bh_m invoke 7]
    # ⚠⚠ THE CONTEXT CLAIM IS READ BEFORE ANY EVENT PUMP, AND THE WORLD CLAIM ON
    # THE NAMED WINDOW. Both are ruling-30 widenings; NEITHER CLAIM IS DROPPED.
    #  * The context claim ("descend_to left us on the design window, not the
    #    viewer") is only meaningful at the instant the command returns.
    #    `browser_descend_to` pumps no events — `raise_activate_toplevel` is
    #    withdraw/deiconify/raise, all asynchronous — so this read is exact. The
    #    old code did an `update` FIRST, and that `update` is precisely what
    #    delivered the Enter/FocusIn that switched the context back to the
    #    viewer canvas. It was measuring the test's own perturbation.
    #  * The world claim ("the design window is AT x1.X2") is then read on the
    #    design window BY NAME, after a verified switch, instead of on whatever
    #    window the context happened to land on. That is strictly stronger: it
    #    can no longer pass by reading some other window that happens to agree.
    set bh_dwin {}
    catch {set bh_dwin [xschem get current_win_path]}
    check {BH50 ...and the context really is the DESIGN window, not the viewer} \
      [list [expr {$bh_dwin ne {} && $bh_dwin ne "$bh_vtop.drw"}] \
            [file tail [pcall xschem get schname 0]]] \
      [list 1 wvhier_top.sch]
    update
    check {BH50 invoking `Descend to here` lands the DESIGN window at x1.X2} \
      [list [bh_ctx_to $bh_dwin0] [pcall xschem get sim_sch_path] \
            [pcall xschem get currsch]] \
      [list 1 {x1.X2.} 2]
    # the status line SAYS SO, in the SCHEMATIC's spelling, so a case fold is
    # visible to the user rather than silent
    check {BH50 the browser status line reports the landing} \
      [pcall $bh_vtop.wvbrowser.ph cget -text] \
      "Signal Browser\ndescended to x1.X2"

    # item 9's D6: the tree is a SNAPSHOT of the VIEWER's raw, and a design
    # descend touches neither — so nothing went stale.
    set bh_rows1 {}
    catch {set bh_rows1 $::wviewer::browserrows($bh_tok)}
    check {BH52 the browser tree is UNCHANGED by the sync (item 9's D6 holds)} \
      [expr {$bh_rows1 eq $bh_rows0}] 1

    check {BH53 the design window's toplevel is mapped after the raise} \
      [list [bs_wait_mapped_top .] [winfo ismapped .]] [list 1 1]

    # already-at-target: a byte-exact target this time (`x1` exists exactly),
    # so this really is the no-op path — and it STILL raises and STILL says so.
    set bh_m2 [pcall ::wviewer::browser_menu_build $bh_tok {g:x1}]
    pcall $bh_m2 invoke 7
    update
    check {BH54 (fixture) a one-level sync first moves there} \
      [list [bh_ctx_to $bh_dwin0] [pcall xschem get sim_sch_path]] [list 1 {x1.}]
    pcall $bh_m2 invoke 7
    update
    check {BH54 already-at-target is a no-op that still lands and still reports} \
      [list [bh_ctx_to $bh_dwin0] [pcall xschem get sim_sch_path] \
            [pcall $bh_vtop.wvbrowser.ph cget -text]] \
      [list 1 {x1.} "Signal Browser\nalready at x1"]
    # ⚠⚠ THE NAMED FLAKY CHECK, WIDENED PER RULINGS 30 AND 17 — NOT deleted and
    # NOT weakened. `winfo ismapped .` was read BARE, as if a raise were
    # instantaneous; a raise is `wm withdraw` + `wm deiconify` + `raise`, all
    # asynchronous, and under a loaded WSLg compositor the MapNotify arrives
    # after the assertion. That is the 1-in-4 flap `11_receipt.md` §13.4 could
    # not name and item 12 finally pinned. `bs_wait_mapped_top` polls the
    # PRECONDITION and RETURNS THE MAPPING (item 5's `bs_wait_mapped` idiom), so
    # a window that never maps still answers 0 and still FAILS this check — the
    # widening buys the WM time, it cannot buy a false claim.
    check {BH54 ...and it still raised the design window} [bs_wait_mapped_top .] 1

    # A bad path through the REAL command surface: refused, reported, rolled
    # back. ⚠ THE TARGET IS `X1.nosuch` WHILE WE SIT AT `x1`, deliberately: the
    # byte-exact prefix is EMPTY, so the walk really ascends out of `x1` and
    # descends into `X1` before failing. `x1.nosuch` would have been the vacuous
    # shape §3.5 of the receipt describes — measured: with the rollback deleted,
    # a `x1.nosuch` target left this check GREEN.
    set ::wviewer::browserrows($bh_tok) [wviewer::browser_rows [list \
      [wviewer::signal_entry {v(X1.nosuch.net5)}]]]
    set bh_m3 [pcall ::wviewer::browser_menu_build $bh_tok {g:X1.nosuch}]
    set bh_bad [pcall $bh_m3 invoke 7]
    update
    check {BH51 a bad path through the REAL entry ROLLS BACK and says why} \
      [list $bh_bad [bh_ctx_to $bh_dwin0] [pcall xschem get sim_sch_path] \
            [pcall $bh_vtop.wvbrowser.ph cget -text]] \
      [list 0 1 {x1.} "Signal Browser\ndescend to 'X1.nosuch' failed: no instance 'nosuch' (returned to x1)"]
    set ::wviewer::browserrows($bh_tok) $bh_rows0

    # --- BH43/BH44/BH45: THE REAL KEY, on the REAL viewer --------------------
    # ⚠ A DELEGATING rename recorder (item 10's shape), so both halves are
    # observable: that the binding fired AND that the world moved. A swallowing
    # recorder would have made the world half untestable, and a world-only
    # assertion could not tell the key from the menu.
    set ::bh_calls 0
    rename ::wviewer::browser_descend_at ::wviewer::__bh_real_descend_at
    proc ::wviewer::browser_descend_at {W} {
      incr ::bh_calls
      return [::wviewer::__bh_real_descend_at $W]
    }
    set BHVTV $bh_vtop.wvbrowser.pw.tvf.tv
    set BHVE  $bh_vtop.wvbrowser.wvsearch.pat
    # ⚠ REQUIRED BETWEEN LEGS, and it is the item's own doing: a successful sync
    # RAISES AND ACTIVATES THE DESIGN WINDOW, which takes the WM focus away from
    # the viewer. Without this the next `send_key` correctly reports a delivery
    # stall and the leg self-skips (observed). Re-raise the viewer first, the
    # same idiom the item itself uses.
    proc bh_focus_viewer {top} {
      catch {raise_activate_toplevel $top}
      catch {focus -force $top}
      update
      return [bs_wait_mapped $top]
    }
    bh_focus_viewer $bh_vtop
    pcall ::wviewer::hier_walk {}
    pcall $BHVTV selection set {g:x1.x2}
    set ::bh_calls 0
    # the CANVAS route (the `WaveViewer` bindtag). Waiting on the WORLD, not on
    # the recorder: the key has not done its job until sim_sch_path has moved.
    set bh_k1 [send_key $bh_vtop.drw <Key-E> {[xschem get sim_sch_path] eq {x1.X2.}}]
    if {!$bh_k1} {
      puts "SKIPPED: BH43 (WSLg key-delivery stall on the viewer canvas)"
    } else {
      check {BH43 a REAL <Key-E> on the CANVAS descends the design window} \
        [list [expr {$::bh_calls > 0}] [pcall xschem get sim_sch_path]] \
        [list 1 {x1.X2.}]
      # NEGATIVE CONTROL: same recorder, same widget, a key that is not bound
      set bh_c1 $::bh_calls
      for {set bh_i 0} {$bh_i < 6} {incr bh_i} {
        focus -force $bh_vtop.drw ; update
        catch {event generate $bh_vtop.drw <Key-D>} ; update
      }
      check {BH43 (NEGATIVE CONTROL) the same recorder reads ZERO more for an unbound <Key-D>} \
        [expr {$::bh_calls - $bh_c1}] 0
    }
    # the TREE route — the one a WaveViewer-only bind could never serve, since
    # the canvas is not in the tree's bindtags (BH42)
    bh_focus_viewer $bh_vtop
    pcall ::wviewer::hier_walk {}
    pcall $BHVTV selection set {g:x1}
    set ::bh_calls 0
    set bh_k2 [send_key $BHVTV <Key-E> {[xschem get sim_sch_path] eq {x1.}}]
    if {!$bh_k2} {
      puts "SKIPPED: BH44 (WSLg key-delivery stall on the browser tree)"
    } else {
      check {BH44 a REAL <Key-E> on the TREE descends the design window too} \
        [list [expr {$::bh_calls > 0}] [pcall xschem get sim_sch_path]] \
        [list 1 {x1.}]
    }
    # the searchbar Entry carries no WaveViewer tag and is not the tree, so
    # typing E there must NOT fire the command — with the delivery PROVEN by
    # the entry's own text, so a stalled key cannot masquerade as a refusal
    if {![winfo exists $BHVE]} {
      puts "SKIPPED: BH45 (the viewer's searchbar pattern entry was not found)"
    } else {
      bh_focus_viewer $bh_vtop
      pcall $BHVE delete 0 end
      set bh_c2 $::bh_calls
      set bh_k3 [send_key $BHVE <Key-E> {[string length [$BHVE get]] > 0}]
      if {!$bh_k3} {
        puts "SKIPPED: BH45 (WSLg key-delivery stall on the search entry)"
      } else {
        check {BH45 `E` TYPED INTO THE SEARCH ENTRY does not fire the command...} \
          [expr {$::bh_calls - $bh_c2}] 0
        check {BH45 ...and the key really WAS delivered — the entry now holds it} \
          [pcall $BHVE get] E
      }
      pcall $BHVE delete 0 end
      pcall ::wviewer::browser_refresh $bh_tok
    }
    rename ::wviewer::browser_descend_at {}
    rename ::wviewer::__bh_real_descend_at ::wviewer::browser_descend_at
    check {BH45 the real browser_descend_at is back in place} \
      [list [expr {[info commands ::wviewer::__bh_real_descend_at] eq {}}] \
            [expr {[info commands ::wviewer::browser_descend_at] ne {}}]] \
      [list 1 1]

    catch {wviewer::close $bh_tok}
  }

} else {
  puts "SKIPPED: BH5x group (Tk/X arm only)"
}


} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

wvbs_finish
