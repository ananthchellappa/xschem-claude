# Refactor B batch plan - perform_action boundary migrations (atoms 26+)

Generated 2026-07-18 by the phase-0 ranking workflow (fresh per-dispatch-group sweep of src/scheduler.c under the log-on-success contract). Rubric: doc/claude/code_analysis/perform_action_atom24_delete_friction_analysis.md section 2 (D1-D4 disqualifiers, F-* friction codes). Driver: RUNBOOK.md + DRIVER_PROMPT.md in this directory.

## Status legend
- `[ ]` pending   `[S]` scouted, verdict pending   `[x]` DONE (implemented + verified + committed)
- `[D]` DEFERRED (friction verdict - reason appended to the line)   `[F]` FAILED (needs human - reason appended)

## Rules of the batch
- Atom numbers are assigned at PROCEED time: next atom = 26 + (count of prior [x]). Deferred items burn NO atom number.
- Every item starts with a fresh-scout friction test (stage A) whose verdict is PROCEED or DEFER; DEFER is a SUCCESS outcome, not a failure.
- Baseline full_audit fails (pre-existing, NOT caused by the batch): test_ciw*, hi_descend*, lib_*, cadence_*, reopen_readonly, save_as_cellview, untitled_reuse, select_at, phase3_mints*, wire_split*, fluid_editing*, selflog_output-transform-keys (~14; driver records the exact list at batch start below).
- Baseline fail list at batch start (2026-07-18, exit=1, 14 tests): test_cadence_descend_newwin_ro, test_cadence_drag, test_ciw, test_descend_untitled_preserve, test_hi_descend, test_lib_manager_gui, test_lib_sweep, test_phase3_mints, test_reopen_readonly, test_save_as_cellview, test_select_at, test_selflog_output, test_untitled_reuse, test_wire_split. (test_fluid_editing PASSED this run despite the ~14 expectation note.)

