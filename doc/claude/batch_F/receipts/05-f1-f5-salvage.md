# Batch F item 5 — F1 + F5 SALVAGE: the verilog-only branch, and the notice that says why

**Verdict [E]** — the payload is rendered text in a pane, so a human must look. **Attempt 1's `[F]` is SUPERSEDED**: `fda9d5a8` (never verified, never reviewed — its implementer,
verifier and all three reviewers died mid-stream) was read in full, judged **salvageable** and finished on top; nothing reverted. Both earlier receipts stay as the record. Full
rationale for every ruling below is in `doc/claude/specs/mixed_signal_signal_browser.md` §F; this receipt is the evidence.

## 1. Files changed

`git diff --stat` on `fda9d5a8` — 5 files, **582 insertions(+), 24 deletions(-)**; `--cached` empty until the commit, nothing dirty beforehand staged. `src/ase.tcl` +112,
`src/wave_viewer.tcl` +55, `tests/headless/test_ase_cosim.tcl` +112/-2, `…/test_wave_sigbrowser_digital.tcl` +189/-1, `doc/claude/specs/mixed_signal_signal_browser.md` +114/-21.
Committed with them: `issues/0308-…md` (84), `0309-…md` (96), `receipts/05b-f1-f5-salvage.md` (625), this receipt.

## 2. Decisions, and the evidence

**D1 — salvageable, not revertible.** Step 3b's ⚠ comments are byte-identical to their pre-item form and the order is now *asserted*: `FV33` watches the live call order, `FV39`
the source layout; moving the step-3c probe below `wviewer::open` reddens both (9 checks), so a reordering cannot satisfy one witness by breaking the other. F5's causes were read
against item 4's REAL code, not the notice: `notloaded` `ase.tcl:1878`, `notraced` `:1862`, `nomap` `:1637` (minted in `cosim_map_match` after all four rungs miss), `noscope`
`:1735` wrapped `:1885`, `nopane` `:2644`.

