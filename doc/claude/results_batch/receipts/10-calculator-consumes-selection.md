# Item 10 — the Calculator consumes the session's selection (U3, U6, U7, U9 — R305, R502, R503)

**Last item of the batch, and the gate `doc/claude/calculator_batch` phase 3 has been waiting on.**
Phase 3 is Evaluate's *computation*; this item settles only **which database it computes
against**, and builds none of it. Tcl only, no C, no rebuild.

## 1. Files changed

| file | +/− | what |
|---|---|---|
| `src/calculator.tcl` | **+394 / −104** | `self` arm and `calc::results_path` **removed** (U6); `calc::ase_raw`'s derived-path arm removed (R502a); `viewer_raw` re-expressed as `calc::session_result` over `results::current` under the 0173 loan; new `ctx_result`, `token_origin`, `results_publish`, `require_result`, `eval_click`, `no_result_msg`, `no_result_advice`, `busy_msg`, `sessions_without_viewer`, `browse_inert`, `btnstate`; Eval's `-command`; the Browse stub |
| `tests/headless/test_calc_skeleton.tcl` | **+566 / −103** | **S27 new**; **S26 restated in place** (id kept; three of its legs did move to S27 — §5); three S15 legs and one S18 leg restated. 503 → **545** checks |
| `tests/headless/test_calc_widgets.tcl` | +13 / −1 | **CW13's `allowed` `-command` list restated**, with the reason |
| `doc/claude/specs/results_selection.md` | **+248 / −21** | new **§7.1a** (R502a/b, R503a–g); R502 and R503 rewritten and delivered; R305 done; §12 T-I and T-J; §18 re-check; **R304's `db_label` citation `:2401` → `:2414`** (handed on by item 9) |
| `doc/claude/specs/calculator.md` | +29 / −3 | W04, W05 (order **replaced**, old kept as labelled history), W12, R603 (*which* database — R503's named silence), R705 (why it still holds) |
| `doc/claude/issues/0516-here-arm-selection-invisible-to-the-calculator.md` | **new, 104** | the R407a `here`-arm collision: reproducer + the A/B showing item 10 introduced the state |
| `doc/claude/issues/status.md` | +1 / −1 | high-water mark 0515 → **0516** |

## 2. Decisions taken, and the evidence

- **U6 — the `self` arm is REMOVED, not demoted.** `calc::results_path` went with it; `xschem raw rawfile` occurs **0 times** in the comment-stripped file, greped by a check rather than read by me.
- **U3 — the row PICKS.** `calc::require_result` resolves **once**, publishes the row from that same measurement, then decides — so the row cannot name one database while the computation uses another, because there is no second measurement. S27 counts the resolutions and gets exactly 1. That is what closes R503's recorded contradiction.
- **U7 — Evaluate refuses and names the next action**, verbatim, asserted **by text** (S18, S27); a second check asserts it does not offer to launch ASE-L. Written `▸` in source so the string does not depend on the file's encoding surviving an editor.
- **U9 — Browse stays disabled**, same widget/state/shape; `-command` is `calc::browse_inert`, whose sentence carries the reason. *"Not implemented"* went because it is a **promise** (R502b). **U8** holds structurally: every cross-window read is a 0173 loan given back, and `results::select` is called **nowhere** in the file (greped at zero).
- **T-J's other half is DISCHARGED** (spec §12 rewritten from *"still owed"*): a refused loan is skipped, remembered and reported **as refused**, never as *"no results"* — two procs, two texts, and a check asserts the strings differ. That matters most here precisely because *"no results"* is also a legitimate answer. **R705 holds and is not a loophole** — it binds the *Calculator*; the batch persists the *session's* selection and the Calculator remembers nothing, every answer being a live `results::current`. That is R603, and the spec now says so.
- **NINE crew rulings, all in `results_selection.md` §7.1a with their evidence** (no human to ask): **R503d** (the borrowed read asks `results::current`, not `xschem raw rawfile` — they differ at a VCD/table slot and at F4's loaded-but-blind database) · **R502a** (a *derived* `ase::last_rawfile` path is a file on disk, not a selection) · **R503b** (provenance `ase | viewer | refused | none`; `ase` is a **lookup** — the viewer token IS the session key) · **R503a** (one resolver, U3's mechanism) · **R503c** (the two refusal sentences must not collapse) · **R503e** (Evaluate is gated, Plot and Table are not) · **R502b** (an inert control states why) · **R503f** (U7's sentence is never said to a user who has already done what it asks — the R407a collision, mitigated *in the message* and **filed as 0516**, because U6 is the user's to reopen) · **R503g** (the gate names a **slot**: `type` and `idx` travel with the path, since one two-plot `.raw` is two answers — U11, R407c(1)).

## 3. Tests, check counts, and the verbatim RESULT lines

`GUI_GATE=1 tests/headless/run_suites.sh`, dev display `:99` (VERBATIM):

```
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_calc_skeleton           run 1/4  RESULT: ALL PASS (545 checks)
PASS     | test_calc_widgets            run 2/4  RESULT: ALL PASS (244 checks)
PASS     | test_results_select          run 3/4  RESULT: ALL PASS (377 checks)
PASS     | test_wave_viewer             run 4/4  RESULT: ALL PASS (400 checks)
RESULT: 4/4 runs passed
```

`test_calc_skeleton` is the item's suite: **503 → 545 checks**, +42. `test_calc_widgets` 244.
No `.sh` suite is touched, so nothing needed a by-hand run outside `full_audit.sh`'s glob.

**AUDIT — a DIFF, not a count.** `GUI_GATE=1 tests/headless/full_audit.sh` on the dev display
`:99`, joined by test NAME and STATUS against
`doc/claude/results_batch/baseline_2026-08-19_226302f9.txt` (331/15/0/0 of 346):

```
SUMMARY: 334 pass  15 fail  0 crash/timeout  0 skip  (total 349)
WIREEDIT: ALL PASS / PASS      SCRATCH: 0 leaked dir(s)      TREE: 0 appeared  0 vanished

baseline rows 346   new rows 349      baseline PASS 331 FAIL 15   new PASS 334 FAIL 15
STATUS CHANGED (0):
ONLY IN BASELINE (0):
ONLY IN NEW (3):  test_results_dialog PASS   test_results_select PASS   test_waves_gate PASS
```

**Zero green→red and zero red→green across all 346 shared rows, and nothing only in the
baseline.** The three extra rows are the three suites `LEDGER.md` records this batch as having
added (items 1, 7, 8). The 15 reds are the baseline's 15 **by name**, including the five the
brief declares not ours (`test_wave_markers`, green standalone, and the four libmgr
environment reds). Full log kept at `doc/claude/results_batch/audit_item10_2026-08-20.txt`
(untracked, as item 8's is). `test_calc_skeleton`, `test_calc_widgets`, `test_results_select`,
`test_results_dialog` and `test_waves_gate` are all PASS inside the audit.

## 4. Sabotage — 38 drives, each restored byte-exact (`cmp -s`) and re-run green

| drive | what was broken | went red | restored |
|---|---|---|---|
| PRE | `calculator.tcl` at its pre-item bytes | 19 then abort | yes |
| SB1 / SBF9 / SBF9b | the `self` arm restored at the head of `results_source` | S26 U6 leg alone; **4** once R503f ran in 0516's exact state | yes |
| SB8 / SBF11 | the reader reverted to `xschem raw rawfile` (`results_path` back) | **17**; 3 on re-drive, incl. both S15 legs + the grep | yes |
| SB2 / SBF10 | a refused loan not recorded → answers `none` (**F6's defect**) | 6 (S26 ×4, S27 ×2) | yes |
| SB6 / SBF14 | `busy_msg` returns `no_result_msg` (**the T-J collapse**) | 3 | yes |
| SB13 / SB14 | the loan taken without `borrow=1`; `leave_ctx` on a **refused** ticket | 3 + 3 | yes |
| SB11 / SB11b | `leave_ctx` dropped | S26 give-back, S26 U6, S27 U8; 4 on re-drive | yes |
| SB3 / SBF13 | `require_result` resolves twice | S27 "SAME resolution" + the loan-count leg | yes |
| SB23 / SBF12 | `results_source` memoised (**R705**) | 23; **34** on re-drive | yes |
| SB4 / SB18 | `eval_click` never refuses; `require_result` always answers `ok 1` | S18 + S27 U7 + S27 T-J; 4 | yes |
| SB5 / SBF6 / SBF7 | U7's sentence shortened; R503f collapsed each way | S18 + S27 U7 ×2; 3; 5 incl. both verbatim-U7 legs | yes |
| SBF8 | `sessions_without_viewer` never asks `wviewer::window_for` | **1** — the discriminating control alone | yes |
| SB7 / SB19 / SB20 | Browse's old stub; Browse enabled + path writable; "not implemented" restored | "the ruled stub" alone; 5 (incl. two S15 legs); REASON leg alone | yes |
| SB9 | the `ase::last_rawfile` arm restored | S26 R502a leg alone | yes |
| SB10 / SBF3 | `token_origin` always `viewer`; then *"is ANY session open?"* (**previously ALL PASS**) | S26 ASE-key ×2; 2 | yes |
| SB12 / SBF4 | the balloon attach deleted; `build_res`'s first-open refresh deleted (**previously ALL PASS**) | 3; 2 (empty row, no balloon) | yes |
| SB15 / SB24 | the collapse arm refreshes too; the walk stops at the first *enterable* context | each reds its own leg alone | yes |
| SB21 / SB-T | a `results::select` call added to `eval_click`; a window really created inside `require_result` | "never calls results::select" alone; S27 U8 "did not move" | yes |
| SB22 | `pack forget .calc.res.path`, then both `pack` sites → `place` | S15 slaves, S27 MAPPED row — **one site alone stayed green** (the expand arm re-packs) | yes |
| SBF1 / SBF2 | `ctx_result` drops the slot's `type`/`idx` (**the shipped defect**); the dict loses the keys | 6 (S26 ×4, S27 T-I slot, S27 U11); 2 | yes |
| SBF5 | an *enabled* selector (`vt`) genuinely disabled | **9** — proves `btnstate` did not disarm the sweep | yes |
| SB-U / CW13 | Eval's `-command` → a proc not on CW13's list; and the OLD `allowed` list vs the new code | CW13 2 red; `test_calc_widgets` 1 FAILED (243) → ALL PASS (244) | yes |

**UNSABOTAGED — declared, therefore NOT evidence (6):** S15 *"shim installed cleanly"*, S15
*"shim was live and is now gone"*, S27 *"the source really was read"*, S27 *"shims are gone
again"*, S27 *"the window path was really readable"*, S27 *"the row's variable really was
cleared first"* — each is the positive term of a neighbouring assertion and cannot red alone.

## 5. What was NOT verified

- **PIXELS — why this is `[E]`.** `▸` (U+25B8, ×2 per sentence) and `—` (U+2014) may render as boxes, and R503f's long sentence may truncate in `.calc.status.msg`. Two **look** debts: `calculator_U7_refusal___Results_Dir_label_forms.1787247321.189995` and `calculator_R503f_no-viewer_refusal_sentence.1787252113.268210`. Also unjudged: whether the three new row labels fit beside the path.
- **The loan protocol is proved by a shim in the suite**, which cannot see a *leaked* loan; the verifier closed that out of band with a real viewer (title and `readonly` survived a real loan, context restored to `.drw`). A **multi-viewer** walk has real-world evidence from nobody. **`results::current` is shimmed** in S26/S27 — its real behaviour (R103, the R102 VCD/table gate, F4) is `test_results_select`'s 377 checks; a viewer holding a VCD or `table` was never driven.
- **Two unreproduced hypotheses, stated as such:** a `self` arm re-inserted by a third route (walking `results::list` for the `cur` slot here) would defeat both U6 checks; and a REFUSED `leave_ctx` (`wave_viewer.tcl:1490-1501`) would strand the walk in the viewer and violate U8. Related: `session_result` maps **every** `{0 …}` ticket to `refused`, including a transiently empty `current_win_path` that `busy_msg` then calls "busy".
- **Finding 4 is MITIGATED, NOT CLOSED, deliberately** — issue **0516**. U6 reads *"removed entirely"*, so a fixer may not add an arm reading this window's context. **The driver must rule** whether R407a's `here` arm survives, and if so whether the Calculator may read the current context when a live session has no viewer. Not re-opened: U7's sentence names a cascade on the **ASE-L window's own menubar** (`ase_window.tcl:527`), reachable only while an ASE-L window is open.
- **Evaluate computes nothing**, by fence — a press *with* a result reaches the phase-3 stub and S27 asserts it; nothing of L4/L5 is touched. Unmeasured: whether walking every viewer on every press causes visible redraw. **No `:0` run** (Tk-widget GUI, run on `:99`); two **suite** debts raised. **One drive went to the wrong display**: the fixer's first post-fix single run used `gated_xschem.sh` alone, which gates but does **not** arm the display, so ~30 s of Calculator windows appeared on the user's real `:0`.
- **`$HOME`.** `recent_files`, `raw_history`, `library.defs`, `xschemrc`, `pdk_launcher.conf`, `net_hilight_editor_seen`: **byte-identical** (md5 by hand around every drive). `~/.xschem/geometry` **was rewritten** — every GUI exit rewrites it — and `~/.xschem/.clipboard.sch`'s mtime moved during an audit at unchanged size, from the audit's own clipboard suite. **Both left in place** for the driver's `pre-item10` restore. Nothing in this item raises `::update_recent_files`.
- **Not mine, not fixed:** `PLAN.md` §1 already carried `[x]` for item 10 while it was uncommitted, and `[x]` for item 8 where `LEDGER.md` says `[E]`; `PLAN.md` is untouched here. Cosmetic: `calculator.md` W05 keeps the superseded resolution order inline beside its replacement, labelled.
- **Reviewers: nine findings, nine CONFIRMED, none rejected.** Eight fixed (slot identity; two stale `calculator.md` citations — **L9 bit twice, the fixer's own edits moving the same blocks again**; the `viewer_raw` comment ×2; the false *"none renumbered"* claim; R503b's missing negative control; `build_res`'s uncovered first open; S17's hover-dependent `-state` sweep), one filed as 0516. **On the record:** three S26 legs *did* migrate to S27 — S26 keeps its id and its block, which is what *"do not renumber it"* was about, but *"none renumbered"* was false and a reviewer's name-by-name diff proved it. **No reviewer could re-verify the 24 implementation-round sabotages** (a lens may not mutate the tree); what was independently verified is the restatement — HEAD's test file against the new code gives `17 FAILED (486 passed)`, and the 17 reds are exactly the legs this item restates.
