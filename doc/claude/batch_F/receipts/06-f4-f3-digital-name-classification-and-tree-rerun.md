# Batch F item 06 (RE-RUN) — F4 ruling on digital name classification, F3 digital DB in the tree

Branch `fluid-editing`, base HEAD `7ff1be9d`. Supersedes round 1's receipt `06-f4-f3-digital-name-classification-and-tree.md` (kept, untracked) and adds the fix pass that six confirmed reviewer findings forced.

## 1. Files changed

`git diff --stat` (`git diff --cached --stat` was empty before the commit): 7 files, **1332 insertions, 27 deletions** — `src/wave_viewer.tcl` 328, `tests/headless/test_wave_sigbrowser_digital.tcl` 676, `specs/mixed_signal_signal_browser.md` 246, `specs/waveform_signal_browser.md` 28, `specs/waveform_signal_browser_two_pane.md` 23, `issues/0308-…` 37, `issues/0309-…` 21. Plus this receipt. `src/wave_viewer.tcl` md5 `f8a1659de95af825c363b3d620fa6158` — no sabotage residue (I patched only scratch copies). All 462 `wviewer::` proc bodies bytecode-compile clean under bare `tclsh`.

## 2. Decisions taken, and the evidence

**RULING F4 — digital names get their OWN class, `digital`**: a fifth *value* of the shipped `class` field, never a sixth key. Written into `specs/mixed_signal_signal_browser.md` §F ("F4/F3 — the digital signal class and the tree") with its measurement table; restated in `waveform_signal_browser.md` (contract lines) and `…_two_pane.md` §3.2.

Evidence, re-measured by me: on the legal VCD name `m.sub.sig` the shipped classifier answers `class devnode`, `path sub` (the `m` level **deleted**), label `sig:i`, and eats a bus index (`m.sub.count[3]` → `count:3`). `sig_declass` is sound *by SPICE grammar only* — a one-letter segment cannot be a subckt because SPICE requires `X`; Verilog has no such rule. So reuse does not mislabel, it **deletes**: `devnode` is what 0217 Ruling B hides by default, so the wire vanished from the browser entirely. The ruling depends explicitly on 0217 Ruling A (`class` stays — the answer is a value of it), on Ruling B (`digital` is deliberately *not* a device class: `sig_is_device digital == 0`, or a VCD would load into an empty tree), and on "the two panes RELOCATE noise, never delete signal" as the boundary not to cross — every analog reading is byte-identical (controls C1b/C2b/C3c, §3). Sub-ruling: the class follows the **database**, not the name shape.

**RULING F3 — `db_label` is already right and is NOT changed.** Confirmed as a value, not by reading: a VCD reads `counter.vcd (vcd)`, distinct from `tb_ase.raw (tran)`, keeping the space+bracket that stops `browser_node_for` reading it as a hierarchy segment. `vcd` is the engine's own string (`src/vcd_read.c:831`). The missing fact was that value *inside* the browser — now carried on both per-DB dicts in `browser_reload`.

**Fix pass — six confirmed reviewer findings, all fixed.** (a) A digital namespace is case-**sensitive**, so `browser_level_names`/`browser_sea_own` merged legal sibling scopes `top.mod`/`top.MOD`; the fix tests the *entry's own class*, and the naive "just make the compare case-sensitive" fix is rejected by a measured control that reds shipped ngspice folding (my C3c). (b)(c) `browser_target_path`/`browser_sea_target_path` still declassed a digital leaf, so a group and its own child reported different paths — `Descend to here` silently no-op'd and a scope+wire selection was refused outright. Fixed by a new pure per-row resolver `browser_id_type {token id}`; **the reviewers' prescribed fix (curry `browser_curtype`) was partially rejected with evidence** — the tree holds several DBs at once and currying the current kind breaks a *foreign* analog raw the other way (sabotage T6). The pane, which draws one DB, does get the current kind as prescribed. (d) `browser_sea_descend_to`'s silent `return 0` now says a sentence — a literal string, not a twelfth `browser_msg` kind, whose `return` count is a pinned ledger (re-counted, still 11). (e) **RULING F4b** (`mixed_signal_signal_browser.md:1046`, `waveform_signal_browser.md:203`, `…_two_pane.md:188`): in *shell* syntax only, the glob is tried first **unchanged** and an exact whole-subject equality second — a strict superset, so typing the bus-bit label the pane draws finds it. Quoting metacharacters, the obvious alternative, was measured to red shipped SM06/SM07/SM19; the wart pre-dates this item (`v(x1.count[3])` has drawn `count[3]` since two-pane item 20). (f) A false "measured" exemplar in a load-bearing `browser_label` comment was corrected.

