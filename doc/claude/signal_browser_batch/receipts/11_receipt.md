# Item 11 — hierarchy sync: browser → schematic ("Descend to here") — receipt

**Verdict: `[x]` — DONE** (driver note (a): NOT a pixel item; the tests genuinely
judge it). Implemented in Tcl only — no C, settled decision 8 honoured.
Four sabotages injected, each fired **exactly** its predicted targets, each
reverted, clean re-run green.

**Commit: `b81ee0c91ad7460c77b6c832ac13063ee78ab82f`** (`b81ee0c9`) — ONE commit,
**NOT pushed**, subject `feat(wviewer): Descend to here, browser->schematic` on
`fluid-editing`. Staged as an explicit file list; no `git add -A`. (The
implementer's own draft of this receipt declined to quote the sha, because
writing it in requires an amend that changes it; the **ledger stage** resolves it
after the fact and quotes it here — §12/§13/§14 below were likewise appended
post-commit and are therefore not inside `b81ee0c9` itself.)

**Files touched — 12, from `git show --stat b81ee0c9` re-run by the verifier, no
scope leak and NO `.c` file (settled decision 8 honoured):**
`src/wave_viewer.tcl` (+465/-19), `tests/headless/test_wave_sigbrowser.tcl`
(+622), `tests/headless/test_wave_grid.tcl` (6 lines, the two GH0 literals),
`tests/headless/fixtures/wvhier/{wvhier_top.sch, wvhier_mid.sch, wvhier_mid.sym,
wvhier_leaf.sch, wvhier_leaf.sym}` (5 new), `doc/waveform_viewer_guide.html`
(+18), `doc/claude/specs/waveform_viewer.md` (+85),
`doc/claude/issues/0212-descend-to-here-cannot-address-a-vector-instance-slice.md`
(new, +80), and this receipt. 1638 insertions, 19 deletions.

**Non-baseline fails: NONE** — §11 for the implementer's audit, §13.4 for the
verifier's independent one and the ruling-22 A/B that cleared
`test_readonly_action_dispatch`.

**FAILED-item triage: not applicable.** The verdict is DONE; there is nothing a
human must look at first to diagnose a failure. What is *owed* instead is one
narrowed claim (§13.2) and one flaky-list entry for the driver (§13.4).

Test file: `tests/headless/test_wave_sigbrowser.tcl` (appended, decision 9;
prefix **BH**). Checks: **X arm 397** (was 323 after item 10, **+74**);
**`--nogui` arm 185** (was 134, **+51**). 73 of the X-arm additions are `BH`;
the extra one is a new third leg on the inherited `BT09` (§8).

---

## 1. THE FOUR EXACT ANCHORS — every one re-verified from source

| PLAN citation | verified |
|---|---|
| `xschem descend -inst <name>` at `src/scheduler.c:2811` | **EXACT.** `if(argc > 2 && !strcmp(argv[2], "-inst")) {`, branch head 2805, doc comment 2795-2804. `get_instance` → `unselect_all(1)` → `select_element` → `descend_schematic(0,0,0,set_title)`; `TCL_ERROR "…instance not found"` on a miss. |
| `xschem get sim_sch_path` at `src/scheduler.c:4567` | **EXACT.** `else if(!strcmp(argv[2], "sim_sch_path"))`; body `path = sch_path[currsch]+1` then skip `sch_waves_loaded()` dots. |
| `xschem change_sch_path n` at `src/scheduler.c:2341` | **EXACT.** Unused by item 11 (vectors deferred, §7). |
| `xschem get sch_inst_number` (no line cited) | `src/scheduler.c:4544`, exists, documents its own off-by-one. Unused. |
| `xschem go_back` (no line cited) | `src/scheduler.c:5279`; core `go_back(int what)` `src/actions.c:3806`. Returns **void**; a Cancel at the save prompt returns WITHOUT ascending. |
| `raise_activate_toplevel` (no line cited) | `src/xschem.tcl:5623`. No-ops entirely without `$has_x` — so every raise/focus assertion is X-arm only. |
| `ase::ui::design_window` | `src/ase_window.tcl:3323` (PLAN said 3324 — drift of 1). `raise_design_editor` :3289, `raise_window_entry` :3308. Read-only use; `ase_window.tcl` NOT modified. |
| item 10's reserved slot | `src/wave_viewer.tcl:6357` at the time of the scout's read; confirmed present, last entry, index 7, disabled, empty `-command`. |

Line drift found: `design_window` 3324→3323, `raise_window_entry` 3306→3308,
`raise_design_editor` 3294→3289. Nothing else moved.

---

## 2. SETTLED DECISION 10, MEASURED — the table nobody had produced

`tests/headless/fixtures/wvhier`, `currsch` 2, `sch_path` fixed at `.X1.X2.`:

| `raw_level` | `sim_sch_path` |
|---|---|
| 0 | `X1.X2.` |
| 1 | `X2.` |
| 2 | `` (empty) |

