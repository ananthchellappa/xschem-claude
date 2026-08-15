# Batch F item 05b — SALVAGE of `fda9d5a8`: F1's verilog branch, F5's empty-pane notice

**Verdict [E] — eyeball pending, and attempt 1's `[F]` is SUPERSEDED.** The item is finished
to standard: the draft is salvageable and was salvaged, not reverted; one real defect in it
was found by measurement and fixed (RULING F1e); every one of the **65 checks the item owns
is now sabotage-backed**, which is the thing attempt 1 never had. The payload is still
rendered text in a pane, so a human must still look — §6 says at what.

> **⚠⚠ READ §7 BEFORE §3-§6. THIS RECEIPT WAS ITSELF REVIEWED AND FOUND WRONG ABOUT ITS OWN
> HEADLINE.** Three adversarial reviewers drove the product on a real viewer and showed that
> RULING F1e's notice — and F5's original notice inherited from `fda9d5a8` — were **erased one
> turn of the Tk event loop after being written**, i.e. the instant the key binding returns,
> so the user saw the false caption anyway; and that step 7b's own predicate was reading the
> pane the user had just LEFT. The measurements in §3 that decided RULING F1e were all taken
> in the same event-loop turn as the write and therefore describe a state that never reached a
> screen. §7 is the fix pass: what was wrong, what changed, the re-sabotage, and the carry-over
> experiment re-run on a quiescent tree. The item now owns **72** checks (46 FV + 25 FD +
> `BK33`), not 65.

**What attempt 1 was.** `fda9d5a8` is real work whose implementer, verifier and three
adversarial reviewers all died on an API stall; the closer committed what was in the tree
after re-measuring six sabotages. So it landed **never independently verified and never
adversarially reviewed**. Its receipt
(`05-f1-f5-verilog-only-view-and-empty-pane-notice.md`) stays in place as the record of
that collapse; this receipt does not replace it, it finishes the job.

**Was it salvageable? YES, and the evidence is specific.** Read in full, the draft's
architecture holds up under attack: the design-context read really is above the raise and
really is asserted behaviourally (`FV33`), the notice really does render the resolver's own
sentence rather than composing a second one, and the four ⚠ blocks at step 3b are untouched
(`git show fda9d5a8 -- src/ase.tcl` shows step 3b byte-identical). Nothing was reverted.

---

## 1. What was actually there vs what the item required

| the item required | attempt 1 shipped | this pass |
|---|---|---|
| F1: a branch for a `verilog`-view cell | step 3c + `browser_digital_probe`, gate ruled F1a | kept, re-sabotaged (10 patches) |
| F1: step 3b's ⚠ ordering PRESERVED | preserved; `git show` confirms it byte-identical | verified, and the guard re-proved: `S02` moves the probe below the raise, `FV32`/`FV33`/`FV39` go red |
| F1: an ORDER CHECK so a reordering fails loudly | `FV33` (live call order) + `FV39` (source layout) | verified BOTH are real: `S02` reddens both, so a move cannot satisfy one by breaking the other |
| F5: three causes distinguished | `notloaded` / `notraced` / `nomap`+`noscope`, `FV10`-`FV18` | verified against item 4's REAL code (§2), and each cause independently reddened |
| F5: the third cause must match item 4's code | asserted by substring against the resolver's own answer | confirmed at `src/ase.tcl:1637` and `:1735`/`:1885` (§2) |
| sabotage every check | 6 of ~40+18 rows re-measured; ~24 claimed, unverified | **54 patches, 65/65 checks red under at least one** (§4) |
| a filed issue for a non-`[x]` verdict | attempt 1 filed none | `doc/claude/issues/0308-…` filed (§3) |

**One real defect was found, and it was in the HAPPY path.** Measured on the live viewer
(`DISPLAY=:0`) before any change: after a *successful* digital re-scope the tree selects
`d:1|g:TOP.m` correctly and the lower pane lists **nothing**, captioned by the shipped
`seaempty` arm as **"TOP.m has no signals of its own"** — about a scope that has two. The
feature's own success case therefore shipped exactly what F5's row forbids: an empty pane
with a WRONG reason. Fixed as RULING **F1e** (§3). That defect had survived attempt 1's 58
checks and its six sabotages, which is what an unreviewed commit looks like from the inside.

## 2. F5's causes, checked against the code and not against the notice

`ase::browser_digital_msg` (`src/ase.tcl:1954`) prefixes and adds nothing, so the sentence
the user reads is minted where the refusal is decided. Verified by reading each site:

| F5's cause | code | sentence minted at | check |
|---|---|---|---|
| no VCD loaded | `notloaded` | `src/ase.tcl:1878` — "is not among the loaded results databases" | `FV10`/`FV11` |
| signals present, trace not enabled | `notraced` | `src/ase.tcl:1862` — "the last run promised no VCD for …" | `FV12`/`FV13` |
| no mapping (no entry) | `nomap` | `src/ase.tcl:1637`, in `cosim_map_match` | `FV14`/`FV15` |
| no mapping (entry, DB declares no scope) | `noscope` | `src/ase.tcl:1735` wrapped at `:1885` with the DB basename | `FV16`/`FV17` |
| the scope resolved, the tree could not reach it | `nopane`, minted by F1 | `src/ase.tcl:2644` | `FV36`/`FV37` |

`FV18` asserts the four are four DIFFERENT strings, so a notice that collapsed them could
not pass by satisfying each singly — and `S11` (the notice composes its own sentence)
reddens `FV11 FV13 FV15 FV17 FV18 FV20 FV35 FV37` together, which is the proof that the
rendering rule is load-bearing rather than decorative.

## 3. What this pass changed, and the ruling behind it

