# Item 15 — persist browser state in snapshot/restore

**Verdict: `[x]` — DONE** (NOT a pixel item — driver note (a); the driver assigned
**no eyeball-queue row**).
Commit: **`3e526f86`** — see §10 for the ledger-stage record (written after the
commit landed, and after the adversarial verifier). Files touched (2, both
tracked, nothing else):

- `src/wave_viewer.tcl`
- `tests/headless/test_wave_sigbrowser_i1315.tcl` (group `BP`, 81 new checks)

`cd src && make` → `Nothing to be done for 'all'` (Tcl-only change; settled
decision 8 honoured, no C touched).

---

## 1. Anchors: CITED vs ACTUAL

Every anchor re-verified from source before it was trusted. The scout's own
re-measure was correct in every case; the PLAN's and the driver's were not.

| cited | actual | ok |
|---|---|---|
| PLAN: `wviewer::snapshot` at `wave_viewer.tcl:2165` | **:2789** (+624) | ✗ |
| PLAN: `restore` at `:2212` | **:2836** pre-commit (+624); **:2840 AFTER `3e526f86`** — the item's own `snapshot` hunk (`@@ -2797,22 +2797,26 @@`, net +4) pushed it down. **ITEM 16 MUST USE :2840** | ✗ |
| driver note (b): snapshot at `:2628` (item 13's re-measure) | **:2789** (+161 more) | ✗ |
| driver note (b): restore at `:2675` | **:2836** (+161) | ✗ |
| PLAN Test: "append to `test_wave_sigbrowser.tcl`" | superseded by ruling 30; correct target `_i1315.tcl` | ✗ |
| driver (c): `_i1315.tcl` reserves `BP` for item 15 | CONFIRMED verbatim, file header lines 17-19 | ✓ |
| driver (f): `searchbar_get {w}` returns the four values as a dict | **:10073**, with item 14's CONDITIONAL 5th key `alldbs`. **There is NO setter** — `searchbar_build/get/fire/error/destroyed/forget` is the whole family | ✓ |
| driver (f)/ruling 24: `plot_dest <token>` | **:3055**, defaults `append` for an unset token | ✓ |
| driver (f): item 8's sidebar mirror | `browser_shown` :7747, `browser_show` :7770, `sync_browser_mirror` :7797, `browser_toggle` :7820 | ✓ |
| driver (f): `browser_leaf_names` | :6114 | ✓ |
| driver (f): `browser_width` computes ONCE at toggle time, one call site | :7718, called only from `browser_show`'s pack branch; no setter, no sash | ✓ |
| driver (f): item 13's 0119 gate | `rawhist_push` :6274 opens with the `::update_recent_files` guard BEFORE the append and the write | ✓ |
| driver (f): item 14's `signal_list_all` / All-DBs box | :1854 / `browser_alldbs` :6565 / `sballdb` :432 | ✓ |
| item 9 D6: the inventory is a snapshot taken when the sidebar is SHOWN | `browser_show` calls `browser_refresh $token 1` on the pack branch | ✓ |
| decision 11: a restored selection must be a legal input to the sync | `browser_descend_here` :7384 does `$tv selection` → `browser_descend_to` → `browser_target_path` | ✓ |
| **UNCITED BLOCKER** found by the scout: `test_wave_modes.tcl:1314` MG9 pins `[dict keys $snap]` | CONFIRMED. **The emission gate is the only thing keeping it green** | ✓ |
| **UNCITED**: `test_wave_hilight.tcl:745` WH9j greps snapshot's body for `wavehl`, wants 0 | CONFIRMED | ✓ |
| **UNCITED**: `test_wave_sigbrowser.tcl:783-795` BT08 greps four literals INSIDE `browser_width` | CONFIRMED, and that file is FROZEN — this forces the `{want {}}` widening and **forbids** factoring the clamp into a helper | ✓ |
| **NEW FINDING** (nothing cited it): `browser_populate` :6684 deletes every row and re-inserts `-open 1`, clearing the selection | CONFIRMED. So the default tree state is ALL-OPEN + EMPTY-SELECTION, which is what makes a collapsed group and a non-empty selection genuinely NON-DEFAULT fixture values (driver note (d)) | ✓ |

---

## 2. What was built

### `src/wave_viewer.tcl`

| proc | line (post-change) | role |
|---|---|---|
| `sb_syntax_label` / `sb_type_label` | ~9890 | PURE inverses of `sb_*_code`, total, defaulting to Shell/All |
| `searchbar_set {w d}` | ~10120 | **THE MISSING TWIN** of `searchbar_get`. Writes through `$w.pat` / `$w.syntax` / `$w.type` and the two checkbutton `-variable`s; honours item 14's conditional `alldbs`; never throws; ends on ONE `searchbar_fire` |
| `browser_width {token {want {}}}` | ~7735 | WIDENED. `{}` = today verbatim; a positive want REPLACES the derived base and takes **the same** cap/floor |
| `rawhist_merge {saved}` | ~6300 | **the second 0119-gated site**; folds oldest-first through item 13's pure `rawhist_add`; index loop (Tcl 8.4), one `rawhist_write` |
| `browser_state_default` | ~7900 | PURE canonical no-op value |
| `browser_state_is_default {d}` | " | PURE gate; **excludes `hist`** (divergence D-A) |
| `browser_tree_nodes` / `browser_tree_state` / `browser_tree_apply` | " | the tree's expanded set + selection |
| `browser_state {token}` | " | THE READER, composed only from owners' accessors |
| `browser_state_apply {token d}` | " | THE WRITER |
| `snapshot` | 2789 | two `dict create` returns folded into one built dict; `browser` appended **only when non-default** |
| `restore` | 2836 | one `browser_state_apply`, LAST, **after** `regenerate` |

**Step order in `browser_state_apply` is forced twice over**: the width goes
after `browser_show` (the pack branch recomputes it) and the tree state goes
after `browser_show` (it repopulates the tree and wipes both fields). Inside
`browser_tree_apply`, **selection first, open-set last** — `$tv see` force-opens
every ancestor, so the reverse order silently re-expands exactly the group the
user collapsed. `browser_reveal` is deliberately NOT reused: it also force-opens
the node it lands on. Sabotage (c) is the proof this is real and not asserted.

### `tests/headless/test_wave_sigbrowser_i1315.tcl` — group `BP`, 81 checks

- `BP01-BP09` SOURCE, both arms — the emission gate, the restore ordering,
  note (f) made assertable, decision 13, the merge's 0119 gate, the LOCAL twin
  of BT08, the widget-write discipline, D-A, and WH9j's rule restated locally.
- `BP10-BP19` PURE, both arms — the default's exact shape and key order, the
  gate's truth table (including "1 when only `hist` differs" = the MG9-stability
  rule), the two label inverses, R4's closed arms re-pinned, and "no window is an
  ANSWER, never a throw".
