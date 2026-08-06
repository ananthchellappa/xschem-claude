# Item 16 — docs, guide rows, issue closure

**Verdict: `[x]` — DONE** (`24c491cd`). Docs-only, no `src/` change, 86 checks added, 4 sabotages run and
reverted. The item's own scope text contained **two measurably wrong instructions**; both
were caught by the scout, re-measured by me from source, and are recorded below rather than
executed.
See **§12** for the ledger-stage record (written after the commit landed and after the
adversarial verifier: independent re-runs, the verifier's own three unnamed sabotages, and
the two questions left for the driver).

---

## 1. Files touched

| file | what |
|---|---|
| `doc/claude/specs/waveform_signal_browser.md` | **NEW**, 898 lines, 16 sections. The deliverable. |
| `doc/waveform_viewer_guide.html` | new **§11 The Signal Browser** (7 subsections, a `data-bseq` gesture table); Troubleshooting 11→12; See also 12→13 + a spec pointer as **text** |
| `doc/claude/issues/0214-readonly-is-cleared-on-a-failed-load.md` | **NEW** |
| `doc/claude/issues/0215-hierarchy-sync-is-asymmetric-between-items-11-and-12.md` | **NEW** |
| `doc/claude/issues/0216-attach-raw-bypasses-the-raw-history.md` | **NEW** |
| `doc/claude/issues/0186-...md` | two stale facts corrected (§4) |
| `references/viva_cadence_waveform_viewer.md` | §13 item 1 back-pointer |
| `tests/headless/test_wave_grid.tcl` | GH8/GH9/GH10 + GS0-GS3, **86 new checks** |
| `doc/claude/signal_browser_batch/PLAN.md` | item 16 ticked |

**No `src/` change. No build run** (none needed — nothing compiled changed).

---

## 2. ⚠ THE ITEM'S SCOPE TEXT WAS WRONG TWICE, and executing it literally goes GREEN IN THE WRONG DIRECTION

### 2.1 "a `data-seq` row per new key/gesture" is a **NO-OP**. Item 16 added ZERO.

Re-measured from source at HEAD, not taken from the scout:

| thing | source | guide | GH0 literal |
|---|---|---|---|
| `bind WaveViewer <...>` in `install_default_binds` | **16** | 16 `data-seq` rows | `16` ✓ |
| `-accelerator` in `build_menubar` | **11** | 11 `data-menu`/`data-accel` pairs | `11` ✓ |

(⚠ a naive `awk '/^proc .../,/^}/' | grep -c accelerator` gives **13**. `wvproc_body` strips
comment lines, and two of the thirteen are comments naming the very option being counted.
The test is right; the naive grep is not. Measured both ways before trusting either.)

Item 8 already wrote the `Control-Key-l` row; item 11 already wrote the `Key-E` row.
**There was no new key or gesture on the `WaveViewer` tag left to document.**

And bumping the literals is not merely unnecessary, it is **forbidden by a shipped check**:
`tests/headless/test_wave_sigbrowser_i12.tcl` BX13 pins `16`/`11` as literal regexps over
`test_wave_grid.tcl`'s own source, and pins `data-seq="Control-Key-5"` == 0. So the
predictable failure mode of this item was: add a Ctrl-5 row, bump GH0 to 17/12,
**`test_wave_grid` goes GREEN and `i12` goes RED in a file item 16 is not told to run.**
Run plan step 4 exists to catch exactly that; it was run, and i12 is green (§5).

**Ctrl-5 is documented in the guide as PROSE ONLY** (§11.5). No `data-*` attribute.

### 2.2 The new machine-readable attribute, and the collision that was checked not assumed

The browser's six gestures are on the **sidebar's own widgets** inside `browser_build`, not
on the `WaveViewer` tag, so they cannot go in §9.1 and cannot use `data-seq`. They use
**`data-bseq`**, verified non-colliding: GH0's extractor is the unanchored
`data-seq="([^"]+)"`, and `data-bseq="` does not contain the substring `data-seq="`.
**Verified as a measurement** — after the edit, `grep -c 'data-seq="'` is still **16**,
`data-menu` **11**, `data-accel` **11**, `data-bseq` **6**.

### 2.3 The section number: §11, not §9, and the reason is measured

Inserting the browser at §9 (the natural reading position, after "8. Saving and reloading")
renumbers **13 of the 15** in-text `§N` references. Inserting it as **§11**, pushing
Troubleshooting→12 and See also→13, costs **ZERO** — measured: no `§11` or `§12` reference
existed anywhere in the file. All `id=` anchors are untouched either way, and there is no
TOC and no `href="#trouble"` / `href="#seealso"` anywhere. Took §11.

GH10 (§3) is the standing guard so the next person can renumber safely.

### 2.4 ⚠ The guide must NOT `href` the spec

`doc/Makefile` installs `*.svg *.html *.css *.png` from `doc/` only. `doc/claude/` is **not
installed**. An `href="claude/specs/waveform_signal_browser.md"` resolves in the repo — so
a `file isfile` check of GH7's shape would go **green** — and is a dead link in every
installed tree. The spec is referenced **by path, in text**, in §11's intro and in See also.

---

## 3. The spec — what it captures that exists nowhere else

898 lines, 16 sections. Driver note (a)'s bar was "a spec that restates the ViVA feature
list and omits the measured corrections is a FAILURE even if every check is green." The
sections that carry the batch's hard-won knowledge:

