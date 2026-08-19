# 13 — the simulator dialog: per-row exe/args/case/-n, a Test button, and B3's auto-probe

**Casemode batch ITEM 13**, the batch's only PIXEL item, therefore **`[E]`** — two `look` debts recorded (`owed.sh`, ids `casemode_item_13_*`). Authority: `PLAN.md` §3b item 13 · `DECISIONS.md` **B1** (extend the existing `simconf`, no second registry), **A1** (probe-driven pre-fill; nobody may select a mode their simulator will silently ignore), **A2** (the per-profile `-n`), **B3** (auto-probe gated on the executable's NAME + the hard timeout). Spec **extended, not replaced**: `doc/claude/specs/simulator_profiles.md` **§17** (item 6 owns §1–§10, item 7 §11, item 8 §12, item 9 §13, item 10 §14, item 11 §15, item 12 §16). Base `3cc05cc5`, branch `fluid-editing`. **No C, nothing built, nothing pushed.**

## 1. Files changed

| file | ± | what |
|---|---|---|
| `src/xschem.tcl` | **+610 −56** | **30 new** `simconf_*` procs (34 in the file, against the 4 that were there) (staging, commit, snapshot, the Case menu, the probe wrapper, B3's arm, the row builders); `simconf` gains `keepsnap` and hands its row build to `simconf_build_row`; the four button commands rewired; the `Add` block un-commented and rewritten; the Help text gains a `SIMULATOR PROFILE` section |
| `doc/claude/specs/simulator_profiles.md` | +365 | **§17**, twelve subsections, every ruling with its measurement |

New: `tests/headless/test_sim_dialog.tcl` (**53 checks** on a display, **35** true-headless, band **`SDG1`–`SDG16e`** — measured by grepping `tests/headless/*.tcl` for the highest id in use, not quoted from a doc; `SDG1`–`SDG6` were already taken by `test_wave_viewer`/`test_schpins_stale_lab_0185`, hence a *new* two-letter band rather than an extension of `CS`, whose neighbour `SC192` would have been one transposition away), this receipt, and `audit_item13_2026-08-18.txt`.
`full_audit.sh` needed **no edit**: it globs `test_*.tcl` and the default arm (`--pipe -q --nolog`) is the one this file wants.
**Untouched:** every existing `cmd` string, `run_cmd`, `attach_dbs`, all C, `ase::expand_path` (issue `0502`).

## 2. Rulings, and the evidence for each (spec §17 carries the measurement)

- **THE COMMIT POINT (§17.2), the defect this item exists for.** `::set_sim_defaults` is not a read — items 9 and 11 both hit it, `test_ase_dialogs` `G13` pins it. Two halves: the new fields are **staged** in `::simconf_ui` and reach `sim()` only at Test / Accept / Accept+Save; **Cancel restores the whole array** from a snapshot taken at open, which is the only thing that can undo the *pre-existing* `-textvariable` writes (`name`/`fg`/`st`/the default radio) and anybody's `cmd` slurp. `SDG5` types into the `cmd` box, edits a live field AND the Exe box, **forces the slurp**, asserts in `SDG5b` that it really landed, cancels, and requires all three back. `SDG5c`: a Test's recorded measurement is undone too.
- **DESTROY BEFORE RESTORE (§17.2).** `array unset sim` under a live widget is not a rollback — Tk re-creates a `-textvariable` element from the widget's own string. `simconf_snapshot_restore` refuses while `.sim` exists (`SDG15b`).
- **AN INVALID VALUE BLOCKS THE CLOSE (§17.3).** Validation is item 6's `sim_profile_set`; a refusal keeps the stored value, keeps the window open, and reaches **three channels** (row label, bottom status line, `ciw_echo … error`). `SDG3b`/`SDG3d`/`SDG3c`/`SDG3e`/`SDG13b`.
- **A1 AS A WIDGET (§17.4).** The Case menu is `sim_profile_selectable`, never a constant: unprobed → `fold` alone; measured → exactly what came back; measured-and-delivers-nothing → the floor entry only. Driven from the model (`SDG7`…`SDG7e`) **and read back out of the real Tk menu** (`SDG4c`, `SDG10b`).
- **A stored-but-unmeasured mode is SHOWN, marked `NOT measured`, and NOT offered** (`SDG7d`). Hiding it loses a real setting; offering it breaks A1.
- **The pre-fill is the FIRST SELECTABLE mode, staged, and never overwrites** (`SDG6`, `SDG6b`, `SDG6c`, `SDG6d`) — `fold` for anything that folds, `preserve` for a binary measured to deliver only that, **nothing** for one that delivers nothing. It fires only on a *recorded* measurement (`SDG12`'s `prefill=<>`).
- **B3: "on Add" is an ARM on a row, consumed once (§17.5).** Two stand-ins differing **only in filename**: the `zzz`-named one is not launched by an Add (`SDG9`) and is measured happily by Test (`SDG10`); the `ngspice`-named one is (`SDG9d`). An **existing** row is never auto-probed however it is named (`SDG9c`).
- **ONE probe per click, and none on a build path (§17.6).** `SDG11` counts the stand-in's own invocations (3 per click, 6 for two); `SDG12` counts **one** launch for a hung probe; `SDG4d` takes its baseline *before* the window is built and requires zero.
- **BACKWARD COMPATIBILITY, re-driven (§17.8).** Item 6's frozen `simrc_pre_casemode` loaded → dialog opened → **Accept, Save and Close** with nothing changed → **byte-identical** (`SDG14`); Cancel writes **no file at all**, with a live edit in flight so the check can fail (`SDG14b`).

## 3. THE TWO DORMANT THINGS — driven, and one of them CORRECTED

**Driven end to end on `:99`** (`scratchpad/item13/e2e*.tcl`): Add → Exe = `build-ver_50/src/ngspice` → Return → **auto-probe** (B3 passes) → `detected = fold preserve distinguish` → the Case menu offers all three → pick `distinguish` → Accept → `ase::run_deck` on a real netlist. Execution traces show **`ase::run_precheck` (item 8's B4 gate), `ase::sim_probe_run` (item 7's run probe, from the rundir) and `ase::preflight_gate` (item 10's pre-flight) all executing** — the first time in this batch any of them is reachable from a user gesture. With `/usr/local/bin/ngspice` the same gesture: **the menu refuses to offer `distinguish` at all** (A1, live), and forcing it the simrc way gives item 8's `ase: REFUSED …` with **only `cell.spice` left in the rundir**.

**CORRECTION to the ledger's "item 13 is what turns it live": item 12's repair is STILL dormant, and the reason is two measurements.** (a) Nothing passes `-case`: `ase::attach_dbs` reads `xschem raw read $rawfile $sim_type` (`ase.tcl:2905/2907`), and a whole-tree grep finds no `-case` / `raw case 1` outside comments — a `distinguish` **profile** does not change that. (b) The raw carries no evidence either: today's `build-ver_50` run `-D casemode=distinguish` writes `Title:/Date:/Command:/Plotname:/Flags:` and **no `Option: casemode=`** (`casemodewrite` is still off by default — the unsent `cp_remvar` ask), so item 3's source 2 cannot answer, and case-kept names land in a **folding** lookup, which is item 12's own theorem for why the repair cannot fire. **RULED (§17.9): item 13 does not wire it** — making the run's *request* set the file's `case_sensitive` installs the global floor as evidence in the one place items 3, 4 and 5 all refused to (item 4: bytes beat the flag, the flag beats the floor; item 5: the viewer override writes the explicit source only, never `case_sensitive`).

**D1's confirmation modal: DECLINED, with reasons and a design (§17.10).** Item 10 deferred it here saying "`[E]` plus a fifth look debt for a dialog no decision specifies". `[E]` is no longer an objection; four others are: the surface is wrong (D1's prompt belongs on the **run** path, not in `Simulation ▸ Configure simulators and tools`); **no decision specifies modality, wording, granularity or partial acceptance**, so the ruling would be taste with no measurement, which nothing else in this batch is; a `tk_messageBox` between the pre-flight and the run re-opens the re-entrancy §11.6 rejected `vwait` for; and it costs a third look debt for one button whose function is already reachable, already named in the refusal and already driven headlessly. §17.10 records what it should look like when somebody builds it.

## 4. Test, RESULT, suites

`tests/headless/test_sim_dialog.tcl` — **`RESULT: ALL PASS (53 checks)`** on the display arm, **`ALL PASS (35 checks)`** under `--nogui` (the dialog legs self-skip with `note:` lines, **never** a column-0 skip banner). No real simulator is needed: every probe runs a `/bin/sh` stand-in that `exec`s (item 7's orphan lesson).

**AUDIT** — `GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`, `DISPLAY` never stripped, load average 0.7 at the start, nothing else running → `doc/claude/casemode_batch/audit_item13_2026-08-18.txt`:

```
SUMMARY: 330 pass  15 fail  0 crash/timeout  0 skip  (total 345)
WIREEDIT: PASS    SCRATCH:  0 leaked dir(s)
TREE:     0 appeared  0 vanished
```

**DIFF vs `audit_item12_closer_2026-08-18.txt` (329/15/0/0 of 344, at `66d7122f`), by NAME and STATUS: rows only in the baseline — NONE. Rows only in mine — `test_sim_dialog` (PASS), this item's new suite. Status changes in EITHER direction — NONE, zero rows moved.** The 15 reds are the same 15 names the batch policy lists, compared as sorted lists; **`test_ase_core` is PASS**, as the contract requires. Counted with a differ matching only `^(PASS|FAIL|CRASH|TIMEOUT|SKIP)\s+\|\s+test_\S+$`, so the six within-file `FAIL | key …` detail lines cannot be miscounted as rows; self-checked by diffing the baseline against itself (344 rows, 329/15, zero changes). **A first audit run was KILLED and its file deleted**, deliberately and recorded here: it had been started before the last three source edits and a sabotage round swapped `src/xschem.tcl` underneath it, so its provenance was mixed. The committed one ran start to finish over the final `md5` (`bb0b78f5…`).

`GUI_GATE=1 run_suites.sh` on `:99`, **11/11 PASS**: `test_sim_dialog` 53, `test_sim_profiles` 97, `test_sim_probe` 61, `test_sim_run_profile` 38, `test_ase_dialogs` **149**, `test_ase_sod_case` 52, `test_ase_preflight` 114, `test_ase_result_case` 28, `test_ase_persist` 109, `test_ase_current_repair` 56, `test_raw_case_mode` 277. The two counts most at risk (`test_ase_dialogs` 149, `test_ase_sod_case` 52) were **re-measured on a byte-restored pre-item-13 `src/xschem.tcl`** and are identical. `test_ase_core --nogui` (the arm the audit uses) `ALL PASS (75)`.

## 5. Sabotage — 49 mutations, no survivor, plus a MASTER RED

Each is an exact literal replacement asserted to hit **exactly once**, applied over a byte-exact backup (never `git checkout` — that would delete the uncommitted item), run, restored, restore `md5`-verified. Driver: `…/scratchpad/item13/mutate.py`; full output `…/mutations.txt`. **MASTER RED:** `git show HEAD:src/xschem.tcl` → **`RESULT: 47 FAILED (6 passed)`**, restored → `ALL PASS (53)`, md5 equal. **Every one of the 53 check ids appears below** (verified by set difference).

| mutation | checks reddened |
|---|---|
| M01/M35 stage list loses / gains a field · M02 staging seeds the default | CS→ SDG1 SDG2 SDG2c SDG3 SDG13 · SDG1 SDG1b · SDG2 SDG5c SDG16 SDG16b SDG16e |
| M03 commit stops reporting · M04 commit is a no-op · M05 status line silenced · M33 row note silenced · M32 the CIW leg dropped | SDG3b/c/d/e SDG13b · **19 checks** · SDG3c SDG13b · SDG3c · SDG3e |
| M06 menu is a constant three · M07 floor entry dropped · M08 no NOT-measured mark · M09/M46 the floor ignored / unvalidated | 9 · 10 · SDG7d · SDG7f · SDG7g |
| M10 arm ignored · M11 name gate dropped · M12 never disarms · M13 Add does not arm · M31 the namegate note silenced | SDG9c · SDG9 SDG9b · SDG9d SDG16c · 9 checks · SDG9b |
| M14 no pre-fill · M15 pre-fill overwrites · M16 pre-fill is a constant `fold` · M36 pre-fills on an unrecorded probe · M24 a constant staged on open | SDG6 SDG6c · SDG6b · SDG6d · SDG12 · SDG2 SDG6 SDG6d SDG12 **SDG14** |
| M47 a probe THROW leaves the row saying `probing...` · M17 retry when not `ok` · M18 the timeout sentence emptied · M40 the delivers sentence loses its modes · M34/M38 the note never refreshed | SDG12d · SDG12 · SDG12 SDG12b · SDG12c SDG16e · SDG6c SDG16e · SDG16e |
| M19/M21 Cancel stops restoring / no snapshot · M20 restore allowed under a live window · M41 Cancel saves the simrc | SDG5 SDG5c SDG16d · +SDG15b · SDG15b · **SDG14b** |
| M22 Accept stops reading the cmd boxes · **M23c** Accept closes on an invalid value | SDG13 · SDG13b |
| M25 Test button unwired · M26 menu entry unwired · M27 the `<Return>` bind dropped · M28 Cancel button → plain close · M29 Add entry unwired | SDG16 SDG16b SDG16e · SDG16b · SDG16c · SDG16d · SDG16d |
| M30 the profile line not built · M44 `.cmd` renamed (the legacy path contract) · M42 the Exe entry bound straight to `sim()` · M43 `sim_profile_get` reads through the staging area · M45 a probe at row-build time | 10 · 12 · 5 · 5 · SDG4c SDG4d |

**Two mutations came back GREEN and are recorded rather than re-run quietly**: `M23`/`M23b` each removed **one** of `simconf_accept`'s two identical early returns, and the other one still fired — the effective mutation is `M23c`, which removes both. **`M36` and `M39` are the same edit** (added in two rounds); one row, counted once.

**Four test defects were found by mutations that should have gone red and did not, and all four are fixed:** `SDG12` bounded a hung probe by the **clock** (a retry inside 2× the budget passed) and now counts **launches**; `SDG12b` accepted six `ERR:invalid command name` strings as "legible sentences" and now requires each to start `Test: `; `SDG14b` compared a file against the bytes it started from, so a cancel that wrongly saved could not fail, and now carries a live `-textvariable` edit; and `SDG4d` took its no-process baseline **after** the window was built, so a probe fired while building a row was invisible. Three separate mutations (`M44`, `M30`, the master red) also ended the file with **no RESULT line** — the batch's own carry-forward — and the file is now abort-proofed at every widget poke, every `set_sim_defaults` and every arithmetic use of a proc's return (`intof`, `ui`, `menulabels`, `pcall`).

## 6. What was NOT verified

- **A `:0` SUITE DEBT IS RECORDED** (`owed.sh add suite test_sim_dialog`): 19 of the 53 legs drive real Tk widgets — `invoke` on a button and on a menu entry, a real `<Key-Return>` on an entry (`SDG16c`), and a whole-array rollback across a `destroy`. Bare `event generate` key delivery is a known ~1-in-5 WSLg flake and WSLg emits 3 `<Configure>` events where Xvfb emits 1. Everything here runs on `:99` so far.
- **Nobody has looked at it.** Two `look` debts recorded; a green suite discharges neither. Reference captures taken during the work: `scratchpad/item13/simconf{,2}.png` (not committed).
- **The `Reset to default` path is undriven** — it opens a `tk_messageBox` this suite cannot answer — and so is `Cancel` after a reset, which is reasoned only.
- **Six checks survive the MASTER RED** (`SDG1b SDG2b SDG6b SDG4d SDG14b SDG15b`); all six assert that something does *not* happen, trivially true when nothing exists. Their evidence is their own targeted mutation (`M35 M43 M15 M45 M41 M20`), not the master red.
- **The layout is measured, not judged.** Two pixel decisions were driven by measurement on `:99` and are in the spec: the status label needed `-width 1` or its own text sized the whole dialog and clipped every row; and it needed a **line of its own** because 184 px is 26 characters and the Test sentence is 48. Rows are taller as a result — about five fit where nine did.
- **`simconf_default_geometry`**: a user with a saved geometry keeps it, so their dialog opens cramped. Deliberate; discarding a saved geometry is worse.
- **No `Option:`-bearing raw exists to test against**, and no Xyce. The `distinguish` end-to-end used the private `build-ver_50`; the REFUSE end-to-end used `/usr/local/bin/ngspice`.
- **`0502` unchanged**: the dialog routes no path through `ase::expand_path`; `Exe` goes through item 6's `sim_profile_expand_vars`, and commit-time validation makes the hole neither easier nor harder to trip.

---

# 13 — FIX ROUND (three reviewers, thirteen confirmed findings, nine distinct defects)

Three review lenses raised thirteen confirmed findings; deduplicated across
lenses they are **nine distinct defects — six in `src/xschem.tcl`, three
coverage holes in `test_sim_dialog.tcl`** (plus a fourth hole found while
closing them). Every one is fixed. No finding was rejected: all nine reproduced.

`src/xschem.tcl` `md5` at the start of the round **`bb0b78f5d14c5aa08ecf7cd8c550d2aa`**
(the implementer's final — the tree was clean of the peer reviewers' mutations
when this round opened, verified before the first edit), at the end
**`5dcdd51e2926eab39c51f200db252270`**. Byte-exact backups of both, plus the
pre-round test file, are the restore source for every sabotage below — never
`git checkout`, which would have deleted the uncommitted item.

## F1. What was fixed, and the measurement that proved each

| # | defect | severity | fix | spec |
|---|---|---|---|---|
| 1 | `Reset to default` **deletes `~/.xschem/simrc`** and Cancel restores only the in-memory array — while the item's own new Help text and §17.11 both promise Cancel undoes it | major | `simconf_snapshot_take` records the FILE too (`{path … exists … bytes …}`); `simconf_cancel` calls the new `simconf_file_restore`, which is **conditional** so a plain Cancel writes nothing | **§17.13** |
| 2 | `simconf_test_row` does not consume B3's Add arm ⇒ **six process launches for one row** (Test 3 + Accept's `simconf_register_armed` 3), and an Accept that blocks for a second whole probe budget | major | Test clears the arm when the row names an exe — a deliberate Test **is** a registration; an empty Exe box keeps its arm, matching `simconf_row_register`'s `noexe` | **§17.15** |
| 3 | committing a new `exe` **keeps the previous binary's `detected`/`probed`**, so the Case menu offers, and `sim_profile_supports` claims, modes nobody measured — A1 broken on the one edit the dialog exists to make | major | `simconf_commit_row` compares staged `exe`/`args`/`nospiceinit` against stored and **drops the measurement** before writing | **§17.14** |
| 4 | the `use global default (<floor>)` entry is unfiltered, so with a non-`fold` floor it requests a mode the row was measured not to deliver — A1's one seam, and §17.4 claimed the menu was purely `sim_profile_selectable` | minor | new `simconf_mode_floor_label`: the entry reads **`use global default (distinguish - NOT measured)`** when the floor is not selectable for that row. Label, not gate — B1 mandates the entry exists | **§17.4** (new RULING) |
| 5 | A2's `-n` checkbutton has no `-onvalue`/`-offvalue`, so `nospiceinit true` (which `sim_profile_valid` accepts and B1 blesses) **displays UNCHECKED while `-n` is really passed** | minor | canonicalise in `simconf_stage_row` (`[expr {$v ? 1 : 0}]`) + `-onvalue 1 -offvalue 0` | **§17.17** |
| 6 | `wm protocol .sim WM_DELETE_WINDOW` = `simconf_accept 0` — the **X commits** while Cancel beside it rolls back, and goes **inert** when a field is invalid | minor | `WM_DELETE_WINDOW` → `simconf_cancel`; Help text says so | **§17.16** |
| 7 | `simconf_saveconf` is **dead** — a second, divergent save path with none of this item's guards, left as a trap | minor | **removed**, with a comment at the site naming what replaced it. `grep -rn simconf_saveconf src/` had returned the definition and no caller | **§17.11** |
| 8 | **both Accept BUTTONS never invoked as widgets** — emptying both `-command`s left `test_sim_dialog` (53), `test_ase_dialogs` (149) and `test_sim_profiles` (97) fully green | major (test) | `SDG13`, `SDG13b`, `SDG14` now go **through** `.sim.bottom.close` / `.sim.bottom.ok`; new `SDG16f` drives both explicitly | **§17.18** |
| 9 | **`Accept, Save` could write nothing**: `if {0} { save_sim_defaults … }` left 8 suites / 836 checks green, because `SDG14` compared the file against the bytes it had copied there itself | major (test) | new **`SDG14c`**: delete the simrc, edit one field through the widget, require the file back, carrying the edit, with **exactly one line moved** | **§17.18** |
| 10 | B3's fallback registration (`simconf_register_armed` inside `simconf_accept`) uncovered — deleting the call left all 53 green | major (test) | new **`SDG17`** (Add → type an ngspice path → Accept, no Return, no Test → 3 legs) and **`SDG17b`** (the `zzz`-named twin → 0 legs, still committed) | **§17.18** |
| 11 | the `Args` entry's staging unpinned — rebinding it to `sim($tool,$i,args)` bypassed the staging area **and** item 6's validation with all 53 green | minor (test) | **`SDG5e`** pins all four staged fields at their own widget; **`SDG3f`** types `{unbalanced` into the Args box and requires the refusal at the button | **§17.18** |

Findings 1, 3 and 4 were each raised by **two** lenses, and 1 by three; every
duplicate pair is one row above.

**Nothing was changed to appease an unconfirmed finding**, and nothing outside
the confirmed list was touched. The verifier's PROBLEM 2 (the REFUSE advice in
`ase::run_mode_advice` naming a lever the user has already pulled) and its
OBSERVATION (item 5's "the override is not persisted — item 13 owns durability")
were **not** in the confirmed set and are **not** fixed here; both are carried
forward in §F5 below.

## F2. Checks: 53 → 69

`tests/headless/test_sim_dialog.tcl`, band `SDG1`–`SDG22`.
**`RESULT: ALL PASS (69 checks)`** on `:99`; **`ALL PASS (37 checks)`** true
headless (`--nogui`), the two extra model legs being `SDG7h`/`SDG7i`.

Sixteen new: `SDG3f` `SDG5e` `SDG7h` `SDG7i` `SDG14c` `SDG16f` `SDG17` `SDG17b`
`SDG18` `SDG18b` `SDG19` `SDG19b` `SDG20` `SDG20b` `SDG21` `SDG22`.
Four restated (subject changed by a fix): `SDG7f` (now on a row that *can*
deliver the floor, so the plain wording is still pinned), `SDG13`, `SDG13b`,
`SDG14` (all three now driven through the button rather than the proc).

`SDG18` closes the hole the round's worst defect hid in: the `Reset to default`
path was declared "undriven, it opens a `tk_messageBox` this suite cannot
answer", and Cancel-after-reset was declared "reasoned only". **The reasoning
was wrong.** `tk_messageBox` is stubbed for the two legs that need it, renamed
back immediately after; the buttons themselves are invoked.

## F3. Sabotage — 22 mutations, every new and every restated check reddened

Driver `…/scratchpad/fix13/mutate.py`, output `…/mutations.txt`. Each mutation
is an exact literal replacement asserted to hit **exactly once**, applied over
the byte-exact backup, run, then restored and `md5`-verified
(`5dcdd51e2926eab39c51f200db252270`) before the next.

| id | broken | red |
|---|---|---|
| W01 | `simconf_mode_floor_label` never marks | **SDG7h** (1) |
| W02 | it marks unconditionally | **SDG7i** SDG7f SDG7g SDG4c SDG15 (5) |
| W03 | `simconf_mode_floor` returns a constant `fold` | **SDG7f** SDG7h (2) |
| W04 | Args entry bound to `sim($tool,$i,args)` | **SDG5e** SDG13 SDG3f (3) |
| W05b | `simconf_commit_row` skips the `args` field | **SDG3f** SDG3d SDG13 (3) |
| W06 | `.sim.bottom.close` `-command` emptied | **SDG13** SDG13b SDG3f SDG16f SDG17 SDG17b SDG20 SDG20b (8) |
| W07 | both of `simconf_accept`'s early returns removed | **SDG13b** SDG3f (2) |
| W08 | `.sim.bottom.ok` `-command` emptied | **SDG14** SDG14c SDG16f (3) |
| W09 | `if {0} { save_sim_defaults … }` (the reviewer's own reproducer) | **SDG14c** SDG16f (2) |
| W10 | **both** Accept buttons' `-command` emptied (the finding verbatim) | **SDG16f** + 9 others (10) |
| W11 | `WM_DELETE_WINDOW` back to `simconf_accept 0` | **SDG22** (1) |
| W12 | `simconf_register_armed` deleted from `simconf_accept` | **SDG17** (1) |
| W13 | `sim_profile_probe_autoprobe_ok` always 1 | **SDG17b** SDG9 SDG9b (3) |
| W14 | Test no longer consumes the arm (the defect restored) | **SDG19** (1) |
| W15 | Test consumes the arm unconditionally, empty Exe included | **SDG19b** (1) |
| W16 | the measurement-drop disabled | **SDG20** SDG20b (2) |
| W17 | the drop gated on `sim_profile_probe_stale` (the plausible wrong fix) | **SDG20b** SDG20 (2) |
| W18 | the `nospiceinit` canonicalisation removed | **SDG21** (1) |
| W19 | `-onvalue true -offvalue false` | **SDG21** SDG5e SDG13 (3) |
| W20 | `simconf_file_restore` dropped from `simconf_cancel` | **SDG18** (1) |
| W21 | `simconf_file_restore` made unconditional | **SDG18b** (1) |

Sixteen of the twenty-two redden **one to three** checks; every new id and every
restated id appears in bold above; the tree came back `ALL PASS (69)` at the
verified `md5` after the last one.

**W17 is the row that matters most.** It applies the *plausible* fix for
finding 3 — drop the measurement only when `sim_profile_probe_stale` says the
binary moved — and `SDG20b` reddens, because two files with identical mtimes are
exactly what staleness cannot see. That is why the fix compares the stored
**values** and not the file's mtime.

**W15 is the twin for finding 2**: consuming the arm unconditionally is the
obvious over-fix and `SDG19b` catches it.

**One mutation came back GREEN and is recorded rather than quietly re-run.**
`W05` made `sim_profile_valid`'s `args` arm `return 1`, expecting `SDG3f` to go
red. It did not, and it is **not** a coverage hole: `{unbalanced` is refused by
the **persistence round-trip guard** above the field `switch`
(`llength "set v \{$value\}"` raises), so the `args` arm is never reached for
that value. The mutation was mis-aimed, not the check. `W05b` — which makes
`simconf_commit_row` skip the `args` field entirely — is the effective one.

## F4. Suites, audit, and the end-to-end re-drive

`GUI_GATE=1 tests/headless/run_suites.sh` on `:99`, **11/11 PASS**, every count
unchanged except this item's own:

```
test_sim_dialog 69 (was 53) · test_sim_profiles 97 · test_sim_probe 61
test_sim_run_profile 38 · test_ase_dialogs 149 · test_ase_sod_case 52
test_ase_preflight 114 · test_ase_result_case 28 · test_ase_persist 109
test_ase_current_repair 56 · test_raw_case_mode 277
RESULT: 11/11 runs passed
```

**AUDIT** — `GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`,
`DISPLAY` never stripped, nothing else running →
`doc/claude/casemode_batch/audit_item13_fixround_2026-08-18.txt`:

```
SUMMARY: 330 pass  15 fail  0 crash/timeout  0 skip  (total 345)
WIREEDIT: ALL PASS / PASS   SCRATCH: 0 leaked dir(s)
TREE:     0 appeared  0 vanished
```

Diffed by NAME and STATUS with the differ at
`…/scratchpad/fix13/auditdiff.py` (matches only
`^(PASS|FAIL|CRASH|TIMEOUT|SKIP)\s+\|\s+test_\S+$`, so the six within-file
`FAIL | key …` detail lines cannot be miscounted as rows — a naive
`grep -c '^FAIL'` says 21 and is wrong), against **both** relevant baselines:

| vs | rows | only in baseline | only in mine | **status movers** |
|---|---|---|---|---|
| `audit_item12_closer_2026-08-18.txt` (329/15/0/0 of 344, `66d7122f`) | 344 → 345 | NONE | `test_sim_dialog` **PASS** | **NONE — zero rows moved in either direction** |
| `audit_item13_2026-08-18.txt` (the item's pre-fix audit, 330/15/0/0 of 345) | 345 → 345 | NONE | NONE | **NONE — zero rows moved in either direction** |

`test_ase_core` **PASS** on both sides, as the contract requires. The 15 reds
are byte-for-byte the 15 names the batch policy lists. The differ was
self-checked by diffing each baseline against itself (zero movers) and by
reproducing the implementer's own claimed diff exactly.

**END-TO-END RE-DRIVE** (the fix round changed the commit path, so the item's
headline claim was re-measured, not assumed):
`GUI_GATE=1 gated_xschem.sh --script …/scratchpad/fix13/e2e.tcl` on `:99` —
`Add row ▸ spice` invoked from the real menu, the `build-ver_50` path typed into
the real Exe entry, a real `<Return>` fired, the mode picked through the real
menu entry, the default radio invoked, and **`Accept, no Save and Close`
invoked as a widget**:

```
E2E 1 auto-probe detected = fold preserve distinguish
E2E 1b menu = {use global default (fold)} fold preserve distinguish
E2E 3 committed = exe=…/build-ver_50/src/ngspice casemode=distinguish
                  detected=fold preserve distinguish  default=5
E2E 4 run_profile = exe=…/build-ver_50/src/ngspice requested=distinguish status=default
E2E 6 procs observed = ase::run_precheck ase::run_profile ase::sim_probe_run
```

So the dialog still reaches ASE-L's run path, `ase::run_precheck` and
`ase::sim_probe_run` still execute from a pure GUI gesture, and — the thing the
fix round had to prove it had not broken — **finding 3's measurement-drop does
NOT fire on the happy path**: the exe committed at registration equals the exe
at Accept, so the auto-probe's measurement survives. It fires only when the user
really changes the binary, which is `SDG20`/`SDG20b`.

## F5. What is STILL not verified, and what is carried forward

- **STILL `[E]`, and now with FOUR look debts, not two.** The fix round changed
  pixels: a menu entry that self-marks `- NOT measured`, a status line that goes
  *backwards* to `not probed - press Test` after an Exe edit, and two new Help
  paragraphs. Two new `owed.sh add look` entries record exactly what to open and
  what would be wrong; the ledger now stands at **5 suite / 15 look**. **No
  green suite discharges any of them.**
- **The `:0` suite debt for `test_sim_dialog` is unchanged and still open** —
  the round added seven more real-widget legs (`.sim.bottom.reset`,
  `.sim.bottom.ok`, `.sim.bottom.close`, the `WM_DELETE_WINDOW` handler), so it
  wants that run more, not less.
- **NOT FIXED, carried forward (verifier PROBLEM 2, not in the confirmed set):**
  `ase::run_mode_advice` (`src/ase.tcl:990`) keys on `sim_profile_resolve`
  returning status `default`, which it does whenever the ASE session names no
  explicit `sim_profile` — so a row configured **through this dialog** gets the
  REFUSE sentence "This session has NO simulator profile row … or configure a
  profile (Simulation ▸ Configure simulators and tools)". Both clauses are false
  in that case and the second tells the user to do what they just did. Reachable
  by hand-edited `simrc` since item 6; item 13 makes it reachable by gesture. It
  is an `ase.tcl` diagnostic, outside this item's confirmed findings and outside
  its scope fence — **it needs its own item**.
- **NOT FIXED, carried forward (verifier OBSERVATION):** item 5's
  "the override is deliberately NOT persisted — item 13 owns durability"
  (`LEDGER.md:318`). It is named in neither the driver's verbatim scope for item
  13 nor §17, and it is a *viewer* setting, not a simulator profile. Still open,
  still unassigned.
- **`-onvalue 1 -offvalue 0` is belt-and-braces**: Tk's defaults are already
  `1`/`0`, so the explicit values change no behaviour today. `SDG21` asserts
  them anyway (`W19` reddens it) so a later edit to a non-canonical on-value
  cannot pass silently. The behavioural half of finding 5 is the stage-time
  canonicalisation, sabotaged separately as `W18`.
- **A save after an Accept now canonicalises `nospiceinit true` to `1`.**
  Deliberate — the field's domain is boolean — and it cannot touch the frozen
  `simrc_pre_casemode` fixture, which carries no profile fields at all. `SDG14`
  and `SDG14c` still pin byte-stability, and `SDG14c` is the first check that
  can tell "saved identically" from "never saved".
- **Everything else in §6 above still stands**: no Xyce, no `Option:`-bearing
  raw, no C, nothing built, `0502` unchanged (the round added no new path
  expander and no new route to one), and the six MASTER-RED survivors keep their
  own targeted mutations as their evidence.