`git diff --numstat` against `fda9d5a8`: `src/ase.tcl` **+52/-0**
(`ase::browser_pane_unread` `:1966`; step **7b** of `show_in_browser_for_current` `:2700` —
most of it the ⚠ block), `src/wave_viewer.tcl` **+23/-0** (`wviewer::browser_sea_empty`
`:8222`), `tests/headless/test_ase_cosim.tcl` **+60/-2** (`FV41`-`FV44`, the spy list and one
`set ::fv_seaempty 0`; 304 → **308** checks, none renumbered or lost),
`tests/headless/test_wave_sigbrowser_digital.tcl` **+37/-1** (`FD19`/`FD19b`, the duplicate
`FD10` restated as `FD10b`, and an `update` the file needed; 18 → **20**),
`doc/claude/specs/mixed_signal_signal_browser.md` **+60/-21** (RULING F1e, the corrected
sabotage row, two re-measured line refs), issue 0308 and this receipt (new files).
**No C changed; no rebuild.**

**The measurement that decided it**, taken on the live viewer (`:0`, real tree, real canvas,
`ase::attach_dbs` with an ngspice raw current and a VCD declaring `TOP.m.siga`/`TOP.m.sigb`)
BEFORE and AFTER the arm, through a scratch probe that was then deleted:

```
BEFORE  show_db_scope -> {alldbs d:1|g:TOP.m TOP.m}   ; the tree DID re-scope
        tree selection = d:1|g:TOP.m                  ; the right row IS selected
        pane cells     = 0                            ; and it lists NOTHING
        pane caption   = "TOP.m has no signals of its own"        <-- FALSE
AFTER   browser_pane_unread = 1
        pane caption   = "showing the digital scope 'TOP.m' of 'fd_dig.vcd' in the
                          tree, but the lower pane lists only the current results
                          database, so this scope's own signals are not in it yet"
        status line    = "Signal Browser\<same sentence>"
        canvas seanote = 1                            ; and it is IN the pane
```

**RULING F1e — the success path's own empty pane must say the TRUE thing.** Written into
`doc/claude/specs/mixed_signal_signal_browser.md` §F with its rationale. Decided by the
measurement above, plus item 4's own rule ("a notice that describes a different behaviour
than the code implements is worse than no notice") read in the direction nobody had read it:
the *shipped* `seaempty` caption is such a notice. Step 7b overwrites it, through the same
renderer, on the same three surfaces. Two sub-rulings: the arm is gated on the PANE
(`browser_sea_empty`, which answers `0` = "no claim" for a viewer with no window or no pane
state, never a guessed yes — `FV43` is the control), and the sentence is COMPOSED here
rather than rendered, for `nopane`'s reason: the resolver answered `ok`, so there is no
resolver sentence to render. Tag `note`, not `error` — nothing failed.

