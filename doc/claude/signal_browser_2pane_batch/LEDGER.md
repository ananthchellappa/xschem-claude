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

Measured **2026-08-08** after two-pane item 19 **and its FIX-UP (`GS28`/`GS29`)**,
both arms green. **THE BATCH IS CLOSED**; the tables below are the contract any
later work compares against. Re-measure before touching this subsystem and record
any drift here; do **not** silently adopt a new baseline.

> **⚠ THE PRE-ITEM-19 BASELINE, KEPT FOR ATTRIBUTION. IT WAS RE-MEASURED EXACT
> ON THE UNCHANGED TREE BEFORE THE ITEM TOUCHED ANYTHING** — headless
> **1662 / 0** with every per-file figure identical (`test_wave_grid` 231), X
> **2244** with every per-suite figure identical (`test_wave_grid` 356), the
> three out-of-baseline X-only suites **13 / 17 / 70**. **NO DRIFT.** Item 19
> took it to headless **1698** / X **2281**; its fix-up to the **1705 / 2287** in
> the tables.
>
> **⚠⚠ THE BASELINE MOVED WITH THE ITEM-19 FIX-UP (2026-08-08) AND THE TABLES
> BELOW ARE THE NEW CONTRACT: headless 1662 → 1705, X 2244 → 2287.**
> **Reason, in one line:** the fix-up added **7** check calls and they are all in
> **ONE** file — `test_wave_grid` 267 → **274** headless / 392 → **399** under X,
> the SAME `+7` in both arms (`GS28` +5, `GS29` +2) — and every other file and
> every other suite is byte-identical in both arms. The `+7` closes the item-19
> verifier's two findings: the guide's §11.7 had **no oracle at all** (`GS28`,
> section-scoped) and a corrected `tb_charge_pump` figure survived as a stale
> `110` in two-pane §0's motivation table (`GS29`, a within-file agreement
> oracle). Out-of-baseline **13 / 17 / 70 unmoved**.
>
> **⚠ NOT ADOPTED FROM THE FIX-UP IMPLEMENTER'S RUN — AND ITS X FIGURE IS
> CORRECTED.** The fix-up reported **"11/12 measurable = 2162"** and declared
> `test_wave_sigbrowser_i12`'s X count **unmeasurable** after nine consecutive
> teardown deaths on `:0` (each after 124 of 126 checks had printed `ok` with
> zero fails; A/B-proven environmental by swapping `HEAD`'s `test_wave_grid.tcl`
> back in and watching `i12` die identically twice). **Its verifier measured that
> number: `i12` = 126 ALL PASS on `:0`, first try.** So the arm is **12/12 =
> 2287**, the declared limit is **closed, not carried**, and `2244 + 36 + 7`
> reconciles **EXACTLY** with no drift hiding behind the missing figure. Both
> arms were re-measured independently by that verifier — all 15 headless files by
> hand (**1705 / 0**, summed by hand) and 12 suites through `xarm.sh suites` on
> the gated `:0` — and the `+7` was **attributed** by checking `589d7424`'s
> `test_wave_grid.tcl` back in (**267 / 0 ALL PASS**, restored byte-identical),
> so all seven are genuinely new checks on a green pre-state.
>
> **⚠ `i1315`'s X COUNT IS 190 *OR* 191 ON IDENTICAL BYTES, AND BOTH ARE REAL.**
> `BP56`'s pixel leg is **gated**; 190 and 191 were observed on consecutive
> standalone runs of the same tree. The total is stated as **2287** (i1315 at
> 190) and reads **2288** when that leg runs. Do not treat either as drift.
>
> **⚠ `:0` DEGRADED PROGRESSIVELY WHILE THE FIX-UP WAS MEASURED.**
> `test_wave_sigbrowser_i1315` **answered 191** in the first X sweep of this
> exact tree, then `NORESULT`ed in the final sweep and on three standalone
> re-runs. **The tree did not change between those sweeps.** Every per-suite
> figure that reported in both sweeps is identical. Treat any single `NORESULT`
> here as a server event, and prefer the sweep in which a suite actually
> reported.
>
> **The pre-fix-up item-19 contract, for provenance: headless 1698 / 0, X 2281
> over 12 suites.** Exactly two figures moved from the pre-item baseline and
> both are attributable to the last check:
> `test_wave_grid` **231 → 267** headless and **356 → 392** under X (the same
> +36: `GS1` +19, `GS2` +6, `GS3` +2, `GS22`-`GS27` +6, `GH11` +2, `GH10` +1),
> and `test_wave_sigbrowser_i1315` **190 → 191** under X only (`BP78`, which
> needs a mapped panedwindow) with its headless 88 **unchanged**. Every other
> per-file and per-suite figure is byte-identical in both arms.
>
> **⚠ THE `:0` ARM WAS UNRELIABLE THE DAY ITEM 19 RAN.** Three whole-suite deaths
> (`i12` and `i1315` pre-item, `sigbrowser` post-item), each with
> `X connection to :0 broken`; the gate panel itself died and was revived once;
> one `BP56` geometry echo failed (240 vs 260 px) and passed on re-run; and
> `test_key_graph_context` TIMEOUTed at 400 s on its first batched attempt and
> answered 70/0 standalone twice. **Every one re-ran clean at its baseline
> count.** The two pre-item deaths were additionally re-measured under **Xvfb**
> — `i12` **126**, `i1315` **190** — so the baseline is attributable rather than
> merely re-attempted. A `NORESULT` is still not a measurement.

> **⚠ THE FIX-UP MOVED THE X ARM ONLY — X 2243 → 2244, headless 1662 UNCHANGED.**
> Two-pane item 18's verifier found the item's ONE decision point unpinned:
> relaxing `browser_show_path`'s full-resolution guard from "the would-be model
> resolves the WHOLE path" to "…resolves MORE than we did" red **nothing** in
> either arm, while flipping the box, tripling the tree 45 → 129 and saying
> nothing about it. The fix-up adds **`BK43`** (X-only, one call, in
> `test_wave_sigbrowser_keys`) and a pointer comment in `browser_show_path`.
> `keys` **48 → 49** under X; **25 unchanged** headless because `BK43` needs the
> Tk fixture. Every other file and every other suite byte-identical in both arms.
> Re-measured by hand: headless **1662 / 0** over the 15 files with every
> per-file figure exact; X **12/12 = 2244** through `xarm.sh suites` with
> `SUITE_TIMEOUT=400` on the real `:0` under the gate panel.
> **Not adopted from the implementer's run:** the fix-up's verifier re-measured
> **both arms independently** — all 15 headless files by hand (**1662 / 0**,
> every per-file figure identical to the 17b table except `keys` 21 → 25, which
> is item 18 and *not* the fix-up, so the fix-up moved headless by ZERO as
> claimed) and 12/12 through `xarm.sh suites` on the real `:0` under the gate
> panel (**2244**, sum verified by hand, only `keys` 48 → **49**). It also
> MEASURED the comment-only claim rather than taking it — `git diff 6c887aed
> 91a3de1a -- src/wave_viewer.tcl` filtered to non-comment lines is **EMPTY** —
> and re-counted the four frozen bare-name oracles pre/post: `browser_devint`
> 5/5, `browser_srccur` 5/5, `browser_alldbs` 2/2, `device internals to reach`
> 1/1, so the new comment names no accessor.

