# Results batch — eyeball sign-off checklist

Tick as you go. Written 2026-08-20 at HEAD `c46dd590`, after all 10 items landed.

**What this covers:** the **5 `look` debts** this batch owes — item 6 ×1,
item 7 ×2, item 8 ×2. Nothing else in `owed.sh list` belongs to this batch; the
Calculator, casemode and GUI-gate debts are from other work.

**Do all of this on your real screen.** Not `:99`. The point is a human looking
at pixels, and the dev display is invisible.

**Anything that reads badly is a fix, not a sign-off.** Two of these controls
exist *because* a passing check could not judge them — item 7's balloon and item
8's refusal sentence are both invisible to every check in the suite.

**A look debt clears only when you say so.** `owed.sh drain` never touches this
list, and no green suite discharges any line below.

---

## Setup

- [ ] 1. Rebuild so the binary matches the final commit: `cd src && make`.
- [ ] 2. Confirm your display: `echo $DISPLAY` must print `:0`, not `:99`.
- [ ] 3. Back up your config dir, because several steps write to it: `cp -a ~/.xschem ~/.xschem.backup-eyeball`.
- [ ] 4. Start xschem on a design you can simulate: `cd src && ./xschem <your design>.sch`.
- [ ] 5. Open an ASE-L session for it: `Tools ▸ Launch ASE-L`. A new window appears, titled with the cell name.
- [ ] 6. Run a simulation from ASE-L so the session holds a real result. Wait for it to finish before going on.
- [ ] 7. Load a second result too, so the Select dialog has more than one row to show you. Any older `.raw` will do.

---

## A. The Select dialog — debt `results-item7-select-dialog`

Open `ASE-L ▸ Results ▸ Select…`. Leave it open for this whole section.

- [ ] 8. Read the regions top to bottom. Expected order: Loaded, then Recent, then Path with Browse, then a one-line Status, then Select and Close.
- [ ] 9. Judge that order. Loaded is first on purpose, the opposite of Cadence, because switching back to a result you already have is free.
- [ ] 10. Look at the Loaded list. The result the session is using now should carry a coloured bullet in the ASE accent colour.
- [ ] 11. Look at the Recent list. Entries that are already loaded should look visibly different from ones that are not.
- [ ] 12. Say whether "already loaded" is legible at a glance, or whether you have to hunt for the difference.
- [ ] 13. Hover the pointer over a Loaded row and wait. A balloon must appear showing the **full path**; the row itself shows only the file name and analysis.
- [ ] 14. This balloon is the one thing no check in the suite can see. If it does not appear, that is a real defect.
- [ ] 15. Click a row whose result is fine. Read the Status line: it should say something like "Using an.raw." and read as an answer.
- [ ] 16. Click a row whose `.raw` is older than the netlist it came from. The Status line must say it looks stale, and say why.
- [ ] 17. Click a row whose file you have deleted or renamed. The Status line must say it is missing, and must not look like an error crash.
- [ ] 18. Double-click a Loaded row. The waveforms must re-plot, **and the dialog must stay open** with the bullet moved to that row.
- [ ] 19. With the dialog still up, click on the ASE-L window behind it, then on the schematic. Both must stay usable — the dialog is modeless on purpose.
- [ ] 20. Say whether anything in the window reads as cramped, mislabelled, or unfinished at its default size.

```sh
tests/headless/owed.sh clear look results-item7-select-dialog.1787215993.1250610
```

---

## B. The two gestures the fix round changed — debt `results-item7-fixer-round-two-gestures`

Same dialog. These two both looked fine and were both broken.

- [ ] 21. Click into the Path box, type the full path of a real `.raw`, and press Return.
- [ ] 22. **Watch the Status line for a full second.** It must keep the sentence "Selected an.raw (tran)." and must not change afterwards.
- [ ] 23. Before the fix it flipped a quarter-second later to "Using an.raw." — the preview overwriting the answer. If you see that flip, it is back.
- [ ] 24. Now type a path that does not exist and press Return. The refusal sentence must stay on screen, not be erased a moment later.
- [ ] 25. Find a Loaded row whose result is stored relative to the run directory, not as a full path. Click it once.
- [ ] 26. Press Select on that row. It must select. Before the fix it previewed fine and then refused with "No such result file".
- [ ] 27. Press Close. The dialog must go away and the ASE-L window must be untouched.
- [ ] 28. Re-open the dialog and dismiss it with the window manager's X instead. Same result: dialog gone, ASE-L fine.

```sh
tests/headless/owed.sh clear look results-item7-fixer-round-two-gestures.1787221349.1339282
```

---