Decision 10 is **TRUE**: `sim_sch_path` is measured from the level where the raw
was loaded, i.e. the same origin the raw's signal names use.

⚠ **AND THE COROLLARY THAT BREAKS THE PLAN'S SABOTAGE (b):** with **no raw
loaded**, `sch_waves_loaded()` is −1, the C skip loop never runs, and
`sim_sch_path` is `sch_path` minus its leading dot **byte for byte**. Measured.
So swapping the getter is invisible in the ordinary case.

---

## 3. FIVE PLAN DEFECTS, all found by measurement

1. **The trailing dot / the empty root.** `sim_sch_path` returns `x1.x2.`, `x1.`
   and `` — the PLAN's algorithm compares those straight against a dotted
   browser path that has neither. `wviewer::hier_split` normalises (BH01).
2. **Case-insensitive retry is necessary but NOT SUFFICIENT.** With exact-first +
   `-nocase` retry only, a lowercase target `x1.x2` legitimately lands on the
   schematic's `x1.X2`, and a byte-exact final verify then rejects its own
   correct result and rolls back. Reproduced verbatim:
   `CASE hgo x1.x2 -> {err {verify failed} {}}`. The final verify must be
   `string equal -nocase` (`hier_same`, BH04/BH26). **This is the defect
   sabotage (d) re-injects — it is not hypothetical.**
3. **`descend -inst` refuses WITHOUT throwing.** Measured: returns the string
   `1` on success, the string **`0`** for a non-subcircuit (`V9`) or a raised
   semaphore, and throws only for "instance not found". Driver note (d)'s exact
   shape — `catch` alone sees success. Confirmed in the test itself (BH25 leg 2
   calls the raw verb and asserts the literal `0`).
4. **PLAN sabotage (b) as written fires NOTHING** (see §2). REPAIRED — §6.
5. **PLAN's BH23 "rollback from depth 1" would have been VACUOUS.** `X1` →
   `X1.nosuch` shares a 1-segment prefix, so the plan is a single descend that
   never happens: "sim_sch_path unmoved" is true whether the rollback exists or
   not. Measured — the first cut of BH23 **passed with the rollback deleted**.
   Rewritten as `X1.X2` → `x1.nosuch`: no byte-exact prefix, so the walk ascends
   twice, descends into `x1`, and only then fails — three steps to undo.

---

## 4. WHAT SHIPPED

| proc | role |
|---|---|
| `hier_split {p}` | THE trailing-dot normaliser. PURE. |
| `hier_common {a b}` | BYTE-exact common prefix — what makes "an exact hit always wins" survive a design carrying both `x1` and `X1`. PURE. |
| `hier_plan {cur target}` | `{<ascends> <segments>}`. PURE. |
| `hier_same {a b}` | THE final verify, `-nocase`. PURE. |
| `hier_now {}` | THE ONLY pivot read. `sim_sch_path`, never `sch_path`. Never throws. |
| `hier_resolve {seg}` | schematic spelling of a segment; EXACT wins, `-nocase` fallback; `VECTOR` sentinel for a bracketed segment. |
| `hier_walk {target {rollback 1}}` | **THE ITEM.** `{ok <path>}` / `{ok already <path>}` / `{err <reason> <path>}`. Never throws. |
| `hier_origin_ok {token}` | the origin guard: refuse, never guess. |
| `browser_target_path {token ids}` | ids → one agreed path, or `err`. |
| `browser_descend_to {token ids}` | THE COMMAND. 1/0, never throws. |
| `browser_descend_here {token}` | the key/menubar target: the tree's selection. |
| `browser_descend_at {W}` | bindtag shim, canvas **or** tree `%W`. |

Every rung asserts on **the world**: the context switch by re-reading
`current_win_path`, the hierarchy move by re-reading `sim_sch_path`. Driver
note (d)'s trap (a swallowed throw inside `catch` looking like success) cannot
survive that, and BH25 proves the specific verb that exhibits it.

---

## 5. THE THREE KEY PATHS, VERBATIM (the written collision check)

Key chosen: **`<Key-E>`** (Shift-e, keysym 69). Bare `e` (Delete Empty Strips)
and `Ctrl-E` (Delete All Markers) are already taken in this window; `E` matches
the schematic's own hierarchy-descend family.

* **p1 — `key_filter`/`graphkeys` → the C dispatcher.** 69 is NOT in
  `graphkeys {97 98 100 115 109 116 65 66 77}` (`wave_viewer.tcl:320`), so
  `key_filter` forwards nothing. `src/keybindings.csv` has **no row for 69** —
  re-verified; the shifted rows it does carry are 65, 66, 72, 75, 76, 79, 80,
  84, 85, 90. `callback.c case 'E'` (`:6185`) fires only under `EQUAL_MODMASK`
  with Alt; bare Shift-E has no arm.
