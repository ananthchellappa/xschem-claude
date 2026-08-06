# Item 01 — `wviewer::sig_match`, the shared matcher — ledger receipt

Ledger-stage receipt (implement + fixup + verify closeout). Batch
`signal_browser_batch`, branch `fluid-editing`, batch HEAD at item start `3098afa0`
(item 0), HEAD at close `bc1efec9`. Date 2026-08-04.

The implementer's own long-form receipt is
`doc/claude/signal_browser_batch/receipts/01_sig_match.md` — it carries the design
argument, the decision-3-vs-test-bullet conflict (§1), the two-`-nocase`-flags
analysis (§8/§11) and the re-baseline recommendation (§12). This file is the ledger
record: verdict, hashes, counts, sabotages, non-baseline fails, divergences.

---

## 1. Verdict

**DONE.** Verifier: `ok: true`, `scopeClean: true`, no BLOCKER.

Item 01 went round-trip twice. The first verify round raised a **BLOCKER** — a real
coverage hole, not a product defect: the verifier's own unnamed sabotage (delete
`-nocase` from the regexp arm) left the suite at ALL PASS. The fixup closed it with a
new check (SM27) and **no product-code change**; `git diff a6913ab2 HEAD -- src/` is
empty. The second verify round re-ran all five named sabotages plus four fresh unnamed
ones and confirmed the fix.

Two things are **owed to the driver** — neither is a defect, neither blocks item 2:

* **SM04 asserts the inverse of item 1's own test bullet** (see §9, D4). Two verifiers
  independently ruled the handling correct; the driver still owns the ruling.
* **PLAN decisions 12/13 authorship** — they entered in `a6913ab2`, whose own message
  declares them as already in the working tree. Confirmation only (see §9, D6).

## 2. Commits

| hash | what |
|---|---|
| `a6913ab2` | `feat(wviewer): sig_match, the shared signal matcher` — the item |
| `bc1efec9` | `test(wviewer): SM27 — the regexp arm's case default was untested` — the verifier-driven fixup, **test-only** |

Neither pushed. Item 1's ledger line reads `-> DONE (a6913ab2 + bc1efec9)`.

## 3. Files touched

| file | commit(s) | why |
|---|---|---|
| `src/wave_viewer.tcl` | `a6913ab2` only | `+139`: two new pure procs — `wviewer::sig_type` and `wviewer::sig_match` — in the pure-helper cluster at the clean seam the scout found (line 1446, before `target_clamp`). No UI, no ctx, no C. Shell arm `string match -nocase` at :1571, regexp arm `regexp -nocase` at :1577, the `^(?:$pat)$` anchoring wrapper at :1552, section header at :1447. **Untouched by the fixup.** |
| `tests/headless/test_wave_sigsearch.tcl` | both | new file (`+175`), then `+31/-14` for SM27 and the SM23 strengthening |
| `doc/claude/signal_browser_batch/PLAN.md` | both | ledger tick only in the fixup (`-1/+4`); `a6913ab2` also carried the driver's decisions 12/13 |
| `doc/claude/signal_browser_batch/receipts/01_sig_match.md` | both | implementer long-form receipt |

Scope verified, not assumed: verifier ran `git show --stat bc1efec9` (3 files, all in
scope) and read the full diff; `git status --porcelain -- src/ tests/ doc/` clean
before and after its own runs, no untracked droppings.

**Blast radius: zero.** `grep -rn 'wviewer::sig_match|wviewer::sig_type' src/ tests/`
outside the definition block and the new test file returns **no callers**. Nothing
user-visible ships behind this item yet; item 3 is the first retrofit.

## 4. Test file and check counts

* Test file: `tests/headless/test_wave_sigsearch.tcl` (**new**; auto-globbed by
  `full_audit.sh`, so no registration and no `gold/` entry is owed).
* **Added: 34 total** — 33 in `a6913ab2`, **+1 (SM27)** in the fixup.
  **Total in file: 34.** (`checksAdded: 1` in the implementer's fixup report is the
  fixup's delta, not the item's.)
* `tests/headless/run_suites.sh test_wave_sigsearch` → **RESULT: ALL PASS (34 checks)**,
  re-run by the verifier three times (once fresh, twice more after its sabotage round),
  green every time.
* `cd src && make` → *"Nothing to be done for all"* (Tcl-only item; build green).

