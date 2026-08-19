# Casemode batch — eyeball sign-off checklist

Tick as you go. Written 2026-08-18 at HEAD `9c14b829`, after all 16 items landed.

**What this covers:** the **10 `look` debts** this batch owes (items 5 ×2, 13 ×4,
14 ×2, **issue 0506 ×2**) plus the one `:0` **suite** debt (`test_sim_dialog`).
Nothing else in `owed.sh list` belongs to this batch — the Calculator and GUI-gate
debts are from other work.

**Updated 2026-08-18** with §0506: the batch closed with the profile dialog
measuring one binary and the plain **Simulate** button running another. That is
now wired, and steps 48–59 are the part that proves the whole point — a schematic
net `EN` arriving in the viewer as `v(EN)`.

**Do all of this on your real screen.** Not `:99`. The whole point is a human
looking at pixels, and the dev display is invisible.

**Anything that reads badly is a fix, not a sign-off.** Several of these controls
exist *because* a passing check could not judge them — item 5's radios were a dead
control that left 113/113 green.

---

## Setup

- [ ] 1. Back up your simulator config: `cp ~/.xschem/simrc ~/.xschem/simrc.backup` — step 30 deletes it on purpose.
- [ ] 2. Record the original: `md5sum ~/.xschem/simrc` and `ls -l ~/.xschem/simrc`. You compare against these at step 32.
- [ ] 3. Rebuild so the binary matches the final commit: `cd src && make`.
- [ ] 4. Confirm your display: `echo $DISPLAY` must print `:0`, not `:99`.

Original md5 / mtime, write them here:

```
md5:
mtime:
```

## Clear the suite debt first — this one is automated

- [ ] 5. Run `AUDIT_DISPLAY=:0 tests/headless/run_suites.sh test_sim_dialog` and wait.
- [ ] 6. The gate panel will pop. Press **Forever** once so nothing else asks you again today.
- [ ] 7. A pass clears the debt by itself. On a failure, re-run once — key delivery flakes ~1-in-5 under WSLg.

## Item 5 — waveform viewer Case Mode (2 debts)

- [ ] 8. Start xschem, open a design with simulation results, open the waveform viewer.
- [ ] 9. Open the viewer's `Options` menu, then the `Case Mode` submenu.
- [ ] 10. Read the greyed readout line. Does "Case mode: unknown — nothing could tell" make sense? Do the em-dashes render?
- [ ] 11. Look at the four radios: auto, fold, preserve, distinguish. Is the tick actually visible against the ASE theme?
- [ ] 12. Click each of the four. The readout line above must change to match every time.
- [ ] 13. Judge "auto (use what was detected)" as a menu label — sensible, or too long and cryptic?
- [ ] 14. Set an override to something other than auto, then re-run the simulation.
- [ ] 15. Reopen the submenu. The tick must still be on your setting, and the readout must still say "your setting".

Clear when satisfied:

```sh
tests/headless/owed.sh clear look waveform_viewer_Options___Case_Mode_cascade.1786937827.2538960
tests/headless/owed.sh clear look waveform_viewer_Case_Mode__the_radios_actually_bite__and_the_tic.1786942481.2627888
```

- [ ] 16. Both item-5 debts cleared.

## Item 13 — Simulator Configuration dialog (4 debts)

