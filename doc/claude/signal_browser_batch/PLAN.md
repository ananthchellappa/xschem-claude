# Signal Browser batch plan — ViVA-style signal browsing for the ASE waveform viewer

Generated 2026-08-03. Source of truth for the batch. Driver: `DRIVER_PROMPT.md` in this
directory. Per-item workflow: `item_pipeline.js`. Receipts: `receipts/NN_receipt.md`.

The batch shape is the one proven by `doc/claude/refactor_b_batch/` (see its `RUNBOOK.md`
for the rationale — fresh context per stage, state on disk, defer-as-success).

Research basis: `references/viva_cadence_waveform_viewer.md` §3 (Results Browser,
Search toolbar, wildcard semantics) and §13 item 1, with the corrections in
`references/viva_briefing_critique.md`. Read §3 before scouting any item — several
ViVA behaviours below are deliberate divergences and the reason is only recorded there.

---

## Status legend

- `[ ]` pending
- `[S]` scouted, verdict pending
- `[x]` DONE — implemented + adversarially verified + committed
- `[E]` DONE but **eyeball pending** — deliverable is pixels, no test can see it
- `[D]` DEFERRED — friction verdict, reason appended to the line
- `[F]` FAILED — needs a human, reason appended to the line

**An item whose deliverable is visible UI may NOT be verdicted `[x]`.** It gets `[E]`
and lands in the eyeball queue at the bottom of this file. Items marked **PIXEL** in
their heading are `[E]`-only. (Lesson: `pixel-deliverables-need-eyeball` — 2 defects
shipped past 28 green checks.)

---

## Rules of the batch

- **Strictly sequential.** Items 0→16 in order. Every item after 4 edits
  `src/wave_viewer.tcl`; parallel items would conflict. Parallelism lives *inside*
  pipeline stages, never across items.
- **One commit per green item.** Explicit file lists only — never `git add -A`,
  `git commit -a`, `git reset --hard`, never `git push`. Commit message ends with the
  item line. Order is **build → suites green → commit → raise review gate**
  (`review-commit-dont-push`).
- **Sabotage-verify every item.** Each item below names its sabotages. Every named
  sabotage must fail EXACTLY its target check, and the clean re-run must be green. No
  exceptions — a green suite is not evidence the changed code ran (`green-but-hollow`).
  ⚠ **REVERT FROM A BYTE-EXACT BACKUP OF THE ITEM STATE, NOT `git checkout -- <file>`,
  WHILE THE ITEM IS UNCOMMITTED.** A checkout reverts to the PREVIOUS COMMIT, which
  deletes the item along with the sabotage. This has now bitten items 2, 3 and 6 — in
  item 6 it actually happened, reverting `wave_viewer.tcl` to `3c7c993f` mid-round.
  Confirm each injection with `diff` before running and each restore with `diff` +
  checksum after. `git checkout --` is only safe AFTER the item's own commit lands.
- ⚠ **A CHECK THAT CAN THROW INSTEAD OF FAILING IS NOT A CHECK.** Item 6 found this the
  hard way: a bare `$w.err cget -text` threw into the outer catch when a sabotage
  destroyed the dialog, silently aborting five later checks — while the fail COUNT still
  coincidentally matched the prediction, so it would have shipped looking correct. Make
  "the thing I am reading vanished" an **assertable value**, never an exception. The same
  rule as item 5's `at_wait_mapped`: a timeout or an absence must PRINT as itself and must
  never be able to forge the value under test.
- **Adversarial verify is a DIFFERENT agent from the implementer.** It re-runs the
  item test, the full headless suite, and diffs the commit scope itself. One repair
  attempt, then `[F]` and move on.
- **Baseline fails** are recorded by the driver at preflight in the header block below.
  Every verifier compares against that exact list. Any new fail is the current item's
  problem, full stop.
- **GUI gate.** Any stage that runs the headless suite under a real `$DISPLAY` must go
  through `tests/headless/run_suites.sh` or `gated_xschem.sh` — never a bare
  `for i in ...; do ./src/xschem --script t.tcl; done`, which enrols in no gate and
  shows up in the panel as `UNGATED` (`gui-test-gate`). Press **Allow 2h** once before
  launching the batch.
- ⏱⏱ **USER AUTHORIZATION 2026-08-05 21:55 MST — EXPIRES 2026-08-06 05:55:48 MST
  (epoch 1786020948). CHECK THE CLOCK (`date +%s`) BEFORE EVERY SUITE RUN.**
  The user explicitly authorised running GUI tests **at will for eight hours, and to
  IGNORE THE USER SETTING ON THE GUI-TEST-GATE WIDGET.** That is broader than the earlier
  6-hour grant: it waives **Pause as well**. Recorded two ways —
  `allow_until` = 1786020948 and `control` = `RUN` (so an in-flight suite proceeds without
  a click), and agents in this window are **cleared to `export GUI_GATE=0`** and to ignore
  a `PAUSE` they find, rather than waiting on it.
  **Consequence the user accepted:** the gate exists to stop suites flooding the display
  and making the machine unusable. For these eight hours that protection is off by their
  instruction. Still never `make` while suites run — that one is about measurement
  quality, not the display, and no authorization touches it.
  **This authorization is TIME-BOXED and does not renew.** After the epoch above the
  normal rule returns IN FULL: wait out a Pause, never set `GUI_GATE=0`, never hand-write
  the control files. An agent reading this after expiry must treat it as VOID — a lapsed
  approval is not an approval. The previous 6-hour grant expired at 06:01 MST on 08-05 and
  was correctly treated as void by items 8-11; do the same with this one.
- **Never `make` while suites run** (`headless-suite-flakes-under-cpu-load`).
- **Known-flaky, NOT regressions:** the authoritative list is the **FLAKY** section of
  the Baseline block below (9 names, measured 2026-08-04) — a verifier seeing one of
  those must re-run it before calling a fail. The older lore still holds as mechanism:
  bare `event generate` key delivery drops ~1-in-5, `test_ase_plot` P4/P6/P8 flap 1-2/10,
  and the WSLg Xwayland abort (`wslg-xwayland-aborts`) kills every client mid-suite —
  it fired 3× during re-baseline run 1 and manufactured all 9 flaky names at once. **A
  run whose log contains `X connection to :0 broken` is not a measurement; re-run it.**
  ⚠ **REVERSED 2026-08-05 by item 5:** `test_wave_trace_menu` IS FLAKY after all and is
  back on the FLAKY list. The re-baseline de-listed it on the strength of 2 passing runs;
  item 5 ran the controlled A/B that de-listing never had — 6 solo runs with item 5 in
  (2 pass / 4 fail) and 6 with `src/wave_viewer.tcl` reverted (3 pass / 3 fail), same fail
  shapes, **identical rate with the item absent**. 12 measurements beat 2. The lesson is
  the re-baseline's own: two runs separate hard fails from flakes, but they cannot rate a
  ~50% flake, and a name that passes both is not thereby proved stable.
- **Ambiguity never escalates to the user mid-batch.** It becomes a `[D]` with reasons,
  reviewed at the final report.
- **Stop conditions:** two consecutive `[F]`; broken build; any non-baseline audit fail
  that survives one repair; item 0 verdicting `[F]`.

### Baseline (driver fills at preflight)

```
Date: 2026-08-04   (RE-BASELINE. This block REPLACES the 2026-08-03 one in place; the
                    superseded text survives in git history.)
HEAD at measurement: 6a3f8e42a13d951168348567f3efe08657c5ff41
  "feat(wviewer): signal_list, typed raw inventory"
  NOT ccd5f30a -- 3098afa0, a6913ab2, bc1efec9 and 6a3f8e42 landed since the old
  baseline was taken, so the two lists are not measurements of the same tree.
Method: tests/headless/full_audit.sh, run TWICE, solo, sequentially, nothing else on
  the box, under a live GUI-gate approval window (no prompt, control=RUN). Default
  AUDIT_TIMEOUT=120. Both audits exited 1 -- expected, failures present.
  Logs:    doc/claude/signal_browser_batch/baseline_2026-08-04_run1.log
           doc/claude/signal_browser_batch/baseline_2026-08-04_run2.log
  Receipt: doc/claude/signal_browser_batch/receipts/baseline_2026-08-04.md

run 1: SUMMARY: 250 pass  24 fail  1 crash/timeout  8 skip  (total 283)
run 2: SUMMARY: 266 pass  16 fail  0 crash/timeout  1 skip  (total 283)
Both runs: WIREEDIT: PASS   SCRATCH: 0 leaked dir(s)

RUN 2 IS THE CLEAN MEASUREMENT. The X server died three times during run 1
(`grep -c 'X connection to :0 broken'` = 3 in run1, 0 in run2) -- the documented WSLg
Xwayland abort (memory: wslg-xwayland-aborts), an environment failure, not code. The
two runs did NOT disagree wildly: run 2's fail set is a strict SUBSET of run 1's.
16 names failed BOTH, 9 failed run 1 ONLY, 0 failed run 2 only. Run 1 additionally
self-SKIPped 8 tests on "no X"; every one of those 8 PASSED in run 2.
(Suite size grew 282 -> 283 since 2026-08-03; that is one added test, not a lost one.)

HARD baseline fails (failed BOTH runs) -- 16 names. THIS is the list every verifier
from item 3 on compares against:
test_ase_log_seam_0207
test_ase_window
test_cadence_drag
test_ciw
test_fluid_editing
test_gf180mcud_libmgr
test_ihp_sg13g2_libmgr
test_lib_manager_gui
test_lib_manager_locate
test_lib_sweep
test_phase3_mints
test_reopen_readonly
test_rotate_stretch_short_0104
test_select_at
test_selflog_output
test_sky130a_libmgr

Anchor check per HARD name (from clean run 2), so a verifier can tell at a glance
whether its own change is implicated -- if the name fails on a DIFFERENT check, that
is not this baseline entry and must be treated as new:
  test_ase_log_seam_0207        16 of 26; first is PS0 "action log open (needs
                                --logdir)" -> {0}. Byte-identical block in both runs.
  test_ase_window               1 of 166; W7 "simulator produced output before Stop"
  test_cadence_drag             RE-ANCHORED 2026-08-04 by item 3 (its P3). The
                                re-baseline recorded "12; first is 'plain click selects
                                instance 0'" -- that check now PASSES, and the test
                                instead fails TWO others: Ctrl+drag and non-cadence
                                plain drag, both "leaves wires behind". Isolation-proved
                                pre-existing against 6a3f8e42. This name's fail COUNT
                                AND fail SET both flap; treat ANY test_cadence_drag
                                failure as baseline unless you can isolation-prove
                                otherwise, and do NOT read the 12-vs-2 difference as a
                                regression.
  test_ciw                      "no result/error text in file"  (run 1 failed a
                                SECOND check, "ciw_create re-shows"; only the first
                                is stable -- this test's fail COUNT flaps, 2 vs 1)
  test_fluid_editing            1 of 26; FE8 "drag-and-return changed the arc AND
                                left buffer MODIFIED (no false-clean) (mod=1 a=30)"
  test_gf180mcud_libmgr         1 of 29; "library_list = exactly the 8 intended libs"
  test_ihp_sg13g2_libmgr        1 of 66; "library_list = exactly the 9 intended libs"
  test_lib_manager_gui          2; GUI8 + GUI9 (tab-per-open / tab reuse)
  test_lib_manager_locate       1 of 3; LM-LOC3 (cell/view selection not cleared)
  test_lib_sweep                5; P1, P1b, P2 "library.defs registers all 12
                                (=> 0/12)", P3, P4
  test_phase3_mints             2; "key g logs 'xschem snap half'" + "key G logs
                                'xschem snap double'"
  test_reopen_readonly          1; R10 "-lastopened resolved to the prior file (fa)"
  test_rotate_stretch_short_0104 1 of 76; "rot180-ip (-30,70): no NEW dangling
                                endpoints"
  test_select_at                5; "action log open", SA5, SA6b, SA7b, SA8b
  test_selflog_output           6; key Shift-F / Alt-F / Shift-R / Alt-R / Shift-V /
                                Alt-V logging
  test_sky130a_libmgr           1 of 18; "library_list = exactly the 12 intended libs"

Two clusters inside those 16, so nobody chases 16 independent defects:
 (a) ACTION-LOG / SELF-LOG -- test_ase_log_seam_0207, test_select_at,
     test_selflog_output, test_phase3_mints and test_ciw all fail on "action log
     open" / "logs <cmd>" shaped checks. Probably ONE defect, not five.
 (b) THE THREE PDK LIBMGR TESTS -- each fails exactly one check, "library_list =
     exactly the N intended libs", each actual list carrying extra libs {SANDBOX
     TEST ...}. CAUSE CORRECTED AGAINST THE LOGS AND THE TREE: those two extras come
     from the USER-LEVEL registry /home/qflow/.xschem/library.defs (lines "DEFINE
     SANDBOX SANDBOX" / "DEFINE TEST TEST"), NOT from the untracked scratch dirs in
     `git status` -- the in-tree xschem_libs_newsym/ and xschem_libraries_oa/
     library.defs are tracked, unmodified, and already DEFINE SANDBOX. Deleting the
     untracked dirs would not change library_list. test_ihp_sg13g2_libmgr also has a
     THIRD extra, sg13g2_tests_ase, registered in the tracked
     ihp-sg13g2/xschem_libs/library.defs:13 and simply missing from that test's
     expectation (sky130A's sibling expectation does list its _tests_ase lib).
     These three tell a verifier nothing about its own change.

FLAKY (failed exactly ONE of the two runs) -- 9 names. A verifier seeing one of these
MUST re-run it before calling a fail. All nine failed run 1 only, and run 1 is the
X-death run:
  test_ase_persist               NO failing check at all -- last line is
                                 "ok: G10 redraw rc 0", then "X connection to :0
                                 broken". Killed mid-test. Pure environment casualty.
  test_descend_readonly          ZERO checks ran -- output ends at "Sourcing
                                 .../xschemrc init file" then the X death.
  test_graph_box_zoom_xy         TIMEOUT, "the monitored command dumped core".
  test_gesture_end_log           1 check: "instance moved by exactly the logged delta"
  test_nh_anim_rearm             4: R1 (animated=1 after=), R2 (ticks=0), R4 (after=),
                                 R6 (ticks=0) -- empty `after` id / zero ticks, i.e.
                                 the Tk event loop was not turning.
  test_palette                   1 line: "EVENT opens palette: NO". The 151-result
                                 query itself worked, so only the synthetic key event
                                 failed -- key delivery.
  test_pristine_untitled_viewer_0172  1 of 41: "W-win fixture: a second window/tab
                                 exists to swap with (other=.drw main=.drw)" -- the
                                 second window never mapped.
  test_remap                     3: "default Shift+Z zooms in (z0=1 z1=1)",
                                 "remapped Shift+Z zooms OUT (z1=1 z2=1)", "restored
                                 Shift+Z zooms in again (z2=1 z3=1)". All three are
                                 the zoom level never changing == the Shift+Z event
                                 was never delivered (documented ~1-in-5 bare
                                 `event generate` flake).
  test_sod_pick_no_select_0204   3 of 66: SO14d "net_name_at on empty canvas is empty
                                 -> {#net1}", SO10a "an empty-canvas click still
                                 queues nothing -> {v(net1)}", SO11d "a real E after a
                                 real pick ARMS -> {0} (exp {1})" -- leftover state
                                 from another test's window.
ADDED TO THE FLAKY LIST 2026-08-04 by item 3, after both re-baseline runs (neither run
caught them, so the 9-name list above is 11 names in practice):
  test_hover_highlight           ~30%: measured 3/10 FAILS with item 3 ABSENT, by
                                 interleaved A/B. It passed both re-baseline runs and
                                 the item-3 verifier's audit, which is exactly how a
                                 30% flake hides. Items 4+ will hit it; re-run 3x.
  test_verb_noun_descend_0200    milder: 1 audit fail, then 3/3 clean on re-run.

ADDED 2026-08-04 by the item-3 D3 FIXUP round (implementer and verifier each hit a
DIFFERENT off-baseline set in the same commit — which is itself the evidence these are
environmental, since neither set can reach the changed code: the only callers of
`graph_get_signal_list` are `graph_fill_listbox`'s two lines feeding `.graphdialog`, and
only `test_wave_sigsearch` references the proc):
  test_ase_unnamed_net           ~1-in-4 on AN8 "empty-space click queues nothing ->
                                 {v(short)}". ISOLATION-PROVED: fails the IDENTICAL check
                                 with the IDENTICAL actual value with the fixup ABSENT.
                                 The documented leftover-window-state signature.
  test_wave_hilight              WD2 envelope-cache checks; 3/3 PASS on re-run.
  test_wave_markers              MF1; flaked once, then 3/3 clean.
  test_graph_context             added by item 4; endorsed by BOTH its sessions.
  test_altf5_ciw                 added by item 4; endorsed by BOTH its sessions.
  test_wave_trace_menu           ~50%. RE-LISTED 2026-08-05 by item 5's controlled A/B
                                 (4/6 fail with the item in, 3/6 with it reverted). The
                                 old TG9 root-coords flake, never actually cured.
  ⚠ TWO FLAKY CHECKS INSIDE OUR OWN NEW TESTS, added 2026-08-05 by item 12. These are
    OURS, not the environment's, and the split round (ruling 30) should fix or widen them
    rather than merely list them:
      BH54 (item 11's `winfo ismapped .`)  1-in-4 WITH ITEM 12 ABSENT. This is the
                                 un-named ~20% flap that `11_receipt.md` §13.4 could not
                                 identify — now identified.
      BT45 (item 9's sidebar-geometry leg) 2 of 9 HEAD runs, 0 of 8 item-11 runs, and it
                                 runs BEFORE any item-12 code.
    ✅ ALL THREE FIXED 2026-08-06 BY THE RULING-30 SPLIT ROUND — widened, never deleted
      and never weakened (ruling 17); each now polls a PRECONDITION and returns the
      measurement, so a budget expiry still fails:
      BH54  bare `winfo ismapped .` -> `bs_wait_mapped_top .` (a raise is withdraw +
            deiconify + raise, all asynchronous; the MapNotify can land after the read).
      BT45  read the two widths once mid-resize -> `bs_wait_widths`, which waits for the
            TOPLEVEL width to stop changing. MEASURED cause, and it is not "zero widths":
            settled 1067/480/587 (sidebar narrower) vs flapping 400/240/160 (sidebar
            WIDER, correctly — `browser_width` floors at 240 px, and on a not-yet-grown
            window the floor beats the 45% cap).
      ⚠ BH50, A THIRD ONE, NEWLY FOUND AND NOT PREVIOUSLY LISTED — it failed **6 of the
            8** pre-split measurement runs, harder than either named flake. Both legs read
            `xschem get ...` AFTER an `update`, and that `update` is what delivers the
            Enter/FocusIn that switches the context back to the VIEWER canvas: the check
            was measuring the test's own perturbation. The context claim is now read
            BEFORE any event pump (`browser_descend_to` pumps none, so the read is exact)
            and the world claim on the design window BY NAME after a verified
            `bh_ctx_to` switch — item 12's `bx_ctx_to` idiom. Both claims kept, both
            strengthened.
      ⚠ BX43, A FOURTH ONE, found in a POST-SPLIT SOAK (2 of ~26 runs) and fixed in the
            same commit: `{1 g:x1.x2 unmapped}` — the recorder had fired and the
            selection was already right, so only the mapping was wrong. `bx_vis_m` was
            waiting on the TREE, but `raise_activate_toplevel` is `wm withdraw` +
            `wm deiconify` (issue 0054), which unmaps the whole TOPLEVEL subtree — it was
            polling a consequence, not the cause. It now waits on the toplevel FIRST.
      Post-fix soaks through `run_suites.sh`: file 1 **10/10**, `_i11` **10/12** (one
      X-server death, one no-X arm), `_i12` **12/12** — zero check failures in any.
  test_prop_form_field_width_0170 ADDED 2026-08-05 by item 12's verifier: off BOTH lists,
                                 failed its audit, cleared 3/3 in isolation.
  test_readonly_action_dispatch  ADDED 2026-08-05 by item 11's verifier: ~20-25%. Cleared
                                 per ruling 22 by A/B, NOT by re-run count — with
                                 `src/wave_viewer.tcl` reverted to 809cb979 it STILL fails
                                 on the SAME two checks at a comparable rate (1/5 reverted
                                 vs 1/3 at HEAD). Pre-existing; the baseline never had it.
  test_wave_axis_zoom            ADDED 2026-08-05 by item 10's verifier: CV1/CV7/CV8, the
                                 `graph_at_pointer` probe=-1,-1 / TG9 root-coords family.
                                 Was on NEITHER list. Cleared per ruling 22 by A/B —
                                 reverted tree 4/4 ALL PASS, item-10 tree 6/6 ALL PASS.
  test_launch_context            added by item 6; failed one audit on "main window has a
                                 usable size (geom=1x1+14+8)" — a WSLg map-timing artifact
                                 in a test that never loads the viewer. 3/3 solo.
  test_wire_vertex_grab          added by item 5; 3/3 on solo re-run, statically inert.
  test_ase_dialogs               added by item 5; 3/3 on solo re-run, statically inert.
  test_wave_modes (MG17 only)    ADDED 2026-08-05 by item 7's FIXUP. Failed 3 times in one
                                 ~3-minute window right after a full audit, ALWAYS in the
                                 MG17 block (0173's context bracket): "in_ctx re-asserted
                                 the viewer title it clobbered, once" {0}, "a refused switch
                                 makes in_ctx return {}" {42}, "...having run nothing at
                                 all" {1}. All three follow from ONE precondition — the
                                 xschem context was ALREADY the viewer's when MG17 started,
                                 so enter_ctx took its "already there" fast path and the
                                 test's fake switch_ctx was never reached. A 12-PAIR
                                 INTERLEAVED A/B (fixup vs 876e8f0f) came out 12/12 vs 12/12,
                                 and the fixup contains no window/context op at all.
                                 ⚠ FLAKY, but 0173 may still owe an answer for WHY the
                                 context lands there under load.
                                 ⚠ WIDENED 2026-08-05 by item 7's VERIFIER — the line
                                 "Only MG17 is flaky here; a failure on any OTHER check is
                                 real" was WRONG AS WRITTEN. Its audit failed this name on
                                 the **MG14 strip drag-reorder block** instead, the whole
                                 block together with "a drag is armed and active before ESC
                                 -> {0}" — the documented WSLg gesture-delivery class.
                                 3/3 solo plus a clean blast-radius run on the committed
                                 bytes. So BOTH the MG17 context bracket and the MG14 drag
                                 block flake. A failure elsewhere in this file is still
                                 worth a second look, but it is no longer automatically
                                 real. (Ruling 17's corollary, applied to the baseline
                                 itself: the claim was narrower than the evidence, so the
                                 claim moved.)
  test_ase_interact              ADDED 2026-08-05 by item 7's verifier: produced NO RESULT
                                 line at all, dying inside the "WF Netlist and Run"
                                 simulator block; 3/3 solo at 63 checks. Was on NEITHER
                                 list. Proven unreachable from item 7: ASE's only
                                 `plot_signals` call is byte-identical under the default
                                 `append` across a 107,520-case differential sweep, and
                                 `auto_plot` bypasses `plan_plot` entirely.
  test_fluid_bodyshove_guards_0132
                                 ADDED 2026-08-05 by item 7's FIXUP audit: failed one audit
                                 on "G2: shove landed at OWN body edge x=160 (not flung by
                                 Rfar)", then 3/3 solo. A wire-shove geometry assertion; the
                                 file never mentions wviewer/wave_viewer/graph at all, so
                                 nothing in the batch's changed procs is reachable from it.
                                 Was on NEITHER list. Same shape as the entry below.
  test_verb_noun_copy_move       ADDED 2026-08-05 by item 7's verifier: failed one audit on
                                 "move: pin relocated to 60", then 3/3 solo. A mouse-gesture
                                 assertion in the schematic editor, unreachable from
                                 wave_viewer.tcl. It was on NEITHER list before and would
                                 have burned the next item.
  test_window_switch_bogus_enter NOT flaky — it failed one audit only because its process
                                 died with `X connection to :0 broken`. A VOID result, not
                                 a measurement. 3/3 solo.
  (test_hier_close_prompt is on NEITHER list — DISCHARGED 2026-08-05: PASS in both audits,
   3/3 solo twice, plus the scout's run. Six-plus green points from three agents.)
  (environmental self-skip)      the self-skipping NAME FLAPS run to run — seen as
                                 test_alt_transform_group_0116, _0098, _0107,
                                 test_ase_dirty and test_rotate_stretch_reconnect_0099.
                                 Do not chase the specific name; it is the same
                                 environmental skip wearing different labels.
                                 ⚠ AMENDED 2026-08-05 (item 7's verifier): a single run can
                                 show **TWO** self-skips at once (it saw test_ase_dirty AND
                                 test_rotate_stretch_reconnect_0099), so the skip COUNT
                                 flaps too, not just the name.
                                 ⚠ WIDENED AGAIN, same day, same verifier's later audit:
                                 **SIX at once** — `_0113`, `_0106`, `_0088`, `_0107`,
                                 `_0096`, `_0098`. Do not treat any particular skip count
                                 as the expected one. Six self-skips is not evidence of a
                                 new problem, and a run's skip column is not a measurement
                                 of anything this batch changes. And the audit TOTALS are not
                                 reproducible run to run — 258/23/1/1 and 263/18/0/2 were
                                 both baseline-clean when compared as SETS. Compare SETS.
                                 A count delta is not evidence of anything.
  test_wave_snap                 claimed by the implementer after an hour of isolation
                                 work; PASSED in the verifier's audit. Both readings are
                                 consistent with a flake — listed so item 4+ does not
                                 spend that hour again.

SKIP FLAKE (the one thing run 2 did worse): test_alt_transform_group_0116 SKIPped in
run 2 but PASSed in run 1. Not a fail either way, but a verifier that treats SKIP as
fine should know that name self-skips on a healthy tree.

REMOVED from the 2026-08-03 baseline (now PASSES both runs -- do NOT mistake these
for suppressed tests; a fail on either is a REAL fail):
test_wave_trace_menu              ⚠ THIS DE-LISTING WAS WRONG AND IS REVERSED — see the
                                   FLAKY list above. It passed both re-baseline runs, but
                                   item 5's 12-run controlled A/B puts it at ~50% with the
                                   batch's changes ABSENT. "It was always a flake" was the
                                   better reading and 2 runs could not see it.
test_resolved_net_hash_bus_0158   (no flake history; may genuinely have been fixed by
                                   one of the four intervening commits -- either way
                                   it passes twice now and leaves the baseline)
DEMOTED, not removed: test_remap moves OUT of the hard list and INTO the flaky list
above. It is not fixed; it passed run 2 and flaked run 1.

NEW since 2026-08-03 -- 1 name, and it is EXPLAINED, not a contamination signal:
test_fluid_editing   Fails BOTH runs on exactly FE8. It is NOT new breakage: item 1's
                     verifier already isolation-proved it, failing "on exactly FE8
                     with the item absent too" after reverting src/wave_viewer.tcl to
                     3098afa0 (receipts/01_receipt.md §7). It was nominated as flaky
                     by item 1; these two runs REFUTE that -- it is a hard fail and
                     belongs in the baseline. No unexplained new hard fail exists.

BUILD: green. `make` reported "Nothing to be done for all", which is legitimate and
not a stale tree: the four commits since ccd5f30a touched only src/wave_viewer.tcl,
which is interpreted at runtime. Binary src/xschem is 08-03 09:58; the newest .c/.h is
08-02 08:33.
DIRTY TRACKED FILES at measurement (both are this batch's own bookkeeping, neither is
src/ or tests/):
  doc/claude/signal_browser_batch/PLAN.md
  doc/claude/signal_browser_batch/receipts/02_receipt.md
Everything else in `git status` is untracked `??`. Any OTHER tracked-file diff a later
verifier sees under src/ tests/ doc/ is the current item's, full stop.

SUPERSESSION: this block replaces the 2026-08-03 baseline per driver ruling 15, and is
measured ONCE -- later items do not re-litigate it.
```