> **⚠ THE BASELINE MOVED WITH ITEM 18 — headless 1658 → 1662 over the same**
> **FIFTEEN files, X 2230 → 2243 over the same TWELVE suites.**
> **Reason, in one line:** item 18 added **4** check calls headless and **13**
> under X, **all of them in ONE file** — `test_wave_sigbrowser_keys` 21 → **25**
> headless / 35 → **48** under X (`BK32`-`BK42`: `BK32`-`BK35` in both arms,
> `BK36`-`BK42` X-only over nine calls). `test_wave_sigbrowser_panes` restated
> `BW59` **in place** from `{4 4 1 1}` to `{5 5 1 1}` with **no change in call
> count**, which is why `panes` does not move in either arm. Every other file and
> every other suite is byte-identical in both arms. The item-18 implementer
> RE-MEASURED the item-17b baseline on the unchanged tree first — headless
> **1658 / 0** with every per-file figure exact, X **2230** with every per-suite
> figure exact — so the delta is attributable.
>
> **⚠⚠ ONE BASELINE FAIL OBSERVED ON THE PRISTINE TREE, AND IT IS A `:0` FLAKE,**
> **NOT A REGRESSION AND NOT A DRIFT TO ADOPT.** The pre-item run of
> `test_wave_sigbrowser_i1315` on the real `:0` failed **`BP77`** TWICE (189
> passed / 1 failed — check count 190, correct) while the SAME file under Xvfb
> answered **190 / 0**. `BP77`'s fourth leg is a **geometry echo** ("opening the
> sidebar lands on the restored 0.44 split"), exactly the class this file's own
> Xvfb note says a window manager can perturb and Xvfb cannot measure. It then
> **passed on `:0`** in the post-item run (190 / 0). So: a WM timing flake,
> reachable only after the handback, on the PRISTINE tree before item 18 existed.
> **Add it to the known-flake list below; re-run before calling it a fail.**
>
> **⚠ THREE WHOLE-SUITE `NORESULT`s in one session** (`i1315` + `sigsearch`
> pre-item, `i12` post-item), one carrying an explicit `X connection to :0
> broken`. All re-run by hand through `xarm.sh one`, all ALL PASS at their
> baseline counts. The WSLg Xwayland death is live again now that the arm is on
> `:0` — a NORESULT is not a measurement.
>
> ---
> **The item-17b record, kept for attribution:**
> **THE BASELINE MOVED WITH ITEM 17b — headless 1649 → 1658 over the same**
> **FIFTEEN files, X 2215 → 2230 over the same TWELVE suites.**
> **Reason, in one line:** item 17b added **9** check calls headless and **15**
> under X, and they are all in the **two** files it touches —
> `test_wave_sigbrowser_keys` 12 → **21** headless / 23 → **35** under X
> (`BK20`-`BK31`, of which `BK20`-`BK28` run in both arms and `BK29`-`BK31` are
> X-only) and `test_wave_sigbrowser_i12` **40 headless, unchanged** / 123 →
> **126** under X (`BX54`, `BX55`, `BX56`). **`BX11`/`BX12`/`BX13`/`BX43`/`BX44`
> were restated IN PLACE with no change in call count**, which is why the
> headless `i12` figure does not move even though five of its ids changed
> meaning. Every other file and every other suite is byte-identical in both arms.
> The item-17b implementer RE-MEASURED the item-16 baseline on the unchanged tree
> first (headless 1649/0 with every per-file figure exact, X 12/12 = 2215 with
> every per-suite figure exact), so the delta is attributable.
> **Not adopted from the implementer's run:** both arms were re-measured
> independently by the item-17b verifier — all 15 headless files run by hand
> (1658 / 0 fail, sum verified) and 12/12 through `xarm.sh suites` under Xvfb
> with `SUITE_TIMEOUT=400` (2230, sum verified, the ten untouched suites
> byte-identical). The verifier also confirmed **neither** moved suite printed a
> `SKIPPED` line, so 35 is not a masked 34 and 126 is not a masked 125 —
> `BX43`'s retargeted real-key leg really fired. Before measuring it ran
> `cd src && make`, which answered *"Nothing to be done"*, proving the shipped
> binary was built from the committed `callback.c`.
>
> **⚠ THE THREE OUT-OF-BASELINE X-ONLY SUITES DID NOT MOVE: 13 / 17 / 70.**
> `test_bindings_file`, `test_keybindings_help` and `test_key_graph_context` were
> re-run by hand through `xarm.sh one` before and after. **The PLAN says the
> first two red BY DESIGN on this item; measured, they do not** — each is a
> lockstep tripwire for one leg of the C / `keybindings.csv` / `actions.csv`
> triangle and each was proven to fire only under sabotage (S1+S5, and S2a).
> They are still in NEITHER baseline and item 18/19 must still run them by hand.
>
> **⚠ TWELVE FURTHER NON-BATCH SUITES were run once, by the verifier**, because
> this item touches four broad-reach files (`callback.c`, `actions.csv`,
> `keybindings.csv`, `xschem.tcl`'s menubar) and an empty "no non-baseline fails"
> claim over 12+3 suites would have held by luck of scope rather than by
> measurement: `test_accelerators`, `test_binding_precedence`, `test_remap`,
> `test_perform_action_check_unique_names`, `test_keybind_snap_grid`,
> `test_gesture_bindings`, `test_mouse_bindings`, `test_clone_canvas_bindings`,
> `test_altf5_ciw`, `test_graph_context` — **all ALL PASS**. The two that did not
> report clean (`test_action_log_dispatch` NORESULT, `test_cadence_window_hop_log`
> SKIP) were re-run by hand under Xvfb **with `--logdir`** and both give ALL PASS:
> the harness passes `--nolog`, so it is an **invocation artefact, not a
> regression**. None of the twelve is adopted into the baseline.

> **⚠ THE BASELINE MOVED WITH ITEM 16 — headless 1637 → 1649 over FIFTEEN files,**
> **X 2192 → 2215 over TWELVE suites.**
> **Reason, in one line:** item 16 added ONE file,
> `test_wave_sigbrowser_keys.tcl` (band `BK`) — **12** checks headless, **23**
> under X — and **every other file and every other suite is byte-identical in
> both arms**. The item-16 implementer RE-MEASURED the item-15 baseline on the
> unchanged tree first (headless 1637, X 11/11 2192, every per-file and
> per-suite figure EXACT, no drift), so the delta is attributable.
> **Not adopted from the implementer's run:** both arms were re-measured
> independently by the item-16 verifier — all 15 headless files run by hand
> (1649 / 0 fail, the 14 pre-existing files summing to **exactly 1637**, every
> per-file figure byte-identical) and 12/12 through `xarm.sh suites` under Xvfb
> with `SUITE_TIMEOUT=400` (2215, the eleven baseline suites byte-identical).
> The verifier also confirmed the `keys` suite printed **no `SKIPPED` line**, so
> `BK18`'s real-key leg really fired and 23 is not a masked 22.
>
> **⚠ THE ITEM-16 NOTE BELOW SAYS "the two binding suites". IT IS THREE.**
> `test_bindings_file.tcl`, `test_keybindings_help.tcl` **and
> `test_key_graph_context.tcl`** are all outside both baselines, and the third is
> the one item 16 reds. Post-item ok-counts: **13 / 17 / 70** (key_graph_context
> was 69; +1 is the explicit absence claim item 16 added beside its inverted
> behavioural leg). A green 15-file / 12-suite run proves NOTHING about them.
> **All three are X-ONLY** — the two binding suites THROW under `--nogui`
> (`invalid command name "focus"` / `"winfo"`), so those figures are reproducible
> only through `xarm.sh one <suite>`, never from the headless arm.

> **⚠ THE BASELINE MOVED WITH ITEM 15 — headless 1628 → 1637, X 2174 → 2192.**
> **Reason, in one line:** item 15 added **18 check calls** and they are all in
> two files — `i14` 47 → **56** headless (`BD60`-`BD66b`, the nine PURE checks)
> and 91 → **107** in X (those nine plus `BD67`/`BD68`/`BD69`/`BD70`/`BD70b`/
> `BD70c`/`BD70d`), and `i1315` 188 → **190** in X only (`BP43a`'s new negative
> control and `BP47b`, the id-scheme control — the headless arm is unchanged at
> 88). Every other file and every other suite is byte-identical in both arms.
> Not adopted from the implementer's run: **both arms were re-measured
> independently by the item-15 verifier** — all 14 headless files run by hand
> (1637 / 0 fail, every per-file figure exact) and all 11 X suites through
> `xarm.sh suites` under Xvfb with `SUITE_TIMEOUT=400` (11/11, 2192). The
> item-15 implementer had also RE-MEASURED the item-14 baseline on the unchanged
> tree first — headless 1628, X 11/11 2174, every per-file and per-suite figure
> EXACT, no drift — so these deltas are attributable.
>
> **The item-14 note, kept:** **THE BASELINE MOVED WITH ITEM 14 — headless**
> **1619 → 1627, X 2149 → 2170,**
> **AND AGAIN WITH ITS FIXUP — headless 1627 → 1628, X 2170 → 2174.**
> **The fixup's whole delta is in `i1315`:** 87 → **88** headless (`BP75`, the
> both-arms SOURCE half) and 184 → **188** in X (`BP75` + `BP76`'s fixture +
> `BP76` + `BP77`). Every other file and every other suite is byte-identical to
> the item-14 figures below in both arms. The fixup closes two coverage holes
> the item's verifier found by sabotage — swapping `browser_state_apply`'s two
> fallback constants, and dropping the sash preference on a restore into a
> never-shown sidebar — **both of which were fully green across four and three
> suites respectively.** Receipt `14_receipt.md` §9.
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

**headless — 1705 checks over 15 files, 0 fail**
(`env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>` from the repo root)