## Ledger
- [x] 01 check_unique_names (T1-prescoped, fr4, logged-raw) - atom 26, decision doc effectively PROCEED: query/mutate split + '#' key routing closes the issue-0068 gap -> atom 26 DONE
- [x] 02 clear_drawing (T2-clean, fr1, silent) - lowest-friction silent mutation left, gains a readonly gate that does not exist today -> atom 27 DONE
- [x] 03 redo (T2-clean, fr1, logged-raw) - already boundary-shaped, zero-coverage consistency move onto core_log_action -> atom 28 DONE
- [D] 04 get_additional_symbols (T2-clean, fr2, silent) - real xctx->sym mutator but the transient/derived-state scope question must be settled first -> DEFERRED: what=1 state is derived netlisting cache (reclass D2 transient, out-of-scope), zero live Tcl callers, and standalone replay of a logged 0-line is destructive
- [x] 05 undo (T2-clean, fr2, logged-raw) - redo's twin, consistency-only with a normalizing-log wrinkle -> atom 29 DONE
- [D] 06 wire (T2-clean, fr3, silent) - best silent coverage win in the pool, wire_cut split shape with a branch-push undo reconcile -> DEFERRED: reclass D3 coordinate-form-bypass — new_wire (actions.c:4290-4331) already emits the exact `xschem wire %.16g ...` replay line at five sites and the branch is the designated silent replay receiver; plus test-harness coord-form machinery callers; rides the rank-24 replay-suppress+dedup unlock with text/rect/line/arc
- [D] 07 make_sch_from_sel (T3-heavy, fr3, logged-raw) - modal save-dialog inside a void core needs rc plumbing before log-on-success can avoid phantom-logging Cancel -> DEFERRED: rc-plumbing is not mechanical (cancel-as-TCL_ERROR would bgerror the Tk menu path) and modal-dialog filename needs a transformed-argv log pattern that does not exist
- [D] 08 instance (T3-heavy, fr6, silent) - highest-value silent placement carrying all five frictions plus the batch single-undo-transaction hazard -> DEFERRED: D3 reclass — log_placed_instance already emits the replay line, and boundary raw-argv logging can never dedup against the funnel's read-back form
- [D] 09 apply_properties (T3-heavy, fr6, logged-raw) - result-consuming property form + standing decision doc pinning the log at the Tcl layer; likely DEFER -> DEFERRED: boundary's Tcl_ResetResult would clobber the load-bearing 0/1/-1 result the property form dispatches on, and the ratified D1 decision pins the log at the Tcl layer
- [D] 10 fluid_pass (T4-unlock, fr4, silent) - name-routes the pass table and depends on unlogged arm state; expected DEFER unless a harness-exemption class emerges -> DEFERRED: harness-only verb (zero production entry) whose replay depends on unlogged fluid_snapshot arm state
- [D] 11 setprop (T4-unlock, fr99, logged-raw) - whole verb is D3/D4 but the per-subtype instance-arm split is the most plausible unlock in the pool -> DEFERRED: guard-locked in-source invariant forbids logging the shape arms and the mutating-raw-front instance-arm split is a new boundary pattern with zero coverage gain
- [D] 12 cut (T4-unlock, fr99, logged-raw) - two other verbs' cores wearing one name; friction-tests the composite inner-suppress boundary class -> DEFERRED: no cut core exists (branch = copy's + delete's cores) and the composite/inner-suppress boundary class it needs is undesigned; routing would touch landed atom-24 guards
- [D] 13 copy (T4-unlock, fr99, logged-raw) - D4 clipboard family; needs entry-dedup spanning three independent log sites -> DEFERRED: undesigned clipboard/disk-side-effect boundary class, plus copy needs a readonly-EXEMPT boundary variant that does not exist
- [D] 14 descend (T4-unlock, fr99, none) - self-logging core (log_action_descend); the exemption pattern it needs is the highest-leverage T4 friction test -> DEFERRED: needs a self-logging-core + result-preserving + readonly-exempt boundary variant that doesn't exist; scoped as its own pattern-extension atom
- [D] 15 descend_symbol (T4-unlock, fr99, none) - same shape as descend plus an embedded-symbol save leg; rides or falls with the rank-14 pattern -> DEFERRED: rank-14 automatic defer trigger fired (self-logging-core exemption pattern does not exist; needs self-log-exempt + readonly-exempt at once)
- [D] 16 go_back (T4-unlock, fr99, none) - core tail self-log covers three raw C entries; dialog-Cancel nondeterminism blocks a faithful replay line -> DEFERRED: descend-family rank-14 automatic defer (self-logging-core + readonly-exempt boundary variant ratified nonexistent)
- [D] 17 netlist (T4-unlock, fr99, logged-raw) - already does in-branch what the boundary lacks: transformed-argv conditional logging plus a consumed result -> DEFERRED: boundary lacks transformed-argv logging, result preservation, done_netlist witness gating, and readonly-exempt gating; migration gains zero coverage
- [D] 18 save (T4-unlock, fr99, logged-raw) - log deliberately lives at the branch because save(0,fast) is a shared confirm-wrapper entered from composites -> DEFERRED: file-op family undesigned (no undo/replay-witness semantics) + composite shared-core entries indiscriminable at save(); branch log already at the boundary, zero coverage gain
- [D] 19 saveas (T4-unlock, fr99, logged-raw) - core self-logs the RESOLVED path; needs dialog-arm/path-arm split + transformed-argv logging -> DEFERRED: transformed-argv (resolved-path) logging pattern nonexistent; boundary log would double the core's resolved self-log and re-log every replayed `saveas {path}` line
- [D] 20 reload (T4-unlock, fr99, logged-raw) - load composite with an Alt-S inline raw second entry; load-family boundary shape undesigned -> DEFERRED: load-family boundary undesigned (no 1:1 core to extract) + Alt-S inline second entry has no dedup channel; readonly gate would break read-only reload
- [D] 21 print_hilight_net (T4-unlock, fr99, logged-raw) - tcleval-routes an inner merge and mixes viewer/mutator modes; stress test for suppress-scope -> DEFERRED: suppress-scope composite pattern undesigned, and the routed merge only arms a pending STARTMERGE gesture so no truthful boundary effect-log exists
- [D] 22 make_symbol (T4-unlock, fr99, logged-raw) - deliberately allowed on read-only cells, so the all-or-nothing gate would wrongly refuse it -> DEFERRED: partial-readonly gating (allow verb, skip only the save leg) is not expressible in the one-gate contract
- [D] 23 make_sch (T4-unlock, fr99, logged-raw) - writes a NEW sibling .sch, object model untouched; disk-artifact class undesigned, zero gain -> DEFERRED: D2 disk-artifact class undesigned with zero net coverage gain (core self-log already covers both entries)
- [D] 24 text (T4-unlock, fr99, none) - canonical coordinate-store replay primitive; suppress + byte-dedup pattern here would retire the whole D3 family -> DEFERRED: both defer triggers confirmed (un-suppressed replay/machinery paths exist + read-back-vs-raw-argv byte-dedup structurally unachievable)
- [D] 25 rect (T4-unlock, fr99, silent) - silent D3 sibling with a genuine undo hole worth a standalone bug fix regardless of migration -> DEFERRED: rank-24 replay-suppress/byte-dedup unlock is itself deferred, and rect is NOT silent — actions.c:4584 emits the %.16g coord read-back form, making it a full D3 coordinate-form-bypass sibling of wire
- [D] 26 arc (T4-unlock, fr99, none) - interactive 3-click commit logs the exact same line; needs the unattempted log-site-relocation pattern -> DEFERRED: D3 coordinate-form-bypass confirmed (interactive commit at actions.c:4453 emits the exact scheduler-branch line) + rank-24 replay-suppress unlock itself deferred
- [D] 27 add_wire_label (T4-unlock, fr99, none) - drop is already logged in end_move_copy_logged and the 1/0 result is the 0122 commit witness -> DEFERRED: drop already logged in the wire_label_try_commit funnel; boundary logging would double-log unless the undesigned log-site-move pattern lands, and the 1/0 commit-witness result would be clobbered
- [D] 28 net_label (T4-unlock, fr99, silent) - gesture-arm at live cursor position; needs effective-coordinate drop logging plus three key-bypass dedups -> DEFERRED: gesture-arm at live cursor; drop already funnel-logged as `xschem instance`, boundary logging would double-record
- [D] 29 edit_vi_prop (T4-unlock, fr99, none) - mutation value comes from an external editor session, never 1:1 replayable; needs a new value-carrying sibling verb -> DEFERRED: coverage hole is FALSE - the core already self-logs the result as replayable setprop/set lines (0063 atom 10), putting it in the self-logging-core class where boundary migration would double-record
- [D] 30 line (T4-unlock, fr99, none) - D3 family tail riding the rank-24 suppress story, same coord-branch undo hole as rect -> DEFERRED: D3 coordinate-form-bypass confirmed (five %.16g emit sites in new_line PLACE, no suppress channel) and both plan defer triggers fire (rank-24 pattern deferred; un-suppressed machinery path via place_sym_pins.tcl)

## Item detail

### 01 check_unique_names
- tier: T1-prescoped | fr: 4 | gain: logged-raw | line: scheduler.c:2255
- wrinkles:
  - Mode-0 is a CURRENTLY-LOGGED read-only-safe query - raw front must retain log_action("...0") (novel vs image/instance_number unlogged splits)
  - Grep-guard row must become two rows; a ==1 count fails closed (test_selflog_grep_guard.tcl:368)
  - '#'/Ctrl+# reach the legacy switch (callback.c:6469) raw, unlogged, ungated - keybindings.csv proves the -accelerator label is display-only
  - Core owns undo (first-duplicate push_undo, token.c:851) - run_core adds none
  - F-flagarg: the 0/1 token drives both effect and both log forms; only "1" ever crosses the boundary so a fixed literal suffices