---

## Settled design decisions

These are **decided**, not open. A scout that wants to overturn one must verdict `[D]`
with the reason; it may not silently substitute its own.

1. **The browser is a left sidebar inside the viewer toplevel**, not a separate
   toplevel and not a floating assistant. `$top.wvbrowser`, packed
   `pack $top.wvbrowser -side left -fill y -before $top.drw` — the same `-before`
   idiom `readout_show` (`wave_viewer.tcl:6563`) already uses for the bottom bar,
   for the same reason (a plain `-side left` after the canvas gets squeezed to zero).
   xschem has no dockable-assistant framework and building one is an `L` this batch
   does not buy.

2. **The match subject is the FULL raw name, `v(out)` — not the stripped `out`.**
   This is a deliberate divergence from `graph_get_signal_list` (`xschem.tcl:4480`),
   which strips the `v(...)` wrapper for matching *and* for display. Reason: the type
   filter derives from the `v(`/`i(` prefix, so stripping it destroys the very
   information the type dropdown needs, and a user searching `i(` deserves a hit.
   Item 3 retrofits the legacy dialog onto the shared matcher **with a compat flag**
   that preserves its stripped display — the legacy dialog's on-screen behaviour must
   not change.

3. **Wildcards are whole-name anchored**, per ViVA (`references/viva_cadence_waveform_viewer.md`
   §3.3). Shell mode: Tcl `string match` is already whole-string, so it is free. RegExp
   mode: wrap the user pattern as `^(?:$pat)$`. Document that xschem's shell mode gets
   `?` and `[a-z]` ranges from `string match` — glob features Cadence never documented.

4. **An invalid regexp is an ERROR, shown in the search bar, not a silent match-all.**
   The legacy `set err [catch {regexp $pattern {12345}} res]; if {$err} {set pattern {}}`
   (`xschem.tcl:4477`) widens a typo into "show everything", which is the worst possible
   failure for a search box. Item 1 returns an error; items 3/4 surface it.

5. **Search is live-as-you-type AND has a Search button.** ViVA is click-to-apply only
   because its databases are huge and it warns with a modal "Searching" dialog. xschem's
   var lists are thousands of entries at worst — a Tcl `string match` sweep is
   sub-millisecond. Ship both: live filter on `<KeyRelease>`, plus the button (so the
   ViVA muscle memory works, and so a future expensive All-DBs search has a trigger).

6. **Default is case-INsensitive**, `Match case` off, matching ViVA
   (*"Select the Match case check box to perform a case-sensitive search"*).

7. **Default syntax is `Shell`**, matching `viva.filter textFilterType string "shell"`.

8. **No new C code in items 1-15.** Everything is Tcl over the existing
   `xschem raw list` / `xschem raw` verb family. If a scout concludes an item needs a
   `scheduler.c` branch, that is a `[D]` — the C surface is a separate batch.