## C. The Waves refusal box — debt `results-item8-waves-gate-refusal-notice`

Switch Cadence mode **on** first: the `cadence_compat` checkbutton in the Options menu.

- [ ] 29. In the schematic window, click `Waves ▸ Tran`. A modal alert box must appear instead of the result loading.
- [ ] 30. Read the whole sentence. It must say why the entry is blocked, not merely that it is.
- [ ] 31. Check it names `cadence_compat` twice — once as the setting, once as "turn cadence_compat off".
- [ ] 32. Check it points you at `ASE-L ▸ Results ▸ Select`. That menu entry really exists now, so the sentence is not an empty promise.
- [ ] 33. Check the text wraps sensibly and no line runs off the edge of the box.
- [ ] 34. Press OK. The box must dismiss cleanly.
- [ ] 35. Click `Waves ▸ Clear`, then `Waves ▸ External viewer`. Neither may pop a box — neither one loads a result.
- [ ] 36. Turn `cadence_compat` **off** and click `Waves ▸ Tran` again. No box; it loads exactly as it always did.
- [ ] 37. Turn `cadence_compat` back on before the next section.

```sh
tests/headless/owed.sh clear look results-item8-waves-gate-refusal-notice.1787226883.1416066
```

---

## D. The refusal sentence after the fix round — debt `results-item8-fixer-round-refusal-sentence`

Still in Cadence mode. The sentence changed and a second click used to crash.

- [ ] 38. Close every ASE-L window, so you are in a schematic window with no ASE-L session open at all.
- [ ] 39. Click `Waves ▸ Tran` and read the box again. It now adds a clause telling you to open ASE-L from `Tools ▸ Launch ASE-L`.
- [ ] 40. **Judge whether you could actually follow that from here.** That clause is the whole reason the fix round happened.
- [ ] 41. Leave the box open. Now click `Waves ▸ Op Annotate` behind it.
- [ ] 42. The **same box** must retext itself to the new message. Before the fix, Tk threw an "Application error" dialog instead.
- [ ] 43. Say whether a box changing its text under the pointer reads as sane, or looks wrong.
- [ ] 44. Read the Op Annotate reason. It must differ from the Tran one: it adopts a result without going through Select.
- [ ] 45. The first version wrongly said Op Annotate wipes the registry. It does not. Check the new wording does not claim that.
- [ ] 46. Read both reasons side by side and say whether they make sense together, or whether two different explanations is confusing.
- [ ] 47. Check the longer sentence still wraps sensibly and the box is not stretched off screen.

```sh
tests/headless/owed.sh clear look results-item8-fixer-round-refusal-sentence.1787231200.1498145
```

---

## E. The recent-results list after a restore — debt `results-item6-restore-writes-raw_history`

- [ ] 48. Note the current list first: `cat ~/.xschem/raw_history`. It is empty, for the reason in the warning below.
- [ ] 49. Open an ASE-L session, load a result, and save the session so there is a saved state to restore.
- [ ] 50. Close that session and re-open the saved one. The result should come back with it.
- [ ] 51. Open the waveform viewer and click the Location bar drop-down at the top.
- [ ] 52. The restored result must appear in that list **exactly once**.
- [ ] 53. Close and re-open the saved session a second time, then look at the drop-down again.
- [ ] 54. It must still appear **once**, not twice. Re-opening the same session must not stack duplicates.
- [ ] 55. Confirm on disk too: `cat ~/.xschem/raw_history` should now name that result once.

```sh
tests/headless/owed.sh clear look results-item6-restore-writes-raw_history.1787212783.1205018
```

---

## Finish

- [ ] 56. Run `tests/headless/owed.sh list` and confirm no `results-item` debts remain.
- [ ] 57. Delete the backup once you are happy: `rm -rf ~/.xschem.backup-eyeball`.
- [ ] 58. Report anything that read badly. That is a follow-up item, not a sign-off.

---

## Two things you should know before you start

**Your recent-results list is empty, and that is our fault.** During item 4 a
test drive wrote to the real `~/.xschem/raw_history` instead of a scratch copy
and truncated it. There was no backup and nothing anywhere held the old
contents. Section E starts from an empty list for that reason.

**Your recent-files list is rolled back five weeks.** During item 5 the same
class of mistake pushed ten scratch paths through `~/.xschem/recent_files`,
whose list holds only ten entries, so every real entry fell off the end. It was
repaired from a backup dated 2026-07-13, so anything you opened between then and
now is missing from that menu.

Both are recorded in `LEDGER.md`. A snapshot guard now runs before every item,
which is why nothing was lost in items 6 through 10.
