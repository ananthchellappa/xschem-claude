# Action-log GREP GUARD (issue 0071 atom 5) -- an executable inventory of the
# self-log-at-core migration, so the invariants cannot silently regress.
#
# The audit's root-cause finding: "we logged verb X, but only from the menu, not
# the key" recurred 3+ times AFTER being named -- human discipline does not hold.
# This test makes the discipline structural, in four static scans + one runtime
# canary:
#   S1  MANIFEST -- every landed self-log site still contains its log_action call
#       (a refactor that drops one fails exactly that row). Gate-locking rows pin
#       the save `!fast` and Ctrl-S `!readonly` guards, not just the calls.
#   S2  TCL LITERAL-LOG CONFLICTS -- no .tcl file hand-logs a literal
#       "xschem <verb>" line for a verb whose C side self-logs, unless the write
#       is dedup-gated on `log_action -emitted` (the action_reload double of
#       atom 4 and the library_manager `load -gui` double fixed with this atom
#       are exactly this class).
#   S3  BRANCH-MUST-NOT-LOG -- verbs whose log lives in a core C function
#       (save.c/actions.c/select.c) must have NO log_action in their scheduler
#       branch, or menu/script paths double-log (the slice-6 lesson).
#   S4  RECORDER DEDUP WIRING -- the four dedup-wired recorders keep their
#       reset/-emitted plumbing; losing it double-logs every covered verb.
#   S5  RUNTIME CANARY -- a cheap end-to-end exactly-once check (script path +
#       menu_action_logged dedup), so a suppress-flag/dedup breakage that static
#       text scans cannot see still fails.
#
# MAINTENANCE: adding a new C self-log means (a) adding its S1 manifest row and
# (b) adding the verb to the S2 conflict set. That is the intended ratchet.
# Atom 9 (0069 paste_at) added: the paste/merge drop-log site + merge_source
# stash rows, the scheduler paste replay-arm rows, `paste` in S2 + S3, and the
# S1c must-NOT-reappear scans (old marker / ctx-menu pick-8 literal).
# Atom 11 (0069 sympin) added: the START_SYMPIN drop-log sites (the sympin
# add_symbol_pin line + the shared log_placed_instance read-back), the scheduler
# add_symbol_pin no-line/writeback replay-arm rows, `add_symbol_pin`/`add_sch_pin`
# in S2 + S3 (the drop funnel is the SOLE logger), and the S1c scan for the old
# `# place symbol pin` marker.
# Refactor B atom 1 (perform_action / trim_wires) MOVED the two trim_wires S1
# log rows (scheduler.c branch + callback.c '&' key) onto the perform_action
# boundary rows (the branch `return perform_action(...)`, the '&' key call, and
# the boundary's ONE readonly gate + ONE log site), and added the S7 exclusivity
# block. trim_wires stays in S2 CVERBS, stays OUT of S3.
# Refactor B atom 3 (perform_action / rotate_in_place) MOVED the rotate_in_place S1
# rows onto boundary rows: the scheduler branch STANDALONE arm (`return perform_action`)
# and the TWO callback.c standalone entry points (the Alt-R single-object
# standalone_group_transform + the verb-noun MENUSTARTROTATE deferred apply, count 2 on
# `perform_action("rotate_in_place", 0, NULL)`), and extended the S7 block (scheduler.c +
# callback.c: NO scattered log_action("xschem rotate_in_place"); scheduler.c: NO scattered
# readonly_reject for it). The UNIQUE wrinkle vs atoms 1-2: rotate_in_place has a
# mid-gesture split -- ONLY the standalone verb crosses the boundary; the during-move/
# during-copy arms stay RAW and log at move/copy END (0069). rotate_in_place stays in S2
# CVERBS, stays OUT of S3.
# Refactor B atom 4 (perform_action / flip_in_place) is the exact MIRROR of atom 3: MOVED the
# flip_in_place S1 rows onto boundary rows -- the scheduler branch STANDALONE arm
# (`return perform_action`) and the TWO callback.c standalone entry points (the Alt-F single-object
# standalone_group_transform else-arm + the verb-noun MENUSTARTROTATE PENDING_TR_FLIP_IP apply, count
# 2 on `perform_action("flip_in_place", 0, NULL)`), and extended the S7 block (scheduler.c +
# callback.c: NO scattered log_action("xschem flip_in_place"); scheduler.c: NO scattered
# readonly_reject for it). Same mid-gesture split as atom 3. flip_in_place stays in S2 CVERBS, stays
# OUT of S3.
# Refactor B atom 5 (perform_action / flipv_in_place) migrates the LAST in-place transform:
# MOVED the flipv_in_place S1 rows onto boundary rows -- the scheduler branch STANDALONE arm
# (`return perform_action`) and the TWO callback.c standalone entry points (the Alt-V single-inline
# standalone apply -- Alt-V has NO standalone_group_transform / no issue-0116 group form -- + the
# verb-noun MENUSTARTROTATE PENDING_TR_FLIPV_IP apply, count 2 on
# `perform_action("flipv_in_place", 0, NULL)`), and extended the S7 block (scheduler.c + callback.c:
# NO scattered log_action("xschem flipv_in_place"); scheduler.c: NO scattered readonly_reject for it).
# flipv_in_place is THREE move_objects calls (ROTATE|ROTATELOCAL x2 + FLIP|ROTATELOCAL, a net vertical
# mirror), not one -- but the boundary row is the same shape. Same mid-gesture split as atoms 3/4.
# flipv_in_place stays in S2 CVERBS, stays OUT of S3. After atom 5 ALL FOUR in-place transforms
# (rotate/flip/flipv) are on the boundary -- no scattered log_action for any remains.
# Refactor B atom 6 (perform_action / rotate -- the pivot form `xschem rotate x0 y0`) migrates the
# FIRST ARG-CARRYING verb: unlike the bare in-place quartet, rotate threads a SHARED pivot x0,y0
# through BOTH halves of the boundary. run_core's rotate arm resolves x0,y0 from argv[2]/argv[3]
# (else the mouse coords) and the NEW core_log_action (the §4 log-form registry SEED) formats
# `xschem rotate x0 y0` from the SAME argv -- so effect and log pivot cannot diverge. This atom
# CHANGED THE ONE LOG SITE: perform_action now calls core_log_action(verb,argc,argv) instead of a
# bare log_action("xschem %s", verb) (the bare-verb output is byte-identical -- core_log_action's
# else branch). It MOVED rotate's S1 rows: the scheduler branch STANDALONE arm (`return
# perform_action("rotate", argc, argv)`) + the THREE callback.c standalone entry points (the Shift-R
# key, the Alt-R GROUP standalone_group_transform arm, and the verb-noun MENUSTARTROTATE
# PENDING_TR_ROTATE apply -- count 3 on `perform_action("rotate", 4, av)`). The S7 scoping is SUBTLER
# than the bare verbs: core_log_action legitimately CONTAINS one `log_action("xschem rotate %...")`
# (the pivot format), so scheduler.c cannot forbid ALL of them -- it must have EXACTLY ONE (the
# core_log_action site) with the scheduler BRANCH carrying none, while callback.c must have ZERO. The
# literal `rotate %` (rotate+space+%) regex does NOT match `rotate_in_place` (no space after rotate),
# and `"rotate"` (rotate+quote) does NOT match `"rotate_in_place"` -- so the two verbs are counted
# independently. The mid-gesture STARTMOVE/STARTCOPY arms (scheduler branch + Shift-R key) stay raw
# and log NOTHING (move/copy END, 0069). rotate stays in S2 CVERBS, stays OUT of S3.
# Refactor B atom 7 (perform_action / flip -- pivot form `xschem flip x0 y0`) migrated the SECOND
# arg-carrying verb, a near-clone of rotate: one run_core arm + one core_log_action `flip` branch,
# MOVED flip's S1 rows onto the boundary (scheduler `return perform_action("flip", argc, argv)` +
# THREE callback.c `perform_action("flip", 4, av)` -- Shift-F key + Alt-F GROUP standalone_group_transform
# else-arm + verb-noun PENDING_TR_FLIP), and extended S7 with the flip EXACTLY-ONE scoping.
# Refactor B atom 8 (perform_action / flipv -- pivot form `xschem flipv x0 y0`) migrated the THIRD and
# LAST arg-carrying pivot verb, the MIRROR of flip: one run_core arm (the THREE-move vertical mirror
# ROTATE, ROTATE, FLIP -- NO ROTATELOCAL, the atom-5-class order hazard) + one core_log_action `flipv`
# branch, MOVED flipv's S1 rows onto the boundary (scheduler `return perform_action("flipv", argc, argv)`
# + TWO callback.c `perform_action("flipv", 4, av)` -- the Shift-V key + verb-noun PENDING_TR_FLIPV;
# count TWO not three -- flipv has NO group form), removed the callback `log_action("xschem flipv %")`
# rows, and extended S7 with the flipv EXACTLY-ONE scoping (+ two flip-unperturbed guards). The literal
# `flipv %` regex does NOT match `flip %` (a `v` intervenes) nor `flipv_in_place`. After atom 8 the whole
# transform SEXTET (rotate/flip/flipv x pivot + in-place) is on the boundary and the shared verb-noun
# START/switch/END block is GONE (six boundary else-if arms). flipv stays in S2 CVERBS, OUT of S3.
# Refactor B atom 9 (perform_action / break_wires) migrated the FIRST NON-transform verb, the
# wire-surgery SIBLING of trim_wires (atom 1): one run_core arm (break_wires_at_pins(remove), which
# owns its OWN push_undo/draw -- no double-push) + one core_log_action `break_wires` branch that
# canonicalizes the FLAG (remove -> `xschem break_wires 1`, else bare `xschem break_wires`). The arg is
# a FLAG (0/1), NOT a coordinate pivot, and there is NO mid-gesture split (break_wires is not a
# transform). MOVED break_wires's S1 rows onto the boundary: the scheduler branch
# (`return perform_action("break_wires", argc, argv)`) + TWO callback.c entries (the '!' key bare
# `perform_action("break_wires", 0, NULL)` and the Ctrl-! key remove `perform_action("break_wires", 3, av)`
# with av[2]="1"), REMOVED the callback `log_action("xschem break_wires[ 1]")` rows, and extended S7 with
# the break_wires exclusivity block. Like the pivot verbs, core_log_action legitimately holds the log
# lines, so scheduler.c must have EXACTLY TWO (one bare + one remove form, both in core_log_action) and
# callback.c ZERO. The literals `break_wires 1"` (space+1 before the quote) and `break_wires")` (quote
# then paren) are mutually exclusive and counted independently -- a re-scattered branch log of EITHER
# fails closed; neither matches break_wires_at_pins / break_wires_at_point / break_wires_at_attach_points
# (an `_` follows). break_wires stays in S2 CVERBS, OUT of S3. break_wires_at_pins() is 1:1 with the verb
# (called only by its own entry points) while break_wires_at_point (the Alt-Right wire_cut gesture) stays
# a SEPARATE verb+gesture, off this boundary.
# Refactor B atom 10 (perform_action / floaters_from_selected_inst) migrated the SECOND non-transform verb,
# the FIRST after the wire-surgery pair. A BARE no-arg verb (no pivot, no flag, no mid-gesture split -- even
# simpler than break_wires), so its run_core arm is `floaters_from_selected_inst(); return TCL_OK;` (the core
# owns its OWN push_undo/set_modify/draw -- no double-push) and its log is the shared bare `xschem %s`
# core_log_action DEFAULT line (NO per-verb branch, like trim_wires/align/in-place). MOVED floaters's single
# S1 row from the scheduler `log_action("xschem floaters_from_selected_inst")` onto the boundary row
# (`return perform_action("floaters_from_selected_inst", argc, argv)`), and added a 3-check S7 block MIRRORING
# trim_wires (scheduler.c + callback.c ZERO scattered `log_action("xschem floaters_from_selected_inst")` +
# scheduler.c ZERO scattered readonly_reject). floaters_from_selected_inst() is strictly 1:1 (the ONLY caller
# is this verb's own scheduler branch -- NO key, NO other C caller), so unlike trim_wires there is no
# sub-step lock to add. NB the branch NEVER HAD a scheduler_readonly_reject -- floaters mutates, so the
# boundary's generic gate CLOSES a scattered 0041/0051 read-only gap (it now refuses on a read-only cell).
# floaters stays in S2 CVERBS, OUT of S3.
# Refactor B atom 11 (perform_action / attach_labels) migrated the THIRD non-transform verb. Its arg is a
# FLAG `interactive` read from argv[2] (like break_wires) but 0/1/2 carry DISTINCT meanings, so its run_core
# arm PRESERVES the value -- `int interactive=0; if(argc>2) interactive=atoi(argv[2]); attach_labels_to_inst(
# interactive);` (the core OWNS its own push_undo via place_symbol/set_modify/draw -- no double-push) -- and
# its core_log_action branch emits TWO forms (`xschem attach_labels %d` for argc>2 preserving the value,
# `xschem attach_labels` for argc==2), reproducing the old branch's log_action_argv byte-for-byte. MOVED the
# branch's self-log OFF its old `log_action_argv(argc, argv)` (which the branch shared with several other
# verbs, so it had NO dedicated S1 row) onto the boundary row (`return perform_action("attach_labels", argc,
# argv)`), added the two core_log_action VALUE/BARE S1 rows, and added an S7 block MIRRORING break_wires
# (arg-carrying, TWO forms): scheduler.c EXACTLY ONE of each form + EXACTLY TWO total, callback.c ZERO,
# scheduler.c ZERO scattered readonly_reject. UNLIKE break_wires/floaters, attach_labels_to_inst() is NOT
# strictly 1:1 (like trim_wires atom 1): it is ALSO called RAW below the boundary by show_unconnected_pins()
# (netlist.c, a netlisting sub-step) and by the Shift+H interactive-DIALOG key (act_attach_labels, registered
# csv-nolog non-equivalent path) -- both stay off the boundary and never self-log (the runtime .tcl case (e)
# locks it). The branch NEVER HAD a scheduler_readonly_reject -- attach_labels mutates in every 0/1/2 form
# (none is a read-only-safe query, unlike check_unique_names §30), so the boundary's generic gate CLOSES a
# scattered 0041/0051 read-only gap. attach_labels stays in S2 CVERBS, OUT of S3.
# Refactor B atom 12 (perform_action / toggle_ignore) migrated the FIRST FRICTION-FREE-SCOUTED verb (the
# exhaustive classification in perform_action_boundary_migration_friction_analysis.md scored all 243 mutating
# scheduler verbs; toggle_ignore was the cleanest of three). A BARE no-arg verb like floaters: one run_core
# arm (`toggle_ignore(); return TCL_OK;`, the core owns its OWN push_undo/set_modify/draw -- no double-push)
# and NO core_log_action branch (it rides the shared bare `xschem %s` DEFAULT). The migration is PURELY
# ADDITIVE: this branch logged NOTHING and had NO readonly gate before, so the boundary ADDS BOTH (a new S1
# scheduler boundary row + the readonly gate, a 0041/0051 close). Added an S7 block MIRRORING floaters
# (scheduler.c + callback.c ZERO scattered `log_action("xschem toggle_ignore")` + scheduler.c ZERO scattered
# readonly_reject). The KEY-EQUIVALENCE INVERSION of attach_labels (§31): toggle_ignore's Shift+T key is
# EQUIVALENT (same core, csv NOT-nolog), so it routes THROUGH the boundary -- ADDING the callback.c S1 key row
# `perform_action("toggle_ignore", 0, NULL)`. Re-verifying from source overturned the scout's premise: the key
# was NOT a coverage hole -- it was ALREADY gated (registry mutates=1 -> readonly_block) and ALREADY logged
# (Layer A d->log_cmd from actions.csv), so routing it is a CONSISTENCY move whose correctness rests on the
# actionlog_cmd_logged DEDUP (the boundary log sets the flag, Layer A skips -> ONE line). The S1 key row is the
# load-bearing lock: the runtime output is identical whether the key uses Layer A or core_log_action, so only
# this grep row catches a raw-core key regression. toggle_ignore stays in S2 CVERBS, OUT of S3.
# Refactor B atom 13 (perform_action LOG-ON-SUCCESS + reset_inst_prop) is the FIRST shared-machinery atom:
# it CHANGED the boundary itself so the log site + the interp reset fire only on rc==TCL_OK, then migrated the
# first verb the change unblocks (reset_inst_prop, the FIRST VALIDATING verb -- it rejects a bad arg with an
# early TCL_ERROR before mutating). Grep changes: (a) the S1 log-site row's regex UPDATED from
# `if(!actionlog_suppress) core_log_action(...)` to `if(rc == TCL_OK && !actionlog_suppress) core_log_action(...)`
# (it fails closed if the guard is reverted -- the correct signal), plus a NEW S1 row pinning the success-only
# `Tcl_ResetResult(interp);   /* clear on success ONLY` (the landmine: it must stay coupled to the log-on-success
# guard so a failed validating call's error message survives); (b) a NEW S1 boundary-branch row + a NEW S1
# core_log_action `xschem reset_inst_prop %s` name-form row; (c) reset_inst_prop ADDED to S2 CVERBS, kept OUT of
# S3; (d) an S7 block (single-form arg-carrying, like rotate/flip: EXACTLY ONE core_log_action site in
# scheduler.c, ZERO in callback.c, ZERO scattered readonly_reject -- the old branch HAD a per-verb one, now GONE).
# Refactor B atom 14 (perform_action / replace_symbol) is a PLAIN per-verb migration onto the UNCHANGED
# atom-13 log-on-success boundary (NO shared-machinery change): the SECOND VALIDATING verb, and the FIRST
# per-verb migration to carry a FAST-FLAG log gate. Grep changes: (a) a NEW S1 boundary-branch row + a NEW
# S1 two-arg referent-build row (`av[3] = argv[3];` -- UNIQUE to replace_symbol) + a NEW S1
# `log_action_argv(4, av)` emit row (distinct from reset_inst_prop's `(3, av)`) + a NEW S1 FAST-FLAG GATE
# row (`if(argc <= 4 || strcmp(argv[4], "fast"))` -- a revert to unconditional logging makes the fast
# machinery form log, failing test (e) closed); (b) replace_symbol ADDED to S2 CVERBS, kept OUT of S3;
# (c) an S7 block (EXACTLY ONE av[3]-build + ONE log_action_argv(4,av) + ONE fast-gate in scheduler.c,
# ZERO scattered raw log / readonly_reject in scheduler.c, ZERO in callback.c). NB atom 14's two-arg
# build line `av[0] = "xschem"; av[1] = verb; av[2] = argv[2]; av[3] = argv[3];` is a SUPERSTRING of
# atom-13's reset_inst_prop build, so the reset_inst_prop S1/S7 referent regexes were LINE-ANCHORED
# (`(?n)...;$`) to stay collision-proof (they end at `argv[2];`, replace_symbol continues to `argv[3];`).
# Refactor B atom 15 (perform_action / show_unconnected_pins) is a PLAIN per-verb migration onto the
# UNCHANGED atom-13 log-on-success boundary (NO shared-machinery change): a BARE no-arg verb like
# floaters (atom 10) / toggle_ignore (atom 12) -- the friction-free verb from the fresh atom-15 fan-out
# scout (the atom-14 validating shortlist was EXHAUSTED). It is the SECOND verb to share the
# attach_labels_to_inst() core after atom 11: its core show_unconnected_pins() (netlist.c) calls
# attach_labels_to_inst(2) RAW, which OWNS the undo/set_modify/draw (no double-push) and stays SILENT
# below the boundary (its log lives under the `attach_labels` verb in core_log_action, NOT in the C fn --
# the atom-11 shared-sub-step lock), so routing show_unconnected_pins double-logs NOTHING with attach_labels.
# Grep changes: (a) a NEW S1 boundary-branch row; its log is the shared bare `xschem %s` core_log_action
# DEFAULT (NO per-verb branch, like floaters/toggle_ignore -- so NO new core_log_action S1 row, just the
# roster note on the `%s` row); (b) show_unconnected_pins ADDED to S2 CVERBS, kept OUT of S3; (c) an S7
# block MIRRORING floaters/toggle_ignore (scheduler.c + callback.c ZERO scattered `log_action("xschem
# show_unconnected_pins")` + scheduler.c ZERO scattered readonly_reject -- the branch never had one; the
# boundary ADDS the readonly gate as a correctness fix, the old branch placed labels on a read-only cell).
# Refactor B atom 16 (perform_action / embed_rawfile) is a PLAIN per-verb migration onto the UNCHANGED
# atom-13 log-on-success boundary (NO shared-machinery change): the DEFERRED runner-up from the atom-15
# fan-out scout (the scout left EXACTLY TWO friction-free candidates -- show_unconnected_pins = atom 15,
# embed_rawfile = atom 16; the pool is now EXHAUSTED). embed_rawfile is a HYBRID: the reset_inst_prop §33
# SINGLE-STRING-referent + argc-GATE template (a VALIDATING-LITE argc<3 early TCL_ERROR; the RAW argv[2]
# file path logged via log_action_argv/Tcl_Merge so a metachar path replays + the `~/` re-expands) crossed
# with the floaters/show_unconnected_pins §30/§35 CORE-OWNS-ITS-OWN-UNDO template (embed_rawfile() (draw.c)
# owns the single push_undo + set_modify -- run_core adds none, no double-push). The `~/` expansion MOVES
# from the scheduler branch into run_core (via the home_dir global). Grep changes: (a) a NEW S1
# boundary-branch row + a NEW S1 referent-build row (`ev[0]=xschem; ev[1]=verb; ev[2]=argv[2];` -- NOTE the
# array is `ev`, NOT `av`, so its line-anchored (?n)...;$ regex stays TEXTUALLY DISTINCT from
# reset_inst_prop's byte-identical `av[...]` build; a shared name would make each verb's count == 2, the
# COLLISION the task flags) + a NEW S1 `log_action_argv(3, ev)` emit row (distinct from reset_inst_prop's
# `(3, av)` and replace_symbol's `(4, av)`); (b) embed_rawfile ADDED to S2 CVERBS, kept OUT of S3; (c) an
# S7 block (EXACTLY ONE ev-build + ONE log_action_argv(3, ev) + ZERO scattered raw log/readonly_reject in
# scheduler.c, ZERO in callback.c) PLUS a COLLISION GUARD re-asserting reset_inst_prop's av-build + (3, av)
# stay == 1. The branch NEVER had a scheduler_readonly_reject; the boundary ADDS one as a CORRECTNESS FIX
# (the old branch embedded on a read-only cell). embed_rawfile is a PURE SCRIPTED verb (no key/menu/
# palette/callback/Tcl caller), so NO callback.c edit and NO key-equivalence decision.
# Refactor B atom 17 (perform_action / wire_cut) is the SILENT-MUTATOR twin of break_wires (atom 9,
# §29): break_wires_at_point (check.c) is the SEPARATE Alt-Right wire_cut gesture core that §29 kept
# OFF break_wires' boundary; atom 17 puts it on. It logged NOTHING before. Structural mirror of
# break_wires: the core OWNS a CONDITIONAL single push_undo (only when a wire is actually split) + its
# own draw, so run_core adds NEITHER (no double-push; a point-off-wire no-op pushes nothing yet returns
# TCL_OK -> no-op-still-logs). The arg is numeric COORDS + a bareword FLAG (%.16g coord log, the
# rotate/flip convention -- NOT log_action_argv, no metacharacter referent), in TWO forms like
# break_wires (aligned `xschem wire_cut x y` + `xschem wire_cut x y noalign`). It carries a MID-GESTURE
# SPLIT like rotate/flip: only the SCRIPTED coord form (scheduler branch argc>3) crosses; the no-coord
# GESTURE-START form stays RAW (arms ui_state, no mutation, no log). Grep changes: (a) a NEW S1
# boundary-branch row + TWO NEW S1 core_log_action form rows (aligned `wire_cut %.16g %.16g"` +
# noalign `wire_cut %.16g %.16g noalign`); (b) wire_cut ADDED to S2 CVERBS, kept OUT of S3; (c) an S7
# block MIRRORING break_wires (EXACTLY TWO total, ONE of each form, ZERO bare, ZERO scattered
# log/readonly_reject in scheduler.c, ZERO in callback.c). The branch NEVER had a
# scheduler_readonly_reject; the boundary ADDS one as a CORRECTNESS FIX (the old scripted coord form cut
# on a read-only cell). OPTION (A): the interactive Alt-Right COMPLETION (callback.c break_wires_at_point
# at mousex/y_snap) stays RAW+silent -- a pre-existing 0069-class gesture-drop gap this atom does NOT
# widen but does NOT close (grep-guard-locked callback.c ZERO; deferred to a follow-up (B) atom). So NO
# callback.c edit.
# Atom 12 (0053 Cadence Ctrl-E window hop) added: the S1 focus_window emit row
# (utils/cadence_nav.tcl) and the S6 SEAM-EXCLUSIVITY block -- `new_schematic
# switch` (a shared core: tab-strip/alt2/window-open machinery) must be logged
# ONLY at the cadence::focus_window seam, never in the C core (else every tab
# redraw floods the log). `new_schematic` is deliberately NOT in the S2 CVERBS set
# (it is Tcl-seam-logged, not C-self-logged, so the Tcl literal log is legitimate).
# The library_manager do_* mutation seam (atom 7 / 0064) is Tcl-only and its
# `libmgr::do_*` lines don't start with "xschem " (S2-invisible), so it is
# locked twice: the S1 site-count row (line-anchored, comments don't count)
# and the S1b closure scan, which enumerates every `proc libmgr::do_*` and
# fails any worker that neither logs its own name nor sits on the read-only
# allowlist -- a NEW unlogged worker fails closed with no row bump needed.
# doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md
#
# Needs the action log open (S5) -> registered in full_audit.sh logdir_tests:
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_selflog_grep_guard.tcl

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
proc srctext {rel} {
  set fd [open [file join $::REPO $rel] r]; set t [read $fd]; close $fd
  return $t
}
proc rxcount {text re} { return [regexp -all -- $re $text] }