* **p2 — an rc `bind .drw` cloned by `clone_canvas_bindings`.**
  `grep -rn "Key-E>" src/*.tcl src/*.c src/cadence_style_rc` returns **exactly
  one** hit, `src/cadence_style_rc:364`, and it is **commented out**
  (`# bind .drw <Control-Shift-Key-E>`). Nothing to clone; and `strip_bindings`
  sweeps every non-keepseq widget-level sequence off a viewer canvas anyway.
* **p3 — the `break`.** Both bodies end in `break`.

**TWO binds, and the second is REQUIRED, not stylistic.** The treeview's
bindtags are `{<tv> Treeview <top> all}` — the canvas is NOT among them
(re-asserted by BH42), so a `WaveViewer`-tag-only key would never fire where the
user actually is (they have just clicked a row). `browser_build` therefore
carries `bind $f.tvf.tv <Key-E>` as well, and both routes resolve the same
target through `browser_descend_at`. **Both routes are proven with REAL keys on
the REAL viewer** — BH43 (canvas) and BH44 (tree), each asserting that
`sim_sch_path` actually moved, with a negative control (`<Key-D>`, unbound,
reads zero on the same recorder) and BH45 proving `E` typed into the search
Entry does NOT fire it while the Entry's own text proves the key was delivered.

**Collateral, done in the same commit:** `doc/waveform_viewer_guide.html` §9.1
gains a `data-seq="Key-E" data-menu="Descend to here" data-accel="E"` row, and
`tests/headless/test_wave_grid.tcl` GH0's two literals go 15→16 and 10→11.

---

## 6. SABOTAGES — 4, all fired EXACTLY, all reverted

A pristine post-implementation copy was kept in the scratchpad **before the
first injection** and every injection was diffed against it; `cp` from that copy
was the revert (a `git checkout --` would have discarded the whole uncommitted
item). All four predicted targets live in the `--nogui` arm, so the whole
sabotage round ran without the GUI gate.

| # | injection | predicted | **observed** |
|---|---|---|---|
| (a) | delete `if {$rollback} { hier_walk [join $start .] 0 }` | the rollback checks, nothing else | `--nogui`: **BH23 ×2, BH24, BH28 (deep-vector leg) — 4**. X arm: **those 4 + BH51 — 5**, all of them rollback checks and nothing else |
| (b) | `hier_now` reads `string range [xschem get sch_path] 1 end` | BH06 (source) + the raw_level arm | **BH06, BH30 leg 2, BH31 — 3 fails; every no-raw leg stayed GREEN, which is the whole point** |
| (c) | delete the `-nocase` scan line from `hier_resolve` | BH26 only | **BH26 only** (`err {no instance 'x2'}`) |
| (d) | `hier_same` → `eq` instead of `string equal -nocase` | BH04 + BH26 | **BH04 leg 1, BH26 — 2 fails**; BH26's message is literally `verify failed at x1.X2`, the prototype defect |

### 6.1 SUBSTITUTION, declared per ruling 23 — the PLAN's sabotage (b)

As the PLAN wrote it ("use `sch_path` instead of `sim_sch_path`") it fires
**nothing**: with no raw loaded the two getters are byte-identical (§2). It was
given teeth by the BH29-BH31 arm (`xschem raw new` + `xschem set raw_level 1`),
and BH31 is the behavioural discriminator: under the SIM origin `X2` is a no-op
(`{ok already X2}`); under `sch_path` it reads `{X1 X2}`, ascends twice, fails to
find an `X2` at the top and rolls back.

### 6.2 ADDED, sabotage (d)

Not in the PLAN. It is the defect the scout's first prototype actually shipped,
and the one a plausible implementation gets wrong.

### 6.2b BH51 HAD TO BE STRENGTHENED, and the sabotage is what found it

The first cut of BH51 (the rollback through the REAL menu entry) targeted
`x1.nosuch` while sitting at `x1` — a shared 1-segment prefix, so the plan was a
single descend that never happens and **the check stayed GREEN under sabotage
(a)** (measured, X arm). Retargeted at `X1.nosuch` from `x1`: empty byte-exact
prefix, so the walk really ascends out of `x1` and descends into `X1` before
failing. It now fails under (a) with the rest. Same defect as §3.5, found the
same way — by running the sabotage rather than by reasoning about the check.

### 6.3 What the PLAN predicted that turned out NOT to hold

PLAN sabotage (a) predicted **BH25** among its casualties. It is not: `V9` is
refused on the FIRST descend from the root, so nothing has moved and there is
nothing to roll back. BH25's teeth are the **non-throwing refusal**, not the
rollback. Said rather than quietly renamed.

---

## 7. DECLARED LIMITS

* **VECTOR INSTANCES — `[D]`, deferred, issue 0212 filed.** A bracketed segment
  is REFUSED and names the issue (BH28). Measured reason: `descend_schematic`
  writes the EXPANDED slice `x1[3]` into `sch_path` (via `find_nth`,
  `src/actions.c`), while `get_instance` (`src/scheduler.c`) only matches the
  unexpanded `x1[3:0]` — so the path the browser holds cannot be fed back to the
  name-addressed verb. The `change_sch_path` route is written up in the issue.