- defer triggers:
  - Key migration turns out to need a messageBox-preserving readonly_block shim (doc's named fallback: shrink scope to branch-only, leave keys to 0068 - not a full DEFER)
  - A hidden Tcl caller consuming an interp result from the branch (none known; would force a result-preserving variant)
- rationale: Atom 26, decision doc exists and is effectively PROCEED: asymmetric query/mutate split (mode-1 rename through the boundary gaining the missing readonly gate; mode-0 highlight stays raw-front AND keeps its own log_action - the new logged-query sub-shape), plus routing the '#'/Ctrl+# legacy keys to close the issue-0068 gap and a real read-only-rename bug.
- receipt: receipts/01_check_unique_names.md - shipped as specified (asymmetric split + '#'/Ctrl+# routing), committed 3702df0b, 38-check test green, sabotage x5 verified

### 02 clear_drawing
- tier: T2-clean | fr: 1 | gain: silent | line: scheduler.c:2359
- wrinkles:
  - Destructive with NO undo anywhere (core and branch push nothing) - the logged line is faithful but irreversible on replay; document this as accepted, not a bug
  - if(argc==2) quirk: extra-arg calls are silent no-op TCL_OK today - needs the reset_inst_prop argc-gate so log-on-success cannot phantom-log (the one behavior tighten)
  - F-shared: teardown sub-step of load/undo-restore/reload (in_memory_undo.c:463, save.c:3816/4173, xinit.c:879, font.c:60) - all C-level, stay raw below the boundary
  - New readonly gate could newly reject an internal flow that clears a read-only view - must be checked
- defer triggers:
  - Deep scout finds a Tcl machinery caller (window/tab setup, tests, preview plumbing) issuing `xschem clear_drawing` as a sub-step - logging would record machine teardown lines
  - A read-only-view init/teardown flow that the new gate would break (e.g. descend-readonly or preview contexts)
- rationale: Lowest-friction genuine mutation left: silent free-everything with a single benign F-shared (C-level teardown callers stay raw, zero double-log risk), and the boundary adds a readonly gate that does not exist today - a pure coverage + gating win in the delete/floaters mold.
- receipt: receipts/02_clear_drawing.md - shipped as specified (boundary + argc gate + new readonly gate, no core_log_action arm), committed 20f71c45, 29-check test green, sabotage x4 verified

### 03 redo
- tier: T2-clean | fr: 1 | gain: logged-raw | line: scheduler.c:8800
- wrinkles:
  - Atom-12 verdict was 'skip - no coverage win'; under today's contract it is still zero-gain, purely a consistency/uniformity atom
  - F-shared: pop_undo_keep_selection(1,1) core shared with the undo branch (scheduler.c:11253) which stays raw - no double-log path exists but the guard rows must say so
  - Every entry is the compound `xschem redo; xschem redraw` - verify Tcl_ResetResult on success does not change what the compound observes
  - Log form must stay byte-identical bare `xschem redo`
- defer triggers:
  - Sprint policy rules zero-coverage consistency moves out of scope (then batch it with undo as one housekeeping atom or drop)
  - Any caller found reading a result from the redo branch
- rationale: Already in boundary shape (inline readonly reject + single branch log, no raw second entry, all entries funnel through the verb) - migration is a near-mechanical consistency move like the toggle_ignore key, worth doing early to unify the log onto core_log_action even though coverage gain is zero.
- receipt: receipts/03_redo.md - shipped as specified (zero-delta boundary migration onto core_log_action), committed fa2344e6, 33-check test green, sabotage x4 verified

### 04 get_additional_symbols
- tier: T2-clean | fr: 2 | gain: silent | line: scheduler.c:4172
- wrinkles:
  - No push_undo, no set_modify, no log - the state is appended-then-removed around netlist runs, arguably derived cache, not document content
  - argc==2 is a silent no-op returning TCL_OK - needs argc validation before log-on-success (F-validate tighten)
  - F-flagarg: the 0/1 what token must replay byte-identically; a lone logged 1-line without its paired 0 replays asymmetrically
  - F-shared: spice/spectre/verilog/vhdl/tedax_netlist.c call the core directly in C - stay raw, no risk
- defer triggers:
  - Deep scout concludes the appended symbols are derived netlisting state rebuilt every run - reclass D2 (transient), DEFER as out-of-scope
  - Tcl callers found using the verb as netlist-machinery bracketing (logging would spam machinery lines per netlist run)
- rationale: Name-trap real mutator of xctx->sym (what=1 appends derived polymorphic symbols, what=0 removes them) with only two mild frictions and zero double-log risk (all 5 netlist backends call the C core raw) - but it carries an unresolved SCOPE question: the mutation is transient/derived, not saved bytes, so the deep scout must first decide it belongs on the object-model boundary at all.
- receipt: receipts/04_get_additional_symbols.md - DEFERRED at scout stage (defer trigger #1 confirmed: derived D2 transient netlisting cache, no Tcl callers, destructive standalone replay)

### 05 undo
- tier: T2-clean | fr: 2 | gain: logged-raw | line: scheduler.c:11242
- wrinkles:
  - F-flagarg: the branch logs NORMALIZED atoi'd ints while core_log_action's raw-argv passthrough differs on inputs like "01" - needs a per-verb normalizing log arm or an accepted byte-level log change
  - F-shared: redo branch calls pop_undo_keep_selection(1,1) directly - stays raw, guard rows must cover both sites
  - Zero coverage gain; value is uniformity + guard consolidation
  - Replay of undo/redo lines is stack-state-dependent by nature - already accepted in the log design
- defer triggers:
  - The normalizing log arm is judged shared-machinery scope creep for zero coverage (defer with redo as a paired housekeeping atom)
  - Policy decision excluding consistency-only moves this sprint
- rationale: Branch is explicitly already in boundary shape (!xctx guard, readonly reject, core, inline log, ResetResult); migrating it is the undo-family twin of redo - consistency-only, cheap, and it locks the normalized log form under the guard.
- receipt: receipts/05_undo.md - shipped as specified (normalizing core_log_action arm + argv-parsed run_core arm), committed 96a1c00e, 46-check test green on both binaries, sabotage x5 verified

### 06 wire
- tier: T2-clean | fr: 3 | gain: silent | line: scheduler.c:11541
- wrinkles:
  - undo=branch-pushes: xctx->push_undo() sits in the branch before storeobject - run_core must take ownership (no-double-push reconcile), and maintain_wire_segments runs after with undo already pushed
  - F-split: argc<=5 and 'gui' arms are gesture-START (start_wire / MENUSTART) - must stay raw in front; the current readonly reject at 11547 gates the WHOLE branch incl. arms, so the split must preserve arm gating deliberately
  - F-flagarg: optional pos/prop/sel + 4 coords; prop can contain spaces/braces - needs log_action_argv-style emission, not raw %s
  - Must verify no Tcl helper (wire-stub/label machinery, tests) issues `xschem wire x1 y1 x2 y2` as a machinery sub-step before turning the log on
- defer triggers:
  - Discovery that Tcl machinery or a test harness emits the coord form as an internal sub-step (log spam) - would need a suppress bracket first
  - Discovery that some path already EMITS `xschem wire <coords>` as a replay line (reclass D3, coordinate-form-bypass applies)
- rationale: The best silent coverage win in the pool: the coord form is a real unlogged mutation with the exact wire_cut atom-17 split shape (gesture-START arms stay raw in front), and - unlike the D3 family - the interactive GUI path (start_wire/new_wire) is a completely separate core, so no replay/double-log hazard exists today.
- receipt: receipts/06_wire.md - DEFERRED at scout stage (fr re-rated 99): new_wire already emits the coord replay line at five sites, reversing the item's core rationale; no code changed, atom number unburned

### 07 make_sch_from_sel
- tier: T3-heavy | fr: 3 | gain: logged-raw | line: scheduler.c:6380
- wrinkles:
  - Core (save.c:5362) is void and returns through cancel paths - run_core needs an rc so dialog-Cancel / name==current-sch skip does not log (F-condlog, harder than had_sel)
  - Modal save_file_dialog inside the core: the logged bare line replays by re-popping the dialog - non-deterministic replay unless a resolved-filename (transformed-argv) log form is invented
  - Core self-logs today only on the real edit - migration must strip the core log and keep the Ctrl+H direct-core Layer-A path deduped via actionlog_cmd_logged (F-2ndentry)
  - push_undo conditional on lastsel inside the core (core-owns - run_core adds none)
- defer triggers:
  - rc-plumbing requires touching the dialog flow's cancel semantics beyond a mechanical return-code (scope balloon -> DEFER)
  - Team decides replayable lines must carry the resolved filename - DEFER until a transformed-argv log pattern exists (same blocker as netlist/saveas)
- rationale: Fresh sweep re-flags it CANDIDATE (fr3) but the atom-24 scout D2'd it for the same reason that makes it heavy: the filename comes from a blocking modal save_file_dialog inside a VOID core, so log-on-success needs a real rc plumbed through every cancel path before the boundary can avoid phantom-logging a cancelled dialog.
- receipt: receipts/07_make_sch_from_sel.md - DEFERRED at scout stage (fr re-rated 99): both defer triggers confirmed plus atom-24 D2 dialog-flow-family precedent and zero coverage gain (test-locked self-log-at-core shape); no code changed, atom number unburned

### 08 instance
- tier: T3-heavy | fr: 6 | gain: silent | line: scheduler.c:5151
- wrinkles:
  - F-validate: argc<7 or >9 silently no-ops TCL_OK - needs the argc gate
  - F-condlog: place_symbol can refuse (symbol-view guard, no symbol match) yet the branch still set_modify(1)+TCL_OK - log must gate on actual placement, which needs place_symbol's rc surfaced (and forces a decision on the spurious set_modify)
  - Batch replay: N calls sharing one undo transaction - boundary logging per call is fine, but run_core must not perturb the first_call/to_push_undo dance or replays gain N undo slots
  - F-2ndentry/F-shared: Insert-key start_place_symbol (callback.c:327), `xschem place_symbol` verb (scheduler.c:7741), add_pin_stubs/wire-stub/save.c embed all hit the core raw - stay raw, guard rows needed
  - W3 maintain_wire_segments post-pass (autotrim_wires-gated): inside or outside run_core is a semantics decision
  - F-flagarg: sym path + coords + rot/flip + optional brace-quoted prop + batch arg n must replay byte-identically (apply_pin_prop atom-18 precedent)
- defer triggers:
  - The refusal/set_modify cleanup turns into its own behavior-change bug fix (land that first, then migrate)
  - Tcl machinery callers (create_instance.tcl, library_manager.tcl flows) found issuing `xschem instance` as sub-steps - log spam without a suppress bracket
  - Batch-undo shape cannot be proven invariant under the boundary in a headless test
- rationale: Highest-value silent mutation (scripted symbol placement, currently unlogged) with undo owned by place_symbol - but it carries all five frictions at once, and the batch form's single-undo-transaction shape (first=!atoi(argv[8])) is a per-call-boundary hazard no prior atom has faced.
- receipt: receipts/08_instance.md - DEFERRED at scout stage (fr re-rated 99): D3 reclass (log_placed_instance already emits the replay line for both drops), read-back-vs-raw-argv dedup impossible by design, both plan defer triggers confirmed; no code changed, atom number 30 unburned

### 09 apply_properties
- tier: T3-heavy | fr: 6 | gain: logged-raw | line: scheduler.c:1461
- wrinkles:
  - Boundary's success-path Tcl_ResetResult clobbers the did=0/1/-1 result the form dispatches on ($did==-1 -> 0042 dialog, ==1 -> applied+slickprop::log_apply)
  - Log site today is TCL-side and conditional (did==1); editprop.c:1679 explicitly excludes this path from setprop logging to avoid doubling - the exclusion web must be re-drawn if the log moves
  - Atom-24 scout verdict was D3 (replay vehicle) - the sweep and the scout disagree; deep scout must adjudicate which is current
  - F-shared: apply_symbol_prop is also the legacy vim/text update_symbol core (stays raw); F-flagarg: two Tcl_Merge-quoted prop referents need byte-identical replay
  - No readonly gate today - the boundary would add one (genuine win, and the one reason to keep this on the list)
- defer triggers:
  - Result-preserving perform_action variant (or form rework) required - near-certain: DEFER until that pattern extension is scoped as its own atom
  - apply_properties_logging_decision.md D1 reaffirmed (log stays Tcl-side) - hard DEFER, log site is settled elsewhere
- rationale: Sweep says CANDIDATE but two documented facts point at DEFER: the 0/1/-1 interp result is consumed by property_form.tcl (Tcl_ResetResult-on-success breaks the issue-0042 vanish-dialog and applied/log contract), and apply_properties_logging_decision.md deliberately pins the log at the Tcl layer - migrating the log to C reverses a standing decision. Only attempt after a result-preserving boundary variant exists.
- receipt: receipts/09_apply_properties.md - DEFERRED at scout stage, both defer triggers confirmed (result-preserving variant required + D1 stands) plus phantom-log-on-minus-1 and CIW-dedup blockers.

### 10 fluid_pass
- tier: T4-unlock | fr: 4 | gain: silent | line: scheduler.c:3283
- wrinkles:
  - Same pass fns are called raw by the move_objects END cluster (logged as the move) - core must stay raw there
  - Track-D harness consumes results; passes set_modify(1) but push NO undo (real-gesture undo comes from move_objects outside the pass core)
  - Byte-identical replay needs the unlogged arm line too - logging one without the other is worse than logging neither
- defer triggers:
  - Confirmation it is harness-only (no production entry) - DEFER as zero-gain
  - Arm-state dependency unresolvable without also logging fluid_snapshot (a gesture-state store the rubric excludes)
- rationale: Expected DEFER. Sweep re-flags CANDIDATE but the atom-24 scout D4/D2'd it and both objections stand: it name-routes the fluid_end_passes[] table, and its effect depends on prior unlogged `fluid_snapshot arm` state, so a logged line is not self-contained replay. Plausible unlock: a harness/test-verb exemption class - which by definition yields zero production coverage.
- receipt: receipts/10_fluid_pass.md - DEFERRED at scout stage, both defer triggers confirmed (harness-only zero-gain + arm-state unresolvable) plus D4 name-routing and load-bearing changed-count Tcl result.

### 11 setprop
- tier: T4-unlock | fr: 99 | gain: logged-raw | line: scheduler.c:10116
- wrinkles:
  - The in-code invariant (10617-10622) FORBIDS logging the shape `allprops` arms - they are editprop.c's replay form (coordinate-form-bypass)
  - -fast is unlogged backannotation machinery; -fastundo/plain push undo per-arm - the log gate and the undo gate are keyed on the same flag but are different decisions
  - One all-subtype readonly reject at 10120 - a subtype split must not change gating for the arms that stay raw
  - Existing narrow self-log at 10623 (instance AND fast!=1) is exactly the condlog the boundary would need to reproduce
- defer triggers:
  - F-condlog flag-gated logging is not yet a boundary pattern - DEFER until that extension is its own atom
  - Any risk to the editprop replay-receiver invariant found during the split - hard stop
  - hspice_backannotate batch flows found routing through the instance subtype with -fast semantics that the gate mis-classifies
- rationale: Expected DEFER as a whole verb (D3/D4 per atom-24), but the sweep's per-subtype split is the most plausible unlock in the pool: route `setprop instance` alone through an F-condlog-capable boundary (log only when fast!=1), leaving shape/graph arms as raw unlogged replay receivers. Friction-test this split shape even though full migration is off the table.
- receipt: receipts/11_setprop.md - DEFERRED at scout stage; instance arm already logged at the boundary-equivalent gate, split would re-draw a guard-locked invariant web via a new mutating-raw-front pattern for zero coverage gain.

### 12 cut
- tier: T4-unlock | fr: 99 | gain: logged-raw | line: scheduler.c:2568
- wrinkles:
  - delete(1) is safe to call raw today ONLY because delete's core_log_action lives at the boundary, not in the core - a routed cut must preserve that arrangement or the migrated atom-24 guard rows break
  - Ctrl-X inline key (callback.c:6055) self-logs `xschem cut` and never reaches the branch - stays raw, no double-log, but must be asserted
  - Branch pushes undo via delete's to_push_undo=1 (branch-pushes by proxy)
- defer triggers:
  - Composite/inner-suppress boundary class not yet designed (it is not) - DEFER
  - Any coupling that would force touching the landed delete atom's tests/guards
- rationale: Expected DEFER - the atom-24 doc's sharpest lesson (section 4.4): lowest raw friction, still D4, because it is two other verbs' cores (save_selection(2) + the migrated delete's delete(1)) wearing one name. Unlock: a composite boundary class that wraps inner cores in an actionlog_suppress scope; friction-testing it defines what that class must guarantee.
- receipt: receipts/12_cut.md - DEFERRED at scout stage; both defer triggers confirmed (D4 no-own-core, three-site dedup web incl. a plan-omitted ctx-menu pick 7, atom-24 guards premise the raw arrangement), unlock spec for the composite/inner-suppress class recorded.

### 13 copy
- tier: T4-unlock | fr: 99 | gain: logged-raw | line: scheduler.c:2422
- wrinkles:
  - Empty-selection still logs (0061/0062 documented behavior) - the boundary must preserve no-op-still-logs here, which it does natively
  - save_selection(2) is the same shared primitive that makes cut fail 1:1
  - Two raw entry points log independently - dedup web spans three sites
- defer triggers:
  - Clipboard boundary class undesigned - DEFER
  - Entry-dedup across three log sites judged more fragile than the current arrangement
- rationale: Expected DEFER - explicit D4 clipboard family. Unlock: a clipboard/disk-side-effect boundary class plus actionlog_cmd_logged entry-dedup across the direct save_selection() sites (raw Ctrl-C key, ctx-menu pick 15) which log at their own sites today.
- receipt: receipts/13_copy.md - DEFERRED at scout stage; both defer triggers confirmed and a copy-specific new requirement found (readonly-EXEMPT boundary variant - copy is deliberately read-only-legal at all three entry sites while perform_action gates unconditionally), coverage already complete so migration gains nothing.

### 14 descend
- tier: T4-unlock | fr: 99 | gain: none | line: scheduler.c:2656
- wrinkles:
  - Boundary log would double-log against the core's absorb line; stripping the core log breaks the select_at absorption design (action_log_absorb spec)
  - Load-shaped: swaps current schematic, descend-autosave machinery, semaphore-guarded, returns ret via Tcl_SetResult (result consumed)
- defer triggers:
  - Self-logging-core exemption not yet a boundary pattern - DEFER until scoped as its own extension atom
  - Any interference with descend-autosave or the -inst absorb replay
- rationale: Expected DEFER - D4 navigation composite whose core SELF-LOGS its outcome (log_action_descend, actions.c:3591) including the select_at stash-absorb machinery. Unlock: a self-logging-core exemption (boundary variant that trusts the core's outcome log and logs nothing itself) - the single pattern that would also admit descend_symbol and go_back, making it the highest-leverage T4 friction test.
- receipt: receipts/14_descend.md - DEFERRED at scout stage; both defer triggers confirmed, exemption spec written for a future pattern-extension atom.

### 15 descend_symbol
- tier: T4-unlock | fr: 99 | gain: none | line: scheduler.c:2703
- wrinkles:
  - Embedded-symbol save handling inside the core adds a save-shaped leg descend lacks
  - Semaphore-guarded; -inst resolve+select preamble mirrors descend
- defer triggers:
  - Rank-14 pattern deferred -> automatic DEFER
  - Embedded-symbol save leg found to need its own gating
- rationale: Expected DEFER - same shape as descend (self-logging core at save.c:5678, load-shaped view swap with embedded-symbol save handling); rides or falls with the self-logging-core exemption pattern tested via rank 14.
- receipt: receipts/15_descend_symbol.md - DEFERRED at scout stage; rank-14 automatic defer trigger confirmed, plus a readonly-exempt requirement (read-only symbol browsing) on top of self-log-exempt.

### 16 go_back
- tier: T4-unlock | fr: 99 | gain: none | line: scheduler.c:4654
- wrinkles:
  - ask_save dialog with Cancel = early no-op return (must not log) - nondeterministic replay
  - Branch gates on xctx->semaphore==0 as a silent no-op
  - Core self-log (issue 0071 atom 3) is the single site covering three raw C entries
- defer triggers:
  - Self-logging-core exemption deferred -> DEFER
  - Dialog nondeterminism means the line can never be a faithful replay without a resolved-outcome log form
- rationale: Expected DEFER - save/load composite whose core self-logs at its TAIL precisely because Ctrl-E/BackSpace/ctx-menu call go_back() directly in C, bypassing the branch; migrating strips coverage from those raw entries or double-logs. Unlock: the same self-logging-core exemption, plus dialog-Cancel/semaphore no-op-means-no-log handling.
- receipt: receipts/16_go_back.md - deferred at scout stage on the descend-family automatic trigger; core tail self-log (actions.c:3747-3748) is outcome-gated past the ask_save dialog and covers three raw C entries no boundary log can.

### 17 netlist
- tier: T4-unlock | fr: 99 | gain: logged-raw | line: scheduler.c:7012
- wrinkles:
  - Shared cores (global_*_netlist) also reached by Shift-N key and CLI -n batch - must stay silent
  - -keep_symbols machinery passes stay silent by design; dropping -messages/-noalert from the logged line is a bespoke transform
  - Tcl_ResetResult would clobber the err/messages result
- defer triggers:
  - Either transformed-argv logging or result preservation missing from the boundary (both are) - DEFER
  - Netlist-dir/show_infowindow tcl-var juggling found order-sensitive under a boundary wrapper
- rationale: Expected DEFER - it already implements, in-branch, exactly what the boundary would need to grow: transformed-argv conditional logging (resolved argv, gated on done_netlist && !keep_symbols) plus a result (err/messages) the caller consumes. Unlock: transformed-argv + result-preserving boundary support - two extensions at once.
- receipt: receipts/17_netlist.md - deferred at scout stage; branch (scheduler.c:7147) self-logs a transformed argv gated on done_netlist && !keep_symbols with a consumed result, and is readonly-legal with no readonly gate — three nonexistent boundary extensions needed at once.

### 18 save
- tier: T4-unlock | fr: 99 | gain: logged-raw | line: scheduler.c:9115
- wrinkles:
  - fast arm must stay silent (machinery gate)
  - Unnamed arm routes to saveas(NULL,...) - fails 1:1 outright
  - Ctrl-S saves inline in callback.c with its own log site (raw second entry)
- defer triggers:
  - File-op boundary family undesigned - DEFER
  - Composite entries (go_back/descend/close) cannot be discriminated at the save() core
- rationale: Expected DEFER - file-lifecycle family. The log deliberately lives at the BRANCH because save(0,fast) is a shared confirm-wrapper also entered from go_back/descend/window-close composites; a boundary log-on-success at the verb would phantom-log inside those composites. Unlock: a file-op boundary family with arm-splitting (unnamed->saveas) and shared-core entry dedup.
- receipt: receipts/18_save.md - DEFERRED at scout stage; both defer triggers confirmed (disk-side-effect family with no undo semantics; composite entries from load-prompt/descend/Ctrl-S indiscriminable at the core) plus unnamed-arm saveas routing needing the nonexistent self-log-exempt pattern - branch log already boundary-equivalent, zero coverage gain.

### 19 saveas
- tier: T4-unlock | fr: 99 | gain: logged-raw | line: scheduler.c:9160
- wrinkles:
  - Branch re-derives xctx->readonly from the new file after return - ordering matters under a wrapper
  - Dialog arm's filename is not in argv - only a resolved-path log is meaningful
- defer triggers:
  - Transformed-argv logging missing (it is) - DEFER
  - Replay-form status of the explicit-path line (coordinate-form-bypass analog) reaffirmed
- rationale: Expected DEFER - the core self-logs the RESOLVED path (actions.c:679) for the dialog arm, and the explicit-path line is itself the replay form; boundary raw-argv logging would both double the resolved self-log and re-log every replayed `saveas {path}`. Unlock: dialog-arm/path-arm split + resolved-argv (transformed) logging.
- receipt: receipts/19_saveas.md - DEFERRED at scout stage; both defer triggers confirmed plus readonly-escape-hatch gate conflict, phantom-log-on-Cancel, and load-bearing core self-log covering the callback.c raw Ctrl-S entry - would need three nonexistent boundary patterns at once (MUTATE/MUTATE arm split, transformed-argv, readonly-exempt gate).

### 20 reload
- tier: T4-unlock | fr: 99 | gain: logged-raw | line: scheduler.c:8879
- wrinkles:
  - load_schematic is not a 1:1 verb core
  - zoom_full flag variant in the log line (F-flagarg-like)
- defer triggers:
  - Load-family boundary undesigned - DEFER
  - Alt-S inline path cannot share a dedup key with the branch
- rationale: Expected DEFER - load composite (unselect_all + remove_symbols + load_schematic) with a branch self-log; Alt-S reloads inline in callback.c with its OWN log site (a raw second entry). Unlock: the load-family boundary shape plus 2nd-entry dedup; until then routing double-logs against the branch self-log.
- receipt: receipts/20_reload.md - DEFERRED at scout stage; both defer triggers confirmed (branch IS the composite, no core exists; Alt-S callback.c:5789 inline path has no C-side dedup channel), zero coverage gain over the existing boundary self-log, and the mandatory readonly gate would break the documented read-only reload mechanism.

### 21 print_hilight_net
- tier: T4-unlock | fr: 99 | gain: logged-raw | line: scheduler.c:8159
- wrinkles:
  - Inner routed merge would double-log under an outer boundary log without a suppress scope
  - Modes 1/3 are read-only viewers the all-or-nothing gate would over-reject (F-split analog)
  - Undo comes from merge_file's push (core-owns by proxy, in a different verb's core)
- defer triggers:
  - Suppress-scope composite pattern undesigned - DEFER
  - Pending-gesture TCL_OK is not a committed edit (log-the-effect rule violated by construction)
- rationale: Expected DEFER - composite that tcleval-routes an inner `xschem merge` (which arms a pending STARTMERGE gesture logged later at drop), self-logs raw with 0061 dedup, and mixes viewer-dialog modes 1/3 with mutating modes 0/2/4 under NO readonly gate. Unlock: composite-aware actionlog_suppress scoping + a mode split for the readonly gate - a good stress test for the suppress-scope pattern.
- receipt: receipts/21_print_hilight_net.md - DEFERRED at scout stage; both defer triggers confirmed (inner tcleval-routed merge re-enters the scheduler and only arms a pending STARTMERGE gesture, so no truthful boundary effect-log exists), zero coverage gain over the existing 0061-deduped branch self-log, and raw family-chord entries (callback.c:5309/5317) belong to issue 0068.

### 22 make_symbol
- tier: T4-unlock | fr: 99 | gain: logged-raw | line: scheduler.c:6395
- wrinkles:
  - Core self-logs unconditionally and also covers the raw 'a' key (callback.c:4972) - core-log removal + dedup needed for zero net gain
  - tk_messageBox okcancel gate -> Cancel must not log
  - The conditional save_schematic is the save verb's core embedded in another verb (composite)
- defer triggers:
  - Partial-readonly gating not expressible in the one-gate contract (it is not) - DEFER
  - The 0041 sibling hole gets fixed independently, removing half the motivation
- rationale: Expected DEFER - composite (confirm messageBox + conditional save_schematic leg + .sym generation) that is DELIBERATELY allowed on read-only cells, so the boundary's all-or-nothing gate would wrongly refuse it. Unlock: a partial-readonly boundary form (allow verb, skip only the save leg) - worth friction-testing because the 0041-sibling hole (readonly silently skips the save) is a live bug either way.
- receipt: receipts/22_make_symbol.md - DEFERRED at scout stage; defer trigger 1 confirmed (inline allow-verb/skip-save-leg readonly form beyond the one-gate contract), the 0041-sibling hole already mitigated in-source, and zero net coverage gain over the save.c:3336 core self-log that also covers the raw 'a' key.

### 23 make_sch
- tier: T4-unlock | fr: 99 | gain: logged-raw | line: scheduler.c:6370
- wrinkles:
  - ask_save overwrite-confirm mid-core with many early no-log returns (conditional log by construction)
  - Core self-log shared with callback.c:5353 - migration needs core-log removal + 2nd-entry dedup for zero gain
  - Deliberately NO readonly gate (writes a different file) - boundary gate would be wrong
- defer triggers:
  - Disk-artifact class undesigned and zero coverage gain - near-automatic DEFER
  - Any coupling with the symbol-view-create flow
- rationale: Expected DEFER - writes a NEW sibling .sch file; the in-memory object model is untouched, so under the current scope it is D2. Unlock: an admit-disk-artifact-generators logging class (no undo, no set_modify, deliberately no readonly gate); net coverage gain is zero since the core already self-logs and covers the raw Ctrl+L key.
- receipt: receipts/23_make_sch.md - DEFERRED at scout stage; defer trigger 1 confirmed (D2 disk-artifact class, no undo/set_modify), zero net coverage gain over the save.c:5509 core self-log that also covers the raw Ctrl+L key, ask_save phantom-log blocker, and no-readonly-gate-by-design incompatible with the one-gate contract.

### 24 text
- tier: T4-unlock | fr: 99 | gain: none | line: scheduler.c:11039
- wrinkles:
  - Branch pushes NO undo (interactive twin place_text pushes) - an admitted coordinate form needs an undo-push decision
  - Atom-24 rubric D1 note: text was separately disqualified as a shared sub-step of create_graph/place_sym_pins
  - Branch already carries its own readonly reject
- defer triggers:
  - Any replay path found NOT suppress-armed (one exists -> whole-family hard stop)
  - Byte-for-byte dedup between two emitters judged too fragile to guard
- rationale: Expected DEFER - the canonical coordinate-store replay primitive: the PLACE_TEXT drop funnel (callback.c:1741) emits this exact argv form, so boundary logging re-logs every replay. Unlock: prove all replays run under actionlog_suppress (the boundary already checks it) AND make the drop-funnel line dedup byte-for-byte against core_log_action - the pattern that, if it holds, retires the whole D3 family.
- receipt: receipts/24_text.md - DEFERRED at scout stage: both defer triggers confirmed (unwrapped source/machinery re-log paths + byte-dedup impossible against the read-back PLACE_TEXT funnel); viable replacement is an event-disjointness multi-file pattern, not a single-verb atom; no code changed, atom number unburned

### 25 rect
- tier: T4-unlock | fr: 99 | gain: silent | line: scheduler.c:8751
- wrinkles:
  - NO push_undo in branch or storeobject - admitted form must add one (behavior change to scope explicitly)
  - gui/bare arms are MENUSTART gesture starters that stay raw (F-split shape)
  - Inline scheduler_readonly_reject already present
- defer triggers:
  - Replay-suppress pattern (rank 24) deferred -> DEFER
  - create_graph.tcl or other machinery found emitting `xschem rect` sub-steps (log spam)
- rationale: Expected DEFER - D3 coordinate form, but notable within the family because it is SILENT today (no gesture log emits it) and has a genuine undo hole (no push_undo anywhere in the coord path). If the rank-24 replay-suppress story lands, rect is the family's cheapest beneficiary; the undo hole deserves a standalone bug fix regardless of migration.
- receipt: receipts/25_rect.md - DEFERRED at scout stage: both defer triggers fired (rank-24 pattern deferred; create_graph.tcl:36 + place_sym_pins.tcl:38 emit coord-form sub-steps) and the plan's 'silent' claim is false (actions.c:4584 logs the coord form); undo hole flagged as standalone 0125/0121-class bug; no code changed, atom number unburned

### 26 arc
- tier: T4-unlock | fr: 99 | gain: none | line: scheduler.c:1943
- wrinkles:
  - Scripted branch does store_arc + set_modify with NO push_undo (undo hole vs interactive path)
  - Branch sets a "1"/"0" validation result consumed by callers - Tcl_ResetResult clobbers it
  - MENUSTART bare form stays raw
- defer triggers:
  - Log-site relocation pattern undesigned - DEFER
  - Result-preservation requirement (same blocker as apply_properties)
- rationale: Expected DEFER - the scripted x/y/r form is the EXACT line the interactive 3-click commit logs (new_arc, actions.c:4453), so routing double-logs interactively and re-logs replays. Unlock: relocate new_arc's commit log into the boundary AND add the missing scripted-path push_undo; the log-site-move is a pattern no atom has attempted.
- receipt: receipts/26_arc.md - DEFERRED at scout stage: D3 confirmed and rank-24 defer fired; result-preservation trigger re-verified but weakened (no consumer found); undo hole already on issue 0127's verify list; no code changed, atom number unburned

### 27 add_wire_label
- tier: T4-unlock | fr: 99 | gain: none | line: scheduler.c:1682
- wrinkles:
  - wire_label_try_commit (callback.c:1816) calls end_move_copy_logged(0) - the drop is ALREADY logged there
  - 1/0 result consumed as the commit witness - Tcl_ResetResult breaks the 36/36 GUI rail contract
  - bare/-place arms are opener/gesture-arm and stay raw
- defer triggers:
  - Log-site-move pattern undesigned (shared blocker with arc) - DEFER
  - Any change risking the 0122 E1 drop-witness tests
- rationale: Expected DEFER - only the -drop form is admissible, and only by relocating end_move_copy_logged's drop log into the boundary (else every commit double-logs); the 1/0 interp result is the committed/refused witness that 0122's GUI tests and the form depend on.
- receipt: receipts/27_add_wire_label.md - DEFERRED at scout stage, both defer triggers confirmed (log-site-move undesigned + 0122 drop-witness/result contract).

### 28 net_label
- tier: T4-unlock | fr: 99 | gain: silent | line: scheduler.c:6965
- wrinkles:
  - Undo core-owns (place_symbol to_push_undo=1) - clean on that axis
  - Three raw keyboard entries bypass the scheduler entirely
  - Committed edit is the drop, logged (if at all) by the gesture funnel, not this verb
- defer triggers:
  - Effective-coordinate drop logging for placements not yet built - DEFER
  - Key-bypass dedup requires touching three legacy handlers for marginal gain
- rationale: Expected DEFER - gesture-arm at live cursor (place_symbol at mousex/y_snap then move_objects START), so replaying the arm depends on mouse position. Unlock: effective-coordinate capture at the DROP (the feb3071e pivot-verb pattern) plus dedup for the three callback.c direct-key bypasses (Alt+Shift+L / Ctrl+P / Ctrl+Shift+P).
- receipt: receipts/28_net_label.md - DEFERRED at scout stage; both defer triggers confirmed and trigger 1 sharpened (drop logging is unnecessary, not unbuilt - the funnel's log_placed_instance already emits an effective-coordinate `xschem instance` line).

### 29 edit_vi_prop
- tier: T4-unlock | fr: 99 | gain: none | line: scheduler.c:2867
- wrinkles:
  - edit_property(1) blocks on the external editor and applies with push_undo inside (core-owns, but value unrecoverable from argv)
  - No log_action today anywhere on this path - a real coverage hole, but unfixable without the new form
- defer triggers:
  - New-verb design out of Refactor B scope (it is migration-only) - DEFER to a feature issue
  - setprop-family coverage judged sufficient for the same edits
- rationale: Expected DEFER - the mutation value comes from an external editor session, so the existing form can never be 1:1 replayable. Unlock: design a value-carrying non-interactive sibling (property text as argv) that the boundary logs, leaving the editor form as its interactive front - a new-verb design task, not a migration.
- receipt: receipts/29_edit_vi_prop.md - DEFERRED at scout stage; the plan's coverage-hole wrinkle is false (core self-logs the edit as setprop/set lines via log_prop_edit_replayable, 0063 atom 10), so this is a self-logging-core defer and the proposed sibling-verb unlock is largely moot.

### 30 line
- tier: T4-unlock | fr: 99 | gain: none | line: scheduler.c:5621
- wrinkles:
  - No push_undo in the coord branch (undo lives in the interactive gesture) - same undo-hole decision as rect
  - bare/'gui' arms arm MENUSTART and stay raw
  - Multiple emit sites in actions.c:4506-4543 would all need byte-for-byte dedup
- defer triggers:
  - Rank-24 pattern deferred -> DEFER
  - Any un-suppressed replay path found (family-wide hard stop)
- rationale: Expected DEFER - same D3 family as text/rect/arc: new_line's gesture end emits the `xschem line x1 y1 x2 y2` replay lines and pushes the undo, while the coord branch pushes none; rides entirely on the rank-24 replay-suppress + dedup story.
- receipt: receipts/30_line.md - DEFERRED at scout stage; both defer triggers fired and the 0127 undo-hole sibling was confirmed with exact cites (storeobject scheduler.c:5774 + set_modify scheduler.c:5780, no push_undo, vs interactive push at actions.c:4499).