* **§3.5 — ViVA's unit-collision rule is PERMANENTLY NOT IMPLEMENTABLE.** `read_dataset`
  discards ngspice's per-var type; xschem has no unit metadata at all. Stated as a permanent
  divergence, not a TODO, with the pointer to where a real fix would have to start.
* **§4 — the legacy `.graphdialog` exception (ruling 16)**, with delta 3 (ARE directors /
  `(?i)x` become an error) written out as **inherent to wrapping the user's pattern at all**,
  and an explicit "do not file this as a bug".
* **§6 — the sidebar width is a DERIVATION, not 583 px.** Driver-flagged risk, honoured:
  583/1400/42%/45% appear as *the measurement that demonstrated the rule*, never as the
  rule. Includes D8 and the observation that the geometry defect and the
  "the binding does not fire" symptom **were the same defect** — Tk would not deliver a
  synthetic `<KeyRelease>` to the clipped entry.
* **§10 — HIERARCHY SYNC**, the mandated section with no upstream doc. All six of the
  driver's points, each as a measurement:
  1. the `sim_sch_path` table (currsch 2, `sch_path` `.X1.X2.`, raw_level 0/1/2 →
     `X1.X2.` / `X2.` / ``),
  2. **§10.2 THE ARM NO TEST CAN REACH** — with no raw the two getters are byte-identical,
     which is *why* the decision-10 guard is a source check and *why* item 11's plan-named
     sabotage did not fire until the fixture was given a raw,
  3. the trailing dot / empty-at-root normalisation,
  4. **case: exact-first + `-nocase` retry is NECESSARY BUT NOT SUFFICIENT** — the final
     verify must also be `-nocase`, with the reproduced
     `CASE hgo x1.x2 -> {err {verify failed} {}}`, and the byte-exact `hier_common` /
     `-nocase` `hier_same` split with the reason each is what it is,
  5. **readback, never `catch`** — `descend -inst` returns the string `0` without throwing;
     `go_back` returns void and does not ascend on a cancelled save prompt,
  6. vector slices (0212), rollback, and **§10.7 the items-11/12 ASYMMETRY recorded as a
     known limit and not papered over**.
* **§11 — the All-DBs `here`-tracking bug**, recorded with the sentence that matters:
  *"a check that had only counted the entries would have gone green."*
* **§14 — every declared limit in one table**, 17 rows, each with its section and its issue
  number where one exists.
* **§16 — ruling 30's measured rule** (489 checks → killed ~90% of the time with **zero**
  check failures) and the transferable lessons 17/22/23/25/26/28/29.

---

## 4. Issues

Next free number was **0214** (the directory ended at 0213). Three filed:

* **`0214-readonly-is-cleared-on-a-failed-load.md`** — **not discretionary.** PLAN.md's
  Deferred block assigns it to item 16 explicitly, and 0186 said it was unfiled.
  `xctx->readonly = 0` in `load_schematic`'s `reset_undo` arm runs **before** the fopen
  test, so **any** read-only buffer whose file has vanished comes back writable — measured
  under `--nogui`, so **not viewer-specific**. Needs C ⇒ filed, not fixed (decision 8).
  ⚠ Anchors are written as **grep-able phrases, not line numbers** (ruling 21) — the
  `readonly = 0; /* default editable` reset, the `if( fd == NULL) {` preceding the
  `unable to open file` fprintf, and the failure-path `clear_drawing()`.
* **`0215-hierarchy-sync-is-asymmetric-between-items-11-and-12.md`** — judgement call,
  offered by receipt 12 §13 row 8 and named by driver note (b). Carries the reason **both
  halves are individually correct**, and the warning that a fix must keep the guard,
  because the failure it prevents *reports success*.
* **`0216-attach-raw-bypasses-the-raw-history.md`** — judgement call, offered by receipt 13
  as a follow-up. Carries why "just call the other one" is not the fix (the two paths
  deliberately differ on `raw clear`).

**0186 edited, two stale facts:**
1. `:53-54` said the readonly defect "is still unfiled. Next free issue number is **0212**"
   — both clauses false. Replaced with a pointer to 0214 plus the batch's full issue
   ledger and decision 13.
2. the drifted anchor `src/xschem.tcl:13074` → **`:13155`** (re-verified: `:13074` is now
   `proc toolbar_show`; the only bare `xschem reload` in that file is `:13155`;
   `action_registry.tcl:183` is still exact).

Everything else in 0186 already reflected what the batch learned — item 0 wrote the
raw-survives / no-Tk-widget-freed / hangs-on-the-modal paragraphs — so driver note (b)
needed no further work there.

---

## 5. Checks and suites

| run | result |
|---|---|
| `test_wave_grid` `--nogui`, **before** any edit | **126 passed / 0 failed** (the baseline) |
| `test_wave_grid` `--nogui`, after | **212 / 0** — **+86** |
| `test_wave_grid` under DISPLAY (`run_suites.sh`) | **337 / 0** (the GG block runs too) |
| `test_wave_sigbrowser_i12` under DISPLAY | **92 / 0** — BX13 still green with the guide edited |
| `test_wave_sigbrowser_i12` `--nogui` | 29 / 0 |

### The 86 new checks