| file | checks | file | checks |
|---|---|---|---|
| `test_wave_sigsearch` | 146 | `test_wave_sigbrowser_i14` | **56** |
| `test_wave_sigbrowser_sea` | 6 | `test_wave_grid` | **274** |
| `test_wave_sigbrowser` | 135 | `test_wave_modes` | 212 |
| `test_wave_sigbrowser_2pane` | 108 | `test_wave_viewer` | 57 |
| `test_wave_sigbrowser_panes` | 15 | `test_wave_markers` | 437 |
| `test_wave_sigbrowser_i11` | 50 | `test_wave_tabs` | 56 |
| `test_wave_sigbrowser_i12` | 40 | | |
| `test_wave_sigbrowser_i1315` | 88 | `test_wave_sigbrowser_keys` | **25** |
| | | **TOTAL** | **1705** |

**X arm — 12/12 suites**, run through `xarm.sh suites …` with `SUITE_TIMEOUT=400`.

> **⚠ MEASURED 2026-08-07: the Xvfb arm reproduces the `:0` arm EXACTLY.** All
> eleven per-suite counts identical, 11/11 both ways, **2136 checks** either way
> (that equivalence was established at the item-12 baseline; item 13 moves the
> total to **2149**, item 14 to **2170**, its fixup to **2174**, item 15 to
> **2192**, item 16 to **2215** over **twelve** suites, item 17b to **2230**
> item 18 to **2243**, its fix-up to **2244**, item 19 to **2281** and ITS
> fix-up to **2287** — see the table; the equivalence itself is unaffected).
> So a number measured before the handback is directly comparable with one
> measured after it, and the unattended window costs no fidelity. What Xvfb
> cannot do is any claim needing a **window manager** — decoration, iconify,
> stacking, raise, geometry echo. Nothing in items 13-19 needs one; if something
> turns out to, it is an eyeball, not a check.

| suite | checks | suite | checks |
|---|---|---|---|
| `panes` | 81 | `2pane` | 108 |
| `sigbrowser` | 353 | `sigsearch` | 233 |
| `sea` | 79 | `grid` | **399** |
| `i11` | 74 | `modes` | 488 |
| `i12` | **126** | | |
| `i1315` | **190 / 191** | `keys` | **49** |
| | | **TOTAL** | **2287** |
| `i14` | **107** | | |

`i1315` reports **190 or 191 on identical bytes** — `BP56`'s pixel leg is
**gated** — so the total reads **2287** at 190 and **2288** at 191. Both were
observed on consecutive standalone runs; neither is drift.

**Baseline fails: NONE.** Any fail is the item's problem. Known flakes that are
*not* regressions and must be re-run before being called a fail: `BR25`
(a `<Return>` through a bare `event generate`), `MG16` (key delivery),
**`BP77` (item 18's finding — a sash GEOMETRY ECHO that a window manager can
perturb; measured 189/1 twice on `:0` and 190/0 under Xvfb on the PRISTINE tree,
then 190/0 on `:0` after the item)**, and a whole-suite `NORESULT` from a WSLg
Xwayland death (reachable only after the handback — Xvfb is immune; item 18 hit
three in one session and all three re-ran clean).
**Add to that list: a whole-suite `TIMEOUT` of `test_key_graph_context` at 400 s
on `:0`** — out of BOTH baselines, hit by item 18's fix-up implementer AND
reproduced independently by its verifier, both times on the first *batched*
attempt and both times ALL PASS in ~0.5-1 s wall standalone on every re-run. A
**stall**, not a slow suite and not a regression; the fix-up touches nothing that
suite loads. **Item 19 should expect it and re-run rather than report a fail.**

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
- [F] 14 — Persistence: `sash` / `devint` / `srccur` **-> FAILED (`1990d00e`).**
      **Rejected a SECOND time by its verifier, for the same class of defect as
      the first rejection.** The failure block is at the end of this item; the
      record of what did land is kept in full below it. Had it passed it would
      have been `[E]` and never `[x]`: the deliverable is a remembered split and
      two remembered boxes, and no check in this batch judges what the restored
      sidebar LOOKS like. Eyeball script: `14_receipt.md` §7.7 — **not to be
      actioned while the item is `[F]`.**
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
      **⚠⚠ REJECTED BY ITS VERIFIER, THEN FIXED UP.** Two sabotages the item had
      NOT named stayed **fully green**: swapping `browser_state_apply`'s two
      fallback constants (`i1315` 184, `panes` 81, `modes` 488, `sea` 79 — four
      suites, zero reds) and dropping the sash preference on a restore into a
      never-shown sidebar (`i1315` 184, `panes` 81, `sea` 79). Both are LIVE
      paths: `ase_window.tcl` persists the session `viewer` dict to a FILE, so
      every pre-`91c6c828` state file enters the key-absent branch; and the
      hidden-sidebar store is the behaviour `declaredLimits` chose on purpose.
      The fixup adds **`BP75`** (SOURCE, both arms), **`BP76`** (a legacy dict
      applied to a window driven to the OPPOSITE pair) and **`BP77`** (a restore
      into a never-shown sidebar) plus one fixture call — **4 new check calls,
      none restated, none deleted** — taking headless **1627 -> 1628** and
      X **2170 -> 2174**, all of it in `i1315`. It also corrects a **false
      sabotage claim shipped in `src/wave_viewer.tcl`** (the comment still
      predicted S7's four-oracle cascade after the receipt had disproved it;
      re-measured on the fixup tree S7 reds **`BP69` + `BP77`**, 186/2, and
      `BP41`/`BP42`/`MG9` measure GREEN) and removes the **two bare proc names**
      the item wrote into a comment, which would have pre-poisoned any future
      `BD06`/`BW59`-style count. Receipt `14_receipt.md` §9. **Next free `BP78`;
      `BD60`-`BD70` still item 15's.**
      **⚠ A COVERAGE HOLE WAS MEASURED AND CLOSED MID-ITEM.** Restoring a class
      box by `invoke` (a RELATIVE toggle) was caught only by SOURCE checks:
      every behavioural round trip asks for the OPPOSITE of the fresh default,
      so one flip lands right by coincidence. `BP74` gained an IDEMPOTENCE leg
      (apply the same dict twice) and the sabotage was re-run — it now reds
      `BP74` behaviourally.
      **⚠ `BW24` was NOT restated**, contradicting items 12 and 13's forecasts:
      `browser_build` still seeds `0`/`1` and a restore only overrides when a
      state dict is applied. See `14_receipt.md`.
      **⚠⚠ FAILED (`1990d00e`) — A THIRD COVERAGE HOLE OF THE SAME FAMILY, FOUND
      BY THE VERIFIER'S OWN FRESH SABOTAGE `V4`, IS STILL OPEN.** ONE CHARACTER
      in the sash accessor's store guard (`src/wave_viewer.tcl:8163`,
      `$want > 0` -> `$want >= 0`, i.e. stop REFUSING spec §9's `sash 0`) goes
      **fully green**: `i1315` **188 ALL PASS** (count held) and `sea` **79 ALL
      PASS**, zero reds — while the same driver in the same session red `V1`
      (`BP75`+`BP76`), `V2`-literal (`BP70`+`BP72`+`BP77`), `V2b` (`BP77`) and
      `S7` (`BP69`+`BP77`) exactly, each with a printed proof-of-mutation. It is
      NOT defensive code: the item's own comment at
      `src/wave_viewer.tcl:10380-10383` cites that guard BY NAME as the reason
      the sash restore "needs no gate of its own", and **nothing measures it** —
      the third written justification this item ships with no oracle behind it.
      It is MORE live than either hole the fixup closed: `browser_state` writes
      `sash 0` for every user who never dragged the sash, so ANY restore of a
      browser dict from such a user (changed width, filter, dest, open set,
      selection — anything) runs that line with `$want` 0. Measured on both
      trees with the same probe: shipped `pref=0.42 frac=0.42 px=210`;
      sabotaged `pref=0 frac=0.0 px=0` — **the tree pane collapses to nothing
      and the two-pane browser is destroyed, silently, with every check in the
      batch green.** Remedy is ONE check, **`BP78`** (free, and the file header
      already reserves it), in the same X block: apply
      `[dict replace $bp_st14 shown 1 sash 0]` to a window carrying a known
      non-zero preference and assert the fraction and `sashpos 0` are unchanged
      and non-zero, with a leg proving the preference was really there first.
      Receipt `14_receipt.md` §10.
      **⚠ THE BASELINE HELD AND THE CODE IS NOT REVERTED.** The verifier
      re-measured both arms independently on `1990d00e` — headless **1628 /
      0 fail**, X **11/11, 2174**, every per-file and per-suite figure EXACT
      against the table above — and MEASURED the source-diff provenance rather
      than taking it (`git diff 91c6c828 1990d00e -- src/wave_viewer.tcl`
      filtered for non-comment `+`/`-` lines yields **zero**, so the fixup's
      behaviour-change-free claim is true line by line). The recorded baseline
      above is therefore the FAILED tree's. **If a human reverts `91c6c828` or
      `1990d00e`, that baseline must be re-measured before item 15 runs.**
      Nothing downstream is blocked — the dependency table gates on 13 and 16,
      not on 14 — so the batch continues at item 15.
      **⚠ Two minor findings, recorded not fixed.** (a) The fixup commit's
      opening line says "three checks" while its own body says "FOUR NEW CHECK
      CALLS"; both readings are defensible (three claims + one fixture call) but
      a check COUNT is this batch's only witness to vacuity, so the skimmable
      sentence is the wrong one to round down. (b) The tree carries an
      **uncommitted** modification to `13_receipt.md` (mtime 00:42:21, ~68 min
      BEFORE the `1990d00e` commit at 01:50:36 — item 13's leftover, not an
      item-14 scope violation). Land it or drop it before item 15.
