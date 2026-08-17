# 05 annex — the fix round, both mutation tables, and the transcripts

Detail for `receipts/05-viewer-tcl-browser-scan.md`, which is the receipt of record. Nothing here contradicts it; the
receipt is the summary and this is what it was summarised from. Written by the implementer and extended by the fix
round, so its own numbers (the first cut's 113 checks, the stale `62 FAILED (48 passed)`) are kept for the record —
§0 explains each.

`PLAN.md` §3b item 5 · `DECISIONS.md` **B2a**/**D2** · spec **extended, not re-cut**: `specs/raw_case_mode.md` **§12**
(§9's three-residue paragraph corrected in place). Base `e368d634`, `fluid-editing`, nothing pushed, **no C changed — no
rebuild**. Verdict **`[E]`**: the Case Mode menu is pixels; `owed.sh add look` recorded.

**FIX ROUND, 2026-08-16 — read §0 first.** Three reviewers raised eight distinct confirmed findings against the first
cut, one of them a **blocker**. All eight are fixed. The check count moved **113 → 134**, and two of the new checks
exist because the review proved the old ones could not fail.

## 0. The fix round — every confirmed finding, and what was done

| # | finding | verdict | fix, and the check that now holds it |
|---|---|---|---|
| 1 | **BLOCKER — no check drove the radiobutton's `-command`.** Replacing it with a no-op left a dead control and 113/113 green: every existing check called `set_case_mode` directly. | **real** | `CS95k2`/`CS95k3` `invoke` the widget. They step off the value the previous one left (`distinguish`→`preserve`→`unknown`) so a no-op `-command` fails **both**. Mutation `WIDGET-dead-command` reddens exactly those two. |
| 2 | **The override was silently discarded by `attach_raw`** — i.e. by every re-run — with no notice and no check. | **real** | RULED and fixed, not merely documented: `casemodeuser($token)` records `{mode path}`, `attach_raw` re-applies it through `casemode_reapply`, **per file per window**. `CS95t`/`CS95u`/`CS95v` (survives a re-attach of the same file), `CS95w` (a different file gets a fresh detection), `CS95s` (dropped with the window). Five mutations redden them. Spec §12 carries the lifetime table. |
| 3 | **`CS92e` did not pin the D2 skip it was cited for** — inverting the rule left the suite green, because the clean slot answered first and the skip was never on the critical path. | **real** | `Amb`/`amb` added to the poisoned slot **only**, so the folded query `AMB` has exactly one slot that could answer and it is ambiguous. New `CS92e2` asserts `{}`; new `CS92e3` proves the name is really there. Mutation `D2-accept-ambiguous` (`ne {ok}` → `eq {no}`) now reddens **`CS92e2` alone** — it left the whole suite green before. `CS92e` keeps a narrower job and spec §12 no longer cites it for the skip. |
| 4 | **`casemode_cached` had no production caller** — both engine sites re-asked unconditionally, so the cache saved nothing and six checks read `casemode_cached` — all of them in the test. | **real** | `casemode_refresh` now returns a warm pair (read *through* `casemode_cached`) instead of re-asking; `set_case_mode` passes `force 1` because it is the caller that changed the answer. `CS95o2` pins the hit (the entry is poked to a value the engine would never return), `CS95o3`/`CS95o3b` pin the force. Mutations `CACHE-no-warm-read` → `CS95o2` alone; `CACHE-set-does-not-force` → `CS95i CS95j CS95o3b CS95p`. |
| 5 | **The master red-before-green figure was stale** — "62 FAILED (48 passed)" sums to 110, not the shipped 113. | **real** | Re-measured on the final bytes: **`RESULT: 78 FAILED (56 passed)`** on `:99` (134) and **`RESULT: 41 FAILED (33 passed)`** true headless (74). §3 corrected. |
| 6 | **`set_case_mode` emitted no `log_action` line** — the only Options command in the file that does not. | **real** | One line added on the success path, in the proc's own argument order so the log is directly callable. `CS95y` spies `log_action` by rename. Mutation `NO-ACTION-LOG` reddens it alone. |
| 7 | **Non-ASCII fold divergence** — the mirror used Unicode-aware `string tolower` while the engine's `strtolower()` (util.c:1006) is byte-wise, so on `v(CÄ)`+`v(cä)` the mirror invented a D2 collision the engine does not have and `resolve_signal_db` skipped a slot that resolves. | **real** | `wviewer::fold_key`, a 26-pair ASCII `string map`, replaces both `string tolower` calls in the matcher. `CS89x`–`CS89z` (pure) and `CS90x`–`CS90z` (agreement against a database that really holds both spellings). Mutation `F1-unicode-fold` reddens `CS89x CS89y CS89z CS90y CS90z`; an identity fold reddens **22** checks, so the rule is load-bearing both ways. |
| 8 | **Five checks called `resolve_signal_db` unguarded in argument position** — the trap the file's own `CS92f2` comment describes — so a throwing proc killed the file with no `RESULT:` line, which a sabotage driver reads as "nothing went red". | **real** | All five hoisted onto their own `pcall` line. **A/B measured with the same mutation** (`error {sabotage}` at the top of the proc): one call left inline → **0 `RESULT` lines**; all hoisted → **`RESULT: 9 FAILED (125 passed)`**. |

**Finding 1's own claim was corrected too, and it needed a measurement.** The review's first item said the control's
"one declared observable effect never fires" because `hilight_sender_case_mode()` (hilight.c:364) reads the **schematic**
window's `xctx->raw`, not the viewer's. That is right, and the two sentences asserting otherwise (`wave_viewer.tcl` and
spec §12) are **deleted and replaced with the measurement**, not softened. It is now pinned by `CS95x2`/`CS95x3`, which
load the same file into both contexts and assert the answers diverge — and writing that check caught a mistake of my
own: `xschem get current_win_path` read after `ase::session_open` returns the **viewer's** path, so the first cut
compared a context with itself and reported the two Raws as one. The capture moved to the top of the file.
Where a session-wide mode belongs is named rather than half-built: the simulator **profile** (item 13's `simconf` row,
`DECISIONS.md` B1), because "which Raw is authoritative when a session has several" is a question a menubar cannot
answer.

**Also corrected, from the verifier's problem list (not a confirmed finding, but the record must be right):** §4's row
`M21` claimed the lookup-flag coupling reddens `CS95l` only; it reddens `CS95l`, `CS95m` **and** `CS95m2` — the
in-memory-rename oracle catches the re-read too. Row corrected below.

## 1. Files changed

`src/wave_viewer.tcl` **+295 −41 first cut, +~140 more in the fix round** (the one matcher · the ASCII fold key · the
per-slot `case` key · the Case Mode control · the override's lifetime) ·
`tests/headless/test_wave_casemode.tcl` **NEW, 134 checks** · `specs/raw_case_mode.md` **§12 extended twice** **+13 −1** (§9) ·
`specs/mixed_signal_signal_browser.md` **+10** · `code_analysis/ngspice_case_sensitivity.md` **+10**. Untracked, also to
commit: this receipt, `audit_item05_closer_2026-08-16.txt` and the fix round's
`audit_item05_fixround_2026-08-16.txt`.

## 2. Decisions, and the evidence for each (all written into spec §12)

- **ONE Tcl mirror, not two — and it does NOT become `xschem raw index`.** `name_rungs`/`name_index`/`name_lookup` are
  the rule; `validate_rpn` and `resolve_signal_db` are their only callers. The engine route was rejected for two
  independent reasons: both callers judge a **foreign** name list (`raw index` answers for the current database only, so
  it would need a `raw switch` per candidate), and `validate_rpn` must stay callable with **no engine**
  (`test_wave_viewer.tcl` drives it on synthetic lists; the gate exists because `raw_add_vector()` swallows the
  evaluator's −1, issue **0418**). Held down by **agreement** instead — the `CS90*` leg reads `raw index` *and* the gate
  for one token and fails on any difference. Measured: `M28` (refuse everything) reddens 36, `M29` (approve everything) 20.
- **`resolve_signal_db`'s flat `tolower` is deleted, not ported.** It ignored D2 (first match won) and could not see
  `distinguish`. Now each slot is judged by **its own** `case` flag — a key `signal_list_all` reads while the engine is
  standing on that slot, the only moment a foreign database's flag is knowable without a second switch cycle.
- **Rung 4 is mirrored now** — item 2's residue 1, the one input where "the rule is `get_raw_index`'s" was false. **Two
  traps hit while writing it:** the C appends nothing after `"i(%s"` (the obvious `"i(<rest>)"` made `i(x1.vp))`, so rung
  4 matched nothing — found by `CS89d` going red, not by review), and the anchor check `CS90m` is vacuous without the
  **bait** column `i(.x1.vp)`, item 2's own `CS39f` bait on the Tcl side.
- **An ambiguous slot is SKIPPED, not a global refusal**, and the tie-break is now stated exactly: **the first slot that
  RESOLVES wins**. `CS92f` pins the consequence a first draft of it got wrong — an *exact* hit in a foreign slot does not
  beat a *folded* hit in the one the user is standing on. ⚠ **The skip itself is pinned by `CS92e2`, NOT `CS92e`** — see
  §0 finding 3; the first cut cited `CS92e` and that check stayed green through the exact inversion of the rule.
- **RULING (fix round) — the fold key is ASCII-only.** `wviewer::fold_key`, a 26-pair `string map`, not
  `string tolower`. The authority is `raw_fold_key()` → `strtolower()` (`util.c:1006`), a `tolower()` loop over **bytes**
  with no `setlocale` anywhere in `src/`. Tcl's Unicode-aware fold turns `v(CÄ)`+`v(cä)` into one key and invents a D2
  collision the engine does not have (`xschem raw index {v(Cä)}` = 2 against the mirror's `ambiguous`). §0 finding 7.
- **THE DRIVER ADDITION WAS BUILT, NOT PASSED ON.** B2a's first-ranked source is now `Options ▸ Case Mode` in the viewer
  menubar: a disabled readout naming the mode **and the source that answered** (B2b), plus `auto`/`fold`/`preserve`/
  `distinguish` radios. `upper` is offered by neither side.
- **RULING — the control writes the EXPLICIT SOURCE ONLY, never `Raw.case_sensitive`.** That flag's setter **re-reads the
  file** (`scheduler.c:10697`), and item 3 separated reporting from acting on purpose (`CS59e`); a menubar pick must not
  silently rebuild a loaded database. Proven by an **in-memory rename** (`CS95h0`/`CS95m`) — a name-list comparison
  cannot tell a re-read of the same file from doing nothing (item 1's `CS24`/`CS25` technique, run backwards).
- **RULING — resolved on a user action, never on a redraw** (item 3's binding constraint). The engine is asked from
  exactly two one-shot call sites, the cascade's `-postcommand` and `set_case_mode`; the answer caches in
  `wviewer::casemode($token)`; **`attach_raw` DROPS it and does not recompute** (`CS95q`); `forget` clears all three
  arrays (`CS95s`). `xschem raw case` (cheap, a struct field) is not `raw casemode` (up to 189 ms, no cache) and
  `db_fuzzy` uses only the former. ⚠ **Fix round: the cache now actually has a reader.** In the first cut both sites
  called `casemode_refresh` and it re-asked unconditionally, so the ruling was satisfied by *placement* alone and
  `casemode_cached` had no production caller at all. `casemode_refresh` returns a warm pair (`CS95o2`); `set_case_mode`
  forces past it (`CS95o3`/`CS95o3b`). §0 finding 4.
- **RULING (fix round) — the override survives a re-attach of the SAME file, per window.** `explicit_case_mode` is a
  field on the `Raw` and `ase::attach_dbs` does clear+read, so a **re-run destroyed the user's setting** and the tick
  silently went back to `auto`. The C already refuses this loss on its own re-read path (`keep_explicit`,
  `scheduler.c:10125`/`:10148`). `casemodeuser($token)` + `casemode_reapply`, path-matched. §0 finding 2.
- **RULING (fix round) — the override does NOT reach the Ctrl-K senders, and the claim that it did is deleted.**
  `hilight_sender_case_mode()` reads the **schematic** window's `xctx->raw`; the viewer is a separate context with its
  own. Pinned by `CS95x2`/`CS95x3`. A session-wide mode belongs on the simulator profile (item 13). §0 finding 1.
- **RULING (fix round) — the override is action-logged**, like every other state-changing Options command in the file
  (`CS95y`). §0 finding 6.
- **The `@dev[param]` audit: it IS handled — the finding is a different one.** Shapes **measured** on `build-ver_50`
  (`.options savecurrents`, one deck, top-level `R1` + `Rq` inside `X1`): `fold` → `i(@r1[i])` / `i(@r.x1.rq[i])`;
  `preserve` → `i(@R1[i])` / `i(@R.X1.Rq[i])`. `grep` finds only three `@` lines in the file, which is what made "no
  @-handling anywhere" look true — all three ARE the handling (`sig_declass`'s `^@?[A-Za-z]$`, `sig_class`'s `@*`,
  `browser_label`'s `regsub {^@}`), and **none is case-sensitive**, so both spellings parse identically.
  **NAMED, NOT FIXED:** a **top-level** `@`-param has no dots, so `sig_declass`'s ≥3-segment guard (DC09) never sees the
  tag and it classes `net` — `Show device internals` OFF therefore hides `i(@r.x1.rq[i])` and **keeps** `i(@r1[i])`
  (`CS91h`–`CS91j`). Out of scope: relaxing the guard moves `sig_declass`, pinned by DC09/DC12/DC13 and by the two-pane
  counts, and this item owes an EMPTY audit diff. It is a classification question, not a case one.

## 3. Test, checks, RESULT

`tests/headless/test_wave_casemode.tcl` — **NEW**, `CS89`–`CS95y`, **134 checks** (band grepped: `CS0`–`CS64f` in
`test_raw_case_mode.tcl`, `CS65`–`CS88` in `test_hilight_case_senders.tcl`; the `CS0`–`CS9` in
`test_cmdmode_descend_0201.tcl` / `test_wave_axis_zoom.tcl` are unrelated file-local ids). **74 run true headless**; the
viewer legs self-skip with a `NOTE` and nothing prints `SKIP`. Verbatim: **`RESULT: ALL PASS (134 checks)`** and
**`RESULT: ALL PASS (74 checks)`**.

**Master red-before-green, re-measured on the FINAL bytes** (the first cut quoted `62 FAILED (48 passed)`, which sums to
110 and described an earlier revision of the test — §0 finding 5): `src/wave_viewer.tcl` replaced by `git show HEAD:`
and re-run → **`RESULT: 78 FAILED (56 passed)`** on `:99` (134) and **`RESULT: 41 FAILED (33 passed)`** true headless
(74); restored from a byte-exact backup (`md5sum` equal) → ALL PASS. That run also shows the pre-item-5 defect
directly: `CS93h` reads `idx 1 … collide.raw` — the old flat matcher naming a `distinguish` database for a folded query.

**15 suites** via `GUI_GATE=1 run_suites.sh` on `:99` → **`RESULT: 15/15 runs passed`**: wave_casemode 134,
raw_case_mode 277, hilight_case_senders 30, wave_viewer 400, wave_crossdb_trace 130, wave_sigsearch 233, wave_grid 399,
wave_sigbrowser_2pane 108, wave_sigbrowser_digital 82, wave_sigbrowser_i14 109, wave_sigbrowser_i1315 191,
backannotate_digital 81, ase_cosim 342, wave_axis_zoom 370, del_negative_arg 24 — every count identical to items 2–4's
receipts and to the first cut's where they overlap; only `wave_casemode` moved, 113 → 134.

**FIX-ROUND audit** (`GUI_GATE=1 full_audit.sh`, `:99`, **`audit_item05_fixround_2026-08-16.txt`**, the file to judge
this item by): `SUMMARY: 319 pass  15 fail  0 crash/timeout  0 skip  (total 334)`. Diffed by test **NAME and STATUS**:
against `audit_item04_closer_2026-08-16.txt` the **entire diff is one added row, `> test_wave_casemode PASS`**; against
the first cut's `audit_item05_closer_2026-08-16.txt` the diff is **EMPTY**, and the 15 red names are **identical** to
the item-04 baseline's, verified by a sorted name-only diff. So the fix round moved zero statuses in either direction
even though it changed 140 lines of `wave_viewer.tcl` and added 21 checks. ⚠ **One observation for the next reader:**
`full_audit.sh` writes its `SUMMARY` line and then keeps working — the file read `320 pass 14 fail` at the moment the
summary first appeared and settled at `319/15` when the run finished (exit 1, as it always is with reds). Wait for the
process, not for the string.

**First-cut audit, kept for the record** (`audit_item05_closer_2026-08-16.txt`): `SUMMARY: 319 pass  15 fail
0 crash/timeout  0 skip  (total 334)`. Diffed by test **NAME and STATUS** against `audit_item04_closer_2026-08-16.txt`
(318/15/0/0 of 333) the **whole diff is one added row, `> test_wave_casemode PASS`** — no row moved either way, none
lost, the 15 reds identical by name (`ase_window`, the four libmgr/SANDBOX environment failures, `cadence_drag`, `ciw`,
`lib_sweep`, `reopen_readonly`, `rotate_stretch_short_0104`, `selflog_output`, `wave_markers`, `wave_sigbrowser_0312`,
`wave_sigbrowser_keys`). Count rows with `grep -cE '^FAIL +\| +test_'` (**15**), never `grep -c '^FAIL'`. The contract is
about **movers**; there are none, so the baseline may roll here. **Slip disclosed:** three COMMENT-only lines in
`wave_viewer.tcl` (a "three places" that should read "two", two stale `:2525` pointers) were `sed`-corrected ~110 rows
into this run — no code, `sed -i` renames atomically, and five suites were re-run green on the final bytes afterwards.
**Verifier's restore point:** `src/wave_viewer.tcl` md5 `5927127bb5d2668a4824ad9889fb7841`; the sabotage rounds ran
against `9309ae7e1025c3c8b2f955a4d0fd9960`, which differs only in those three comments.

## 4. Sabotage — 45 mutations, each on a copy of a byte-exact backup, restored `md5sum`-clean. **98 of 113 checks appear**

| mutation | reddens |
|---|---|
| `M1` rung 4 deleted · `M2` rung 4 gets a trailing `)` (**the bug that really happened**) | CS89d CS89e CS89j CS90k CS90l CS90t |
| `M3` rung 4 unanchored (needs the bait) · `M4` guard cut to four chars | CS89f CS90m · CS89g |
| `M38` the `v()` wrap rung deleted | CS89b CS89c CS89d CS89e CS89f CS89g CS89k CS89n CS90n CS90o CS92h |
| `M5` byte-identical duplicates treated as a D2 collision · `M6` D2 poison → first-wins | CS89q · CS89m CS89n CS89w CS92f3 |
| `M7` the `distinguish` suppression removed | CS89s CS89t CS89u CS90s CS90u CS93f CS93h CS93l |
| `M8` the exact rungs deleted | CS89h CS89o CS89p CS89r CS90r CS90t CS92f2 CS93e CS93i CS93k |
| `M28` `name_lookup` refuses everything · `M29` approves everything | 36 checks (CS89h…CS93n) · 20 checks (CS89l…CS93l) |
| `M9` `db_fuzzy` always folds · `M10` `validate_rpn` ignores its override | CS90s CS90u · CS89u CS93f CS93l |
| `M11` slot `case` hardwired 0 · `M39` the `case` key removed | CS93c CS93d CS93f CS93h CS93l · the same + CS92c |
| `M12` `db_by_index` drops `case` · `M13` `add_trace`'s arm loses the override | CS93d CS93f CS93l · CS93l |
| `M14` `resolve_signal_db` back to the flat `tolower` | CS93h |
| `M40` resolve never answers · `M41` resolve answers slot 0 blind | CS92d CS92e CS92f CS92h CS93i · CS92d CS92g CS92h CS93h CS93i |
| `M15`/`M15b` the readout stops naming its source · `M31` no-database renders as `fold` | CS94c CS95j · CS94b CS94d CS94e CS94g CS95e · CS94f |
| `M16` choices offer `upper`, not `auto` · `M22` `auto` means `fold` | CS94 CS94h CS95n CS95o CS95p · CS95o CS95p |
| `M17` refresh never caches · `M34` `casemode_cached` drops its guard | CS95g CS95i CS95o CS95p CS95r · CS94i CS95q |
| `M18` `attach_raw` keeps a stale cache · `M19` `forget` leaks the entry | CS95q · CS95s |
| `M20` no cascade · `M20b` no `-postcommand` · `M20c` the whole cascade block gone | CS95d · CS95e0 · CS95e0 |
| `M42` no readout entry · `M43` radios → checkbuttons · `M44` the cascade widget renamed | CS95b CS95e CS95e0 CS95j · CS92 CS95c CS95d · 11 incl. CS95 |
| `M30` `set_case_mode` never reaches the engine · `M23` the post never sets the tick · `M24` never updates the readout | CS95h CS95i CS95j CS95k CS95n · CS95f · CS95e CS95j |
| `M21` **the control also flips the lookup flag** (the coupling this item ruled against) | CS95l CS95m CS95m2 |
| `M25` `sig_declass` drops `@?` · `M26` `sig_class` drops `devmeas` · `M27` `browser_label` keeps the `@` · `M35` drops `srcbranch` · `M37` `sig_type` calls `@` a current | CS91 CS91b CS91c CS91d CS91e CS91i CS91j · CS91–CS91e · CS91h · CS91f · CS91k |

**`M20b` SURVIVED GREEN at 110/110** and that is the round's best finding: the first cut of the menu leg *called*
`casemode_menu_post` directly, so deleting the cascade's `-postcommand` — the only thing that would ever call it — moved
nothing. `CS95e0` now **posts the menu for real** (`$m post` fires `-postcommand` exactly as a click does) against a
sentinel label; `M20b` and `M20c` then redden it alone.

(`M21`'s row is corrected here: the first cut claimed `CS95l` alone. The in-memory-rename oracle catches the re-read
too, so it reddens three.)

## 4b. Fix-round sabotage — 21 mutations, driver `scratchpad/sab2.py`, each applied to a copy of a byte-exact backup and
## restored `md5sum`-clean (`c23ff09914a0aa22b098e71715ed3023`) before the next

Verbatim driver output, `RESULT` line then the reddened checks:

| mutation (all in `src/wave_viewer.tcl`) | RESULT | reddens |
|---|---|---|
| `F1-unicode-fold` — `fold_key` → `string tolower` | 5 FAILED (129 passed) | CS89x CS89y CS89z CS90y CS90z |
| `F1-identity-fold` — `fold_key` folds nothing | 22 FAILED (112 passed) | CS89i CS89m CS89n CS89q CS89v CS89w CS89x CS89y CS89z CS90e CS90f CS90h CS90l CS90o CS90w CS90y CS90z CS92e CS92f CS92f3 CS93g CS93n |
| `EXACT-rung-off` — `name_lookup`'s exact loop | 11 FAILED (123 passed) | CS89h CS89o CS89p CS89r CS90r CS90t **CS92e3** CS92f2 CS93e CS93i CS93k |
| **`D2-accept-ambiguous`** — `resolve_signal_db` `ne {ok}` → `eq {no}` | 1 FAILED (133 passed) | **CS92e2** — *this is the mutation that left the FIRST CUT fully green* |
| `RESOLVE-skip-all` — every slot skipped | 6 FAILED (128 passed) | CS92d CS92e CS92e3 CS92f CS92h CS93i |
| **`RESOLVE-throws`** — `error {sabotage}` at the top of the proc | **9 FAILED (125 passed)** | CS92d CS92e CS92e2 CS92e3 CS92f CS92g CS92h CS93h CS93i — *with one call left un-hoisted the same mutation gives **0 `RESULT` lines**, measured* |
| `CACHE-no-warm-read` — the warm short-circuit | 1 FAILED (133 passed) | CS95o2 |
| `CACHE-set-does-not-force` — `casemode_refresh $token 1` → `$token` | 4 FAILED (130 passed) | CS95i CS95j CS95o3b CS95p |
| `CACHE-no-write` — `casemode_refresh` stops caching | 6 FAILED (128 passed) | CS95g CS95i CS95o CS95o3b CS95p CS95r |
| `NO-ACTION-LOG` — the `log_action` line | 1 FAILED (133 passed) | CS95y |
| `USER-not-recorded` — `set_case_mode` stops recording the pick | 2 FAILED (132 passed) | CS95u CS95v |
| `USER-no-reapply` — `attach_raw` stops calling `casemode_reapply` | 2 FAILED (132 passed) | CS95u CS95v |
| `USER-no-path-guard` — re-apply onto any file | 1 FAILED (133 passed) | CS95w |
| `USER-invalidate-kills-it` — `casemode_invalidate` also drops the user pick | 2 FAILED (132 passed) | CS95u CS95v |
| `FORGET-keeps-the-user-pick` — `forget` calls `casemode_invalidate` | 1 FAILED (133 passed) | CS95s |
| `ATTACH-no-invalidate` — a stale cache survives a re-run | 1 FAILED (133 passed) | CS95q |
| **`WIDGET-dead-command`** — the radio's `-command` → `[list list]` | 2 FAILED (132 passed) | **CS95k2 CS95k3** — *the first cut stayed at 113/113 through this* |
| `MENU-no-postcommand` | 1 FAILED (133 passed) | CS95e0 |
| `SET-engine-never-reached` | 14 FAILED (120 passed) | CS95h CS95i CS95j CS95k CS95k2 CS95n CS95o3 CS95o3b CS95y CS95p **CS95t** CS95u CS95v CS95x2 |
| `SET-leaks-to-current-ctx` — the control also writes the CURRENT ctx's Raw | 1 FAILED (133 passed) | **CS95x3** |
| `SET-no-ctx-loan` — `enter_ctx $token` → `enter_ctx [current_token]` | 1 FAILED (133 passed) | **CS95x2** |

**Every new check has a row.** The two that do not are declared below.

**Unsabotaged — NOT evidence, 16 checks.** Premise/setup: `CS89` (source — a syntax error in `wave_viewer.tcl`
SIGSEGVs before any check prints), `CS90`, `CS90b`, `CS90c`, `CS90q`, `CS90v`, `CS92b`, `CS93`, `CS93b`, `CS93m`,
`CS95h0`, `CS95x` (the schematic window reading the file — `xschem raw read`, C) — the fixture read, engine verbs
items 1–3 own, the viewer opening. Controls: `CS91g` (a name with no tag at all) and `CS90x` (an exact non-ASCII hit,
which needs no fold and therefore agrees under both fold rules — that is the point of a control). Doubly guarded:
`CS94k` (`enter_ctx` refuses the bogus token before the whitelist is reached, so it answers 0 either way). `CS92` is
listed here rather than claimed: it reddens only as collateral of a broken menubar. **`CS94j` is NOT in this list any
more** — the verifier's two-edit mutation of the same guard does redden it.

## 5. What was NOT verified

- **AN EYEBALL IS OWED — hence `[E]`.** Nobody has seen the `Options ▸ Case Mode` cascade. `CS95e0` proves the wiring
  fires and `CS95e`/`CS95j` pin the readout STRING, but whether that ~60-character line reads sensibly in a Tk menu,
  whether the em-dashes render, and whether the radio tick is visible against the ASE theme are pixels.
- **The `@`-shape raws were measured by hand, not by the suite** — the two ngspice runs behind §12's table are
  transcribed into an inline ASCII fixture; no simulator runs during the test. The two-pane **widget** was not
  re-rendered either: the `CS91*` leg drives the parser procs.
- **`raw casemode` on a VCD or `table_read` database still has no committed check.** Item 2 raised it, item 3 passed it
  on, and this item passes it on a **fourth** time — both viewer legs here register two spice raws.
- **The `@`-param classification asymmetry has no issue number** — filed only in §12 and above. It belongs to whoever
  owns the two-pane browser; it is not a case-mode question.
- **Latency, item 4's pointer: NOT measured.** Nothing looked wrong across 15 suites at unchanged counts, but that is an
  absence of a symptom. Item 4's schematic walk per `raw read` remains unmeasured.
- **No valgrind** — no C changed; the Tcl allocates three per-token array entries that `forget` drops (`CS95s`).
- **The override's reach is now a NAMED LIMIT, not a claim.** It governs this window's `xschem raw casemode` answer and
  nothing else; the Ctrl-K / Ctrl-Shift-X senders read the schematic window's Raw and are unaffected (`CS95x2`/`CS95x3`).
  A session-wide mode is the simulator profile's job — item 13.
- **The override is not persisted.** It dies with the window (`CS95s`) and with the process. Deliberate: nothing in
  `DECISIONS.md` asks for it and the profile (item 13) is where a durable statement belongs.
- **`casemode_reapply` was tested through `wviewer::attach_raw`, not through a real simulator re-run.** The path it
  compares is whatever `xschem raw rawfile` reports, and a real ASE re-run overwrites `<rundir>/<cell>_ase.raw` in
  place, so the match is expected to hold — but that specific end-to-end was not driven.
- **Fix-round arithmetic, disclosed:** the check count moved 113 → 134 and the master-red figure 62/48 → 78/56. Anyone
  diffing this receipt against the first cut's numbers should read §0 first rather than assume a transcription error.