**Issues 0308 and 0309 ruled NOT blockers for F3 and DEFERRED**, reasons written into both issue files. 0308 is now *pinned as a value* by FD48 so its false caption cannot drift unnoticed; 0309 is made rarer by F4, not closed.

## 3. Tests, check count, RESULT line

`tests/headless/test_wave_sigbrowser_digital.tcl` — 25 checks at HEAD → **59** (34 new: FD30–FD48 in round 1, FD49–FD55 in the fix pass). Frozen oracles re-counted, all unmoved: `browser_alldbs` 2 (BD06), `browser_devint`/`browser_srccur` 5/5 (BW59), `browser_msg` returns 11 (BK33), GS23's contract list 57, BM05's `plot_signals` signature literal intact.

**THERE IS NO RESULT LINE FOR THE COMMITTED TREE.** The user's control panel (pid 2670, alive) has been at `control=PAUSE` since 10:27 and was still PAUSE at 14:24; every sanctioned path blocks at `gate_pause_point`. The only verbatim harness RESULT lines that exist are round 1's, taken on the verified-healthy display **before** the eight fix-pass checks:

```
PASS     | test_wave_sigbrowser_digital run 1/1  RESULT: ALL PASS (51 checks) / RESULT: 1/1 runs passed   [GUI arm]
PASS     | test_wave_sigbrowser_digital run 1/1  RESULT: ALL PASS (19 checks) / RESULT: 1/1 runs passed   [--nogui arm]
```

My gate-free corroboration — 14 assertions I wrote against the product's real procs in bare `tclsh`, **not** a harness RESULT line: `CLOSER-BAND: 14 pass / 0 fail` on the working tree, `7 pass / 7 fail` against `git show HEAD:src/wave_viewer.tcl`. The 7 still passing at HEAD are exactly my analog controls, so the analog path is provably unchanged. **AUDIT: NOT RUN — §5.**

## 4. Sabotage table