- [E] 15 — R7: All-DBs headers + a design root per DB **-> DONE-PIXEL
      (`e1cfd5ff`)**. `[E]` and never `[x]`: the deliverable is a tree whose top
      level changes shape on screen, and no check in this batch judges pixels —
      the new checks judge widget STATE (ids, text, `-open`, selection), and the
      X arm ran under **Xvfb**, with no window manager. Eyeball script:
      `15_receipt.md` §11.
      — **18 new check calls** (`BD60`-`BD66b` PURE + `BD67`-`BD70d` in `i14`,
      `BP43a`'s negative control + `BP47b` in `i1315`) + **15 restated, none
      deleted**, three of which are TOMBSTONES whose own comments already spelled
      out what item 15 owed (`BD48c`, `BD50c`, `BP43a`). Headless **1628 →
      1637**, X **11/11**, 2174 → **2192**. **7/7 of the item's own sabotages
      fire**, plus **three the verifier invented** (`VS1`/`VS2`/`VS3`) and a
      verbatim replay of `S6`; every positive control held and the tree was
      restored byte-exact each time.
      **⚠ THE PLAN'S CENTRAL PRESCRIPTION WAS REFUSED, ON A MEASUREMENT.** PLAN
      item 15 gives group 0 a `d:0|` prefix. It gets a HEADER and keeps its BARE
      ids. Spec §4.3's closing sentence rules the same way, but the deciding fact
      came out of the FIRST RED RUN: the prefix would carry the DB's **registry
      index**, which is not a property of the design, and `i1315`'s restore
      fixture moves the current DB from slot **1** to slot **0** — so every
      persisted `d:1|g:x1.x2` would name a row that no longer exists and the
      user's selection and open set would silently evaporate, reding
      `BP52`-`BP55` with **no defect in the persistence code at all**. The
      verifier reproduced this from the other side: sabotage `VS3` (collapse
      "absent" and "deliberately empty" prefix) reds 17 in `i14` and 9 in
      `i1315` **including `BP52`-`BP55`**. Blast radius fell from ~20 existing
      checks to 15; six the PLAN's design would have re-keyed (`BD51b`, `BD54`,
      `BD58b`, `BP52`, `BP54`, `BP55`) stayed byte-identical, and that is the
      evidence for the ruling. `BP47b` pins the drift AND the survival, on
      literals rather than on "they are equal".
      **⚠ FOUR MORE PLAN ERRORS, EACH MEASURED.** (a) `BD67`'s prescribed
      `db_label $cur` throws `wrong # args` — the proc takes TWO. (b) `BD68`'s
      `{d:0 d:1}` and `BD70`'s `{d:0|g:}` name the WRONG DB: in the `i14` fixture
      the current DB is registry slot **1** (`BD31`/`BD31b`/`BD43` pin it), so
      every X check now derives its header id from the ENGINE and `BD67` asserts
      the derived index itself. (c) `BD65`'s id is backwards for that fixture.
      (d) The break-list names **2** existing checks and describes `BD51` in a
      form two-pane item 10 had already replaced; the real radius is **15**.
      **⚠ ONE VACUITY CAUGHT BY THE RED RUN, FIXED AND NOT EXCUSED.** `BD69` as
      first written asserted item 10's already-shipped box-OFF shape and PASSED
      before the code existed. Its reading became a CAPTURE folded into `BD68`'s
      own tuple as leg 1, and the `BD69` id was re-spent on a red-before claim —
      R5's guard that a search keystroke never re-opens a DB header the user
      collapsed. **`BD69` is the SOLE witness to the mirror defect** (opening the
      header on EVERY populate, the verifier's `VS2`); `BD70b` is the sole
      witness to the opposite one (`S6`, never opening it). Neither may be
      weakened. ⚠ `15_receipt.md` shipped one sentence misattributing `S6` to
      `BD69`; corrected in §7 after the verifier replayed `S6` verbatim.
      **⚠ TWO SPEC CLAUSES DIVERGED FROM, BOTH FLAGGED.** §4.1's "this is the
      single change in `browser_populate`" becomes two (the current DB's header
      is born open as well as its root, or R4's selected root sits inside a
      collapsed parent and §4.2 forbids `see` there — `BW53`); and §4.3's
      "unlabelled" clause is now stale. **Item 19 owns the spec edit.**
      **⚠ SIX DECLARED LIMITS, two of them asserted as VALUES in checks rather
      than only in prose** (`BP53` leg 4, `BD70d`). The one item 16+ should know:
      a persisted **DB-header** open state does not survive a registry renumber —
      §4.2 says the persisted `open` set wins and it named the old slot, so the
      header comes back COLLAPSED. Selection and instance-node collapse survive,
      which is the whole point of the unprefixed ids. **Next free `BD71` /
      `BP78`.**
