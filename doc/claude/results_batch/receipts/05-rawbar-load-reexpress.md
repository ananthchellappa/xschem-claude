# Item 5 — `wviewer::rawbar_load` re-expressed on `results::select` (R501, T-C)

## 1. Files changed

| file | lines | what |
|---|---|---|
| `src/wave_viewer.tcl` | **+103 / −9** | `rawbar_load` comes through R303's door; the five arms labelled in place; header records what moved, what stayed, and the five measured divergences |
| `tests/headless/test_results_select.tcl` | **+550** | groups **AM** and **AN**, **SEL295-SEL338 = 44 new** ids, total **340** |
| `tests/headless/test_wave_sigbrowser_i1315.tcl` | **+44 / −8** | **BR06 and BR07 RESTATED** (4 legs) + 1 new anti-vacuity leg; 191 → **192** |
| `doc/claude/specs/results_selection.md` | **+188 / −4** | new **§7.1** (R501a/b/c, l.1028-1242); §12's T-J note (l.1533) records item 5's half discharged |
| `doc/claude/issues/0515-rawbar-load-refused-context-switch-is-silent.md` | new, 89 | filed here, **OPEN**, deliberately unfixed |
| `doc/claude/issues/status.md` / `results_batch/CREW_BRIEF.md` | +1/−1, +13/−1 | 0514 → 0515; CREW_BRIEF §3 gains the four-writers rule (§2) |
| this receipt | new | — |