## 5. Sabotage table

All five named sabotages fire on **exactly** their stated targets. Every one was
reverted with a targeted `git checkout -- src/wave_viewer.tcl` after
`git diff --numstat` confirmed a single one-line hunk, then
`git status --porcelain -- src/wave_viewer.tcl` confirmed empty.

| # | sabotage | target | result | failedExactly | reverted |
|---|---|---|---|---|---|
| (a) | drop the `^(?:...)$` anchoring at :1552 | SM04 | 1 FAILED / 33 passed — returned all 13 fixture names (the ViVA trap, measured) | **yes** | **yes** |
| (b) | flip the `-case` default (`set nocase 0`) | SM09 + SM27 | 2 FAILED / 32 passed — exactly the two case-DEFAULT checks, nothing else | **yes** (two targets, declared — see §9 D2) | **yes** |
| (c) | restore the legacy `if {$err} {set pattern {}}` | SM18 | 1 FAILED / 33 passed — `{ok 1}` vs `{err 0}`, both halves fired | **yes** | **yes** |
| (d) | delete `-nocase` from the **regexp** arm (:1577) — *the verifier's original blocker, promoted to a named sabotage* | SM27 | 1 FAILED / 33 passed | **yes** | **yes** |
| (e) | delete `-nocase` from the **shell** arm (:1571) — (d)'s mirror, added for symmetry | SM09 | 1 FAILED / 33 passed | **yes** | **yes** |

(d) is the whole point of the fixup: on the pre-fixup suite it left **33/33 ALL PASS**.
(d) and (e) together prove the two `-nocase` flags are pinned **per arm**, which is what
makes (b)'s two-check blast radius correct scoping rather than leakage. The verifier
re-ran all five itself rather than taking the claim.

## 6. The verifier's own unnamed sabotages

Round 1 (the BLOCKER, now closed): **delete `-nocase` from the regexp arm** →
survived at ALL PASS (33). Fixed by SM27; it is now named sabotage (d).

Round 2 (post-fixup), four fresh ones:

| id | sabotage | outcome |
|---|---|---|
| **U1** | keep the anchors, drop the **non-capturing group**: `set rx "^$pattern\$"` instead of `^(?:$pattern)\$` at :1552 | **SURVIVES — ALL PASS (34).** Non-blocking coverage gap, see below. |
| U2 | drop `-nocase` from `sig_type`'s `i(` arm | 3 FAILED (SM13, SM14, ST04) — covered |
| U3 | invert the `-case` mapping (`? 1 : 0`) | 1 FAILED (SM10) — covered |
| U4 | hoist the empty-pattern short-circuit above the `-type` filter | 3 FAILED (SM12, SM13, SM14) — covered |

**U1, the one surviving gap.** The group is not cosmetic: it is what makes whole-name
anchoring survive **alternation** — the one thing RegExp mode can do that Shell mode
cannot. Measured over the fixture, pattern `out|l1` returns `{l1}` under the settled
wrap and `{l1 xl1}` under the sabotage (`^out|l1$` parses as *starts-with-`out`* OR
*ends-with-`l1`*). The verifier deliberately did **not** call this a second BLOCKER:
(i) the product code is correct and unchanged — a test gap, not a defect — and
`sig_match` has zero callers today, so nothing user-visible ships wrong; (ii) alternation
is not among item 1's ten stated minimum-coverage bullets, and the anchoring requirement
*per se* **is** pinned by named sabotage (a); (iii) every stated bullet is covered.

**Recommended to the driver as item 4's entry condition** (item 4 is where a user first
types alternation into a RegExp search bar) — one line, confirmed by the verifier to
pass on shipping code and to fail (`{l1 xl1}`) under U1:

```tcl
check {SM28 regexp arm anchors an ALTERNATION as a whole} \
  [lindex [sig_match $SIGS {out|l1} -syntax regexp] 1] [list l1]
```

Note U1 evaporates if the driver overturns SM04 (§9 D4) — no wrapper, no gap.

## 7. Non-baseline fails

The item's own suite is green; everything here is `full_audit.sh` noise, and **all of it
is cleared**. Two independent solo audits were run (implementer, then verifier), both
pgrep-checked and piped to a file.