- `BP40-BP61` REAL viewer + REAL raws.

File totals: **166 checks** (85 item 13 + 81 item 15) in the X arm, **80** in
`--nogui`.

---

## 3. THE ANTI-VACUITY WORK (driver notes (d)/(e), ruling 29)

Both PLAN-named sabotages are negatives and the whole group is round-trip
shaped — the exact BD44/BD45 shape item 14's receipt warns about. Three
structural answers, all measured rather than reasoned:

1. **BP41 is the positive control for the SNAPSHOT side.** A FRESH window's
   `browser_state` is asserted EQUAL to `browser_state_default`. So every value
   set below is a real departure.
2. **BP46 is the positive control for the DESTROY.** close → assert the state is
   gone → re-open → assert **every field is back at DEFAULT** → close. Without
   it, "the field round-tripped" and "the field never changed" are the same
   picture.
3. **Every field is set to a NON-DEFAULT value and PROVEN to have taken (BP43)
   before the destroy.** search `.*`/RegExp/case ON/Voltage/**AllDBs ON**;
   filter `.*`/RegExp/case ON/Voltage; `set_plot_dest newstrip`; sidebar shown;
   `browser_width $tok 260`; `g:x1` collapsed; `s:v(x1.x2.n1)` selected. The
   patterns are `.*` on purpose: non-default, but match-all, so the tree keeps
   the group rows the collapse/selection claims need.

**Missing-key discipline (note (e)):** every read is `pcall`-wrapped and every
snapshot field is read with `[wviewer::dget $d <k> {NO-KEY}]`, so "key absent"
(`NO-KEY`), "key present but empty" (`{}`) and "the widget is gone" (`ERR:…`)
are three different assertable values, never one exception that deletes the
evidence of every later check.

**BP57 (the PLAN's second named assertion) de-vacuumed.** A fresh window is BORN
hidden, so `browser_shown == 0` after a restore is true whether or not the
restore did anything. Two things fix it: BP48 is the proven positive control on
the same code path (a restore really CAN show the sidebar), and BP57's last leg
asserts a **non-default FILTER pattern in a hidden sidebar** — which kills the
one world a bare `shown == 0` cannot distinguish, "the restore did nothing at
all". Sabotage (b) confirms: BP57 red, BP48 green.

---

## 4. SABOTAGE LOG — 2 named + 2 mine, all four RUN, not reasoned about

Reverted from a pristine scratchpad copy, **not** `git checkout --` (the item is
uncommitted; `git checkout --` would discard it — driver's warning).
`diff` against the pristine copy shown before every run.

| # | injection | PREDICTED | ACTUAL | verdict |
|---|---|---|---|---|
| **(a)** PLAN | drop the `dict set d dest [plot_dest $token]` pair from `browser_state` | a SUPERSET, declared up front: **BP04, BP43, BP45, BP51** red; **BP44 GREEN** | **exactly BP04, BP43, BP45, BP51** — `4 FAILED (162 passed)`. BP44 green as predicted (the state is still non-default via other fields) | ✅ exact |
| **(b)** PLAN | `browser_state_apply`: `set shown [dget $d shown 0]` → `set shown 1` | **BP57 alone**; BP48 untouched by design | **exactly BP57** — `1 FAILED (165 passed)` | ✅ exact |
| **(c)** MINE | `browser_tree_apply`: move the open-set application BEFORE the selection | **BP53 + BP54** red, BP52 green | **exactly BP53 + BP54** — `2 FAILED (163 passed)`; BP52 green | ✅ exact |
| **(d)** MINE | `snapshot` emits `browser` UNCONDITIONALLY | **BP02 (gate leg) + BP42** red **AND `test_wave_modes.tcl` MG9 red** | **exactly BP02+BP42** (`2 FAILED (164 passed)`) **AND MG9** (`test_wave_modes: 1 FAILED (484 passed)`) | ✅ exact, cross-file |

Sabotage (a)'s superset was **declared before the run** (ruling 23), not renamed
after it. Sabotage (d) is the evidence that the emission gate is load-bearing
**outside** this file — it is the only thing standing between item 15 and a red
`test_wave_modes.tcl` on every machine.

Clean re-run after the last revert: `RESULT: ALL PASS (166 checks)`,
`git status` showing exactly the two item files modified.

---

## 5. FOOTPRINT — the axis ruling 30 was cut on, MEASURED (driver note (c))

Item 13's claim does not transfer: **destroy/restore CYCLES** are a new axis.
`BP4x` adds **5 destroy/restore cycles**, ONE more three-point ASCII raw
(hierarchical names, so there are group rows to collapse), holds **at most one
viewer alive at a time**, and opens **NO design window at any point**.

**MEASURED, N = 6 consecutive standalone runs through `gated_xschem.sh`:**

```
run 1 rc=0 1.70s  RESULT: ALL PASS (166 checks)  X-broken=0
run 2 rc=0 2.15s  RESULT: ALL PASS (166 checks)  X-broken=0
run 3 rc=0 2.26s  RESULT: ALL PASS (166 checks)  X-broken=0
run 4 rc=0 2.22s  RESULT: ALL PASS (166 checks)  X-broken=0
run 5 rc=0 2.18s  RESULT: ALL PASS (166 checks)  X-broken=0
run 6 rc=0 2.26s  RESULT: ALL PASS (166 checks)  X-broken=0
```

**6/6 completions, zero `X connection to :0 broken`, ~2.2 s each.** Plus 4 more
whole-file runs during the sabotage round and 2 in the verification set — 12
measurable runs, 12 completions. **Verdict: appending to `_i1315.tcl` is
correct; item 15 does NOT need its own file.**

The one place the footprint changed a DESIGN choice is **BP55**: decision 11's
clause ("a restored selection must be a legal input to item 12's sync") is
asserted through `wviewer::browser_target_path` — the exact value
`browser_descend_to` computes from `$tv selection` before it does anything else
— rather than by driving a real `browser_descend_here`. A real descend calls
`ase::ui::design_window`, which OPENS THE DESIGN WINDOW: precisely the "real
viewer AND real design window at once" shape **every** pre-split death landed
in. Declared as a substitution (ruling 23), not renamed. BP55 carries its own
negative control (an empty selection is refused by the same gate), so
`{ok x1.x2}` cannot be what that proc says about everything.

---

## 6. VERIFICATION

**Targeted set** (`run_suites.sh`, one pass):

```
PASS test_wave_sigbrowser        ALL PASS (324)
PASS test_wave_sigbrowser_i11    ALL PASS (74)
PASS test_wave_sigbrowser_i12    ALL PASS (92)
PASS test_wave_sigbrowser_i14    ALL PASS (83)
PASS test_wave_sigbrowser_i1315  ALL PASS (166)   <- mine
FAIL test_wave_modes             1 FAILED (484)   <- MG13, see below
PASS test_ase_persist            ALL PASS (109)   R3/R4
PASS test_wave_hilight           ALL PASS (196)   WH9j
PASS test_wave_sigsearch         ALL PASS (194)   BAR11/BAR29
```

`test_wave_modes` MG13 — *"Ctrl+Shift+4 resolves to the `<Control-Key-dollar>`
form"* — is a **key-binding resolution** check with nothing to do with
snapshot/restore, and it is in the known WSLg key-delivery flake family.
**Re-run 4× through `run_suites.sh -n 4`: 4/4 `ALL PASS (485 checks)`.** MG9 (the
tripwire) was green on every one of the five runs.

**FULL headless suite** (`tests/headless/full_audit.sh`): **288 cases**, `grep -c
'X connection to :0 broken'` = **0**, so the run is a measurement.

15 FAIL names, compared as a SET against the 16 HARD baseline names:

```
test_ase_log_seam_0207  test_ase_window  test_cadence_drag  test_ciw
test_gf180mcud_libmgr   test_ihp_sg13g2_libmgr  test_lib_manager_gui
test_lib_manager_locate test_lib_sweep   test_phase3_mints
test_reopen_readonly    test_rotate_stretch_short_0104
test_select_at          test_selflog_output      test_sky130a_libmgr
```

**A strict SUBSET of the 16.** The 16th, `test_fluid_editing`, PASSED — the
documented exception. Every HARD name failed on **its recorded check**
(`test_ase_window` W7; `test_lib_manager_gui` GUI8+GUI9; `test_lib_manager_locate`
LM-LOC3; `test_lib_sweep` P1/P1b/P2/P3/P4; `test_reopen_readonly` R10;
`test_rotate_stretch_short_0104` "rot180-ip (-30,70)"; the three PDK libmgr tests
on their `library_list` check with the `{SANDBOX TEST …}` extras from the
user-level `library.defs`; the action-log/self-log cluster on its "action log
open" / "logs `<cmd>`" shapes). `test_cadence_drag` is the RE-ANCHORED
exception. **Zero non-baseline fails.**

---

## 7. DECLARED DIVERGENCES (driver note (g))

- **D-A — `hist` is carried and restored but EXCLUDED from the non-default
  emission test.** `rawhist` is a GLOBAL disk-backed store that already outlives
  the session (item 13), and counting it would make the snapshot's key set
  depend on the developer's home directory — i.e. MG9 would go red on any
  machine that had ever opened a raw. Consequence, accepted: an all-default
  browser state records no history, and does not need to (`rawhist_load` reads
  the same store back at startup). Pinned by BP09 + BP12.
- **D-B — the restored width is RE-CLAMPED to the new toplevel** (45% cap / 240
  floor). The dict field round-trips exactly; the pixels do not when the window
  changed size. The load-bearing checks (BP43/BP45) are at the DICT level and
  WM-independent; the pixel apply leg (BP56) is gated on `bs_wait_widths`
  returning `settled` with `topw >= 600` and otherwise prints a visible
  `SKIPPED:` line — never a silent pass, never a flaky fail. This is the one
  inherited flake (BT45, ~1-in-6) genuinely adjacent to this item; it was
  `settled` and the pixel leg ran green in every measured run.
- **D-C — All-DBs IS snapshot state** (note (f) demanded a deliberate answer).
  It is a user-set search SCOPE and arrives free from `searchbar_get`. The
  foreign INVENTORIES are NOT persisted: `browser_reload` re-scans on show, so
  the tree repopulates from whatever DBs are open now. Pinned by BP49/BP50,
  which also re-pin item 14's conditional-key contract locally (the Filter bar
  must carry NO `alldbs` key at all, not `0`).
- **D-D — the open-set and the selection are applied only when the sidebar
  restores SHOWN** (item 9's D6: there is no populated tree while it is hidden).
- **D-E — the readout-bar-vs-sidebar pack order** (assigned to item 15 by item
  8's eyeball row). Cursor state is deliberately NOT persisted (`snapshot`'s own
  D8), so after a restore the order is always sidebar-first / readout-later —
  deterministic. NOT fixed, NOT a pixel change. **Flag for the driver:** if the
  readout bar should always span the full toplevel width, that is a separate
  issue, not item 15's.
- **D-F — a restore emits NO action-log lines.** It writes the `dest` and
  `browser` arrays directly and calls `sync_browser_mirror` + `browser_show`
  rather than `set_plot_dest` / `browser_toggle`, both of which `log_action`.
  This is `restore`'s own precedent for `mode`/`target` and it stops a rebuild
  filling the replay log with lines nobody typed. It IS a divergence from note
  (f)'s "consume their accessors" **on the write side**, which is why item 7's
  VALUE normaliser (`dest_norm`) is still used even though the storage write is
  direct. **If the driver wants a restore to be replayable that is a different
  decision and should be said now, not discovered in review.**
- **Proc placement.** The scout's plan put `browser_tree_state/apply` after
  `browser_reveal`; they ship in one contiguous item-15 section after
  `browser_toggle_at`, with the rest of the state machinery. `rawhist_merge` is
  where the scout put it, beside `rawhist_push`, so the two 0119 gate lines are
  readable side by side. Behaviourally identical; noted only because the plan
  named a location.

**Exclusions honoured, none "fixed":** undo/redo history, wave highlights (D4 —
`clear_history` and `wave_hilight_clear_set` still run in `restore` untouched,
and BP09 greps every item-15 body for `wavehl`/`undo_hist`/`redo_hist`), and the
per-tab `view` range cache. Nothing items 8-14 added makes any of them wrong.

---

## 8. BEHAVIOUR CHANGE WORTH KNOWING (not a comment — it belongs here)

`ase::ui::viewer_snapshot`'s difference test means that **once the `browser`
sub-dict IS emitted**, a changed sidebar width or a changed global raw history
makes the next Save State fold in a different `viewer` value and mark the
session changed. Only at SAVE time (snapshot-at-save-only), so nothing dirties
spuriously — and a window nobody opened the browser in emits nothing at all and
serialises byte-identically to the pre-item-15 build. Real, and declared.

## 9. THE 0119 WRITE PATH, TRIPLE-BRACKETED

The restore is the **second** write path into a file under the user's home
(`~/.xschem/raw_history`), and item 13's sabotage (b) really wrote the user's
real one. All three mitigations shipped:

1. `rawhist_merge` carries `rawhist_push`'s gate line **verbatim**
   (`::update_recent_files`), before the in-memory fold and before the write, so
   a `--script` session cannot write at all. Pinned by BP06 (order, not
   presence).
2. BP59 brackets its own leg: `::USER_CONF_DIR` repointed at `$scratch`, both
   globals saved and put back, positive control first (the merge really lands in
   memory AND on disk, read back by `source` in a FRESH interp), then the gate
   closed and the negative asserted on the same fixture.
3. Item 14's BD59 discipline at FILE SCOPE: the user's real store's existence
   AND content are recorded up front and re-asserted untouched at the very end
   (BP61) — so **every** run, including every sabotage run, proves it clean.
   All four sabotage runs and all 12 clean runs passed BP61.

---

## 10. LEDGER STAGE — written AFTER `3e526f86` landed, and after the verifier

Everything below is the pipeline's ledger stage, not the implementer's. §1-§9 were
written *inside* the commit they would have had to name, so they could not name it;
this section can, and it also records the adversarial verifier's independent
re-measurements — which differ from §6's in one direction only: **cleaner**.

### 10.1 Verdict and commit

**Verdict: `[x]` — DONE.** Not DONE-PIXEL: the deliverable is session state, not an
appearance. No pixel is added by this item (the sidebar it restores is item 8/9's),
and the driver assigned **no eyeball-queue row**.

| commit | subject | branch | pushed? |
|---|---|---|---|
| `3e526f86510fe63b443ee424d5f31c5bea775fca` (`3e526f86`) | `feat(wviewer): persist browser state across sessions` | `fluid-editing` | **no** |

One commit. The verifier ran `git show --stat 3e526f86` itself and confirmed it
touches **exactly the two scoped files**, with **no other tracked diff under `src/`
or `tests/`** after all of its own injections and reverts (`git status -- src tests`
clean; only pre-existing untracked scratch from the session-start snapshot).

### 10.2 Files touched

| file | + | − | note |
|---|---|---|---|
| `src/wave_viewer.tcl` | 371 | 16 | the whole feature — the state machinery, `searchbar_set`, `rawhist_merge`, `browser_width`'s `{want {}}` widening, the `snapshot`/`restore` legs |
| `tests/headless/test_wave_sigbrowser_i1315.tcl` | 598 | 6 | group `BP` appended to item 13's file (ruling 30) |
| `doc/claude/signal_browser_batch/receipts/15_receipt.md` | — | — | **UNCOMMITTED** — driver's ledger (§1-§9 by the implementer, §10 by this stage) |
| `doc/claude/signal_browser_batch/PLAN.md` | — | — | **UNCOMMITTED** — the item-15 tick, this stage |

**No `.c`/`.h` file in the commit** — settled decision 8, confirmed independently
from `git show --stat`; `cd src && make` → `Nothing to be done for 'all'`. **No
frozen test file was edited**: `tests/headless/test_wave_sigbrowser.tcl` stays
byte-identical to ruling 30's freeze, which is precisely why `browser_width` was
WIDENED rather than refactored (BT08 greps four literals inside its body).

### 10.3 Test file and check counts

**`tests/headless/test_wave_sigbrowser_i1315.tcl`** — appended to, group prefix
`BP` (reserved for item 15 in that file's header, lines 17-19). No `gold/` entry.

| arm | added by this item | total in the file | verifier's independent re-measure |
|---|---|---|---|
| X (Tk), via `gated_xschem.sh` / `run_suites.sh` | **81** | **166** | recomputed from source, not from the receipt: **166 `check` invocations at HEAD vs 85 at parent `a37a620c` ⇒ 81 new**, and `check {BP` = **81**. Ran the file **3 separate times**, `RESULT: ALL PASS (166 checks)` every time |
| `--nogui` | — | **80** | (the X arm is the one this item's fixtures need; the `--nogui` arm is item 13's plus the pure `BP10-BP19` legs) |

166 = every invocation in the file, so **BP56's gated pixel-width leg RAN** in the
verifier's runs rather than printing `SKIPPED:` — the D-B gate is not quietly
swallowing the one WM-dependent check.

### 10.4 SABOTAGE TABLE — ledger form, `failedExactly` / `reverted` per row

Two PLAN-named injections plus two the implementer added, because the PLAN's named
pair are both NEGATIVES and driver note (d) is right that a negative alone is thin
cover. **Every row was RUN** (ruling 29). Each was diffed against a pristine
post-implementation scratchpad copy before the run and **restored from that copy**
afterwards — *not* `git checkout --`, which while the item was still uncommitted
would have discarded the item itself (the driver's standing warning; it has bitten
items 2, 3 and 6).

| # | origin | injection | predicted | ACTUAL | `failedExactly` | `reverted` |
|---|---|---|---|---|---|---|
| **(a)** | PLAN | drop `dict set d dest [wviewer::plot_dest $token]` from `browser_state` | a SUPERSET **declared UP FRONT** (ruling 23): **BP04, BP43, BP45, BP51** red, **BP44 GREEN** | **exactly those four** — `4 FAILED (162 passed)`; BP44 green as predicted (the state is still non-default via other fields), which is itself informative | **true** (against the declared superset) | true |
| **(b)** | PLAN | `browser_state_apply`: `set shown [dget $d shown 0]` → `set shown 1` (sidebar always visible) | **BP57 alone**; BP48 untouched by design | **exactly BP57** — `1 FAILED (165 passed)`; BP48 (a restore really CAN show the sidebar) green | **true** | true |
| **(c)** | implementer | `browser_tree_apply`: move the open-set application BEFORE the selection | **BP53 + BP54** red, BP52 green | **exactly BP53 + BP54** — `2 FAILED (163 passed)`; BP52 (selection) green | **true** | true |
| **(d)** | implementer | `snapshot` emits `browser` **unconditionally** (the gate removed) | **BP02 (gate leg) + BP42** red **AND `test_wave_modes.tcl` MG9 red** | **exactly BP02 + BP42** (`2 FAILED (164 passed)`) **AND MG9** (`1 FAILED (484 passed)`), identical diff `{… target browser}` vs `{… target}` | **true**, cross-file | true |

**What the table buys.** (c) is the only injection that proves the non-obvious
ordering finding is REAL rather than asserted — `$tv see` force-opens every
ancestor, so applying the collapse first silently re-expands exactly the group the
user collapsed. (d) is the evidence that the non-default emission gate is
load-bearing **outside this batch**: it is the only thing standing between item 15
and a red `test_wave_modes.tcl` on every machine.

Clean re-run after the last revert: `RESULT: ALL PASS (166 checks)`, `git status`
showing exactly the two item files modified.

### 10.5 The verifier's own UNNAMED sabotages, and their outcomes

The verifier injected **two probes the implementer never named**, from a pristine
copy, reverting each with `git checkout --` (safe here — the item's own commit had
landed) and byte-diffing against a pristine scratchpad copy afterwards.

| # | injection | outcome | what it settles |
|---|---|---|---|
| **V1** (aimed at a PLAN-named field none of (a)-(d) touched — the sidebar WIDTH, on the RESTORE side) | `browser_state_apply`: `browser_width $token [dget $d width 0]` → `browser_width $token` (derive instead of restore) | **failed EXACTLY ONE check** — `BP56 the restored width was really applied to the frame -> {480 480} (exp {260 260})`, `1 FAILED (165 passed)`. Reverted; clean re-run `ALL PASS (166)` | The width leg is genuinely covered, and with **strong discrimination** (derived 480 vs restored 260 — not an off-by-a-pixel). Also proves BP56 is not being silently skipped |
| **V2** (`rawhist_merge`'s data-loss guard) | `set new $rawhist` → `set new {}` — full REPLACE semantics, with `rawhist_add`/dedup/cap left in place so BP06's source greps still pass | **ALL PASS (166)** — nothing failed. Reverted clean | **A COVERAGE GAP, not a defect** — see 10.7 P1. The merge-vs-replace claim in the proc's ⚠ comment is UNPINNED |

The verifier also re-verified every anchor **from source** rather than from this
receipt (`snapshot` :2789, `restore` **:2840** post-commit, `test_wave_modes.tcl`
MG9 at :1314 pinning `{open sharedx rawfile graphs mode target}`), read
`browser_descend_to` (:7346 — its literal first statement really is
`browser_target_path $token $ids`, so BP55's declared substitution is accurate and
not a dodge), read `set_plot_dest` (:3081), the Add Trace combobox (:10563) and the
Plot Destination menu (:12828) to confirm **neither UI route keeps a `-variable`
mirror** (so D-F's direct array write cannot desync a widget), and matched
`searchbar_get`'s (:10379) sub-dict **key order** against `browser_state_default`
(the string-equality gate depends on it; pinned by BP10/BP41). It read the whole
new test body hunting tautologies and **found none**.

### 10.6 Non-baseline fails

**NONE.** `nonBaselineFails` is **EMPTY**, in both audits, sets compared rather
than counts.

| audit | summary | X deaths | fail set |
|---|---|---|---|
| implementer, shipping tree (gated) | 288 cases, 15 FAILs | `grep -c 'X connection to :0 broken'` = **0** | a **STRICT SUBSET** of the 16 HARD baseline names; the 16th, `test_fluid_editing`, PASSED (its documented exception). Each failed on **its recorded check** |
| verifier, independent (gated; waited out a ~35-minute human PAUSE mid-run) | 288 cases, 15 FAILs | **0** | same strict subset, `test_fluid_editing` again passing. **No `GUI_GATE=0`, no hand-written gate file** |

The one targeted-set fail was `test_wave_modes` **MG13** (a Ctrl+Shift+4
keybinding-resolution check, nothing to do with snapshot/restore) in the known WSLg
key-delivery flake family — **4/4 `ALL PASS (485 checks)` on re-run**, and the
verifier's own run of that file was `ALL PASS (485)` with **MG9 green**. MG9, the
cross-file oracle, was green on all five implementer runs and the verifier's.
**Nothing new goes onto the FLAKY list from this item.**

### 10.7 The verifier's NON-BLOCKING problems (`ok: true`, `scopeClean: true`)

- **P1 — `rawhist_merge`'s data-loss guard is UNPINNED (ruling 17).** The body
  carries a ⚠ block claiming *"IT MERGES, IT DOES NOT REPLACE … a restore that
  assigned the saved list would silently delete raws opened in another window since
  the snapshot was taken."* Probe **V2** made it a full replace and **all 166 checks
  stayed green**, because BP59's fixture sets `::wviewer::rawhist {}` immediately
  before the merge — merge and replace are indistinguishable there. Ruling 17 says
  widen the coverage or narrow the claim, **never neither**: either add a leg that
  pre-populates the live `rawhist` with an entry the saved list does NOT mention and
  asserts it survives, or drop the claim from the comment. **Does not fail the
  item** — the PLAN's scope word is "raw-file history" and it does round-trip, and
  the item-core sabotages all fired — but **the driver should rule on this before
  item 16**.
- **P2 — receipt anchor accuracy.** §1's `restore` row cited `:2836`, the *pre-edit*
  number, alongside post-edit ones. The post-commit line is **:2840**. Corrected in
  §1 above and restated here so item 16, which is told to re-verify anchors from
  source, does not discover a fourth disagreeing figure and treat it as new drift.
- **P3 — OBSERVATION, not a defect.** 32 of the 81 new checks (`BP01-BP09`) are
  source greps and 10 more (`BP10-BP19`) are pure-function; only **39 are Tk
  behavioural round-trips**. Acceptable here — BP01 explicitly guards the greps
  against the vacuous-empty-body trap, and all four named sabotages **plus both
  verifier probes** landed on behavioural checks — but the grep arm is the part most
  likely to go stale silently, and `BP08`'s literal `"$w.type   set"` (three spaces)
  will break on a reformat rather than on a regression.

### 10.8 DIVERGENCES FROM THE PLAN — the complete list, each with its reason

1. **D-A — `hist` is carried and restored but EXCLUDED from the non-default
   emission test.** *Reason:* `rawhist` is a GLOBAL disk-backed store that already
   outlives the session (item 13); counting it would make a state file's key set
   depend on the developer's home directory — MG9 would go red on any machine that
   had ever opened a raw. *Consequence accepted:* an all-default browser state
   records no history, and does not need to (`rawhist_load` reads the same store
   back at startup). Pinned by BP09 + BP12.
2. **D-B — the restored width is RE-CLAMPED to the new toplevel** (45% cap / 240
   floor). *Reason:* `browser_width`'s clamp could not be factored out (BT08, frozen
   file), so the want passes through the same cap. The dict field round-trips
   exactly; the pixels do not when the window changed size. Load-bearing checks
   (BP43/BP45) are at the DICT level and WM-independent; the pixel leg (BP56) is
   gated on `bs_wait_widths` `settled` && `topw >= 600` and otherwise prints a
   visible `SKIPPED:` line — never a silent pass, never a flaky fail. This is BT45's
   mechanism, the one inherited flake genuinely adjacent to item 15; it was
   `settled` and green in every measured run, **including the verifier's**.
3. **D-C — All-DBs IS snapshot state** (driver note (f) demanded a deliberate
   answer). *Reason:* it is a user-set search SCOPE and arrives free from
   `searchbar_get`. The foreign INVENTORIES are NOT persisted — `browser_reload`
   re-scans on show. BP49/BP50 also locally re-pin item 14's conditional-key
   contract: the Filter bar must carry **NO `alldbs` key at all**, not `0`.
4. **D-D — the open-set and selection are applied ONLY when the sidebar restores
   SHOWN.** *Reason:* item 9's D6 — there is no populated tree while it is hidden.
5. **D-E — the readout-bar-vs-sidebar pack order**, assigned to item 15 by item 8's
   eyeball row. Cursor state is deliberately NOT persisted (`snapshot`'s own D8), so
   after a restore the order is always sidebar-first / readout-later —
   deterministic. **NOT fixed, NOT a pixel change. WANTS A DRIVER WORD:** if the
   readout bar should always span the full toplevel width, that is a separate issue.
6. **D-F — a restore emits NO action-log lines.** *Reason:* it writes the
   `dest`/`browser` arrays directly and calls `sync_browser_mirror` + `browser_show`
   rather than `set_plot_dest` / `browser_toggle`, both of which `log_action` —
   matching `restore`'s own precedent for `mode`/`target` and keeping a rebuild out
   of the replay log. This IS a divergence from note (f)'s "consume their accessors"
   **on the write side**, which is why item 7's VALUE normaliser (`dest_norm`) is
   still used even though the storage write is direct. The verifier confirmed
   neither UI route mirrors `plot_dest` into a `-variable`, so nothing desyncs.
   **WANTS A DRIVER WORD:** if a restore should be replayable, that is a different
   decision and should be said now, not discovered in review.
7. **BP55 SUBSTITUTION — declared, not renamed (ruling 23).** Decision 11's clause
   ("a restored selection must be a legal input to item 12's sync") is asserted
   through `wviewer::browser_target_path` — the exact value `browser_descend_to`
   computes from `$tv selection` before it does anything else — rather than by
   driving a real `browser_descend_here`. *Reason:* a real descend calls
   `ase::ui::design_window`, which OPENS THE DESIGN WINDOW: precisely the "real
   viewer AND real design window at once" shape **every** pre-split death landed in.
   BP55 carries its own negative control (an empty selection is refused by the same
   gate). Verified accurate from source by the verifier.
8. **TEST FILE LOCATION.** The PLAN said "append to `test_wave_sigbrowser.tcl`";
   *reason:* superseded by ruling 30 (that file is FROZEN). Appended to
   `test_wave_sigbrowser_i1315.tcl` as group `BP`, per driver note (c) — **after
   MEASURING** the new destroy/restore-cycle axis (item 13's footprint claim does not
   transfer): 5 cycles, one three-point ASCII raw with hierarchical names, at most
   ONE viewer alive at a time, NO design window ever; **6/6 standalone completions at
   ~2.2 s, 12/12 measurable runs, `X connection to :0 broken` = 0**. Item 15 did NOT
   need its own file.
9. **PROC PLACEMENT.** The scout's plan put `browser_tree_state`/`_apply` after
   `browser_reveal`; they ship in one contiguous item-15 section after
   `browser_toggle_at` with the rest of the state machinery, and `rawhist_merge` sits
   beside `rawhist_push` so the two 0119 gate lines read side by side.
   *Reason:* readability; behaviourally identical. Noted only because the plan named
   a location.
10. **ANCHOR DRIFT REPORTED** (every item that checked this PLAN found one):
    `snapshot` is at `src/wave_viewer.tcl:2789` — the PLAN said `:2165` (+624) and
    driver note (b)'s re-measure said `:2628`, still short by 161. `restore` is at
    **`:2840` post-commit** (`:2836` pre-commit; PLAN `:2212`, driver `:2675`). The
    scout's re-measure was correct in every case and was re-verified from source
    before use, then again by the verifier.

**Exclusions honoured, none "fixed":** undo/redo history, wave highlights (D4 —
`clear_history` and `wave_hilight_clear_set` still run in `restore` untouched, and
BP09 greps every item-15 body for `wavehl`/`undo_hist`/`redo_hist`), and the per-tab
`view` range cache.

### 10.9 If this had FAILED — what a human would look at first

It did not fail (`ok: true`, `scopeClean: true`, `nonBaselineFails` empty). This
section exists because the ledger schema asks for it, and because the two most
useful findings of this item came from *injections*, not from a green suite. Should
item 15 come back:

1. **Re-run sabotage (d) before reading anything else.** If removing the
   non-default emission gate stops turning `test_wave_modes.tcl` MG9 red, then
   either the gate has been deleted or MG9 has stopped pinning `[dict keys $snap]`
   — and every session will start serialising a `browser` key, marking itself dirty
   on save. That is the failure that reaches users who never opened the browser.
2. **Then sabotage (c).** If BP53/BP54 stop firing when the open-set is applied
   before the selection, the ordering finding is unmeasured again — and the symptom
   in the wild is subtle and easy to misfile: *"the group I collapsed comes back
   expanded after a restore"*, caused by `$tv see` force-opening every ancestor.
3. **`browser_state_apply`'s step order is forced TWICE.** Both the width and the
   tree state must go **after** `browser_show` (the pack branch recomputes the width;
   `browser_populate` :6684 deletes every row and re-inserts `-open 1` with the
   selection cleared). A "the restore did nothing" report is almost always something
   moved above `browser_show`.
4. **A width complaint is probably D-B, not a bug.** The dict round-trips exactly;
   the pixels are re-clamped to the new toplevel (45% cap / 240 floor). Check BP56's
   line first — if it printed `SKIPPED:`, the WM never settled and the pixel leg was
   never measured in that run.
5. **A raw-history complaint is P1's gap.** `rawhist_merge`'s merge-vs-replace claim
   is currently unpinned (verifier probe V2 stayed green under full-replace
   semantics). If the report is *"raws I opened in another window disappeared from
   the Location history after a restore"*, that is exactly the uncovered claim —
   widen BP59 rather than hunting elsewhere.
6. **`~/.xschem/raw_history` is the blast radius** (issue 0119). `rawhist_merge` is
   the SECOND write path into the user's home; BP06 pins its `::update_recent_files`
   gate by ORDER, not presence, and BP61 re-asserts the user's real store untouched
   at file scope — it passed in all four sabotage runs and all 12 clean runs.
7. **Two questions are OPEN and belong to the driver, not to a debugger:** D-F (a
   restore emits no replay lines — deliberate) and D-E (readout-bar pack order).
   Neither is a defect today; both were flagged rather than decided.