* **GH8 / GH9 — the browser's own gestures, doc ↔ source, BOTH directions.** The direct
  analogue of GH1/GH2, i.e. squarely "extending the row assertions". `wvproc_body
  wviewer::browser_build` is the source side; `data-bseq` is the doc side. Carries a
  **positive-extraction control** (`llength == 6`) for the same reason GH0 carries one:
  without it every per-row leg is vacuously green on a guide whose table was deleted, and
  it distinguishes "one row removed" (5) from "nothing parsed" (0).
* **GH10 — every prose `§N` names a real heading in the same file.** Self-defence for the
  renumber I made. ⚠ **Its claim is narrowed in the check comment** (ruling 17): it pins
  prose↔heading *consistency inside one file*, and explicitly **not** that the numbering is
  right for a reader, nor that a §-ref points at the *topic* it claims.
  ⚠ The heading regexp needed care: the obvious `>([0-9]+(?:\.[0-9]+)?)\.` extracts **`9`**
  from `<h3>9.1 Viewer keys` (it backtracks to satisfy the trailing `\.`), which would have
  made every `§9.1` ref fail. `\.?\s` instead. Caught by running it, not by reading it.
* **GS0-GS3 — the spec ↔ source oracle. DECLARED SCOPE EXTENSION** (see §7). Only
  contract-list lines (`^- \`wviewer::name\``) are read, never a prose mention. Both
  directions: 29 GS1 legs (spec → source) and 23 GS2 legs (source → spec, so a spec that
  simply *stopped naming things* cannot pass). GS3 checks every
  `doc/claude/issues/NNNN-` the spec cites resolves to exactly one file.
  ⚠ The scout's `[string first "\nproc wviewer::$n "]` needs a trailing space and would
  false-fail on a future `proc wviewer::foo {}`. Used `regexp "\nproc wviewer::${n}\\s"`.

---

## 6. Sabotage table — four, every one INJECTED AND RUN (ruling 29), never reasoned about

Driver note (d) is the reason all four exist: the named sabotage is a **negative**, and this
batch caught five vacuous checks of that shape.

| # | injection | predicted | **MEASURED** | verdict |
|---|---|---|---|---|
| **S1** | delete the whole `<tr data-seq="Key-E" ...>` row from §9.1 (guide `:491-508`) | 2 | **4** — GH0 seqs `16→15`, GH0 menus `11→10`, GH2, GH4 | ⚠ **SUPERSET, DECLARED** (§6.1) |
| **S2** | delete one `data-bseq` **attribute**, leave the row's prose | 2 | **exactly 2** — GH8 count `6→5`, GH9 | ✅ as predicted |
| **S3** ⭐ | point one `data-bseq` at a sequence that is **not bound** (`tvf.tv <Button-1>`) | 1 | **exactly 1** — GH8's per-row leg for that value; counts stayed **6/6** so GH8-count and GH9 stayed **green** | ✅ **the one that mattered** |
| **S4** | rename one spec contract entry to `wviewer::nosuchproc` | 1 | **exactly 1** — that GS1 leg | ✅ as predicted |

Each was reverted and re-run: **212/0** after every one.

### 6.1 ⚠ S1's superset, reported rather than hidden (ruling 23)

The plan's sabotage — "remove one new `data-seq` row" — **could not be run as written**,
because item 16 adds none. Re-aimed at the `Key-E` row item 11 added, and it over-fired:

* **4 legs in `test_wave_grid`, not 2.** The predicted GH0-seq and GH2 fired; GH0-menus and
  GH4 fired too, because that row is a **menu-twin** row carrying `data-menu`/`data-accel`
  as well. Legitimate — those two legs *should* notice a missing menu twin.
* **plus 1 leg in a different file.** `test_wave_sigbrowser_i12.tcl` BX13's control leg
  (`data-seq="Key-E"` must be `1`) fails, exactly as declared. Run and confirmed:
  `28 passed, 1 failed`, that leg and no other.

**What S1 nonetheless proves, and it is the point:** GH0 reported **15**, not 0. The
extraction still worked and the fifteen surviving rows still passed their GH1 legs — so
GH0/GH2 genuinely distinguish *"one row absent"* from *"the attributes were stripped"* from
*"the file did not parse"*. That is the positive control driver note (d) demanded.

### 6.2 Why S3 was the necessary one

GH8's doc→source direction is exactly the shape of the vacuous check this batch caught five
times: a count-only check (`6 rows exist`) is **an assertion the guide makes about itself**.
S3 leaves the counts untouched at 6/6 and changes only *what one row claims*. It produced
**exactly one failure**, which is the only available evidence that GH8 reads
`browser_build` rather than the guide. Had it produced zero, GH8 would have been worthless
and would have needed redesigning.

### 6.3 Revert discipline

The item was uncommitted throughout, so `git checkout -- doc/waveform_viewer_guide.html`
would have **discarded the whole item's guide work**. Pristine copies were taken to the
scratchpad before the first sabotage, and a **post-item / pre-sabotage** snapshot as well;
every revert was a copy-back + `diff -q` + a clean re-run, never a `git checkout`.

---

## 7. Divergences from the item text, all declared

1. **ZERO `data-seq` rows added** where the scope text said "a row per new key/gesture".
   §2.1 — the instruction was a no-op and executing it literally would have turned a
   different file red.
