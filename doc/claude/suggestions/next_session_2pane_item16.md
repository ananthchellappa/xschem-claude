> ⚠ **HISTORICAL — THE ITEM WAS RENUMBERED AFTER THIS PROMPT WAS WRITTEN.**
> What this file calls "item 16" is now **two-pane item 20**, and its work order
> is `doc/claude/signal_browser_2pane_batch/ITEM20_label_filter.md` (was
> `ITEM16_label_filter.md`); the receipt is `20_receipt.md`. The number 16 was
> already taken twice — single-pane item 16 (docs, shipped) and two-pane item 16
> (R9, Ctrl-L → Ctrl-B, unstarted). This file is left as the dated record of what
> was asked; the numbering rule is in the two-pane `PLAN.md` header.

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

Implement the **two-pane Signal Browser, item 16 — THE BARS FILTER WHAT THE USER SEES**,
and pay item 11's one outstanding debt.
The scoping is DONE and every ruling in it is TAKEN — do not re-open them.

## READ FIRST

**`doc/claude/signal_browser_2pane_batch/ITEM16_label_filter.md`** (commit `2f7d45d6`) is
the work order. It carries the design, the measurements, the per-site blast radius, the
rebuilt discriminator and the sabotage list. This prompt does not repeat it — it tells you
where you are standing and what will bite.

Then `11_receipt.md` §4 (two traps) and §8 (found, not fixed).

## WHERE YOU ARE

Items 1-11 are DONE and **PUSHED** — `github/fluid-editing` = `14d8bdb8`. The only
unpushed commit is `2f7d45d6`, the work order itself. **Commit when green; DO NOT PUSH**
unless told.

**Baselines to reproduce before you touch anything:**

* Headless **1602**, fourteen files, zero failures:
  sigsearch 139, sea 6, sigbrowser 135, 2pane 108, panes 14, i11 50, i12 32, i1315 80,
  i14 47, grid 229, modes 212, viewer 57, markers 437, tabs 56.
* X arm **11/11**: panes 53, sigbrowser 352, **sea 66**, i11 74, i12 101, i1315 167,
  i14 86, 2pane 108, sigsearch 226, grid 354, modes 485.

Two known flakes, NOT regressions, neither of which appeared last session: `BR25` (a
`<Return>` through a bare `event generate`, ~1 in 5) and a whole-suite `NORESULT` from the
WSLg Xwayland death (`X connection to :0 broken`). Both pass on re-run.
**Re-verify the X server first** — `timeout 15 xdpyinfo -display :0` must return 0.

## ⚠⚠ THE THREE THINGS THAT WILL BITE

**1. `GSO01`-`GSO06` IS A 10,340-COMPARISON DIFFERENTIAL ORACLE.**
`test_wave_sigsearch.tcl` runs a frozen `git show afdd44a0^` copy of
`graph_get_signal_list` against the live one over 52 names × 94 patterns × 2 sorts, **zero
permitted differences**. Any *semantic* change inside `sig_match` reds it. Adding an
option that defaults to identity is not semantic — **prove that by running it, do not
assume it.** It is the whole reason item 16 adds `-key` instead of rewriting the match
loop.

**2. THE OPTIONAL-ARGUMENT SHAPE IS THE RULING, NOT A STYLE CHOICE.**
`browser_and` / `browser_match_one` are pinned as PURE procs by **BT14 (5 checks), BT15
(3), BT16 (4)** — all calling them directly with RAW patterns against a RAW list. Make the
label transform unconditional and those twelve move for no reason. Keyed optional and
defaulted, they stay green **by construction**. The sabotage "make the key unconditional
in `browser_match_one`" exists to prove that; run it.

**3. `-type` STAYS ON THE RAW NAME.** `sig_type` reads the `v(`/`i(` prefix, which the
label deliberately destroys (a current renders `v1:i`). SM12/SM13/SM14, AT12, BAR11/15/16/
17/27/28 and BP43/BP45/BP49/BP50/BP57 all depend on it. Key the type filter off the label
too and all of them red — which is a sabotage in the work order, not a plan.

## THE WORK

`ITEM16_label_filter.md` §4 is the scope, §5 the ~16 checks that move, §6 the rebuilt
BT25/BT26/BT27 discriminator (**already solved and measured**: `net*` 4 of 8 ∧ `*:i` 2 of
8 → AND 1, giving 8/4/2/1 from two label-only patterns), §7 the RED-first order, §8 the
five sabotages.

### AND THE DEBT ITEM 11 DID NOT PAY — one, and it is not optional

**The sea has no hover tooltip.** `PLAN.md` item 11's scope names *"Tooltip on hover shows
`browser_label_full`"*; nothing binds `<Motion>` on `$f.pw.sea.c`. Seven binds, not eight.
An acknowledged MISS, not a deferral, recorded in `11_receipt.md` §8.