# ---------------------------------------------------------------------------
# S1) MANIFEST: every self-log site is still present.  {file {regex min label}...}
# ---------------------------------------------------------------------------
set MANIFEST {
  src/scheduler.c {
    {log_action\("xschem cut"}                        1 {cut branch}
    {log_action\("xschem delete"}                     1 {delete branch}
    {log_action\("xschem copy"}                       1 {copy branch (atom 4)}
    {log_action\("xschem undo"}                       1 {undo branch}
    {log_action\("xschem redo"}                       1 {redo branch}
    {if\(!fast\) log_action\("xschem save"}           1 {save branch incl. fast-machinery gate (atom 4)}
    {log_action\("xschem reload%s"}                   1 {reload branch incl. zoom_full arg (atom 4)}
    {return perform_action\("align", argc, argv\);}   1 {align branch routes through the perform_action boundary (Refactor B atom 2): no scattered readonly/log/push_undo here}
    {return perform_action\("trim_wires", argc, argv\);} 1 {trim_wires branch routes through the perform_action boundary (Refactor B atom 1): no scattered readonly/log/push_undo here}
    {int perform_action\(const char \*verb,}          1 {the single mutation/command boundary is defined once (Refactor B, audit §4)}
    {if\(scheduler_readonly_reject\(interp, verb\)\) return TCL_ERROR;} 1 {perform_action's ONE readonly gate -- covers every migrated verb from every entry point (0041/0051 unification)}
    {if\(rc == TCL_OK\) \{   /\* LOG-ON-SUCCESS \+ success-only reset \(Refactor B atom 13\)} 1 {perform_action's LOG-ON-SUCCESS guard (Refactor B atom 13, the FIRST shared-machinery change): the log site AND the interp reset fire only when run_core returned TCL_OK, so a VALIDATING verb's early-TCL_ERROR (reset_inst_prop `argc<3` / "instance not found", and the replace_symbol/load_backup class it unblocks) is NOT phantom-logged. Reverting to the unconditional log (sabotage 1) deletes this uniquely-commented line -> fails closed. Every migrated verb returns TCL_OK on BOTH success AND no-op, so no existing log is dropped and the no-op-still-logs property survives}
    {if\(!actionlog_suppress\) core_log_action\(verb, argc, argv\);} 1 {perform_action's ONE log site -- delegates the per-verb log FORM to core_log_action (atom 6), gated on the re-entrant suppress counter (foundation §20); now NESTED inside the atom-13 log-on-success `if(rc == TCL_OK)` block above}
    {Tcl_ResetResult\(interp\);   /\* clear on success ONLY} 1 {perform_action clears the interp result ONLY on the TCL_OK path (atom 13) -- a TCL_ERROR from a validating verb (reset_inst_prop) keeps run_core's Tcl_SetResult message, closing the C-side empty-error bug; MUST stay coupled to the log-on-success guard, never split from it}
    {static void core_log_action\(const char \*verb, int argc, const char \*argv\[\]\)} 1 {the per-verb log-form dispatcher (§4 Refactor A step-2 registry SEED, atom 6): bare verbs -> "xschem %s"; the arg-carrying pivot verbs rotate/flip/flipv -> the pivot form "xschem <verb> x0 y0" (rotate atom 6, flip atom 7, flipv atom 8)}
    {log_action\("xschem %s", verb\);}                1 {core_log_action's BARE-verb form -- trim_wires/align/rotate_in_place/flip_in_place/flipv_in_place/floaters_from_selected_inst/toggle_ignore/show_unconnected_pins all self-log through here, byte-identical to the pre-atom-6 perform_action log site}
    {log_action\("xschem break_wires 1"}              1 {break_wires REMOVE form now lives in core_log_action (atom 9), NOT the scheduler branch -- exactly ONE such site in scheduler.c (S7 pins exclusivity); the literal `break_wires 1"` (space+1 before the quote) does NOT match the bare `break_wires")` form}
    {log_action\("xschem break_wires"\)}              1 {break_wires BARE form now lives in core_log_action (atom 9), NOT the scheduler branch -- exactly ONE such site in scheduler.c (S7 pins exclusivity); the `break_wires"\)` (quote then paren) does NOT match `break_wires 1"` nor break_wires_at_pins/_at_point/_at_attach_points}
    {log_action\("xschem attach_labels %}             1 {attach_labels VALUE form now lives in core_log_action (atom 11) -- `log_action("xschem attach_labels %d", atoi(argv[2]))` PRESERVES the 0/1/2 value (unlike break_wires which collapses nonzero to 1); byte-identical to the old log_action_argv for the canonical integer arg every live path emits, strictly MORE faithful for a non-canonical token (`007`->`7`); exactly ONE such site in scheduler.c (S7 pins exclusivity); the literal `attach_labels %` (space+%) does NOT match the bare `attach_labels")` form}
    {log_action\("xschem attach_labels"\)}            1 {attach_labels BARE form now lives in core_log_action (atom 11), NOT the scheduler branch -- exactly ONE such site in scheduler.c (S7 pins exclusivity); the `attach_labels"\)` (quote then paren) does NOT match `attach_labels %`}
    {(?n)av\[0\] = "xschem"; av\[1\] = verb; av\[2\] = argv\[2\];$} 1 {reset_inst_prop SELF-CONTAINED name form lives in core_log_action (atom 13): the referent argv[2] (a name or numeric index) is emitted via log_action_argv (Tcl_Merge), NOT a raw %s -- so an arrayed/bussed name with Tcl metacharacters (x2[3:0]) is brace-quoted and REPLAYS (raw %s would replay `[3:0]` as a command substitution; the issue-0048 replay-safe pattern, flagged by this atom's adversarial review). Reached ONLY on TCL_OK (log-on-success), so a failed validation logs nothing}
    {log_action_argv\(3, av\);} 1 {reset_inst_prop's Tcl_Merge emit (atom 13): log_action_argv brace-quotes the referent minimally, so a plain refdes (R1) logs byte-identically to `xschem reset_inst_prop R1` while an arrayed name logs `xschem reset_inst_prop {x2[3:0]}`. Exactly ONE such `(3, av)` site in scheduler.c (S7 pins exclusivity); distinct from the `argc`/`ac`-arg log_action_argv calls (add_pin_stubs, paste)}
    {return perform_action\("replace_symbol", argc, argv\);} 1 {replace_symbol branch routes through the perform_action boundary (Refactor B atom 14 -- the SECOND VALIDATING verb, and the FIRST per-verb migration to carry a FAST-FLAG log gate; a PLAIN migration onto the UNCHANGED atom-13 log-on-success boundary): run_core MOVES the fast-flag parse + the argc!=4 "needs 2 additional arguments" / "instance not found" validation IN (early TCL_ERROR BEFORE its single non-fast push_undo, so a bad arg mutates nothing) and, via log-on-success, logs nothing on failure; core_log_action logs the SELF-CONTAINED `xschem replace_symbol <inst> <sym>` (argv[2]+argv[3], both Tcl_Merge-quoted) on success only AND only when NOT fast. The boundary ADDS the generic readonly gate (already present in the old branch, now unified); the old success-path instname interp result is dropped (no caller consumed it). No scattered readonly/log/push_undo here}
    {av\[3\] = argv\[3\];} 1 {replace_symbol SELF-CONTAINED two-arg form lives in core_log_action (atom 14): BOTH the instance referent argv[2] AND the symbol path argv[3] are emitted via log_action_argv (Tcl_Merge), NOT a raw %s -- either can carry Tcl metacharacters (an arrayed name x2[3:0], a path with a space/bracket), so both are brace-quoted and REPLAY. `av[3] = argv[3];` is UNIQUE to replace_symbol (no other verb uses av[3]) -- the S7 exclusivity marker. Reached ONLY on TCL_OK (log-on-success) AND only when NOT fast, so a failed validation or a fast machinery call logs nothing}
    {log_action_argv\(4, av\);} 1 {replace_symbol's Tcl_Merge emit (atom 14): log_action_argv brace-quotes the two referents minimally, so a plain refdes+path (R1 devices/capa.sym) logs byte-identically to `xschem replace_symbol R1 devices/capa.sym` while an arrayed name logs `xschem replace_symbol {x2[3:0]} devices/capa.sym`. Exactly ONE such `(4, av)` site in scheduler.c (S7 pins exclusivity); distinct from reset_inst_prop's `(3, av)` and the `argc`/`ac`-arg calls (add_pin_stubs, paste)}
    {if\(argc <= 4 \|\| strcmp\(argv\[4\], "fast"\)\)} 1 {replace_symbol's FAST-FLAG LOG GATE (atom 14 -- the FIRST per-verb migration to carry one): core_log_action logs the swap ONLY when the call is NOT the fast multi-substitution machinery sub-mode (argv[4]=="fast"), mirroring run_core's `if(!fast)` undo skip -- the atom-4 save-fast axis applied to a per-verb log form. NB core_log_action reads the ORIGINAL argc (run_core clamps its own local copy to 4), so the fast test reads the untouched argv[4]. Reverting the gate (log unconditionally) makes the fast form log +1 -> test (e) fails closed}
    {return perform_action\("break_wires", argc, argv\);} 1 {break_wires branch routes through the perform_action boundary (Refactor B atom 9 -- the FIRST NON-transform verb; the arg is a FLAG (0/1), not a pivot; NO mid-gesture split): run_core + core_log_action read `remove` from argc/argv; break_wires_at_pins owns its own push_undo/draw, so no scattered readonly/log/push_undo here}
    {log_action\("xschem flip %}                      1 {flip PIVOT form now lives in core_log_action (atom 7), NOT the scheduler branch -- exactly ONE such site remains in scheduler.c (S7 pins the exclusivity); the literal `flip %` (flip+space) does NOT match `flipv %`}
    {log_action\("xschem flipv %}                     1 {flipv PIVOT form now lives in core_log_action (atom 8), NOT the scheduler branch -- exactly ONE such site remains in scheduler.c (S7 pins the exclusivity); the literal `flipv %` (flipv+space) does NOT match `flip %` (a `v` intervenes) nor `flipv_in_place`}
    {log_action\("xschem rotate %}                    1 {rotate PIVOT form now lives in core_log_action (atom 6), NOT the scheduler branch -- exactly ONE such site remains in scheduler.c (S7 pins the exclusivity)}
    {return perform_action\("rotate", argc, argv\);}  1 {rotate branch STANDALONE arm routes through the perform_action boundary (Refactor B atom 6 -- the FIRST arg-carrying verb): run_core + core_log_action thread the pivot from argc/argv; the mid-gesture STARTMOVE/STARTCOPY arms stay raw (logged at move/copy END, 0069), no scattered readonly/log/push_undo here}
    {return perform_action\("flip", argc, argv\);}    1 {flip branch STANDALONE arm routes through the perform_action boundary (Refactor B atom 7 -- the SECOND arg-carrying verb, a near-clone of rotate): run_core + core_log_action thread the pivot from argc/argv; the mid-gesture STARTMOVE/STARTCOPY arms stay raw (logged at move/copy END, 0069), no scattered readonly/log/push_undo here}
    {return perform_action\("flipv", argc, argv\);}   1 {flipv branch STANDALONE arm routes through the perform_action boundary (Refactor B atom 8 -- the THIRD and LAST arg-carrying pivot verb, the mirror of flip): run_core's THREE-move vertical mirror (ROTATE, ROTATE, FLIP, NO ROTATELOCAL) + core_log_action thread the pivot from argc/argv; the mid-gesture STARTMOVE/STARTCOPY arms stay raw (logged at move/copy END, 0069), no scattered readonly/log/push_undo here}
    {return perform_action\("flip_in_place", argc, argv\);} 1 {flip_in_place branch STANDALONE arm routes through the perform_action boundary (Refactor B atom 4, the mirror of rotate_in_place): the mid-gesture STARTMOVE/STARTCOPY arms stay raw (logged at move/copy END, 0069), no scattered readonly/log/push_undo here}
    {return perform_action\("flipv_in_place", argc, argv\);} 1 {flipv_in_place branch STANDALONE arm routes through the perform_action boundary (Refactor B atom 5, the last in-place transform): THREE move_objects calls (ROTATE|ROTATELOCAL x2 + FLIP|ROTATELOCAL) live in run_core; the mid-gesture STARTMOVE/STARTCOPY arms stay raw (logged at move/copy END, 0069), no scattered readonly/log/push_undo here}
    {return perform_action\("rotate_in_place", argc, argv\);} 1 {rotate_in_place branch STANDALONE arm routes through the perform_action boundary (Refactor B atom 3): the mid-gesture STARTMOVE/STARTCOPY arms stay raw (logged at move/copy END, 0069), no scattered readonly/log/push_undo here}
    {log_action\("xschem change_elem_order %d"}       1 {change_elem_order branch}
    {log_action\("xschem check_unique_names}          1 {check_unique_names branch}
    {log_action\("xschem create_instance"}            1 {create_instance branch}
    {return perform_action\("floaters_from_selected_inst", argc, argv\);} 1 {floaters_from_selected_inst branch routes through the perform_action boundary (Refactor B atom 10 -- the SECOND non-transform verb, a BARE no-arg verb): run_core calls floaters_from_selected_inst() which OWNS its own push_undo/set_modify/draw (no double-push); the log is the shared bare `xschem %s` core_log_action DEFAULT line (no per-verb branch); the boundary ADDS the readonly gate this branch never had (a 0041/0051 close). No scattered readonly/log/push_undo here}
    {return perform_action\("attach_labels", argc, argv\);} 1 {attach_labels branch routes through the perform_action boundary (Refactor B atom 11 -- the THIRD non-transform verb; the arg is a FLAG `interactive` (0/1/2, value PRESERVED not collapsed), not a pivot; NO mid-gesture split): run_core + core_log_action read `interactive` from argc/argv; attach_labels_to_inst() OWNS its own push_undo (via place_symbol) + set_modify + draw, so no double-push; the boundary ADDS the readonly gate this branch never had (a 0041/0051 close -- every 0/1/2 form mutates); the SHARED core is ALSO a raw netlisting sub-step (show_unconnected_pins) + the Shift+H dialog key, both off the boundary. No scattered readonly/log/push_undo here}
    {return perform_action\("toggle_ignore", argc, argv\);} 1 {toggle_ignore branch routes through the perform_action boundary (Refactor B atom 12 -- the FIRST FRICTION-FREE-SCOUTED verb, a BARE no-arg verb): run_core calls toggle_ignore() which OWNS its own push_undo (on the FIRST selected element) + set_modify + draw (no double-push); the log is the shared bare `xschem %s` core_log_action DEFAULT line (no per-verb branch); the boundary is PURELY ADDITIVE -- this branch logged NOTHING and had NO readonly gate before, so it ADDS BOTH (a 0041/0051 close). The equivalent Shift+T key routes through the SAME boundary. No scattered readonly/log/push_undo here}
    {return perform_action\("reset_inst_prop", argc, argv\);} 1 {reset_inst_prop branch routes through the perform_action boundary (Refactor B atom 13 -- the FIRST BENEFICIARY of the log-on-success change, and the FIRST VALIDATING verb): run_core MOVES the argc<3 / "instance not found" validation IN (early TCL_ERROR BEFORE its single push_undo, so a bad arg mutates nothing) and, via log-on-success, logs nothing on failure; core_log_action logs the SELF-CONTAINED `xschem reset_inst_prop <ref>` (argv[2], a name or index) on success only. The boundary ADDS the generic readonly gate (already present in the old branch, now unified); the old success-path instname interp result is dropped (no caller consumed it). No scattered readonly/log/push_undo here}
    {return perform_action\("show_unconnected_pins", argc, argv\);} 1 {show_unconnected_pins branch routes through the perform_action boundary (Refactor B atom 15 -- the friction-free BARE no-arg verb from the fresh atom-15 fan-out scout, after the atom-14 validating shortlist was EXHAUSTED): run_core calls show_unconnected_pins() (netlist.c), whose RAW attach_labels_to_inst(2) sub-step OWNS its push_undo (via place_symbol) + set_modify + draw (no double-push) and stays SILENT below the boundary (its log lives under the `attach_labels` verb in core_log_action, NOT in the C fn -- the atom-11 shared-sub-step lock -- so show_unconnected_pins double-logs NOTHING with attach_labels); the log is the shared bare `xschem %s` core_log_action DEFAULT line (no per-verb branch). The boundary ADDS the readonly gate this branch NEVER HAD -- a correctness fix: the old branch placed lab_show labels on a read-only cell. A no-unconnected-pins sheet is a no-op but STILL logs +1 (the §30 no-op-still-logs property). No scattered readonly/log/push_undo here}
    {return perform_action\("embed_rawfile", argc, argv\);} 1 {embed_rawfile branch routes through the perform_action boundary (Refactor B atom 16 -- the DEFERRED runner-up from the atom-15 scout, a HYBRID of the reset_inst_prop §33 single-STRING-referent + argc-gate template and the floaters/show_unconnected_pins §30/§35 core-owns-its-own-undo template): run_core MOVES the `~/` expansion IN (via the home_dir global) and the argc<3 "needs a file argument" validation (early TCL_ERROR BEFORE any mutation, so a missing arg mutates nothing and, via log-on-success, logs nothing -- the old branch SILENTLY no-op'd); the core embed_rawfile() (draw.c) OWNS the SINGLE push_undo + set_modify (no double-push); core_log_action logs the SELF-CONTAINED `xschem embed_rawfile <path>` via log_action_argv (Tcl_Merge on the RAW argv[2] so a metachar path replays + the `~/` re-expands) on success only. The boundary ADDS the readonly gate this branch NEVER HAD -- a CORRECTNESS FIX: the old branch embedded on a read-only cell. A missing/non-regular file is a MUTATION (base64_from_file NULL -> blanks spice_data), not a failure. No scattered readonly/log/push_undo here}
    {(?n)ev\[0\] = "xschem"; ev\[1\] = verb; ev\[2\] = argv\[2\];$} 1 {embed_rawfile SELF-CONTAINED path form lives in core_log_action (atom 16): the referent argv[2] (a `~/...`, absolute or relative RAW path) is emitted via log_action_argv (Tcl_Merge), NOT a raw %s -- a path with a space/bracket/brace carries Tcl metacharacters (`sim [1].raw`) and a raw line would misparse on replay. The array is named `ev` (not `av`) SO THIS LINE STAYS TEXTUALLY DISTINCT from reset_inst_prop's byte-identical `av[...]` build -- both are line-anchored (?n)...;$, and a shared name would make each verb's count == 2, breaking the exclusivity rows. Reached ONLY on TCL_OK (log-on-success), so a failed validation logs nothing}
    {log_action_argv\(3, ev\);} 1 {embed_rawfile's Tcl_Merge emit (atom 16): log_action_argv brace-quotes the path minimally, so a plain path (/d/small.raw) logs unbraced while a metachar path logs `xschem embed_rawfile {/d/sim [1].raw}` and a `~/` path logs the RAW `xschem embed_rawfile ~/f.raw` (re-expanded on replay). Exactly ONE such `(3, ev)` site in scheduler.c (S7 pins exclusivity); the `ev` name keeps it distinct from reset_inst_prop's `log_action_argv(3, av)` and replace_symbol's `(4, av)`}
    {return perform_action\("wire_cut", argc, argv\);} 1 {wire_cut branch routes the SCRIPTED COORD form through the perform_action boundary (Refactor B atom 17 -- the SILENT-MUTATOR twin of break_wires (atom 9, §29): break_wires_at_point (check.c) is the SEPARATE Alt-Right wire_cut gesture core that §29 kept OFF break_wires' boundary; atom 17 puts it on). Only the argc>3 coord form crosses (via the branch's argc>3 guard); the no-coord GESTURE-START form stays RAW (arms ui_state, no mutation, no log -- the rotate/flip STARTMOVE-stays-raw split). break_wires_at_point OWNS a CONDITIONAL single push_undo + draw, so no scattered readonly/log/push_undo here; a point off any wire is a no-op that still returns TCL_OK -> no-op-still-logs. The boundary ADDS the readonly gate this coord form NEVER HAD -- a CORRECTNESS FIX (the old scripted form cut on a read-only cell)}
    {log_action\("xschem wire_cut %\.16g %\.16g"} 1 {wire_cut ALIGNED coord form lives in core_log_action (atom 17): the RAW click coords argv[2]/argv[3] via %.16g (NOT log_action_argv -- numeric coords, no metacharacter referent to brace-quote), NOT the snapped point (align is applied in-core by closest_point_calculation, so raw-coords replay IDENTICALLY). Exactly ONE such quote-terminated site in scheduler.c (S7 pins exclusivity); the trailing `"` (immediately after the second %.16g) does NOT match the ` noalign"` form}
    {log_action\("xschem wire_cut %\.16g %\.16g noalign"} 1 {wire_cut NOALIGN coord form lives in core_log_action (atom 17): the RAW click coords + the bareword `noalign` flag; break_wires_at_point applies noalign in-core, so the raw-coords+flag line replays IDENTICALLY. Exactly ONE such site in scheduler.c (S7 pins exclusivity); the ` noalign"` (space before the quote) does NOT match the aligned `%.16g"` form, and neither matches break_wires_at_point / _at_pins / _at_attach_points (an `_` follows)}
    {log_action\("xschem print_hilight_net}           1 {print_hilight_net branch}
    {log_action\("xschem exit closewindow force"}     2 {exit hook (both terminating sites)}
    {log_action\("xschem set cadgrid}                 1 {set cadgrid resolved-value}
    {log_action\("xschem set cadsnap}                 1 {set cadsnap resolved-value}
    {log_action\("xschem set rectcolor}               1 {set rectcolor}
    {"xschem hilight_net_interactive" : "xschem unhilight_net_interactive"} 1 {hilight interactive noun-verb (ternary log)}
    {log_action\("xschem library_manager}             1 {library_manager open}
    {log_action_stash_select_at}                      1 {select_at stash flush}
    {if\(fast != 1 && argc > 2 && !strcmp\(argv\[2\], "instance"\)\)} 1 {setprop self-log gate stays instance-only: the wire/rect/text/line/arc/poly `allprops` replay arms must NOT self-log (atom 10)}
    {if\(!\(xctx->ui_state & STARTMERGE\)\)}          1 {paste replay arm: pending-merge completion gate (atom 9)}
    {merge_file\(8, f\)}                              1 {paste replay arm: -file merge form (atom 9)}
    {!strcmp\(argv\[k\], "-anchor"\)}                 1 {paste replay arm: -anchor pivot parse (atom 9 review)}
    {if\(argc > 7\) noline = atoi\(argv\[7\]\);}      1 {add_symbol_pin no-stub-line replay arg: the sympin drop replay form matches the -place geometry (atom 11)}
    {if\(vi >= 0\) pin_view_writeback\(vi\);}         1 {add_symbol_pin noline reproduces the -place move-time name_* writeback so the replay saves byte-identically (atom 11)}
    {strcmp\(argv\[4\], "kissing"\) && strcmp\(argv\[4\], "stretch"\)} 2 {move_objects + copy_objects replay arms parse `rot flip [local] [-anchor]`, guarded against the kissing/stretch flag words so a plain line parses unchanged (atom 13 / 0069)}
    {if\(done_netlist && !keep_symbols\)}            1 {netlist branch self-log gate: `-keep_symbols` cellview/reroute machinery stays SILENT, the atom-4 `save fast` axis; dir-unwritable (done_netlist==0) logs nothing (atom 14 / 0062)}
    {av\[ac\+\+\] = "netlist";}                       1 {netlist branch emits the resolved `xschem netlist [-erc] [-nohier] [{fname}]` replay form -- the branch IS the 1:1 self-log site (atom 14 / 0062)}
    {tclsetboolvar\("enable_stretch", atoi\(argv\[3\]\)} 1 {set enable_stretch replay arm applies the resolved tcl var, the absolute form toggle_stretch_cmd self-logs; NO self-log here -> no double on replay (atom 16 / 0062 tail)}
    {if\(!v\) xctx->manhattan_lines = 0;}             1 {set orthogonal_wiring replay arm reproduces the manhattan_lines side effect (edit-mode faithfulness), matching toggle_orthogonal_wiring_cmd; NO self-log here (atom 16 / 0062 tail)}
    {!strcmp\(argv\[2\], "-suppress"\)}               1 {log_action -suppress push|pop: the re-entrant scope guard the replay seam + composite ops ride on -- a DEPTH COUNTER so replay{composite{core}} stays suppressed until the outermost pop (issue 0071 Refactor B foundation / audit §3.2)}
    {!strcmp\(argv\[2\], "actionlog_suppress"\)}      1 {set actionlog_suppress N: the absolute (hard-reset) setter; NOT self-logged (a control command, and once >0 the log_action is a no-op anyway)}
  }
  src/util.c {
    {void actionlog_suppress_push\(void\)}            1 {the re-entrant suppress-scope PUSH (depth counter): the write site actionlog_suppress lacked -- the gate existed in log_action* but nothing ever set it (audit §3.2)}
    {void actionlog_suppress_pop\(void\)}             1 {the matching POP, underflow-clamped (>0 guard) so an unbalanced extra pop keeps logging ON}
  }
  src/callback.c {
    {log_action\("xschem set enable_stretch}          1 {toggle_stretch_cmd core self-logs the ABSOLUTE resolved state, not the replay-fragile relative flip (atom 16 / 0062 tail)}
    {log_action\("xschem set orthogonal_wiring}       1 {toggle_orthogonal_wiring_cmd core self-logs the ABSOLUTE resolved state (atom 16 / 0062 tail)}
    {log_action\("xschem copy"}                       1 {Ctrl-C inline key (atom 4)}
    {if\(!xctx->readonly\) log_action\("xschem save"} 1 {Ctrl-S inline key incl. readonly gate (atom 4)}
    {log_action\("xschem reload"}                     1 {Alt-S inline key ok-arm (atom 4)}
    {log_action\("xschem cut"}                        1 {Ctrl-X inline key (atom 2)}
    {log_action\("xschem delete"}                     1 {Delete inline key (atom 2)}
    {log_action\("xschem change_elem_order -1"}       1 {Shift-S inline key}
    {perform_action\("align", 0, NULL\);}             1 {Alt-U inline key routes through the perform_action boundary (Refactor B atom 2): no inline readonly_block/push_undo/log_action}
    {perform_action\("trim_wires", 0, NULL\);}        1 {'&' inline key routes through the perform_action boundary (Refactor B atom 1): no inline readonly_block/push_undo/log_action}
    {perform_action\("rotate_in_place", 0, NULL\);}   2 {the two callback.c standalone rotate_in_place entry points route through the perform_action boundary (Refactor B atom 3): the Alt-R single-object standalone (standalone_group_transform) + the verb-noun deferred apply (MENUSTARTROTATE); the mid-gesture STARTMOVE/STARTCOPY arms stay raw}
    {perform_action\("flip_in_place", 0, NULL\);}     2 {the two callback.c standalone flip_in_place entry points route through the perform_action boundary (Refactor B atom 4): the Alt-F single-object standalone (standalone_group_transform else-arm) + the verb-noun deferred apply (MENUSTARTROTATE PENDING_TR_FLIP_IP); the mid-gesture STARTMOVE/STARTCOPY arms stay raw}
    {perform_action\("flipv_in_place", 0, NULL\);}    2 {the two callback.c standalone flipv_in_place entry points route through the perform_action boundary (Refactor B atom 5): the Alt-V standalone apply (case 'v' EQUAL_MODMASK -- no standalone_group_transform / no group form) + the verb-noun deferred apply (MENUSTARTROTATE PENDING_TR_FLIPV_IP); the mid-gesture STARTMOVE/STARTCOPY arms stay raw}
    {perform_action\("rotate", 4, av\);}              3 {the THREE callback.c standalone rotate (pivot form) entry points route through the perform_action boundary (Refactor B atom 6, the FIRST arg-carrying verb), each passing its own pivot in av[2]/av[3]: the Shift-R key standalone apply + the Alt-R GROUP standalone_group_transform arm (issue 0116) + the verb-noun deferred apply (MENUSTARTROTATE PENDING_TR_ROTATE); the mid-gesture STARTMOVE/STARTCOPY arms stay raw}
    {perform_action\("flip", 4, av\);}                3 {the THREE callback.c standalone flip (pivot form) entry points route through the perform_action boundary (Refactor B atom 7, the SECOND arg-carrying verb, mirror of rotate), each passing its own pivot in av[2]/av[3]: the Shift-F key standalone apply + the Alt-F GROUP standalone_group_transform else-arm (issue 0116) + the verb-noun deferred apply (MENUSTARTROTATE PENDING_TR_FLIP); the mid-gesture STARTMOVE/STARTCOPY arms stay raw}
    {perform_action\("flipv", 4, av\);}               2 {the TWO callback.c standalone flipv (pivot form) entry points route through the perform_action boundary (Refactor B atom 8, the THIRD and LAST arg-carrying verb, mirror of flip), each passing its own pivot in av[2]/av[3]: the Shift-V key standalone apply + the verb-noun deferred apply (MENUSTARTROTATE PENDING_TR_FLIPV). Count is TWO, NOT three -- flipv has NO group form (no standalone_group_transform arm), unlike rotate/flip; the mid-gesture STARTMOVE/STARTCOPY arms stay raw}
    {perform_action\("break_wires", 0, NULL\);}       1 {'!' inline key (bare split, remove=0) routes through the perform_action boundary (Refactor B atom 9): no inline break_wires_at_pins/log_action; the semaphore + readonly_block key guards stay}
    {perform_action\("break_wires", 3, av\);}         1 {Ctrl-! inline key (split-and-remove) routes through the perform_action boundary (Refactor B atom 9): av[2]="1" carries the remove FLAG (the arg is a flag, not a pivot); no inline break_wires_at_pins/log_action}
    {perform_action\("toggle_ignore", 0, NULL\);}     1 {Shift+T key (act_toggle_ignore) routes through the perform_action boundary (Refactor B atom 12): perform_action's rc is DISCARDED and the handler returns 1 (event-handled contract, NOT perform_action's TCL_OK/ERROR). The key was ALREADY readonly-gated (registry mutates=1 -> readonly_block) + already logged via Layer A (d->log_cmd, actions.csv not-nolog); routing through the boundary unifies the log onto core_log_action -- log_action sets actionlog_cmd_logged so dispatch's Layer A copy DEDUPS to ONE line. This S1 row is the load-bearing lock that the EQUIVALENT key routes through the boundary (the runtime output is identical either way, so only this grep row catches a raw-core regression). No inline toggle_ignore()/log_action}
    {log_action\("xschem pan %}                       1 {drag-pan END}
    {log_action\("xschem zoom_box %}                  1 {zoom-drag END}
    {(?n)^\s*av\[ac\+\+\] = "xschem"; av\[ac\+\+\] = "paste";} 1 {paste/merge drop replay line (atom 9 / 0069)}
    {(?n)^\s*av\[ac\+\+\] = "-file";}                 1 {paste/merge drop -file source rider (atom 9)}
    {(?n)^\s*av\[ac\+\+\] = "-anchor";}               2 {paste/merge (atom 9) + rotmove (atom 13) drop -anchor pivot rider: a whole-log replay's regenerated clipboard / move-START seeds a different pivot}
    {(?n)^\s*log_action_argv\(ac, av\);}              2 {paste/merge (atom 9) + rotmove (atom 13) drop emit calls, line-anchored: if(0)/line-comment counts as removed (a BLOCK comment still evades -- the behavioral test is the real lock)}
    {(?n)^\s*av\[ac\+\+\] = "xschem"; av\[ac\+\+\] = is_copy \? "copy_objects" : "move_objects";} 1 {rotmove drop: mid-move/copy rotate/flip replay line, one form for both verbs (atom 13 / 0069)}
    {(?n)^\s*av\[0\] = "xschem"; av\[1\] = "add_symbol_pin";} 1 {sympin drop: symbol-pin replay line (atom 11 / 0069)}
    {(?n)^\s*av\[0\] = "xschem"; av\[1\] = "instance";} 1 {placed-instance read-back line in log_placed_instance -- shared by PLACE_SYMBOL + schematic Add-Pin drop (atom 11)}
    {(?n)^\s*if\(log_placed_instance\(\)\) return;}   2 {log_placed_instance called by both the PLACE_SYMBOL arm and the START_SYMPIN sch-pin arm (atom 11)}
    {log_action\("xschem netlist -erc -nohier"}      1 {Shift-N current-level netlist key entry-site: bypasses the branch (direct global_*_netlist(0,1)), logs `-erc -nohier` -- `-erc`=state-preserving (erc=1 skips the netlist_name clear + infowindow suppression the key never does), NOT bare `-nohier` which would clear a custom netlist_name (atom 14 review MAJOR / 0062)}
  }
  src/paste.c {
    {(?n)^\s*my_strncpy\(xctx->merge_source,}         1 {merge_file source stash for the drop logger (atom 9)}
    {(?n)^\s*xctx->ui_state &= ~STARTMERGE;}          1 {merge_file empty-merge dangling-flag clear (atom 9 review: a dangler mislogs the next move drop as a paste)}
  }
  src/actions.c {
    {log_action\("xschem saveas \{%s\}}               1 {saveas dialog-resolution arm}
    {log_action\("xschem load \{%s\}"}                1 {load ask-dialog arm}
    {log_action\("xschem load_new_window \{%s\}"}     1 {load_new_window ask-dialog arm}
    {log_action_descend\("descend"}                   1 {descend core self-contained -inst form}
    {log_action\("xschem go_back"\)}                  1 {go_back core bare form (atom 3)}
    {log_action\("xschem go_back %d"}                 1 {go_back core what!=1 form (atom 3)}
    {log_action\("xschem wire %}                      1 {new_wire storeobject site}
    {log_action\("xschem line %}                      1 {new_line storeobject site}
    {log_action\("xschem rect %}                      1 {new_rect storeobject site}
    {log_action\("xschem arc %}                       1 {new_arc site}
  }
  src/save.c {
    {log_action\("xschem make_symbol"}                1 {make_symbol core (slice 6)}
    {log_action\("xschem make_sch_from_sel"}          1 {make_sch_from_sel core (slice 6)}
    {log_action\("xschem make_sch"\)}                 1 {make_sch core (slice 6)}
    {log_action_descend\("descend_symbol"}            1 {descend_symbol core -inst form (atom 3)}
  }
  src/select.c {
    {log_action\("xschem select_grow_connected}       2 {connected-grow core, both forms (atom 1)}
  }
  src/editprop.c {
    {(?n)^\s*log_prop_edit_replayable\(type, presel_names\);} 1 {property-dialog per-object replayable emit tail, line-anchored (atom 10 / 0063)}
    {"schprop";}                                      1 {global-attrs edit -> `set sch<X>prop {..}` replay emit (atom 10)}
    {(?n)^\s*presel_names\[s\] = NULL;}               1 {ELEMENT emit pre-edit-name snapshot: a rename must address the OLD name (atom 10 review)}
  }
  src/xschem.tcl {
    {log_action -reset}                               2 {stdin REPL + TCP handler dedup resets (0003)}
    {log_action -emitted}                             4 {stdin REPL + TCP handler -emitted gates (0003)}
    {# failed: }                                      2 {stdin REPL + TCP failed-command comment form (0003)}
    {(?n)^\s*xschem\s+log_action\s+\[list\s+net_hilight_style_set_live\M} 2 {nhse_apply_live + delete-last-row live-commit lines, raw replay form (atom 8 / 0065)}
    {(?n)^\s*xschem\s+log_action\s+net_hilight_style_reset\M} 1 {nhse_reset live-reset line (atom 8 / 0065)}
    {(?n)^\s*xschem\s+log_action\s+\[list\s+set\s+::net_hilight_style\M} 1 {nhse_save staged-table line (atom 8 review: Save writes the staged var)}
    {(?n)^\s*xschem\s+log_action\s+\[list\s+write_net_hilight_style_conf\M} 1 {nhse_save resolved-path line (atom 8 / 0065)}
    {(?n)^\s*xschem toggle_stretch$} 1 {Options-menu "Enable stretch" checkbutton -command routes through the self-logging toggle_stretch_cmd (atom 16 / 0062 tail): a bare -variable checkbutton bypassed the cmd and logged nothing}
    {(?n)^\s*xschem toggle_orthogonal_wiring$} 1 {Options-menu "Enable orthogonal wiring" checkbutton -command routes through toggle_orthogonal_wiring_cmd -- the ONLY interactive control for the keyless verb -- applying side effects AND self-logging (atom 16 / 0062 tail)}
    {(?n)^\s*xschem log_action -suppress push$} 1 {replay_action_log seam: source a recorded log IN-SESSION under the suppress scope so lines re-EXECUTE but do not re-LOG -- the audit §3.2 replay re-entrancy hazard, made safe for an in-session replay (Refactor B foundation)}
    {(?n)^\s*xschem log_action -suppress pop$}  1 {replay_action_log seam close: balanced via catch so a mid-file error still pops the scope}
  }
  src/library_manager.tcl {
    {(?n)^\s*xschem\s+log_action\s+\[list\s+libmgr::do_} 14 {do_* mutation-seam logs, one per worker, line-anchored so a commented-out site does not count (atom 7 / 0064)}
  }
  utils/cadence_nav.tcl {
    {(?n)^\s*xschem log_action "xschem new_schematic switch } 1 {focus_window logs the Cadence Ctrl-E parent-window hop at the entry seam, line-anchored so the prose in the comment above does not count (atom 12 / 0053)}
  }
  utils/apply_hilight.tcl {
    {(?n)^\s*xschem log_action \[list net_hilight_apply \$style\]} 1 {aphl::try_apply CLICK-arm emit: the click-to-apply style logs the RESOLVED row (atom 15 / 0065 §4 / 0067 §5); the click's own select_at is logged by the core (atom 1) and re-selects the net on replay}
    {(?n)^\s*xschem log_action \[list net_hilight_apply \$row\]}   1 {apply_hilight IMMEDIATE-arm emit: the raw cadence F5 bind (bypasses dispatch_input_action) records here; the CIW-typed path dedups via ciw_exec `-emitted` -> exactly once (atom 15)}
  }
}
foreach {relfile rows} $MANIFEST {
  set text [srctext $relfile]
  foreach {re min label} $rows {
    set n [rxcount $text $re]
    check "S1 $relfile: $label" [expr {$n >= $min}] "want>=$min got=$n re=$re"
  }
}

# ---------------------------------------------------------------------------
# S1b) libmgr do_* seam CLOSURE (atom 7 review): the >=14 floor above cannot
#      see a NEW unlogged worker, so enumerate every `proc libmgr::do_*` and
#      require each to be either an allowlisted read-only viewer or to carry an
#      UNCOMMENTED log_action of its own name (line-anchored; \M so do_checkin
#      does not satisfy do_checkin_lib). A new mutating worker fails closed
#      until it logs or is allowlisted.
# ---------------------------------------------------------------------------
set LBM_READONLY {do_show_checkouts do_history do_history_view do_history_cell do_history_lib}
set lbmtext [srctext src/library_manager.tcl]
set lbmworkers {}
foreach {m name} [regexp -all -inline {proc\s+libmgr::(do_\w+)} $lbmtext] {
  lappend lbmworkers $name
}
set lbmworkers [lsort -unique $lbmworkers]
check "S1b do_* worker inventory found" [expr {[llength $lbmworkers] >= 19}] \
  "n=[llength $lbmworkers]"
foreach w $lbmworkers {
  if {[lsearch -exact $LBM_READONLY $w] >= 0} continue
  set re "(?n)^\\s*xschem\\s+log_action\\s+\\\[list\\s+libmgr::${w}\\M"
  check "S1b libmgr::$w logs its own line (uncommented)" \
    [expr {[rxcount $lbmtext $re] >= 1}] "re=$re"
}

# ---------------------------------------------------------------------------
# S1c) must-NOT-reappear (atom 9): the paste/merge drop marker and the
#      ctx-menu pick-8 literal are gone for good -- re-adding either would
#      shadow or double the drop's replayable `xschem paste dx dy` line.
# ---------------------------------------------------------------------------
set cbtext [srctext src/callback.c]
check "S1c old '# paste/merge drop' marker stays removed" \
  [expr {[rxcount $cbtext {# paste/merge drop}] == 0}]
check "S1c ctx-menu pick-8 'xschem paste' literal stays removed (drop line is the record)" \
  [expr {[rxcount $cbtext {"xschem paste"}] == 0}]
# atom 11: the sympin drop marker is replaced by replayable add_symbol_pin /
# instance lines -- it must not creep back (it would shadow the real record).
check "S1c old '# place symbol pin (no replayable...)' marker stays removed" \
  [expr {[rxcount $cbtext {# place symbol pin \(no replayable}] == 0}]
# atom 10: the property-dialog marker is replaced by replayable setprop lines --
# it must not creep back for the converted types (it would shadow the real record).
check "S1c old '# property-edit' marker stays removed (property dialogs now replayable)" \
  [expr {[rxcount [srctext src/editprop.c] {# property-edit}] == 0}]
# atom 13: the mid-move/copy rotate/flip marker is replaced by replayable
# move_objects/copy_objects lines -- the dead `no single-command replay` marker
# must not creep back (it would shadow the real record and drop the orientation).
check "S1c old rotate/flip 'no single-command replay' marker stays removed (rot/flip drops now replayable)" \
  [expr {[rxcount $cbtext {no single-command replay}] == 0}]

# ---------------------------------------------------------------------------
# S1d) apply_hilight CLOSURE (atom 15): the two S1 emit rows lock the KNOWN apply
#      arms, but they cannot see a NEW unlogged net_hilight_apply call site. So
#      count every statement-position `net_hilight_apply` invocation in
#      utils/apply_hilight.tcl (the log lines start with `xschem`, comments with
#      `#`, so neither matches) -- there must be EXACTLY 2 (aphl::try_apply and the
#      apply_hilight immediate arm). A NEW apply arm bumps this and fails closed
#      until its own log_action + S1 row are added. Pairs with the 2 emit rows to
#      guarantee 2 invocations <-> 2 logs.
# ---------------------------------------------------------------------------
set aphtext [srctext utils/apply_hilight.tcl]
check "S1d exactly 2 net_hilight_apply invocation sites in apply_hilight.tcl (both logged)" \
  [expr {[rxcount $aphtext {(?n)^\s*net_hilight_apply\M}] == 2}] \
  "got=[rxcount $aphtext {(?n)^\s*net_hilight_apply\M}]"

# ---------------------------------------------------------------------------
# S2) TCL LITERAL-LOG CONFLICTS: no ungated hand-rolled `xschem log_action
#     "xschem <verb> ..."` for a verb the C side self-logs.
#     Gated = the same or one of the 2 preceding lines carries `log_action
#     -emitted` (the menu_action_logged / library_manager pattern).
# ---------------------------------------------------------------------------
# Verbs self-logged in C. `set` is keyed per-subcommand (set cadsnap|cadgrid|
# header_text|rectcolor log in C; `set readonly` is Tcl-owned).
set CVERBS {
  cut delete copy undo redo save reload saveas align trim_wires break_wires
  flip flipv rotate flip_in_place flipv_in_place rotate_in_place
  change_elem_order check_unique_names create_instance toggle_ignore
  reset_inst_prop replace_symbol show_unconnected_pins embed_rawfile wire_cut
  floaters_from_selected_inst print_hilight_net attach_labels add_pin_stubs
  setprop unhilight_all hilight_net_interactive unhilight_net_interactive
  make_symbol make_sch make_sch_from_sel descend descend_symbol go_back
  select_grow_connected select_at library_manager exit
  wire line rect arc polygon instance text pan zoom_box paste
  add_symbol_pin add_sch_pin netlist
  move_objects copy_objects load load_new_window
  {set cadsnap} {set cadgrid} {set header_text} {set rectcolor}
  {set enable_stretch} {set orthogonal_wiring}
}
# (file,verb) pairs allowed UNGATED: the file-menu dialog-resolution arms eval
# the WITH-FILENAME form, for which the C side is silent by design (C logs only
# its own ask-dialog arm) -- a single faithful line, no dedup needed.
set S2_ALLOW { {xschem.tcl load_new_window} }
set nviol 0
foreach f [glob -directory [file join $REPO src] *.tcl] {
  set lines [split [srctext src/[file tail $f]] \n]
  set n [llength $lines]
  for {set i 0} {$i < $n} {incr i} {
    set L [lindex $lines $i]
    if {[regexp {^\s*#} $L]} continue
    # literal log: xschem log_action "xschem ..."   or   {xschem ...}
    if {![regexp {xschem log_action\s+["\{]xschem\s+(\S+)(\s+(\S+))?} $L -> v1 - v2]} continue
    set verb [string trim $v1 "\"\}"]
    if {$verb eq "set" && $v2 ne ""} { set verb "set [string trim $v2 "\"\}"]" }
    if {[lsearch -exact $CVERBS $verb] < 0} continue
    if {[lsearch -exact $S2_ALLOW [list [file tail $f] $verb]] >= 0} continue
    set gated 0
    for {set j [expr {$i-2}]} {$j <= $i} {incr j} {
      if {$j >= 0 && [string match {*log_action -emitted*} [lindex $lines $j]]} { set gated 1 }
    }
    if {!$gated} {
      incr nviol
      check "S2 ungated Tcl literal log of C-logged verb '$verb'" 0 "[file tail $f]:[expr {$i+1}]: [string trim $L]"
    }
  }
}
check "S2 no ungated Tcl literal logs of C-self-logged verbs" [expr {$nviol == 0}] "violations=$nviol"

# ---------------------------------------------------------------------------
# S3) BRANCH-MUST-NOT-LOG: verbs whose log lives in a core C function must not
#     ALSO log in scheduler.c (menu/script would double). Word-boundary regexes
#     so make_sch does not match make_sch_from_sel, descend not descend_symbol.
# ---------------------------------------------------------------------------
set sched [srctext src/scheduler.c]
# `paste`: the branch IS the coordinate replay form (atom 9) -- a log there
# would re-log every replayed drop. `add_symbol_pin`/`add_sch_pin` (atom 11):
# the drop funnel (end_move_copy_logged, callback.c) is the SOLE logger -- both
# the `-place` gesture start and the direct `add_symbol_pin` replay form must
# stay silent in the scheduler, else a replayed sympin drop double-logs.
# `move_objects`/`copy_objects` (atom 13): same shape -- the scheduler arms ARE
# the coordinate replay form (rot/flip/-anchor), the drop funnel is the sole
# logger, so a log in the branch would re-log every replayed rot/flip drop.
# toggle_stretch/toggle_orthogonal_wiring (atom 16 / 0062 tail): the cores
# (toggle_*_cmd, callback.c) self-log the ABSOLUTE `set <var> <v>` form, so the
# scheduler branches must NOT log the replay-fragile relative flip; likewise the
# `set enable_stretch`/`set orthogonal_wiring` replay arms ARE the coordinate/replay
# form and must not self-log (a log there would double every replayed line).
foreach verb {make_symbol make_sch make_sch_from_sel descend descend_symbol
              go_back select_grow_connected update_net_hilight_style paste
              add_symbol_pin add_sch_pin move_objects copy_objects
              toggle_stretch toggle_orthogonal_wiring
              {set enable_stretch} {set orthogonal_wiring}} {
  set n [rxcount $sched "log_action\\(\"xschem $verb\[\"% \]"]
  check "S3 scheduler.c has NO log_action for core-logged verb '$verb'" \
    [expr {$n == 0}] "got=$n"
}
check "S3 scheduler.c has NO log_action_descend (lives in the cores)" \
  [expr {[rxcount $sched {log_action_descend\(}] == 0}]

# ---------------------------------------------------------------------------
# S4) RECORDER DEDUP WIRING: the four dedup-wired recorders + the lbm gated
#     fallback keep their reset/-emitted plumbing.
# ---------------------------------------------------------------------------
set ar  [srctext src/action_registry.tcl]
set cw  [srctext src/ciw.tcl]
set cb  [srctext src/callback.c]
set lbm [srctext src/library_manager.tcl]
check "S4 menu_action_logged: reset wired"    [expr {[rxcount $ar {log_action -reset}]   >= 1}]
check "S4 menu_action_logged: -emitted gates" [expr {[rxcount $ar {log_action -emitted}] >= 2}]
check "S4 ciw_exec: reset wired"              [expr {[rxcount $cw {log_action -reset}]   >= 1}]
check "S4 ciw_exec: -emitted gates"           [expr {[rxcount $cw {log_action -emitted}] >= 2}]
check "S4 callback.c: dedup flag resets (ctx menu + dispatch)" \
  [expr {[rxcount $cb {actionlog_cmd_logged = 0}] >= 2}]
check "S4 callback.c: dedup flag checks (ctx menu + dispatch)" \
  [expr {[rxcount $cb {!actionlog_cmd_logged}] >= 2}]
check "S4 library_manager open_cellview: gated fallback (-emitted x2)" \
  [expr {[rxcount $lbm {log_action -emitted}] >= 2}]
# The suppress-scope guard (issue 0071 Refactor B foundation) is NEW dedup wiring:
# the setter + the two re-entrancy seams. If any of these four go missing, the
# replay/composite double-log hazard (§3.2) re-opens -> fail closed.
set utl [srctext src/util.c]
set xtcl [srctext src/xschem.tcl]
check "S4 suppress-scope: util.c defines the push/pop depth guard" \
  [expr {[rxcount $utl {void actionlog_suppress_push}] >= 1 &&
         [rxcount $utl {void actionlog_suppress_pop}]  >= 1}]
check "S4 suppress-scope: scheduler.c wires -suppress push|pop + the absolute set" \
  [expr {[rxcount $sched {!strcmp\(argv\[3\], "push"\)}] >= 1 &&
         [rxcount $sched {!strcmp\(argv\[2\], "actionlog_suppress"\)}] >= 1}]
# NOTE: abort_operation is deliberately NOT suppress-wrapped (adversarial-review
# MAJOR, §20): its STARTPOLYGON arm calls new_polygon(END) which self-logs a real
# `xschem polygon` line, so a blanket wrap would drop it. The composite hazard is
# closed via the replay seam + the general push/pop primitive instead. The
# suppress-gate test's case (g) locks the "abort must not suppress" behaviour.
check "S4 suppress-scope: replay_action_log seam push AND pop (xschem.tcl)" \
  [expr {[rxcount $xtcl {log_action -suppress push}] >= 1 &&
         [rxcount $xtcl {log_action -suppress pop}]  >= 1}]

# ---------------------------------------------------------------------------
# S5) RUNTIME CANARY: exactly-once end-to-end (static scans can't see a broken
#     suppress flag or dedup at runtime). Cheap no-fixture verbs only.
# ---------------------------------------------------------------------------
set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  check "S5 runtime canary (skipped: no --logdir)" 1 "static scans only"
} else {
  proc logcount {pat} {
    set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
    set n 0
    foreach l [split $b \n] { if {[string match $pat $l]} { incr n } }
    return $n
  }
  foreach verb {undo redo copy trim_wires} {
    set c0 [logcount "xschem $verb"]
    xschem $verb
    check "S5 script 'xschem $verb' -> exactly +1" \
      [expr {[logcount "xschem $verb"] == $c0 + 1}] "c0=$c0 now=[logcount "xschem $verb"]"
  }
  set c0 [logcount {xschem copy}]
  menu_action_logged {xschem copy}
  check "S5 menu_action_logged dedup live (copy exactly +1)" \
    [expr {[logcount {xschem copy}] == $c0 + 1}] "c0=$c0 now=[logcount {xschem copy}]"
}

# ---------------------------------------------------------------------------
# S6) new_schematic switch SEAM EXCLUSIVITY (atom 12 / 0053): the Cadence Ctrl-E
#     parent-window hop is logged ONLY at the cadence::focus_window seam. The core
#     `new_schematic switch` is shared by the tab-strip click machinery
#     (xschem.tcl `... switch $w {} 0`, no-draw), alt2 toggle and window-open paths
#     -- logging in the C core (or in any of those Tcl callers) would flood every
#     tab redraw. So: exactly ONE Tcl file logs a `new_schematic switch` line, it is
#     utils/cadence_nav.tcl, and the C scheduler branch logs it nowhere.
# ---------------------------------------------------------------------------
set nsw_files {}
set nsw_total 0
foreach rel [concat [glob -directory [file join $REPO src] *.tcl] \
                    [glob -directory [file join $REPO utils] *.tcl]] {
  set t [srctext [string range $rel [expr {[string length $REPO]+1}] end]]
  set n 0
  foreach L [split $t \n] {
    if {[regexp {^\s*#} $L]} continue
    if {[regexp {log_action\s+["\{]?xschem new_schematic switch} $L]} { incr n }
  }
  if {$n > 0} { lappend nsw_files [file tail $rel] ; incr nsw_total $n }
}
check "S6 exactly one Tcl 'new_schematic switch' log line exists" \
  [expr {$nsw_total == 1}] "total=$nsw_total files=$nsw_files"
check "S6 the sole 'new_schematic switch' logger is cadence_nav.tcl (focus_window seam)" \
  [expr {$nsw_files eq {cadence_nav.tcl}}] "files=$nsw_files"
# The C cores must not self-log the SWITCH form (that is the tab-strip/alt2/window-open
# machinery). Scan ALL C files the switch machinery lives in -- scheduler.c (the dispatch
# branch) AND xinit.c (switch_window/new_schematic) AND callback.c (the EnterNotify/FocusIn
# context switch) -- not scheduler.c alone. Match `new_schematic switch` SPECIFICALLY, so
# the legitimate `new_schematic destroy` window-close self-logs (xinit.c:2240/2331, the
# close-window verb) are not false-positives.
set nsw_c 0
foreach cf {scheduler.c xinit.c callback.c} {
  incr nsw_c [rxcount [srctext src/$cf] {log_action\w*\([^;]*"xschem new_schematic switch}]
}
check "S6 no C core self-logs the new_schematic SWITCH form (machinery must stay silent)" \
  [expr {$nsw_c == 0}] "got=$nsw_c across scheduler.c+xinit.c+callback.c"

# ---------------------------------------------------------------------------
# S7) perform_action BOUNDARY EXCLUSIVITY (Refactor B atoms 1-2 / trim_wires, align):
#     each migrated verb's readonly gate + log site live SOLELY in perform_action.
#     Every entry point (scheduler branch, the inline legacy-switch key, and the
#     menu/toolbar/command-palette that reach the branch via `xschem <verb>`) funnels
#     through it. This block fails closed if a future edit re-adds a SCATTERED
#     readonly check or log_action for a migrated verb at any entry point -- the exact
#     per-path-checklist regression the boundary abolishes (audit §3.1). The S1
#     rows above pin the boundary's positive presence; these pin its exclusivity.
#     Both verbs stay in S2 CVERBS (a scripted/replayed `xschem <verb>` re-executes
#     AND self-logs -- a real re-executable verb, not a coordinate-form bypass) and
#     deliberately OUT of S3 (their log lives in the boundary, reached from the
#     branch, not in a shared core the branch must stay silent for).
# ---------------------------------------------------------------------------
check "S7 scheduler.c: NO scattered log_action(\"xschem trim_wires\") (branch delegates to the boundary)" \
  [expr {[rxcount $sched {log_action\("xschem trim_wires"}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem trim_wires"}]"
check "S7 callback.c: NO scattered log_action(\"xschem trim_wires\") ('&' key delegates to the boundary)" \
  [expr {[rxcount $cbtext {log_action\("xschem trim_wires"}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem trim_wires"}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"trim_wires\") (the boundary's generic gate covers it)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "trim_wires"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "trim_wires"\)}]"
check "S7 scheduler.c: NO scattered log_action(\"xschem align\") (branch delegates to the boundary)" \
  [expr {[rxcount $sched {log_action\("xschem align"}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem align"}]"
check "S7 callback.c: NO scattered log_action(\"xschem align\") (Alt-U key delegates to the boundary)" \
  [expr {[rxcount $cbtext {log_action\("xschem align"}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem align"}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"align\") (the boundary's generic gate covers it)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "align"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "align"\)}]"
# rotate_in_place (Refactor B atom 3): the STANDALONE verb's readonly gate + log site live
# SOLELY in perform_action. The mid-gesture STARTMOVE/STARTCOPY arms (scheduler branch +
# Alt-R key) stay raw and log NOTHING at the verb level (they are logged at move/copy END,
# 0069) -- so `log_action("xschem rotate_in_place")` must be ZERO in BOTH files, and the
# scheduler branch drops its scattered readonly_reject (gesture arms are unreachable read-only).
check "S7 scheduler.c: NO scattered log_action(\"xschem rotate_in_place\") (standalone delegates to the boundary; gesture arms are silent)" \
  [expr {[rxcount $sched {log_action\("xschem rotate_in_place"}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem rotate_in_place"}]"
check "S7 callback.c: NO scattered log_action(\"xschem rotate_in_place\") (Alt-R + verb-noun apply delegate to the boundary)" \
  [expr {[rxcount $cbtext {log_action\("xschem rotate_in_place"}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem rotate_in_place"}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"rotate_in_place\") (the boundary's generic gate covers the standalone verb)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "rotate_in_place"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "rotate_in_place"\)}]"
# flip_in_place (Refactor B atom 4): the exact mirror of rotate_in_place. The STANDALONE verb's
# readonly gate + log site live SOLELY in perform_action. The mid-gesture STARTMOVE/STARTCOPY arms
# (scheduler branch + Alt-F key) stay raw and log NOTHING at the verb level (logged at move/copy END,
# 0069) -- so `log_action("xschem flip_in_place")` must be ZERO in BOTH files, and the scheduler
# branch drops its scattered readonly_reject (gesture arms are unreachable read-only). NB the regex
# is literal `flip_in_place"` -- it does NOT match `flipv_in_place"` (a `v` intervenes), so the two
# verbs are counted independently below.
check "S7 scheduler.c: NO scattered log_action(\"xschem flip_in_place\") (standalone delegates to the boundary; gesture arms are silent)" \
  [expr {[rxcount $sched {log_action\("xschem flip_in_place"}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem flip_in_place"}]"
check "S7 callback.c: NO scattered log_action(\"xschem flip_in_place\") (Alt-F + verb-noun apply delegate to the boundary)" \
  [expr {[rxcount $cbtext {log_action\("xschem flip_in_place"}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem flip_in_place"}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"flip_in_place\") (the boundary's generic gate covers the standalone verb)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "flip_in_place"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "flip_in_place"\)}]"
# flipv_in_place (Refactor B atom 5): the LAST in-place transform. The STANDALONE verb's readonly
# gate + log site live SOLELY in perform_action. The mid-gesture STARTMOVE/STARTCOPY arms (scheduler
# branch + Alt-V key) stay raw and log NOTHING at the verb level (logged at move/copy END, 0069) --
# so `log_action("xschem flipv_in_place")` must be ZERO in BOTH files, and the scheduler branch drops
# its scattered readonly_reject. The literal `flipv_in_place"` regex is distinct from `flip_in_place"`
# / `rotate_in_place"`. After atom 5 all four in-place transforms are on the boundary.
check "S7 scheduler.c: NO scattered log_action(\"xschem flipv_in_place\") (standalone delegates to the boundary; gesture arms are silent)" \
  [expr {[rxcount $sched {log_action\("xschem flipv_in_place"}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem flipv_in_place"}]"
check "S7 callback.c: NO scattered log_action(\"xschem flipv_in_place\") (Alt-V + verb-noun apply delegate to the boundary)" \
  [expr {[rxcount $cbtext {log_action\("xschem flipv_in_place"}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem flipv_in_place"}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"flipv_in_place\") (the boundary's generic gate covers the standalone verb)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "flipv_in_place"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "flipv_in_place"\)}]"
# rotate (Refactor B atom 6 -- the FIRST arg-carrying verb, the pivot form `xschem rotate x0 y0`):
# the STANDALONE verb's readonly gate + the ONE `xschem rotate x0 y0` log site (via core_log_action)
# live SOLELY in perform_action. The mid-gesture STARTMOVE/STARTCOPY arms (scheduler branch + Shift-R
# key) stay raw and log NOTHING at the verb level (logged at move/copy END as move_objects/
# copy_objects, 0069). UNLIKE the bare in-place verbs, the boundary's core_log_action legitimately
# CONTAINS one `log_action("xschem rotate %...")` (the pivot format), so scheduler.c cannot forbid ALL
# of them -- it must have EXACTLY ONE (the core_log_action site), with the scheduler rotate BRANCH
# carrying none and every callback.c entry carrying ZERO. The literal `rotate %` (rotate+space+%)
# regex does NOT match `rotate_in_place` (no space after "rotate"), and `"rotate"` (rotate+quote) does
# NOT match `"rotate_in_place"`, so the two verbs are counted independently.
check "S7 scheduler.c: EXACTLY ONE log_action(\"xschem rotate %\") -- the core_log_action pivot site (the branch delegates to the boundary)" \
  [expr {[rxcount $sched {log_action\("xschem rotate %}] == 1}] \
  "got=[rxcount $sched {log_action\("xschem rotate %}]"
check "S7 callback.c: NO scattered log_action(\"xschem rotate %\") (Shift-R + Alt-R group + verb-noun apply delegate to the boundary; group FLIP keeps its %s form)" \
  [expr {[rxcount $cbtext {log_action\("xschem rotate %}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem rotate %}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"rotate\") (the boundary's generic gate covers the standalone verb)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "rotate"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "rotate"\)}]"
# flip (Refactor B atom 7 -- the SECOND arg-carrying verb, the pivot form `xschem flip x0 y0`, a
# near-clone of rotate): the STANDALONE verb's readonly gate + the ONE `xschem flip x0 y0` log site
# (via core_log_action) live SOLELY in perform_action. The mid-gesture STARTMOVE/STARTCOPY arms
# (scheduler branch + Shift-F key) stay raw and log NOTHING at the verb level (logged at move/copy END
# as move_objects/copy_objects, 0069). Like rotate, core_log_action legitimately CONTAINS one
# `log_action("xschem flip %...")` (the pivot format), so scheduler.c must have EXACTLY ONE (the
# core_log_action site), with the scheduler flip BRANCH carrying none and every callback.c entry
# carrying ZERO. The literal `flip %` (flip+space+%) regex does NOT match `flipv %` (a `v` intervenes
# before the space) nor `flip_in_place` (an `_` follows), and `"flip"` (flip+quote) does NOT match
# `"flipv"`/`"flip_in_place"`, so flip is counted independently of flipv.
check "S7 scheduler.c: EXACTLY ONE log_action(\"xschem flip %\") -- the core_log_action pivot site (the branch delegates to the boundary)" \
  [expr {[rxcount $sched {log_action\("xschem flip %}] == 1}] \
  "got=[rxcount $sched {log_action\("xschem flip %}]"
check "S7 callback.c: NO scattered log_action(\"xschem flip %\") (Shift-F + Alt-F group + verb-noun apply all delegate to the boundary)" \
  [expr {[rxcount $cbtext {log_action\("xschem flip %}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem flip %}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"flip\") (the boundary's generic gate covers the standalone verb)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "flip"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "flip"\)}]"
# flipv (Refactor B atom 8 -- the THIRD and LAST arg-carrying pivot verb, the pivot form
# `xschem flipv x0 y0`, the mirror of flip): the STANDALONE verb's readonly gate + the ONE
# `xschem flipv x0 y0` log site (via core_log_action) live SOLELY in perform_action. The
# mid-gesture STARTMOVE/STARTCOPY arms (scheduler branch + Shift-V key) stay raw and log NOTHING
# at the verb level (logged at move/copy END as move_objects/copy_objects, 0069). Like rotate/flip,
# core_log_action legitimately CONTAINS one `log_action("xschem flipv %...")` (the pivot format), so
# scheduler.c must have EXACTLY ONE (the core_log_action site), with the scheduler flipv BRANCH
# carrying none and every callback.c entry carrying ZERO. The literal `flipv %` (flipv+space+%) regex
# does NOT match `flip %` (a `v` intervenes before the space) nor `flipv_in_place` (an `_` follows),
# and `"flipv"` (flipv+quote) does NOT match `"flip"`/`"flipv_in_place"`, so flipv is counted
# independently of BOTH flip and flipv_in_place -- and this migration must NOT perturb flip's counts.
check "S7 scheduler.c: EXACTLY ONE log_action(\"xschem flipv %\") -- the core_log_action pivot site (the branch delegates to the boundary)" \
  [expr {[rxcount $sched {log_action\("xschem flipv %}] == 1}] \
  "got=[rxcount $sched {log_action\("xschem flipv %}]"
check "S7 callback.c: NO scattered log_action(\"xschem flipv %\") (Shift-V + verb-noun apply delegate to the boundary; flipv has no group arm)" \
  [expr {[rxcount $cbtext {log_action\("xschem flipv %}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem flipv %}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"flipv\") (the boundary's generic gate covers the standalone verb)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "flipv"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "flipv"\)}]"
# flip counts must stay EXACTLY as atom 7 left them -- flipv's migration must not perturb them.
check "S7 (flip unperturbed) scheduler.c: still EXACTLY ONE log_action(\"xschem flip %\")" \
  [expr {[rxcount $sched {log_action\("xschem flip %}] == 1}] \
  "got=[rxcount $sched {log_action\("xschem flip %}]"
check "S7 (flip unperturbed) callback.c: still ZERO log_action(\"xschem flip %\")" \
  [expr {[rxcount $cbtext {log_action\("xschem flip %}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem flip %}]"
# break_wires (Refactor B atom 9 -- the FIRST NON-transform verb, arg is a FLAG (0/1) not a pivot):
# the readonly gate + the TWO `xschem break_wires [1]` log forms (via core_log_action) live SOLELY in
# perform_action. break_wires has NO mid-gesture split (not a transform) -- both keys ('!' bare /
# Ctrl-! remove) and the scheduler branch fully cross the boundary. UNLIKE the single-form pivot verbs,
# core_log_action legitimately holds TWO break_wires log lines (the bare + the remove form), so
# scheduler.c must have EXACTLY TWO in total -- ONE of each form -- with the scheduler BRANCH carrying
# none and every callback.c entry carrying ZERO. The literals `break_wires 1"` (a space+1 before the
# quote) and `break_wires")` (a quote then a paren) are MUTUALLY EXCLUSIVE and counted independently,
# so a re-scattered branch log of EITHER form fails closed; and neither matches break_wires_at_pins /
# break_wires_at_point / break_wires_at_attach_points (an `_` follows in all three). break_wires stays
# in S2 CVERBS (a scripted/replayed `xschem break_wires [1]` re-executes AND self-logs) and OUT of S3.
check "S7 scheduler.c: EXACTLY ONE log_action(\"xschem break_wires 1\") -- the core_log_action REMOVE form (the branch delegates to the boundary)" \
  [expr {[rxcount $sched {log_action\("xschem break_wires 1"}] == 1}] \
  "got=[rxcount $sched {log_action\("xschem break_wires 1"}]"
check "S7 scheduler.c: EXACTLY ONE log_action(\"xschem break_wires\") -- the core_log_action BARE form (the branch delegates to the boundary)" \
  [expr {[rxcount $sched {log_action\("xschem break_wires"\)}] == 1}] \
  "got=[rxcount $sched {log_action\("xschem break_wires"\)}]"
check "S7 scheduler.c: EXACTLY TWO log_action(\"xschem break_wires...\") in total -- both forms live in core_log_action, nowhere else" \
  [expr {[rxcount $sched {log_action\("xschem break_wires}] == 2}] \
  "got=[rxcount $sched {log_action\("xschem break_wires}]"
check "S7 callback.c: NO scattered log_action(\"xschem break_wires...\") (both '!'/Ctrl-! keys delegate to the boundary)" \
  [expr {[rxcount $cbtext {log_action\("xschem break_wires}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem break_wires}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"break_wires\") (the boundary's generic gate covers the verb)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "break_wires"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "break_wires"\)}]"
# floaters_from_selected_inst (Refactor B atom 10 -- the SECOND non-transform verb, a BARE no-arg verb like
# trim_wires): the readonly gate + the log site live SOLELY in perform_action. floaters is BARE (no pivot,
# no flag), so its log is the shared `xschem %s` core_log_action DEFAULT line -- there is NO per-verb
# `log_action("xschem floaters_from_selected_inst")` anywhere (contrast the EXACTLY-N pivot/flag verbs
# rotate/flip/flipv/break_wires whose forms live in core_log_action). So scheduler.c AND callback.c must
# have ZERO such literal. There is NO key entry point -- the callback.c ZERO check guards against a future
# key re-adding a scattered log. The branch NEVER had a scheduler_readonly_reject; the boundary's generic
# gate now covers it (a 0041/0051 close), so a re-scattered per-verb readonly_reject also fails closed.
# floaters_from_selected_inst() is strictly 1:1 (only its own scheduler branch calls it), so unlike
# trim_wires there is no sub-step to lock. floaters stays in S2 CVERBS, OUT of S3.
check "S7 scheduler.c: NO scattered log_action(\"xschem floaters_from_selected_inst\") (branch delegates to the boundary; the log is the shared bare %s form)" \
  [expr {[rxcount $sched {log_action\("xschem floaters_from_selected_inst"}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem floaters_from_selected_inst"}]"
check "S7 callback.c: NO scattered log_action(\"xschem floaters_from_selected_inst\") (no key entry point; guards a future re-scatter)" \
  [expr {[rxcount $cbtext {log_action\("xschem floaters_from_selected_inst"}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem floaters_from_selected_inst"}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"floaters_from_selected_inst\") (the boundary's generic gate covers the verb -- the branch never had one)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "floaters_from_selected_inst"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "floaters_from_selected_inst"\)}]"
# attach_labels (Refactor B atom 11 -- the THIRD non-transform verb; the arg is a FLAG `interactive`
# (0/1/2), not a pivot): the readonly gate + the TWO `xschem attach_labels [n]` log forms (via
# core_log_action) live SOLELY in perform_action. attach_labels has NO mid-gesture split (not a
# transform). UNLIKE break_wires (which collapses any nonzero to 1), attach_labels PRESERVES the value
# with `%d`, so core_log_action legitimately holds TWO forms (the bare `xschem attach_labels` for
# argc==2, and the value form `xschem attach_labels %d` for argc>2). So scheduler.c must have EXACTLY
# TWO in total -- ONE of each form -- with the scheduler BRANCH carrying none (it delegates) and
# callback.c carrying ZERO (the Shift+H interactive-dialog key calls the raw core, csv-nolog, and never
# self-logs `xschem attach_labels`). The literals `attach_labels %` (a space+% before the format) and
# `attach_labels")` (a quote then a paren) are MUTUALLY EXCLUSIVE and counted independently, so a
# re-scattered branch log of EITHER form fails closed; and neither matches attach_labels_to_inst (an `_`
# follows). attach_labels stays in S2 CVERBS (a scripted/replayed `xschem attach_labels [n]` re-executes
# AND self-logs) and OUT of S3. The SHARED core attach_labels_to_inst() is ALSO a raw netlisting
# sub-step (show_unconnected_pins, netlist.c) + the Shift+H dialog key -- both stay BELOW the boundary
# (raw core, no self-log), exactly the trim_wires-is-a-sub-step-of-align pattern; the runtime .tcl case
# (e) locks that `xschem show_unconnected_pins` and the key emit ZERO `xschem attach_labels`.
check "S7 scheduler.c: EXACTLY ONE log_action(\"xschem attach_labels %\") -- the core_log_action VALUE form (the branch delegates to the boundary)" \
  [expr {[rxcount $sched {log_action\("xschem attach_labels %}] == 1}] \
  "got=[rxcount $sched {log_action\("xschem attach_labels %}]"
check "S7 scheduler.c: EXACTLY ONE log_action(\"xschem attach_labels\") -- the core_log_action BARE form (the branch delegates to the boundary)" \
  [expr {[rxcount $sched {log_action\("xschem attach_labels"\)}] == 1}] \
  "got=[rxcount $sched {log_action\("xschem attach_labels"\)}]"
check "S7 scheduler.c: EXACTLY TWO log_action(\"xschem attach_labels...\") in total -- both forms live in core_log_action, nowhere else" \
  [expr {[rxcount $sched {log_action\("xschem attach_labels}] == 2}] \
  "got=[rxcount $sched {log_action\("xschem attach_labels}]"
check "S7 callback.c: NO scattered log_action(\"xschem attach_labels...\") (the Shift+H dialog key calls the raw core, csv-nolog -- it never self-logs)" \
  [expr {[rxcount $cbtext {log_action\("xschem attach_labels}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem attach_labels}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"attach_labels\") (the boundary's generic gate covers the verb -- the branch never had one)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "attach_labels"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "attach_labels"\)}]"
# toggle_ignore (Refactor B atom 12 -- the FIRST FRICTION-FREE-SCOUTED verb, a BARE no-arg verb like
# floaters/trim_wires): the readonly gate + the log site live SOLELY in perform_action. toggle_ignore is
# BARE (no pivot, no flag), so its log is the shared `xschem %s` core_log_action DEFAULT line -- there is
# NO per-verb `log_action("xschem toggle_ignore")` anywhere (contrast the EXACTLY-N pivot/flag verbs
# rotate/flip/flipv/break_wires/attach_labels whose forms live in core_log_action). So scheduler.c AND
# callback.c must have ZERO such literal. UNLIKE floaters (no key), toggle_ignore HAS a key -- but the
# Shift+T key (act_toggle_ignore) routes THROUGH perform_action, so it carries NO `log_action("xschem
# toggle_ignore")` C literal either (its pre-migration Layer A log came from actions.csv `d->log_cmd`, NOT a
# C literal, and now DEDUPS against the boundary). The callback.c ZERO check thus locks that the key routes
# through the boundary and never self-logs a scattered literal -- a re-scattered C literal in either file
# fails closed. The branch NEVER had a scheduler_readonly_reject; the boundary's generic gate now covers it
# (a 0041/0051 close -- purely additive, this branch had NEITHER a gate NOR a log before), so a re-scattered
# per-verb readonly_reject also fails closed. toggle_ignore() is 1:1 with the verb (called ONLY by the branch
# + the key, both on the boundary), so unlike attach_labels there is no sub-step to lock. toggle_ignore stays
# in S2 CVERBS, OUT of S3.
check "S7 scheduler.c: NO scattered log_action(\"xschem toggle_ignore\") (branch delegates to the boundary; the log is the shared bare %s form)" \
  [expr {[rxcount $sched {log_action\("xschem toggle_ignore"}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem toggle_ignore"}]"
check "S7 callback.c: NO scattered log_action(\"xschem toggle_ignore\") (Shift+T key routes through the boundary; its Layer A log is from actions.csv, not a C literal -- a re-scatter fails closed)" \
  [expr {[rxcount $cbtext {log_action\("xschem toggle_ignore"}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem toggle_ignore"}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"toggle_ignore\") (the boundary's generic gate covers the verb -- the branch never had one)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "toggle_ignore"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "toggle_ignore"\)}]"
# reset_inst_prop (Refactor B atom 13 -- the FIRST BENEFICIARY of the log-on-success boundary change,
# and the FIRST VALIDATING verb): the readonly gate + the ONE `xschem reset_inst_prop <ref>` log form
# (via core_log_action) live SOLELY in perform_action. It is arg-carrying (a single %s referent, like
# rotate/flip's single pivot form), so core_log_action legitimately holds EXACTLY ONE
# `log_action("xschem reset_inst_prop %s"...)` and scheduler.c must have EXACTLY that ONE -- the
# scheduler BRANCH carries none (it delegates) and callback.c ZERO (no key entry point). NB the branch's
# early-error Tcl_SetResult("xschem reset_inst_prop needs 1 more argument" / "... instance not found")
# are NOT log_action calls, so they don't perturb this count. The literal `reset_inst_prop %` (space+%)
# does not collide with any other verb. The old branch HAD a scattered scheduler_readonly_reject(...,
# "reset_inst_prop"); the boundary's generic gate now covers it, so a re-scattered per-verb one fails
# closed. reset_inst_prop stays in S2 CVERBS (a scripted/replayed `xschem reset_inst_prop <ref>`
# re-executes AND self-logs) and OUT of S3 (its log lives in the boundary, reached from the branch).
check "S7 scheduler.c: EXACTLY ONE reset_inst_prop referent-build (av\[1\]=verb; av\[2\]=argv\[2\]) -- the core_log_action Tcl_Merge site (the branch delegates to the boundary)" \
  [expr {[rxcount $sched {(?n)av\[1\] = verb; av\[2\] = argv\[2\];$}] == 1}] \
  "got=[rxcount $sched {(?n)av\[1\] = verb; av\[2\] = argv\[2\];$}]"
check "S7 scheduler.c: NO scattered raw log_action(\"xschem reset_inst_prop\") (the replay-unsafe %s form must not reappear -- Tcl_Merge is the only emit)" \
  [expr {[rxcount $sched {log_action\("xschem reset_inst_prop}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem reset_inst_prop}]"
check "S7 callback.c: NO scattered log_action(\"xschem reset_inst_prop\") (no key entry point; guards a future re-scatter)" \
  [expr {[rxcount $cbtext {log_action\("xschem reset_inst_prop}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem reset_inst_prop}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"reset_inst_prop\") (the boundary's generic gate covers the verb -- the old branch's per-verb one is GONE)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "reset_inst_prop"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "reset_inst_prop"\)}]"
# replace_symbol (Refactor B atom 14 -- the SECOND VALIDATING verb, and the FIRST per-verb migration to
# carry a FAST-FLAG log gate; a PLAIN migration onto the UNCHANGED atom-13 log-on-success boundary): the
# readonly gate + the ONE `xschem replace_symbol <inst> <sym>` log form (via core_log_action, gated on
# !fast) live SOLELY in perform_action. It is TWO-arg (argv[2]+argv[3]), so core_log_action holds EXACTLY
# ONE `log_action_argv(4, av)` built from `av[3] = argv[3];` (UNIQUE to replace_symbol -- no other verb
# uses av[3]) and scheduler.c must have EXACTLY that ONE -- the scheduler BRANCH carries none (it
# delegates) and callback.c ZERO (no key entry point). NB the branch's early-error Tcl_SetResult("xschem
# replace_symbol needs 2 additional arguments" / "... instance not found") are NOT log_action calls, so
# they don't perturb this count; NB2 print_spice_element (scheduler.c ~7470) has a PRE-EXISTING copy-paste
# Tcl_SetResult "xschem replace_symbol: instance not found" -- also NOT a log_action, so the raw-log scan
# stays 0 (it is NOT a second replace_symbol entry and NOT atom 14's to fix). The FAST-FLAG gate is pinned
# so a revert to unconditional logging (which would log the fast machinery sub-mode) fails closed. The old
# branch HAD a scattered scheduler_readonly_reject(..., "replace_symbol"); the boundary's generic gate now
# covers it, so a re-scattered per-verb one fails closed. replace_symbol stays in S2 CVERBS (a
# scripted/replayed `xschem replace_symbol <inst> <sym>` re-executes AND self-logs) and OUT of S3 (its log
# lives in the boundary, reached from the branch).
check "S7 scheduler.c: EXACTLY ONE replace_symbol referent-build (av\[3\] = argv\[3\];) -- the core_log_action two-arg Tcl_Merge site (the branch delegates to the boundary); av\[3\] is unique to replace_symbol" \
  [expr {[rxcount $sched {av\[3\] = argv\[3\];}] == 1}] \
  "got=[rxcount $sched {av\[3\] = argv\[3\];}]"
check "S7 scheduler.c: EXACTLY ONE replace_symbol log_action_argv(4, av) emit (distinct from reset_inst_prop's (3, av))" \
  [expr {[rxcount $sched {log_action_argv\(4, av\);}] == 1}] \
  "got=[rxcount $sched {log_action_argv\(4, av\);}]"
check "S7 scheduler.c: EXACTLY ONE replace_symbol FAST-FLAG log gate (if(argc <= 4 || strcmp(argv\[4\], \"fast\"))) -- a revert to unconditional logging makes the fast machinery form log +1, failing test (e) closed" \
  [expr {[rxcount $sched {if\(argc <= 4 \|\| strcmp\(argv\[4\], "fast"\)\)}] == 1}] \
  "got=[rxcount $sched {if\(argc <= 4 \|\| strcmp\(argv\[4\], "fast"\)\)}]"
check "S7 scheduler.c: NO scattered raw log_action(\"xschem replace_symbol\") (the replay-unsafe %s form must not reappear -- Tcl_Merge is the only emit; the print_spice_element Tcl_SetResult copy-paste is NOT a log_action)" \
  [expr {[rxcount $sched {log_action\("xschem replace_symbol}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem replace_symbol}]"
check "S7 callback.c: NO scattered log_action(\"xschem replace_symbol\") (no key entry point; guards a future re-scatter)" \
  [expr {[rxcount $cbtext {log_action\("xschem replace_symbol}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem replace_symbol}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"replace_symbol\") (the boundary's generic gate covers the verb -- the old branch's per-verb one is GONE)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "replace_symbol"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "replace_symbol"\)}]"
# show_unconnected_pins (Refactor B atom 15 -- the friction-free BARE no-arg verb from the fresh atom-15
# fan-out scout, like floaters/toggle_ignore): the readonly gate + the log site live SOLELY in
# perform_action. It is BARE (no pivot, no flag), so its log is the shared `xschem %s` core_log_action
# DEFAULT line -- there is NO per-verb `log_action("xschem show_unconnected_pins")` anywhere (contrast the
# EXACTLY-N pivot/flag verbs rotate/flip/flipv/break_wires/attach_labels whose forms live in
# core_log_action). So scheduler.c AND callback.c must have ZERO such literal. There is NO key entry point
# (menu-only + command palette, both `xschem show_unconnected_pins` verbatim) -- the callback.c ZERO check
# guards against a future key re-adding a scattered log. The branch NEVER had a scheduler_readonly_reject;
# the boundary's generic gate now ADDS one (a correctness fix -- the old branch placed lab_show labels on a
# read-only cell), so a re-scattered per-verb readonly_reject also fails closed. show_unconnected_pins() is
# the SECOND caller of the shared attach_labels_to_inst() core (after atom 11): that raw call stays BELOW
# the boundary (its log rides the `attach_labels` verb, not the C fn), so routing this verb double-logs
# NOTHING -- the runtime .tcl case (g) locks that `xschem show_unconnected_pins` emits ZERO `xschem
# attach_labels`. show_unconnected_pins stays in S2 CVERBS, OUT of S3.
check "S7 scheduler.c: NO scattered log_action(\"xschem show_unconnected_pins\") (branch delegates to the boundary; the log is the shared bare %s form)" \
  [expr {[rxcount $sched {log_action\("xschem show_unconnected_pins"}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem show_unconnected_pins"}]"
check "S7 callback.c: NO scattered log_action(\"xschem show_unconnected_pins\") (no key entry point; guards a future re-scatter)" \
  [expr {[rxcount $cbtext {log_action\("xschem show_unconnected_pins"}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem show_unconnected_pins"}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"show_unconnected_pins\") (the boundary's generic gate covers the verb -- the branch never had one; the gate is a NEW correctness fix)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "show_unconnected_pins"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "show_unconnected_pins"\)}]"
# embed_rawfile (Refactor B atom 16 -- the DEFERRED runner-up from the atom-15 scout; a HYBRID of the
# reset_inst_prop §33 single-STRING-referent/argc-gate template and the floaters/show_unconnected_pins
# §30/§35 core-owns-its-own-undo template): the readonly gate + the ONE `xschem embed_rawfile <path>` log
# form (via core_log_action) live SOLELY in perform_action. It is arg-carrying (a single RAW-path %s
# referent, like reset_inst_prop's single referent), so core_log_action legitimately holds EXACTLY ONE
# referent-build + ONE log_action_argv emit, and scheduler.c must have EXACTLY that ONE -- the scheduler
# BRANCH carries none (it delegates) and callback.c ZERO (a PURE SCRIPTED verb: NO key/menu/palette/
# callback/Tcl caller). The referent array is named `ev` (NOT `av`) so its line-anchored build regex is
# TEXTUALLY DISTINCT from reset_inst_prop's byte-identical `av[...]` build -- if they shared a name the
# line-anchored (?n)...;$ regexes would each match BOTH lines, making each verb's count == 2 and breaking
# BOTH verbs' exclusivity rows (the COLLISION the task flags). The branch's early-error Tcl_SetResult
# ("xschem embed_rawfile needs a file argument") is NOT a log_action call, so it doesn't perturb the
# raw-log count. The branch NEVER HAD a scheduler_readonly_reject; the boundary's generic gate now ADDS
# one (a CORRECTNESS FIX -- the old branch embedded on a read-only cell), so a re-scattered per-verb
# readonly_reject also fails closed. embed_rawfile() is 1:1 with the verb (called ONLY by its own branch --
# no key, no other C caller, no Tcl caller), so unlike reset_inst_prop there is no sub-step to lock.
# embed_rawfile stays in S2 CVERBS (a scripted/replayed `xschem embed_rawfile <path>` re-executes AND
# self-logs) and OUT of S3 (its log lives in the boundary, reached from the branch).
check "S7 scheduler.c: EXACTLY ONE embed_rawfile referent-build (ev\[0\]=xschem; ev\[1\]=verb; ev\[2\]=argv\[2\]) -- the core_log_action Tcl_Merge site; `ev` (not `av`) keeps it distinct from reset_inst_prop's line-anchored build" \
  [expr {[rxcount $sched {(?n)ev\[0\] = "xschem"; ev\[1\] = verb; ev\[2\] = argv\[2\];$}] == 1}] \
  "got=[rxcount $sched {(?n)ev\[0\] = "xschem"; ev\[1\] = verb; ev\[2\] = argv\[2\];$}]"
check "S7 scheduler.c: EXACTLY ONE embed_rawfile log_action_argv(3, ev) emit (distinct from reset_inst_prop's (3, av) and replace_symbol's (4, av))" \
  [expr {[rxcount $sched {log_action_argv\(3, ev\);}] == 1}] \
  "got=[rxcount $sched {log_action_argv\(3, ev\);}]"
check "S7 scheduler.c: NO scattered raw log_action(\"xschem embed_rawfile\") (the replay-unsafe %s form must not reappear -- Tcl_Merge is the only emit)" \
  [expr {[rxcount $sched {log_action\("xschem embed_rawfile}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem embed_rawfile}]"
check "S7 callback.c: NO scattered log_action(\"xschem embed_rawfile\") (no key entry point; guards a future re-scatter)" \
  [expr {[rxcount $cbtext {log_action\("xschem embed_rawfile}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem embed_rawfile}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"embed_rawfile\") (the boundary's generic gate covers the verb -- the branch never had one; the gate is a NEW correctness fix)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "embed_rawfile"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "embed_rawfile"\)}]"
# COLLISION GUARD: embed_rawfile's `ev` build must NOT perturb reset_inst_prop's byte-identical `av` build
# (both are single-referent Tcl_Merge sites). Re-assert reset_inst_prop stays EXACTLY ONE on BOTH its
# line-anchored build and its (3, av) emit -- a regression that renamed embed's array back to `av` would
# make these == 2, failing closed here (and on reset_inst_prop's own S1/S7 rows).
check "S7 (reset_inst_prop unperturbed) scheduler.c: still EXACTLY ONE av-build (embed's ev name did not collide)" \
  [expr {[rxcount $sched {(?n)av\[0\] = "xschem"; av\[1\] = verb; av\[2\] = argv\[2\];$}] == 1}] \
  "got=[rxcount $sched {(?n)av\[0\] = "xschem"; av\[1\] = verb; av\[2\] = argv\[2\];$}]"
check "S7 (reset_inst_prop unperturbed) scheduler.c: still EXACTLY ONE log_action_argv(3, av)" \
  [expr {[rxcount $sched {log_action_argv\(3, av\);}] == 1}] \
  "got=[rxcount $sched {log_action_argv\(3, av\);}]"
# wire_cut (Refactor B atom 17 -- the SILENT-MUTATOR twin of break_wires (atom 9, §29); the SEPARATE
# Alt-Right gesture core break_wires_at_point (check.c) that §29 kept OFF break_wires' boundary): the
# readonly gate + the TWO `xschem wire_cut x y [noalign]` log forms (via core_log_action) live SOLELY in
# perform_action. Only the SCRIPTED coord form crosses (the scheduler branch's argc>3 guard) -- the
# no-coord GESTURE-START form stays RAW in the branch (arms ui_state, no mutation, no log, the rotate/flip
# STARTMOVE-stays-raw split). Like break_wires, core_log_action legitimately holds TWO log lines (the
# aligned + the noalign form), so scheduler.c must have EXACTLY TWO in total -- ONE of each form -- with
# the scheduler BRANCH carrying none (it delegates) and every callback.c entry carrying ZERO. The arg is
# numeric COORDS + a bareword FLAG (%.16g, NOT log_action_argv -- no metacharacter referent). The aligned
# literal `wire_cut %.16g %.16g"` (a quote right after the second %.16g) and the noalign literal
# `wire_cut %.16g %.16g noalign` (a space+noalign before the quote) are MUTUALLY EXCLUSIVE and counted
# independently, so a re-scattered branch log of EITHER form fails closed; and neither matches
# break_wires_at_point / break_wires_at_pins / break_wires_at_attach_points (an `_` follows in all three).
# The verb is ALWAYS arg-carrying, so a BARE `xschem wire_cut"` log form must be ZERO. OPTION (A): the
# interactive Alt-Right COMPLETION (callback.c break_wires_at_point at mousex/y_snap) stays RAW+silent, so
# callback.c must have ZERO `log_action("xschem wire_cut` (this guards a future gesture-logging edit from
# silently double-logging). The branch NEVER HAD a scheduler_readonly_reject; the boundary's generic gate
# now ADDS one (a CORRECTNESS FIX -- the old scripted coord form cut on a read-only cell). break_wires_at_point()
# is 1:1 with wire_cut's own entry points (the scheduler branch + the callback.c Alt-Right gesture), never
# another verb. wire_cut stays in S2 CVERBS (a scripted/replayed `xschem wire_cut x y [noalign]` re-executes
# AND self-logs) and OUT of S3.
check "S7 scheduler.c: EXACTLY ONE log_action(\"xschem wire_cut %.16g %.16g noalign\") -- the core_log_action NOALIGN form (the branch delegates to the boundary)" \
  [expr {[rxcount $sched {log_action\("xschem wire_cut %\.16g %\.16g noalign"}] == 1}] \
  "got=[rxcount $sched {log_action\("xschem wire_cut %\.16g %\.16g noalign"}]"
check "S7 scheduler.c: EXACTLY ONE log_action(\"xschem wire_cut %.16g %.16g\\\"\") -- the core_log_action ALIGNED form (quote-terminated, distinct from the noalign form)" \
  [expr {[rxcount $sched {log_action\("xschem wire_cut %\.16g %\.16g"}] == 1}] \
  "got=[rxcount $sched {log_action\("xschem wire_cut %\.16g %\.16g"}]"
check "S7 scheduler.c: EXACTLY TWO log_action(\"xschem wire_cut %...\") in total -- both forms live in core_log_action, nowhere else" \
  [expr {[rxcount $sched {log_action\("xschem wire_cut %}] == 2}] \
  "got=[rxcount $sched {log_action\("xschem wire_cut %}]"
check "S7 scheduler.c: NO scattered bare log_action(\"xschem wire_cut\") (the verb is always arg-carrying -- both forms are %.16g)" \
  [expr {[rxcount $sched {log_action\("xschem wire_cut"}] == 0}] \
  "got=[rxcount $sched {log_action\("xschem wire_cut"}]"
check "S7 callback.c: NO scattered log_action(\"xschem wire_cut...\") (option A: the interactive Alt-Right completion stays raw+silent)" \
  [expr {[rxcount $cbtext {log_action\("xschem wire_cut}] == 0}] \
  "got=[rxcount $cbtext {log_action\("xschem wire_cut}]"
check "S7 scheduler.c: NO scattered scheduler_readonly_reject(...,\"wire_cut\") (the boundary's generic gate covers the verb -- the branch never had one; the gate is a NEW correctness fix)" \
  [expr {[rxcount $sched {scheduler_readonly_reject\(interp, "wire_cut"\)}] == 0}] \
  "got=[rxcount $sched {scheduler_readonly_reject\(interp, "wire_cut"\)}]"
# atom-13 NESTING COUPLING (adversarial-review finding): the S1 existence rows above pin
# that the guard line, the log line and the reset line each EXIST, but not that log+reset are
# INSIDE the log-on-success block. A de-nest that keeps all three lines yet closes the
# `if(rc == TCL_OK) {` block early (moving core_log_action + Tcl_ResetResult OUT, back to
# unconditional) would satisfy every existence row while reintroducing the phantom-log
# regression. This regex requires BOTH core_log_action(verb,argc,argv) AND Tcl_ResetResult
# to appear before the FIRST `}` after the guard (i.e. still nested). `[^}]` matches newlines,
# and the intervening comments carry no `}`, so the block matches as one unit; the de-nest
# puts a `}` before core_log_action -> 0 matches -> fails closed. (Runtime (b) also catches it.)
check "S7 perform_action: core_log_action + Tcl_ResetResult stay NESTED inside the log-on-success if(rc == TCL_OK) block (atom 13 coupling; a de-nest reintroduces the unconditional-log regression)" \
  [expr {[rxcount $sched {if\(rc == TCL_OK\) \{[^\175]*core_log_action\(verb, argc, argv\);[^\175]*Tcl_ResetResult\(interp\);[^\175]*\175}] == 1}] \
  "got=[rxcount $sched {if\(rc == TCL_OK\) \{[^\175]*core_log_action\(verb, argc, argv\);[^\175]*Tcl_ResetResult\(interp\);[^\175]*\175}]"
check "S7 perform_action is defined EXACTLY once" \
  [expr {[rxcount $sched {int perform_action\(const char \*verb,}] == 1}] \
  "got=[rxcount $sched {int perform_action\(const char \*verb,}]"

catch {destroy .ciw}; update

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