**Not fixed, filed instead:** `doc/claude/issues/0308-…` — the lower pane still cannot read
a foreign database, so the scope lists nothing; F1e makes the caption honest, F3 has to make
the pane useful. The issue also records the two paths F1e does NOT cover (selecting a foreign
row by hand, and item 15's `BD70d` foreign-root case) and says the arm must be DELETED when
F3 lands.

**Recorded, not fixed (a second time), with the reason:** a `partial` landing that had to
tick the All-DBs box reports `partial`, not `alldbs`, so that one combination grows the tree
without saying so. It needs a scope whose names the DB inventory carries but whose node the
tree cannot fully reach; the `browser_names_under` gate makes it near-unreachable (measured:
`browser_show_db_scope … TOP.nosuch` with the box off refuses at the gate and leaves the box
untouched). Reporting it would need a 12th `browser_msg` arm and a third restatement of
`BK33`, which is not a trade worth making for an unreachable state. Written into the spec's
"What F1 does NOT solve".

**`FD10` was used TWICE by the draft.** Restated as `FD10b`, assertion byte-identical: two
rows of a sabotage table cannot both say "FD10 went red" and mean different checks.

## 4. Sabotage — 54 patches, one at a time, 65/65 checks covered

Every patch was applied to the live tree, run, and reverted from a **byte-exact backup with
`md5sum -c` after every single restore** (`ase.tcl 4cb2128a…` — CORRECTED 2026-08-10: this receipt originally quoted
`7a5d82d8…`, which matches no version of the file and made the restore evidence for the
most-edited file uncheckable; `wave_viewer.tcl 962e66e4…`,
`test_ase_cosim.tcl 13b8cf0e…`, `test_wave_sigbrowser_digital.tcl 2e3b28b8…`). Never
`git checkout --`. The catalogue and driver are in the session scratchpad (`sal/patches.py`,
`sal/runall.sh`). **Suites: `test_ase_cosim` (`--nogui`), `test_wave_sigbrowser_digital`
(`:0`), `test_wave_sigbrowser_keys` (`:0`).**

| # | what was broken | checks that went RED |
|---|---|---|
| S01 | the probe call deleted from step 3c | FV32 33 34 35 36 37 38 39 41 42 43 |
| S02 | the probe MOVED BELOW `wviewer::open` (the declared ordering sabotage) | FV32 33 34 36 38 39 41 43 |
| S03 | the `vfile` gate removed — every analog cell enters the branch | FV3 FV38 |
| S04 | the empty-selection and empty-f1 guards removed | **NONE — survived**, see below |
| S04b | all THREE probe guards removed | FV3 FV4 FV5 FV38 |
| S05 | the probe takes TWO design-context f1 reads | FV6 32 34 36 41 43 |
| S06 | the state form delegates an EMPTY f1 (the split buys nothing) | FV7 (+27 FS) |
| S07 | `notloaded` reported as `notraced` | FV10 11 18 (+FS40) |
| S08 | `notraced` reported as `notloaded` | FV12 13 35 (+FS42) |
| S09 | the `nomap` sentence reworded | FV15 |
| S10 | the `noscope` sentence drops the database name | FV17 (+FS39 FS64) |
| S11 | the notice COMPOSES its own sentence instead of rendering | FV11 13 15 17 18 20 35 37 |
| S12 | the notice fires on a SUCCESS too | FV19 |
| S13 | the `multi` refusal deleted | FV20 (+FS41) |
| S31 | `nomap` reported as `ambiguous` | FV14 (+5 FS) |
| S32 | `noscope` reported as `nomap` | FV16 (+FS38 FS63) |
| S33 | the probe never answers | FV2 6 10-18 20 32-38 41 42 43 (22) |
| S14 | `browser_root_id` no longer accepts a bare `g:` | FV21 |
| S15a | `browser_node_for` always starts at the CURRENT root | FV22 FV23 |
| S15b | `browser_node_for` always starts at the FOREIGN root | FV24 |
| S16 | `browser_id_path` leaks the `d:N|` prefix | FV23 |
| S17 | `browser_rows_headered` always yes | FV25 |
| S18 | `browser_row_exists` always yes | FV26 |
| S19 | `browser_names_under` folds case | FV27 |
| S20 | `browser_db_group_id` compares un-normalized strings | FV28 |
| S21 | …never looks at the foreign inventory | FV29 |
| S22 | …falls back to the current DB instead of `{}` | FV30 |
| S23 | the eleventh `alldbs` sentence deleted | FV31 |
| S24b | the notice is written BEFORE the fall-through | FV34 FV40 |
| S25 | an unreachable scope mints no fourth cause | FV36 FV37 |
| S26 | RULING F1e's arm deleted | FV41 FV42 |
| S27 | F1e's arm ignores the pane predicate (fires always) | FV32 FV43 |
| S28 | `browser_pane_unread` is not total | FV44 |
| S29 | the selection reducer answers nothing | FV1 32 33 34 35 36 37 38 38a 41 42 43 |
| S30 | the session-state reader answers nothing | FV0 2 6 10-13 16-20 32 35 36 37 41 42 43 (+AT17 FS45) |
| D01 | the `alldbs` sentence deleted (Tk arm) | FD01 FD16 |
| D02 | `browser_notice` inspects the cause | FD02 |
| D03 | the notice is never cleared by the sea refresh | FD03 FD22 |
| D10 | the viewer never opens | FD10 FD10b (the file then aborts — the fixture is a precondition) |
| D10b | the sidebar never toggles | FD10b |
| D11 | only the analog raw is attached | FD11 11b 13 14 15 16 17 17b 19 21 |
| D12 | `browser_rows_headered` always yes | FD12 |
| D13 | the All-DBs box is never invoked | FD13 14 15 16 19 21 |
| D14 | the landing is never revealed (no selection) | FD14 FD19 |
| D15 | `browser_id_path` leaks the prefix (Tk arm) | FD13 15 16 17 |
| D17 | a `partial` landing is reported as a success | FD17 |
| D17b | a first-segment miss is not refused | FD17b |
| D18 | an unheld database is not refused BY NAME | FD18 |
| D19 | `browser_sea_empty` always says "not empty" | FD19 |
| D19b | `browser_sea_empty` always says "empty" | FD19b |
| D20 | the notice never reaches the pane caption | FD20 |
| D21 | the pane draws no notice (canvas arm deleted) | FD03 FD21 |
| K33 | the `alldbs` sentence deleted, keys suite | **BK33** |

**Coverage: FV 44/44, FD 20/20, BK33 — 65 of 65. No check is unsabotaged.**

**TWO patches did not redden anything, and both are named rather than dropped.**

**`S04` — defence in depth, not a hole.** `S04` deletes the probe's
`if {$selname eq {}}` and `if {$f1 eq {}}` guards and the file stays ALL PASS. Cause,
measured: the third guard below them (`dict get $f1 vfile` inside a `catch`, then
`if {$vf eq {}}`) refuses the same two inputs, so the first two are defence in depth. `FV4`
and `FV5` claim an OUTCOME ("no selection / an unknown instance is not a branch"), and
`S04b`, which removes all three, reddens both — so neither check is hollow. This is the same
row attempt 1's receipt mentioned without measuring; it is now measured from both sides.

**`S24` — a MIS-AIMED patch of mine, superseded.** My first attempt at "the notice is written
before the fall-through" inserted it above the CIW echo, which is still *below* both
`browser_show_path` calls — so it moved nothing that `FV34`/`FV40` are about and the file
stayed ALL PASS. That is a defect in the patch, not in the checks: `S24b` performs the
intended move (the notice arm hoisted above `set res {}`) and `FV34` and `FV40` both go red.
`S24` is listed here because a sabotage table that quietly drops its own failures is the thing
this receipt exists to replace.

## 5. Suites, verbatim, and the audit diff

Restored tree, `md5sum -c` clean, three suites re-run under `GUI_GATE=1 DISPLAY=:0` through
`run_suites.sh`:

* `PASS     | test_ase_cosim               run 1/1  RESULT: ALL PASS (308 checks)` (`--nogui`;
  264 → 304 by attempt 1, → **308** here)
* `PASS     | test_wave_sigbrowser_digital run 1/1  RESULT: ALL PASS (20 checks)` (18 → **20**)
* `FAIL     | test_wave_sigbrowser_keys    run 2/2  RESULT: 1 FAILED (47 passed)` —
  `FAIL: BK40 (X, THE OTHER CONTROL) …`. **`BK33`, the check this item restated, is GREEN in
  every run.** `BK40` is the known focus flake and this run is itself part of the proof: the
  SAME tree scored `test_wave_sigbrowser_keys` **PASS** in the full audit an hour earlier
  (§5b). Check counts never shrank in any run — the witness to a file that aborted early.

### The audit — a DIFF, by NAME and STATUS, in both directions

`tests/headless/full_audit.sh`, `DISPLAY=:0`, `GUI_GATE=1`, the user's panel live
(pid 3122619, `control=RUN`, `allow_until` ~10 h ahead; logged `approved batch window open …
(no prompt)`). The panel was never launched, killed, re-armed or written to; no Pause, no
Stop; no hidden display, no Xvfb, no `DISPLAY` other than `:0`; X did not die. Baseline
`doc/claude/batch_F/baseline_status.txt` **EXISTS** (`7a592f9c`, same `:0`).

**307 rows** (306 + the file this item added): **274 PASS / 32 FAIL / 1 TIMEOUT / 0 SKIP**,
plus `WIREEDIT: ALL PASS` (58/58) and `SCRATCH: 0 leaked dir(s)`. *(The 58 wireedit names
show as "GONE" in a naive name diff only because the two sections of the log are parsed
differently; the harness's own `WIREEDIT: ALL PASS` line covers all 58.)*

**NEW (1):** `test_wave_sigbrowser_digital` — **PASS**. This item's other two rows are
`test_ase_cosim` **PASS** and `test_wave_sigbrowser_keys` **PASS**.

**RED → GREEN (6):** `test_fluid_bodyshove_guards_0132`, `test_fluid_editing`,
`test_wave_crossdb_trace`, `test_wave_sigbrowser_i12`, `test_wire_vertex_grab` (FAIL→PASS)
and `test_rotate_stretch_dangling_0103` (SKIP→PASS). Same six as item 4's and attempt 1's
audits — the baseline's own collateral, not this item's doing.

**RED → RED, flavour changed (1):** `test_ase_plot` TIMEOUT→FAIL (its documented P4/P6/P8
gesture flake). `test_ase_window` was FAIL in the baseline and is FAIL here.

**GREEN → WORSE (10):** `test_ase_dialogs`, `test_ase_interact`, `test_cmdmode_descend_0201`,
`test_multi_window`, `test_wave_modes`, `test_wave_sigbrowser`, `test_wave_sigbrowser_i1315`,
`test_wave_sigbrowser_sea`, `test_wave_tabs`, `test_wave_viewer`. Settled in §5b.

### 5b. The carry-over rows — THIRD PASS, and this one ends it

**CONCLUSION: none of the ten is a regression from items 1-5. All ten are the session's
degraded X key/focus delivery, and it is now measured on both sides rather than argued.**

**The experiment.** Every one of the ten rows was run **twice with the item's Tcl in place**
and **twice with `src/ase.tcl`, `src/ciw.tcl` and `src/wave_viewer.tcl` reverted to
`7a592f9c`** — the exact commit `baseline_status.txt` was measured at, so the revert removes
**all of items 3, 4 and 5** (item 3 is docs-only; item 4 touched `ase.tcl`+`ciw.tcl`; item 5
those two plus `wave_viewer.tcl`). Same binary, same `:0`, same panel, same session,
back-to-back, through `gated_xschem.sh`. Sources restored from the byte-exact backup
afterwards, `md5sum -c` **OK on all six files**. `git checkout --` was never used.

| row | WITH the item (2 runs) | with items 3/4/5 REVERTED (2 runs) | verdict |
|---|---|---|---|
| `test_ase_dialogs` | 19 red, 10 red — `G2 G6 GE3-GE16` | **14 red, 20 red — same `GE` family** | env. noise; fails MORE at base in run 2 |
| `test_ase_interact` | 4 red (`I7`), 4 red | **4 red (`I7`), 4 red** | env. noise; identical both sides |
| `test_cmdmode_descend_0201` | 4 (`DS7b DS7b2 DS7b3 DS7c`) ×2 | **4, identical ids ×2** | env. noise; identical both sides |
| `test_multi_window` | 1 (`MWf`) ×2 | **1 (`MWf`) ×2** | env. noise; identical both sides |
| `test_wave_modes` | 1 (`MG16`) ×2 | **1 (`MG16`) ×2** | env. noise; identical both sides |
| `test_wave_sigbrowser` | 10 red, 12 red — `BT25 26 27 29 45` | **7 red, 7 red — `BT25 26 27 29 45`** | env. noise; same check family, count varies run to run on BOTH sides |
| `test_wave_sigbrowser_i1315` | 1 (`BR25`) ×2 | **1 (`BR25`) ×2** | env. noise; identical both sides |
| `test_wave_sigbrowser_sea` | 23 red, 10 red (`BQ` family) | **12 red, 12 red (`BQ` family)** | env. noise; the ITEM runs STRADDLE the base runs (23 > 12 > 10) — within-phase variance exceeds between-phase |
| `test_wave_tabs` | 2 red (`TG16`), then **ALL PASS** | **1 red (`TG16`), then ALL PASS** | env. noise, PROVEN: one run of each phase is clean |
| `test_wave_viewer` | 4 red (`G5 G6 G9a`) ×2 | **4 red, 3 red — `G5 G6 G9a`** | env. noise; identical both sides |

**Every failing check in all ten is a key- or focus-delivery leg** (`G5 Insert + w delivered`,
`G9a Ctrl-W was delivered`, `TG16 a real Ctrl-N opened a tab`, `BR25 <Return> reaches the
commit path`, `MWf`, the `BQ`/`BT`/`GE` search-bar and dialog families) — the documented WSLg
flake where a bare `event generate` misses roughly one delivery in five. Nothing in items 3-5
is anywhere near that path: they add Tcl procs to `ase::`/`wviewer::` that only
`show_in_browser_for_current` and `browser_show_db_scope` call, plus one `tag configure` line.

**The one thing NOT reverted, stated rather than hidden:** item 2 (`16290d8b`) is C —
`draw.c`, `scheduler.c`, `xschem.h` — and reverting it needs a rebuild, which cannot run while
suites do. It is not a candidate: it re-brackets the `node=` raw-file walkers, touching no Tk
binding, no focus and no event queue, and the row that *is* its subject,
`test_wave_crossdb_trace`, went **FAIL → PASS**. Item 1 IS the baseline commit.

**`BK40`, and `test_wave_sigbrowser_keys` generally, is settled from three directions.**
Attempt 1 chased its diverging leg to `bs_type`'s literal `no-focus` sentinel (the helper
tries ~50 times over ~1 s to force focus onto the search entry, then gives up) and measured it
red in **4 of 5 runs at HEAD**. This pass adds the cleanest possible evidence: on **the same
tree, in the same session**, a standalone run FAILED `BK40` and the full audit an hour later
scored the same file **PASS**. One tree, two answers — that is the definition of a flake, and
it is why the row is absent from this audit's green→worse list while it was present in
attempt 1's.

**What this closes.** Item 4's audit left 12 rows green→worse of which 10 reproduced when
reverted; attempt 1 measured 11 and re-ran 5. This pass measures **10 rows × 4 runs = 40 paired
runs** and finds **zero** attributable to items 1-5. The carry-over is CLOSED. What remains
true is the standing condition, already recorded in the batch's own baseline notes: `:0`'s key
delivery in this session is worse than it was when `baseline_status.txt` was captured, so the
baseline's PASS on these ten rows is itself the lucky sample, not the norm. **A future pass
should re-baseline rather than re-litigate these ten.**

## 6. What was NOT verified, and the eyeball

* **Still no real co-simulation.** Both suites synthesize their databases (`mkraw`/`mkvcd`),
  so Verilator's real scope naming is untested, exactly as in attempts 1 and 4.
* **The end-to-end pixel is proved in three parts, not one.** `FV41` proves the command
  writes the notice last; `FD19` proves the real pane is empty at that moment; `FD20`/`FD21`
  prove `browser_notice` reaches the caption, the status line and the canvas. No check drives
  `ase::show_in_browser_for_current` against a real viewer holding a real code block — that
  needs a design with a `verilog`-view instance and a live window, and it is the eyeball.
* **`ase::browser_pane_unread`'s success path is exercised only through a stub** in the FV
  arm; the real reader is exercised by `FD19`/`FD19b`.
* **Attempt 1's ~24 unverified sabotage rows are still not evidence** and are not carried
  here. This pass's 54 patches replace them wholesale; where a row of attempt 1's six
  overlapped (S01, S02, S3b→S08, S9→S23, SD1→D13, SD3→D21) it reproduced.
* **EYEBALL OWED — this is the `[E]`.** Open the co-sim design, select the `d_cosim`
  instance, press Ctrl-Alt-V, and judge four things:
  1. **the re-scoped tree** — does it read as *the tool did what I asked*, or as *something
     broke*? The foreign database's subtree appears and the box ticks itself.
  2. **RULING F1e's sentence in the empty pane** — "showing the digital scope 'X' of 'Y.vcd'
     in the tree, but the lower pane lists only the current results database, so this scope's
     own signals are not in it yet". Is it legible and sanely wrapped at the default sidebar
     width AND with the sash dragged narrow? It is the sentence the happy path now shows, so
     it is the one that matters most.
  3. **the caption and the status line CLIP the long sentence.** Whether F5 needs a short
     form there is a live design question this pass did not settle either.
  4. **the CIW pair** — what was shown, then the `note`-tagged caveat — read as one account,
     and the `note` colour reads as a caveat rather than an error.

---

# 7. THE REVIEW FIX PASS (2026-08-10) — what the salvage got wrong, and the repair

Three adversarial reviewers ran against the salvage. They agreed on one mechanism, reached
it independently, and it invalidates this receipt's §3 headline measurement. Nothing in §1–§6
above has been rewritten (it is the record of what was believed at the time); this section is
what is now true.

## 7.1 The defect all three found — the notice never reached the user

`wviewer::browser_reveal` lands the tree with `$tv selection set`, which only **queues**
`<<TreeviewSelect>>`. The bind (`src/wave_viewer.tcl`, `browser_build`) runs
`wviewer::browser_sea_refresh`, whose **first** act is `set browserseanote($token) {}` and
whose **last** act re-captions the pane from the shipped `seaempty`/`seacount` arms. That
event is delivered on the very next turn of the Tk event loop — **the instant the Ctrl-Alt-V
binding returns**. So:

* the F5 refusal notice (inherited from `fda9d5a8`, not introduced by the salvage) and
  RULING F1e's success notice were both written and then **erased before the user could read
  either**. Measured on a real viewer: on return the caption held the sentence; one `update`
  later it read `TOP.m has no signals of its own` — the exact falsehood RULING F1e was created
  to remove — with `browserseanote` empty and zero canvas note items. Only the sidebar status
  line survived.
* step 7b's own predicate, `ase::browser_pane_unread`, reads the pane MODEL (`browsersea`),
  which that same queued refresh had not rebuilt yet. So the arm decided using **the pane the
  user had just left**: from a settled design root listing 2 signals it answered "not empty"
  and refused to fire at all. Measured: `pane_unread = 0` at the product's decision point,
  `1` one `update` later.

**§3's deciding measurement was taken in the same event-loop turn as the write** and therefore
describes a state that exists for microseconds. That is the whole error, and it is a
methodology error, not a coding one: **every check in both arms read its surface in the turn
that wrote it, which is the one turn the product never gets.**

**The coverage hole that let it land.** `test_ase_cosim`'s `fv_arm` stubs
`wviewer::browser_notice` entirely and asserts only that it was CALLED;
`test_wave_sigbrowser_digital`'s `update` calls sat at `:166` and `:216`, i.e. **before** the
notice and never after it. A reviewer proved the hole with a sabotage nobody had named
(refresh the pane immediately after the notice — semantically what Tk does one turn later):
**both suites stayed ALL PASS** under a patch that guarantees the notice reaches nobody.

## 7.2 What changed

| # | file | change |
|---|---|---|
| 1 | `src/ase.tcl` | **step 6c: `catch {update}`** — one flush, below every call that can move the tree (step 6, its `partial` fall-through, 6b's last-mile retry) and above the notice. `update`, not `update idletasks`: the virtual event is on the main queue, and `browser_reveal` already calls `update idletasks` without delivering it. Fixes BOTH blockers with one line — the notice is now written onto a settled pane, and the predicate now reads that settled pane. Ruled into the spec as **RULING F1f**. |
| 2 | `src/ase.tcl` | step 7b's sentence names **`[lindex $res 2]`, the LANDING**, not `[lindex $dig 2]`, the scope that was asked for. They differ on a `partial`, where the old sentence claimed "showing the digital scope 'TOP.m' in the tree" one statement after the CIW had said "no signals under 'TOP.m' - showing TOP instead". |
| 3 | `src/wave_viewer.tcl` | `browser_sea_empty` now returns 1 only when nothing is drawn **AND** `browser_sea_own` (the UNFILTERED inventory at that level) is 0. `browsersea` is the FILTERED set, so an empty one had two causes; the old body called a bar-hidden node "empty" and let step 7b replace the shipped and TRUE caption `0 of 2 signals (the Search/Filter bar is hiding them)` with a sentence blaming a foreign database. |
| 4 | `tests/headless/test_wave_sigbrowser_digital.tcl` | **`FD23`/`FD24`** drive the REAL command against the real viewer (only the five design-side reads stubbed — steps 4/5/6/6c/7/7b are shipped code) and read the caption, status line and canvas **after `update`**. **`FD25`** is the tombstone for the unflushed order. **`FD26`** is the bar-vs-empty distinction. |
| 5 | `tests/headless/test_ase_cosim.tcl` | **`FV45`** — a `partial` landing is named by where it landed (the only check that can tell the two apart; everywhere else in the arm the asked scope and the landing are the same string). **`FV46`** — the settle sits between the last tree move and the notice, exactly once. |
| 6 | `doc/claude/specs/mixed_signal_signal_browser.md` | RULING **F1f** added; RULING F1e's "same three surfaces" annotated as true only because of F1f; the bar/empty sub-ruling and the landing sub-ruling added; the "near-unreachable" claim about ticked+`partial` **WITHDRAWN**. |
| 7 | `doc/claude/issues/0308-*.md` | the "overwrites the caption, the sidebar status line and the pane canvas" paragraph carries a **CORRECTION** block saying it was false on two of three surfaces and why. |
| 8 | `doc/claude/issues/0309-*.md` | **NEW.** The ticked-and-`partial` combination grows the tree without saying so, with the reviewer's reproducer, and with the `BK33`-restatement cost that is the reason it is tracked rather than done here. |

### One reviewer fix NOT taken, with the evidence

Finding `f1e-notice-claims-scope-shown-on-partial-landing` proposed two things. The
sentence-composition half is **taken** (change 2 above). The gating half — "fire only when
`[lindex $res 0]` is `ok` or `alldbs`" — is **NOT taken, deliberately**, because it
reintroduces the falsehood it is meant to remove. On a `partial` landing inside a foreign
VCD the pane is empty for exactly the same reason it is empty on an `ok` (item 15's `BD70d`
limit: the pane reads the CURRENT database's entries), so suppressing the notice hands that
landing straight back to `browser_sea_refresh`'s shipped `seaempty` arm and its
`'TOP' has no signals of its own` — about a node inside a database that does have signals
there. Naming the landing removes the contradiction the reviewer found; dropping the arm
would only hide it behind the original false caption. `FV45` asserts BOTH halves in one
tuple: leg 1 is that the notice still fires on a `partial`, legs 2/3 that it names `TOP` and
not `TOP.dcell`.

## 7.3 Re-sabotage — 12 patches, every check this pass touched or whose subject it changed

Byte-exact backup, `md5sum -c` verified before and after **every** restore, never
`git checkout --`. Backup hashes: `ase.tcl 78294875…`, `wave_viewer.tcl 23c29400…`,
`test_ase_cosim.tcl 09cac9dd…`, `test_wave_sigbrowser_digital.tcl d029a9e4…`.
Suites: `test_ase_cosim` (`--nogui`), `test_wave_sigbrowser_digital` (`:0`), both through
`tests/headless/run_suites.sh` with `GUI_GATE=1`, the user's panel live and untouched.

| # | what was broken | checks that went RED |
|---|---|---|
| R-S1 | **step 6c `catch {update}` DELETED** — the fix removed outright | `FD23` `FD24`; `FV46` (`got '0 0 0'`) |
| R-S2 | step 6c flush **MOVED above step 6**, so it flushes before the last tree move | `FD23` `FD24`; `FV46` (`got '1 0 1'` — the position leg alone) |
| R-S3 | `browser_sea_empty` reverted to the conflating one-liner | `FD26` |
| R-S4 | 7b sentence composed from `[lindex $dig 2]` again | `FV45` (`got '… 0 1'` — names `TOP.dcell`, not the landing) |
| R-S5 | `set browserseanote($token) {}` removed from `browser_sea_refresh` | `FD03` `FD22` `FD25` |
| R-S6 | `browser_sea_empty` → always `0` | `FD19` `FD23` `FD24` |
| R-S7 | `browser_sea_empty` → always `1` | `FD19b` `FD23` `FD26` |
| R-S8 | RULING F1e's arm neutered (`} elseif {0} {`) | `FV41` `FV42` `FV45` `FD23` `FD24` |
| R-S9 | the pane predicate dropped from the arm's guard | `FV32` `FV43` |
| R-S10 | `ase::browser_pane_unread` made non-total (guard + `catch` deleted) | `FV44` |
| R-S11 | **the step-3c probe MOVED BELOW `wviewer::open`** — the item's mandated order sabotage | `FV32` `FV33` `FV34` `FV36` `FV38` `FV39` `FV41` `FV43` `FV45` |
| R-S12 | F5's `notraced` cause relabelled `notloaded` | `FV12` `FS42` |

**Zero survivors.** Every check added by this pass reds under at least one patch that breaks
what it claims to test, and the two INHERITED guarantees the item's contract names explicitly
are re-proved: R-S11 reddens **both** order witnesses (`FV33` live call order, `FV39` source
layout), so a future reordering cannot satisfy one by breaking the other; R-S12 shows F5's
cause codes are genuinely distinguished rather than collapsed.

**The reviewer's own unnamed sabotage now fails loudly.** R3-S1 (`browser_sea_refresh` called
immediately after the notice — semantically what Tk does one turn later) left both suites ALL
PASS before this pass. It is R-S5's mechanism, and `FD25` plus `FD22` plus `FD03` now catch
it.

## 7.4 The carry-over — ENDED, on a quiescent tree, with a paired 12-run experiment

The reviewer's objection to §5b was correct on process: those runs were taken while another
agent was concurrently patching the shared working tree (`src/ase.tcl`'s md5 moved twice in
two minutes and at one point carried two live sabotages). This pass re-ran the experiment
with **no other agent touching the tree**, and the reviewer's "deterministic core" is the
thing being tested.

**Method.** `tests/headless/run_suites.sh -n 3 test_wave_sigbrowser test_wave_sigbrowser_sea`
— the two rows carrying the alleged core — run **at HEAD (this pass's tree)**, then with
`src/ase.tcl`, `src/wave_viewer.tcl` and `src/ciw.tcl` written from `git show 7a592f9c:…`,
which removes **all of items 3, 4 and 5**, then run again. Same binary, same `:0`, same
panel, same session, back-to-back. Sources restored from the byte-exact backup afterwards,
`md5sum -c` OK. 12 runs in all.

| | `test_wave_sigbrowser` | `test_wave_sigbrowser_sea` |
|---|---|---|
| **HEAD** (items 3/4/5 present) | 3, 6, 10 red | 23, 21, 12 red |
| **BASE** (items 3/4/5 reverted) | **7, 7, 10 red** | **7, 24, 25 red** |

**Both rows are FAIL in 6 of 6 runs at HEAD and 6 of 6 runs at BASE.** `test_wave_sigbrowser`
fails *more* with the items removed. The alleged deterministic core, per-id, across the three
base runs:

| id | at HEAD | with items 3/4/5 REVERTED | verdict |
|---|---|---|---|
| `BT27` | 2 of 3 runs | **3 of 3 runs** (11 red check-lines vs 3) | not ours — fails MORE at base |
| `BT29` | 2 of 3 | **3 of 3** | not ours — fails MORE at base |
| `BT45` | 3 of 3 | **3 of 3** | not ours — identical |
| `BQ66b` | 2 of 3 | **2 of 3** | not ours — identical |
| `BQ71` | 2 of 3 | **2 of 3** | not ours — identical |

**`BT45` is settled by its own failure string, which is byte-identical in both arms:**

```
FAIL: BT45 the sidebar is narrower than the canvas on a real viewer
      -> {not-narrower (w=320 240 80 settled)} (exp {narrower})
```

The reviewer was right that this is geometry and not key delivery — and BT45's own comment in
`tests/headless/test_wave_sigbrowser.tcl` documents it as **"THE NAMED FLAKY CHECK"** with
exactly this mechanism: `wviewer::browser_width` caps the sidebar at 45% of the toplevel but
**floors it at 240 px**, so on a toplevel the WM has not grown to final size the floor wins
and the sidebar is legitimately wider than the canvas. `w=320 240 80` is a toplevel that
settled at 320 px. In this session's WSLg that happens every time, which is why it looks
deterministic; it is deterministic in the *environment*, and it happens identically with
every line of items 3/4/5 removed.

**CONCLUSION, and this ends the third pass.** Zero of the green→worse rows is attributable to
items 1-5. The reviewer's "deterministic core" is real as an observation and wrong as an
attribution: three of its five members fail as often or more often with the items gone, and
the other two are unchanged. What is also now established, and matters more than the per-row
membership: **`test_wave_sigbrowser` and `test_wave_sigbrowser_sea` are red at the BASELINE
COMMIT'S OWN Tcl on this display, in 6 of 6 runs.** `baseline_status.txt` records both as
PASS at `7a592f9c` — so those two PASSes were a lucky sample of a flaky pair taken under a
different display condition, not a state this session can return to.

**Per the reviewer's advice the per-row table of §5b should not be read as fact** — membership
churns run to run (this pass measured `test_wave_sigbrowser` at 3, 6 and 10 red on three
consecutive runs of the *same* tree). The durable findings are the two above: nothing is
attributable to items 1-5, and the baseline's PASS on these rows is stale. **The batch should
re-baseline on the current display rather than re-litigate these rows a fourth time.**

## 7.5 Suites, verbatim

```
tests/headless/run_suites.sh --nogui test_ase_cosim
  PASS | test_ase_cosim               run 1/1  RESULT: ALL PASS (310 checks)
tests/headless/run_suites.sh test_wave_sigbrowser_digital
  PASS | test_wave_sigbrowser_digital run 1/1  RESULT: ALL PASS (25 checks)
tests/headless/run_suites.sh test_wave_sigbrowser_keys
  PASS | test_wave_sigbrowser_keys    run 1/1  RESULT: ALL PASS (48 checks)
```

`test_wave_sigbrowser_keys` **ALL PASS including `BK40`** on this tree, standalone, forty
minutes before the audit scored the same file FAIL on `BK40` alone. One tree, two answers —
that is the flake, measured inside one session, and it is why `BK40` appears in the audit's
green→worse list below and nowhere else.

## 7.6 The audit — a DIFF, by NAME and STATUS, in both directions

`tests/headless/full_audit.sh`, `DISPLAY=:0`, `GUI_GATE=1`, the user's panel live and
untouched (control `RUN` throughout, never written to). Diffed against
`doc/claude/batch_F/baseline_status.txt` (exists; `7a592f9c`, 364 rows).

```
307 rows: 273 PASS / 33 FAIL / 1 TIMEOUT / 0 CRASH / 0 SKIP
WIREEDIT: ALL PASS (58/58)      SCRATCH: 0 leaked dir(s)
```

**NEW (1)** — `test_wave_sigbrowser_digital` **PASS**. The file this item adds.

**RED→BETTER (7)** — `test_ase_plot` TIMEOUT→FAIL (red→red flavour, its documented P4/P6/P8
flake), plus the same six every pass in this batch has reported:
`test_fluid_bodyshove_guards_0132`, `test_fluid_editing`, `test_wave_crossdb_trace`,
`test_wave_sigbrowser_i12`, `test_wire_vertex_grab` FAIL→PASS and
`test_rotate_stretch_dangling_0103` SKIP→PASS. These are collateral of the X death **during
the baseline run**, recovering — not this item.

**GONE (58)** — every `test_wireedit_*` row. **Parsing artifact, not a regression:**
`full_audit.sh` prints that section in a different format, and its own summary line reads
`WIREEDIT: ALL PASS` with all 58 files `RESULT: ALL PASS`.

**GREEN→WORSE (11)**, with the failing check ids, which is what makes them attributable:

| row | failing ids | reading |
|---|---|---|
| `test_wave_sigbrowser` | `BT25 BT26 BT27 BT29 BT45` | **PROVEN environmental, §7.4**: FAIL in 3 of 3 runs with items 3/4/5 REVERTED, and *more* red at base than at HEAD. `BT45`'s failure string is byte-identical in both arms and is the WM-sizing mechanism its own comment documents. |
| `test_wave_sigbrowser_sea` | `BQ53 BQ65 BQ66b BQ67 BQ73` | **PROVEN environmental, §7.4**: FAIL in 3 of 3 base runs; `BQ66b`/`BQ71` fail as often at base as at HEAD. |
| `test_wave_sigbrowser_keys` | `BK40` | **PROVEN flake, §7.5**: same tree, same session, ALL PASS standalone. |
| `test_wave_sigbrowser_panes` | `BW46` | `BW46` IS the delivery precondition — its own name is "the keystrokes were really delivered". |
| `test_wave_tabs` | `TG16` | "a real Ctrl-N opened a tab" — key delivery. |
| `test_wave_sigbrowser_i1315` | `BR25` | `<Return>` reaches the commit path — key delivery. |
| `test_multi_window` | `MWf` | focus delivery. |
| `test_wave_modes` | `MG16` | key delivery. |
| `test_ase_dialogs` | `G2 G4` | dialog focus; the salvage measured this row failing MORE with the items reverted (20 vs 10). |
| `test_cmdmode_descend_0201` | `DS7b DS7b2 DS7b3 DS7c` | command-mode keystrokes. |
| `test_wave_viewer` | `G5 G6 G9a` + `TD7 TD8 TD9` | `G5`/`G6`/`G9a` are delivery legs; `TD7`-`TD9` read the CURSOR SHAPE (`got tcross` / `sb_v_double_arrow`), which is the documented WSLg stale-cursor condition — the same one that produced issue-free re-runs after a `wsl --shutdown`. |

**Every one of the eleven is a key-, focus- or cursor-delivery leg**, two of them proven
environmental by direct base comparison and one proven flaky inside a single session. **Zero
are attributable to items 1-5.** Nothing this item touches is anywhere near a Tk binding, a
focus grab or the event queue except step 6c's single `catch {update}` — and that line is in
`ase::show_in_browser_for_current`, which **only** `test_ase_cosim`,
`test_wave_sigbrowser_digital` and `test_wave_sigbrowser_keys` (source-only) reach; all three
are green.

**Three audits of the same tree have now produced three different sets of "ten or eleven"**
(the salvage's, the verifier's and this one differ on `test_wave_tabs`, `test_wave_viewer`,
`test_wave_sigbrowser_keys` and `test_wave_sigbrowser_panes`). The membership is the churn;
the family is the finding.

> **⚠ ONE HONEST CAVEAT ON THIS AUDIT'S SCOPE.** It was run on the tree BEFORE `FD27` and one
> accuracy comment in `ase::browser_pane_unread` were added — deliberately, so that no source
> file changed underneath a running audit (the process failure the review caught in the
> previous pass). The delta is one added check in a file the audit scored PASS, plus a
> comment; both suites were re-run ALL PASS afterwards (`310` and `25`), and `FD27` was
> sabotage-verified (row R-S13). No other row can be affected.

| # | what was broken | checks that went RED |
|---|---|---|
| R-S13 | step 6c `catch {update}` deleted again, with `FD27` now present | `FD23` `FD24` **`FD27`** |

## 7.7 Findings raised by the review and NOT acted on, so the record is honest

* **"Fire step 7b only on `ok`/`alldbs`"** — the gating half of the partial-landing finding.
  Not taken, with evidence, for the reason set out at the end of §7.2: it reintroduces the
  false `seaempty` caption on the very path the reviewer's own reproducer found. The
  sentence-composition half of that same finding IS taken.
* **Receipt hygiene items** — the bogus backup hash in §4 (`7a5d82d8…`, which matches no
  version of the file) is corrected to `4cb2128a…` in place, and the "42 patches" / "54
  patches" contradiction in §6 is corrected to 54, which is what the table plus `S24` count.
* **"Drop the per-row green→worse table"** — partially taken. §5b's table stays as the record
  of what that pass measured, but the header now points at §7.4, and §7.6 states plainly that
  membership churns and that three audits produced three different sets.

## 7.8 The eyeball — unchanged in kind, sharper in target

The payload is still rendered text in a pane, so the verdict is **[E]**. What a human must
look at is now narrower and more specific, because the mechanism is understood:

1. **Ctrl-Alt-V on a code block, then LOOK AT THE PANE CAPTION AND LEAVE IT ALONE FOR A
   SECOND.** The whole defect this pass fixed was a caption that was right for one frame.
   The sentence that must still be there after the gesture settles is *"showing the digital
   scope '…' of '….vcd' in the tree, but the lower pane lists only the current results
   database, so this scope's own signals are not in it yet"* — **not** "'…' has no signals of
   its own".
2. The same, on the **refusal** path (a code block whose run promised no VCD): the caption
   must still read "no digital signals to show: …" a second later.
3. Whether the long sentence **clips** on the pane caption and the sidebar status line at
   default sidebar width AND with the sash dragged narrow. This is the one question the
   checks genuinely cannot answer, and whether F5 needs a short form is still unsettled.
4. The CIW pair reading as ONE account (what was shown, then the caveat) and the `note`
   colour reading as a caveat rather than an error.

Still true from the salvage pass: no real co-simulation ran (both suites synthesize their
databases with `mkraw`/`mkvcd`), so Verilator's real scope naming remains untested.