* **A case-MISMATCHED already-at-target RE-WALKS** rather than no-opping. It
  lands correctly and reports the schematic's spelling; only a byte-exact match
  takes the untouched no-op path (BH22 pins the no-op; BH26 pins the re-walk).
* **A multi-row target with DISAGREEING paths is DISABLED, not first-wins**
  (ruling 17). BH05 pins the refusal, BH41 pins the grey entry with no
  `-command`, BH40/BH41 pin the live one.
* **The origin guard REFUSES rather than guesses** — but `sod_base_level`
  answers 0 when the session's design is not in the window's stack **at all**
  (its own documented rule), so the guard passes there too. Pre-existing hole in
  `ase_window.tcl`; **asserted as a limit** (BH32's last leg) rather than closed,
  because item 11 does not restructure that file.
* **A sync CLEARS THE SELECTION at every level it traverses**, because both
  `descend -inst` and `go_back` call `unselect_all(1)` in C. The already-there
  path does not (BH22 asserts `selected_set` unchanged).
* **All-digit path segments.** `get_instance` treats an all-digit argument as an
  INDEX. `hier_resolve` sidesteps it by scanning by index and never doing a
  by-name lookup; the case is unreachable from the browser anyway (SPICE
  instance names cannot be all digits). Noted in 0212 so nobody rediscovers it.

## 8. WHAT ITEM 11 CONSUMED, and the two inherited checks it had to rewrite

* **item 10's reserved RMB slot.** `browser_menu_build`'s single reserved line
  became a two-armed `if`/`else`; menu construction is otherwise untouched,
  which is what the reservation bought. ⚠ Its stated rationale ("so item 11 need
  not risk the 0178 swallow") was already void — item 10 measured that swallow
  inapplicable to a `ttk::treeview`. The reservation was still useful; the
  reasoning is not repeated.
* **BM02** (source) and **BM25** (widget) pinned the reservation item 11
  consumes, so both had to be rewritten — the shape that hides regressions. Both
  replacements pin **BOTH** states: live-with-command when the rows agree on one
  path, still-disabled-with-no-command when they do not (BM02 rewritten in
  place; BM25's widget half is now BH40/BH41).
* **BT09** asserted item 9's "no bump needed" claim against test_wave_grid's
  15/10 literals. Item 11 DOES bump them, so BT09's second leg now reads 16/11
  and a NEW third leg pins that the one addition is item 11's `<Key-E>` /
  `Descend to here` and nothing else — so the bumped literals cannot be quietly
  satisfied by some third key appearing. Item 9's own leg is untouched.
* **item 9's D6 is NOT violated, and it is stated rather than assumed.** The raw
  lives in the VIEWER context (every `raw read` site is in `wave_viewer.tcl`), so
  descending the DESIGN window touches neither `xctx->raw` of the viewer nor
  `browsersigs`. BH52 asserts the row snapshot is byte-identical across a
  successful sync.

## 9. THE FIXTURE, and why it is shaped as it is

`tests/headless/fixtures/wvhier/` (5 files, `ase_hier`-shaped):
`wvhier_top.sch` holds **`X1` AND `x1`**, both instances of mid — this is what
gives exact-first TEETH — plus the non-subcircuit `V9`; `wvhier_mid.sch` holds
`X2`; `wvhier_leaf.sch` is a leaf. Loaded via the measured
`set XSCHEM_LIBRARY_PATH "$fixdir:…"` idiom (test_ase_hier_pick_0161's,
unqualified per the auto-memory rule).

**The positive control comes first** (driver note (c)): BH20 proves the same
fixture in the same process DOES move before any of BH23/BH24/BH28 claim
"unmoved". Without it those checks would be vacuous — and §3.5 shows exactly how
one of them started out that way.

## 10. GROUPS AND ARMS

| block | arm | what |
|---|---|---|
| BH01-BH09 | both | the pure planners, `browser_target_path`, and 4 source guards |
| BH20-BH32 | **both** | the walk on the real fixture — ⚠ a **DECLARED DEVIATION** from the file header's "20-39 = throwaway toplevel". Item 11's subject is the xschem hierarchy walk, which needs no Tk; gating it on X would have made the rollback X-only for no reason. Recorded in the file header too. |
| BH40-BH42 | X | the menu entry's two states on a throwaway toplevel, plus the structural reason the item binds the key TWICE |
| BH43-BH45, BH50-BH54 | X | END TO END on a REAL viewer + a real ASE session on the fixture + a real design window: the real menu entry invoked, REAL `<Key-E>` on the canvas AND on the tree with a negative control, and the DESIGN window's own `sim_sch_path` read back every time |

### 10.1 Two measured test-harness facts, recorded so nobody re-derives them

* **Real keys do not work on a throwaway toplevel.** It is not the WM's active
  window, so `focus -displayof` never names its widgets and `send_key` correctly
  reports `delivery ... never confirmed (WSLg focus stall)`. Item 10's Button-3
  legs work there because pointer events need no focus; keys do. That is why
  BH43-BH45 live on the real viewer — which is also where the user is.
* **A successful sync steals the focus from the viewer**, because the item
  raises and activates the DESIGN window (that is the feature). Between key legs
  the viewer must be re-raised first (`bh_focus_viewer`) or the next `send_key`
  self-skips. Observed as a real self-skip before the helper was added.

---

## 11. THE AUDIT

`tests/headless/full_audit.sh`, one full sweep:
**269 pass / 15 fail / 0 crash / 0 timeout / 0 skip (total 284).**

* **`X connection to :0 broken`: ZERO occurrences.** Checked BEFORE interpreting
  anything, per the standing rule. The run is a measurement.
* **NON-BASELINE FAILS: NONE.** Sets compared, not counts. The 15 are a strict
  subset of the 16 HARD baseline names; the one that did not fail is
  `test_fluid_editing`, which the baseline explicitly records as "sometimes
  PASSES".
* **The four action-log names item 11 could plausibly have moved were each
  re-run in isolation and fail on EXACTLY the check the PLAN's Baseline block
  records** — not merely "they were already on the list":

  | name | recorded anchor | observed |
  |---|---|---|
  | `test_select_at` | 5: "action log open", SA5, SA6b, SA7b, SA8b | identical, all 5 |
  | `test_phase3_mints` | 2: `key g logs 'xschem snap half'` + `key G logs 'xschem snap double'` | identical, both |
  | `test_selflog_output` | 6: Shift-F / Alt-F / Shift-R / Alt-R / Shift-V / Alt-V | identical, all 6 |
  | `test_ciw` | "no result/error text in file" | identical (the count flap the baseline documents) |
  | `test_ase_log_seam_0207` | 16 of 26, first PS0 "action log open" | failed in the audit; **PASSED** on an isolated `--logdir` re-run — its own documented environment dependence |

  ⚠ `test_phase3_mints` and `test_ciw` must be re-run **in `--logdir` mode** to
  reproduce their recorded anchors; without it they fail a different, larger set
  purely because the log file is absent. Recorded so the next reader does not
  mistake that for a regression.
* **The two FLAKY names flagged RELEVANT to this item** (`test_descend_readonly`,
  `test_verb_noun_descend_0200`) both **PASSED** — they exercise the same
  `descend_schematic`/`go_back` core item 11 drives. No A/B (ruling 22) was
  needed, because nothing moved.
* Item 11 adds **no new C emission and no new action-log line**. The declared
  residual risk stands and is stated rather than hidden: a ROLLBACK drives real
  `go_back`/`descend` verbs, both of which self-log in C, so a failed sync leaves
  a plausible-but-unrequested `descend`/`go_back` pair in a user's action log.

---

## 12. SABOTAGE TABLE — ledger form (`failedExactly` / `reverted` per row)

Five injections in total: the implementer's four (§6), plus the verifier's own
unnamed one (§13.2). Every one was reverted and followed by a clean green re-run.
Revert method for (a)-(d) was `cp` from a pristine post-implementation scratchpad
copy taken **before the first injection**, then `diff` to zero — a
`git checkout --` would have discarded the whole then-uncommitted item. The
verifier, working against the committed tree, used the same pristine-copy
discipline for his probes and confirmed `git diff --name-only -- src/ tests/`
empty afterwards.

| # | origin | injection | predicted targets | observed | `failedExactly` | `reverted` |
|---|---|---|---|---|---|---|
| (a) | PLAN | delete `if {$rollback} { hier_walk [join $start .] 0 }` from `hier_walk`'s failure exit | the rollback checks and nothing else | `--nogui` **4**: BH23 ×2, BH24, BH28 deep-vector leg. X arm **5**: those + BH51 (the rollback through the REAL menu entry). Nothing else moved. ⚠ the PLAN also predicted **BH25** — it is NOT a casualty (§6.3) | **yes** | **yes** |
| (b) | PLAN, **REPAIRED** (§6.1, ruling 23) | `hier_now` reads `string range [xschem get sch_path] 1 end` | BH06 (source guard) + the raw-level arm | **3**: BH06, BH30 leg 2, BH31. Every no-raw leg stayed GREEN — the point of the repair | **yes** | **yes** |
| (c) | PLAN | delete the case-insensitive scan line from `hier_resolve` (exact only) | BH26 | **1**: BH26, message `err {no instance 'x2'}`. BH27 (exact-first) stayed green | **yes** | **yes** |
| (d) | **ADDED** by the implementer (§6.2) | `hier_same` `string equal -nocase` → `eq` | BH04 leg 1 (pure), BH26 (behavioural) | **2**: exactly those. BH26's message is literally `verify failed at x1.X2` — a correct walk rejected by its own byte-exact verify | **yes** | **yes** |
| (v) | **VERIFIER, UNNAMED** (§13.2) | in `hier_walk`'s descend loop replace `if {$r ne {1} \|\| [llength [wviewer::hier_now]] <= $before}` with `if {0}` — i.e. trust `catch` alone, delete the world-readback | (undeclared to the implementer; aimed at driver note (d)) | **1**: EXACTLY BH25 — `err {verify failed at } {}` vs expected `err {descend refused at 'V9'} {}`. 184 passed | **yes** | **yes** |

**Sabotage (a) additionally swept under X** to record its superset rather than
assume the `--nogui` set was complete — which is how BH51's vacuity was found
(§6.2b).

---

## 13. VERIFIER STAGE — `ok: true`, `scopeClean: true`

Everything in this section was **re-run by the verifier**, not read off §1-§11.

### 13.1 Re-runs that reproduced the claims

| what | result |
|---|---|
| `git show --stat b81ee0c9` | EXACTLY the 12 claimed files; no `.c`; no scope leak |
| all four `scheduler.c` anchors re-verified from source | `descend -inst` block at `:2805ff` (PLAN's `:2811` is inside it); `get sim_sch_path` `:4567` EXACT; `get_instance` `:86` confirms plain `strcmp` **and** the `isonlydigit()`-as-index branch; `xschem windows` `:12833` confirms field 0=win_path, 4=current_name, 6=hier stack — which is what `browser_descend_to` indexes |
| **decision 10 proved from the C, not only measured** | the `sim_sch_path` body is `start_level = sch_waves_loaded()` then a skip loop over `sch_path`'s dots — so with no raw loaded (`-1`) it degrades to `sch_path` minus the leading dot byte for byte, exactly as §2 claims |
| `grep` for `sch_path` in the committed diff's **code** (not comments) | **zero hits** — `hier_now` reads only `sim_sch_path` |
| `--nogui` arm | **185 passed / 0 failed** — matches exactly |
| X arm (`gated_xschem.sh`) | **397 passed / 0 failed** — matches exactly. Prefixes counted independently: 73 `BH` + 1 new `BT09` leg = **74 added**; item 10's 323/134 corroborated from its own receipt, so 323+74=397 and 134+51=185 both reconcile |
| the whole BH01-BH54 block read line by line, hunting tautologies | every behavioural leg asserts on `xschem get sim_sch_path` / `currsch` / `schname`, on menu `entrycget`, or on the status label read back — **none** asserts merely "the proc did not throw". BH20's POSITIVE CONTROL precedes the four rollback checks, so they are not vacuous; BH43's recorder has a paired NEGATIVE control (`<Key-D>` must read ZERO); BH45 proves the key was delivered while NOT firing |
| the three rewritten inherited checks read against the pre-item-11 file | BT09 2→3 legs (item 9's zero-contribution leg untouched); BM02 still 3 legs but now pins both arms plus "still LAST"; BM25's lost disabled-state coverage genuinely re-pinned by BH41. **No coverage dropped** |
| the fixtures read directly | `wvhier_top.sch` really carries BOTH `X1` and `x1` plus the non-subcircuit `V9`; `wvhier_mid` carries `X2` — exact-first, the case retry and the non-throwing refusal all have REAL teeth, not staged ones |
| issue 0212 + the doc bumps | 0212 exists and really is the next free number (`doc/claude/issues/` ends 0211); the guide row carries `data-seq="Key-E"`; `test_wave_grid` reads 16/11 |

### 13.2 The verifier's own UNNAMED sabotage — and its outcome

**Row (v) in §12.** Aimed squarely at the item core *and* at driver note (d):
delete `hier_walk`'s world-readback so the descend loop trusts `catch` alone.
**Outcome: 184 passed / 1 failed, and the one failure was EXACTLY BH25** — the
check whose whole existence is the non-throwing refusal. Reverted from the
pristine copy, diffed to zero, clean re-run green. The coverage is real.

⚠ **A SECOND PROBE (not required) FOUND A COVERAGE HOLE — recorded, and the claim
NARROWED rather than the coverage widened (ruling 17).** Neutering the FINAL
VERIFY — `if {$problem eq {} && ![wviewer::hier_same $now $tgt]}` → `if {0 && …}`
— left the `--nogui` arm **fully green at 185/185**. Sabotage (d) proves the
verify *runs* and that its `-nocase` matters (it fires BH26), but **no check
constructs a walk where every step reports success and the landing is nonetheless
wrong**, so *deleting* the verify is invisible to the suite. The verifier judged
this defensible rather than a FAIL: the verify is belt-and-braces against an
unknown-unknown that the per-step readbacks already catch by construction. **The
narrowed claim: item 11's tests prove the final verify's CASE-INSENSITIVITY, not
its NECESSITY.**

### 13.3 Gating

The GUI gate paused twice during the item and was **waited out** both times.
`GUI_GATE=0` was never set and no gate file was hand-written. All X-arm runs went
through `gated_xschem.sh` / `run_suites.sh`; no bare loop.

### 13.4 The verifier's own full audit, and the two off-list names

`full_audit.sh` run start to finish by the verifier: **264 pass / 18 fail /
0 crash / 0 timeout / 2 skip (284 classified)**, against the implementer's
**269 / 15 / 0 / 0**. `grep 'X connection to :0 broken'` = **0**, checked BEFORE
interpreting anything, in both runs.

⚠ **The totals differ and that is EXPECTED — the baseline says in terms "COMPARE
SETS, NOT COUNTS — THE TOTALS ARE NOT REPRODUCIBLE".** The sets reconcile: the
verifier's 18 = the **16 HARD baseline names** + `test_deselect_mode` +
`test_readonly_action_dispatch`.

* `test_deselect_mode` — on the documented FLAKY list; **3/3 PASS** in isolation
  via `run_suites.sh -n 3`. Cleared.
* ⚠ **`test_readonly_action_dispatch` is on NEITHER the HARD nor the FLAKY list.**
  Cleared per **ruling 22 by A/B, not by re-run count**: 2/3 pass at HEAD, then
  with `src/wave_viewer.tcl` reverted to `809cb979` it **still fails, on the SAME
  two checks** (`control: toggle_ignore mutates writable` and `treatment: zoom_in
  (non-mutating) still works read-only`) at a comparable rate, 1/5. Same shape,
  same rate, item 11 reverted ⇒ **pre-existing ~20-25 % flake, not item 11**.
  Tree restored; `git diff --name-only -- src/` empty.
  **ACTION FOR THE DRIVER: add it to the FLAKY list before item 12.**

`nonBaselineFails` therefore stands **EMPTY** — but honestly qualified: it held on
the implementer's luckier sample. **15-of-16 was one run, not a property.**

⚠ **One unexplained flap, recorded rather than hidden.** One of the verifier's
five X-arm runs of `test_wave_sigbrowser` scored **396 passed / 1 failed**; the
other four scored 397/0 and both `--nogui` runs were clean. The run was piped to
`tail`, so **which check flapped was not captured**, and it did not reproduce in
four subsequent runs. It sits inside the file's own documented WSLg key-delivery
envelope (BH43/BH44/BH45 self-skip on a delivery stall rather than failing), but
it is logged as an un-named ~20 % one-check flap rather than as nothing.

---

## 14. DIVERGENCES FROM THE PLAN — the complete list, each with its reason

| # | divergence | reason |
|---|---|---|
| 1 | **VECTOR INSTANCES verdicted `[D]`** for that sub-case alone; a bracketed segment is REFUSED naming **issue 0212**, which is filed. | The PLAN explicitly authorises `[D]`-for-vectors provided the receipt says which and an issue is opened. Measured reason: `descend_schematic` writes the EXPANDED slice `x1[3]` into `sch_path` via `find_nth`, while `get_instance` only matches the unexpanded `x1[3:0]` — the browser's own path cannot be fed back to the name-addressed verb. The `change_sch_path` route is written up in 0212. |
| 2 | **PLAN DEFECT 1 — the trailing dot.** Added `wviewer::hier_split` as THE normaliser (BH01). | `sim_sch_path` returns `x1.x2.`, `x1.` and `` (empty at the sim root); the PLAN's algorithm compares those straight against a dotted browser path with neither. |
| 3 | **PLAN DEFECT 2 — case-insensitive retry is necessary but NOT SUFFICIENT.** Split into byte-exact `hier_common` (prefix) + `-nocase` `hier_same` (final verify). | Without a `-nocase` FINAL verify, a correct walk of `x1.x2` lands on `x1.X2` and the verify rejects its own correct result and rolls back. Reproduced verbatim in the scout's prototype. |
| 4 | **PLAN DEFECT 3 — every step confirmed by READBACK, never by `catch`.** BH25 asserts the raw verb's literal `0`. | `descend -inst` returns the STRING `0` WITHOUT THROWING for a non-subcircuit (measured on `V9`) or a raised semaphore, and `go_back` returns void and does not ascend on a cancelled save prompt. Driver note (d)'s exact shape. |
| 5 | **PLAN DEFECT 4 — sabotage (b) REPAIRED** with a `xschem raw new` + `set raw_level 1` arm (BH29-BH31); substitution declared per ruling 23. | As written it fires NOTHING: with no raw loaded the two getters are byte-identical (§2, and the verifier confirmed it from the C). |
| 6 | **PLAN DEFECT 5 — BH23 retargeted** from `X1`→`X1.nosuch` to `X1.X2`→`x1.nosuch`; BH51 likewise from `x1`→`x1.nosuch` to `x1`→`X1.nosuch`. | The PLAN's shape is VACUOUS: a shared 1-segment prefix means the plan is a single descend that never happens. MEASURED — the first cut of BH23 **passed with the rollback deleted**, and the same trap in BH51 was caught by running sabotage (a) under X. Found by running the sabotage, not by reasoning about the check. |
| 7 | **ORIGIN GUARD is real work the PLAN under-specified.** `browser_descend_to` re-scans `xschem windows` itself (current_name first, then the 7th field = the whole stack, mirroring `raise_design_editor` / issue 0168) and requires `current_win_path` to equal that entry. | `ase::ui::design_window` returns 1/0 and never says WHICH window, and `raise_window_entry` does a bare `xschem new_schematic switch` with NO verify — so PLAN step 3 ("verify the context followed", landmine 17) had to be implemented here. `ase_window.tcl` was NOT modified; read-only use only. |
| 8 | **DECLARED DEVIATION from the test file header's arm blocking:** BH20-BH39 run in BOTH arms against a REAL loaded fixture, not a throwaway Tk toplevel. | Item 11's subject is the xschem hierarchy walk, which needs no Tk; gating it on X would have made the item's defining behaviour (the rollback) X-only for no reason. Recorded in the test file header as well as here. |
| 9 | **REAL-KEY LEGS MOVED** to the REAL viewer (BH43-BH45), with a `bh_focus_viewer` re-raise between them. | Measured: a throwaway toplevel is not the WM's active window, so `focus -displayof` never names its widgets and `send_key` correctly reports a delivery stall (item 10's Button-3 legs work there only because pointer events need no focus). And a successful sync RAISES the design window, stealing focus from the viewer, so without the re-raise the next `send_key` self-skips — observed. |
| 10 | **THREE INHERITED CHECKS REWRITTEN** (BM02, BM25, BT09), each pinning BOTH states rather than being dropped. | BM02/BM25 pinned item 10's reservation that item 11 CONSUMES; BT09 pinned item 9's "no bump needed" claim against test_wave_grid's 15/10 literals. BT09's new third leg pins that the ONE addition is `<Key-E>`/`Descend to here`, so the bumped literals cannot be satisfied by some third key appearing. Verifier confirmed no coverage was lost. |
| 11 | **MULTI-ROW RULE: the command is enabled only when every picked row yields the SAME path**; a disagreeing set leaves the entry disabled with the reason in the status line. | Chosen against a silent first-wins, ruling 17 — a first-wins would sync somewhere the user did not pick, silently. |
| 12 | **DECLARED LIMIT: a case-MISMATCHED already-at-target RE-WALKS** rather than no-opping. | It lands correctly and reports the schematic's spelling; only a byte-exact match takes the untouched no-op path (BH22 pins the no-op, BH26 the re-walk). |
| 13 | **DECLARED LIMIT, asserted rather than pretended away (BH32's last leg):** `ase::ui::sod_base_level` answers 0 when the session's design is not in the window's stack AT ALL, so the origin guard passes there too. | Its own documented rule; a pre-existing hole in `ase_window.tcl`. Item 11 does not restructure that file (PLAN: read-only use). |
| 14 | **DECLARED LIMIT: `get_instance` treats an all-digit argument as an INDEX**; `hier_resolve` sidesteps it by scanning by index and never doing a by-name lookup. | Unreachable from the browser (SPICE instance names cannot be all digits), so recorded in 0212 rather than guarded. Verifier confirmed the `isonlydigit()` branch from source. |
| 15 | **MEASURED HARNESS FACT carried forward:** `xschem raw new` stamps the raw at the CURRENT hierarchy level, not 0 — BH29 sets `raw_level` explicitly. | An assumed 0 would have made BH29's "the two getters agree" leg pass for the wrong reason. |
| 16 | **PRE-EXISTING CRASH, NOT FIXED and NOT FILED:** `xschem raw read` on an ASCII rawfile whose `Values:` block lacks blank-line point separators SEGFAULTS. | Out of scope — no C per decision 8, and it is a malformed-input robustness bug in `save.c`'s `read_raw_ascii_point` path, unrelated to item 11. Hit while hand-writing a fixture raw; sidestepped with `xschem raw new`/`raw add`, which is also the existing BTV/BMV idiom. |
| 17 | **SCOUT ANCHOR DRIFT corrected, not silently followed:** `ase::ui::design_window` 3324→3323, `raise_window_entry` 3306→3308, `raise_design_editor` 3294→3289. | Three `ase_window.tcl` line numbers in the PLAN had drifted. The four `scheduler.c` citations were EXACT, re-verified by both implementer and verifier. |
| 18 | **RECEIPT FILENAME:** the PLAN's per-item Receipt line for item 11 says `receipts/11_receipt.md` and the file IS that — noted only because items 7-10 carried wrong Receipt lines (D10). | No divergence here; recorded so the driver's pending "fix items 10-16 in one pass" does not touch this one needlessly. |
