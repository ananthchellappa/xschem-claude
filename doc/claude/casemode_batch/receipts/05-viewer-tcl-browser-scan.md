# 05 — the viewer's Tcl half + the two-pane browser scan

`PLAN.md` §3b item 5 · `DECISIONS.md` **B2a**/**B2b**/**D2** · spec **extended, not re-cut**: `specs/raw_case_mode.md` **§12** (§9's three-residue
paragraph corrected in place). Base `e368d634`, `fluid-editing`, nothing pushed, **no C changed — no rebuild**. Verdict **`[E]`**: the
`Options ▸ Case Mode` cascade is pixels; **two `look` debts recorded**. Item round **plus a fix round of nine confirmed review findings**, one a
blocker (the radios were a dead control); checks moved **113 → 134**. Narrative, both mutation tables verbatim and the transcripts:
**`receipts/05-viewer-tcl-and-browser-scan-annex.md`**.

## 1. Files changed

`src/wave_viewer.tcl` **+528 −46** (the one matcher — `name_rungs`/`name_index`/`name_lookup`/`fold_key` — the per-slot `case` key,
`resolve_signal_db`, the Case Mode control, the override's lifetime) · `tests/headless/test_wave_casemode.tcl` **NEW, 782 lines, 134 checks** ·
`specs/raw_case_mode.md` **+312 −1** (§12) · `specs/mixed_signal_signal_browser.md` **+9** · `code_analysis/ngspice_case_sensitivity.md` **+13**
(the measured `@dev[param]` shapes). Untracked, also committed: this receipt, the annex, and `audit_item05_{closer,fixround,commit}…txt` —
**`_closer` is the implementer's first cut and misnamed**; judge this item by, and roll the baseline to, **`_commit`**.

## 2. Decisions, and the evidence (all written into spec §12)

- **ONE Tcl mirror, and it stays a mirror — it does NOT become `xschem raw index`.** Two reasons, either sufficient: both callers judge a
  **foreign** name list (`raw index` answers for the current database only, so it would need a `raw switch` per candidate), and `validate_rpn` must
  stay callable with **no engine** (`test_wave_viewer.tcl`). Held down by **agreement** instead — the `CS90*` leg reads `raw index` *and* the gate
  for one token and fails on any difference ("refuse everything" reddens 36 checks, "approve everything" 20). **Corrects §9's closing line.**
- **`resolve_signal_db`'s flat `string tolower` is deleted, not ported** — it ignored D2 (first match won) and could not see `distinguish`; each
  slot is now judged by **its own** `case` flag, read while the engine stands on that slot. **Rung 4 is mirrored** (item 2's residue 1, the one
  input where "the rule is `get_raw_index`'s" was false); two traps hit — the C appends nothing after `"i(%s"` (the obvious `"i(…)"` made
  `i(x1.vp))`, found by `CS89d` going red, not by review) and `CS90m` is vacuous without the **bait** column `i(.x1.vp)`.
- **RULING — a D2-poisoned slot is SKIPPED, not a global refusal**; the tie-break is **the first slot that RESOLVES wins** — an exact hit in a foreign database does not beat a folded hit in the one the user stands on (`CS92f`). ⚠ The skip is pinned by **`CS92e2`, NOT `CS92e`**.
- **RULING — the fold key is ASCII-only.** `wviewer::fold_key`, a 26-pair `string map`, because the authority is `raw_fold_key()` →
  `strtolower()` (`util.c:1006`), a `tolower()` loop over **bytes** with no `setlocale` anywhere in `src/`. On `v(CÄ)`+`v(cä)` Tcl's Unicode fold
  invented a D2 collision the engine does not have, and made `resolve_signal_db` skip a slot that resolves.
- **THE DRIVER ADDITION WAS BUILT, NOT PASSED ON.** B2a's first-ranked source is `Options ▸ Case Mode` in the viewer menubar: a disabled readout
  naming the mode **and the source that answered** (B2b), plus `auto`/`fold`/`preserve`/`distinguish` radios, **action-logged** (`CS95y`). Three
  rulings govern it, all in §12:
  - **it writes the EXPLICIT SOURCE ONLY, never `Raw.case_sensitive`**, whose setter **re-reads the file** (`scheduler.c:10697`) — item 3 separated
    reporting from acting on purpose (`CS59e`), and a menubar pick must not silently rebuild a loaded database. Proven by an **in-memory rename**
    (`CS95h0`/`CS95m`/`CS95m2`), the only oracle that tells a re-read of the same file from doing nothing.
  - **resolved on a user action, never on a redraw** (item 3's binding constraint, discharged): the engine is asked only from the cascade's
    `-postcommand` and `set_case_mode`; a **warm cache entry short-circuits it** (`CS95o2`), `set_case_mode` forces past it (`CS95o3b`),
    `attach_raw` **drops** it without recomputing (`CS95q`), `forget` clears all three arrays (`CS95s`).
  - **it survives a re-attach of the SAME file, per window.** `explicit_case_mode` lives on the `Raw` and `ase::attach_dbs` does clear+read, so a
    **re-run silently destroyed the user's setting** and the tick snapped back to `auto` — as the C already refuses to on its own re-read path
    (`keep_explicit`, `scheduler.c:10125`). `casemodeuser($token)` records `{mode path}` and `casemode_reapply` re-applies it path-matched
    (`CS95u`/`CS95v`); a different path gets a fresh detection (`CS95w`); the window's close drops it (`CS95s`).
- **RULING — the override does NOT reach the Ctrl-K senders, and the claim that it did is DELETED.** `hilight_sender_case_mode()`
  (`hilight.c:364`) reads the **schematic** window's `xctx->raw`; the viewer is a separate context with its own, measured by loading one file into
  both and watching the answers diverge (`CS95x2`/`CS95x3`). Not plumbed across — "which Raw is authoritative when a session has several" is not a
  question a menubar can answer, and B1 already puts a session-wide mode on the simulator profile (item 13).
- **The `@dev[param]` audit: it IS handled — the finding is a different one.** Shapes **measured** on `build-ver_50` (`.options savecurrents`):
  `fold` → `i(@r1[i])` / `i(@r.x1.rq[i])`; `preserve` → `i(@R1[i])` / `i(@R.X1.Rq[i])`. The three `@` lines `grep` finds **are** the handling
  (`sig_declass`, `sig_class`, `browser_label`; §12 names them) and **none is case-sensitive**. **NAMED, NOT FIXED:** a **top-level** `@`-param
  has no dots, so the ≥3-segment guard never sees the tag and `sig_declass` classes it `net` — `Show device internals` OFF hides
  `i(@r.x1.rq[i])` and **keeps** `i(@r1[i])` (`CS91h`–`CS91j`). A classification question, not a case one, and out of an empty-diff item's scope.

## 3. Test, checks, RESULT

`tests/headless/test_wave_casemode.tcl` — **NEW**, `CS89`–`CS95y`, **134 checks** (band grepped: `CS0`–`CS64f` in `test_raw_case_mode.tcl`,
`CS65`–`CS88` in `test_hilight_case_senders.tcl`). **74 run true headless**; the viewer legs self-skip with a `NOTE` and nothing prints `SKIP`.
Verbatim, both re-run by the closer on the committed bytes: **`RESULT: ALL PASS (134 checks)`** on `:99`, **`RESULT: ALL PASS (74 checks)`**
`--nogui`. **Master red-before-green** (re-measured on the shipped bytes; the first cut's `62 FAILED (48 passed)` sums to 110 and described an
earlier revision): `wave_viewer.tcl` ← `git show HEAD:` → **`RESULT: 78 FAILED (56 passed)`** on `:99`, **`RESULT: 41 FAILED (33 passed)`**
headless; restored byte-exact (`md5 c23ff09914a0aa22b098e71715ed3023`) → ALL PASS. It also shows the pre-item-5 defect directly: `CS93h` reads
`idx 1 … collide.raw`, the old flat matcher naming a `distinguish` database for a folded query.

**15 suites** via `GUI_GATE=1 run_suites.sh` on `:99` → **`RESULT: 15/15 runs passed`** (wave_casemode 134, raw_case_mode 277,
hilight_case_senders 30, wave_viewer 400, wave_grid 399, ase_cosim 342, the four sigbrowser suites, …; every count listed in the annex) — all
identical to items 2–4's where they overlap. Ten further suites a reviewer ran are 10/10.

**Closer audit** (`GUI_GATE=1 full_audit.sh`, `:99`, **`audit_item05_commit_2026-08-16.txt`**):
`SUMMARY: 319 pass  15 fail  0 crash/timeout  0 skip  (total 334)`. Diffed by test **NAME and STATUS** against
`audit_item04_closer_2026-08-16.txt` (318/15/0/0 of 333) the **entire diff is one added row, `> test_wave_casemode PASS`** — **zero movers in
either direction**; against the fix round's own capture the diff is **empty**. The 15 red names are **identical** to the baseline's by a sorted
name-only diff; `test_wave_markers` (the declared not-ours) is among them, and `test_ase_core` is **PASS in both**, so item 3's carry-forward
naming it a known red is stale. Count rows with `grep -cE '^FAIL +\| +test_'`, never `grep -c '^FAIL'`. There are no movers: the baseline may roll.

## 4. Sabotage — 66 mutations, each on a copy of a byte-exact backup, restored `md5sum`-clean, re-run green

**Every one of the 134 checks appears in exactly one row**; the annex lists the other mutations that redden each and the verbatim `RESULT` line per mutation. All mutations are in `src/wave_viewer.tcl` and **every one restored green** — hence no third column.

| what was broken | went red (and green again after restore) |
|---|---|
| rung 4 deleted · rung 4 gets a trailing `)` (**the bug that really happened**) · unanchored (needs the bait) · guard cut to four chars | CS89d CS89e CS89j CS90k CS90l · CS89f CS90m · CS89g |
| the `v()` wrap rung deleted · the exact rungs deleted · the exact loop sees only rung 1 · the folded rung never answers | CS89b CS89c CS89k CS90n · CS90r CS93e CS93k · CS90t · CS89i CS89v CS93g CS93n |
| a D2 collision also kills the EXACT rung · byte-identical duplicates treated as a collision · the poison never flagged (first-wins) · the `distinguish` suppression removed · the ambiguous message reworded · `db_fuzzy` never folds · always folds | CS89h CS89o CS89p CS89r CS92f2 · CS89q · CS89m CS89n CS92f3 · CS89s CS89t · CS89w · CS90e CS90f CS90h CS90o CS90w · CS90s CS90u |
| **`fold_key` → Unicode `string tolower`** (invents a collision the engine has not) · `name_lookup` refuses everything · approves everything (the agreement oracle, both directions) | CS89x CS89y CS89z CS90y CS90z · CS90d CS90g CS90j · CS89l CS90i CS90p |
| `sig_declass`'s tag regexp lowercase-only · its `@?` dropped · `sig_class`'s `@*` arm · its `srcbranch` arm · `browser_label` keeps the `@` · `sig_type` calls a bare `@name` a current · the per-slot `case` key removed · hardwired 0 · `db_by_index` drops it · `add_trace`'s arm drops the override · `validate_rpn` discards `fuzzy` | CS91 CS91c · CS91i CS91j · CS91b CS91d CS91e · CS91f · CS91h · CS91k · CS92c · CS93c · CS93d · CS93l · CS89u CS93f |
| `resolve_signal_db` never answers · answers slot 0 blind · slots scanned reversed · **back to the flat `tolower`** | CS92d CS92e CS92h CS93i · CS92g · CS92f · CS93h |
| **an ambiguous slot ACCEPTED instead of skipped** (this left the first cut fully green) · the exact rung off · the readout stops naming its source (four single-clause edits) · a no-database raw rendered as `fold` · choices offer `upper`, not `auto` | **CS92e2** · CS92e3 · CS94b CS94c CS94d CS94e CS94g CS95e CS95j · CS94f · CS94 CS94h CS95n |
| `casemode_cached` drops its `info exists` guard · the window guard **and** the ctx loan both removed (two edits) | CS94i · CS94j |
| the cascade widget renamed · no readout entry · radios → checkbuttons · the cascade entry removed · **no `-postcommand`** · the post never sets the tick · `set_case_mode` sends a bad token · never reaches the engine at all · **the control also flips the lookup flag** (the coupling ruled against) | CS95 · CS95b · CS95c CS92 · CS95d · CS95e0 · CS95f · CS95h · CS95k CS95t · **CS95l CS95m CS95m2** |
| **the radio's `-command` → a no-op** — a dead control, through which the first cut stayed 113/113 green · `casemode_refresh` stops caching · stops reading warm · `set_case_mode` stops forcing · `auto` maps to `fold` | **CS95k2 CS95k3** · CS95g CS95r · CS95o2 · CS95i CS95o3 CS95o3b · CS95o CS95p |
| `attach_raw` keeps a stale cache · `forget` leaks the entry · the pick not recorded · `attach_raw` stops re-applying · re-applied onto ANY file | CS95q · CS95s · CS95u CS95v · CS95u CS95v · CS95w |
| the `enter_ctx` loan dropped (writes the wrong Raw) · the control ALSO writes the current ctx's Raw · the `log_action` line deleted | CS95x2 · CS95x3 · CS95y |

**Unsabotaged — NOT evidence, 16 checks.** Premise/setup, all engine verbs items 1–3 own plus the fixture read and the viewer opening: `CS89`
(sourcing the file — a syntax error there SIGSEGVs before any check prints), `CS90`, `CS90b`, `CS90c`, `CS90q`, `CS90v`, `CS92b`, `CS93`, `CS93b`,
`CS93m`, `CS95h0`, `CS95x`. Deliberate controls: `CS91g` (a name with no class tag), `CS90x` (an exact non-ASCII hit, needing no fold, so it agrees
under either fold rule). Doubly guarded: `CS94k`. `CS92` reddens only as collateral of a broken menubar and is listed, not claimed.

## 5. What was NOT verified

- **AN EYEBALL IS OWED — hence `[E]`; TWO `look` debts are in the ledger.** (1) the cascade itself: whether the ~60-character readout reads
  sensibly in a Tk menu, whether the em-dashes render, whether the tick shows against the ASE theme. (2) the fix round's new behaviour: the radios
  were a dead control until now, so nobody has seen clicking one move the readout, and the tick surviving a re-run is new. Suite debts unchanged.
- **Reviewers: nine confirmed findings across three lenses, all fixed** — the dead radio `-command` (blocker); the override lost on re-attach;
  `CS92e` not pinning the D2 skip; a cache with no reader; a stale master-red figure; no `log_action`; the non-ASCII fold divergence; five
  unguarded `resolve_signal_db` calls (A/B: inline → **0 `RESULT` lines**, hoisted → `RESULT: 9 FAILED`); the false Ctrl-K claim. **Nothing was
  raised-but-unconfirmed.**
- **Reviewer not-proven, carried.** Nobody could break the mirror: 84 + 33 adversarial tokens × two modes against a live engine gave **zero**
  disagreements with `xschem raw index`, so "identical to `get_raw_index`" is unrefuted, not proven; and no second mishandled `@` shape was found,
  in either direction. Measured, not filed: the new per-slot index costs 1.4×–1.7× the old flat list (3.8 ms at 5000 names) on a path reached only
  after the current database has refused; and a D2-poisoned *current* database now lets a *different* one satisfy the trace — this item's own
  tie-break, better than the pre-item-5 answer (issue **0418**'s all-zero column), but disclosed nowhere else.
- **The `@`-shape raws were measured by hand, not by the suite** — transcribed into an inline ASCII fixture, no simulator in the loop — and the
  two-pane **widget** was never re-rendered by anyone; `CS91*` drives the parser procs. **The `@`-param classification asymmetry has no issue
  number**; it belongs to the two-pane owner.
- **`casemode_reapply` was driven through `wviewer::attach_raw`, not a real simulator re-run** (a real ASE re-run overwrites
  `<rundir>/<cell>_ase.raw` in place, so the path match should hold). The override is **not persisted** — deliberately; item 13 owns durability.
- **`raw casemode` on a VCD or `table_read` database still has no committed check** — passed on for a **fifth** time. **Item 4's latency pointer
  is still unmeasured** (one schematic walk per `raw read`): nothing looked wrong across 19 suite runs at unchanged counts, which is an absence of
  a symptom, not a measurement. **No valgrind** — no C changed. Untracked `tr_MODE.raw` and `tests/headless/.scratch/0211` **predate this item**.
