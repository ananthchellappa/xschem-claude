# Item 11 — hierarchy sync: browser → schematic ("Descend to here") — receipt

**Verdict: `[x]` — DONE** (driver note (a): NOT a pixel item; the tests genuinely
judge it). Implemented in Tcl only — no C, settled decision 8 honoured.
Four sabotages injected, each fired **exactly** its predicted targets, each
reverted, clean re-run green.

**One commit, NOT pushed** — subject `feat(wviewer): Descend to here,
browser->schematic` on `fluid-editing`, the tip at hand-off. Staged as an
explicit file list; no `git add -A`. (The sha is deliberately not quoted here:
writing it into the receipt requires an amend, which changes it — `git log` is
the authority.)

Files touched: `src/wave_viewer.tcl`, `tests/headless/test_wave_sigbrowser.tcl`,
`tests/headless/test_wave_grid.tcl`, `doc/waveform_viewer_guide.html`,
`doc/claude/specs/waveform_viewer.md`,
`doc/claude/issues/0212-descend-to-here-cannot-address-a-vector-instance-slice.md`,
`tests/headless/fixtures/wvhier/` (5 new files), this receipt.

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