12. **DRIVER RULING 2026-08-03 (item 0): the items-8-15 auto-defer is WAIVED.**
   Items 8-15 proceed. The auto-defer's premise — "anything that adds state makes 0186
   strictly worse — a reload that destroys the context now also orphans a sidebar" — was
   MEASURED FALSE under a real DISPLAY (`receipts/00_precondition.md` §3): across an
   `xschem reload` on a viewer context the toplevel, `$top.drw`, a sidebar packed with
   the exact item-8 idiom, its packing and its child all survive; the raw survives
   424 vars -> 424 vars; and snapshot/restore state is token-keyed **Tcl**, outside
   `xctx`, so a context wipe cannot reach it. The real "more state = worse" mechanism
   belonged to **0187** (viewer flags branded onto somebody else's live schematic), and
   0187 is FIXED in 3098afa0.

13. **0186 stays OPEN, and items 8+ must route around it.** `xschem reload` typed in the
   CIW while a viewer holds the context still blanks the document, still silently clears
   `readonly`, and under X still pops a modal nobody can dismiss. Therefore: **browser
   state is derived from `xschem raw list` / `xschem raw`, NEVER from the rect model.**
   Any item that derives browser content from rects inherits 0186 and must instead
   verdict `[D]` and say so.

9. **Two test files, not seventeen.** `tests/headless/test_wave_sigsearch.tcl` (items
   1-7) and `tests/headless/test_wave_sigbrowser.tcl` (items 8-15). Each item APPENDS
   its checks to the right file and both files are re-run whole by every later item's
   verifier. Both get `gold/` entries if the suite convention requires one.

   ⚠⚠ **REVISED 2026-08-05 BY DRIVER RULING 30 — `test_wave_sigbrowser.tcl` IS FROZEN.**
   Item 12 measured that at **489 checks the file is KILLED MID-RUN** by WSLg — 5 of 6
   runs for the implementer, **11 of 12 for the verifier** — with **ZERO check failures**,
   while the SAME file at 397 checks completed 8/8 in the same window and both of item 12's
   halves are 3/3 clean amplified 10-12× standalone. The cause is the file's CUMULATIVE
   footprint (six toplevels in one process, up from four) against a compositor now carrying
   116 `could not be marshaled` fatals. **Decision 9's intent was "do not create seventeen
   files" — not "one file at any size".** Three files honour that intent; a file that dies
   90% of the time honours nothing, because it makes every later item's verification
   unmeasurable. See ruling 30 for what replaces it.

   ✅ **EXECUTED 2026-08-06. THE SPLIT AS SHIPPED — items 13-15 read THIS list:**

   | file | items | prefixes | X arm | `--nogui` |
   |---|---|---|---|---|
   | `tests/headless/test_wave_sigbrowser.tcl`     | 8, 9, 10 | BS BT BM | 324 | 135 |
   | `tests/headless/test_wave_sigbrowser_i11.tcl` | 11       | BH       |  74 |  50 |
   | `tests/headless/test_wave_sigbrowser_i12.tcl` | 12       | BX       |  92 |  29 |
   | **items 13-15 create ONE more file** — item 13 owns the name | 13-15 | BR BD BP | — | — |

   `tests/headless/wvbs_common.tcl` is the SHARED PRELUDE all of them source
   (`check`/`check_true`/`pcall`/the counting `::bgerror`/`wvproc_body`/`bs_packed`/
   `bs_order`/`bs_wait_mapped`/`bs_wait_mapped_top`/`bs_wait_widths`/`send_key`/
   `viewer_ready`/`$wsrc`/`wvbs_finish`). It is deliberately **not** named `test_*.tcl`,
   because `full_audit.sh` selects its cases with `ls test_*.tcl` and would otherwise run
   the prelude as a case and score it FAIL forever. The suite total goes **284 → 286**.
   No `gold/` entry is needed — no browser test has one; the convention here is the
   `RESULT: ALL PASS (N checks)` banner.

   ⚠ **The split was cut on FIXTURE COST, not check count.** Across the 8 pre-split
   measurement runs, three deaths landed inside BH5x and five inside BX4x/BX5x, and
   **none** in BS/BT/BM — those two groups are the only ones holding a REAL VIEWER AND
   THE REAL DESIGN WINDOW at the same time. Items 11 and 12 therefore get one process
   each; the three viewer-only items share one. **An item 13-15 group that opens a design
   window as well as a viewer should get its own file on the same rule.**

10. **Hierarchy sync pivots on `xschem get sim_sch_path`, in BOTH directions.**
   That getter (`src/scheduler.c:4567`) returns the path relative to the level where
   the raw was loaded — the same origin the raw's signal names use. `xschem get
   sch_path` is absolute and includes levels above the sim root; using it puts the sync
   one or more levels off, silently and plausibly. Neither item 11 nor item 12 may use
   `sch_path`. A sync is **name-addressed** (`xschem descend -inst <name>`), never
   coordinate- or index-addressed, which also makes it replayable in the action log for
   free.

11. **A failed sync rolls back.** Partway down a hierarchy is a worse place to leave a
   user than where they started. Both directions report what happened in the status bar;
   neither ever fails silently.

14. **DRIVER RULING 2026-08-04 (item 2, divergence D1): `path`/`leaf` split the
   UNWRAPPED name.** `signal_list`'s `leaf`/`path` fields are computed after stripping
   the `v(...)`/`i(...)` wrapper: `v(x1.x2.net5)` → `path x1.x2`, `leaf net5`. The item-2
   contract line's literal reading ("last dot-segment" of the full raw name) yields
   `path v(x1` and `leaf net5)`, which would give item 9's hierarchy tree a root node
   literally called `v(x1`. **AFFIRMED as shipped in 6a3f8e42** — no rework.
   This does **not** touch decision 2: `name` is still the full raw name, `sig_type`
   still reads the `v(`/`i(` prefix off the full name, and `sig_match`'s subject is still
   the full name. Decision 2 governs the MATCH SUBJECT; decision 14 governs the TREE
   SPLIT. They are different questions and both are now closed.

16. **DRIVER RULING 2026-08-04 (item 3, divergence D3): the LEGACY dialog matches the
   STRIPPED name. Deltas 1 and 2 are REVERSED; delta 3 is accepted and documented.**

   Item 3 shipped the Graph dialog matching against the full raw name `v(out)` (wrapped
   `.*(?:$pat).*` for the legacy unanchored semantics), then stripping for display. That
   produced three measured on-screen deltas, pinned by GS12/GS13/GS14. Ruling, per delta:

   - **Delta 1 — a user's `^…$` no longer matches a `v()`-wrapped name: REVERSE.** This
     is a silent regression against precisely the user who knows it is a regexp box.
     Anchoring is the first thing a power user reaches for and it now fails closed.
   - **Delta 2 — a bare `v` now returns every voltage: REVERSE.** "Arguably better,
     definitely different" is the exact thing this item's scope line forbade. Decision 2's
     justification for a full-name subject is that *the type filter derives from the
     `v(`/`i(` prefix* — the legacy dialog has **no type filter**, so the full-name
     subject buys it nothing and costs it this.
   - **Delta 3 — ARE directors / embedded options (`(?i)x`) are now an error: ACCEPT.**
     It is inherent to wrapping the user pattern at all, it is vanishingly rare in a
     signal-name box, and it now fails *visibly* rather than silently misbehaving. Record
     it in the item-16 spec as a divergence; do not spend code on hoisting directors.

   **Mechanism:** strip the input names BEFORE matching, so the subject is the stripped
   name exactly as the legacy body had it (`xschem.tcl:4479-4483` — `regsub`, then
   `regexp $pattern $i`). Keep the `.*(?:$pat).*` wrap (legacy `regexp` was unanchored
   substring; `sig_match` is whole-name anchored per decision 3). Keep the `graph_sort`
   mapping. Keep the ONE sanctioned delta: an invalid regexp yields an empty list, not
   everything (decision 4).

   **This does not overturn decisions 2 or 3.** `sig_match` is not touched — it stays
   whole-name anchored, and `src/wave_viewer.tcl` stays at zero blast radius. Decision 2
   governs the NEW search surfaces (items 4-15), where the type filter makes the full-name
   subject load-bearing. The legacy dialog is a **compat surface**: the point of item 3 is
   code-sharing and the invalid-regexp fix, not behaviour change. Where decision 2's
   general rule and its own *"the legacy dialog's on-screen behaviour must not change"*
   clause collide, the clause wins, because it is the specific one.

17. **DRIVER RULING 2026-08-04: "green mutation with non-zero fuzz defects = FAIL" was a
   BAD ACCEPTANCE CRITERION, and it is withdrawn. Coverage of a regex is proved by a
   DIFFERENTIAL ORACLE, not by counting fixtures.**

   The driver set that criterion for the item-3 D3 fixup and it has no fixed point. The
   mutation space of a regular expression is unbounded — a character class can always be
   narrowed by one more character — so "find a green mutation" always succeeds and the
   rule generates an infinite regress. Two verifier rounds applied it correctly and
   correctly returned `ok=false`; round 1 found the leading anchor (1,872 differing
   comparisons), round 2 found five capture-group narrowings, a widened `\(`, and `v`→`v?`
   (144-1,966 each). A third round of fixtures would find an eighth. **The verifiers were
   right; the criterion was wrong.** This is the driver's error, not theirs.

   **Replacement criterion, binding from here:** a regex whose identity is load-bearing is
   covered when the test file carries a **differential property oracle** — a frozen copy of
   the reference implementation, exercised over a generated name × pattern matrix, asserting
   ZERO differences except the ones explicitly sanctioned. That is strictly stronger than
   any finite fixture set: every behaviour-changing mutation fails automatically, including
   the ones nobody thought of. Both verifiers already built this harness as a throwaway
   probe; it belongs in the committed test instead.

   **The generated name set MUST include the real ngspice classes the fixtures missed**,
   which is how these holes stayed green: `v(a,b)` (differential voltage — `v(out,outb)` is
   an ordinary line in a real `.raw`), `v(vdd!)`, `v(net#1)`, `v(x-y)`, dotted hierarchical,
   and bracketed bus names.

   **Documentation is part of the defect.** A check named *"the capture takes ANY content"*
   that pins two characters, and a part→check map presented as complete when it is not, are
   worse than no claim: a maintainer reading them next to a green suite would reasonably
   "tidy" `(.*)` into an explicit class and ship the regression. Either the coverage widens
   to match the claim or the claim narrows to match the coverage — never neither.

   **Termination:** ONE more round on this. If the oracle lands, item 3's coverage is closed
   and no further mutation-hunting rounds are authorised on it. If it does not, the fixup is
   ACCEPTED AS-IS with a bounded, honest coverage claim written into the receipt — the
   shipped BEHAVIOUR was independently confirmed correct twice, across ~46,000 differential
   comparisons, and behaviour is what users meet.

20. **DRIVER RULING 2026-08-05 (item 5): the Add Trace searchbar KEEPS its Search button
   (`-showbutton 1`). AFFIRMED as shipped.** Item 5 flagged a conflict between settled
   decision 5 (which mandates the button) and driver note (b)'s mention of `-showbutton 0`.
   There is no conflict: note (b) was *describing the API* — `-showbutton 0` is the
   filter-bar variant item 9 will use — not instructing item 5. The Add Trace dialog is a
   SEARCH surface, so decision 5 applies and the button stays.
   The raised concern is real but is not a reason to drop a mandated control: the button is
   the widest child and therefore sets the dialog's minimum width. **That is an EYEBALL
   question, not a design one** — it is in the queue, and if the dialog proves visibly too
   wide the remedy is a layout fix decided on what the screen actually shows. Removing a
   control the spec requires, pre-emptively, against a width risk nobody has yet seen,
   trades a certain loss of function for a speculative gain.

21. **DRIVER NOTE 2026-08-05: P1 IS FIXED — item 5's ledger claim that it was "carried
   unfixed a THIRD time" is STALE.** `src/xschem.tcl:4547-4548` now reads "see the
   `source ... wave_viewer.tcl` line further down this file"; the number is gone, so it
   cannot rot again. The GUI-gate fix (51291535) applied it. Verified by the driver against
   the working tree. No further action; do not re-fix it.

22. **DRIVER RULING (item 5): `test_wave_trace_menu` is RE-LISTED AS FLAKY (~50%)**,
   reversing the re-baseline's de-listing. 12 measurements beat 2. **Generalise: the two-run
   baseline separates hard fails from flakes but CANNOT rate a ~50% flake, and a name that
   passed both runs is not thereby proved stable. When a name fails and you suspect
   yourself, the decisive evidence is an A/B with your own change reverted — not a re-run
   count.** Items 5-12 each used exactly this to clear themselves.

23. **A SABOTAGE MAY LEGITIMATELY FAIL A SUPERSET of its predicted single check** when the
   structure genuinely makes it so (item 6: three independent oracles watching one loop;
   item 8: one claim at source, fixture and live levels). Weakening checks to manufacture a
   single-target number is NOT acceptable. ⚠ **And a PLAN-named sabotage may prove NOTHING**
   — item 10's fired one source check and no behavioural check; item 11's sabotage (b) fired
   nothing at all until repaired with a `raw new` arm; item 12 had to SUBSTITUTE one whose
   target state was unreachable. When that happens, SAY SO and substitute sabotages that
   carry the real load. Do not quietly rename a prediction to match the result.

24. **DRIVER RULING (item 7): `wviewer::plot_dest <token>` is THE destination accessor** and
   nothing may re-implement the policy. **Replace does nothing under multi-plot** — a
   declared limit, surfaced in item 10's menu label rather than hidden.

25. **DRIVER RULING: A DEAD AGENT IS NOT A VERDICT.** Item 8 attempt 1's `[D]` was actually
   `API Error: Connection closed mid-response`; the pipeline collapsed a transport failure
   into a domain judgement. Mark REVOKED, `item_pipeline.js` FIXED (a null scout returns
   `INFRA_FAILURE` and touches no ledger line). **A `[D]` may only come from an agent that
   actually examined the code and said no.**

26. **DRIVER NOTE (items 8 + 9): AN ORACLE CAN BE BLIND, AND AN ORACLE CAN BE WRONG ON
   CORRECT CODE.** Item 8: widths cannot see `-before` (`pack info` does not report it), so
   only slave ORDER sees it. Item 9: that same oracle aimed at the sidebar's own children
   would have FAILED ON CORRECT CODE, because `pack slaves` reports PACKING order and a
   mixed `-side top`/`-side bottom` stack does not draw in packing order. **Verify what a
   named oracle MEASURES, not merely that it can see the thing.**

27. **ITEM 9's DECLARED LIMITS, inherited by items 10-15:** D7 "row order" means RAW-FILE
   order, not the tree's visual order; D8 geometry reads need `update idletasks` (a frame's
   `reqwidth` is computed on the idle queue); D1 the bars are wider than any sane sidebar, so
   at 583 px the error label is clipped and its message is mirrored into the status line;
   D3 a double-click on a GROUP does not plot (ttk owns that gesture) while MMB and the Plot
   button do; **D6 the inventory is a SNAPSHOT taken when the sidebar is SHOWN**, so a raw
   loaded afterwards needs a re-show.

28. **DRIVER NOTE (item 10): A PLAN RATIONALE IS NOT EVIDENCE.** Issue 0178's Button3 swallow
   does NOT transfer to a `ttk::treeview` (ttk binds no `<Button-3>`; `bind all <Button-3>`
   is empty; the canvas is not in the tree's bindtags; the real filter is canvas-level). The
   premise behind an entire item was false, and only measurement found it.

29. **DRIVER NOTE (item 11): THE VACUOUS-CHECK TRAP IS THE BATCH'S MOST PRODUCTIVE FINDING.**
   A negative check ("nothing moved", "nothing fired", "nothing expanded") is worthless
   without a PROVEN POSITIVE CONTROL on the same fixture. Item 11 shipped a rollback check
   that passed with the rollback deleted, caught it by RUNNING the sabotage rather than
   reasoning about the check, then caught the identical trap a second time. Item 12 then hit
   it a third time (its first visibility leg was vacuous because the un-hide repopulates an
   all-open tree) and STRENGTHENED the check rather than renaming it. **Run the sabotage. Do
   not reason about whether the check would catch it.**

30. **DRIVER RULING 2026-08-05 (item 12): SPLIT THE BROWSER TEST FILE. Decision 9 is
   REVISED, not overturned.** At 489 checks `test_wave_sigbrowser.tcl` is killed mid-run by
   WSLg roughly 90% of the time with ZERO check failures; items 13-15 would make it
   monotonically worse. Decision 9 forced the append, so only the driver can lift it.
   - `test_wave_sigbrowser.tcl` is **FROZEN at items 8-12**. No item appends to it again.
   - It is **SPLIT** by ITEM RANGE, so a check's file still says which item owns it, and
     every file is still re-run whole by every later verifier.
   - **Items 13-15 go in a new file.**
   - Three or four files honour decision 9's actual intent ("not seventeen"). A file that
     cannot complete honours nothing, because it makes every later verification unmeasurable.
   ⚠ **The split must not be a silent refactor.** Moved checks must be PROVEN still able to
   fail — each half re-runs its own item's sabotage. A green split is exactly the
   "green but hollow" outcome this batch has caught six times, and moving 3790 lines of test
   code is the easiest place in this whole batch to lose coverage without noticing.
   ⚠ **`wsl --shutdown` is RECOMMENDED but is the USER'S call** — it kills every running
   session including this batch, so NO AGENT MAY RUN IT. The compositor is carrying 116
   `could not be marshaled` fatals, so the threshold may be lower now than on a fresh boot.
   **Split anyway:** the fix must not depend on the machine having been rebooted recently.

   ✅ **DONE 2026-08-06, commit `18c45a16`** (test files only; `git status -- src/` empty).
   **THE SPLIT RULE, MEASURED — apply it for items 13-15:**
   **every DESIGN-WINDOW-COUPLED item gets its own process.** The split point was not
   chosen by check count; the implementer recorded the LAST check each killed run reached
   across 8 pre-split runs: three died inside `BH5x` (~388 checks) and five inside
   `BX4x/BX5x` (~475-486). **Not one died in `BS`, `BT` or `BM`.** Those two groups are the
   only ones holding a REAL VIEWER AND THE REAL DESIGN WINDOW alive simultaneously, each
   with its own loaded document and hierarchy walk. That is the mechanism; the check count
   is only its proxy.
   - `test_wave_sigbrowser.tcl` — items 8/9/10 (`BS` `BT` `BM`), 324 checks, viewer-only.
   - `test_wave_sigbrowser_i11.tcl` — item 11 (`BH`), design-window coupled.
   - `test_wave_sigbrowser_i12.tcl` — item 12 (`BX`), design-window coupled.
   - `wvbs_common.tcl` — shared helpers. ⚠ **Deliberately NOT named `test_*.tcl`**, because
     `full_audit.sh` selects cases with `ls "$HERE"/test_*.tcl`; a prelude with that name
     would be run as a case, run zero checks, print no `RESULT` and be scored FAIL forever.
   **RESULT:** interleaved same-window A/B, 8 cycles — merged file 4/8 completions (2/8
   clean), each split file 8/8, combined **24/24**. Post-fix soaks 10/10, 10/12, 12/12.
   Coverage proven intact FOUR ways, including an exhaustive check-name + payload diff:
   zero names dropped, zero renamed, 483 of 490 payloads byte-identical, and the 8 that
   changed all GAINED legs. BH54/BT45 widened (not weakened) and their flakes measured gone.
   ⚠ **The box is still degraded, and the split did not fix that** — an X-server death still
   killed one soak run and the 194-check items-1-7 file still dies sometimes (2 of 4 in the
   same window). `wsl --shutdown` remains worth doing and remains the user's call.

18. **DRIVER RULING 2026-08-04: the oracle LANDED (5f1de36a). Item 3 closes after one
   scoped cleanup of three proven defects IN the oracle — and closes regardless of how
   that cleanup goes.** Ruling 17 authorised one round; the round produced a working
   differential oracle (GSO01-GSO06, 9,072 comparisons, 290 ms) **and the batch's first
   genuinely clean 283-test pass**. Its verify stage then found three defects in the
   artifact itself, each with a remedy the verifier already proved:
   1. The punctuation sweep is missing `"`, `\` and backtick, so three capture narrowings
      stay green while changing behaviour. One string, two occurrences. The completeness
      claim is asserted in **six** places and is false — this is round 2's sin repeated
      inside the artifact built to cure it. Widen the axis, then state the TRUE bounded
      claim ("any narrowing that excludes a printable ASCII character fails") and list the
      residue (non-printables, non-ASCII) as the acknowledged unbounded tail ruling 17
      withdrew.
   2. The declared "third difference class" **does not exist**. Its premise — that a
      leading-hyphen pattern makes `regexp $pattern {12345}` throw — is false for a
      variable-spelled pattern in Tcl 8.6; measured, 22 comparisons, zero differences. It
      excluded a whole pattern class from the oracle and offered the driver a decision on
      a false basis. Delete the exclusion; putting those patterns back ADDS coverage.
   3. The failure-printing loop reuses `gso_b`, the class-(b) anti-vacuity counter, so
      GSO04 prints "ok" vacuously on exactly the failing runs a reader would be inspecting.
      Rename the loop variable.
   **This is not a fourth mutation-hunting round and none is authorised.** Fixing named,
   proven defects is finishing round 3, not extending it. Whatever the outcome, item 3 is
   CLOSED afterwards and the batch proceeds to item 4.

15. **DRIVER RULING 2026-08-04 (items 1 D7 / 2 P1): the baseline is RE-MEASURED once,
   between items 2 and 3, and the flaky set is named.** Four audits produced four
   different non-baseline sets, so "zero non-baseline fails" has been luck, not evidence.
   The re-baseline runs `full_audit.sh` **twice, solo, sequentially** on the item-2 HEAD:
   a name failing BOTH runs is a hard baseline fail; a name failing ONE is FLAKY and is
   listed separately. Verifiers from item 3 on compare against the hard list and must
   re-run any name in the flaky list before calling it a regression. The baseline is
   re-measured exactly once — later items do not get to re-litigate it.

---

## Ledger

**This table is the ledger.** The pipeline ticks exactly one line here per item and
touches nothing else in this file except the eyeball queue. The detail sections below
are stable reference text and carry no checkbox.

- [x] 0 — PRECONDITION: 0187 FIXED (Tcl-only); 0186 carried forward as `[D]`; the
      items-8-15 auto-defer is RECOMMENDED NOT TO FIRE — its premise is measured false
      (see `receipts/00_precondition.md` §3). Driver's call. -> DONE (3098afa0)
- [x] 1 — `wviewer::sig_match` — the shared matcher (34 checks, 5/5 sabotages
      after the verifier's coverage-hole FIXUP: the regexp arm's case-INsensitive
      DEFAULT is now pinned by SM27, and sabotage (b) legitimately fails TWO
      case-default checks, SM09+SM27 — see `receipts/01_sig_match.md` §8/§11;
      the item's "regexp `l*` matches everything" test bullet is OVERRULED by
      settled decision 3 and asserted INVERTED — see `receipts/01_sig_match.md` §1)
      -> DONE (a6913ab2 + bc1efec9)
- [x] 2 — `wviewer::signal_list` — typed signal inventory (27 checks added, 61 total;
      7 sabotages by the implementer + 3 by the verifier, both NAMED ones single-target;
      DRIVER RULING OWED on D1 — `path`/`leaf` are computed on the UNWRAPPED name, so
      `v(x1.x2.net5)` -> path `x1.x2` / leaf `net5`, not the PLAN's literal dot-split;
      it decides what item 8's tree shows — see `receipts/02_receipt.md` §8 D1 + §9)
      -> DONE (6a3f8e42)
- [x] 3 — retrofit the legacy dialog onto the shared matcher
      (76 checks in test_wave_sigsearch.tcl, 61 -> 76; 9 sabotages by the implementer,
      the NAMED one single-target, + 1 unnamed by the verifier — CAUGHT on GS10+GS12;
      src/xschem.tcl only, wave_viewer.tcl untouched. Verifier ok + scopeClean, and its
      independent 8000-comparison legacy-vs-new fuzz found 0 UNEXPLAINED differences.
      audits 265/18/0/0 (implementer, zero X deaths) and 261/21/0/1 (verifier, one X
      death repaired by 3x re-runs); zero non-baseline fails after isolation tests;
      EYEBALLED under X (the real listbox read out of the widget + a window capture).
      ⚠ ADD `test_hover_highlight` TO THE FLAKY LIST — measured 3/10 fails with
      this item ABSENT, by interleaved A/B; it is in neither re-baseline list.
      ⚠ RE-ANCHOR `test_cadence_drag` — its recorded anchor check now PASSES while 2
      others fail (isolation-proved pre-existing); the next verifier will read that as
      a new regression.
      DRIVER RULING OWED on D3 — driver note (d)'s two halves are in tension
      (full-raw-name subject vs no on-screen change) because the LEGACY body
      stripped BEFORE matching; three deltas are pinned by GS12/GS13/GS14 —
      see `receipts/03_receipt.md` §8 D3 + §7 + §9.
      For item 4: P1 stale `:14295` citation inside the shipped comment; P2 the display
      strip's trailing anchor survives mutation — one fixture element closes it)
      -> DONE (afdd44a0), then CLOSED after 4 driver-ordered follow-up commits:
      3258c372 (ruling 16 — legacy dialog matches the STRIPPED name; deltas 1+2 reversed,
      delta 3 accepted), 1d9652ab (pin every part of the strip regsub), 5f1de36a (the
      DIFFERENTIAL ORACLE, ruling 17 — and the batch's FIRST clean 283-test audit),
      89565388 (ruling 18 — the sweep's 3 missing punctuation chars, the phantom
      third-difference class deleted, the `gso_b` vacuity collision renamed).
      FINAL STATE: 88 checks in test_wave_sigsearch.tcl, ~10,340 oracle comparisons in
      ~290 ms, 0 unexplained; 19/20 wave/graph suites re-run green. Divergence recorded:
      the cleanup added one name-axis entry `{v(0123456789a-zA-Z)}` (+188 comparisons)
      WITHOUT which 40 of 95 capture narrowings stay green — i.e. it is what makes
      ruling 18's authorised claim actually true. In-spirit with ruling 17, not scope creep.
- [E] 4 — PIXEL — `wviewer::searchbar` reusable widget
      (31 checks added, 88 -> 119; 90 in the `--nogui` arm — the file stops being fully
      `--nogui`-safe, D7. 12 sabotages in round 1 + 6 re-measured in the fixup round + 8
      by the verifier, both NAMED ones and both required extras single-target.
      REJECTED ONCE and repaired: two of the four "converging" routes (the type
      `<<ComboboxSelected>>` and the checkbutton `-command`) were pinned by NOTHING —
      `$w.case select` sets the variable without running `-command`, which is why the
      hole was invisible — and the `searchbar_forget` comment was measurably FALSE in
      both halves. BAR27/BAR28/BAR29 close them; the Tk mechanism was re-probed
      independently by both sessions on Tk 8.6.14 and the comment rewritten to what was
      measured. BAR25 (end-to-end generated `<KeyRelease>`) was written, measured
      non-deterministic under audit load, and DELETED with the claim narrowed — D9.
      Verifier ok + scopeClean; its own unnamed U1 (a plausible re-implementation of the
      `-command` bind) was CAUGHT on BAR28 alone, its U2 SURVIVED — the
      `searchbar_error`-on-throwing-consumer path is unpinned but the claim is MEASURED
      TRUE, so it is a coverage gap, not a false claim: **item 5 closes it with one
      check**. Audits 262/20/0/1 (implementer, zero X deaths) and 277-of-283
      (verifier, HALTED by the gate — see below); no fail attributable to item 4.
      ⚠ EYEBALL OWED — spacing, red-on-panel legibility and the 24-char clip budget have
      no headless proxy; see `receipts/04_receipt.md` §10 + appendix §9.
      ⚠ ADD `test_graph_context` AND `test_altf5_ciw` TO THE FLAKY LIST (both endorsed by
      both sessions); item 5 owes a 3x re-run of `test_hier_close_prompt` off a healthy
      panel; the environmental self-skip NAME FLAPS (0116 / 0098 / 0107).
      ⚠ GUI-GATE `revive FAILED -- suite continues UNGATED` fired TWICE more (18:36:58
      implementer, 22:18:25 verifier) — the SEVENTH occurrence today, and it cost the
      verifier a completed 283-test measurement. **Fix before item 5.**
      P1 carried unfixed a SECOND time: `src/xschem.tcl:4548` says `:14352`, the `source`
      is at `:14374` — out of item 4's Files line; the driver should replace the number
      with a grep-able phrase) -> DONE-PIXEL (43bf6d94 + 9c1bfa60)
- [E] 5 — PIXEL — searchbar into `add_trace_dialog`
      (20 checks added, 119 -> 139 in the DISPLAY arm; 90 unchanged in `--nogui`, so 49 of
      139 are now DISPLAY-arm-only. 9 sabotages in round 1 + 4 re-measured in the fixup
      round + 5 by the verifier; both NAMED ones single-target. Closes item 4's V-U2 —
      AT21 pins the throwing-consumer -> `searchbar_error` path with an anti-vacuity
      pre-read.
      REJECTED ONCE ON A BLOCKER and repaired: AT18 read `focus -lastfor` behind a single
      `update` and was a SHIPPED FLAKE (3 fails in 22 solo runs, always the TOPLEVEL) —
      a brand-new toplevel is often still UNMAPPED, so Tk has not applied the focus yet.
      Repaired by WIDENING, not deletion, on a measurement neither the plan nor the
      verifier had: **Tk RE-APPLIES the deferred focus request at MAP time** (12/12), so
      the value is recoverable. `at_wait_mapped` polls `winfo ismapped` (15 s budget) —
      the PRECONDITION, never the asserted value — and AT18 asserts
      `{ismapped focus-record}`, so a budget expiry (`{0 …}`) cannot masquerade as a focus
      theft (`{1 …wvsearch.pat}`). TEST FILE ONLY; `src/wave_viewer.tcl` is byte-identical
      to the revision the verifier audited (md5 987360a5…). Evidence: 25/25 instrumented
      soak with 3 late-mapping runs the OLD form would have failed, and the verifier's
      **115 valid solo runs with 0 AT18 fails** incl. 43 under 2- and 3-way parallel load,
      plus 1 in 30 instrumented runs that reproduced the verifier's exact failure value
      on the REAL dialog and recovered after a 2255 ms wait.
      Verifier ok + scopeClean; all 5 of its own unnamed sabotages single-target,
      including one aimed at the anti-masquerade term (`wm withdraw` + budget cut ->
      `{0 …}`, i.e. a timeout FAILS and prints as "never mapped") and one subtle
      re-implementation (snapshot the selection by INDEX instead of by NAME -> AT14 alone).
      Audits 260/19/0/4 (implementer) and 261/18/0/4 (verifier); `test_wave_sigsearch`
      PASSED INSIDE BOTH — audit load is the condition that revived the flake. No fail
      attributable to item 5.
      ⚠ EYEBALL OWED — WIDTH is the risk the PLAN does not name: the bar becomes the
      dialog's minimum width. See `receipts/05_receipt.md` §7 (six points) and §10.4 for
      what AT18 does NOT pin (visible caret, WM focus arrival, end-to-end X key delivery).
      ⚠ DRIVER RULING REQUESTED — `-showbutton` left at 1 because settled decision 5
      mandates the Search button, against driver note (b)'s `-showbutton 0`. The button is
      the widest child, i.e. the main driver of the WIDTH risk; dropping it is a ruling.
      ⚠ RE-LIST `test_wave_trace_menu` AS FLAKY (both sessions ask). The verifier ran the
      controlled A/B the PLAN's de-listing never had: 6 solo runs with item 5 in =
      2 pass / 4 fail; 6 more with `src/wave_viewer.tcl` reverted to `51291535` =
      3 pass / 3 fail, same fail shapes. Identical rate with the item ABSENT.
      ⚠ ADD `test_wire_vertex_grab` AND `test_ase_dialogs` TO THE FLAKY LIST (both 3/3 on
      solo re-run, both statically inert to item 5); and DROP the
      `test_hier_close_prompt` line — driver note (f) is DISCHARGED, it belongs on NEITHER
      list (PASS in both audits + 3/3 solo twice + the scout's; six-plus green points from
      three agents). `test_window_switch_bogus_enter` FAILed the verifier's audit only
      because its process died with `X connection to :0 broken` — a VOID result, not a
      measurement, 3/3 solo.
      P1 carried unfixed a THIRD time: `src/xschem.tcl:4548` still says `:14352`, the
      `source` is at `:14374` — outside item 5's Files line; the driver should replace the
      number with a grep-able phrase, which is the remedy item 5 applied to the one
      comment it did own, D10b) -> DONE-PIXEL (3c7c993f)
- [x] 6 — multi-select plot from Add Trace
      (19 checks added, 139 -> 158 in the DISPLAY arm; 90 unchanged in `--nogui`, so 68 of
      158 are DISPLAY-arm-only. 7 sabotages by the implementer + 3 by the verifier + 2
      independent re-measurements. NAMED (b) is single-target `{MS10,MS11}`, exactly this
      PLAN's prediction; NAMED (a) fails an honest SUPERSET of its single-check prediction
      — STRUCTURAL, three independent oracles (model `vec` list, trace colors, the canvas
      rect's `node` text) watch the same loop and no injection point severs it for one and
      not the others. MS05/MS07 were NOT weakened to manufacture a single-target result:
      ruling 17's corollary is satisfied by WIDENING, as item 5's E7 was. Verified FIRST
      TIME, no rejection: verifier ok + scopeClean, and its own V3 closed a requirement the
      implementer had not sabotaged ("a typed Expression still wins") -> {MS08,MS09,MS17}.
      ⚠ A SABOTAGE FOUND A REAL TEST DEFECT: a bare `$w.err cget -text` threw into the
      outer catch when the injection destroyed the dialog, silently aborting MS14-MS18
      while the fail COUNT still coincidentally matched the prediction (5) — exactly how
      it would have shipped. Repaired with an `ms_err` helper that makes "the dialog
      vanished" an ASSERTABLE VALUE; re-measured green, and the verifier's own V1
      re-proves the repair independently.
      ⚠ ITEM 5's HANDOFF IS HALF FALSE — item 7 must not repeat it. The AT fixture's
      `win_path` is `$SLVWP` = `.x1.drw`, a TAB (`tabbed_interface` 1), so `winfo exists`
      is 0 and `add_trace` -> `regenerate` -> `viewport_rect` THROWS at `winfo width $wp`
      AFTER `set_graphs` has already written the trace. The dialog half of the handoff
      works, the ADD half does not; the MS fixture points at `$SLMAIN` (`.drw`) — D1.
      ⚠ ITEM 7 INHERITS an extended `sl_main.raw` (2 -> 10 vectors, deliberately NO
      `raw new` because that would drop `wrong_ctx_var` which SL12 still names; MS17 pins
      the exact 10) and the first group in this file that really DRAWS — MS18 pins that
      the teardown really cleaned up (rects=0, readonly=0).
      ⚠ ADD `test_launch_context` TO THE FLAKY LIST — the verifier's audit failed it on
      "main window has a usable size (geom=1x1+14+8)", a WSLg map-timing artifact in a
      test that never loads the viewer; 3/3 on solo re-run, and it is on NEITHER list.
      Audits 265/17/0/1 (implementer) and 265/17/0/1 (verifier); zero X deaths, zero gate
      revive failures, WIREEDIT PASS, 0 scratch leaks in both; NO NON-BASELINE FAIL in
      either. The two 17-name fail sets differ in COMPOSITION only, because the
      environmental self-skip flaps (`test_ase_dirty` vs `test_fluid_editing`).
      ⚠ PROCESS, for every later item: `git checkout -- <file>` is NOT a valid sabotage
      revert while an item is UNCOMMITTED — the first use here reverted `wave_viewer.tcl`
      to `3c7c993f` and deleted the item. Revert from a byte-exact backup of the ITEM
      state. NO EYEBALL OWED (behaviour item, no queue row); `receipts/06_receipt.md` §10
      lists the two things worth a passing user's eye anyway. Receipt filename divergence:
      `receipts/06_receipt.md`, not this item's cited `06_multiselect.md` — the batch's
      `NN_receipt.md` convention, items 2-5, D10) -> DONE (7f8affec)
- [E] 7 — PIXEL — plot-destination dropdown
      (36 checks added, 158 -> 194 in the DISPLAY arm; 90 -> 107 in `--nogui`, so 87 of 194
      are DISPLAY-arm-only. 10 sabotages in round 1 + 6 re-measured FROM SCRATCH against the
      committed bytes in the fixup round + 7 by the verifier; both PLAN-named ones measured in
      BOTH rounds. Shipped: `append`/`replace`/`newstrip`/`newtab` as a `Destination:` combobox
      at row 0 of Add Trace plus an `Options > Plot Destination` cascade, persisted per WINDOW
      (not per tab, D-d), honoured at BOTH landing seams (`add_trace_ok` and `plot_signals`).
      `plan_plot` was EXTENDED, not forked; the `clear` key is emitted **iff** dest is
      `replace`, which is why `test_wave_modes`' ~25 whole-dict oracles stayed green — measured,
      not asserted (sabotage U5 fails 24 there + 10 here).
      REJECTED ONCE on FIVE problems and repaired; none argued away, three were real defects.
      P1 Replace was INERT under multi-plot — multi lands only on strips it creates or on
      reused EMPTY ones, so there is nothing there to clear. The CLAIM is NARROWED (Replace is
      a single-mode policy, declared in four places, pinned by DS05 / DS05b / DS30c), because
      "wipe the whole plot area" is a DIFFERENT policy from the item's own mapping and would
      re-open the reuse arithmetic. P2 `plan_replace_clear`'s "a reused-empty strip is never
      listed" was FALSE in both arms (`single 3 1 2 1 {1 2} replace` -> `clear {2}`): the
      BEHAVIOUR was widened to meet the claim (a 4th `free` argument), and it took a SECOND
      call-site change nobody named — `add_trace_ok` was still passing `{}`. P3 the `newtab` ->
      `append` collapse line was dead code credited as load-bearing: deleted, credit withdrawn
      from the code comment, the receipt and the commit message, and sabotage S6 proves DS09 can
      still fail. P4 a mislabelled number, RE-MEASURED rather than reconciled. P5 baseline
      hygiene, not this item's.
      ⚠ A no-op clear changes NO trace count, so NO count check anywhere could have caught P2 —
      the live checks use a `clear_graph_traces` CALL RECORDER (`ds_spy_*`), with DS30 as its
      positive control and DS04c as an explicit negative control. Third costume of driver note
      (e)(2): make the thing you must observe an assertable value.
      Verifier ok + scopeClean on the fixup; its own unnamed sabotage — an index-space
      corruption in the multi arm (`pre = t - new` -> `pre = t`), which nobody named — was
      CAUGHT on DS05+DS05b alone; it re-measured all six committed-code sabotages EXACT and ran
      a 107,520-case differential sweep of the two revisions (5382 differ, 0 outside the `clear`
      key, 0 on a non-`replace` dest, multi+replace non-empty clears 3078 -> 0).
      Audits 267/16/0/0 (implementer fixup, zero X-deaths, 15 of 16 HARD names — `test_fluid_editing`
      passed, the documented composition flap) and 253/24/0/6 (verifier); no fail attributable
      to item 7.
      ⚠ EYEBALL OWED — dropdown placement, New Tab actually raising the tab, and the New Tab
      error path being CIW-only by construction; see `receipts/07_receipt.md` §5 and §10.
      ⚠ ITEMS 8/9 INHERIT A DECLARED LIMIT: `wviewer::plot_dest <token>` is THE accessor and
      nothing may re-implement the policy — and **Replace does nothing under multi-plot** (D-n).
      A browser gesture offering Replace while the window is in multi mode is offering Append.
      ⚠ ADD `test_ase_interact` TO THE FLAKY LIST (verifier: no RESULT line at all, died inside
      the "WF Netlist and Run" simulator block; 3/3 solo at 63 checks; on NEITHER baseline list;
      proven unreachable — ASE's only `plot_signals` call is byte-identical under the default
      `append` across the 107,520-case sweep, and `auto_plot` bypasses `plan_plot` entirely).
      ⚠ DO NOT NARROW `test_wave_modes` TO MG17 — the verifier's audit failed it on the MG14
      strip drag-reorder block instead, the whole block together with "a drag is armed and active
      before ESC -> {0}", i.e. the documented WSLg gesture-delivery class. 3/3 solo plus a clean
      blast-radius run on the committed bytes. The FLAKY entry's "Only MG17 is flaky here" line
      is wrong as written and should be widened.
      ⚠ THE SELF-SKIP COUNT FLAPS FURTHER THAN THE PLAN ADMITS — the verifier's audit produced
      SIX self-skips at once (`_0113`, `_0106`, `_0088`, `_0107`, `_0096`, `_0098`), against the
      one name the PLAN documented and the two this item amended it to.
      ⚠ The PLAN's own FLAKY amendments (P5) are DELIBERATELY LEFT UNCOMMITTED — this file was
      dirty on arrival and neither item-7 commit carries it) -> DONE-PIXEL (876e8f0f + e5d3a8f7)
- [E] 8 — PIXEL — browser sidebar shell (empty)
      (⚠ ATTEMPT 1 WAS VOID. A `[D] DEFERRED` mark was written here on 2026-08-05 and
      REVOKED by the driver the same day. It was NOT a verdict: the scout agent died on
      `API Error: Connection closed mid-response`, and `item_pipeline.js` could not tell a
      dead agent from a considered DEFER, so it recorded an infrastructure failure as an
      engineering judgement. Nothing was implemented, committed or measured; `src/` and
      `tests/` were untouched. The pipeline now returns `INFRA_FAILURE` and touches NO
      ledger line in that case. ATTEMPT 2 ran from scratch and is what follows.
      NEW TEST FILE `tests/headless/test_wave_sigbrowser.tcl` — the second file of
      decision 9. 84 checks, all 84 new; 28 of them source/pure and therefore also green
      under `--nogui`, and the header says loudly that **a green `--nogui` run proves
      NOTHING about the sidebar**. 2 implementer sabotages (both PLAN-named) + 2 by the
      verifier; neither implementer injection was single-target, and in both cases every
      extra was the SAME claim observed at another level (source / fixture / real viewer),
      which ruling 23 sanctions — no check was weakened to manufacture a smaller number.
      SHIPPED: `$top.wvbrowser` packed `pack $f -side left -fill y -before $top.drw`, which
      is settled decision 1 VERBATIM and the exact line item 0 measured surviving an
      `xschem reload` (`receipts/00_precondition.md` §3) — so **the items-8-15 waiver is
      INTACT**, and BS01 asserts that literal string and names itself its guard. Built
      HIDDEN out of `open` (the `tabbar_build` rule), so a viewer that never opens the
      browser has byte-identical canvas geometry — pinned on a REAL fresh viewer by
      BS40/BS41. Two arrays in the shipping `gridshow` shape — `::wviewer::browser` is the
      AUTHORITY, `::wviewer::browsershow` the Tk `-variable` mirror pushed by
      `sync_browser_mirror` — because collapsing them makes sabotage (b) unfireable.
      PER TOKEN, NOT PER TAB (`layouts`/`cvr` are tab-frozen; a sidebar over the WINDOW's
      raw inventory must not blink on a tab switch) — items 9-15 inherit this. The toggle
      does not capture, regenerate or switch context: the resize already rides
      `<Configure>` → `configure_apply`.
      KEY `<Control-Key-l>`, with the written three-path collision check recorded at the
      binding: 108 is not in `graphkeys`, its only `keybindings.csv` row is bare `l` mod 0
      (`edit.add_wire_label`, ctx `canvas`), NO rc binds it so `clone_canvas_bindings` has
      nothing to copy (BS45 proves survival across a real `strip_bindings` sweep), and the
      body `break`s. **Ctrl-B was considered and REJECTED** — 98 IS a `graphkeys` member and
      membership is unconditional on modifiers, so one keystroke would also have toggled
      cursor B.
      ⚠ THE PLAN'S OWN SABOTAGE-(a) ORACLE DOES NOT WORK, and that is now MEASURED, not
      argued. "Assert the canvas keeps non-zero width" cannot see a dropped `-before`: the
      canvas is `-fill both -expand true`, so it is the SIDEBAR that collapses, and only on
      a narrow toplevel. Under sabotage (a) BS26 (canvas width) and BS27 (sidebar width)
      both stayed GREEN. The working discriminator is pack-SLAVE-ORDER (BS24 fixture, BS43
      real viewer), the house oracle from `test_wave_tabs.tcl`; the width legs ship as
      documented regression guards and say so in the file. **Items 9-15 must not reach for
      a width oracle here.**
      ⚠ MANDATORY COLLATERAL, done: one `doc/waveform_viewer_guide.html` §9.1 row plus
      `test_wave_grid` GH0's two hard-coded literals 14 → 15 and 9 → 10, or GH0-GH4 would
      have failed and read as item 8's regression (`test_wave_grid` is on NEITHER baseline
      list). Green afterwards at 245. **Every later item that adds a viewer key or a menu
      accelerator owes the same two edits.**
      Verifier ok + scopeClean; both of its own unnamed sabotages were CAUGHT — S1
      (`-side left` → `-side right`) on BS01+BS25, S2 (delete the `$new == $cur` early
      return from `browser_toggle` ONLY, leaving `grid_toggle`'s identical line alone) on 4
      checks including BOTH `ds_spy`-shaped NEGATIVE controls. Audits 262/18/0/4
      (implementer, zero X-deaths) and 264/19/0/1 (verifier); `nonBaselineFails` is EMPTY in
      both. The off-list names DIFFER between the two runs — implementer `test_multi_window`
      + `test_readonly_action_dispatch`, verifier `test_add_pin_lib_symbol_view` — which is
      itself the evidence that they are environmental; all three PASS solo, and all 16
      `wave_*` suites passed in the verifier's audit including the ~50%-flaky
      `test_wave_trace_menu`.
      ⚠ EYEBALL OWED — and note what is NOT claimed: NO divider/sash was added, so this
      item's own "the divider is draggable if one is added" is **NOT APPLICABLE**. See
      `receipts/08_receipt.md` §6 (ledger) and appendix §7.
      ⚠ FIX BEFORE ITEM 9 — the new file's header, which items 9-15 inherit VERBATIM as
      their convention contract, says "14 run in both arms" where the measured number is
      **28** (`tests/headless/test_wave_sigbrowser.tcl:27`). One-word fix; deliberately NOT
      made by this ledger stage, which may not touch `tests/`.
      ⚠ FOUR NEW STALE LINE ANCHORS, shipped by the item whose own divergence list OPENS by
      correcting one (`readout_show` is `:7067`, not the `:6563` this PLAN and settled
      decision 1 both cite): `wave_viewer.tcl:5822` says readout_show is at `:7080` (it is
      `:7261`), `:359` says `tab_thaw` is at `:9330` (`:9526`), and the receipt cites
      `snapshot` at `:2585` (`:2609`) and the graphkeys-modifier note at `:8534` (`:8728`).
      Comment/prose only, no check depends on any of them — but item 4's P1 asked for
      grep-able phrases instead of numbers and this is the fourth item to pay for ignoring it.
      ⚠ THE RECEIPT NAMES THE WRONG COMMIT TWICE (`1b9aa319`, amended away and reachable
      from no branch); corrected in the ledger section, appendix preserved verbatim. And
      `f3c89935` holds EXACTLY FOUR files — the receipt is NOT in it: `08_receipt.md` is
      untracked, as are `00_` and `01_`, while `02_`-`07_` are tracked. Pre-existing and
      not item 8's to resolve, but **this batch's durable record is currently half
      untracked** and the driver should settle it.
      ⚠ ITEM 15 INHERITS TWO THINGS: `wviewer::snapshot` was NOT touched, so sidebar
      visibility does not survive save/restore; and `readout_show` packs the readout bar
      `-before $top.drw` ON DEMAND, so unlike the always-built status bar its width is
      ORDER-DEPENDENT against the sidebar — cosmetic, invisible to every current check, and
      exactly the kind of thing that reads as a regression later) -> DONE-PIXEL (f3c89935)
- [E] 9 — PIXEL — browser content: tree + search + filter
      (132 checks added, 84 -> 216 in the DISPLAY arm; 28 -> 91 in `--nogui`, so 125 of 216
      are DISPLAY-arm-only. 131 new `BT*` plus ONE widened `BS22` leg. 3 implementer
      sabotages (all three PLAN-named) + 3 by the verifier; every one single-target.
      Shipped: a `ttk::treeview` populated from `wviewer::signal_list` ONLY (decision 13 —
      never the rect model), grouped one node per DOT SEGMENT of the item-2 `path` so
      ruling 14's split gives `x1 > x2 > net5` and no node is ever called `v(x1`; FLAT when
      no signal has a path. Search bar on top (button KEPT, decision 5) + a
      `-showbutton 0` Filter bar at the bottom — ruling 20's variant, first user — ANDed by
      CHAINING `sig_match` so the second bar filters the FIRST bar's output. All three
      §3.4 gestures (double-click, MMB, Plot button) funnel into `plot_signals`, so item 7's
      destination policy stays implemented once (ruling 24) — asserted by BT06, and its
      Replace-under-multi limit is asserted AS a limit (D2), not papered over.
      ⚠ THREE PLAN ERRORS, all caught by MEASUREMENT, none by review.
      (1) **A5's width rule does not work as written**: a frame's `reqwidth` is computed on
      the IDLE queue, so measuring straight after `pack` gave `755 - 172 = 1 - 1 = 0`, the
      240 px floor took over and decision 5's Search button was clipped off-screen
      (`mapped=0`). One `catch {update idletasks}` gives sidebar 583 / canvas 817 / Search
      mapped at x=502. The implementer ALSO reports that the clipped entry stopped Tk
      delivering a synthetic `<KeyRelease>` at all — "the pixel bug and the binding-never-
      fires symptom were ONE defect". **The verifier re-injected exactly that removal and
      got ONE fail (BT23, the mapped-button check); BT25/BT26 stayed green** — so the WIDTH
      claim is genuinely pinned, but the coupled-symptom story is a development-time
      observation that does NOT reproduce at the shipped fixture size. Recorded as observed,
      not as a pinned claim.
      (2) `event generate <Double-Button-1>` is **ILLEGAL** in Tk ("Double, Triple or
      Quadruple modifier not allowed") — a double-click is a PATTERN in the press/release
      stream, so driver note (f)'s "drive the real route" required replaying two
      ButtonPress-1/ButtonRelease-1 pairs.
      (3) **The plan's own internal-layout oracle would have FAILED ON CORRECT CODE.** Item 8's
      `bs_order` is right for sidebar-vs-canvas (BT21/BT45), but the plan also aimed it at the
      sidebar's OWN slave order — and `pack slaves` reports PACKING order, which for a mixed
      `-side top`/`-side bottom` stack is NOT visual order (`.ph`/`.wvfilter` are packed BEFORE
      `.tvf` precisely so the tree, packed last with `-expand 1`, takes what is left BETWEEN
      them). WIDENED, not weakened: BT21 asserts the whole `pack slaves` list + each `-side` +
      the tree's `-expand`. That is note (b)'s lesson one level deeper: **verify what a named
      oracle MEASURES, not merely that it can see the thing.**
      ⚠ SABOTAGE (c)'s FIRST RUN EXPOSED A DEFECT IN THE TEST, not in the code: an unguarded
      `$tv parent g:x1.x2` THREW, escaped to the file's outer catch and silently ABORTED 51
      later checks while the printed fail count still looked plausible — item 6's trap,
      reproduced exactly. Every hard-coded row id is now `pcall`-wrapped and the re-run fails
      24 and aborts nothing. Strongest evidence yet in this batch for sabotage-verification:
      the defect was invisible on green.
      ⚠ TWO OF ITEM 8's OWN CHECKS EDITED, BOTH WIDENINGS (ruling 17): BS22's only-child leg
      (falsified by construction once the sidebar is filled) became an assertion of the FULL
      item-9 child set plus "`.ph` is still child #1"; and BS08's NAME/comment — which claimed
      `browser_toggle` does "widget geometry only … no context switch" while toggling ON now
      repopulates and takes a 0173 loan one level down — were NARROWED to "browser_toggle's OWN
      BODY", with the loan's real location (`signal_list`) written into test and source.
      Coverage was not reduced in either case.
      Verifier **ok + scopeClean**; its three unnamed sabotages: V1 (break the AND at the
      WIRING level — read the search bar twice) -> 7 FAIL, all BT26/BT27, each showing the
      unfiltered superset as the got-value; V2 (remove `update idletasks`) -> 1 FAIL, BT23;
      V3 (sever the Plot button's `-command`) -> 4 FAIL on BT30/BT31/BT32, MMB and
      double-click green. All reverted and diffed byte-identical; clean re-run 216/0.
      ⚠ ONE MINOR, NON-BLOCKING PROBLEM CARRIED FORWARD, ruling 17 (a check NAME that
      overstates what it pins is itself a defect): **BT44's two real-viewer checks are named
      as GESTURES** ("a Plot-button gesture under newstrip created a new strip", "under multi
      a Replace gesture APPENDS") **but call `::wviewer::browser_plot_selection` directly** —
      the handler, not the Tk route (`test_wave_sigbrowser.tcl:1491`, `:1503`). PROVEN by V3:
      severing the button's `-command` failed BT30/31/32 and left BT44 GREEN. Coverage is NOT
      missing — the real `$BTF.tb.plot invoke` route is pinned by BT30/31/32 and BT43 drives
      the real MMB + double-click against real traces — but no single check does
      (real button route -> real trace); only the composition does. **Fix in item 10** (it
      re-touches these gestures anyway): swap to `$BTVF.tb.plot invoke`, or narrow the name to
      say "the Plot handler". One line either way.
      Audits: 256/24/0/4 (implementer) and 260/22/1/1 (verifier). BOTH carried WSLg Xwayland
      X-deaths (3 and 4 `X connection to :0 broken`), both corroborated in `/mnt/wslg/stderr.log`
      per ruling 19 — the verifier's with `weston: … weston_wm_handle_map_request: Assertion
      !window->shsurf failed` + a WSLGd restart at 13:32:50 — and every one re-ran CLEAN, leaving
      exactly the 16 HARD baseline names + `test_wave_trace_menu`. **nonBaselineFails = [] on both
      runs.** Ruling-22 A/B on `test_wave_trace_menu` (it failed TG10 in the verifier's audit):
      3/3 PASS at HEAD, then 1/3 FAIL with item 8's `wave_viewer.tcl` restored — the flake
      reproduces WITHOUT item 9, and it is the documented ~50 % TG9/TG10 root-coords family.
      Item 9 cleared; tree restored byte-identical.
      ⚠ EYEBALL OWED — but the ONE Eyeball clause that could become evidence HAS: BT17 builds
      2220 rows from 2000 signals in 14-20 ms and BT33 does the whole real refresh (both bar
      reads, the chained AND, 2220 ttk inserts) in 15-16 ms, printed AND asserted in-suite, and
      independently reproduced by the verifier. What is left for a human is judgement: the
      sidebar is **583 px, 42 % of a 1400 px window**, and it is that wide BECAUSE decision 5
      requires the Search button against item 4's 755 px bar (under the 45 % cap by design).
      ⚠ NEW DECLARED LIMITS: **D7 — "row order" means RAW-FILE order, NOT the tree's visual
      order** (ttk re-parents a late arrival under its group, so `v(x1.x2.n) v(x1.y3.n)
      i(x1.x2.n)` DRAWS the two `x1.x2` leaves adjacent while `browser_leaf_names` returns them
      first-and-last; plotting a group plots in raw order — written into the source comment and
      into BT29's check NAME, ruling 17). **D8 — `browser_width` needs `update idletasks`.**
      **D1** — the bars are wider than any sane sidebar (755/680 px): at 583 px the Search button
      is mapped (x=502) and the ERROR LABEL is clipped (x=577, `ismapped 0`), mitigated by
      mirroring the message into the status line. **D3** — a double-click on a GROUP does not
      plot (ttk owns that gesture); MMB and the Plot button do. **D6** — the inventory is a
      SNAPSHOT taken when the sidebar is SHOWN, so a raw loaded afterwards needs a re-show
      (items 13/15).
      ⚠ REVERT METHOD DEPARTED FROM THE LETTER OF THE DISCIPLINE, stated not glossed: item 9's
      work was UNCOMMITTED during sabotage, so `git checkout -- src/wave_viewer.tcl` would have
      discarded the whole item; a pristine post-implementation copy was kept in the scratchpad
      and each injection diffed against it instead. The verifier, working against the commit,
      used `git checkout --` normally.
      ⚠ RECEIPT FILENAME, D10 again: the PLAN's Receipt line says `receipts/09_browser_tree.md`;
      the file is `receipts/09_receipt.md`, matching every file on disk and the pipeline. The
      per-item Receipt lines have been wrong since item 7 and the driver should fix items 10-16
      in one pass) -> DONE-PIXEL (46f89349)
- [E] 10 — PIXEL — RMB context menu on a browser row
      (⚠ THE PLAN'S CENTRAL PREMISE WAS WRONG AND THE ITEM SAYS SO: issue 0178's Tcl-only
      Button3 swallow does NOT transfer to a `ttk::treeview`. Re-measured three ways —
      ttk's Treeview class binds no `<Button-3>`, `bind all <Button-3>` is empty, and the
      CANVAS is not in the tree's bindtags; the swallow the PLAN cites at
      `wave_viewer.tcl:7680` really lives in `btn3_filter` (`:9656` per the scout,
      re-measured at `:9879` by the verifier — a CANVAS-level filter, structurally
      inapplicable here). The `break` is KEPT as defence in depth and BM01 is NAMED to say
      only that; the negative claim is carried by BM35 (structure) and BM42 (real gesture).
      PLAN sabotage (1) was run anyway and reported honestly: it fires ONE source check and
      NO behavioural check. Two substitutes carried the real load — severing the whole bind
      (10 fails, BM42's canvas ZERO surviving, which is what proves the negative control is
      not vacuous) and making `Plot to` PERMANENT (11 fails, all three of BM31's teeth).
      SHIPPED: an 8-entry menu — disabled header naming the target, `Plot (<dest>)`, a
      `Plot to` cascade (Append/Replace/New Strip/New Tab) that is a ONE-SHOT override
      (`plot_signals`' new 4th `destover` param, resolved BEFORE `dest_prepare`),
      `Send to Add Trace...`, `Copy name(s)`, and item 11's reserved disabled
      `Descend to here`. `browser_menu_unpost` at BOTH teardown sites (`forget` and
      `tab_drop_transients`).
      A REAL DEFECT WAS FOUND BY THE TESTS, not by review: `browser_copy_names` first wrote
      a bare `clipboard clear`, which Tcl resolved to this namespace's own 0-argument
      `wviewer::clipboard`; the throw was swallowed by the proc's catch and the entry
      silently did nothing. Every structural check was green — only BM33's real
      `clipboard get` saw it. Now `::clipboard`, pinned at source (BM09) and behaviourally.
      DECISIONS: an RMB on a GROUP posts and acts on its leaves (item 9's D3 yields the
      DOUBLE-CLICK to ttk, and ttk owns no Button-3); the RMB never mutates the selection;
      blank tree space posts NOTHING (not a menu of dead entries); `Copy name` is a DYNAMIC
      label; the multi-plot Replace limit is SURFACED in the label (`Replace -> appends`)
      from one shared `dest_menu_label`. ASCII `->` / `...` rather than the PLAN's `→` / `…`.
      ORACLE: a menu is not a widget tree, so this group ships `bm_entries` and a
      FIVE-valued `bm_menu_state` (absent / empty / built:N / posted:N / unreadable); all
      four meaningful values observed for real, `dismissed` being the built:N that follows a
      posted:N, asserted as one sequence. Exactly ONE real `tk_popup` (global grab) is taken.
      VERIFIER took a 4th, UNNAMED sabotage designed to evade every source-level check —
      flipping the one-shot resolution to `$destover ne {}` so all of BM05's greps still
      match — and got 4 behavioural fails (BM44 ×2, BT44, BM46). The coverage is real.
      ⚠ FLAKY-LIST INPUT for the next item, not a fail: `test_wave_axis_zoom` (CV1/CV7/CV8,
      the `graph_at_pointer` probe=-1,-1 / TG9 root-coords family) failed in the verifier's
      audit and is on NEITHER the HARD nor the FLAKY list. Cleared per ruling 22 by A/B —
      reverted tree 4/4 ALL PASS, item-10 tree 6/6 ALL PASS — item 10 adds no canvas binding
      and no pointer code. `nonBaselineFails` stands EMPTY.
      NOT PUSHED) -> DONE-PIXEL (809cb979)
- [x] 11 — hierarchy sync: browser -> schematic ("Descend to here")
      (SHIPPED Tcl-only, no C (decision 8), `ase_window.tcl` READ-ONLY: `Descend to here`
      walks the ASE-L session's DESIGN window to the hierarchy path of the selected browser
      row(s), via item 10's reserved RMB slot, a View-menu entry, and `E` bound on BOTH the
      WaveViewer tag AND the tree widget — the canvas is NOT in the tree's bindtags, so one
      bind alone would be a key that never fires where the user actually is.
      ⚠ DECISION 10 MEASURED for the first time (currsch 2, sch_path fixed at `.X1.X2.`):
      raw_level 0 -> `X1.X2.`, 1 -> `X2.`, 2 -> `` — TRUE. THE COROLLARY MATTERS MORE: with
      NO raw loaded the two getters are BYTE-IDENTICAL (`sch_waves_loaded()` is -1 so the C
      skip loop never runs), therefore THE PLAN'S SABOTAGE (b) FIRES NOTHING as written; it
      needed a `xschem raw new` + `set raw_level 1` arm (BH29-BH31) to have any teeth.
      ⚠ FIVE PLAN DEFECTS, every one found by measurement: (1) `sim_sch_path` carries a
      TRAILING DOT and is EMPTY at the sim root, which the PLAN's algorithm compares straight
      against a dotted browser path that has neither — `hier_split` normalises; (2)
      exact-first + case-insensitive retry is NECESSARY BUT NOT SUFFICIENT — the FINAL VERIFY
      must also be `-nocase`, or a correct walk of `x1.x2` lands on the schematic's `x1.X2`
      and is rejected by its own verify (split into byte-exact `hier_common` for the prefix +
      `-nocase` `hier_same` for the verify); (3) `descend -inst` returns the STRING `0`
      WITHOUT THROWING for a non-subcircuit or a raised semaphore, and `go_back` returns void
      and does not ascend on a cancelled save prompt — so every step is confirmed by READBACK
      of `sim_sch_path`, never by `catch` (driver note (d)'s exact shape); (4) sabotage (b) is
      toothless; (5) the PLAN's BH23 "rollback from depth 1" is VACUOUS — a 1-segment shared
      prefix means the plan is a single descend that never happens, so "unmoved" is true with
      or without the rollback. THE IMPLEMENTER SHIPPED (5) HIMSELF FIRST: his first cut of
      BH23 PASSED with the rollback deleted. Retargeted at `X1.X2` -> `x1.nosuch`; the SAME
      trap was then caught in BH51 by running sabotage (a) under X and fixed the same way.
      Both found by RUNNING the sabotage, not by reasoning about the check.
      FOUR SABOTAGES, each fired EXACTLY its targets and nothing else, each reverted against a
      pristine scratchpad copy (never `git checkout --`, which would have discarded the
      uncommitted item), each followed by a clean green re-run: (a) delete the rollback -> 4
      fails in `--nogui`, 5 under X, all of them rollback checks (⚠ the PLAN predicted BH25
      among them — it is NOT: `V9` is refused on the FIRST descend so nothing has moved and
      there is nothing to roll back; BH25's teeth are the non-throwing refusal. Said rather
      than quietly renamed); (b) REPAIRED as above -> BH06, BH30 leg 2, BH31, with every
      no-raw leg staying GREEN, which is the point; (c) drop the `-nocase` scan from
      `hier_resolve` -> BH26 only; (d) ADDED, not in the PLAN, `hier_same` -> `eq` -> BH04
      leg 1 + BH26, whose failure message is literally `verify failed at x1.X2` — the defect
      the scout's own prototype shipped, not a hypothetical.
      VERIFIER (ok, scopeClean) re-verified all four `scheduler.c` anchors from source, found
      the `sim_sch_path` body PROVES decision 10, re-measured both arms to the SAME 397/185,
      and took his OWN UNNAMED sabotage aimed at driver note (d): delete hier_walk's
      world-readback so only `catch` guards the descend loop -> 1 fail, EXACTLY BH25.
      ⚠ HIS SECOND PROBE FOUND A COVERAGE HOLE, recorded rather than glossed: neutering the
      FINAL VERIFY entirely leaves `--nogui` FULLY GREEN at 185/185. Sabotage (d) proves the
      verify RUNS and that its `-nocase` matters, but no check constructs a walk whose every
      step reports success and whose landing is nonetheless wrong, so DELETING the verify is
      invisible. Claim NARROWED rather than coverage widened (ruling 17) — the verify is
      belt-and-braces over per-step readbacks that already catch the known cases.
      ⚠ FLAKY-LIST INPUT FOR ITEM 12, not a fail: `test_readonly_action_dispatch` failed the
      verifier's audit and is on NEITHER the HARD nor the FLAKY list. Cleared per ruling 22 by
      A/B, not by re-run count — with `src/wave_viewer.tcl` reverted to 809cb979 it STILL
      fails on the SAME two checks at a comparable rate (1/5 reverted vs 1/3 at HEAD). A
      pre-existing ~20-25 % flake the baseline does not record; THE DRIVER SHOULD ADD IT.
      `nonBaselineFails` stands EMPTY: implementer 269/15/0/0, verifier 264/18/0/2, ZERO
      `X connection to :0 broken` in both, and both fail SETS are the 16 HARD names plus
      already-cleared flakes — compare SETS not counts, and 15-of-16 was ONE SAMPLE, not a
      property. ⚠ Also un-named: 1 of the verifier's 5 X-arm runs scored 396/1 and the
      flapping check was NOT captured (output piped to `tail`); the other 4 were 397/0 and
      both `--nogui` runs clean — inside the file's documented WSLg key-delivery envelope,
      recorded rather than pretended away.
      VECTORS ARE A DECLARED [D], issue 0212 filed (next free number, confirmed): a bracketed
      segment is REFUSED naming the issue, because `descend_schematic` writes the EXPANDED
      slice `x1[3]` into sch_path via `find_nth` while `get_instance` only matches the
      unexpanded `x1[3:0]` — the browser's own path cannot be fed back to the name-addressed
      verb. The `change_sch_path` route a future item would take is written up in 0212.
      OTHER DECLARED LIMITS: a multi-row target whose rows DISAGREE leaves the entry DISABLED
      with the reason in the status line (chosen against a silent first-wins, ruling 17); a
      case-MISMATCHED already-at-target RE-WALKS rather than no-opping (it lands correctly and
      reports the schematic's spelling); `sod_base_level` answers 0 when the session's design
      is not in the window's stack AT ALL, so the origin guard passes there too — a
      pre-existing hole in `ase_window.tcl`, ASSERTED at BH32 rather than closed; a sync
      CLEARS THE SELECTION at every level traversed, because C's `descend -inst`/`go_back`
      both call `unselect_all(1)`.
      DECLARED DEVIATION from the test file's own arm blocking: BH20-BH39 run in BOTH arms
      against a REAL loaded fixture rather than a throwaway toplevel — the subject is the
      xschem hierarchy walk, which needs no Tk, and gating it on X would have made the item's
      defining behaviour (the rollback) X-only for no reason. Two measured harness facts
      behind it: REAL KEYS DO NOT WORK on a throwaway toplevel (it is not the WM's active
      window, so `focus -displayof` never names its widgets — item 10's Button-3 legs work
      there only because pointer events need no focus), and A SUCCESSFUL SYNC STEALS THE FOCUS
      from the viewer (it raises the design window — that is the feature), so a re-raise is
      required between key legs or the next `send_key` self-skips.
      THREE INHERITED CHECKS REWRITTEN, each pinning BOTH states rather than being dropped:
      BM02 (source) + BM25 (widget) pinned item 10's reservation that item 11 CONSUMES and now
      pin live-with-command AND still-disabled-with-no-command; BT09 pinned item 9's "no bump
      needed" claim against test_wave_grid's 15/10 literals — its second leg now reads 16/11
      and a NEW third leg pins that the ONE addition is `<Key-E>`/`Descend to here`, so the
      bumped literals cannot be satisfied by some third key appearing.
      ⚠ PRE-EXISTING CRASH FOUND, NOT FIXED and NOT FILED (out of scope, no C): `xschem raw
      read` on an ASCII rawfile whose `Values:` block lacks blank-line point separators
      SEGFAULTS. Hit while hand-writing a fixture raw; sidestepped with `xschem raw new`/`raw
      add`, which is also the existing BTV/BMV idiom.
      +74 checks (397 X-arm, was 323) and +51 (185 `--nogui`, was 134), both re-measured
      independently by the verifier and matched EXACTLY. The GUI gate paused twice and was
      waited out both times; `GUI_GATE=0` was never set.
      NOT PUSHED) -> DONE (b81ee0c9)
- [x] 12 — hierarchy sync: schematic -> browser ("Show in Signal Browser")
      (SHIPPED Tcl-only, no C (decision 8), `ase_window.tcl` READ-ONLY: Ctrl-5 / Tools >
      "Show in Signal Browser" opens-or-raises the ASE session's viewer, un-hides the
      browser sidebar and selects + scrolls to the tree node for the schematic's current
      hierarchy position, or the deepest ancestor that exists, saying which. Pivot is
      `xschem get sim_sch_path` through item 11's `hier_now`/`hier_split` (decision 10, no
      second normaliser); the window-relative position is mapped onto the browser origin by
      dropping `ase::session_for_current`'s level (0168) and that mapping is asserted
      BYTE-EQUAL to `ase::ui::sod_rel_path`, not assumed. The pivot is read BEFORE the
      viewer is touched, because opening/showing moves the xschem context to the viewer.
      ⚠ TWO PLAN CLAIMS WERE WRONG AND BOTH ARE PINNED BY A CHECK: (1) the Files list said
      `src/ase_window.tcl` — that builds the ASE-L SESSION window's menubar, not the design
      window's; the design window's Tools cascade is `xschem.tcl:14933`, so `src/ase.tcl` +
      `src/xschem.tcl` were substituted and `ase_window.tcl` was NOT modified; (2) "you will
      need to bump `test_wave_grid` GH0 again" is FALSE — GH0/GH2 count only `bind
      WaveViewer` inside `install_default_binds` and `-accelerator` inside `build_menubar`,
      and item 12's key is a schematic `.drw` bind on a `xschem.tcl` cascade, so 16/11 MUST
      STAY and no `data-seq` guide row may be added (BX13).
      4 sabotages, one SUBSTITUTED and one ADDED, both declared (ruling 23): the PLAN's
      "select without expanding ancestors" is not a reachable state — `see` IS the expansion
      and `browser_populate` opens every row — so deleting `see` carried the load; and the
      `-nocase` candidate was ADDED because without it the item finds nothing on any real
      ngspice raw. Each fired exactly its targets plus a declared superset, each reverted,
      clean re-runs green. RUNNING sabotage (a) again proved a check VACUOUS (BX42's first
      visibility leg — the un-hide repopulates an all-open tree); it was STRENGTHENED with a
      second invoke on a deliberately collapsed tree, not renamed. A probe found a REAL
      defect before it shipped: the miss-retry `browser_refresh` could replace a good tree
      with an empty one (a failed read answers with nothing) — now IMPROVE-OR-RESTORE (BX39).
      ⚠ DECLARED ASYMMETRY WITH ITEM 11, per driver note (f): item 11 REFUSES when the design
      window sits on an ancestor of the session's design; item 12 MAPS that case. Closing it
      means changing item 11 — out of scope. Decision 10's PIVOT CHOICE is still NOT claimed
      as behaviourally proven (no raw in the design window ⇒ the two getters are identical);
      what is proven is the level>0 ORIGIN MAPPING (BX48) plus a source guard (BX09).
      Verifier `ok:true`, `scopeClean:true`, and took TWO unnamed sabotages of his own —
      improve-or-restore → unconditional accept (10 fails incl. both BX39 legs) and
      `browser_origin_drop` → always 0 (BX08 ×2 in both arms + BX48's two legs) — both
      reverted; and reproduced substituted sabotage (a) to exactly 3 visibility fails.
      +92 checks (489 X-arm, was 397) and +29 (214 `--nogui`, was 185); the `--nogui` count
      was re-measured independently and matched EXACTLY. `nonBaselineFails` EMPTY in both
      audits. The GUI gate was waited out (one request sat 67 minutes); `GUI_GATE=0` never
      set, no gate file hand-written.
      ⚠⚠ TWO DRIVER ACTIONS BEFORE ITEM 13, neither an item-12 defect. (1) THE TEST FILE NOW
      CROSSES A WSLg XWAYLAND THRESHOLD: at 489 checks `test_wave_sigbrowser` is killed
      mid-run with ZERO `BX` failures — implementer ~5 of 6, verifier 11 of 12 — while the
      SAME file at `b81ee0c9` (397 checks) completed 8/8 in the same window and both of item
      12's halves are 3/3 clean amplified 10-12× standalone. It is the file's CUMULATIVE
      footprint (six toplevels in one process, up from four), and `/mnt/wslg/stderr.log` is
      at 102 marshalling fatals. Re-measure after `wsl --shutdown`, then REVISIT SETTLED
      DECISION 9 ("two test files, not seventeen") — decision 9 is what forces the append, so
      only the driver can fix it, and items 13-15 make it monotonically worse. (2) FLAKY-LIST
      INPUT, three names: `BH54` (item 11's, `winfo ismapped .`, 1-in-4 with item 12 ABSENT —
      this is the un-named ~20% flap `11_receipt.md` §13.4 could not identify), `BT45` (item
      9's sidebar-geometry leg, 2 of the verifier's 9 HEAD runs and 0 of 8 item-11 runs, and
      it runs before any BX code), and `test_prop_form_field_width_0170` (off BOTH lists,
      failed the verifier's audit, cleared 3/3 in isolation).
      NOT PUSHED) -> DONE (35d9e18f)
- [E] 13 — PIXEL — Location bar + last-20 raw history
      (⚠ THE PLAN'S PERSISTENCE PREMISE WAS FALSE AND THE ITEM SAYS SO: "persisted in the
      config the same way other viewer prefs are" names a mechanism that does not exist —
      `grep -n USER_CONF_DIR src/wave_viewer.tcl` is ZERO hits, no wviewer pref is persisted
      anywhere. `recent_files`' shape was SUBSTITUTED (`load_recent_file`/`update_recent_file`/
      `write_recent_file`): the store is its OWN file `$USER_CONF_DIR/raw_history`, Tcl-
      sourceable, newest-first, deduped by `file normalize`, capped at `$::raw_history_max`
      (20, registered in `xschem.tcl` beside the other viewer vars), written through the 0119
      `update_recent_files` gate and read ONCE at startup.
      SHIPPED Tcl-only (decision 8, no `.c`): a `.loc` row above item 4's search bar —
      `ttk::combobox -width 18 -justify right` (Enter and `<<ComboboxSelected>>` reach the
      SAME commit proc), a full-path balloon RE-ATTACHED on every load, and `Browse...`
      reusing `select_raw` (packed `-side right` FIRST, because item 9's `browser_width` sets
      `pack propagate 0` and an over-wide child is CLIPPED, not accommodated). A load also
      runs item 9's D6 `browser_refresh`, so the tree follows the new raw.
      A REAL DEFECT WAS FOUND BY A WORLD-ASSERTING CHECK, driver note (e) verbatim:
      `rawhist_write`'s bare `open`/`close` resolved to this namespace's own
      `wviewer::open {token}` / `wviewer::close {token}`, threw, and was swallowed by its own
      `catch` — NO STORE WAS EVER WRITTEN while every structural check stayed green. Caught
      only by reading the file back off disk.
      ⚠⚠ THE FIRST SHIPPING WAS FULLY GREEN WITH THE HEADLINE LINE DELETED. The adversarial
      verifier deleted `rawbar_sync` from `rawbar_load` (the only call site) and then the
      startup `rawhist_load` — 71/71 both times. The fixup round closed both holes with
      readings of the WORLD: six legs that read the real combobox after a real load (entry
      text, the `<Enter>` balloon script, `-values`), each with a CONTROL leg first (before
      any load the bar is blank and has NO balloon), and `BR19`, which seeds a scratch
      `fakehome/.xschem/raw_history`, `exec`s a `--nogui` CHILD with `HOME` pointed there and
      reads the restored list off its stdout — the only way to observe a read that happens
      before the test script is sourced. Re-run: V3 fires exactly 6, V4 exactly 2 (its
      CONTROL leg green, so the failure localises to the restore). 71/37 -> 85/40 checks.
      P4 FIXED RATHER THAN DECLARED (ruling 17: the honest claim was the existing one, so the
      code was made true): `rawbar_sync` fans the dropdown `-values` out to every other open
      viewer — and ONLY the `-values`; entry text and balloon stay per window because they
      name the raw THAT window shows (declared limit 7; `BR28/BR29` + sabotage V5, which
      fires exactly 1).
      P3 FIXED BY ACTUALLY FILING IT: `doc/claude/issues/0213-read-raw-ascii-point-overruns-
      its-buffer.md` — the first shipping SAID it was filed and it was not. A malformed ASCII
      `Values:` block drives `read_raw_ascii_point` (`save.c:406`, takes `tmp` but not its
      capacity) past its buffer; reproduced independently as both `double free or corruption`
      and SIGSEGV. A Location bar lets a user type ANY path into `xschem raw read`, which
      widens exposure. NO `.c` FILE TOUCHED.
      ⚠ ISSUE 0119 REPRODUCED LIVE by PLAN sabotage (b): with the gate deleted, the ungated
      fixture loads wrote `/home/qflow/.xschem/raw_history` — THE USER'S REAL FILE. It did not
      exist before, a copy was kept in the scratchpad, it was DELETED and verified absent by
      both implementer and verifier. Anyone re-running sabotage (b) writes it again.
      DECLARED LIMITS worth carrying: `attach_raw` (the ASE re-run path) does NOT enter the
      history — arguably the user's commonest raw, offered as a follow-up issue, not hidden;
      `rawbar_load` does not clear the previous raw, so raws ACCUMULATE in
      `xctx->extra_raw_arr` (deliberate — it is what buys failed-read atomicity); the dropdown
      shows NORMALISED ABSOLUTE paths; `Browse...` is modal `tk_getOpenFile` and is never
      exercised headlessly.
      FOR ITEM 14, MEASURED FOR FREE BY THE SCOUT: `xschem raw info` DOES enumerate the extra
      raws (`<i> current`, then one `<i> <path> <type>` line per loaded DB), so item 14's
      `[D]`-if-no-getter risk is GONE. FOR ITEM 15: the PLAN's `wviewer::snapshot`/`restore`
      anchors have drifted ~460 lines, to `wave_viewer.tcl:2628` / `:2675`.
      TEST FILE: `tests/headless/test_wave_sigbrowser_i1315.tcl` (new, prefix `BR`, `BD`
      reserved for item 14 and `BP` for item 15) — the PLAN's "append to
      `test_wave_sigbrowser.tcl`" is SUPERSEDED by ruling 30 / `18c45a16`. ⚠ ITS FOOTPRINT
      CLAIM DOES NOT TRANSFER: item 14 holds two raw DBs open at once and item 15 adds
      destroy/restore cycles — both new axes; re-measure before appending.
      ⚠ FLAKY-LIST INPUT, not fails: `BT45` (item 9's sidebar-geometry leg) — ruling-22 A/B
      says 1-in-6 with the item and 0-in-6 without, and the mechanism is item 9's, not item
      13's (`browser_width` computes the width ONCE at toggle time from whatever toplevel
      width the WM has applied; at `top=400` the 45% cap loses to the 240 floor). The three
      names the verifier could not place — `test_cmdmode_descend_0201`,
      `test_lib_manager_checkin`, `test_hover_highlight` — ALL PASSED in the fixup audit.
      `nonBaselineFails` stands EMPTY for both audits (252/23/0/12 and 253/23/0/11, `X
      connection to :0 broken` = 0 in each, 0 leaked scratch dirs).
      TWO COMMITS, NOT PUSHED) -> DONE-PIXEL (8655fd3b + 76bd7c04)
- [x] 14 — All DBs search -> DONE (a37a620c)
- [x] 15 — persist browser state in snapshot/restore -> DONE (3e526f86). One gated `browser` key on
      the ASE `viewer` dict (sidebar shown/width, BOTH searchbars, plot destination, the
      tree's expanded set + selection, raw-file history); `wviewer::searchbar_set` is the
      missing twin note (f) forced; `browser_width` grew an OPTIONAL `{want {}}` (the clamp
      could NOT be factored out — BT08 greps four literals inside its body and that file is
      FROZEN). Group `BP` in `_i1315.tcl`, 81 checks, file now 166.
      ⚠ THE EMISSION GATE IS LOAD-BEARING OUTSIDE THIS BATCH: `test_wave_modes.tcl:1314`
      MG9 pins `[dict keys $snap]`; sabotage (d) removed the gate and turned BP42 **and**
      MG9 red together. 4/4 sabotages fired EXACTLY their predicted sets ((a) declared a
      superset UP FRONT: BP04/BP43/BP45/BP51, BP44 green).
      FOOTPRINT RE-MEASURED (note (c)): 5 destroy/restore cycles, one viewer at a time, NO
      design window — 6/6 standalone completions (~2.2 s), 12/12 measurable runs, `X
      connection to :0 broken` = 0. Item 15 did NOT need its own file.
      ⚠ DECISION 11's clause is asserted through `browser_target_path` (the value
      `browser_descend_to` computes from `$tv selection`) rather than a real descend, which
      would open the DESIGN WINDOW — the shape every pre-split death landed in. Declared,
      not renamed (ruling 23). Divergences D-A..D-F in `receipts/15_receipt.md`; **D-F (a
      restore emits NO replay lines) and D-E (readout-bar pack order) want a driver word.**
      Full audit: 288 cases, 15 fails, a strict SUBSET of the 16 HARD names, each on its
      recorded check; `nonBaselineFails` EMPTY.
- [x] 16 — docs, guide rows, issue closure -> DONE (24c491cd). Spec
  `doc/claude/specs/waveform_signal_browser.md` (898 lines, 16 sections — the batch's
  durable record); guide §11 "The Signal Browser" (new, `data-bseq` mouse table,
  Troubleshooting 11->12, See also 12->13); issues **0214** (readonly cleared on a failed
  load — the Deferred block's explicit item-16 deliverable), **0215** (items 11/12
  asymmetry), **0216** (`attach_raw` bypasses the raw history); 0186's stale
  "next free is 0212" and its drifted `xschem.tcl:13074` anchor corrected;
  `references/viva_cadence_waveform_viewer.md` §13 item 1 back-pointer.
  **ZERO `data-seq` rows added** — the scope text's "a row per new key/gesture" was a
  no-op (GH0's 16/11 already matched source, and `test_wave_sigbrowser_i12.tcl` BX13
  FORBIDS bumping them). 86 checks added to `test_wave_grid.tcl` (126 -> 212 nogui,
  337 under DISPLAY): GH8/GH9 doc<->`browser_build` both directions, GH10 prose-§ refs,
  GS0-GS3 the spec's contract list vs source + its issue citations. 4 sabotages run.

## Item detail

### Item 0 — PRECONDITION: issues 0186 / 0187

`doc/claude/issues/0186-viewer-context-destroyed-by-reload-and-inplace-loads.md` and
`0187-wviewer-open-context-guard-is-circular.md`.
(The filename above was corrected at implement time: the PLAN as written carried 0172's
title on 0186's number. The parenthetical gloss it used — "viewer context destroyed by
reload and in-place loads" — matched the real file, so this was a typo, not a missing
anchor.)

**Why first:** item 13 persists browser state into the snapshot, and every item from 8
onward adds live widget state to the viewer toplevel. Anything that adds state makes
0186 strictly worse — a reload that destroys the context now also orphans a sidebar.

**Scope:** read both issues. The scout's job is a verdict, not a fix design:
- both already fixed on this branch → `[x]`, note the commit, proceed;
- fixable inside the pipeline's one implement stage → fix it, `[x]`;
- needs real design → `[D]`, and **items 8-15 are automatically deferred with it**
  (items 1-7 and 16 do not touch the toplevel and proceed regardless).

**Files:** `src/wave_viewer.tcl` (`wviewer::open` :624, `wviewer::forget`), the load
path in `src/xschem.tcl`.
**Test:** existing `tests/headless/test_wave_viewer.tcl`.
**Receipt:** `receipts/00_receipt.md`

---

### Item 1 — `wviewer::sig_match` — the shared matcher (pure Tcl, no UI)

The foundation. Every later item calls this; nothing else may re-implement matching.

**Contract** (write it in the proc header comment, verbatim, so a later reader cannot
guess wrong):

```tcl
# wviewer::sig_match  siglist  pattern  ?opts?
#   -syntax   shell|regexp    default shell
#   -case     0|1             default 0  (0 = case-INsensitive, ViVA default)
#   -type     all|v|i|other   default all
#   -sort     0|1|-1          0 = raw order (default), 1 = -increasing, -1 = -decreasing
# Returns: {ok  {matched names...}}   on success
#          {err {message}}            on an invalid regexp
# Matching is WHOLE-NAME anchored. shell -> `string match`; regexp -> `^(?:$pat)$`.
# The subject is the FULL raw name (`v(out)`), never the stripped form.
# An empty pattern matches everything (that is a cleared box, not a typo).
```

Plus `wviewer::sig_type {name}` → `v` | `i` | `other`, classifying on a leading
`v(` / `i(` (case-insensitively), and used by `-type`.

**Files:** `src/wave_viewer.tcl`, new procs near the other pure helpers (NOT inside
any dialog proc).
**Test:** create `tests/headless/test_wave_sigsearch.tcl`. Cover at minimum:
shell `l*` matches `l...` and NOT `xl...`; regexp `l*` matches **everything** (the
documented ViVA trap — assert it, it is not a bug); regexp `l.*` matches `l...` only;
`net[0-9]` range; literal-bracket escape `*net_name[[]*`; `?` single-char;
case-insensitive default vs `-case 1`; `-type v` excludes `i(...)`; empty pattern =
all; invalid regexp `[` returns `{err ...}` and **not** the whole list.
**Sabotages (3):** (a) drop the `^(?:...)$` anchoring → the regexp-anchoring check
fails and nothing else; (b) flip the `-case` default to 1 → the case check fails;
(c) restore the legacy `if {$err} {set pattern {}}` → the invalid-regexp check fails.
**Done:** all checks green, 3 sabotages fire on exactly their targets.
**Receipt:** `receipts/01_receipt.md`

---

### Item 2 — `wviewer::signal_list` — typed signal inventory

One accessor every consumer uses instead of open-coding `split [xschem raw list] "\n"`
(currently done at `wave_viewer.tcl:7190`).

**Contract:** `wviewer::signal_list {token}` → list of dicts
`{name <full raw name> type <v|i|other> leaf <last dot-segment> path <all but last>}`,
where `leaf`/`path` split the **UNWRAPPED** name per settled decision 14 (`v(x1.x2.net5)`
→ path `x1.x2`, leaf `net5`), while `name` stays the full raw name.
Returns `{}` when no raw is loaded (the `catch {xschem raw list}` arm at `:7187` — keep
that behaviour, it is what produces the *"no raw data loaded"* note). Must switch to the
viewer's `win_path` context first and **verify the switch followed** — landmine 17, the
rule this file states at `wviewer::open` and has been burned by before.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigsearch.tcl`. Load a fixture raw, assert count, assert
a known `v(...)` classifies `v`, an `i(...)` classifies `i`, a dotted hierarchical name
splits into `path`/`leaf`, and that a token with no raw returns `{}` without throwing.
**Sabotages (2):** (a) delete the context-switch verify → the wrong-context check fails;
(b) make the no-raw arm throw instead of returning `{}` → the no-raw check fails.
**Receipt:** `receipts/02_receipt.md`

---

### Item 3 — retrofit the legacy dialog onto the shared matcher

`graph_get_signal_list` (`src/xschem.tcl:4469`) is the only search box that exists
today, and it silently turns a bad regexp into match-all.

**Scope:** reimplement its body as a call to `wviewer::sig_match` with
`-syntax regexp -case 1 -sort $graph_sort`, then apply the legacy display strip
(`regsub {^v\((.*)\)$}`) to the RESULT. **On-screen behaviour must not change** except
that an invalid pattern now yields an empty list rather than the whole list. Keep the
`graph_sort` global and its `-increasing`/`-decreasing` mapping exactly.

⚠ `src/xschem.tcl` may not depend on `wave_viewer.tcl` having been sourced. Scout must
confirm load order; if the dependency is wrong, move `sig_match` to a shared file and
say so in the receipt.

**Files:** `src/xschem.tcl`.
**Test:** append to `test_wave_sigsearch.tcl` — call `graph_get_signal_list` directly
with a known list: sort order both ways, the `v()` strip still happens in the output,
and a bad regexp returns `{}` not everything.
**Sabotage (1):** revert the strip → the display check fails.
**Receipt:** `receipts/03_receipt.md`

---

### Item 4 — **PIXEL** — `wviewer::searchbar` reusable widget

The ViVA Search toolbar as a self-contained megawidget with no consumer yet.

**Contract:** `wviewer::searchbar_build {parent args}` → the frame path.
`-command <cb>` is called as `<cb> <pattern> <syntax> <case> <type>` on every live
keystroke and on the Search button. `-showbutton 0` hides the button (the Filter bar
variant). `wviewer::searchbar_get {w}` → the same four values as a dict, for snapshot.

**Widgets, in ViVA's order** (§3.2): type dropdown (`All / Voltage / Current / Other`)
→ pattern entry → syntax dropdown (`Shell / RegExp`) → `Match case` checkbutton →
`Search` button. Defaults: type `All`, syntax `Shell`, case OFF. Plus an error label
that shows `sig_match`'s `err` message and clears on the next valid keystroke.

Theme through `ase::ui::apply_theme`, fonts `AseLabelFont` / `AseEntryFont`, error
label foreground `[ase::theme accent]` — the same treatment `add_trace_dialog` gives
`$w.err` at `:7198`.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigsearch.tcl` — build it on a throwaway toplevel,
assert every child exists and its default value, assert the callback fires with the
right four args on a simulated keystroke, assert the error label populates on `[`.
**Sabotage (1):** change the syntax dropdown default to RegExp → the default check fails.
**Eyeball:** widget order, spacing, that the error label does not resize the bar.
**Receipt:** `receipts/04_receipt.md`

---

### Item 5 — **PIXEL** — searchbar into `add_trace_dialog`

**Scope:** insert a searchbar above `$w.vars` in `add_trace_dialog`
(`wave_viewer.tcl:7152`), filtering the listbox through `wviewer::sig_match` over
`wviewer::signal_list`. Set `$w.vars -selectmode extended`.

⚠ **Do not redesign the dialog.** It already has, and must keep: the Graph combobox
(`:7160`, hidden when `< 2` graphs), the Expression row (`:7172`), the
`Name (optional):` row (`:7173`), and the `$w.err` label (`:7183`). The searchbar's own
error label is separate from `$w.err`; `$w.err` stays the RPN/no-raw channel. Grid rows
shift — renumber every `grid` call, do not leave a hole.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigsearch.tcl` — open the dialog headless, type a
pattern, assert the listbox contents shrink to the matching set and grow back when
cleared; assert the Graph combobox / Name entry / err label still exist and still work
(a regression guard for the "do not redesign" clause).
**Sabotages (2):** (a) make the filter reset the selection → the
selection-survives-filter check fails; (b) delete the Name row → the regression guard
fails.
**Eyeball:** the dialog is not taller than the screen; the bar does not steal focus
from the Expression entry (`focus $ee` at `:7200` must still win).
**Receipt:** `receipts/05_receipt.md`

---

### Item 6 — multi-select plot from Add Trace

**Scope:** `add_trace_ok` (`:7217`) currently reads one selection
(`lindex $sel 0` at `:7226`). Make the empty-expression path add **one trace per
selected row**, in listbox order, each through the existing
`wviewer::add_trace $token $gi $rpn $name`. Rules: a non-empty Expression entry still
wins and still adds exactly one trace (the RPN path is unchanged); the `Name` field
applies only when exactly one row is selected (N traces cannot share one name — with
N > 1 and a name typed, show that in `$w.err` and add nothing); the first error from
any trace aborts the rest and reports, leaving the already-added ones in place.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigsearch.tcl` — select 3, OK, assert 3 traces; assert
the RPN path still adds 1; assert name+multi is refused with a message and adds nothing.
**Sabotages (2):** (a) keep `lindex $sel 0` → the 3-trace check fails; (b) drop the
name+multi refusal → that check fails.
**Receipt:** `receipts/06_receipt.md`

---

### Item 7 — **PIXEL** — plot-destination dropdown

ViVA's `Append / Replace / NewSubWin / NewWin`, mapped to xschem's model.

**Mapping** (decided): `Append` → current behaviour, land per `plan_plot`
(`wave_viewer.tcl:1491`); `Replace` → clear the target graph's traces first, then add;
`New Strip` → force a fresh graph regardless of plot mode; `New Tab` → open a new
viewer tab and land there. `plan_plot` is already the pure landing *policy* — extend
it, do not fork it. Default `Append`, persisted per window.

⚠ ViVA's `Append` has a unit-collision rule (*different unit → new Y axis; four Y axes
already → new subwindow instead*). xschem has **no unit metadata at all** —
`save.c read_dataset` discards ngspice's per-var type. Do not attempt it. Record the
divergence in the receipt.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigsearch.tcl` — one check per policy asserting the
resulting graph/trace counts.
**Sabotages (2):** (a) make Replace behave as Append → the Replace check fails;
(b) make New Strip respect plot mode → the New Strip check fails.
**Eyeball:** dropdown placement; New Tab actually raises the new tab.
**Receipt:** `receipts/07_receipt.md`

---

### Item 8 — **PIXEL** — browser sidebar shell (empty)

*Depends on item 0. If item 0 is `[D]`, this and everything after it defer with it.*

**Scope:** `$top.wvbrowser` frame, `pack ... -side left -fill y -before $top.drw`.
A `View > Signal Browser` menu checkbutton mirroring a per-token variable, plus a
bindtag key on `WaveViewer` (pick an unused one — **run the written three-path
collision check** that `wave_viewer.tcl` documents per key, and record the three paths
checked in the receipt). Show/hide follows the `readout_show` (`:6563`) pattern
exactly: pack/unpack against the mirror, `catch {pack forget}`, `pack ... -before`.
Content: a placeholder label only.

**Files:** `src/wave_viewer.tcl`.
**Test:** create `tests/headless/test_wave_sigbrowser.tcl` — toggle on/off, assert
`pack info` presence/absence, assert the canvas `$top.drw` survives both, assert the
menu checkbutton and the key agree.
**Sabotages (2):** (a) drop `-before $top.drw` → a geometry check fails (assert the
canvas keeps non-zero width); (b) desync the menu variable from the key → the agree
check fails.

⚠⚠ **ITEM 9 WENT ONE LEVEL DEEPER, and this is the generalised rule (ruling 26b):**
item 8's `bs_order` is CORRECT for sidebar-vs-canvas, and the PLAN then aimed the same
oracle at the sidebar's OWN slave order — where **it would have FAILED ON CORRECT CODE.**
`pack slaves` reports PACKING order, which for a mixed `-side top` / `-side bottom` stack
is NOT visual order: `.ph` and `.wvfilter` are packed BEFORE `.tvf` precisely so the tree,
packed last with `-expand 1`, takes what is left between them. So the sequence is:
**an oracle can be blind (item 8), and an oracle can be actively WRONG on correct code
(item 9). Verify what a named oracle MEASURES, not merely that it can see the thing.**
Item 9 widened rather than weakened: its check asserts the whole `pack slaves` list, each
`-side`, and the tree's `-expand`.

⚠ **CORRECTION, MEASURED BY ITEM 8: sabotage (a)'s named oracle is BLIND.** Dropping
`-before $top.drw` left BOTH the canvas-width and sidebar-width checks GREEN. Widths are
not the observable. `pack info` **does not report `-before` at all**, so the only thing
that can see it is the parent's **slave ORDER**. Item 8 pins it with `bs_order top a b`
returning an assertable string (`a-before-b` / `a-after-b` / `a-missing` / `b-missing` /
`no-top`), at three levels — source, fixture, live viewer. **Item 9 and any later item
doing geometry: do not assert widths and believe you have pinned packing order.**
**Eyeball:** the canvas does not jump or repaint wrong on toggle (WSLg repaint is a
known trap here); sidebar width is sane and the divider is draggable if one is added.
**Receipt:** `receipts/08_receipt.md`

---

### Item 9 — **PIXEL** — browser content: tree + search + filter

**Scope:** fill the sidebar. `ttk::treeview` over `wviewer::signal_list`, grouped by
the `path` field (dot-separated hierarchy) with leaves as rows; flat when no signal has
a path. A `searchbar_build` at the top (with the Search button) and a second
`searchbar_build ... -showbutton 0` at the bottom as ViVA's **Filter** bar — both feed
`sig_match`, ANDed. `-selectmode extended`. Plot gestures, all three, per §3.4:
**double-click**, **middle-click**, and a **Plot** toolbar button — each honouring
item 7's destination dropdown.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigbrowser.tcl` — assert tree population from a fixture
raw, assert grouping for a hierarchical name, assert each of the three plot gestures
adds a trace, assert search and filter AND together.
**Sabotages (3):** (a) break the AND so filter is ignored → that check fails;
(b) remove the MMB binding → the MMB check fails; (c) flatten the grouping → the
hierarchy check fails.
**Eyeball:** tree indentation, column width, that a 2000-signal raw is not
unusably slow to populate.
**Receipt:** `receipts/09_receipt.md`

---

### Item 10 — **PIXEL** — RMB context menu on a browser row

**Scope:** Plot (per destination), Plot to → `Append / Replace / New Strip / New Tab`
(a one-shot override of the dropdown), `Send to Add Trace…` (opens
`add_trace_dialog` with the name prefilled into the Expression entry), `Copy name`.

Reserve a **`Descend to here`** entry, greyed/disabled, at the bottom of the menu.
Item 11 fills it in. Reserving it now means item 11 does not have to re-touch the menu
construction and risk the 0178 swallow.
Follow the Tcl-only Button3 swallow that issue 0178 established for the legend
(`wave_viewer.tcl:7680`) — the canvas RMB must not also fire.

⚠⚠ **CORRECTION, MEASURED BY ITEM 10: THIS PREMISE IS WRONG.** 0178's swallow does NOT
transfer to a `ttk::treeview`. Re-measured three ways: ttk's Treeview class binds no
`<Button-3>`; `bind all <Button-3>` is empty; and the CANVAS is not in the tree's
bindtags. The swallow the PLAN cites is really `btn3_filter` — a **canvas-level** filter,
structurally inapplicable to a sidebar widget. Consequence: the PLAN's sabotage (1)
("drop the swallow") fires ONE source check and **NO behavioural check**, so it cannot
carry the negative claim. Item 10 kept the `break` as defence in depth, named its source
check to say only that, and carried the real negative claim with a structural check plus
a real-gesture check whose canvas-recorder must read ZERO. **Item 11's stated rationale
for the reserved menu entry ("so item 11 need not risk the 0178 swallow") is therefore
void as written — the reservation is still useful, but not for that reason.**

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigbrowser.tcl` — assert menu entry labels, assert each
entry's effect, assert the RMB does not reach the canvas.
**Sabotage (1):** drop the swallow → the canvas-must-not-see-it check fails.
**Eyeball:** menu posts at the pointer, entries not greyed wrongly on an empty selection.
**Receipt:** `receipts/10_receipt.md`

---

### Item 11 — hierarchy sync: browser -> schematic ("Descend to here")

The user descends the browser tree to `x1.x2`, invokes the command, and the ASE-L
session's **schematic** window is at that same point in the hierarchy — opened, raised
and activated if it was not already.

**All primitives exist. No C.**

- `xschem descend -inst <name>` (`src/scheduler.c:2811`) — name-addressed descend:
  `get_instance(name)`, `unselect_all`, `select_element`, `descend_schematic`. Returns
  non-zero on success; errors with *"instance not found"*. This is the coordinate-free
  replay form the action log already emits, so a sync is replayable for free.
- `xschem get sim_sch_path` (`src/scheduler.c:4567`) — the current hierarchy path
  **relative to the level where the raw was loaded**, i.e. the same origin the raw
  signal names use. This is the pivot for BOTH directions. Do not use
  `xschem get sch_path`, which is absolute and includes levels above the sim root.
- `xschem go_back` — ascend one level.
- `raise_activate_toplevel` — the WSLg raise idiom (issue 0054: a bare
  `deiconify`/`raise` is a no-op there).

**Algorithm** (write it in the proc header so nobody re-derives it wrong):

1. Target = the tree node's dotted instance path, sim-root-relative, e.g. `x1.x2`.
2. Resolve the ASE-L session's design window from the token; if it is gone, open it;
   then `raise_activate_toplevel` + `focus`.
3. **Verify the context followed** before touching hierarchy state — landmine 17, the
   rule `wviewer::open` documents and this file has been burned by. A switch under a
   raised semaphore silently no-ops roughly 3 times in 10.
4. Read `xschem get sim_sch_path`. Compute the common prefix with the target.
5. `xschem go_back` once per level of current-beyond-common-prefix.
6. `xschem descend -inst <seg>` once per remaining target segment.
7. Redraw / `xschem zoom_full` per the existing descend convention.

**The traps, all of which must be handled and tested:**

- **Case.** ngspice lowercases: the raw carries `x1.x2`, the schematic instance is
  `X1`. `get_instance()` is case-sensitive. The scout must establish the real
  behaviour from source and the matcher must be case-insensitive **with the
  case-sensitive attempt tried first** (an exact hit always wins, so a design that
  genuinely has both `x1` and `X1` still resolves correctly).
- **Partial failure must roll back.** If segment 3 of 4 does not resolve, `go_back` the
  levels already descended and report — never strand the user halfway down a hierarchy
  they did not ask for. This is the single most important behaviour in the item.
- **Vector instances.** `descend -inst` picks the instance; the slice is separate
  (`xschem change_sch_path n`, `scheduler.c:2341`; the slice reached is readable as
  `xschem get sch_inst_number`). If the target path segment carries a slice index,
  either apply it via `change_sch_path` or verdict `[D]` for vectors specifically and
  handle scalars only — say which, in the receipt, and open an issue for the other.
- **Unsaved changes / read-only.** Descend goes through the normal path; do not
  bypass any existing guard. If a guard refuses, report it in the status bar and roll
  back what was already descended.
- **Already there** = a no-op that still raises the window, and says so.

**Entry points:** an entry in item 10's browser RMB menu ("Descend to here"), a
`View` (or `Hierarchy`) menu item, and a `WaveViewer` bindtag key — run the written
three-path collision check and record the three paths in the receipt.

**Files:** `src/wave_viewer.tcl`; possibly `src/ase_window.tcl` for the design-window
handle (read-only use of the session state — do not restructure it).
**Test:** append to `tests/headless/test_wave_sigbrowser.tcl` against a 2-3 level
fixture: descend 2 levels and assert `sim_sch_path`; a sibling-to-sibling sync
(requires an ascend then a descend, not just a descend); a bad segment leaves
`sim_sch_path` **exactly as it started** (the rollback check); already-at-target is a
no-op; case-mismatched path still resolves.
**Sabotages (3):** (a) remove the rollback → the bad-segment check fails and the tree
is left descended; (b) use `sch_path` instead of `sim_sch_path` → the sync lands one or
more levels off and the 2-level check fails; (c) drop the case-insensitive retry → the
case check fails.

⚠⚠ **MEASURED BY ITEM 11 — DECISION 10 IS TRUE, AND FIVE THINGS ABOVE WERE WRONG.**
The `sim_sch_path` claim finally has evidence (currsch 2, `sch_path` fixed at `.X1.X2.`:
raw_level 0 → `X1.X2.`, 1 → `X2.`, 2 → ``). **But the corollary bites: with NO raw loaded
the two getters are BYTE-IDENTICAL** (`sch_waves_loaded()` is -1 so the C skip loop never
runs), so **sabotage (b) as written fires NOTHING** — it needs a `xschem raw new` +
`raw_level 1` arm to have any teeth. The other four defects: `sim_sch_path` carries a
TRAILING DOT and is EMPTY at the sim root, which the algorithm above compares straight
against a dotted browser path having neither; exact-first + case-insensitive retry is
necessary **but not sufficient** — the FINAL VERIFY must also be `-nocase`, or a correct
walk of `x1.x2` lands on the schematic's `x1.X2` and is rejected by its own verify;
`descend -inst` returns the STRING `0` **without throwing** for a non-subcircuit or a
raised semaphore, and `go_back` returns void and does not ascend on a cancelled save
prompt — so every step must be confirmed by READBACK, never by `catch`; and **the PLAN's
own rollback check was VACUOUS** (a 1-segment shared prefix means the plan is a single
descend that never happens, so "unmoved" is true with or without the rollback).
**Receipt:** `receipts/11_receipt.md`

---

### Item 12 — hierarchy sync: schematic -> browser ("Show in Signal Browser")

The mirror. From the schematic at `x1.x2`, one command opens/raises the viewer, expands
the browser tree to that node, selects it, and scrolls it into view.

**Direction-specific pieces:**

- Source of truth is again `xschem get sim_sch_path`, read in the **schematic's**
  context. Verify the context is the one you think it is before reading it.
- `wviewer::open $token` is already raise-or-open and returns 0 for an unknown token —
  reuse it, do not write a second opener.
- If the browser sidebar is hidden, show it (item 8's mirror) as part of the command.
- If the tree has no node for that path — the usual cause is that the raw simply has no
  signals under that instance — **say so in the status bar and select the deepest
  ancestor that does exist.** Silently doing nothing is the failure mode to avoid.
- If no raw is loaded at all, report that and stop.

**Entry points:** a schematic-side menu item, plus a key. Both must work while the
schematic is descended and while it is at the top. Consider the precedent in
`ase-direct-plot-hierarchy-0168` (a descended Direct Plot resolves against the
ancestor that owns the raw) — this item resolves against the same origin, and the
scout should confirm the two agree rather than assume it.

**Files:** `src/wave_viewer.tcl`, `src/ase_window.tcl` (menu/key on the design window),
`src/cadence_style_rc` if the key is bound there.
**Test:** append to `tests/headless/test_wave_sigbrowser.tcl` — descend the schematic
2 levels, invoke, assert the tree selection is the matching node and that it is
visible (its ancestors are expanded); assert the deepest-ancestor fallback for a path
with no signals; assert a clear report when no raw is loaded; assert the sidebar
un-hides.
**Sabotages (3):** (a) select the node without expanding ancestors → the visible check
fails; (b) remove the deepest-ancestor fallback → that check fails; (c) skip the
sidebar un-hide → that check fails.
**Receipt:** `receipts/12_receipt.md`

---

### Item 13 — **PIXEL** — Location bar + last-20 raw history

**Scope:** ViVA's Location field (§3.1). An editable path entry at the top of the
sidebar, Enter commits and loads that raw; a dropdown of the last 20 raw files opened,
newest first, deduped, persisted in the config the same way other viewer prefs are.
Replaces nothing — `select_raw` (`xschem.tcl:14209`, a bare `tk_getOpenFile`) stays as
the Browse… button beside it.

⚠ **Do not pollute Open Recent.** Issue 0119 is exactly this class of bug: a
`--script` verification run re-polluted the recent-files list. The raw history is its
own store, and headless/`--script` loads must not write to it.

**Files:** `src/wave_viewer.tcl`, config var registration in `src/xschem.tcl`.
**Test:** append to `test_wave_sigbrowser.tcl` — assert history grows, dedups, caps at
20, newest-first; assert a `--script` load does NOT append.
**Sabotages (2):** (a) remove the dedup → that check fails; (b) let the headless load
append → the 0119 guard fails.
**Eyeball:** long paths do not blow out the sidebar width (ViVA right-justifies with a
tooltip — do that).
**Receipt:** `receipts/13_receipt.md`

---

### Item 14 — All DBs search

**Scope:** the `All DBs` checkbox from §3.2, searching every open results database, not
just the current one. xschem's equivalent registry is `xctx->extra_raw_arr[]`
(`src/save.c`, reachable from `scheduler.c:9517`'s `raw`/`raw_query` branch). Scout
must first establish **from source** what the Tcl-visible enumeration of extra raws is;
if there is no getter, this is a `[D]` (decision 8 — no new C in this batch).
Matched rows from a non-current DB are labelled with their source in the tree.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigbrowser.tcl` — two raws loaded, assert All-DBs finds
a signal that exists only in the second and labels its source; assert it is excluded
when the box is off.
**Sabotage (1):** ignore the checkbox → the excluded-when-off check fails.
**Receipt:** `receipts/14_receipt.md`

---

### Item 15 — persist browser state in snapshot/restore

*Depends on item 0 being `[x]`.*

**Scope:** `wviewer::snapshot` (`wave_viewer.tcl:2165`) / `restore` (`:2212`) carry:
sidebar visible?, sidebar width, search pattern/syntax/case/type, filter
pattern/syntax/case/type, destination policy, raw-file history, **the browser tree's
expanded-node set and current selection** (so a restore lands where the user left it —
and so item 12's sync survives a session round-trip). Follow the existing
deliberate exclusions — undo/redo history, wave highlights and the per-tab `view` range
cache are excluded on purpose; do not "fix" that here.

**Files:** `src/wave_viewer.tcl`.
**Test:** append to `test_wave_sigbrowser.tcl` — snapshot → destroy → restore, assert
every field round-trips; assert a snapshot taken with the sidebar hidden restores hidden.
**Sabotages (2):** (a) drop one field from the snapshot → its round-trip check fails;
(b) restore the sidebar always-visible → the hidden check fails.
**Receipt:** `receipts/15_receipt.md`

---

### Item 16 — docs, guide rows, issue closure

**Scope:**
- New spec `doc/claude/specs/waveform_signal_browser.md`: the settled decisions above,
  the divergences from ViVA and **why** (anchoring, error-not-match-all, live+button,
  full-name subject, no unit rule), and the widget contracts.
- The spec must carry a **hierarchy-sync section**: the `sim_sch_path` pivot and why
  `sch_path` is wrong, the descend/ascend algorithm, the rollback rule, the case-folding
  rule, and whatever items 11/12 concluded about vector instances. This is an
  xschem-only feature — ViVA has no documented equivalent of "put the schematic where
  the browser is" — so there is no upstream doc to fall back on and this spec is the
  only record.
- `doc/waveform_viewer_guide.html`: a `data-seq` row per new key/gesture. Note
  `test_wave_grid.tcl` GH1/GH2/GH5 assert those rows — extend the assertion, don't
  break it.
- Open a numbered issue under `doc/claude/issues/` for each `[D]` this batch produced.
- Add a `references/viva_cadence_waveform_viewer.md` §13-item-1 back-pointer to the
  new spec.

**Files:** docs only.
**Test:** `tests/headless/test_wave_grid.tcl` still green with the extended row set.
**Sabotage (1):** remove one new `data-seq` row → the guide check fails.
**Receipt:** `receipts/16_receipt.md`

---

## Eyeball queue

Items verdicted `[E]` land here with their commit hash. Batch them into one review
session at the end; the driver does not block on them.

| Item | Commit | What to look at | Eyeballed? |
|------|--------|-----------------|------------|
| 4 | `43bf6d94` + `9c1bfa60` | widget order, spacing, that the error label does not resize the bar. *(Build on a throwaway toplevel — `pack $w -fill x` is REQUIRED; see `receipts/04_receipt.md` appendix §9 for the five-point note, incl. `#8b0000`-on-`#f2f2f2` legibility and the 24-char clip budget.)* |  |
| 5 | `3c7c993f` | the dialog is not taller than the screen; the bar does not steal focus from the Expression entry (`focus $ee` at `:7200` must still win). *(Open **Graph > Add Trace…** on a real viewer with a raw loaded. The plan's `:7200` has drifted to `:7719` — it is the last statement before `return $w`. **WIDTH is the risk the plan does not name**: the bar becomes the dialog's minimum width, and the Search button is its widest child (D15 — dropping it is a decision-5 RULING, not a fix). See `receipts/05_receipt.md` §7 for the six-point note and §10.4 for what AT18 does NOT pin: the visible caret, WM focus arrival, end-to-end X key delivery. Expect a possible SLOW MAP — 3 of 25 opens took up to 3.5 s on an idle machine; environmental, not item 5's.)* |  |
| 7 | `876e8f0f` + `e5d3a8f7` | dropdown placement; New Tab actually raises the new tab. *(Open **Graph > Add Trace…** on a real viewer with a raw loaded. `Destination:` is row 0 and every other row moved down one, so read the label column: with TWO graphs it should scan as `Destination / Graph / Expression / Name`; with ONE graph `Graph:` is created but never gridded, so `Destination:` sits directly above `Expression:` — check both. It is a ROW, not a column: the grid is 3 columns wide and column 2 holds only the listbox scrollbar. **New Tab is also the FIRST time the tab bar packs** (`tabbar_refresh` packs at >= 2 tabs), so watch for a canvas jump or a stale WSLg repaint. Third item: the New Tab ERROR path is CIW-only **by construction** — `dest_prepare` has already destroyed the dialog, so a bad expression under New Tab reports through `wviewer::echo`; confirm the user actually notices. Declared policy, not a defect: in **multi-plot** mode `Replace` behaves as `Append` (D-n) — whether the dropdown should say so is item 9's call. See `receipts/07_receipt.md` §5 for the three-point note, §9.8 for why the fixup did not change it, and §10.)* |  |
| 8 | `f3c89935` | the canvas does not jump or repaint wrong on toggle (WSLg repaint is a known trap here); sidebar width is sane and the divider is draggable if one is added. *(Open a real viewer with a raw loaded and toggle **View > Signal Browser**, then the same again with **Ctrl-L**. **"The divider is draggable" is NOT APPLICABLE** — item 8's content is a placeholder label only and NO divider/sash was added; do not read its absence as a defect. What the implementer already measured, so look for what it does NOT cover: at 1000x620 the toplevel width never moves, the canvas gives up exactly the sidebar's 166 px (1000 → 834) and takes them back, and hidden → shown → hidden is BYTE-IDENTICAL (md5 `45606cf3…`) — i.e. three still frames at ONE size on ONE machine. **The untested sizes are the point**: try a NARROW window (that is where a dropped `-before` would squeeze the sidebar, and where the width oracle the plan named is blind), and watch the intermediate frames, not just the settled ones. The 166 px comes purely from the placeholder label's `-width 22` — no `pack propagate 0`, no hard-coded pixels. Two layout facts recorded so they do not read as regressions: the status bar spans the FULL width so the sidebar stops at it, and `readout_show` packs the readout bar `-before $top.drw` ON DEMAND, so enabling cursors before vs. after showing the sidebar gives that bar a different width (item 15's to settle). See `receipts/08_receipt.md` §6 and appendix §7 — including the harness bug that produced a BLACK first frame and nearly became a false repaint finding.)* |  |
| 9 | `46f89349` | tree indentation, column width, that a 2000-signal raw is not unusably slow to populate. *(**The third clause is already DISCHARGED as evidence** — BT17 builds 2220 rows from 2000 signals in 14-20 ms and BT33 does the whole real refresh, both bar reads + the chained AND + 2220 real ttk inserts, in 15-16 ms; printed and asserted in-suite and independently reproduced by the verifier. Do not spend the session re-timing it. Indentation is also structurally pinned (`$tv parent s:v(x1.x2.net5)` is `g:x1.x2`, whose parent is `g:x1`, BT24/BT42 on a real raw; groups insert `-open 1`) and `#0` is 200 px `-minwidth 80 -stretch 1`. **What is left is judgement, and it is the WIDTH**: open a viewer with a real raw and press **Ctrl-L**. The sidebar is **583 px — 42 % of a 1400 px window** — and it is that wide BECAUSE settled decision 5 keeps the Search button visible against item 4's 755 px bar; under the 45 % cap by design, not by accident. Whether that reads as "a sane sidebar" is the one thing no check can say. Then look at the cases the checks do NOT reach: a **NARROW window**, where the cap binds and BOTH bars clip further and the status-line error mirror is all that keeps decision 4 alive (declared limit D1 — at 583 px the error label is ALREADY clipped, `ismapped 0` at x=577); **repaint on toggle and on tree scroll** (item 8's known WSLg trap, now with a subtree that changes size — the viewer toplevel's unguarded `<Visibility> -> raise_dialog` fires for browser churn too); and the **theme** — `ase::ui::apply_theme` is applied to the whole sidebar and its `Treeview` arm already existed, but nobody has looked at the result against the ASE palette. Two behaviours to recognise rather than report as defects: a double-click on a GROUP does not plot (ttk owns that gesture — MMB and the Plot button do, D3), and plotting a group plots in RAW-FILE order even though the tree DRAWS same-group leaves adjacent (D7). See `receipts/09_receipt.md` §7 for the three-part looked-at / measured / owed split and §8 for all eight declared limits.)* |  |
| 10 | `809cb979` | menu posts at the pointer, entries not greyed wrongly on an empty selection. *(Open a viewer with a real raw, **Ctrl-L**, then RMB a row. **The PLAN's "empty selection" clause is answered by CONSTRUCTION, so read it as a different question**: an RMB on a row that is NOT selected targets THAT row without mutating the selection (BM28), and an RMB on **blank tree space below the last row posts NOTHING AT ALL** — no menu of dead entries (BM21, and the `absent` oracle value exists to say so). What is left for the eye is FIVE things, none of them claimable from the suite: (1) the menu posts **at the pointer in ROOT coordinates** — not at the window corner, not at the tree's origin (BM22 pins the derivation rule at the seam; whether the pointer is where the user thinks it is, is pixels); (2) on a row **nothing is greyed except the disabled header and item 11's reserved `Descend to here`** — anything else greyed is a defect; (3) the labels **read sanely at the sidebar's measured 583 px** — `Plot (Append)` and, under multi-plot, `Plot to > Replace -> appends` (a DELIBERATE surfacing of item 9's D2 limit, not a typo, and it comes from the same `dest_menu_label` as the top entry so the two cannot drift); (4) the **cascade opens without running off the toplevel** — it is added UNCONDITIONALLY so entry INDICES are a fixed table, which means an empty submenu is possible in principle; (5) the **submenu carries the ASE palette** — it is a separate widget, `ctx_menu_child` re-applies the theme, but only an eyeball can say it matches its parent. Two behaviours to RECOGNISE rather than report: an RMB on a **GROUP** row posts and plots its leaves (unlike the double-click, which yields to ttk — D3 does not apply to Button-3), and a multi-row target acts in **RAW-FILE order**, not the tree's visual order (D7). ASCII `->` / `...` in the two new labels is recorded, not accidental. See `receipts/10_receipt.md` §10 for the owed list, §2 for why the PLAN's swallow premise does not hold here, and §7 for the `clipboard` defect the tests caught.)* |  |
| 13 | `8655fd3b` + `76bd7c04` | long paths do not blow out the sidebar width (ViVA right-justifies with a tooltip — do that). *(Open a viewer with a real raw and press **Ctrl-L**; the Location row is the top row of the sidebar. **Everything the code does about width is MECHANISM, not an observed result** — the combobox is `-width 18` so its `reqwidth` cannot grow with the text, `-justify right` so the TAIL (the file name) is what survives, the full path lives in a balloon **re-attached on every load**, and `Browse...` is packed `-side right` FIRST because item 9's `browser_width` sets `pack propagate 0`, so an over-wide child is CLIPPED, not accommodated. Five steps: (1) type a **very long** path in and commit — the sidebar must not widen and the tail must be what shows; (2) hover — the balloon must carry the FULL path; (3) confirm **`Browse...` is still fully visible** at item 9's measured 583 px and has not been clipped off the right edge; (4) drop the dropdown open and confirm the entries read sanely at that width — they are **normalised ABSOLUTE paths** (declared limit 6, that is what makes the dedup real), so a 20-deep history is 20 long strings; (5) load a second raw from the bar and confirm the tree **visibly changes** to the new raw's signals (item 9's D6 refresh — sabotage (d) shows the failure mode is a STALE tree, A's signals under B's waveforms, not an empty one). Four things to RECOGNISE rather than report: raws loaded by an **ASE re-run** (`attach_raw`) never appear in the dropdown at all (declared limit 1, a follow-up issue is offered); a load in one viewer refreshes **every** viewer's dropdown but only the loading viewer's Location text and balloon (limit 7, deliberate); a **bad path is REFUSED and the bar keeps naming the raw that IS loaded** (BR46); and the sidebar falls back to a 240 px floor whenever the WM has not yet applied the toplevel width, which is §10.1's `BT45` mechanism and item 9's to fix, not a new defect. **Do NOT type a path to a malformed ASCII raw** — issue `0213` (unterminated `Values:` block → `read_raw_ascii_point` overruns its buffer → SIGSEGV or `double free`) is exactly what a free-text path box widens exposure to; it is C, so it was filed, not fixed. See `receipts/13_receipt.md` §9 for the owed list, §8 for all seven declared limits, and §12 for the two coverage holes an adversarial verifier found in the first shipping.)* |  |

---

## Deferred / failed

Appended by the pipeline's ledger stage with the full reason. Do not summarise —
a `[D]` reason is the input to the next batch.

### Item 0 — issue 0186 `[D]` (0187 in the same item was FIXED)

`doc/claude/issues/0186-viewer-context-destroyed-by-reload-and-inplace-loads.md` was
re-measured at `ccd5f30a` on 2026-08-03 and still reproduces verbatim
(`before wv=1 ro=1 rects2=1` → `after wv=1 ro=0 rects2=0`). Two independent reasons it
is deferred rather than fixed:

1. **It needs C.** The two families of site are `src/scheduler.c:10036` (the `reload`
   branch, whose body `unselect_all(1); remove_symbols(); load_schematic(...)` has no
   guard) and the routing-exempt in-place loads (`scheduler.c` / `src/save.c:3734`,
   `:3810`, `:3814`, `:3827`). Batch **decision 8** forbids new C in items 1-15.
   `src/xschem.tcl` holds only a `xschem reload` *caller* (`:13074`, plus
   `action_registry.tcl:183`), so no Tcl edit can close it.
2. **Its Part 2 is an undecided design question by the issue's own words** — the
   in-place loads are "arguably correct as it stands"; the open question is whether
   "explicit" should still mean "explicit" when the target is a viewer.

New data for whoever picks it up: the **raw survives intact** (424 vars / 20503 points,
before and after), so the blast radius is the graph-rect model only; **reload frees no
Tk widget** (a sidebar packed `-before $top.drw` survives packed, with its child); and
**under a real `DISPLAY` reload on a viewer also HANGS** on the modal
`alert_ {Unable to open file: …}` at `save.c:3814` — a symptom the original `--nogui`
filing could not see. The split-out `readonly`-cleared-on-failed-load defect is item
16's to file; the next free issue number is **0212**, not 0188.