It belongs in this item because it is the same defect wearing the other sign: the pane
shows a label and gives the user no way to see the name behind it. Landing it here means
**GH8's literal goes `14` → `15`** and the guide gains one more `data-bseq` row — bump the
ledger in the SAME commit as the bind and the row, never separately.

**Commit it separately from the filter change.** Two commits, two attributions.

## HOUSE RULES THAT HAVE BITTEN EVERY SESSION IN THIS BATCH

* Headless: `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>` from the
  repo ROOT; scripts end in `exit 0`.
* X arm: `tests/headless/run_suites.sh` under one **`Allow 2h`** press — never a bare
  `for` loop. `SUITE_TIMEOUT=400`. If `~/.claude/gui_test_gate/control` says `PAUSE`,
  nothing starts; that is the user's authority, ask rather than override.
* **⚠ A SHORTFALL IN THE CHECK COUNT IS THE ONLY WITNESS TO VACUITY.** Item 10's change
  silently stopped 43 checks running and the file reported a plausible 276 instead of 319
  — zero failures, six `SKIPPED:` banners. **Diff the COUNT, never just the fail count**,
  on every run and after every sabotage.
* **⚠⚠ `event generate` STAMPS TIME 0.** Tk's double-click detector compares the event's
  TIME field, so any two presses at one spot are a Double and the second goes to
  `<Double-Button-1>`. `after` does not help — wall-clock is not what Tk compares.
  `bs_sea_click` carries an increasing `-time`; `bs_sea_dclick` deliberately shares one.
  If you write a new gesture helper, carry the stamp.
* **⚠ ttk fires `<<TreeviewSelect>>` on EVERY `selection set`, even an unchanged one.**
  Measured. It is why `browser_refresh`'s tail call had no witness until BQ66b unbound the
  other route to make one.
* **`bs_type` needs its focus loop** — Tk routes KEY events to the toplevel's focus
  widget, not to the window named in `event generate`. Without it the bar HOLDS the
  pattern, the helper ANSWERS it, and `browser_refresh` runs ZERO times while every claim
  goes green. `<Button-1>` has no such problem.
* **`pcall` returns the STRING `ERR:<msg>`.** `expr` on it THROWS past the check into the
  outer catch, deleting every remaining check; `lsearch` on it answers -1, so `< 0` goes
  **green on a failed read**. Use `bs_num`/`bs_set` or assertable sentinels — three shapes
  minimum.
* **Expected literals are STRING REPS, not nested lists.** `[list {g:} 0]` is `g: 0`.
  Build every expectation with `[list …]`.
* **A check that passes before you wrote the code is a check to stop and look at.**
* **`begin {…}` is not a proc.** Named helpers, and they must RESTORE what they changed.
* **Do not renumber.** Item 10 spent `BW40`-`BW53`; item 11 spent `BQ50`-`BQ68`. ⚠ PLAN
  gives item 13 `BW53/BW54/BW55` — already gone; item 13 must re-band.
* Never `make` while suites run. `MG13` and `test_ase_plot` P4/P6/P8 are known flakes.
* Measure, don't reason. Every line number in every doc has drifted at least once.

## START BY

Confirming the X server is alive, re-measuring headless **1602**, then running the X arm
on the UNCHANGED tree to confirm 11/11 — so that every red after that is yours. Then write
the `BQ70`-band RED (work order §7.1) before touching `sig_match`.

## CORPUS — use these, do not invent counts

`tests/headless/fixtures/tb_bandgap_vars.txt` (424) and `tb_charge_pump_vars.txt` (1191).
Measured against the SHIPPED pipeline, not copied from the PLAN:

| fact | value |
|---|---|
| class-filtered (`0 1`) | **190** of 424 |
| own level at the design root / at `x1` | **18** / **43** |
| recursive under `x1` | **172** (⚠ PLAN's 406 is the PRE-class-filter figure) |
| tree rows | **45** = 44 instance nodes + the design root |
| nodes rendering empty | **12** pure ancestors |
| at `x1`: `net*` raw / label | **0** / **26** |
| at `x1`: `net1*` raw / label | **0** / **11** |
| within-level label collisions | **0** on both corpora |
| raw names containing `[` | 0 of 424 bandgap, **292 of 1191** charge pump |

⚠ `string match {i(@c.x1.c1[i])}` against itself is **0** — `[i]` is a character class.
That is the measurement that says the raw-name paste path is already broken and does not
need preserving.

## WHAT THIS ITEM IS NOT

* Not the tree. §7.1 already scopes both bars to the lower pane; `x1*` matching a NODE is
  a separate question with its own rulings.
* Not a `raw:` escape hatch and not a label-OR-raw union — both rejected in §4.4, with the
  reason recorded.
* Not item 12. The checkboxes stay inert; the hardcoded `0 1` in `browser_refresh`'s two
  `browser_class_filter` calls is item 12's to replace.