- [ ] 17. Open `Simulation > Configure simulators and tools`. Every row now has a second line: Exe / Args / Case / -n / Test.
- [ ] 18. Judge readability at the shipped size. About five rows fit where nine did. Too cramped, or acceptable?
- [ ] 19. Note the profile line appears on the wave-viewer tools too (gaw, gtkwave, bspwave), where an exe means nothing. Honest, or noise?
- [ ] 20. Read the "use global default (fold)" menubutton. Is it obvious it means "this profile names no mode"?
- [ ] 21. A row with no executable has a deliberately blank status line. Does that row look unfinished, or clean?
- [ ] 22. "Add row" is a menubutton listing seven tools. Does it read as an Add button?
- [ ] 23. Point a row's Exe at `/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice` and press **Test**.
- [ ] 24. Read "Test: delivers fold preserve distinguish (51 ms)". Reads as an answer? Does the millisecond figure belong there?
- [ ] 25. Open that row's Case menu. It must offer **all three** modes — this is the case-capable build.
- [ ] 26. Now point the same row's Exe at `/usr/local/bin/ngspice` and press **Test**.
- [ ] 27. Read "Test: no casemode support — fold only". Information, or breakage, to an ordinary apt-install user?
- [ ] 28. Open the Case menu again. It must offer **only fold**. Can you tell *why* the list shrank?
- [ ] 29. Put `set sim_case_mode distinguish` in an rc, restart, press Test on the stock row, open the Case menu.
- [ ] 30. First entry must read "use global default (distinguish - NOT measured)". A warning, or a broken-looking parenthesis?
- [ ] 31. Press Test on a row, retype its Exe to a different path, press Accept, reopen the dialog.
- [ ] 32. The row must now read "not probed - press Test". Correct, or does it look like the dialog forgot something?
- [ ] 33. Press **Help**. Read the two new paragraphs: Cancel restores the simrc file; editing Exe discards the measurement.
- [ ] 34. Press **Reset to default** and confirm. The rows must visibly change to the built-in defaults.
- [ ] 35. Press **Cancel**. Your own rows must come back.
- [ ] 36. **The one that shipped a false promise** — check the file really returned: `md5sum ~/.xschem/simrc` must equal step 2, and mtime must be recent.
- [ ] 37. Restart xschem. Your rows must still be there. Before the fix they were gone at exactly this point.
- [ ] 38. Reopen the dialog, edit any field, press the titlebar **X**. The edit must be discarded and the window must close.

Clear when satisfied:

```sh
tests/headless/owed.sh clear look casemode_item_13_____the_Simulator_Configuration_dialog_s_new_pr.1787049897.194128
tests/headless/owed.sh clear look casemode_item_13_____the_Test_button_s_answer__and_the_Case_menu.1787049911.194161
tests/headless/owed.sh clear look casemode_item_13_FIX_ROUND_____the_three_new_changed_sentences_i.1787055179.278262
tests/headless/owed.sh clear look casemode_item_13_FIX_ROUND_____Reset_to_default__then_Cancel__is.1787055179.278274
```

- [ ] 39. All four item-13 debts cleared.

## Item 14 — netlist collision warning (2 debts)

- [ ] 40. Open `xschem_library/examples/test_bus_tap.sch`. It genuinely carries both `VCC`/`vcc` and `VSS`/`vss`.
- [ ] 41. Netlist it with default settings. The warning should fire twice.
- [ ] 42. Read the ERC-window sentence. Does it name the right two nets and the right cell?
- [ ] 43. Look at the canvas: the two colliding nets should be painted, one colour per pair. Right nets highlighted?
- [ ] 44. Does that highlight colour read as a **warning**, or just like ordinary selection?
- [ ] 45. Read the one-line status-bar summary. Sensible, and does it fit without truncating?
- [ ] 46. Look in the CIW for the relayed ngspice line, in the dark-orange "note" colour. Legible?

Clear when satisfied:

```sh
tests/headless/owed.sh clear look casemode_item_14_____read_the_two_new_user-facing_lines_in_situ.1786961881.2960820
tests/headless/owed.sh clear look casemode_item_14_fix_round__the_netlist-time_collision_warning_s.1786968458.3058594
```

- [ ] 47. Both item-14 debts cleared.

## Issue 0506 — the profile actually reaching the run (2 debts)

**This is the goal.** Everything above proves parts; this proves the whole chain.
A fixture is committed for it: `doc/claude/casemode_batch/eyeball_en_goal.sch`,
whose only interesting feature is a net labelled **`EN`** in capitals.

