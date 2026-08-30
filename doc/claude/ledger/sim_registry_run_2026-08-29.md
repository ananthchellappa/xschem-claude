# Simulator registry + capability run 2026-08-29 — items S1–S4 (branch `annotate`)

The user's ask, verbatim: *"add ability to register (and remove) simulator that is
not on the PATH both through ASE-L GUI and rc file. Then add this detection
capability and ability to use it to save all device OP info without dumbness. As
good as spectre"*

Status codes: **x** done+verified+committed · **F** failed (tree clean, nothing
committed) · **D** deferred (blocked; nothing committed) · **E** landed but needs a
human eyeball (GUI-only proof, or an unratified user-visible behaviour change)

| item | status | commit | tests | new issues | one-line result |
|---|---|---|---|---|---|
| S1 | E | 439d1087dcc8c443213caa6c880a3092081bc54e | measured by me at this code: test_ase_simreg_0931 48 (ALL PASS + OVERALL: ok), test_ase_core 182 (ALL PASS), both exit 0; measured at the same code by the repair pass: test_ase_final 80, test_ase_final_gf180 34, test_ase_cosim 341, test_annot_blank_cause_0909 27, test_ase_view 36, test_ase_persist 109, test_ase_plot 150, test_ase_window 228, test_ase_dialogs 174, test_wave_viewer 401 with --nolog / 404 with --logdir, T1 47 blocks all reading zero | 0932, 0933, 0934, 0935, 0936 | One mistyped simulator path now takes your working PATH ngspice out of service until you fix it, because the first entry you register goes into force even when its file is bad - should only a validated entry ever be put in force, or is stopping every run the right answer? |
| S2 | E | (uncommitted at the time of writing — the write-up agent commits) | measured by me at this code: test_ase_simdlg_0937 4 headless / **23 on the dev display** (ALL PASS + OVERALL: ok), test_ase_simreg_0931 **58** (was 48; ALL PASS), test_ase_core 182, test_ase_final 80, test_ase_final_gf180 34, test_ase_cosim 341, test_annot_blank_cause_0909 27, test_ase_plot 150 (dev display; 30 headless — its GUI legs self-skip), test_ase_view 36 and test_ase_persist 109 (dev display; 32 / 17 headless, same reason — issue 0936's trap), test_ase_window 228, test_ase_dialogs 174, test_wave_viewer 401 with --nolog, T1 **49 blocks all reading zero**, 0 launch failures, 0 NODISPLAY | 0932 FIXED, 0933 half fixed (the sentence, not the storage); **0938 (a REGRESSION this item caused), 0939, 0940, 0941, 0942, 0943, 0944 filed at write-up** | Setup > Simulators… is the door: the registered simulators with the reason any one of them cannot be started, Add / Edit / Remove, and “use this one” with “(none — use the program my system finds on the PATH)” first. It saves through S1's writer on every gesture, so what you register is there at the next start; removing the one in use now says what takes over; and the dialog shows the CIW's own sentences, never its own wording. NOBODY HAS SEEN IT — a look debt is recorded. **AND IT SHIPPED WITH SEVEN KNOWN DEFECTS, one of them a regression of ours (0938): a runnable simulator whose path contains a literal dollar sign is now refused.** |

## S2 repair pass — five guards nothing could see

The sabotage pass on S2 returned **FAIL**: four guards could be deleted with both
suites staying fully green, and one predicted red (the dialog's Problem column)
turned out to be a tautology. All five are now measured. Nothing in `src/` was
changed to satisfy any of them — the guards were right, the rows were missing.

| what could be deleted with everything green | the row that now sees it | proved by |
|---|---|---|
| the body of `ase::sim_entry_why` (the per-entry reason) | **S2**, two new terms that do not mention the mint at all: each broken entry's Problem cell must carry words, and must name that entry's own program | blanked the proc → `S2 … 0 0 1 1`, 24/25 |
| the `ase: ` prefix strip in `ase::ui::simdlg_plain` | **S6**, `ase: ` (one colon, a space) added to the jargon list it scans the row editor's message for — `ase::` could never match it | deleted the strip → `S6 … JARGON-ase: `, 24/25 |
| `array unset dlg $key,*` in `ase::ui::close` | **S18**, new: leave the Simulators window standing and close the ASE-L session window out from under it, which is the only way to reach that cleanup — S15's ESC has already run `simdlg_close`, which drops those records itself | deleted the line → `S18 … simnames` left behind, 24/25 |
| `catch {unset simuse($key)}` in `ase::ui::close` | **S18**, same row, last term: the picked simulator is remembered per session on purpose, so the session ending is when it has to go | deleted the line → `S18 … 1`, 24/25 |
| the permission restore in `ase::sim_write_conf` | **R12**, new in the registry suite: put 0600 on your own saved list, save again, it is still 0600 | deleted the line → `R12 … 0644`, 59/60 |

One promise had no row either, and it is the reason the writer was rewritten in
the first place: **a save that cannot happen must leave the list you already had
exactly as it was.** `R11` is new and behavioural — it makes the save impossible
in a way that works for root too (the file the writer builds beside the real one
is already a directory) and then asserts the saved list is byte-identical, does
not mention what was just added, and that the user got the "could not be saved"
sentence. Reverting the writer to truncate-in-place reds it (`R11 … 1 0 1 0`,
59/60), so that deviation is now pinned from both ends: `S11` for the reporting,
`R11` for the durability.

Three of the sabotage pass's other observations needed no change and are recorded
rather than acted on: `V7`/`S17` (the recorder is still covered by five other
rows), `V15`/`S12` (the plan's claim was wrong; `S13` covers it, and `S12`'s own
"once, not twice" is about the menu interceptor and is true), and `V5`/`R7`
(declared in advance — the list and the resolver are wrong together, which is why
`R5` is worded about the sentence).

**Counts after the repair**, measured on this tree: `test_ase_simdlg_0937`
**25** on the dev display (4 headless, structural rows only), `test_ase_simreg_0931`
**60** headless. Tier list all at baseline: test_ase_core 182, test_ase_final 80,
test_ase_final_gf180 34, test_ase_cosim 341, test_annot_blank_cause_0909 27,
test_ase_view 36, test_ase_persist 109, test_ase_plot 150, test_ase_window 228,
test_ase_dialogs 174, test_wave_viewer 401 (--nolog). T1: exit 0, 49 blocks, every
one `Total num fail: 0`, 0 counted failures, 0 launch failures, 0 NODISPLAY.


## S2 write-up pass — seven defects filed, and one of them is ours

The write-up agent reproduced every one of these first-hand on the built
`src/xschem` before filing it; none is taken on report. **No product code was
changed to fix them** — the house rule is to file, not to fix silently, and a fix
at write-up time would ship code that no sabotage pass had seen. One **comment**
in `src/ase.tcl` was corrected, because it asserted the exact opposite of 0938
and the next reader would have trusted it.

| issue | what a user does | what happens | why no row saw it |
|---|---|---|---|
| **0938** REGRESSION, ours | registers `$::PDKROOT/bin/ngspice` where the root has a literal `$` in a folder name | registers clean (`rv 1`, `ok 1`), file **is** runnable, then the run is refused: `ok` 1→0, `resolved` empty, `sim_exe` raises "mentions a setting this session does not know about" — about a path mentioning no setting | R7 compares the list against the run; after this change they are wrong **together** |
| **0939** | edits a simulator their xschemrc declares | `origin` laundered `rc`→`session`, entry enters the saved list, the rc no longer governs it, ever — and nothing says so | S9 uses session-origin entries only |
| **0940** | presses **Add…** with a name already in the list | silently replaces it, wipes `-args` and `-backend`, reports success | this is the defect **S9** exists to prevent, reachable through the other button |
| **0941** | removes an in-force simulator their startup file declared | the program that runs changes silently; the only sentence shown is the rc one | `sim_said` holds ONE string and the rc sentence is said LAST (row R4); S8a/S8b use session entries only |
| **0942** | has `~/.xschem/ase_simulators` symlinked to a shared list, then saves | the link is replaced by a plain file, the shared list is orphaned, save reports success | no row saves through a symlink |
| **0943** | has a writable list in a read-only folder | the save is **refused** where the old writer succeeded; the internal `.new` name leaks into the sentence; the dialog says "could not be saved" above a label still saying "your list is saved in …" | S11 asserts the *reporting*; nothing asserts a save the old writer managed still works |
| **0944** | registers an entry for another backend | Problem column is **blank**; the entry is unusable the moment it is picked, and the sentence for it already exists | `sim_entry_why` validates the path only |

**0938 and 0943 are on the user's ruling queue**, because both are live
behaviour changes with a trade only the user can settle: a wrong sentence in a
rare arm versus a refusal to run a working simulator (0938), and an atomic save
that is safer but narrower (0943). 0939–0942 and 0944 are defects, not choices,
and are filed for whoever picks them up.

**Verified at write-up, on this tree, after the comment correction:**
`test_ase_simreg_0931` **60** headless and `test_ase_simdlg_0937` **25** on the
dev display, both `ALL PASS` + `OVERALL: ok`, exit 0. `grep -rn SABOTAGE src/`
empty. `full_audit.sh` registration is deliberately 0 — it auto-discovers every
`tests/headless/test_*.tcl` at line 393 and `nogui_tests` only selects the
`--nogui` **arm**, so listing a Tk suite there would strip its GUI rows;
`test_ase_dialogs` is absent for the same reason. `run_regression.tcl`
registration is 2 (hcases + the 0891 display arm).
