# Two-pane Signal Browser — batch LEDGER

> **⚠ ITEM NUMBERING.** Always write `two-pane item N`. The single-pane plan
> (`doc/claude/signal_browser_batch/PLAN.md`, items 1-16) is a different batch and
> the number 16 has already meant three things. The rule and its history are in
> `PLAN.md`'s header block.

This file is the **state of the batch**. The driver reads it and nothing else to
decide what runs next; the pipeline's ledger stage is the only thing that writes
it. `PLAN.md` stays the spec — it is never edited by the batch.

Scope: `PLAN.md` items **13, 14, 15, 16, 17b, 18, 19**. Everything else is done.

---

## Recorded baseline — the contract every verifier compares against

Measured **2026-08-07** on `e5347591` (two-pane item 12), both arms green.
Re-measure before item 13 and record any drift here; do **not** silently adopt a
new baseline.

**headless — 1618 checks over 14 files, 0 fail**
(`env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>` from the repo root)

| file | checks | file | checks |
|---|---|---|---|
| `test_wave_sigsearch` | 146 | `test_wave_sigbrowser_i14` | 47 |
| `test_wave_sigbrowser_sea` | 6 | `test_wave_grid` | 230 |
| `test_wave_sigbrowser` | 135 | `test_wave_modes` | 212 |
| `test_wave_sigbrowser_2pane` | 108 | `test_wave_viewer` | 57 |
| `test_wave_sigbrowser_panes` | 14 | `test_wave_markers` | 437 |
| `test_wave_sigbrowser_i11` | 50 | `test_wave_tabs` | 56 |
| `test_wave_sigbrowser_i12` | 40 | | |
| `test_wave_sigbrowser_i1315` | 80 | **TOTAL** | **1618** |

**X arm — 11/11 suites** (`tests/headless/run_suites.sh`, `SUITE_TIMEOUT=400`)

| suite | checks | suite | checks |
|---|---|---|---|
| `panes` | **68** | `2pane` | 108 |
| `sigbrowser` | 353 | `sigsearch` | 233 |
| `sea` | 79 | `grid` | 355 |
| `i11` | 74 | `modes` | 485 |
| `i12` | 123 | | |
| `i1315` | 167 | | |
| `i14` | **91** | | |

**Baseline fails: NONE.** Any fail is the item's problem. Known flakes that are
*not* regressions and must be re-run before being called a fail: `BR25`
(a `<Return>` through a bare `event generate`), `MG16` (key delivery), and a
whole-suite `NORESULT` from a WSLg Xwayland death.

---

## Ledger

Marks: `[ ]` not started · `[x]` done, test-verified · `[E]` done, **eyeball
owed** (a pixel/feel deliverable no test can judge) · `[D]` deferred, with reason
· `[F]` failed, needs a human.

- [ ] 13 — `browser_reveal` / `browser_tree_apply` under collapsed-by-default
- [ ] 14 — Persistence: `sash` / `devint` / `srccur`
- [ ] 15 — R7: All-DBs headers + a design root per DB
- [ ] 16 — R9: Ctrl-L → Ctrl-B, incl. the C-table row deletion
- [ ] 17b — R10: `Ctrl-Alt-V` via the C action registry (the half `882694cc` left)
- [ ] 18 — R12: auto-tick, reveal, and say so
- [ ] 19 — Docs, oracles, the four-file lockstep, 0217 closed

### Dependencies — the driver enforces these before launching

| item | needs | notes |
|---|---|---|
| 13 | 10 ✔ | ready |
| 14 | 12 ✔, 13 | **hard**: persistence with nothing to persist is not implementable |
| 15 | 4 ✔, 8 ✔, 10 ✔ | ready; independent of 13/14 |
| 16 | 9 ✔ | ready; **touches C + the generated key table** |
| 17b | 16 | **hard**: there is no `Control-Alt-v` binding anywhere in `src/` yet |
| 18 | 12 ✔, 13, 17b | |
| 19 | all | runs last regardless, and documents whatever actually shipped |

**Run order: 13 → 14 → 15 → 16 → 17b → 18 → 19.** Strictly sequential, never two
in flight — every item touches `src/wave_viewer.tcl` and the same test files.

A `[D]`/`[F]` on **13** blocks 14 and 18; on **16** blocks 17b and 18. In both
cases the driver skips the dependants with `[D] blocked by item N` and carries
on to the next runnable item rather than stopping the batch. **15 and 19 always
run** — 15 depends on nothing outstanding and 19 documents whatever shipped.

---

## Eyeball queue

Pixel items may **never** be marked `[x]`. `[E]` + a row here.

| item | commit | what to look at | eyeballed? |
|---|---|---|---|

---

## Carried in from item 12 — read before item 14 or 18

* **`.ph` is still class-filter blind.** It is `"[llength $names] of $total
  signals"` — bar-matched only — so R11's boxes move the tree, the sea and
  `browserseaent` but not that line. Spec §6 lists the status line in its "one
  consistent set"; §7.2 puts the per-node caption on `$f.pw.sea.st` instead.
  **Untouched on purpose**: `BD52`, `BX37`, `BX42`, `BX44`-`BX46`, `BH50`,
  `BH51`, `BH54` pin `.ph` byte-identically. Whoever takes §7.2's three-state
  caption settles it; nobody else may move it.
* **`browser_state` is untouched**, so both R11 boxes reset to 0/1 on every
  window build. That is item 14's whole job.
* **Item 12's build-time default pin is `BW24`, not `BW56`.** If item 14 makes
  the defaults come from a persisted file, `BW24` is the check to restate.
