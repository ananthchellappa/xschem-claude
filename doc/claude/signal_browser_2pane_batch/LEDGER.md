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

Measured **2026-08-08** after two-pane item 14, both arms green.
Re-measure before item 15 and record any drift here; do **not** silently adopt a
new baseline.

> **⚠ THE BASELINE MOVED WITH ITEM 14 — headless 1619 → 1627, X 2149 → 2170.**
> **Reason, per file:** `i1315` 80 → **87** headless / 167 → **184** in X
> (`BP62`-`BP68`, 7 both-arms PURE/SOURCE calls, plus the 10-call `BP69`-`BP74`
> real-viewer block); `grid` 230 → **231** / 355 → **356** (`GH8`'s per-row loop
> gained the sixteenth guide row); `modes` 485 → **488** in X only (`MG18`,
> three calls inside the existing `has_x` gate — the headless arm is unchanged
> at 212); `panes` **unchanged** at 15/81 (`BW59` restated in place, no new
> call). Every other file and every other suite is byte-identical in both arms.
> The item-14 implementer RE-MEASURED the item-13 baseline on the unchanged tree
> first — headless 1619, X 2149, every per-file and per-suite figure EXACT, no
> drift — so these deltas are attributable.
>
> **The item-13 note, kept:** THE BASELINE MOVED WITH ITEM 13 — headless
> 1618 → 1619, X 2136 → 2149.
> **Reason, in one line:** item 13 added 13 check calls and they are *all* in
> `test_wave_sigbrowser_panes.tcl` — `panes` 14 → **15** headless (the single
> both-arms SOURCE check `BW15`) and 68 → **81** in X (`BW15` + `BW68`-`BW78`);
> every other file and every other suite is byte-identical in both arms.
> Not adopted from the implementer's own run: both arms were **re-measured
> independently by the item-13 verifier** from a clean tree, and the headless
> per-file split below is that verifier's, parsed from each file's own
> `RESULT:` line. The previous baseline (item 12, `e5347591`) was headless
> **1618** / X **2136** with `panes` at 14 and 68.

**headless — 1627 checks over 14 files, 0 fail**
(`env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>` from the repo root)

| file | checks | file | checks |
|---|---|---|---|
| `test_wave_sigsearch` | 146 | `test_wave_sigbrowser_i14` | 47 |
| `test_wave_sigbrowser_sea` | 6 | `test_wave_grid` | **231** |
| `test_wave_sigbrowser` | 135 | `test_wave_modes` | 212 |
| `test_wave_sigbrowser_2pane` | 108 | `test_wave_viewer` | 57 |
| `test_wave_sigbrowser_panes` | **15** | `test_wave_markers` | 437 |
| `test_wave_sigbrowser_i11` | 50 | `test_wave_tabs` | 56 |
| `test_wave_sigbrowser_i12` | 40 | | |
| `test_wave_sigbrowser_i1315` | **87** | **TOTAL** | **1627** |

**X arm — 11/11 suites**, run through `xarm.sh suites …` with `SUITE_TIMEOUT=400`.

> **⚠ MEASURED 2026-08-07: the Xvfb arm reproduces the `:0` arm EXACTLY.** All
> eleven per-suite counts identical, 11/11 both ways, **2136 checks** either way
> (that equivalence was established at the item-12 baseline; item 13 moves the
> total to **2149** and item 14 to **2170** — see the table; the equivalence
> itself is unaffected).
> So a number measured before the handback is directly comparable with one
> measured after it, and the unattended window costs no fidelity. What Xvfb
> cannot do is any claim needing a **window manager** — decoration, iconify,
> stacking, raise, geometry echo. Nothing in items 13-19 needs one; if something
> turns out to, it is an eyeball, not a check.

| suite | checks | suite | checks |
|---|---|---|---|
| `panes` | **81** | `2pane` | 108 |
| `sigbrowser` | 353 | `sigsearch` | 233 |
| `sea` | 79 | `grid` | **356** |
| `i11` | 74 | `modes` | **488** |
| `i12` | 123 | | |
| `i1315` | **184** | **TOTAL** | **2170** |
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

- [E] 13 — `browser_reveal` / `browser_tree_apply` under collapsed-by-default
      **-> DONE-PIXEL (`9d5cdd26`)**, on `24fb6769`. `[E]` and never `[x]`: the
      deliverable is visible UI and no check in this batch judges pixels.
      — **13 check calls over 12 ids** (`BW15` + `BW68`-`BW78`; `BW74` is used
      twice, which is why `panes` moves +13 and not +12), `BX31` restated with a
      third leg. Headless **1618 → 1619**, X **11/11**, 2136 → **2149**
      (`panes` 68 → **81**, everything else byte-identical). **9/9 sabotages fire
      exactly on target** — 8 the item's own, plus `S9`, the verifier's own
      unnamed mechanism (it never writes `-open` at all: it `see`s the target's
      first CHILD, so ttk opens the target as an ancestor). `S9` reds `BW77` and
      nothing else.
      **⚠ FIXUP after an adversarial verifier rejected `24fb6769`.** Its own
      sabotage `V4` — an ADDITIVE re-open of the target guarded on
      `[llength [$tv children $id]] > 0` — was **fully green**: every live
      witness of the headline claim landed on `g:x1.x2`, which `BW69` itself
      asserts is CHILDLESS, and `-open` on a childless row is never rendered.
      `BW77`/`BW78` move the claim onto `g:x1`, which HAS children; `V4` now
      reds `BW77` and nothing else. Two bookkeeping faults fixed with it: the
      header's §4.2 citation for "leave the target closed" is **R3**, and this
      item is `[E]`, not `[x]`.
      **⚠ ONE PLAN CLAUSE REFUSED**: the selection's ancestor chain is NOT
      unioned into the applied open set — spec §4.2 forbids it and `BP54` is
      named there as a check that "stays green". The union is now sabotage S4
      and reds `BW76`+`BP53`+`BP54` across three files. See `13_receipt.md`.
