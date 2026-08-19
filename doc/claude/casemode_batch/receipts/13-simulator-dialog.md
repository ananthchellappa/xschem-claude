# 13 — simulator dialog: per-row exe/args/case/-n, a Test button, B3's auto-probe

Casemode batch item 13, **`[E]`** — the payload is a Tk dialog. Authority: `DECISIONS.md` **B1** (extend `simconf`, no second registry), **A1** (probe-driven; nobody selects a mode their simulator ignores), **A2** (per-profile `-n`), **B3** (auto-probe gated on the exe's NAME, hard timeout). Spec extended as `simulator_profiles.md` **§17** (18 subsections). Base `3cc05cc5`. No C, nothing built, nothing pushed. Implementer + verifier + 3 review lenses + fix round; this is the closer's record.

## 1. Files changed

| file | ± | what |
|---|---|---|
| `src/xschem.tcl` | **+756 −68** | 31 new `simconf_*` procs, 35 in the file against the 4 that were there (staging, commit, snapshot incl. the simrc FILE, the A1 Case menu, the probe wrapper, B3's arm, the row builders); `simconf` hands its row build to `simconf_build_row`; the four buttons + `WM_DELETE_WINDOW` rewired; the dead `Add` block rewritten and live; dead `simconf_saveconf` removed; Help gains a `SIMULATOR PROFILE` section |
| `doc/claude/specs/simulator_profiles.md` | **+571 −0** | §17.1–§17.18: every ruling with the measurement that drove it |
| `tests/headless/test_sim_dialog.tcl` | **new, 1094** | 69 checks, band `SDG1`–`SDG22` |
| `audit_item13{,_fixround,_closer}_2026-08-18.txt` | new ×3 | the three full audits. `full_audit.sh` needed no edit: it globs `test_*.tcl` and its default arm is the one this file wants |
| `receipts/13-simulator-dialog-annex.md` | new, 299 | the implementer's and the fix round's own long-form records, kept verbatim |

## 2. Decisions taken, and the evidence

| ruling | evidence | spec |
|---|---|---|
| **The commit point.** The four new fields are STAGED in `::simconf_ui`; they reach `sim()` only at Test / Accept / Accept+Save, validated through item 6's `sim_profile_set`. Cancel restores the WHOLE `sim()` array from a snapshot taken at open, and `simconf_snapshot_restore` refuses while `.sim` exists | the defect items 9 and 11 both hit — `::set_sim_defaults` is not a read, it slurps every `…r.$i.cmd` box; a snapshot is the only thing that can undo that *and* the pre-existing `-textvariable` writes; and Tk re-creates a `-textvariable` element from the widget's own string the moment it is unset | §17.2 |
| **An invalid value BLOCKS the close** and is reported on three channels (row label, bottom status line, `ciw_echo`) | a report destroyed with the window it was printed on is not a report | §17.3 |
| **A1 as a widget**: the Case menu is built from `sim_profile_selectable`, never a constant. Unprobed → `fold` alone; measured → exactly what came back; measured-to-deliver-nothing → the floor entry only. A stored-but-unmeasured mode is DISPLAYED marked `NOT measured` and is not offered. Pre-fill = first selectable mode, staged, only on a recorded measurement, never overwriting. The floor entry **self-marks** `use global default (distinguish - NOT measured)` when the floor is not selectable there — label, not gate, since B1 mandates the entry exists | item 7 probes each mode with `-D casemode=<m>` and checks `$curcasemode`; "presence implies all three" was already refuted. Review finding: with a non-`fold` floor the unfiltered entry was A1's one seam | §17.4 |
| **B3's "on Add" is an ARM** on the row Add just created, consumed once; an existing row is never auto-probed however it is named; **a deliberate Test consumes the arm** | the name gate avoids checking out a licence merely because a path was typed; without the consumption, Test-then-Accept launched **six** processes for one row. **One probe per click, none on a build path**, no retry loop around item 7's whole-probe timeout, transport stays `-b <abs deck>`: item 7's own first cut froze 15016 ms, and `-p` opens `$DISPLAY` and cores with it unset | §17.5, §17.15, §17.6 |
| **A measurement belongs to the binary it was taken on** — committing a changed `exe`/`args`/`-n` DROPS `detected`/`probed`. Compared by stored VALUE, not by mtime | two binaries can share an mtime, which is exactly what a staleness check cannot see (`SDG20b`) | §17.14 |
| **Cancel restores the simrc FILE**, conditionally, not only the array; and **the titlebar X is Cancel**, not Accept | `set_sim_defaults reset` deletes `$USER_CONF_DIR/simrc`; the Help text promised Cancel undid it and it did not — the config was gone at the next start. The X meanwhile committed while Cancel beside it rolled back, and went inert on an invalid field | §17.13, §17.16 |
| **A2's `-n` is canonicalised at the boundary** (`[expr {$v ? 1 : 0}]` + explicit `-onvalue/-offvalue`) | a hand-written `nospiceinit true` — which `sim_profile_valid` accepts and B1 blesses — displayed UNCHECKED while `-n` was really passed | §17.17 |
| **CORRECTION to the batch's premise**: item 12's repair is **still dormant** after this item. Ruled NOT to wire it here | measured twice — no caller passes `-case` (`ase.tcl:2905/2907`), and today's ver_50 writes no `Option: casemode=` header under `distinguish`. Wiring it would install the floor as evidence, which items 3, 4 and 5 all refused. What DID become live, driven end-to-end through the real dialog into a real `ase::run_deck`: `ase::run_precheck`, `ase::sim_probe_run`, `ase::preflight_gate` observed executing and item 8's `REFUSE` firing with nothing generated — items 8/9/10 reachable by gesture for the first time in this batch | §17.9 |
| **Item 10's deferred D1 confirmation modal: DECLINED**, with a written design for whoever builds it | wrong surface (it belongs on the run path); no decision specifies it, so the ruling would be taste with no measurement; `tk_messageBox` re-opens the re-entrancy §11.6 rejected `vwait` for | §17.10 |

## 3. Test, check count, RESULT

`tests/headless/test_sim_dialog.tcl`, band `SDG1`–`SDG22`, **69 checks** (53 from the implementer, 16 from the fix round). Closer's own run, dev display `:99`, `GUI_GATE=1`, through `run_suites.sh` — verbatim:

> `PASS     | test_sim_dialog              run 1/1  RESULT: ALL PASS (69 checks)`

True headless (`--nogui`) it self-reduces to the model legs, `RESULT: ALL PASS (37 checks)`; the 11-suite battery is 11/11 PASS with counts unchanged (`test_sim_profiles` 97, `test_sim_probe` 61, `test_sim_run_profile` 38, `test_ase_dialogs` 149, `test_ase_sod_case` 52, `test_ase_preflight` 114, `test_ase_result_case` 28, `test_ase_persist` 109, `test_ase_current_repair` 56, `test_raw_case_mode` 277). **Closer's own `full_audit.sh`** (`GUI_GATE=1`, self-armed to `:99`, `DISPLAY` never stripped) — `SUMMARY: 330 pass  15 fail  0 crash/timeout  0 skip  (total 345)`, saved as `audit_item13_closer_2026-08-18.txt`. **Diffed by NAME and STATUS against `audit_item12_closer_2026-08-18.txt` (329/15/0/0 of 344): rows only in the baseline NONE, rows only in mine `test_sim_dialog`=PASS, MOVERS ZERO in either direction**, `test_ase_core` PASS on both sides, and the 15 reds are byte-for-byte the 15 the batch policy lists. Its `TREE: 1 appeared` is this receipt's own annex, copied in mid-run, not a test dropping. Item 6's frozen `fixtures/simrc_pre_casemode` was also re-driven THROUGH the dialog: open → Accept+Save → byte-identical; Cancel writes nothing.

## 4. Sabotage — one row per check, all 69 covered

Every mutation is an exact literal replacement asserted to hit once, applied over a byte-exact backup (never `git checkout` — that would delete the uncommitted item), run, restored, restore `md5`-verified. Three independent rounds: implementer 49 mutations, verifier 52 of its own, fix round 22. **MASTER RED** (`git show HEAD:src/xschem.tcl` over the item): `RESULT: 47 FAILED (6 passed)`, restored to `ALL PASS`, md5 equal.

| check | what was broken | red? | restored green? |
|---|---|---|---|
| SDG1 | the stage list drops `nospiceinit` | yes | yes |
| SDG1b | the stage list gains `detected` — a measurement staged as an edit | yes | yes |
| SDG2 | `simconf_stage_row` seeds `{}` instead of `sim_profile_get` | yes | yes |
| SDG2b | `sim_profile_get` reads the staging area first (the model leaks) | yes | yes |
| SDG2c | `simconf_commit_row` skips the `exe` field | yes | yes |
| SDG3 | `sim_probe_argv` never appends `-n` | yes | yes |
| SDG3b | `simconf_commit_row` swallows the refusal instead of `lappend errs` | yes | yes |
| SDG3c | `simconf_report_errors` blanks the status line | yes | yes |
| SDG3d | `simconf_commit_row` skips the `args` field | yes | yes |
| SDG3e | `simconf_report_errors` drops the `ciw_echo` leg | yes | yes |
| SDG3f | `simconf_commit_row` `continue`s past `args`, so the box's refusal cannot fire | yes | yes |
| SDG4 | the row is built at `…r.x$i`, breaking the pre-item-13 widget-path contract | yes | yes |
| SDG4b | `simconf_build_profile_row` never called — the whole profile line unbuilt | yes | yes |
| SDG4c | the Case menu's entries are labelled `XX` instead of the model's label | yes | yes |
| SDG4d | a probe fired at ROW-BUILD time | yes | yes |
| SDG5 | `simconf_cancel` drops `simconf_snapshot_restore` | yes | yes |
| SDG5b | the Exe entry bound to `sim($tool,$i,exe)` instead of the staging area | yes | yes |
| SDG5c | as SDG5 — a Test measurement survives a Cancel | yes | yes |
| SDG5d | as SDG5b — typing reaches the model immediately | yes | yes |
| SDG5e | the Args entry bound straight to `sim($tool,$i,args)` | yes | yes |
| SDG6 | the A1 pre-fill assignment deleted from `simconf_do_probe` | yes | yes |
| SDG6b | the pre-fill's `casemode eq {}` guard removed (it overwrites a choice) | yes | yes |
| SDG6c | the `nocasemode` sentence stubbed, losing its "fold only" wording | yes | yes |
| SDG6d | the pre-fill becomes the constant `fold` | yes | yes |
| SDG7 | `simconf_mode_menu_items` iterates the constant `{fold preserve distinguish}` | yes | yes |
| SDG7b | the menu truncated to the first selectable mode | yes | yes |
| SDG7c | `sim_profile_selectable` concats `fold` back onto a measured list | yes | yes |
| SDG7d | `simconf_mode_label` drops the `(NOT measured)` mark | yes | yes |
| SDG7e | a measured-and-delivers-nothing row returns `fold` instead of `{}` | yes | yes |
| SDG7f | `simconf_mode_floor` returns the constant `fold`, ignoring `sim_case_mode` | yes | yes |
| SDG7g | `simconf_mode_floor` stops validating `sim_case_mode` | yes | yes |
| SDG7h | `simconf_mode_floor_label` never marks an undeliverable floor | yes | yes |
| SDG7i | `simconf_mode_floor_label` marks unconditionally (the over-fix twin) | yes | yes |
| SDG8 | `simconf_add_gui` sets `autoprobe 0` — Add no longer arms the row | yes | yes |
| SDG8b | the `noexe` branch disarms the row instead of leaving it armed | yes | yes |
| SDG9 | B3's name gate replaced by `if {0}` — every added exe auto-launched | yes | yes |
| SDG9b | the "not auto-probed … press Test" note emptied | yes | yes |
| SDG9c | `simconf_row_register` ignores the arm, so an EXISTING row is probed | yes | yes |
| SDG9d | the armed Add path returns without calling the probe | yes | yes |
| SDG10 | `simconf_test_row` returns without probing — Test measures nothing | yes | yes |
| SDG10b | the menu truncated, so it cannot grow after a Test | yes | yes |
| SDG11 | a second `sim_profile_probe_capability` call — a retry loop around item 7 | yes | yes |
| SDG12 | the `timeout` outcome's "TIMED OUT … nothing recorded" sentence replaced | yes | yes |
| SDG12b | the `error` outcome returns a bare string not starting `Test: ` | yes | yes |
| SDG12c | the `ok` sentence drops `[join $d]`, never naming the measured modes | yes | yes |
| SDG12d | a throw out of the probe leaves the row's note at `probing...` | yes | yes |
| SDG13 | the `Accept, no Save and Close` BUTTON's `-command` emptied | yes | yes |
| SDG13b | BOTH of `simconf_accept`'s early returns removed (one alone is inert) | yes | yes |
| SDG14 | the `Accept, Save and Close` BUTTON's `-command` emptied | yes | yes |
| SDG14b | `simconf_cancel` writes `save_sim_defaults` before closing | yes | yes |
| SDG14c | `if {0} { save_sim_defaults … }` — Accept+Save writes nothing, ever | yes | yes |
| SDG15 | `simconf_mode_refresh` returns 1 with no dialog open | yes | yes |
| SDG15b | `simconf_snapshot_restore`'s live-window guard replaced by `if {0}` | yes | yes |
| SDG16 | the Test BUTTON's `-command` emptied | yes | yes |
| SDG16b | the Case menu ENTRY's `-command` emptied | yes | yes |
| SDG16c | the `<Return>` bind on the Exe entry replaced by an empty script | yes | yes |
| SDG16d | Cancel BUTTON rewired to `simconf_close`; and the Add MENU ENTRY unwired | yes | yes |
| SDG16e | `simconf_mode_refresh` never refreshes the row note | yes | yes |
| SDG16f | BOTH Accept BUTTONS' `-command` emptied in one mutation | yes | yes |
| SDG17 | `simconf_register_armed` deleted from `simconf_accept` | yes | yes |
| SDG17b | `sim_profile_probe_autoprobe_ok` gains an unconditional `return 1` | yes | yes |
| SDG18 | `simconf_cancel` drops `simconf_file_restore` | yes | yes |
| SDG18b | `simconf_file_restore` made unconditional, so every Cancel rewrites | yes | yes |
| SDG19 | `simconf_test_row` stops consuming B3's arm (Accept re-probes: 3→6 legs) | yes | yes |
| SDG19b | `simconf_test_row` consumes the arm even on an empty Exe box | yes | yes |
| SDG20 | `simconf_commit_row`'s measurement-drop disabled | yes | yes |
| SDG20b | the drop gated on `sim_profile_probe_stale` (mtime) instead of on VALUE | yes | yes |
| SDG21 | the stage-time boolean canonicalisation removed (+ a non-canonical on-value) | yes | yes |
| SDG22 | `WM_DELETE_WINDOW` reverted to `simconf_accept 0` | yes | yes |

**No check is unsabotaged.** Three mutations came back GREEN and are recorded rather than quietly re-run: `M23`/`M23b` each removed one of `simconf_accept`'s two identical early returns and the other still fired (`M23c`, both, is the effective one); and `W05` (`sim_profile_valid`'s `args` arm → `return 1`) is mis-aimed, not a hole — `{unbalanced` is refused by the persistence round-trip guard above the field switch, so that arm is never reached (`W05b` is the effective one). **Six checks survive the MASTER RED** (`SDG1b SDG2b SDG6b SDG4d SDG14b SDG15b`): all six assert that something does *not* happen, trivially true when nothing exists — their evidence is their own targeted mutation, not the master red. **Eight test defects were found by mutations that should have reddened and did not**, all eight fixed: `SDG12` bounded a hung probe by the clock and now counts launches; `SDG12b` accepted `ERR:invalid command name` as a legible sentence; `SDG14b` compared a file against the bytes it started from; `SDG4d` took its baseline after the window was built; and four whole holes the review found — both Accept BUTTONS never invoked, Accept+Save able to write nothing, `simconf_register_armed` uncovered, the Args entry's staging unpinned (each left 8 suites / 836 checks green).

## 5. What was NOT verified

- **PIXELS — nobody has looked at this dialog.** **Four `look` debts** are recorded in `owed.sh` (two from the implementation: the profile line's readability at the shipped 1010x520 and its presence on the `*wave` viewer rows; the Test sentence and the A1-built Case menu — two from the fix round: the self-marking floor entry, the status line that goes *backwards* after an Exe edit, the two new Help paragraphs, and the Reset→Cancel round trip checked by eye AND `ls -l ~/.xschem/simrc` AND a restart). **No green suite discharges any of them.** Ledger now 5 suite / 15 look. **One `:0` SUITE DEBT is recorded too** (`owed.sh add suite test_sim_dialog`): 19+ legs drive real Tk widgets, including a bare `event generate <Key-Return>` (a known ~1-in-5 WSLg flake), and WSLg emits 3 `<Configure>` events where Xvfb emits 1. Everything here ran on `:99`.
- **Reviewers raised nothing that was not confirmed** (that set was empty) and **all nine distinct confirmed defects were fixed**, none dismissed, every one reproduced first. **Reviewer-declared not-proven, still not proven by me either**: the pixels; the 49+22 mutation rounds (I re-ran none — I ran the suite, the audit and the diff); the MASTER RED (recorded, not re-driven here); the end-to-end "dormant code observed executing" traces; the ruling that item 12's repair stays dormant; and any behaviour on `:0`.
- **NOT FIXED, carried forward — verifier PROBLEM 2, outside the confirmed set and outside this item's fence**: `ase::run_mode_advice` (`src/ase.tcl:990`) keys on `sim_profile_resolve` returning status `default`, which it does whenever the session names no explicit `sim_profile` — so a row configured THROUGH this dialog gets "This session has NO simulator profile row … or configure a profile", both clauses false and the second telling the user to do what they just did. Reachable by hand-edited `simrc` since item 6; item 13 makes it reachable by gesture. **It needs its own item.** And, **verifier OBSERVATION**: item 5's "the override is deliberately NOT persisted — item 13 owns durability" (`LEDGER.md:318`) is named in neither the driver's verbatim scope nor §17, and it is a *viewer* setting. Still open, still unassigned.
- **No Xyce, and no `Option:`-bearing raw exists to test against.** The `distinguish` end-to-end used the private `build-ver_50`; the REFUSE end-to-end used `/usr/local/bin/ngspice`. `ver_50` keeps moving; every leg asserts on `$curcasemode` and measured output and SKIPs when it is absent. `-onvalue 1 -offvalue 0` is belt-and-braces (Tk's defaults already are `1`/`0`) — the behavioural half of that fix is the stage-time canonicalisation, sabotaged separately; a save after Accept now canonicalises `nospiceinit true` to `1`, deliberate, and it cannot touch the frozen fixture, which carries no profile fields. **Issue `0502` is unchanged**: the dialog routes no path through `ase::expand_path` — `Exe` goes through item 6's `sim_profile_expand_vars` — and commit-time validation makes the hole neither easier nor harder to trip. Rows are taller, so about five fit where nine did; a user with a saved `simconf_default_geometry` keeps it and opens cramped (deliberate).