`S1`–`S17` were run by the implementer on the verified-healthy display (full table in round 1's receipt); `T1`–`TB` in pure `tclsh` on scratch copies; `X1`–`X8` are mine, today, on scratch copies, with a patcher that refuses any anchor not occurring exactly once.

| check | broken by | red? | restored green? |
|---|---|---|---|
| FD30 | S1 `db_is_digital` always NO / S2 always YES | yes | yes |
| FD31, FD35 | S1, S2, S11 `sig_split` ignores dbtype, S14 `sig_declass` never strips | yes | yes |
| FD31b | S1, S2 | yes | yes |
| FD31c | S15 digital arm grows a sixth key | yes | yes |
| FD32 | S1, S2, S3 `sig_is_device` folds digital, S14 | yes | yes |
| FD32b | S16 `browser_class_filter` both-boxes-ON fast path | yes | yes |
| FD33, FD34, FD34b | S1, S2, S4 `browser_label` digital arm deleted, S14 | yes | yes |
| FD33b | S2, S14 | yes | yes |
| FD36 | S1, S3, S11 | yes | yes |
| FD36b | S1, S2, S14 | yes | yes |
| FD37 | S1, S3 | yes | yes |
| FD38 | S13 `db_label` drops the analysis suffix | yes | yes |
| FD39, FD40 | S5 foreign dict loses `type`, S6 current dict loses it | yes | yes |
| FD41, FD42 | S1, S3, S5, S8 All-DBs loop untold, S11 | yes | yes |
| FD42b | S6 | yes | yes |
| FD43 | S1, S3, S4, S5, S8 | yes | yes |
| FD44 | S1, S6, S9 `browser_sea_own` untold, S11 | yes | yes |
| FD45 | S1, S3, S4, S6, S10 `browser_sea_refresh` untold, S11, S12 | yes | yes |
| FD46 | S1, S3, S6, S9, S11, S12 | yes | yes |
| FD47 | S1, S3, S4, S6, S7 matcher key un-curried, S12 | yes | yes |
| FD48 | S1, S3, S5, S8, S11, S17 (the shape of 0308's fix) | yes | yes |
| FD49 | T1 unconditional `-nocase` restored; T2 always case-sensitive (control leg) | yes | yes |
| FD50 | T3 `browser_sea_own` unconditional `-nocase` | yes | yes |
| FD51 | T4 drop the `browser_id_type` arg; T5 always current kind; T6 always `vcd` (control) | yes | yes |
| FD52 | T7 drop `$seatype`; T8 hardcode `vcd` (control leg) | yes | yes |
| FD52b | T9 delete the `browser_status` call, restoring the silent `return 0` | yes | yes |
| FD53 | TA drop the exact-literal arm; TB drop the glob (control leg) | yes | yes |
| **FD54** | **UNSABOTAGED — NEVER EXECUTED.** Real-tree twin of FD51; needs the gate. | — | — |
| **FD55** | **UNSABOTAGED — NEVER EXECUTED.** Real-pane twin of FD52; needs the gate. | — | — |

FD54/FD55 are **not evidence**. Their pure twins FD51/FD52 are fully covered; T4 and T7 are the sabotages that should red them and the kit is anchor-verified and staged.

My eight corroborate the fix pass independently: X1 reds 6 of my 14; X2 only the two digital case legs; X3 (the naive case fix) only the *analog* control; X4b only the exact-literal leg; X5b only the three glob controls; X6 the label legs; X7 the not-a-device leg; X8 the two analog controls. **X4 and X5 red nothing on their first aim** — they patched `sig_match`'s case-*sensitive* branch while the matcher defaults to `-nocase`; re-aimed as X4b/X5b. Recorded because that is exactly the hollow row this table exists to catch.

## 5. What was NOT verified

* **THE AUDIT DID NOT RUN — UNVERIFIED.** The baseline `doc/claude/batch_F/baseline_status.txt` **does exist** (365 rows; 277 PASS / 26 FAIL / 2 TIMEOUT / 1 SKIP audit-only). I launched `full_audit.sh` with `DISPLAY=:0 GUI_GATE=1` at 14:20:33; it cleared `gate_start` then parked with **zero progress in 3 minutes** (111-byte log). I killed my own process group so it cannot fire a stray audit when the user resumes; `~/.claude/gui_test_gate/{status,req}/` are empty and no harness or `xschem` process remains. I did **not** set `GUI_GATE=0`, write a bare loop, unset `DISPLAY`, start Xvfb or a hidden display, or touch the gate dir. Display verified real throughout: 5120×1440, no `+-327` window (0310's stub absent). Round 1's audit (279/22/2/4 over 307, wireedit 58/58, 11 moved rows, `test_remap` settled by a marker probe) was healthy-display but **predates the fix pass**. **An audit diff is owed before this item is trusted.**
* **NO SUITE RAN AGAINST THE COMMITTED TREE.** The eight fix-pass checks have never executed under the harness; FD40–FD48 and FD54/FD55 sit behind the Tk/X gate.
* **NEIGHBOURING SUITES NOT RE-RUN** since the fix pass: `test_wave_sigbrowser`, `_sigsearch`, `_2pane`, `_i11`, `_i12`, `_i14`, `_sea`, `_keys`, `_panes`, `test_wave_grid`, `test_wave_crossdb_trace`, `test_ase_cosim`, `test_vcd_read`. `sig_match` and both path resolvers are shared code.
* **All six reviewer findings were CONFIRMED and fixed; none was raised-but-unconfirmed.** Reviewer not-proven items still standing: that `xschem raw info` reports `type` = `vcd` live (statically confirmed at `vcd_read.c:831` only); S2's cross-suite claim that guessing `digital` reds 50 analog checks; 0308's live false caption; FD48's pre-feature failure.
* **Gaps with no oracle** (declared, not defects): `type` stays `other` on a digital entry and no check asserts it; `db_is_digital` keys on the literal `vcd` and misses `save.c`'s other reader `table`; in the `--nogui` arm FD39 counts *declarations*, not uses, so S8/S12's wirings rest on the X arm alone.
* **EYEBALL OWED — this is why the verdict is `[E]`.** (1) The All-DBs tree with a VCD attached: `counter.vcd (vcd)` → `counter` → `TOP` → `counter` echoes the file name in adjacent rows — sensible, or a stutter? If it reads badly the fix is a `browser_root_label` ruling for digital DBs, deliberately not invented here. (2) A digital scope with the VCD **current** — the pane should list `sig count count[0..3]` bare. (3) A VCD with a one-letter top scope — its wires must be in the tree at the default box state. (4) On a digital scope `Descend to here` must now **act** rather than sit enabled doing nothing, and a scope selected with one of its own wires must be enabled, not refused.