**No C, no rebuild.** `git diff src/results.tcl` is **EMPTY** (`bf565ec6…`, item 4's file byte-for-byte): the door's contract was not widened, and every `results.tcl` edit in §4 is a sabotage that was restored and `cmp`-verified. Scope fence held — `wviewer::snapshot`/`ase::ui::viewer_restore` (item 6), the Select dialog (7), the Waves menu (8), `raw_is_loaded` (9) and `calculator.tcl` (10) are untouched.

## 2. Decisions taken, and the evidence

**The five arms, MEASURED FIRST** on the pre-item body (`scratchpad/item05/tc_probe.tcl`) and re-measured after. The arms themselves did not move:

| arm | condition | sentence | rc |
|---|---|---|---|
| 1 | the token names no viewer window | **SILENT** | 0 |
| 2 | nothing typed | `Location: type the path of a raw file` | 0 |
| 3 | `![file isfile $path]` | `Location: no such file '<tail>'` | 0 |
| 4 | `![wviewer::switch_ctx $token]` | **SILENT** | 0 |
| 5 | the engine refused the file | `Location: could not read '<tail>'` | 0 |

**Moved into the door (R303):** the resolver, R302a's one-spelling-per-run, the `xschem raw select` verb, the MRU push, `casemode_invalidate`/`reapply`, `browser_refresh $token 1`, `results::persist`. **Stayed in the viewer (R501):** the `file isfile` guard (arm 3 is about a typo in an entry box the user is looking at, not a stored selection that went missing); `switch_ctx` (R302e — the registry is per-`Xschem_ctx`, and a bracket inside the door would put an enter/leave pair around the engine call, the window L7 forbids a redraw in); `capture_live_view_state`; `regenerate`; `rawbar_sync`; `log_action`; and the three sentences (R501a).

Three crew rulings, written into `doc/claude/specs/results_selection.md` **§7.1**. None re-opens `DECISIONS.md`.

- **R501a (l.1035) — T-C outranks the sentence half of R501's rationale**, so `rawbar_load` passes `host none` and keeps its own three `Location: …` strings. The MRU half **did** unify, and its delta is provably identical because `wviewer::rawhist_add` (`wave_viewer.tcl:8208`) `file normalize`s its own argument (SEL312). The sentences could not: the texts differ, and `results::select` emits **on success**, which `rawbar_load` never has — routing them would put a brand-new sentence into the sidebar on every successful load. The channel is unified either way (both end in `wviewer::browser_status`); what T-C freezes is the TEXT.
- **R501b (l.1059) — the two silent arms stay silent, and that SATISFIES T-J** (the F6 borrow half §12 reassigned here) rather than overriding it. `rawbar_load` takes **no borrow ticket** — `enter_ctx`/`leave_ctx` appear in neither proc (SEL332) — and its return set is exactly `{0 1}` (SEL319), so a refusal has no answer it could be mistaken for. What remains is an **R801** gap on arm 4 alone (arm 1's silence is forced: no window ⇒ no sidebar). **Filed as issue 0515, OPEN, deliberately unfixed** — T-C's own text names the silence, and repairing it is the one change this item forbids. 0515 carries the one-line fix and names SEL303/304/317/318 as the checks to restate with it.
- **R501c (l.1104) — FIVE divergences are real, are ruled acceptable, and are each measured** against the frozen PRE body in the same process: (1) one spelling per run — PRE made a permanent duplicate slot, SEL320/321; (2) the case-mode cache is now invalidated and the override re-applied, SEL322; (3) a one-point OP/DC now publishes — PRE left **the schematic annotated from one database while the viewer drew another**, SEL323/324; (4) a typeless re-load keeps the analysis you are standing on, SEL325/326; (5) **a `~/`-spelled path now LOADS where PRE refused it** (arm 5 → success), the only divergence that moves rc and the sentence together, SEL337/338. Plus one ordering: `browser_refresh` now precedes `regenerate` (SEL327/328), being one of R302d's side effects. Unchanged: `capture_live_view_state` is still first (SEL329) and the widget tail still gets the path the USER typed (SEL330, SEL336).

**BR06/BR07 of `test_wave_sigbrowser_i1315` RESTATED — not deleted, not renumbered.** They are source-shape legs that grep `rawbar_load`'s body for `rawhist_push` and `browser_refresh $token 1`, the two calls this item moves, and the first audit turned that suite red on them. The rule did not change, only the place it is enforced, so each leg now asserts **both** halves — gone from the viewer proc **and** present and correctly ordered against `results::select`'s own `rc == 0` bail-out — plus a new leg asserting the door's body was found at all (`regexp -all` over `{}` is 0, so a rename would make every leg vacuously green).

**⚠ `~/.xschem/recent_files` was damaged by this item's first draft, and has been REPAIRED.** `::update_recent_files` ungates **four** writers, not one. `wviewer::rawhist_push` was shimmed correctly from the first draft (`~/.xschem/raw_history` is md5 `34ff432f…` throughout), but the same flag ungates `update_recent_file` → `write_recent_file` (`xschem.tcl:3869`/`:3911`), which fires on every `xschem load`; raising it across `am_run`'s `loadcell` pushed ten scratch `cellA.sch` paths through a list capped at 10. Fixed both ways in the suite — `write_recent_file` shimmed and restored (proved by body in SEL333), and the flag raised only around the call under test. **Repair applied and verified by content, not by a green suite:** `grep -c _resultssel_ ~/.xschem/recent_files` 1 → **0**, ten real entries back, md5 `f219bba5…`. The recovered list is **stale from 2026-07-13**; entries added since are gone for good. The durable rule is now in `CREW_BRIEF.md` §3.

## 3. Checks and result

`tests/headless/test_results_select.tcl` groups **AM** (T-C, the before/after tuple) and **AN** (the divergences and the rulings): **44 new ids SEL295-SEL338, 340 total**, band measured free at 294, nothing renumbered. `tests/headless/test_wave_sigbrowser_i1315.tcl`: BR06/BR07 restated + 1 leg, **192**. **T-C is a COMPARISON**: the pre-item body is frozen in the suite as `wviewer::rawbar_load_PRE` and every scenario runs twice from an identical registry with the two observable tuples (rc, registry before/after, current database + analysis, MRU, sidebar sentences) diffed. SEL295 is the anti-vacuity gate for the whole group.

Both suites re-run by the closer on the final tree, `GUI_GATE=1` through `run_suites.sh`, dev display `:99`:

```
PASS     | test_results_select          run 1/2  RESULT: ALL PASS (340 checks)
PASS     | test_wave_sigbrowser_i1315   run 2/2  RESULT: ALL PASS (192 checks)
RESULT: 2/2 runs passed
```
`--nogui` arm of the same file: `RESULT: ALL PASS (340 checks)`. `~/.xschem` checked before and after every run — `raw_history` `34ff432f…`, `recent_files` `f219bba5…`, `grep -c _resultssel_` **0**: unchanged, no droppings.

**Audit — a DIFF, not a count.** `GUI_GATE=1 tests/headless/full_audit.sh`, dev display `:99`, taken by the closer on the final tree:

```
SUMMARY: 332 pass  15 fail  0 crash/timeout  0 skip  (total 347)
WIREEDIT: ALL PASS / PASS      SCRATCH: 0 leaked dir(s)
TREE:     0 appeared  0 vanished (report only, gitignored paths excluded)
```
Joined by test NAME and STATUS against `baseline_2026-08-19_226302f9.txt` (331/15/0/0 of 346):
```
baseline rows 346   new rows 347
baseline: PASS 331  FAIL 15        new: PASS 332  FAIL 15
STATUS CHANGED (0):
ONLY IN BASELINE (0):
ONLY IN NEW (1):    test_results_select   PASS
```
**0 green→red and 0 red→green across all 346 shared rows, and nothing only in the baseline.** The single extra row is `test_results_select` PASS, which `LEDGER.md` records as added by item 1 and the brief names as a legitimate extra. The 15 reds are the baseline's 15 **by name**: `test_ase_window`, `test_cadence_drag`, `test_ciw`, `test_gf180mcud_libmgr`, `test_ihp_sg13g2_libmgr`, `test_lib_manager_gui`, `test_lib_manager_locate`, `test_lib_sweep`, `test_reopen_readonly`, `test_rotate_stretch_short_0104`, `test_selflog_output`, `test_sky130a_libmgr`, `test_wave_markers`, `test_wave_sigbrowser_0312`, `test_wave_sigbrowser_keys`. Counting note: a naive `grep -cE '^FAIL'` over-counts, because within-file detail is spelled `FAIL     | key …`; the join anchors on `test_\S+`, which is what makes the row counts 346/347.

**The item's FIRST audit was red and the red was this item's own** — `test_wave_sigbrowser_i1315` PASS → FAIL, on BR06/BR07. Cause and disposition in §2; restated, not deleted, not renumbered.

## 4. Sabotage

27 drives (16-drive matrix + pre-feature drive + 10 fixer drives), each broken, run, restored from a byte-exact backup (`cmp`/`filecmp`-asserted; never `git checkout --`, the item is uncommitted) and re-run green. Drivers: `scratchpad/item05/sab.py`, `scratchpad/fix05/sab.py`. **All 27 restored green.** Rows are keyed by drive and name every check id; the union below covers **all 44 new SEL ids and all 5 restated/new BR legs — no new check is unsabotaged.**

| drive | what was broken | went red | restored green |
|---|---|---|---|
| PRE / V0 | `src/wave_viewer.tcl` at its base-HEAD bytes | **SEL295**, 321, 322, 324, 326, 328, 331, 332 | ✔ |
| SB1 | arm 1 (unknown token) writes a sentence | **296, 297**, 317, 318 | ✔ |
| SB2 | arm 2's sentence text changed | **298, 299** | ✔ |
| SB3 | the `file isfile` guard removed | **300, 301, 302** | ✔ |
| SB4 | arm 4 (refused `switch_ctx`) writes a sentence — 0515's own fix | **303, 304**, 317, 318 | ✔ |
| SB5 | arm 5's sentence text changed | **305, 306, 307, 308** | ✔ |
| SB6 | arm 5 clears the registry (the F7-forbidden shape) | **309**, 305, 307 | ✔ |
| SB7 | success returns `{}` instead of 1 | **310, 311, 313, 314, 315, 316, 319**, 321, 324, 326 | ✔ |
| SB8 | the door pushes a constant to the MRU | **312**, 310, 311, 313, 315 | ✔ |
| SB9 | `xschem raw clear` before the door (L8) | 305, 307, 309, 315, 316, 326 | ✔ |
| SB10 | `token` dropped from the opts dict | **322**, 328, 331 | ✔ |
| SB11 / F4a | `rawbar_sync` dropped from the success tail | **330**, 334, 335, 336 | ✔ |
| SB12 / F4b | `capture_live_view_state` deleted / moved after the door | **329**, 334, 335 | ✔ |
| SB13 | `host none` dropped — R501a reversed | **331**, 305-308, 310, 311, 313, 315, 317, 318 | ✔ |
| SB14 | `switch_ctx` replaced by the `enter_ctx` borrow idiom | **332** | ✔ |
| SB15 *(test-side)* | `am_run PRE` dispatches to the POST body | 320, 322, 323, 325, 327 | ✔ |
| SB16 *(test-side)* | one shim restore line dropped | **333** | ✔ |
| T4 *(test-side)* | the frozen PRE body normalises its path | **320** alone | ✔ |
| T1 / F3c *(test-side)* | the frozen PRE body's `raw read` → `raw select` | **323, 325, 337**, 295, 313, 334 | ✔ |
| T2 *(test-side)* | the frozen PRE body's `browser_refresh` hoisted | **327** alone | ✔ |
| F3a / V17 | `results.tcl`: `_engine_spelling` bypassed | **321**, 336, + item 4's 239/240/241/270/289 | ✔ |
| F3d / V16 | `results.tcl`: the door's verb `raw select` → `raw read` | **324, 326**, + item 4's 224/225/240/241/249/250/254/289 | ✔ |
| F1a | tail hands `rawbar_sync`/`log_action` `[dict get $res path]` | **336** — and SEL330 stays green, which was the hole | ✔ |
| F2a | `if {$how eq {read}} { wviewer::regenerate … }` | **334** alone | ✔ |
| F2b | `wviewer::regenerate $token` deleted | **335**, 328, 334 | ✔ |
| F3f | **both** tilde expanders removed (`file normalize` **and** the door's verb) | **338** + 15 | ✔ |
| B1/B2/B3/B4/B6/B8 | the two moved calls re-inserted into `rawbar_load`; the MRU push and the refresh hoisted above the door's bail-out; the `1` dropped from `browser_refresh`; `host none` dropped; `results::select` renamed | **BR06 legs 1+2, BR07 legs 1+2, the new anti-vacuity leg** — and B3 also reds **BR43-BR46/BR52**, the *behavioural* legs in a live viewer window | ✔ |

**Four checks were caught weak BY SABOTAGE and strengthened, not hidden.** SEL309 ran on an empty registry, where "a refusal leaves the previous result standing" is true of nothing (SB6 stayed green) — both refusal legs now preload a result. SEL331's positive term grepped `host none` and was satisfied by the **comment three lines above the call** (SB13 stayed green) — it now greps the list construction. SEL330's invariant was asserted only where the typed and engine spellings are byte-identical (F1a stayed green) — SEL336 re-asserts it on `$tmp/amsub/../an.raw`, the one fixture where they provably differ, with a third term asserting they DO differ. And nothing pinned `regenerate` on the already-loaded `how switch` path (F2a survived 1008 checks in four suites) — SEL334/335 now compare the viewer tail `{capture regenerate rawbar_sync log_action}` PRE vs POST as an ordered subsequence, on both success legs.

> ⚠ **SEL338 is belt-and-braces, and that is this item's own correction to a reviewer's recipe.** A reviewer proposed killing `_engine_spelling`'s `file normalize` as SEL338's sabotage. **Measured: it does not red it** — nor does swapping the door's verb — because the tilde is expanded **twice, independently**, in Tcl (`results.tcl:475-486`) and in C (`save.c:2408-2416`, added by item 3's fixer round). Only `F3f`, removing both, reds it. A later item that takes one expander out must not read a green SEL338 as permission; that is said in R501c divergence 5.

## 5. What was NOT verified

- **Raised but not confirmed: none.** All seven confirmed review findings (four distinct defects — the tilde divergence raised twice, the `recent_files` damage three times) were reproduced before being fixed, and the reviewers' "raised but not confirmed" list was empty.
- **Reviewer not-proven, carried forward.** *(a)* No lens ran `full_audit.sh` — three lenses shared one tree and a ~40 min run would not be attributable; the audit in §3 is the closer's own, taken on the final tree. *(b)* R501b's ruling was not independently re-derived: a lens confirmed no `enter_ctx`/`leave_ctx` exists and the return set is `{0,1}`, but had no reproducer turning arm 4's silence into a wrong ANSWER. *(c)* **`xschem raw select`'s R301a sibling re-stamp** — it re-stamps `schname`/`level` on other slots naming the same file, which the old append-read never did — is a registry mutation **nothing measures**, because `raw->schname` has no Tcl accessor (issue 0514). One lens built a probe for it and got byte-identical PRE/POST tuples; not proven either way, not filed. *(d)* R501c divergence 3 was measured with `switch_ctx` shimmed; `update_op()` (`save.c:3339`) reads `xctx->raw` and sets a GLOBAL Tcl array, so it should fire identically in production, but was not driven in a live window — and a lens records the opposite reading ("the viewer must not rewrite the schematic's annotation") as arguable and unaddressed by the ruling. *(e)* Whether `~/`-spelled paths actually occur in this user's Location-bar workflow: reachable (`rawbar_commit` passes the combobox text verbatim) but frequency unknown; affects severity, not existence.
- **No live viewer window in group AM.** Every leaf is shimmed (`switch_ctx`, `regenerate`, `browser_refresh`, `rawbar_sync`, `log_action`, `capture_live_view_state`, `browser_status`, `casemode_*`) with the **real** `xschem raw read`/`raw select` underneath: routing proven, painting not. Narrowed by `test_wave_sigbrowser_i1315`'s BR42-BR47/BR50-BR52, which drive `rawbar_load` in a real mapped window against a real sidebar and the real MRU store, were watched running green, and which drive B3 proves are load-bearing.
- **Five of the 44 new checks can only be sabotaged test-side, unavoidably** (SEL320/323/325/327/337 pin how the FROZEN PRE body behaved — the "before" half of a before/after comparison — and SEL333 is a shim-restore hygiene check). Each reds under a drive aimed at its subject; none is a coverage hole, but no edit to shipped product code can move them.
- **SEL337/SEL338 are GUARDED on the scratch tree living under `$HOME`** (`string first $::env(HOME)/ …`). Here the guard is true and both run (340 confirms it); on a tree outside `$HOME` the file would total 338. Creating a fixture under the real `$HOME` to force the case is exactly the damage `CREW_BRIEF.md` §3 exists for. Nothing is printed when the guard is false, so the SKIP-substring trap is not tripped.
- **SEL295 has a red only in the PRE/V0 drive**, not in the matrix — the right shape for an anti-vacuity gate, but a future edit that made the two bodies converge is caught only by re-running that drive. **The T-C tuple excludes the call trace by design** (R501c is the list of why), so any behaviour visible only as which viewer-side calls ran with what arguments is outside T-C's reach; SEL334-336 close the two instances a lens could demonstrate, not the class.
- **The `catch` around `results::select` is unsabotaged** — the door is documented never to throw and no fixture makes it throw; kept as R801 defence, mirroring the `catch` the old read verb had. **`results::persist` still writes nothing** (item 6); its call is pinned by item 4's SEL269-272, not re-pinned here. **Not driven:** multi-tab, an installed-tree run, a leak trace (`-d 3 -l log`), a `:0` run.
- **Eyeball: none owed, nothing added to `owed.sh`.** The payload is a Tcl re-expression, an rc, a registry/MRU delta and five measured divergences — all confirmable headlessly, and the behavioural half additionally confirmed in a live window by a suite this item does not own. The one ordering that moved is inside a single gesture with no `update` between the calls, so no intermediate state is ever painted. **`~/.xschem/raw_history` is still the empty list item 4 left behind** (`34ff432f…` throughout, untouched here); it has no `.bak` and is unrecoverable — item 4's damage, recorded in `LEDGER.md`, nothing here can restore it.