- [ ] 48. Confirm you have a case-capable ngspice. Stock 46 **cannot** do this — it lower-cases at parse time and the capital is gone before xschem sees the file.
- [ ] 49. Open `Simulation > Configure simulators and tools`. On the **Ngspice batch** row set Exe to your case-capable binary and press **Test**.
- [ ] 50. Set that row's **Case** to `preserve`, make it the default row, then **Accept, Save**.
- [ ] 51. Open `doc/claude/casemode_batch/eyeball_en_goal.sch` and netlist it. The deck must read `V1 EN 0 1.5` — capitals, verbatim.
- [ ] 52. Press **Simulate**. Watch the CIW for the note: `Simulator profile case mode: appending -D casemode=preserve -D casemodewrite`.
- [ ] 53. Judge that note. Useful confirmation, or noise on every single run once you have configured a mode?
- [ ] 54. Open the waveform viewer and look at the **signal browser list**. It must show `v(EN)`, not `v(en)`. **That is the goal.**
- [ ] 55. Open `Options > Case Mode`. The readout must now say **preserve**, not "unknown — nothing could tell". Before this change it could never say anything else.
- [ ] 56. Now the error paths. On the **Ngspice interactive** row (the one whose command starts with `$terminal`) set an Exe and set Case to `preserve`, Accept, and Simulate.
- [ ] 57. Read the two red CIW lines: the executable was not used, and the case mode had nowhere to go. Do they tell you what to actually do about it?
- [ ] 58. Judge their length. They are long by CIW standards — deliberately, because a short version of either reads as a mystery. Too long in practice?
- [ ] 59. **The compatibility check.** Clear the Exe and set Case back to the global default, Accept, Simulate. The CIW must say **nothing new at all** — a user who configured nothing must see no change.

Clear when satisfied:

```sh
tests/headless/owed.sh clear look issue_0426_-_the_three_new_CIW_lines_in_situ__declined_exe___unp.1787083043.493534
tests/headless/owed.sh clear look issue_0426_-_the_whole_goal_end_to_end__net_EN_-__Simulate_butto.1787083043.493546
```

## Finish

- [ ] 60. `tests/headless/owed.sh list` — confirm no casemode debts remain.
- [ ] 61. Restore config if anything went wrong: `cp ~/.xschem/simrc.backup ~/.xschem/simrc`.
- [ ] 62. **Decide issue `0501`** — see below. You saw the warning fire at step 41; that is the decision point.
- [ ] 63. Report anything that read badly. That is a follow-up item, not a sign-off.

---

## The one judgement call that is yours, not a defect

**Issue `0501`.** `xschem_library/examples/test_bus_tap.sch` is a **shipped
example** and it really does name `VCC` and `vcc`, `VSS` and `vss`. So item 14's
warning fires on it, and **the warning is correct** — under the default `fold`
mode those are one node to the simulator and two nets to xschem.

Two defensible answers, and nobody has picked one:

- **Rename in the example** (`vcc`→`VCC`, `vss`→`VSS`). The example goes quiet and
  demonstrates the good habit. Requires checking the file's `T` records and any
  doc text that names the supplies.
- **Leave it.** Every user who netlists that example meets the warning on day one,
  which is arguably a useful live demonstration of what it is for — and arguably
  just noise in a file about bus taps.

Also unswept: **nobody has checked the rest of `xschem_library/`** for other
collisions. This one was found because the check fired on it, not by searching.

## Also worth knowing before you sign off

- **Nothing is pushed.** 37 commits sit on `fluid-editing`.
- **Issue `0502` is a code-execution surface, pre-existing and unfixed.**
  `ase::expand_path` runs a command substitution hidden in an array index, so
  opening an ASE-L state file someone else wrote can execute arbitrary commands.
  Item 6 guarded its own new field; the three original call sites are untouched.
- **Nine issues filed:** `0418` `0419` `0500` `0501` `0502` `0503` `0504` `0505`
  by the batch, and **`0506`** after it — the plain Simulate path ignoring the
  profile the dialog had just measured, now fixed (steps 48–59, spec
  `simulator_profiles.md` §18, 27 checks in `test_sim_plain_run.tcl`). `0504` and `0505` came out of item 13 and are the two most likely
  to annoy you in the dialog you are about to open — `0504` is a message that tells
  a user who just configured a profile to configure a profile.
- **Audit result, verified by diffing name and status against the pre-batch
  baseline:** 14 rows added, **zero statuses moved**. All 14 are suites this batch
  wrote.