**D2 — RULING F1e: the SUCCESS path has an empty pane of its own and must say the true thing.** Measured on the real viewer: after a *successful* re-scope the pane lists nothing
(drawn from `browserseaent`, the current DB alone — item 15's `BD70d` limit) and the shipped `seaempty` arm captions it `'TOP.m' has no signals of its own`, about a scope with
two — exactly what F5 forbids, an empty pane with a WRONG reason. Fixed as step 7b + `ase::browser_pane_unread` + `wviewer::browser_sea_empty`; gated on the PANE, sentence
composed where the fact is decided (the resolver answered `ok`), tag `note` not `error`.

**D3 — RULING F1f: the notice must outlive the refresh its own gesture queued. THE BLOCKER THE REVIEW FOUND — it invalidated D2's own deciding measurement.** `browser_reveal`'s
`$tv selection set` only QUEUES `<<TreeviewSelect>>`; the bind runs `browser_sea_refresh`, whose first act is `set browserseanote($token) {}` and whose last re-captions from
`seaempty` — delivered the instant the Ctrl-Alt-V binding returns. Measured: on return the caption held the notice, one `update` later it read the falsehood again, and **the same
defect hit F5's ORIGINAL refusal notice inherited from `fda9d5a8`**. Same cause, second consequence: step 7b's predicate read the pane the user had just LEFT. Fix: one `catch
{update}` at step 6c, below every call that can move the tree and above the notice — `update`, not `update idletasks` (the virtual event is on the main queue and `browser_reveal`
already calls idletasks without delivering it). `FV46` pins the source position; `FD23`/`FD24`/`FD27` drive the real command and read the surfaces AFTER the turn.

**D4 — `browser_sea_empty` asks BOTH halves** (`FD26`). `browsersea` is the FILTERED set, so an empty one has two causes; calling a bar-hidden node "empty" replaced the shipped
TRUE caption `0 of 2 signals (the Search/Filter bar is hiding them)` with a sentence blaming a foreign database. It now answers 1 only when nothing is drawn AND `browser_sea_own`
(unfiltered) is 0.

**D5 — the sentence names WHERE THE TREE LANDED (`[lindex $res 2]`), not the scope asked for** (`FV45`): they differ on a `partial`, and naming the asked scope contradicted the
CIW line written one statement earlier. **A `partial` still GETS the notice** (guard `$done`) — the reviewer's gating half was deliberately NOT taken, because an ancestor in a
foreign VCD lists exactly as little, so suppressing the arm restores the false `seaempty` caption on that very path.

**D6 — three things ruled as tracked, not fixed.** A `partial` that ticked All-DBs reports `partial`, so it grows the tree without saying so — an omission, nothing false: **issue
0309**, and the salvage's "near-unreachable" claim is WITHDRAWN in the spec (the review hit it first try). The pane still lists nothing after a successful F1 — F3's job, **issue
0308**, which also records that F1e's arm must be DELETED when F3 lands. And the spec's H7 row was stale after the review-fix pass (40 FV / 18 FD / 65 checks): corrected to 46 FV
+ 25 FD + `BK33` = **72**, with the 13 `S1`–`S13` patches recorded — a spec asserting counts the tree lacks is this item's own named failure mode.

## 3. Tests, check counts, VERBATIM RESULT lines

`test_ase_cosim.tcl` (`--nogui`; FV = 46 ids) · `test_wave_sigbrowser_digital.tcl` (Tk/X) · `test_wave_sigbrowser_keys.tcl` (Tk/X, owns `BK33`; `BK40` is the known focus flake):

```
PASS     | test_ase_cosim               run 1/1  RESULT: ALL PASS (310 checks)
PASS     | test_wave_sigbrowser_digital run 1/1  RESULT: ALL PASS (25 checks)
PASS     | test_wave_sigbrowser_keys    run 1/3  RESULT: ALL PASS (48 checks)
```

### AUDIT — a DIFF against `doc/claude/batch_F/baseline_status.txt`, never a red count

Baseline EXISTS (`7a592f9c`, 364 rows, `DISPLAY=:0`). This run: `full_audit.sh`, `DISPLAY=:0`, `GUI_GATE=1`, panel live and untouched, `control=RUN` throughout. `SUMMARY: 273
pass 32 fail 2 crash/timeout 0 skip (total 307)`, `WIREEDIT: ALL PASS`, `SCRATCH: 0 leaked dir(s)`.

**NEW (1)** `test_wave_sigbrowser_digital` → PASS, the file this item adds. **RED → BETTER (7)** `test_fluid_bodyshove_guards_0132`, `test_fluid_editing`,
`test_wave_crossdb_trace`, `test_wave_sigbrowser_i12`, `test_wire_vertex_grab` FAIL→PASS; `test_rotate_stretch_dangling_0103` SKIP→PASS; `test_ase_plot` TIMEOUT→FAIL (red→red
flavour, its documented flake). The same set every pass in this batch reports — collateral of the X death DURING the baseline run, recovering; not this item. **GONE (58)** every
`test_wireedit_*` row: a PARSING ARTIFACT — that section prints in another format, and all 58 files read `RESULT: ALL PASS` under a `WIREEDIT: ALL PASS` summary. **GREEN → WORSE
(11), with failing ids** `test_ase_dialogs` PASS→TIMEOUT {GE1 GE3 GE4 GE6 GE8 …}; `test_ase_interact` {I7}; `test_cmdmode_descend_0201` {DS7b DS7b2 DS7b3 DS7c};
`test_multi_window` {MWf}; `test_wave_modes` {MG16}; `test_wave_sigbrowser` {BT25 BT26 BT27 BT29}; `…_i1315` {BR25}; `…_keys` {BK40}; `…_sea` {BQ53 BQ65 BQ66 BQ66b BQ71 BQ72
BQ73}; `test_wave_tabs` {TG16}; `test_wave_viewer` {G5 G6 G9a}.

**CARRY-OVER ENDED — none of the 11 is a regression from items 1-5, on three legs.** (a) EVERY failing line is an explicit key/focus-DELIVERY precondition in its own words: "ESC
dismisses … → {0} (exp {1})", "a REAL E keypress armed the pick (got 0 want 1)", "new window focuses its canvas (keys reach it) (focus=)", "the disabled-key probe was actually
delivered → {0}", "the keystrokes were really delivered", "a real Ctrl-W closed the tab → {0}" — the documented WSLg flake; in `test_wave_sigbrowser` the rest of each tuple is
exactly the state of a pane nobody typed into. (b) BK40 PROVEN FLAKY IN THIS SESSION, one tree, minutes apart: PASS, FAIL, PASS, FAIL, FAIL over four runs. (c) PAIRED
BASE-REVERT, mine: with `src/ase.tcl` + `src/wave_viewer.tcl` + `src/ciw.tcl` written from `git show 7a592f9c:` (removing ALL of items 3/4/5), `test_wave_sigbrowser_keys` fails
**3 of 3**, BK40 red in 2 — it fails MORE at the baseline commit's own code than at HEAD, which reproduces the fixer's 12-run experiment (`…sigbrowser` and `…_sea` red 6/6 at
base). Restored from a byte-exact backup, `md5sum -c` OK, both item suites green afterwards. **MEMBERSHIP IS CHURN, THE FAMILY IS THE FINDING:** three audits of the same tree
gave three sets of 10-11, differing on `_panes`, `ase_interact`, `wave_tabs`, `wave_viewer`. **RECOMMENDATION: re-baseline on the current display** rather than litigate a fourth
time — the baseline records `…sigbrowser` and `…_sea` as PASS, yet both are red 6/6 at that very commit. All three suites reaching `show_in_browser_for_current` are green, `BK33`
included.

## 4. Sabotage table — one row per NEW check (14)

Each patch applied ALONE, reverted from a byte-exact backup, `md5sum -c` after every restore; never `git checkout --`.

| check | what was broken | red? | restored green? |
|---|---|---|---|
| FD23 | step 6c `catch {update}` DELETED (S1) | yes, +FD24 | yes |
| FD24 | S1; and separately the 7b arm neutered to `elseif {0}` (S8) | yes | yes |
| FD27 | step 6c flush deleted again, FD27 present (S13) | yes, +FD23/24 | yes |
| FV46 | S1 (flush deleted) and S2 (flush MOVED above step 6) — two legs | yes | yes |
| FD25 | `set browserseanote($token) {}` cut from `browser_sea_refresh` (S5) | yes, +FD03/22 | yes |
| FD26 | `browser_sea_empty` reverted to the conflating one-liner (S3); also S7 | yes, alone | yes |
| FD19 | `browser_sea_empty` forced `return 0` — always "not empty" (S6) | yes, +FD23/24 | yes |
| FD19b | `browser_sea_empty` forced `return 1` — always "empty" (S7) | yes, +FD23/26 | yes |
| FD10b | `wviewer::browser_toggle` forced `return 0` on both exits (salvage D10b) | yes, alone | yes |
| FV41 | 7b arm guard replaced by `} elseif {0} {` (S8) | yes, +FV42/45 | yes |
| FV42 | S8; and the composed sentence replaced by a refusal-worded one | yes, alone | yes |
| FV43 | pane predicate dropped from the 7b guard — fires on every success (S9) | yes, +FV32 | yes |
| FV44 | `browser_pane_unread` made non-total: `info commands` guard + `catch` gone (S10) | yes, alone | yes |
| FV45 | sentence built from `[lindex $dig 2]` (asked) not `[lindex $res 2]` (landing) (S4) | yes, alone | yes |

**Unsabotaged, therefore not evidence: NONE — every new check has a row.** Inherited checks whose subject this pass changed were re-sabotaged (evidence, not new rows):
`FD03`/`FD22` (S5), `FV32` (S9/S11), `FV12`+`FS42` (S12), `FV33`+`FV39` (S11). Across the salvage pass (54 patches) and this one (13) **all 72 checks the item owns go red under
at least one**. Two salvage patches reddened nothing, both named in the spec's H7 row (`S04` defence-in-depth, `S24` mis-aimed); `S04b`/`S24b` redden `FV4`/`FV5`, `FV34`/`FV40`.

## 5. What was NOT verified

**EYEBALL OWED — this is the [E].** (1) Ctrl-Alt-V on a code block: the caption must STILL read "showing the digital scope '…' of '….vcd' in the tree, but the lower pane lists
only the current results database…" *a second after the gesture*, not `'…' has no signals of its own` — the defect just fixed was a caption correct for exactly one frame, so
look, then keep looking. (2) The same on the refusal path. (3) Whether that long sentence CLIPS on the caption and the sidebar status line at default width AND with the sash
dragged narrow — no check can answer it, and whether F5 needs a short form is unsettled. (4) The CIW pair reading as one account, the `note` colour as a caveat.

**Raised by reviewers, NOT confirmed, carried forward:** the suspected tick-leak in `browser_show_db_scope` (the untick runs only on the `browser_row_exists` failure, not the
later `matched == 0` return) — asymmetry established, reproducer not; whether step 7b is reachable end-to-end with a Search/Filter bar active (D4's accessor-level defect is
measured, the product-level consequence inferred from one call site); whether the sidebar status line RETAINS the notice — a probe captured only line 1 of that two-line label.
**Not verified at all:** no real co-simulation ran (both suites synthesize with `mkraw`/`mkvcd`, so Verilator's real scope naming is untested, as in attempts 1 and 4);
`browser_pane_unread`'s success path runs through a stub in the FV arm, the real reader only in FD19/FD19b/FD23/FD24; two paths F1e's arm does not cover stay open, both issue
0308's — a foreign row selected BY HAND still gets the false `seaempty` caption, and item 15's `BD70d` foreign-root case still shows the current DB's names. **Known hazard,
documented not hidden:** step 6c's `catch {update}` re-enters the Tk event loop inside a key binding and can process a second Ctrl-Alt-V; it is at the tail so only the notice
write follows and every proc after it is total, so the worst case is cosmetic. **Process fault, so it is not repeated:** one reviewer measured while another agent patched this
shared tree (`src/ase.tcl`'s md5 changed three times in two minutes, carrying two live sabotages at once), so numbers from that window are untrustworthy; everything in §3 was
taken afterwards on a quiescent tree, md5s checked before the audit, during it, and after the base-revert restore.