- [E] 14 — Persistence: `sash` / `devint` / `srccur` **-> DONE-PIXEL.** `[E]` and
      never `[x]`: the deliverable is a remembered split and two remembered
      boxes, and no check in this batch judges what the restored sidebar LOOKS
      like. Eyeball script: `14_receipt.md` §7.7.
      — **21 new check calls** (`BP62`-`BP74` in `i1315`, `MG18` in `modes`, one
      more leg through `GH8`'s per-row loop) + **6 restated, none deleted**
      (`BP10` `BP13` `BP43` `BP45` `BW59` `GH8`). Headless **1619 -> 1627**,
      X **11/11**, 2149 -> **2170**. **8/8 sabotages fire.**
      **⚠ THE ITEM IS ONE LINE.** `browser_sash`'s read arm used to SEED
      `browsersash($token) = 0.55`, and `browser_show` calls it twice on its
      pack branch — so "has a preference" and "has been shown" were the same
      fact and spec §9's `sash 0` was not expressible. The layout default is now
      a LOCAL; `browser_sash_pref` (pure) is the persisted reader and
      `browser_sash_drop` + a `<ButtonRelease-1>` on `$f.pw` is the ONLY writer.
      The accessor's return contract is deliberately UNCHANGED — `sea.tcl`
      captures and restores it, and a pref-returning read arm would leave the
      sea squeezed for the rest of that file.
      **⚠ THREE SABOTAGE PREDICTIONS WERE WRONG AND ARE CORRECTED IN THE
      RECEIPT.** (a) the pixel-persisting drop reds `BP70` ALONE — the
      accessor's `0 < want < 1` guard makes it fail CLOSED, so `BP72` cannot
      see it; (b) inserting the keys mid-dict reds `BP10` ALONE — `browser_state`
      starts FROM the default dict and `dict set` preserves key position, so the
      predicted `BP41`/`BP42`/`MG9` cascade is impossible; (c) re-seeding the
      sash reds `BP69` ALONE — `BP41`/`BP42`/`MG9` all read never-shown
      sidebars. **`BP69`, `BP70` and `BP10` are each the SOLE witness to their
      defect; none may be weakened.**
      **⚠ A COVERAGE HOLE WAS MEASURED AND CLOSED MID-ITEM.** Restoring a class
      box by `invoke` (a RELATIVE toggle) was caught only by SOURCE checks:
      every behavioural round trip asks for the OPPOSITE of the fresh default,
      so one flip lands right by coincidence. `BP74` gained an IDEMPOTENCE leg
      (apply the same dict twice) and the sabotage was re-run — it now reds
      `BP74` behaviourally.
      **⚠ `BW24` was NOT restated**, contradicting items 12 and 13's forecasts:
      `browser_build` still seeds `0`/`1` and a restore only overrides when a
      state dict is applied. See `14_receipt.md`.
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
| 14 | *(this item)* | Drag the **sash** small, tick **Show device internals**, save/quit/reopen: both must come back. Then reopen into a **shorter** window — the sash must return to the same *proportion*, not the same pixel row. A window you never drag must have **no `browser` key** in its state at all. Full script: `14_receipt.md` §7.7. | ☐ |
| 13 | `24fb6769` + `9d5cdd26` | **Tools → Show in Signal Browser** (Ctrl+5 today; R10's Ctrl-Alt-V is item 17b's and does NOT exist yet) with an instance that **CONTAINS other instances** selected. (a) the tree row scrolls in, is selected, expander stays **CLOSED**; (b) the LOWER pane fills with **that node's own-level signals**; (c) clicking the expander still opens it. Full script: `13_receipt.md` §9. **A LEAF instance answers nothing** — that node class is exactly where the batch's checks were blind. | ☐ |

---

## Carried in from item 12 — read before item 14 or 18

* **`.ph` is still class-filter blind.** It is `"[llength $names] of $total
  signals"` — bar-matched only — so R11's boxes move the tree, the sea and
  `browserseaent` but not that line. Spec §6 lists the status line in its "one
  consistent set"; §7.2 puts the per-node caption on `$f.pw.sea.st` instead.
  **Untouched on purpose**: `BD52`, `BX37`, `BX42`, `BX44`-`BX46`, `BH50`,
  `BH51`, `BH54` pin `.ph` byte-identically. Whoever takes §7.2's three-state
  caption settles it; nobody else may move it.
* ~~**`browser_state` is untouched**, so both R11 boxes reset to 0/1 on every
  window build. That is item 14's whole job.~~ **SETTLED by two-pane item 14:**
  all three fields now ride in the `browser` sub-dict. The build still seeds the
  boxes; a restore overrides.
* **Item 12's build-time default pin is `BW24`, not `BW56`.** ~~If item 14 makes
  the defaults come from a persisted file, `BW24` is the check to restate.~~
  **It did not**: `browser_build` still seeds `0`/`1` and only an applied state
  dict overrides. `BW24` is green untouched, and that is the record of the
  decision rather than an oversight.
