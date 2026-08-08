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

**X arm — 11/11 suites**, run through `xarm.sh suites …` with `SUITE_TIMEOUT=400`.

> **⚠ MEASURED 2026-08-07: the Xvfb arm reproduces the `:0` arm EXACTLY.** All
> eleven per-suite counts identical, 11/11 both ways, **2136 checks** either way.
> So a number measured before the handback is directly comparable with one
> measured after it, and the unattended window costs no fidelity. What Xvfb
> cannot do is any claim needing a **window manager** — decoration, iconify,
> stacking, raise, geometry echo. Nothing in items 13-19 needs one; if something
> turns out to, it is an eyeball, not a check.

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
whole-suite `NORESULT` from a WSLg Xwayland death (reachable only after the
handback — Xvfb is immune).

---

## The unattended window, and the handback

The user granted **7 hours of free test running from 2026-08-07 23:21 MST**, then
wants the GUI-test-gate widget raised so they have control again.

| | |
|---|---|
| deadline | **1786195286** = Sat 2026-08-08 **06:21:26 MST** |
| stored in | `DEADLINE` (epoch seconds) beside `xarm.sh` — the only clock anything reads |
| before it | private **Xvfb**. No gate, the user's screen untouched, Xwayland death cannot reach the batch |
| after it | the real **`:0` under the gate panel**, which `xarm.sh` **raises if it is not already up** |

**Every X-arm run goes through `xarm.sh`** (`suites` / `one` / `mode`) so the
switchover is automatic and no agent has to check a clock. Nothing else may call
`run_suites.sh`, `gated_xschem.sh` or `./src/xschem` for an X run.

Extending or ending the unattended window is a one-line edit to `DEADLINE`.

After the handback the panel's **Pause and Stop are the user's authority.** A run
that stalls may simply be paused — check `~/.claude/gui_test_gate/control`, wait,
and never work around it with `GUI_GATE=0`.

The `--nogui` headless arm needs no display at all and is unaffected by any of this.

---

## Ledger

Marks: `[ ]` not started · `[x]` done, test-verified · `[E]` done, **eyeball
owed** (a pixel/feel deliverable no test can judge) · `[D]` deferred, with reason
· `[F]` failed, needs a human.

- [x] 13 — `browser_reveal` / `browser_tree_apply` under collapsed-by-default
      — 10 checks (`BW15` + `BW68`-`BW76`), `BX31` restated with a third leg.
      Headless **1618 → 1619**, X **11/11** (`panes` 68 → 79, everything else
      byte-identical). 7/7 sabotages fire exactly on target.
      **⚠ ONE PLAN CLAUSE REFUSED**: the selection's ancestor chain is NOT
      unioned into the applied open set — spec §4.2 forbids it and `BP54` is
      named there as a check that "stays green". The union is now sabotage S4
      and reds `BW76`+`BP53`+`BP54` across three files. See `13_receipt.md`.
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
