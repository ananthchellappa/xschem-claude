# Item 7 — `Results ▸ Select…`, the ASE-L dialog (R401-R407) — **`[E]`**
**PIXEL DELIVERABLE**; not verdictable `[x]` however many checks pass. Two `owed.sh look` debts raised (§5). Covers the implementer round plus the fixer round that closed all six confirmed review findings. Full rationale lives in `doc/claude/specs/results_selection.md` §6.1, not here.
## 1. Files changed
| file | +/− | what |
|---|---|---|
| `src/ase_window.tcl` | **+879 / −0** | the `Select…` menu entry (R401) and the dialog: 25 `ase::ui::rsel_*` procs |
| `tests/headless/test_results_dialog.tcl` | **new, 918** | groups RA..RF, **SEL360-SEL416 = 57 checks** (31 without a DISPLAY) |
| `doc/claude/specs/results_selection.md` | +244 / −7 | new **§6.1** (R407a…R407i), §18 re-check, five stale citations re-derived |
| `tests/headless/test_wave_grid.tcl` | +24 / −2 | **GX9 restated** 2 → 3 `regenerate` sites, **plus a new leg** pinning the fold order (§2) |
| `src/results.tcl` | +3 / −3 | citation sweep only (`ase::ui::viewer_restore` 3562 → 4441) |
| `tests/headless/test_ase_dialogs.tcl` | +6 / −2 | comment only: GE header narrowed from "EVERY ASE-L dialog" to the item-10 set |
| `tests/headless/test_results_select.tcl` | +1 / −1 | citation sweep only |
| `specs/typed_signal_accessors.md`, `results_batch/PLAN.md` | +5 / −5 | citation sweep; **already stale at HEAD** (−134), re-derived in the same pass |
No C, no rebuild. Fence held: no Waves menu (item 8), `raw_is_loaded` untouched (item 9), `calculator.tcl` untouched (item 10), `results::select` not widened, **no cascade added to the viewer's menubar** (R504/D12).
## 2. Decisions taken, and the evidence
Ten crew rulings, all written into `results_selection.md` **§6.1** with their rationale and rejected alternatives; none re-opens `DECISIONS.md`; each carries a check and a sabotage that reds it (§4).
- **R407c — THE OPEN QUESTION ITEM 4 HANDED THIS ITEM, RULED.** The dialog passes the type it knows: (1) a `Loaded` row passes **its own** type, per SLOT — U11 makes one file's `dc` and `tran` two rows and one result, so a by-path lookup picks the wrong analysis of the right file; (2) a `Recent`/typed path that normalises onto a loaded slot **inherits that slot's type**, so a VCD stays re-selectable by name for as long as it is a loaded database; (3) otherwise **no type is passed and none is invented**, and the refusal is `results::select`'s own sentence. `<NULL>` maps to the empty type at every hand-off (a rendering, not a token). Both driver-named alternatives were rejected with measured reasons: extension sniffing is a guess that would *break* the case clause 2 gets right (an explicit non-spice type makes `raw_select()` refuse a file loaded under another analysis — R301b's guard), and "disabled with a reason" needs the same sniff so it would grey out most of the MRU. Residual case — one MRU entry of a digital database no longer loaded — is inside §16's declared non-goal. Pinned SEL360/364/367/372/373/374/409.
- **R407a — which context.** Borrow the session's viewer (`enter_ctx`/`leave_ctx`); with none, read the current context and say so in the `Loaded` title; **a refused ticket is reported AS refused, never as "no results"** (F6). Refusing outright with no viewer was rejected — "evaluate against last night's raw" is precisely the pre-run case. SEL365/368/369/410.
- **R407b/b.1 — one sentence composed once**, to `host ase` (R802) and the Status region. F2/F3 fix: a physical Return is a KeyPress *and* a KeyRelease, so the 250 ms debounced preview overwrote the door's sentence a quarter-second later, and erased refusals outright. Two halves because they are two races — `%K` plus a `Return`/`KP_Enter`/`Escape` guard, **and** the commit cancels an already-pending preview. SEL371/375/412/415.
- **R407d/R406 — one armed candidate**, the Path entry is its readout; `Select`, `<Return>` and double-click share ONE commit path; the dialog stays open and refreshes. SEL402/403/413/415/416.
- **R407e — resolver inputs** are `rawfile` + `rundir` + an **existing** `<rundir>/<cell>.spice`. **`key` is deliberately NOT passed**: it reaches `ase::last_rawfile` → `ase::rundir`, which `file mkdir`s and rewrites the global `::netlist_dir` — on every row click. SEL381-385.
- **R407f — the regenerate runs INSIDE the loan** (`with_edit`'s `switch_ctx` does not restore; landmine L7). SEL410 plus the new GX9 leg.
- **R407g/g.1 — a non-file candidate is refused ahead of the door**, so the resolver's derived fallback cannot substitute a different result. F1 fix: the guard resolved the raw spelling against the process CWD while the preview one region above used the session `rundir`, so a legitimately relative `Loaded` row previewed `Using an.raw.` and was then refused by its own `Select` button. New `ase::ui::rsel_abs` resolves against the same rundir; the **original spelling** is still what the door is handed (R302a's one-spelling rule is `results::_engine_spelling`'s, not the dialog's). SEL376/377/411.
- **R407h — `default`/`ok`/`stale` are quoted verbatim from the resolver, `invalid` is not**, because R407g means the fall-back its sentence describes cannot happen. SEL386/387.
- **R407i — `rsel_close` takes every record its own header promises**, `rselstatus` included (F5). SEL407/414.
- **`results::_same_path` is called deliberately** — "same file?" is ruled once in R302a/R302h and a second copy would drift; a public alias was declined as wider than this item's fence. Foot of §6.1.
- **`test_wave_grid` GX9's expectation genuinely changed** (2 → 3 `regenerate` sites in `ase_window.tcl`): the check says every site in this file is a KNOWN one taking issue 0194's fold, and `rsel_commit` is exactly that. Restated in place with the reason, **plus a new leg** asserting `capture_live_view_state` < `results::select` < `regenerate` < `rsel_release`, so raising a count can never be the way past it. 399 → 400 checks; nothing renumbered or dropped.
## 3. Checks and result
`tests/headless/test_results_dialog.tcl`, new, **SEL360-SEL416 = 57 checks**; band measured free at 359 by grepping `tests/headless/*.tcl`, not from a doc. PRE-drive on the byte-exact pre-item source: **11 FAILED / 1 passed then abort** — the one pass is SEL361, a fixture guard, so no feature check passes before the feature exists.
```
PASS     | test_results_dialog          run 1/2  RESULT: ALL PASS (57 checks)
PASS     | test_wave_grid               run 2/2  RESULT: ALL PASS (400 checks)
```
`--nogui` arm: `RESULT: ALL PASS (31 checks)`, printing `gui legs not run (no usable DISPLAY)` — none of `full_audit.sh`'s three skip banners, so the 31 that ran are still scored. Nine-suite `run_suites.sh` run: 8/9, the one FAIL being `test_ase_window` W7, the brief's named pre-existing red.
**Audit — a DIFF, not a count** (`GUI_GATE=1 tests/headless/full_audit.sh`, dev display `:99`, shot by the closer on the final tree): `SUMMARY: 333 pass  15 fail  0 crash/timeout  0 skip  (total 348)`, `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`, `TREE: 2 appeared 0 vanished` — the two being `scratchpad/item07-close/{join.py,msg.txt}`, the closer's own join script and commit message, written after the snapshot; report-only and outside the repo's tracked tree. Joined by test NAME and STATUS against `baseline_2026-08-19_226302f9.txt` (331 pass / 15 fail / 0 crash / 0 skip of 346): **STATUS CHANGED 0 · ONLY IN BASELINE 0 · ONLY IN NEW 2** — `test_results_select` (item 1, already declared in `LEDGER.md`) and `test_results_dialog` (this item; the driver owes it a row in the added-suites table, total 348). The 15 reds are the baseline's 15 **by name**. Counting note: `FAIL     | key …` is within-file detail, not a row — the join anchors on `test_\S+`. `~/.xschem` `raw_history` `34ff432f…` and `recent_files` `f219bba5…` byte-identical before and after every drive and the audit.
## 4. Sabotage
Every drive: break, run, record reds, restore from a byte-exact backup (md5 asserted — never `git checkout --`, the item is uncommitted), re-run green. **65 drives, seven rounds, all restored green.** Drivers `scratchpad/item07{,-fix}/sab*.py`.
| check | what was broken | red? | green? |
|---|---|---|---|
| SEL360 | `rsel_type_norm` passes `<NULL>` through | y | y |
| SEL361 | **UNSABOTAGED — not evidence.** Fixture precondition (`xschem raw read` → `1 1`); no item-7 code under it | — | — |
| SEL362 | `results::_same_path` → a raw string compare | y | y |
| SEL363 | the `if {$same}` guard removed — first row's type for any path | y | y |
| SEL364 | `type_for` returns the raw state type, no `<NULL>` mapping | y | y |
| SEL365 | the no-viewer arm stamps `where viewer` | y | y |
| SEL366 | rows lose `cur` — no row ever marked current | y | y |
| SEL367 | `Recent` rows never inherit `inreg`; and never inherit the slot type | y | y |
| SEL368 | a refused ticket dressed as an empty list (F6's exact defect) | y | y |
| SEL369 | the refusal sentence → "There are no results." | y | y |
| SEL370 | `rsel_commit` returns 0 for every outcome | y | y |
| SEL371 | the door's sentence never reaches Status (fixed literal) | y | y |
| SEL372 | the row's type re-derived BY PATH (U11's wrong analysis) | y | y |
| SEL373 | the clause-2 type fallback deleted | y | y |
| SEL374 | a type INVENTED for an unknown path | y | y |
| SEL375 | `host ase` dropped; and `key` added to the opts | y | y |
| SEL376 | the R407g guard neutered — a missing file goes to the door | y | y |
| SEL377 | the refusal sentence re-worded | y | y |
| SEL378 | every outcome reported as success | y | y |
| SEL379 | the Status write replaced by a fixed literal | y | y |
| SEL380 | the empty-candidate arm neutered | y | y |
| SEL381 | `rundir` input deleted; netlist derivation deleted; `key` added | y | y |
| SEL382 | the `[file isfile $nl]` existence gate removed | y | y |
| SEL383 | the rundir-emptiness gate → `if {1}` | y | y |
| SEL384 | `key` put into the resolver input (R407e reversed) | y | y |
| SEL385 | the `netlist` input deleted — `stale`'s mtime half cannot fire | y | y |
| SEL386 | the resolver's msg wrapped instead of quoted | y | y |
| SEL387 | R407h reversed — the resolver's `invalid` msg quoted | y | y |
| SEL388 | `rsel_commit` returns 0 under the raised MRU flag | y | y |
| SEL389 | the `Results` menu separator deleted | y | y |
| SEL390 | the `Select…` entry's `-command` retargeted at `direct_plot` | y | y |
| SEL391 | the dialog built withdrawn | y | y |
| SEL392 | the dialog takes a `grab` (R402 reversed) | y | y |
| SEL393 | `Loaded`/`Recent` grid rows swapped (R405/D2 reversed) | y | y |
| SEL394 | the same swap — `Loaded` no longer the first slave | y | y |
| SEL395 | the list scrollbar's `pack` deleted | y | y |
| SEL396 | an `OK` button created and packed | y | y |
| SEL397 | `Browse…`'s `pack` deleted | y | y |
| SEL398 | the current slot never marked; and the `here` arm mislabelled `viewer` | y | y |
| SEL399 | `inreg` forced 0 — `Recent` never distinguished | y | y |
| SEL400 | the balloon carries the row label, not its full path | y | y |
| SEL401 | the `<Motion>` binding deleted | y | y |
| SEL402 | `rsel_dblclick` picks but never commits | y | y |
| SEL403 | `rsel_arm` stops filling the Path entry | y | y |
| SEL404 | `rsel_browse` → `rsel_commit`, so `Browse…` SELECTS | y | y |
| SEL405 | the `plain` row tag's foreground hardcoded, off the palette | y | y |
| SEL406 | re-invoking REBUILDS instead of raising and refilling | y | y |
| SEL407 | ESC → a bare `destroy`; and `rsel_close` stops unsetting `rselstatus` | y | y |
| SEL408 | a `Results` cascade added to the VIEWER's menubar (R504/D12) — other file, restored byte-exact | y | y |
| SEL409 | a by-path dedupe added — one file's two analyses collapse to one row | y | y |
| SEL410 | the loan never released; and the regenerate moved OUTSIDE it (R407f) | y | y |
| SEL411 | `rsel_abs` drops the rundir join — the shipped F1 defect put back | y | y |
| SEL412 | the `Return`/`KP_Enter`/`Escape` guard removed; the commit's cancel deleted; `%K` dropped | y | y |
| SEL413 | `Select`'s `-command` → `rsel_preview` (exists, does not commit) | y | y |
| SEL414 | `Close`'s `-command` emptied; `wm protocol` deleted; `rselstatus` left behind | y | y |
| SEL415 | the `<Return>` binding deleted | y | y |
| SEL416 | `rsel_pick` discards the row's own type | y | y |
| GX9 restated (`test_wave_grid`) | **both directions** — the regenerate deleted (count 2), a fourth emitter added (count 4) | y | y |
| GX9 new leg (`test_wave_grid`) | `capture_live_view_state` deleted; the regenerate deleted; the regenerate moved after `rsel_release` | y | y |
Three lessons paid for. (a) `if {0} {…}` is **not** a sabotage of a source-shape check — `count_emitters`/`string first` still see the text; those drives became evidence only once the lines were *deleted*. (b) Three checks were caught **weak** by sabotage and rewritten: SEL372 needed a two-plot `multi.raw` to separate R407c clause 1 from clause 2, SEL406 needed the Path entry's contents (a rebuild recreates the same window path), SEL405 needed the row **tags** (`apply_theme` re-skins chrome either way). (c) The review's own SEL413 recipe (retarget at a non-existent command) **aborts** the GUI leg instead of naming a red; S58b expresses the same defect so the check can speak.
## 5. What was NOT verified
- **THE PIXELS.** Region order, the bullet glyph, the accent colours, the balloon and whether the Status sentences read sensibly are asserted as widget facts (`grid info -row`, `winfo manager`/`ismapped`, `cget`, slave order) — the anti-vacuity ask, and still not a human looking at the window. **Two look debts raised:** `results-item7-select-dialog.1787215993.1250610` (region order; the marks on the current row and on already-loaded `Recent` entries; the balloon's FULL path; the Status sentence for ok / stale / missing; double-click re-plots with the window still open; modelessness) and `results-item7-fixer-round-two-gestures.1787221349.1339282` (the Return sentence must not flip back a quarter-second later; a rundir-relative `Loaded` row must SELECT; `Close` and the WM `X` must both dismiss).
- **Reviewer findings raised but not confirmed: none.** All six confirmed findings, plus a seventh (SEL416's gesture gap), are fixed and pinned in §4.
- **Marked not-proven by the reviewers and still not proven here:** the 65 sabotage drives were not re-run by the closer (one lens may not mutate the tree; another re-ran S34 and it behaved as claimed); the pixels; the rendered balloon (`balloon_show` returns early unless the X pointer is physically over the widget — the resolved text and the `<Motion>` binding are driven instead); multi-tab, a second ASE session, an installed tree, `:0`/WSLg event traffic, and a leak trace (`-d 3 -l log`).
- **Carried forward, named, not repaired.** (a) `rsel_commit`'s own fallback `msg` is a **dead branch** — `results::select` already returns that exact wording, so replacing the string leaves the suite green; harmless, and SEL379 is covered by the Status-write drive, but the first receipt's attribution for that one row was wrong. (b) The context loan is released by a plain call, not a `finally`: no reproducer was built and every throwing call found is catch-guarded, but this does not copy `signal_list_all`'s shape (L7). (c) `ase::ui::close` never `after cancel`s `rselprevid`/`rseltipid` — one never-rendered string on a dead key; a one-line fix, left so the audit stayed valid on this tree. (d) `results::persist` never fires from this dialog when the session has no viewer (`token` is set only under `haswin` and R407e withholds `key`); not shown wrong, since `wviewer::snapshot`'s writing branch is itself viewer-gated. (e) `rsel_commit` is the first **writing** caller of the `enter_ctx … 1` borrow door, whose stated precondition is read-only bodies: the doctrine breach is real, no harm was demonstrated, and it is not this item's to close.
- **No `.sh` suite touched**, so nothing needed a by-hand run outside `full_audit.sh`'s `test_*.tcl` glob.