2. **S1 re-aimed and its superset declared.** §6.1 — the named sabotage was unrunnable as
   written.
3. **Three issues filed, not "one per `[D]`".** 0214 is **not** discretionary (PLAN.md's
   Deferred block assigns it explicitly and 0186 said it was unfiled); 0215 and 0216 are
   judgement calls, both named by driver note (b) and both offered by the receipts that
   found them. Presented as such.
4. **GS0-GS3 is a genuine SCOPE EXTENSION**, flagged so the driver can veto it without
   failing the item. Note (f) allows "test-logic changes beyond extending
   `test_wave_grid.tcl`'s row assertions" only for the row assertions; GH8/GH9 *are* row
   assertions and GH10 is self-defence for a change I made, but **GS0-GS3 is new coverage
   of a new file**. Justification: the guide's own GH block exists because
   `ase_l_tutorial.html`'s tables went stale, and its comment says an unchecked doc table is
   worse than none. The spec is now the batch's **only durable record** and deserves the
   same oracle. It is 55 of the 86 checks; deleting the `GS*` block is a clean revert.
5. **Section inserted at §11, not §9.** §2.3 — zero prose renumbers vs thirteen.
6. **The guide references the spec as text, never as an `href`.** §2.4.

---

## 8. Full audit — **NON-BASELINE FAILS: NONE**

`tests/headless/full_audit.sh`, one run:
**`SUMMARY: 270 pass  17 fail  0 crash/timeout  1 skip  (total 288)`**