- [x] 16 — R9: Ctrl-L → Ctrl-B, incl. the C-table row deletion **-> DONE
      (`08c37980`)**
      Receipt `16_receipt.md`. **Both baselines RE-MEASURED EXACT on the unchanged
      tree first** (headless 1637/0, X 11/11 2192, every per-file and per-suite
      figure), so every red is attributable. New file
      `tests/headless/test_wave_sigbrowser_keys.tcl`, band **BK01-BK18**,
      **NEXT FREE BK19** (BK20+ is item 17b's). Headless **1637 → 1649** over
      **15** files, X **2192 → 2215** over **12** suites; the whole delta is the
      new file (+12 / +23) and every other file and suite is byte-identical.
      **⚠ THREE out-of-baseline suites, not the two this LEDGER's item-16 NOTE
      names.** `test_key_graph_context.tcl` is in NEITHER baseline and is the one
      this item actually reds — twice. Pre/post ok-counts: bindings_file 13/13,
      keybindings_help 17/17, **key_graph_context 69 → 70**.
      **⚠ TWO PLAN CHECKS WERE VACUOUS AND WERE REPLACED.** `BK02` as prescribed
      searched a literal it had written itself (green before, after, and under
      the sabotage it was named for); it now EXTRACTS `set fwd [expr {…}]` from
      the source and EVALUATES it (red `1 1 0 1 1 1` → green `1 0 0 1 1 1`), with
      the membership claim moved to `BK03` on the LIVE `graphkeys`. `BK06` used
      `[xschem get sym_txt]`, which **does not exist** — it returns `""`, so the
      PLAN's landmine witness would have compared `""` to `""` and passed with
      sym_txt flipped. Everything reads `$::sym_txt`.
      **⚠ THE SABOTAGE THAT DECIDED THE ITEM.** `S1b'` keeps the carve-out text
      byte-identical and re-opens the 98 hole alone: `BK01`/`BK02` stay GREEN and
      **`BK12` reds `{1 1 1 0 1}`** — forwarded, `sym_txt` FLIPPED, `graph_flags`
      unmoved, i.e. the forward reached the C switch's ControlMask arm. Had it
      red nothing, the two behavioural checks would have been redundant with the
      source greps. `S3` (delete the bare-b idle row too) **TIMED OUT** — bare `b`
      falls through to the merge-schematic modal — which is why a sabotage filter
      MUST count TIMEOUT as a red; its isolating evidence was
      `test_key_graph_context:323` going red in the same run.
      **⚠ THE PLAN'S BREAK LIST IS WRONG TWICE.** It says S6 reds "GH1 alone";
      measured radius is **8 legs across 3 files** (GH1+GH3 headless, GH1+GH3+GH5
      +GH6 under X, BS09 ×2). And it never names `test_key_graph_context.tcl` at
      all, which is the item's real blast radius.
      **⚠ TWO DECLARED LIMITS, both from measurement.** (8) `graph_use_ctrl_key 1`
      users lose their only cursor-B chord (default is commented out; bare `b`
      measured still working, `graph_flags` 0 → 4). (9) Ctrl+b over a graph
      EMBEDDED IN A SCHEMATIC now toggles `sym_txt`, **measured 0 → 1** — a
      schematic-editor behaviour change no part of the PLAN mentions, pinned by an
      inverted check rather than left for the next reader to file as a bug.
      **⚠ REGENERATION TRAP.** `save_input_bindings_file` writes the LIVE table and
      the shipped csv is LOADED INTO IT at startup, so regenerating in place
      reproduces the deleted row **moved to the end of the file** — a diff that
      reads as harmless reordering. Move the csv aside and generate from the
      builtins. Spec §8.1 anchors corrected (all stale by ~+2300), its "nothing
      user-visible is lost" and "the schematic side is untouched" both replaced
      with the measurements, §10 gained limits 8 and 9, §13 gained the eighth file.
      **No eyeball owed** — every claim is a bind, a dump row, a byte-compare or a
      Tcl variable, and the menu accelerator is read at RUNTIME
      (`entrycget -accelerator`, sigbrowser`:543` + grid`:1107`), not as a source
      string.
      **⚠ 9/9 OF THE ITEM'S OWN SABOTAGES FIRE, PLUS TWO THE VERIFIER INVENTED,
      neither on the item's list.** `SV-A` — the likeliest half-done state, the C
      row still PRESENT **and** the csv correctly regenerated to match it, in
      which the VIEWER behaves perfectly and `BK12` cannot see a thing — reds
      `BK04`, `BK06`, `BK16` **and both** restated `test_key_graph_context`
      claims, so the C-table deletion is covered by **4 checks in 2 files**, not
      the 1 the PLAN predicted. `SV-B` — `($s & 4)` → `($s == 4)` in the
      carve-out, which would leak **Ctrl+Alt+b** and **NumLock+Ctrl+b** back to
      the C switch — reds `BK01` **alone**.
      **⚠ ONE OPEN COVERAGE NOTE, FOR 17b, WHICH OWNS `BK20+` IN THE SAME FILE:**
      `BK02` evaluates the shipped expression only over masks 0 and 4, so it
      cannot tell a bitmask test from an equality test. **Add the pair `{98 12}`**
      when next touching that file. The shipped code is correct; this is the
      oracle, not the behaviour.
      **⚠ DRIVER HAZARD, found by the verifier hitting it.** Restoring a `.c`
      from a `cp -p` backup and re-running `make` is a **NO-OP** — the preserved
      mtime is older than the `.o` the sabotage just built, so the binary keeps
      the SABOTAGED object and the "clean re-run" measures the sabotage. `touch`
      the file before rebuilding. **Item 17b touches C too.**
- [x] 17b — R10: `Ctrl-Alt-V` via the C action registry (the half `882694cc` left)
      **-> DONE (`c5a55dd8`)**
      Receipt `17b_receipt.md`. **Both baselines RE-MEASURED EXACT on the
      unchanged tree first** (headless 1649/0 over 15 files, X 12/12 = 2215,
      every per-file and per-suite figure byte-identical; the three
      out-of-baseline X-only suites 13/17/70), so every red is attributable.
      Headless **1649 → 1658** (`keys` 12 → **21**), X **2215 → 2230**
      (`keys` 23 → **35**, `i12` 123 → **126**); only the two files this item
      touches moved. Band **BK20-BK31** + **BX54-BX56**; **BK19 left UNSPENT**
      (reserved to item 16's file band). **NEXT FREE `BK32` / `BX57`.**
      **⚠ THE ACCELERATOR WAS A LIE BEFORE THIS ITEM.** Measured: `bind .drw
      <Control-Key-5>` is **EMPTY** in the shipped default profile —
      `cadence_style_rc` is opt-in — while the Tools cascade advertised `Ctrl+5`
      to everyone. R10 makes it true for every profile *and* remappable
      (`xschem bind` / `keybindings.csv`).
      **⚠ SEVEN literal `Ctrl-5` sites over FIVE files**, not the PLAN's "five
      coordinated edits" nor spec §8.2's "four": `cadence_style_rc:234,243,245`,
      `xschem.tcl:14942`, **`wave_viewer.tcl:9608`**, **`ase.tcl:1017`** and
      **`doc/waveform_viewer_guide.html:1094`** — the last three are named by
      neither document. The guide section is **§11.5** (`browser-hier`), not
      §11.4 as `17_receipt.md:92` says.
      **⚠ THE PLAN'S RED LIST IS WRONG IN BOTH DIRECTIONS.** It says
      `test_bindings_file` and `test_keybindings_help` red BY DESIGN — **they do
      not** when the item is done right (measured 13/13 and 17/17, and
      `test_key_graph_context` 70/70). Both are **LOCKSTEP TRIPWIRES**, proven to
      fire under sabotage (S1+S5 and S2a). And its "existing checks it reds" list
      misses **`BX11`, `BX12`, `BX43`, `BX44`** entirely; all four were found by
      grep and restated. `BX43` was driving a `bind .drw <Control-Key-5>` **the
      test itself installed** (the `BS46` shape) — retargeted through the shipped
      table, and its hand-installed bind deleted.
      **⚠ THE SABOTAGE PAIR THAT DECIDED THE ITEM.** `S2b` (registry row gone,
      `set_input_binding` kept) reds `BK22`, `BK23`, `BX54`, `BX55`, `BX56`,
      `BK31` while **`BK29` STAYS GREEN** — the live `bindings dump` **cannot see
      a missing registry row**, which is why the behavioural drive at `BX54` is
      not redundant with the table check. `S3` (bind it in `cadence_style_rc`
      instead) leaves `BK24`/`BK25`/`BK27`/`BK28` green: an rc bind is
      indistinguishable from a registry row **except through the un-bind**, which
      is what `BK31`/`BX55` exist for. **9/9 of the item's own sabotages fire**,
      plus the verifier's own — removing `ase::show_in_browser_for_current`'s
      `{win {}}` default arm, which **only `BX56` can see** (`BX43`/`BX54`/`BX55`
      install a spy that supplies the default itself) — red `BX56` alone, count
      held at 126.
      **⚠ TWO KEY-DISPATCH TRAPS, both measured, both now written into the
      tests.** (a) `event generate <Control-Alt-Key-v>` delivers state
      **131076**, not 12 — Tk's `Alt` pattern modifier is the virtual META bit;
      drive `<Control-Mod1-Key-v>` or `-state 12`. (b) `handle_key_press` looks a
      **printable** keysym up under `rstate` (`state & ~ShiftMask`), so the
      "inert" control state 5 became **Ctrl-v = clipboard paste**, whose MODAL
      dialog **hung the `i12` suite for ten minutes**. Near-miss control is
      **68** (Ctrl+Super); state 13 FIRES the chord, by the same stripping.
      **⚠ CONSEQUENCE, REPORTED NOT SMOOTHED:** that hang cost `BX56` its
      initial-red measurement. Its red evidence comes from sabotage `S2b` and
      from the verifier's own sabotage instead.
      **⚠ `handle_window_switching` does NOT fire on a KeyPress** (FocusIn /
      Expose / EnterNotify only, `callback.c:8497-8498`) — the PLAN's safety
      sentence for the argument-less Tcl command is imprecise. The context is
      right because the preceding Enter/Focus set it; corrected in the C comment.
      **⚠ SHIPPED CASE SPLIT, ON PURPOSE:** the Tools accelerator is
      `Ctrl+Alt+V` (house style, cf. `file.save_as_symbol`) and the generated
      cheat-sheet is `Ctrl+Alt+v` (`keybinding_chord_label` renders keysym 118
      through `%c`). `BK20`/`BK27` pin the first, `BK30` the second — **do not
      copy either literal into the other's check.**
      **⚠ REGENERATION, not hand-editing:** `keybindings.csv` was moved aside and
      produced from the builtins — 66 → 67 lines, the new row at 66, Alt-2 still
      last at 67 (item 16's §4.1 trap, honoured).
      **⚠ ONE UNEXPLAINED MEASUREMENT, DECLARED AND NOT ASSERTED.** A
      Ctrl+Alt+NumLock drive (state 28) recorded **one** spy call where the code
      says zero — `key_chord_has_binding` compares mods for EQUALITY and nothing
      strips `Mod2Mask`. The verifier read the same code and agrees. The leg was
      **removed** from `BX54` rather than pinned to a number nobody can explain.
      **⚠ CROSS-ITEM TRIPWIRE.** `BK29` leg 3 and `BK31` legs 3/5 pin
      `[llength [xschem bindings dump]]` at **72** (71 mid-unbind). Any future
      item that adds or removes ANY C binding reds this file. Deliberate — it was
      the only count oracle available — but items 18/19 will meet it.
      **⚠ ONE EYEBALL OWED, and it is NOT a pixel** (hence `[x]`, no queue row):
      a **physical Ctrl+Alt+V on the real `:0` display**. The whole X arm ran
      under Xvfb, which has no window manager and no compositor, so a
      desktop-environment **grab** of this specific chord is untestable here —
      and it is R10's chosen chord. One press after the handback.
- [E] 18 — R12: auto-tick, reveal, and say so **-> DONE-PIXEL (`91a3de1a`)**,
      on `6c887aed`. `[E]` and never `[x]`: the deliverable is a checkbox a human
      must see **ticked** and a tree that **triples on screen**. `BK38` and
      `BK43` assert the `-variable` and the accessor one refresh later — no check
      in this batch judges whether the `ttk::checkbutton` WIDGET renders ticked,
      nor whether 45 → 129 reads as **explained** rather than alarming in situ.
      The item and its fix-up both shipped saying "no eyeball owed"; **both
      verifiers rejected that sentence**, and it is corrected here and in
      `18_receipt.md` §12. Eyeball script: `18_receipt.md` §12.
      Receipt `18_receipt.md`. **Both baselines RE-MEASURED EXACT on the
      unchanged tree first** (headless 1658/0 every per-file figure exact; X 2230
      every per-suite figure exact) — except `BP77`, see the baseline block.
      `src/wave_viewer.tcl`: ONE arm in `browser_msg`, ONE in `browser_say`, and
      the R12 **pure probe** in `browser_show_path` between the walk and the
      shipped improve-or-restore. Headless **1658 → 1662** (`keys` 21 → **25**),
      X **2230 → 2243** (`keys` 35 → **48**); nothing else moved in either arm.
      The three out-of-baseline suites re-run by hand: **13 / 17 / 70**, unmoved
      (this item touches no C and no csv).
      **Band `BK32`-`BK42` — the PLAN's `BK40`-`BK49` was dead on arrival for the
      THIRD time in this batch, and internally inconsistent besides.**
      **NEXT FREE `BK44`** (`BK43` spent by the FIX-UP below). `BK19` still
      reserved and unspent.
      **RESTATED, NOT DELETED: `BW59` `{4 4 1 1}` → `{5 5 1 1}`** — the PLAN said
      "reds existing: none" for the THIRD time and was wrong for the third time.
      **THE RED RUN EARNED ITS KEEP AGAIN:** `BK39`/`BK40`/`BK42` were GREEN
      before the code existed (all three asserted only shipped behaviour) and
      were rewritten to carry a moving leg in the same tuple.
      **FIX-UP (verifier finding — the ONE decision point was UNPINNED).** The
      arm's full-resolution guard had no check: relaxing it to "any improvement"
      red NOTHING across both arms while flipping the box and tripling the tree
      45 → 129 with no mention of it in the status line. **`BK43`** (X-only)
      closes it — a dual pair in ONE tuple: the deeper-but-partial
      `x1.x1.xm1.zznosuch` must report the shipped `partial` at `g:x1.x1` with
      box **0** and tree **45**, while the fully-resolving `x1.x1.xm1` on the
      same fixture moments later ticks and grows the tree to **129**. Verified
      by sabotage: the relaxation now reds **exactly `BK43`** (49 checks, 1 fail,
      count held); turning the whole arm off reds `BK36`-`BK43` (so `BK43`'s
      positive half is a MOVING leg, not inertia); the behaviourally-invisible
      "bypass the checkbutton's -command" control still reds **exactly `BK35`**
      in both arms, which proves the driver mutated the loaded file.
      X **2243 → 2244** (`keys` 48 → **49**), headless **1662 unchanged**.
      **NEXT FREE `BK44`.**
      **⚠ THE FIX-UP'S VERIFIER PROVED THE HOLE WAS REAL AND TOTAL, rather than
      believing the claim.** It extracted the keys file **at `6c887aed`** (48
      checks, pre-repair) into a probe deliberately NOT named `test_*.tcl`, ran it
      under X twice — pristine **48/0**, and with the IDENTICAL relaxation on disk
      **48/0**. Zero reds. The repaired file reds `BK43` alone under the same
      mutation. Probe deleted, tree byte-clean.
      **⚠ A FOURTH SABOTAGE, THE VERIFIER'S OWN, ON AN AXIS NOBODY AIMED AT.**
      All three of the fix-up's sabotages aim at the GUARD; `MY1` aims at R12's
      LAST clause — *reveal, but never say so* (`set r12 1` → `0` in the merge, so
      the box still ticks and the tree still grows but the arm returns a plain
      `ok` and the sentence is never rendered). It reds **7 of the item's 8 X
      checks** (`BK36` `BK37` `BK39` `BK40` `BK41` `BK42` `BK43`, count held at
      49); **`BK38` correctly stays green** — it asserts only that the box is
      still ticked one refresh later, which is still true. So the "say so" axis is
      densely covered and `BK43`'s positive half is a MOVING leg under a sabotage
      the implementer never named.
      **⚠ THE `13 / 17 / 70` FIGURES ARE CONFIRMED, and the fix-up's contrary
      DECLARED LIMIT IS WRONG.** The fix-up declared those three out-of-baseline
      X-only suites "cannot be count-verified" because their `RESULT:` line
      carries no count. Measured: `xarm.sh one` prints one `ok:` line per check,
      and counting them gives **exactly 13 / 17 / 70**. **This LEDGER is the
      correct half**; `18_receipt.md` §14 is restated to match. The over-claim was
      in the conservative direction and blocked nothing.
      **⚠ ONE OPEN NOTE FOR ITEM 19, PRE-EXISTING AND NOT THIS ITEM'S DOING:**
      five ids in `test_wave_sigbrowser_keys.tcl` each carry **two** check calls —
      `BK14`, `BK15`, `BK18` (item 16) and `BK36`, `BK42` (item 18) — so a FAIL
      line naming `BK42` is ambiguous between the improve-or-restore control and
      the teardown, and the verifier had to read the values to tell which fired
      under `MY1`. `BK43` is a single call and does not add to the pattern.
      **7 sabotages, 7 fired**, incl. `S1b` proving the rejected confirm-guard
      shape is visible (refresh count 1 → **3**) and `S6` reddening `BW59`
      **under X** — a gap the headless-only sweep had missed.
      **DECLARED LIMITS:** the tick is kept only on a FULL resolution; the probe
      is current-DB only. **DIVERGENCES FOR ITEM 19:** §8.2's "prefix" is a
      complete sentence; §7.4's "is logged" describes a path with no
      `log_action`; §3.3's 44/128 is still 45/129.
- [x] 19 — Docs, oracles, the four-file lockstep, 0217 closed **-> DONE
      (`589d7424`, FIX-UP `b5a57db6`).**
      Receipt `19_receipt.md`. **BOTH BASELINES RE-MEASURED EXACT on the
      unchanged tree first**: headless **1662 / 0** over 15 files with every
      per-file figure identical to the block above; X **2244** over 12 suites
      with every per-suite figure identical; the three out-of-baseline X-only
      suites **13 / 17 / 70**.
      **AFTER: headless 1698 / 0** (`grid` 231 → **267**, +36; **every other
      file byte-identical**), **X 2281** (`grid` 356 → **392**, +36;
      `i1315` 190 → **191**, +1 for the X-only `BP78`; every other suite
      byte-identical), out-of-baseline **13 / 17 / 70 unmoved**.
      The +36 is attributable to the last check: `GS1` +19 (the contract list
      38 → 57), `GS2` +6 (the roster 23 → 29), `GS3` +2 (6 → 8 cited issues),
      `GS22`-`GS27` +6, `GH11` +2, `GH10` +1 (the guide's §11 rewrite adds one
      NEW distinct §-ref, §11.2 — 14 → 15).
      **BAND, MEASURED NOT TAKEN: the PLAN's `GS10`-`GS15` are ALL FIVE SPENT.**
      `GS` names two unrelated blocks inside `test_wave_grid.tcl` (the spec
      oracles GS0-GS3 and the grid-selection block GS0-GS14) **and** is owned by
      `test_wave_sigsearch.tcl` (GS01-GS21). Item 19 took **`GS22`-`GS27`**,
      plus **`GH11`** and **`BP78`** (both free, both reserved for this).
      **SIX PLAN BULLETS WERE ALREADY DONE and one was REFUSED.** Already done:
      0217 is tracked (`422b3f55`) and reads `Status: FIXED`; §5.4's hybrid rule;
      M6's 9-of-22; §10's limit 8 (there is a ninth); §11's `d:N|` FIXED row.
      **REFUSED: §14's "78→84, 278→303".** §3.3 already carries 84/303 and rules
      in writing that §14's 78/278 is a *different metric* — nodes minted only by
      device paths — in an audit of somebody else's awk. Executing that bullet
      injects an error. The refusal is now written into §14 so nobody executes it
      later.
      **THE PLAN'S GS10 LIST WOULD HAVE RED `GS1` TWICE.** It named
      `browser_tree` and `browser_sea`; MEASURED, neither exists — two-pane item
      1 never landed (`09_receipt.md:26-27`). Dropped from the list, and §12.1 is
      rewritten to record the accessor as never-introduced rather than as owed.
      **RESTATED, NEVER DELETED:** `GS0`'s floor `>= 20` → `>= 48` in place;
      `GS2`'s roster 23 → 29 (`sig_declass`, `browser_tree_rows`,
      `browser_class_filter`, `browser_level_names`, `browser_label`,
      `browser_flow_layout`).
      **THE RED RUN EARNED ITS KEEP: three checks were GREEN before the docs
      existed** — `GS25` and both `GH11` legs. They are **regression GUARDS** on
      two-pane items 14/16, declared as such in the file, each carrying its
      positive control in the SAME tuple, and their only positive evidence is the
      sabotage run. `BP78` likewise closes a coverage hole rather than pinning
      new code.
      **8 SABOTAGES RUN, 8 FIRED**, under a locked, trapped, pre-state-asserting
      driver whose filter counts `NORESULT`/`TIMEOUT`/`X connection broken` as
      reds. `S1` (a ghost contract line) reds **exactly one `GS1` leg, naming
      `browser_zznosuch`**, plus `GS23`'s exact ledger; count +1. `S2` (delete
      the item's 19 lines) reds `GS0`+`GS22`+`GS23`+4 `GS2` legs and the **count
      FALLS 267 → 248**. `S3` (the pre-two-pane §11 wording) reds `GS24` **and**
      `GS26` — they are not redundant. **THE FOUR-FILE LOCKSTEP, run four times
      and the PLAN's "BT09 *or* BX13" is neither an or nor one lever:** a 17th
      `data-seq` row in the guide reds `GH0`+`GH1`+`GH2`+**`BT09`** with **`BX13`
      GREEN**; bumping the literal in `test_wave_grid.tcl` reds `GH0`+**`BX13`**
      with `BT09` green; a 17th `data-bseq` row reds `GH8`×2 + `GH9`; deleting a
      `bind $f.` reds `GH8`+`GH9`+**`GH11`'s CONTROL** (both counters fall
      together, which is exactly why that floor is 16 and not the PLAN's 14).
      `S6` reds **`BP78` alone**, count held at 191.
      **⚠ `S5` FAILED ITS OWN PREDICTION AND `S5b` IS THE CORRECTION.** Rewriting
      an EXISTING bind through an alias reds `GH8`+`GH9`+`GH11` — because GH8's
      per-row leg greps the literal the rewrite deleted. That is **not** the hole.
      The hole is an **ADDED** gesture: `S5b` ships a new `bind $zzc <Button-4>`
      beside the sash bind, `$f.` stays 16, the guide stays 16, and **`GH11` reds
      ALONE with `GH8` and `GH9` GREEN** — that green pair IS the finding.
      **ONE SRC EDIT, COMMENT-ONLY, UNDER THE BD06 PROTOCOL.** The
      `tb_charge_pump` triple above `browser_class_filter` was wrong by exactly 9
      in every term (137/111/110). RE-MEASURED on the committed fixture:
      **1191 → 146 → 120, nets-only 119**; histogram net 120, srcbranch 26,
      devmeas 283, devnode 762. Corrected in the source comment **and** in
      two-pane §5.4-adjacent §6. Bare-name counts identical before and after
      (`browser_devint` 5, `browser_srccur` 5, `browser_alldbs` 2, `device
      internals to reach` 1) and `git diff` filtered to non-comment lines is
      **EMPTY**. `BW59` and `BD06` green.
      **NEW ISSUE `0225`** — `browser_target_path` mis-decodes `d:N|` All-DBs ids
      — filed and `git add`ed, FIXED by two-pane item 8, cited from the parent
      spec's §15 alongside **0217**. It had lived only as a paragraph inside
      `0217:190`. `GS3` now loops **8** issues, all resolving to exactly one file.
      **⚠ THE `:0` ARM IS UNRELIABLE TODAY AND THREE WHOLE-SUITE DEATHS WERE SEEN
      IN THIS SESSION** (`i12` + `i1315` pre-item, `sigbrowser` post-item), all
      carrying `X connection to :0 broken`, plus a `BP56` geometry-echo FAIL
      (240 vs 260 px) that passed on re-run, plus the documented
      `test_key_graph_context` 400 s TIMEOUT on its first batched attempt (70/0
      standalone, twice). **Every one re-ran clean at its baseline count**, and
      the two pre-item deaths were additionally re-measured under **Xvfb**
      (`i12` **126**, `i1315` **190**) to make the baseline attributable.
      **DIVERGENCES ITEM 18 HANDED ON, ALL THREE NOW CLOSED:** §3.3 gains the
      rows-vs-nodes sentence (44/128 **nodes**, 45/129 **rows**); §8.2's "prefix"
      is corrected to "a whole `browser_msg` arm, not a prefix" (`BK37` pins the
      string byte-exact); §7.4's "is logged" is corrected to **no log line at
      all** — the auto-tick calls `browser_devint` directly and that accessor has
      no `log_action`.
      **DECLARED LIMITS:** the `.ph` count line is **still class-filter blind**
      and still belongs to §7.2's three-state caption — recorded, not moved;
      `browser_show_path`'s bar clause is still stale and still not item 19's;
      **nothing in this batch is visually verified** — the eyeball queue below
      keeps its four unticked rows.
      **⚠⚠ REJECTED BY ITS VERIFIER ON TWO REAL FINDINGS, THEN FIXED UP
      (`b5a57db6`) AND ACCEPTED.** (1) **The item's own thesis failed on the
      item's own delivered prose:** reverting the guide's §11.7 *"What is
      remembered"* wholesale to its pre-two-pane single-pane wording — dropping
      the sash split, **both** class-box names and the whole fraction-vs-pixels
      paragraph — left **all four** guide-reading suites ALL PASS with **every
      count unchanged** (grid 267, sigbrowser 135, i12 40, keys 25). §11.7 is the
      ONLY user-facing doc of two-pane item 14's feature. `GS24` asks the WHOLE
      FILE and all four phrases also occur in §11.0/§11.2 (measured: with §11.7
      gutted, `Show source currents` still greps **2**); `GS26` pins the Ctrl-B
      prose; `GH10` counts headings. **`GS28`** (5 legs) closes it, section-scoped
      via `bs_section` + `bs_flat` — `bs_flat` is REQUIRED, not cosmetic, because
      the guide hard-wraps `<b>Show device\ninternals</b>` so that phrase exists
      nowhere in the raw bytes. (2) **A corrected number survived as a stale copy
      415 lines up in the same file:** §0's motivation table still read
      `| tb_charge_pump | 1191 | 110 |`; corrected to **119** and pinned by
      **`GS29`**, a **within-file agreement** oracle (§0's row must equal §5.4's
      `nets-only **N**`, `tb_bandgap` as positive control). Two minor overclaims
      narrowed rather than argued away: `GH11`'s limit → *"every bind spelled from
      a lower-case-initial variable is counted"*, and `GS22` **retitled** (the
      roster is 17 hand-picked names). **+7 checks, same +7 in both arms**;
      **6 sabotages, 6 fired exactly on target**, incl. a faithful replay of the
      verifier's own revert. **The first `SAB-B` attempt was a DRIVER bug caught
      by the COUNT, not the fail total** — an `&sect;8` where the guide has a
      literal `§8` occurring exactly once file-wide, inside §11.7, so `GH10` lost
      a leg and grid fell 274 → **273**: the right check red for the wrong reason.
      **⚠ THE FIX-UP'S VERIFIER RE-MEASURED BOTH ARMS BY HAND AND CLOSED THE ONE
      NUMBER THE FIX-UP DECLARED UNMEASURABLE.** `test_wave_sigbrowser_i12`
      answered **126 ALL PASS under `:0` on the first try**, so the X arm is
      **12/12 = 2287**, not the fix-up's "11/12 = 2162", and `2244 + 36 + 7`
      reconciles **exactly**. It also attributed the `+7` by checking out
      `589d7424`'s `test_wave_grid.tcl` (**267 / 0**, restored byte-identical),
      replayed the §11.7 revert from `git show c5a55dd8:` (four `GS28` legs red
      ALONE, control green, count HELD at 274, guide §-markers held at 24 — so
      **not** the implementer's `&sect;` driver bug), replayed the stale `110`
      (`GS29` red ALONE), and **re-derived 119 independently** with the shipped
      procs (net 120 / srcbranch 26 / devmeas 283 / devnode 762 = 1191;
      `browser_class_filter 0 0` = 120, all class `net`, minus the sweep variable
      `time` = **119**).
      **⚠ TWO OPEN NOTES FROM THE FIX-UP'S VERIFIER, BOTH FROM ITS OWN FRESH
      SABOTAGES, NEITHER ON ANYBODY'S LIST — RECORDED, NOT FIXED.**
      (a) **`GS29` CANNOT SEE THE THIRD SITE.** The stale triple lived in
      **three** places and `GS29` is a within-file oracle over **two**; rotting
      `src/wave_viewer.tcl`'s `browser_class_filter` comment back to
      `1191 -> 137 -> 111, nets-only 110` — **the one site item 19 actually edited
      in source** — leaves **all 15 headless files GREEN with every count exact**.
      Honestly scoped in the check title ("elsewhere in the same file"), but the
      commit and receipt prose read broader than the check is. **It belongs in
      declared limits and is now written into `19_receipt.md` §9 as limit 11.**
      (b) **§14's device-node counts have NO doc oracle**: reverting the spec's
      `303 → 278` / `84 → 78` rows reds nothing. Severity low — `TP35` pins 84 and
      303 against the committed fixture in code, so only the prose can rot, and it
      would then disagree with a green check — but it is one section away from the
      finding that got the item rejected.
      **⚠ A NEW OVERCLAIM INSIDE THE FIX FOR THE OLD OVERCLAIM, MEASURED:**
      `GS22`'s new comment says the batch's other minted procs are "covered only
      INDIRECTLY, by `GS23`'s exact 57". **28 procs minted by two-pane item 11**
      (the whole `browser_sea_draw` / `_hit` / `_click` / `_colw` / `_rowh` /
      `_canvas` / `_configure` / `_label` / `_own` / `_extend` / `_say` /
      `_toggle` / `_descend_to` / `_copy_names` / `_sel_names` / `_target_path` /
      `_send_to_add_trace` / `_plot_at` / `_plot_idx` / `_menu_build` / `_ids` /
      `_post` / `_unpost` / `_tip` family) appear **nowhere** in the parent spec,
      so `GS23`'s 57 does not cover them either. The 57-name list is plainly a
      **curated public-surface contract** — a defensible shipped reality — but the
      PLAN's chartered "every proc this batch minted is named" is **not literally
      met**. One sentence, not a rework.
      **⚠ THREE OF THE FIX-UP'S OWN FIGURES CORRECTED BY MEASUREMENT, none a
      defect.** (a) X is **12/12 = 2287** (2288 when `i1315`'s **gated** `BP56`
      pixel leg runs), not 11/12 = 2162. (b) **`i1315`'s X count is not stably
      191** — 190 and 191 were both observed on consecutive standalone runs of
      **identical bytes**, because `BP56`'s leg is gated; the baseline's 190 and
      the item's 191 are both real. (c) *"`test_key_graph_context` did NOT stall
      this session"* was **luck, not a property** — it stalled and emitted fails on
      the verifier's first attempt and answered **70 ALL PASS** on re-run, exactly
      as this baseline predicts.
      **⚠ THE VERIFIER'S OWN DRIVER BIT IT, AND IT IS THE TRAP THIS DISCIPLINE
      NAMES.** Its sabotage harness re-took the backup **after** the first
      mutation on a twice-patched file, so the restore left two mutations on disk
      while printing *"byte-identical: True"* and the post-restore suite run came
      back **fully green**. Only `git status` caught it. The X arm had already run
      with that residue; both mutations were ones it had **just proved red nothing
      anywhere**, both files were restored from `git show HEAD:`, and
      `test_wave_grid` was re-measured clean on both arms (**274 / 399**). Final
      tree byte-identical to `HEAD`. **No measurement is contaminated.**
      **FLAKES HIT AND RE-RUN, none a regression, all pre-documented:**
      `test_wave_sigbrowser` `NORESULT` inside the batched X sweep → **353 ALL
      PASS** standalone; **`MG13`** in `test_wave_modes` → **488 ALL PASS**
      standalone (key-delivery class, sibling of the listed `MG16`); **`BP77`** in
      `i1315` (the listed `:0` geometry echo). Non-baseline fails: **NONE**.

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

⚠ **THE ITEM-19 FIX-UP TICKED NOTHING AND OWES ITEM 14's ROW HARDER THAN BEFORE.**
`GS28` now pins the *words* of the guide's §11.7 — that it still claims the sash
split and both class boxes are remembered as a **proportion** rather than pixels.
It cannot tell whether any of that is **true**. An oracle on prose makes the
prose stop rotting; only item 14's row below can say the prose is not confidently
describing a feature that does not work. Four rows remain unticked: **18, 15, 14,
13.**

| item | commit | what to look at | eyeballed? |
|---|---|---|---|
| 18 | `6c887aed` + `91a3de1a` | With **Show device internals OFF**, select a **MOSFET instance** on the schematic and press **Ctrl+Alt+V**. Three things must be true *at once*: (a) the **checkbox is visibly ticked** — the widget, not the variable; (b) the tree grew **45 → 129** rows and scrolled to that instance, selected, expander still **CLOSED**; (c) the status line reads *"showing device internals to reach `<path>`"*, so the tripling reads as **explained, not alarming**. Then ask for a path that is **deeper but still partial** (`<inst>.zznosuch`): the box must stay **UNTICKED**, the tree stay at **45**, and the sentence be the shipped *"no signals under … - showing … instead"*. Full script: `18_receipt.md` §12. **A `net`-classed instance answers nothing** — with no hidden device node the probe correctly says "no" and the shipped path runs. | ☐ |
| 16 | *(this item)* | **NONE OWED.** Every claim is a bind, a `xschem bindings dump` row, a file byte-compare or a Tcl variable — there is no pixel deliverable. The one thing a human might still want to *feel* is the chord itself: press **Ctrl-B** over a plotted strip and confirm the sidebar toggles and the symbol text on the schematic behind it does **not** change. That is `BK12`+`BK18` restated in fingers, not a gap in coverage. | n/a |
| 15 | `e1cfd5ff` | With **two raws loaded**, tick the **All-DBs** box. The tree's TOP LEVEL must become one row per database — **the current one included** — and each header must carry that database's **own** design root, named for **its own** raw (not the current design's name under a foreign header). The current DB's header **and** root come back **OPEN**; the foreign header stays **COLLAPSED**. Then collapse a header by hand and **type in the search bar** — it must stay collapsed. Judge indentation, nesting legibility and label truncation on a **real** raw path. Full script: `15_receipt.md` §11. **A one-DB tree answers nothing**, and neither does the box left OFF. | ☐ |
| 14 | *(this item)* | Drag the **sash** small, tick **Show device internals**, save/quit/reopen: both must come back. Then reopen into a **shorter** window — the sash must return to the same *proportion*, not the same pixel row. A window you never drag must have **no `browser` key** in its state at all. Full script: `14_receipt.md` §7.7. | ☐ |
| 13 | `24fb6769` + `9d5cdd26` | **Tools → Show in Signal Browser** (**Ctrl+Alt+V** since two-pane item 17b, `c5a55dd8`; the old Ctrl+5 no longer exists) with an instance that **CONTAINS other instances** selected. (a) the tree row scrolls in, is selected, expander stays **CLOSED**; (b) the LOWER pane fills with **that node's own-level signals**; (c) clicking the expander still opens it. Full script: `13_receipt.md` §9. **A LEAF instance answers nothing** — that node class is exactly where the batch's checks were blind. | ☐ |

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
* ~~**`.ph` is still class-filter blind.**~~ **MEASURED BY TWO-PANE ITEM 18 AND
  IT NEEDED NO MOVE.** The shipped `browser_msg` sentence has always landed on
  `.ph` (`browser_status` writes `"Signal Browser\n$msg"`; `browser_say` calls it
  on every branch), and `browser_sea_refresh` writes `$f.pw.sea.st`, never `.ph`.
  So `BK37` asserts the new sentence there **byte-exact** and the twelve
  byte-identity pins are untouched. The class-filter blindness of the *count*
  line is unchanged and still belongs to §7.2's three-state caption — which is
  still nobody's but item 19's or a later item's.
* **Item 12's build-time default pin is `BW24`, not `BW56`.** ~~If item 14 makes
  the defaults come from a persisted file, `BW24` is the check to restate.~~
  **It did not**: `browser_build` still seeds `0`/`1` and only an applied state
  dict overrides. `BW24` is green untouched, and that is the record of the
  decision rather than an oversight.