| | implementer audit | verifier audit |
|---|---|---|
| SUMMARY | 247 pass / 28 fail / 1 crash-timeout / 7 skip (283) | 252 pass / 24 fail / 2 crash-timeout / 5 skip (283) |
| WIREEDIT | PASS | PASS |
| SCRATCH | 0 leaked dirs | 0 leaked dirs |
| non-baseline names | 13 | 11 |

Disposition of every non-baseline name across both audits:

* **CLEARED by re-run (PASS on `run_suites.sh` / `gated_xschem.sh`)** — `test_ase_unnamed_net` (28),
  `test_close_window_force`, `test_deselect_mode` (18), `test_fluid_editing` (26),
  `test_hover_highlight`, `test_lib_manager_bold`, `test_multi_window` (15),
  `test_wave_modes` (485), `test_altf5_ciw`, `test_lib_manager_checkin` (was TIMEOUT),
  `test_ase_dialogs` (133), `test_callback_argc` (5), `test_cmdmode_descend_0201`,
  `test_wave_drag_preview` (94), `test_wave_split_strip` (221),
  `test_key_graph_context` (was TIMEOUT).
* **DOCUMENTED FLAKE** — `test_ase_plot`: fails on exactly the documented P4/P6 gesture
  checks (+P9 focus), reproduced by both sides independently, and fails **identically**
  with `wave_viewer.tcl` reverted to `3098afa0`. Memory: 1–2/10, always has.
* **ISOLATION-PROVED not item 1's** (revert `src/wave_viewer.tcl` to `3098afa0`, confirm
  `grep -c sig_match` = 0, re-run, restore):
  * `test_prop_form_field_width_0170` — fails identically (same 2 checks) with `sig_match`
    physically absent.
  * `test_fluid_editing` — fails on exactly FE8 with the item absent too.
  * `test_geometry_sanity` — HEAD 1 pass/3 fail vs item-absent 0 pass/5 fail, i.e.
    **worse without** the item. Pure WSLg window-manager noise (got 1067x734 or 1x1
    where 800x600 was asked).
* **SKIPs are self-declared banners, not failures** — all re-run individually:
  `test_graph_box_zoom_xy`, `test_drag_keeps_selection`, `test_fluid_loop_0088`,
  `test_fluid_reversal_0089`, `test_fluid_drag_through_anchor_0109`,
  `test_connected_drag_group_transform_0114` (7), `test_flylines_render`,
  `test_ase_savestate_adopt` (26) — PASS individually, except
  `test_descend_goback_selflog` / `test_drag_keeps_selection`, which print a SKIP banner
  (no `--logdir` / no X).
* **Three *baseline* names PASSED** for the verifier — `test_remap`,
  `test_resolved_net_hash_bus_0158`, `test_wave_trace_menu` (the TG9 one).

**`test_wave_axis_zoom` — raised, then downgraded.** The implementer flagged it: always
the same 5 axis-grab checks; HEAD 1 pass/3 fail, `3098afa0` (item 0 only) 1 pass/3 fail,
`ccd5f30a` (pre-batch) 5 pass/1 fail — a tree carrying *neither* batch item still fails,
so it is nobody's regression, but the rate looked worse on the two batch trees, with item
0 the only candidate. **It then PASSED outright in the verifier's audit** and is absent
from its fail list. Net: one cheap re-run by the driver, **not** a bisect.

**Baseline is unreliable for the fourth consecutive run.** Four audits of this single item
produced four different non-baseline sets (9 / 8 / 13 / 11 names). Both sides recommend a
**re-baseline before item 2**, adding to the known-flaky set: `test_geometry_sanity`,
`test_fluid_editing` (FE8), `test_key_graph_context`, `test_ase_plot` (P4/P6/P9),
`test_wave_axis_zoom`. A driver process call, not repairable inside an item.

## 8. Anchors re-verified

All five source citations checked byte-exact from the shipping tree by the verifier:
`wave_viewer.tcl:1571` (shell `string match -nocase`), `:1577` (regexp `regexp -nocase`),
`:1447` (the new SIGNAL SEARCH section header), `xschem.tcl:4477/4478` (the legacy
`set err [catch ...]` / `if {$err} {set pattern {}}`), `:4480` (the
`regsub {^v\((.*)\)$}` strip). The scout's fourteen anchors were all `ok: true`, with one
standing warning carried forward: **file drift is `+40` almost everywhere but `+53` at
`wviewer::open`** — later scouts must re-verify line numbers, never add 40.