**288 = the 283-case baseline + the five browser cases** (`_i11`, `_i12`, `_i1315`, `_i14`,
item 15's; `wvbs_common.tcl` is correctly not a case). Compared as **SETS, not counts**:

| the run's 17 fails | verdict |
|---|---|
| 15 of the 16 HARD-baseline names | expected |
| `test_fluid_editing` — **PASSED** | the baseline's own documented exception ("sometimes PASSES") |
| `test_wave_trace_menu` | **FLAKY (~50%), on the list.** Re-measured 3×: 1 pass / 2 fail, and the failing leg both times is **TG9 root-coords**, itself a documented WSLg flake ("4-in-10 on a PRISTINE tree") |
| `test_wave_viewer` | ⚠ **NOT on either list — investigated, and it is NOT a fail.** See below |

### ⚠ `test_wave_viewer`, and why the audit's verdict on it is not a measurement

The audit log contains **`X connection to :0 broken (explicit kill or server shutdown)`
twice** — the known WSLg Xwayland abort. Per the baseline rule, *a run containing it is not
a measurement*, so I located which tests it landed in rather than reading the verdict:
the two occurrences terminate the captured output of **`test_wave_trace_menu`** and
**`test_wave_viewer`**. The X server died under them; both were killed, not failed.

Re-measured under a live server through `run_suites.sh -n 3`:

```
PASS | test_wave_viewer        run 1/6   ALL PASS (400 checks)
PASS | test_wave_viewer        run 3/6   ALL PASS (400 checks)
PASS | test_wave_viewer        run 5/6   ALL PASS (400 checks)
```

**3/3, 400 checks each.** `test_wave_viewer` is green; its audit verdict was an artefact of
the server dying mid-test.

`test_wave_grid`, `test_wave_sigsearch`, `test_wave_sigbrowser` and all four
`_i11/_i12/_i1315/_i14` files **PASSED in the audit** — i.e. every suite this item touches
or could plausibly touch is green in the same run.

Nothing this item changed can reach any of the 16 HARD names: the item edits three documents
and adds source-level legs to one test file, and makes **no `src/` change at all**.

## 9. Gating

The 8-hour authorization had **expired** (`allow_until` was ~3 minutes in the past when I
checked it against `date +%s`). Normal gating applied in full and was honoured: every
DISPLAY run went through `tests/headless/run_suites.sh` / `full_audit.sh`, **`GUI_GATE=0`
was never set**, no gate file was hand-written, no bare loop over `./src/xschem`, and
`wsl --shutdown` was never run. The `--nogui` arm — which covers **every one of the 86 new
checks**, all of them source-level — is ungated, which is why the sabotage cycle cost the
panel nothing.

## 10. If a human looks at one thing

`doc/claude/specs/waveform_signal_browser.md` **§10** (hierarchy sync). It is the only
record of that algorithm anywhere, ViVA has no equivalent to fall back on, and §10.2 —
*with no raw loaded the two getters are byte-identical, so no test can distinguish
decision 10 on that arm* — is the fact that makes the whole feature's guard structure make
sense. Everything else in the batch has a receipt and a test; that section has only this
document.

---

## 11. Ledger

Commit **`24c491cd`** — `docs(wviewer): signal browser spec, guide, issues`.
7 files, +1451 / -5. **Not pushed.**

Staged as an explicit list (no `git add -A`, no `commit -a`):

```
doc/claude/specs/waveform_signal_browser.md            (new, 898)
doc/waveform_viewer_guide.html                         (+227)
doc/claude/issues/0214-readonly-is-cleared-on-a-failed-load.md            (new)
doc/claude/issues/0215-hierarchy-sync-is-asymmetric-between-items-11-and-12.md (new)
doc/claude/issues/0216-attach-raw-bypasses-the-raw-history.md             (new)
doc/claude/issues/0186-...md                           (+15/-5)
tests/headless/test_wave_grid.tcl                      (+109)
```

**Deliberately NOT committed, left for the driver's ledger commit:**

* `doc/claude/signal_browser_batch/PLAN.md` — item 16 ticked, but the file arrived
  **already dirty** with the driver's bookkeeping; committing it would sweep that in.
* `doc/claude/signal_browser_batch/receipts/16_receipt.md` — this file. Items 8-15 left
  their receipts untracked for the ledger (`3e526f86`, item 15, is `src/` + test only);
  same convention followed.
* ⚠ **`references/viva_cadence_waveform_viewer.md` — THE EDIT IS MADE ON DISK BUT CANNOT
  BE COMMITTED.** The whole `references/` tree is untracked in this repo (884 KB, carrying
  `:Zone.Identifier` droppings), so `git add` there would import the entire directory.
  The §13-item-1 back-pointer is written and reads: *"SHIPPED as the Signal Browser …
  The as-built contract, the divergences from this entry and the measured corrections are
  `doc/claude/specs/waveform_signal_browser.md`"*, plus the one divergence that cannot be
  ported at all (the unit-collision rule). **Flagged for the driver**, since the item asked
  for it and the repo's own convention prevents committing it.

---

## 12. Ledger-stage record (post-commit, post-verifier)

Written by the ledger stage after the adversarial verifier returned
`ok: true`, `scopeClean: true`, `nonBaselineFails: []`.

### 12.1 Verdict

**`[x]` DONE.** Docs-only item; no `src/` change, no build. **No eyeball-queue row**
— the driver assigned none (the guide/spec/issues are text, and the one pixel-adjacent
fact in the spec, the sidebar width, is written as a *derivation*, never as a number).
**Not pushed** — batch convention (`review-commit-dont-push`).

### 12.2 Commit(s)

| commit | subject | contents |
|---|---|---|
| **`24c491cd`** | `docs(wviewer): signal browser spec, guide, issues` | 7 files, **+1451 / -5**. Verified by the verifier with `git show --stat`: all 7 in scope, **no `src/`, no C, no scope leak.** |

No other commit belongs to item 16.

### 12.3 Files touched

**Committed in `24c491cd` (7, staged as an explicit list — no `git add -A`, no `commit -a`):**

| file | change |
|---|---|
| `doc/claude/specs/waveform_signal_browser.md` | **NEW**, 898 lines, 16 sections — the batch's only durable record |
| `doc/waveform_viewer_guide.html` | **+227** — new §11 "The Signal Browser" (7 subsections, `data-bseq` gesture table); Troubleshooting 11→12; See also 12→13 |
| `doc/claude/issues/0214-readonly-is-cleared-on-a-failed-load.md` | **NEW** |
| `doc/claude/issues/0215-hierarchy-sync-is-asymmetric-between-items-11-and-12.md` | **NEW** |
| `doc/claude/issues/0216-attach-raw-bypasses-the-raw-history.md` | **NEW** |
| `doc/claude/issues/0186-viewer-context-destroyed-by-reload-and-inplace-loads.md` | **+15 / -5** — two stale facts corrected (§4) |
| `tests/headless/test_wave_grid.tcl` | **+109** lines, **+86 checks** |

**Edited on disk, deliberately NOT committed (3) — for the driver, not defects:**

* `references/viva_cadence_waveform_viewer.md` — the §13-item-1 back-pointer **is written**
  (verifier confirmed the text is there) but **cannot be committed**: `git ls-files
  references/` is **empty**, i.e. the whole 884 KB tree is untracked, so `git add` there
  would import the entire directory (`:Zone.Identifier` droppings included).
* `doc/claude/signal_browser_batch/PLAN.md` — item 16 ticked; the file **arrived already
  dirty** with the driver's bookkeeping, so committing it would sweep that in.
* `doc/claude/signal_browser_batch/receipts/16_receipt.md` — this file, left for the ledger
  commit, matching items 8-15 (item 15's `3e526f86` is `src/` + test only).

### 12.4 Test file and check counts

**File: `tests/headless/test_wave_grid.tcl`** (extended; no new test file).

| measurement | value | who measured it |
|---|---|---|
| checks **before** the item, `--nogui` | **126** | implementer, then **independently re-derived by the verifier**: it swapped `git show 3e526f86:tests/headless/test_wave_grid.tcl` into place, ran it (126), and restored from a pristine copy |
| checks **added** | **+86** | confirmed by that swap, not by arithmetic |
| checks **total**, `--nogui` | **212 / 0** | both |
| checks **total**, under `DISPLAY` via `run_suites.sh` (the `GG` block runs too) | **337 / 0** | both |
| `test_wave_sigbrowser_i12` with the edited guide | **92 / 0** DISPLAY, **29 / 0** `--nogui` (BX13 green) | both |

Breakdown of the 86: **GH8/GH9** (browser gestures, doc ↔ `browser_build`, both directions),
**GH10** (every prose `§N` names a real heading), **GS0-GS3** (the spec ↔ source oracle,
**55 of the 86** — the declared scope extension, §12.7 item 4).

### 12.5 Sabotage table — implementer's four, each INJECTED AND RUN

| # | injection | predicted | measured | **failedExactly** | **reverted** |
|---|---|---|---|---|---|
| **S1** | delete the `<tr data-seq="Key-E" …>` row from guide §9.1 (the PLAN's sabotage **re-aimed**, ruling 23 — item 16 adds no new `data-seq` row, so it was unrunnable as written) | 2 | **4** in `test_wave_grid` (GH0 seqs 16→15, GH0 menus 11→10, GH2, GH4) **+ 1** in `test_wave_sigbrowser_i12` (BX13's `Key-E` control leg: 28 passed / 1 failed, that leg and no other) | **NO — superset, DECLARED** (§6.1). The two extra legs are legitimate: the row is a **menu twin**, and GH0-menus/GH4 *should* notice a missing twin. Proves what it needed to: GH0 reported **15, not 0**, and the 15 survivors still passed their GH1 legs — so GH0/GH2 distinguish *one row absent* from *attributes stripped* from *file did not parse* | **yes** |
| **S2** | delete one `data-bseq` **attribute**, leave the row's prose | 2 | **2** — GH8 count 6→5, GH9 (6 binds vs 5 rows); the 5 surviving per-row legs stayed green (positive control on the same fixture) | **yes** | **yes** |
| **S3** ⭐ | point one `data-bseq` at a sequence that is **not bound** (`tvf.tv <Button-1>`); counts left at 6/6 | 1 | **1** — GH8's per-row leg only; GH8-count and GH9 stayed **green** | **yes** | **yes** |
| **S4** | rename one spec contract entry to `wviewer::nosuchproc` (deliberately `sig_bare`, which is **not** on GS2's want-list, so GS2 would not also fire) | 1 | **1** — that GS1 leg | **yes** | **yes** |

**S3 is the load-bearing one.** GH8's doc→source direction is the exact shape of the vacuous
check this batch caught five times: a count-only check is an assertion the guide makes about
itself. S3 changes *what one row claims* while leaving the counts at 6/6 — one failure is the
only evidence GH8 reads `browser_build`. Zero would have meant redesigning GH8.

Revert discipline: the item was uncommitted throughout, so `git checkout --` would have
discarded the whole item. Pristine + pre-sabotage copies were taken to the scratchpad;
every revert was copy-back + `diff -q` + a clean **212/0** re-run.

### 12.6 The verifier's own sabotages (unnamed by the implementer) — three, all fired exactly

The verifier deliberately attacked the **source side**, the direction the implementer never
tested (S1-S4 all edited a *document*):

| # | injection | outcome | what it proves |
|---|---|---|---|
| **V1** | add a 7th `bind $f.tvf.tv <Key-Q>` to `browser_build` in `src/wave_viewer.tcl` | **exactly 1 failure** — GH9 (7 vs 6); 211 passed | GH9 reads `browser_build`'s **source**, not the guide's self-description. The implementer only ever deleted guide rows |
| **V2** | renumber `<h3 id="ref-graph-keys">9.3` → `9.8` in the guide | **exactly 1 failure** — "GH10 the guide's §9.3 names a real heading" | GH10 catches the renumber rot it was written to defend against — the risk item 16 itself created by inserting §11 |
| **V3** | rename `proc wviewer::hier_now` in `src/wave_viewer.tcl` | **exactly 1 failure** — "GS1 the spec's `wviewer::hier_now` exists in `src/wave_viewer.tcl`" | GS1 reads the **source** (the mirror of S4, which only edited the spec side) |

All three reverted from pristine copies; `git status --porcelain src/
doc/waveform_viewer_guide.html doc/claude/specs/ tests/headless/test_wave_grid.tcl` **empty**
afterwards, clean re-run **212/212 ALL PASS**.

**Independent verification beyond sabotage** (the verifier re-ran, it did not read):
GH0's literals re-measured from source with a `tclsh` replica of `wvproc_body`
(**16** `bind WaveViewer`, **11** `-accelerator`, **6** `bind $f.`; guide 16 / 11 / 6 —
`data-bseq` provably does not collide with GH0's unanchored `data-seq="` extractor);
BX13 read directly and confirmed to **forbid** bumping 16/11, so divergence 1 is *forced,
not optional*; **all 27** proc signatures named in spec §5 grep-confirmed against
`src/wave_viewer.tcl` with matching argument lists; `hier_now` confirmed to read
`sim_sch_path` and **no** hier proc to read `sch_path` (decision 10 honoured);
0214's mechanism confirmed in `src/save.c` (`xctx->readonly = 0` at :3734 inside the
`reset_undo` arm opened at :3731, `fopen` NULL test at :3810 — clear-then-discover) and its
printed grep anchor confirmed to work; 0216's mechanism confirmed (`rawhist_push` called at
exactly one site, :6426 inside `rawbar_load`; `attach_raw` at :2690 never pushes);
`doc/Makefile` confirmed to install `*.svg *.html *.css *.png` from `doc/` and `xschem_man/`
**only**, with zero `href="*claude*"` in the guide; the §11 placement confirmed to delete
**exactly 2** lines with no `#trouble`/`#seealso` anchor anywhere and GH10 green across all
14 unique prose §-refs.

### 12.7 Divergences from the PLAN, each with its reason

1. **ZERO `data-seq` rows added**, where the scope text said "a `data-seq` row per new
   key/gesture". *Reason:* the instruction is a **no-op** — `install_default_binds` has 16
   `bind WaveViewer` and `build_menubar` 11 `-accelerator`, exactly matching GH0's literals
   and the guide's existing 16/11 rows; items 8 and 11 had already written the only new rows
   (`Control-Key-l`, `Key-E`). Worse, executing it **turns `test_wave_grid` GREEN and
   `test_wave_sigbrowser_i12` BX13 RED** in a file item 16 is not told to run. Ctrl-5 is
   documented as **prose only**. *Verifier: confirmed from source and from BX13's text —
   forced, not optional.*
2. **The browser's six widget gestures use a NEW attribute `data-bseq`, not `data-seq`.**
   *Reason:* they are bound on the sidebar's own widgets inside `browser_build`, not on the
   `WaveViewer` tag, so they cannot live in §9.1. Non-collision with GH0's unanchored
   extractor was **verified as a measurement**, not assumed (16 / 11 / 11 / 6 after the edit).
3. **S1 re-aimed, and its superset declared** (ruling 23) — the PLAN's sabotage was
   unrunnable as written. §12.5.
4. **GS0-GS3 (55 of the 86 checks) is a DECLARED SCOPE EXTENSION** beyond driver note (f)'s
   "extending `test_wave_grid.tcl`'s row assertions" — GH8/GH9 *are* row assertions and GH10
   is self-defence for the renumber, but **GS\* is new coverage of a new file**. *Reason:* the
   GH block exists because `ase_l_tutorial.html`'s tables went stale, and its own comment says
   an unchecked doc table is worse than none; the spec is now the batch's only durable record.
   Flagged so the driver can **veto without failing the item — deleting the `GS*` block is a
   clean revert.**
5. **Guide section inserted at §11, not the natural §9.** *Reason, measured:* §9 renumbers
   **13 of the 15** in-text §-refs; §11 (pushing Troubleshooting→12, See also→13) renumbers
   **zero**. No TOC, no `href="#trouble"`/`#seealso"`.
6. **The guide references the spec as TEXT, never an `href`.** *Reason:* `doc/Makefile`
   installs `*.html` from `doc/` but **not** `doc/claude/`, so a link would resolve in-repo
   (going green under a `file isfile` check of GH7's shape) and be **dead in every installed
   tree**.
7. **THREE issues filed, not "one per `[D]`".** *Reason:* **0214 is not discretionary** —
   PLAN.md's Deferred block assigns it to item 16 explicitly and 0186 said it was unfiled.
   0215 and 0216 are judgement calls, both named by driver note (b) and both offered as
   follow-ups by the receipts that found them.
8. **The spec's line-number citations were converted to grep-able phrases** (ruling 21) after
   verifying all five were exact today (`xschem.tcl:4469/4478/4801`, `save.c:593`,
   `ase_window.tcl:791`); every replacement anchor was then grep-confirmed against source.
9. **GH10's heading regexp was repaired BY RUNNING IT.** The obvious
   `>([0-9]+(?:\.[0-9]+)?)\.` extracts `9` from `<h3>9.1 Viewer keys` (it backtracks to
   satisfy the trailing dot), which would have failed every §9.1 ref. `\.?\s` instead.
10. **GS1 uses `regexp "\nproc wviewer::${n}\\s"`** rather than the scout's
    `string first "\nproc wviewer::$n "`, which requires a trailing space and would
    false-fail on a future zero-arg `proc wviewer::foo {}`.
11. **`references/viva_cadence_waveform_viewer.md`'s back-pointer is written but
    uncommittable** — `references/` is an untracked 884 KB tree. **Driver's call.**
12. **PLAN.md and this receipt deliberately left uncommitted**, per items 8-15's convention
    and because PLAN.md arrived dirty.
13. **No `make`, no build** — the item is docs-only and makes no `src/` change.
14. **⚠ ADDED BY THE LEDGER STAGE — a divergence the implementer did not list.** Ruling 21
    (anchors as grep-able phrases) was applied to the spec and to the new issue 0214, but
    **not** to `0186`, which item 16 edited: it still carries six `file:line` citations, and
    item 16 **fixed one by writing a new line number** (`xschem.tcl:13074` → `:13155`) rather
    than converting it to a phrase. The new number is accurate today (verifier confirmed
    `:13155` is the `xschem reload` caller) and it is named in the commit message, but it was
    not declared as a divergence. Its cost is visible in the same file: the **pre-existing**
    `src/save.c:3814` anchor is already stale — the modal `alert_ {Unable to open file: …}`
    is at **:3816** — and item 16's citation-re-verification pass, which covered the spec, did
    not cover 0186. *Not introduced by item 16 and not disqualifying; recorded so the next
    editor of 0186 converts the remaining six rather than re-numbering them.*

### 12.8 Non-baseline fails

**NONE** — independently established twice.

* **Implementer's audit:** `SUMMARY: 270 pass / 17 fail / 0 crash / 1 skip (total 288)`.
  288 = the 283-case baseline + the five browser cases. Compared as **SETS, not counts**.
  15 of the 16 HARD names (with `test_fluid_editing` **passing** — the baseline's own
  documented exception), `test_wave_trace_menu` on the FLAKY list failing on **TG9
  root-coords** (a documented WSLg flake), and `test_wave_viewer`, which is on **neither**
  list. That one required digging: the log carried `X connection to :0 broken` terminating
  its captured output, so **the verdict was not a measurement** — re-run under a live server
  it is **3/3 PASS at 400 checks**.
* **Verifier's own audit:** 288 tests, 288 verdicts, **23 FAIL** — a *worse* footprint,
  because that run hit the WSLg Xwayland abort three times. Classified as sets: all 16 HARD
  names present; `test_ase_dialogs` / `test_ase_unnamed_net` / `test_deselect_mode` on the
  FLAKY list; and **four off both lists** (`test_ase_interact`, `test_ase_persist`,
  `test_wave_sigsearch`, `test_wave_tabs`) each with `X connection to :0 broken` **inside
  their captured output** — grepped *before* interpreting, per the baseline rule. Re-run
  gated: **4/4 PASS** (194 / 172 / 63 / 109 checks), zero X breaks.

⚠ **The measurement-quality note both runs force:** a raw audit fail-count from this machine
is not by itself a measurement. Both stages had to locate the X aborts and re-run under a
live server before any verdict was legitimate. **After that, non-baseline fails: NONE.**

**Gating honoured end to end** (both stages): the 8-hour authorization had expired, every
`DISPLAY` run went through `run_suites.sh` / `full_audit.sh` (the verifier waited out the
control panel), **`GUI_GATE=0` never set**, no gate file hand-written, no bare loop over
`./src/xschem`, `wsl --shutdown` never run. The `--nogui` arm covers **all 86 new checks**,
which is why the whole sabotage cycle cost the panel nothing.

### 12.9 Open for the driver (declared, not defects)

1. **GS0-GS3 — 55 of the 86 checks — is new coverage of a new file**, beyond note (f).
   Veto is a clean revert of the `GS*` block.
2. **`references/viva_cadence_waveform_viewer.md`'s back-pointer is real on disk but
   uncommittable** (untracked 884 KB tree). The item asked for it; the repo's convention
   forbids committing it.
3. **`PLAN.md` (item 16 ticked, line 1473) and this receipt are uncommitted**, for the
   ledger commit.
4. **Bookkeeping, NOT item 16's:** the arrival note listed `receipts/{02..07}` as the
   expected-dirty tracked set, but `{10..14}` are dirty too. The verifier established by
   mtime (17:09-08:29, **all before** item 16's 11:18 commit) that these are prior items'
   verifier addenda — the "any other tracked diff under `doc/` is item 16's" rule does not
   implicate this item. **Flagged so the ledger commit does not mistake them for scope leak.**

### 12.10 Known limits of the new checks (named, so they are not mistaken for coverage)

* **GS2's `gs_want` is a hand-maintained list of 23 proc names, not derived from source.**
  GS1 catches a spec entry with no proc; GS2 only catches removal of a name already on the
  hand-list. **A NEW proc added to `src/wave_viewer.tcl` and omitted from the spec goes
  unnoticed** — the one rot direction the GS block does not see. The check name does not
  overstate what it pins (ruling 17 satisfied), so this is a *limit*, not a defect.
* **GH8's per-row legs would pass on a guide carrying six IDENTICAL `data-bseq` rows**
  (count 6 + six copies of one true assertion + GH9's 6 == 6). The same hole exists in the
  pre-existing GH0/GH1, so it is not an item-16 regression, and both S3 and V1 fired — the
  block has real teeth. Recorded because this batch's most productive finding was exactly
  the vacuous-check trap.
* **Two cosmetic nits, verified harmless:** issue 0214's prose writes `xschem->readonly = 0`
  where the source says `xctx->readonly = 0` (the grep command printed alongside it is
  correct and resolves to `save.c:3734`); and `0186`'s remaining line-number anchors, §12.7
  item 14.

### 12.11 It did not FAIL — but if item 16 comes back, look here first

The ledger schema asks what a human would look at first on a FAILED verdict. This one is
`ok: true` / `scopeClean: true` / `nonBaselineFails: []`, so the list is written as a
regression triage order instead:

1. **Re-run S3 before reading anything else.** If pointing a `data-bseq` at an unbound
   sequence (counts left at 6/6) stops producing exactly one failure, GH8 has become an
   assertion the guide makes about itself and the browser's documented gestures are
   unchecked — the exact vacuous shape this batch caught five times.
2. **Then V1 and V3**, the source-side mirrors: add a 7th `bind $f.` (GH9 must fire) and
   rename a proc the spec names (GS1 must fire). If either goes quiet, the doc↔source oracle
   is decorative.
3. **A "the guide's §-refs are wrong" report is GH10's regexp**, not the prose. `\.?\s` is
   load-bearing: the obvious `\.` backtracks and reads `9` out of `9.1`.
4. **Never bump GH0's 16/11 literals to "fix" `test_wave_grid`.** `test_wave_sigbrowser_i12`
   BX13 pins them as literal regexps over `test_wave_grid.tcl`'s own source; the naive fix
   goes green here and red there.
5. **A "dead link in the installed docs" report is the `href` divergence** (§12.7 item 6):
   `doc/claude/` is not installed. The spec must stay a text reference.
6. **The one thing with no other record:** `doc/claude/specs/waveform_signal_browser.md`
   **§10** (hierarchy sync). ViVA has no equivalent, and §10.2 — *with no raw loaded the two
   getters are byte-identical, so no test can distinguish decision 10 on that arm* — is what
   makes the feature's whole guard structure make sense. Everything else in the batch has a
   receipt and a test; that section has only this document.