## 9. Divergences from the PLAN

| # | divergence | reason |
|---|---|---|
| **D1** | **The fixup changed no product code.** The BLOCKER was a *test* coverage hole; `src/wave_viewer.tcl` is byte-identical to `a6913ab2` (`git diff a6913ab2 HEAD -- src/` empty). | `sig_match` was correct; the suite was not. Confirmed by re-running the verifier's own sabotage against the new check. |
| **D2** | **Sabotage (b) now fails TWO checks (SM09 + SM27), not one.** The PLAN's "(b) → the case check fails" assumed a single case-default check. | The implementation carries **two independent `-nocase` flags** (:1571 shell, :1577 regexp), so the default needs one check per arm. Sabotages (d)/(e) each hit exactly one arm, so per-arm pinning is still provable — correct scoping, not leakage. Declared in the test file, `01_sig_match.md` §8/§11, and the ledger line; verifier re-measured all three combinations rather than accepting the claim. |
| **D3** | **Two sabotages added beyond the PLAN's three** — (d) the verifier's regexp `-nocase` deletion, (e) its shell-arm mirror. | Closes the blocker and proves per-arm pinning. The PLAN's three are unchanged and all still fire on exactly their targets. |
| **D4** | **SM04 asserts the INVERSE of item 1's own test bullet.** The bullet says regexp `l*` matches everything (the documented ViVA trap); SM04 asserts it matches nothing. | Settled **decision 3** wraps patterns as `^(?:$pat)$`, and under the unanchored reading the PLAN's own sabotage (a) would have no target. `references/viva_cadence_waveform_viewer.md` is internally inconsistent (:207 vs :211 vs :943 — which admits the anchoring rule "is inferred from three worked examples, never stated"). Two verifiers independently reached the same resolution. The trap *is* still asserted, inverted, in one check. **Still owes a driver ruling**: if it goes the other way, SM04 *and* the `^(?:...)$` wrapper both change — and U1 (§6) disappears with them. |
| **D5** | **SM23 strengthened** from "sig_match call vs sig_match call" to an independent literal `[list ok [list l1 l2]]`. | A verifier test-quality note. Verified not to give sabotage (a) a second target — the shell arm is untouched by the anchoring wrapper, and (a) still fails SM04 alone. |
| **D6** | **PLAN decisions 12/13 authorship, and the 1-8, 12, 13, 9, 10, 11 numbering.** | Not this item's to prove or fix: they were already in the working tree when item 1 started, and entered the repo in `a6913ab2`, whose message says so; the verifier read that diff to confirm. **Driver confirmation only.** The cosmetic numbering was left alone deliberately — renumbering settled decisions mid-batch would invalidate every citation already written into code comments and receipts. |
| **D7** | **Re-baseline recommendation** (§7). | A driver process call, not repairable inside an item. Raised with fresh evidence (four audits → four different non-baseline sets) by both sides. |
| **D8** | **U1 deferred to item 4** rather than fixed here (§6). | Alternation is not among item 1's ten stated coverage bullets, the anchoring requirement itself is pinned by (a), and the proc has zero callers — so nothing ships wrong. The exact one-line check is written out in §6 and confirmed to pass/fail correctly. |

## 10. If this had FAILED — what a human looks at first

Not applicable: **DONE**, `ok: true`, `scopeClean: true`, 34/34 checks, 5/5 sabotages
fired on exactly their targets and were reverted, no product-code defect found.

The three things a human should still glance at, in order, **before item 2 starts**:

1. **The SM04 ruling (D4).** One decision, two artefacts hang off it (SM04 and the
   `^(?:...)$` wrapper), and it also decides whether U1/SM28 is a real item-4 entry
   condition. Everything downstream that matches signal names inherits it.
2. **The re-baseline (D7/§7).** Four audits, four different non-baseline sets — every
   later item's "non-baseline fails" section is currently guesswork until this is redone.
   Cheapest fix: one clean solo `full_audit.sh` on `HEAD`, promoted as the new baseline,
   with the flaky set named in §7 marked as such.
3. **One cheap re-run of `test_wave_axis_zoom`** (§7) — raised by the implementer, then
   contradicted by the verifier's own green run. It fails on the pre-batch tree too, so
   it is nobody's regression; a single re-run settles it without a bisect.
