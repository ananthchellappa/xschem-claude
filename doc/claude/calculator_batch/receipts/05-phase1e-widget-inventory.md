# Item 05 — phase 1e: the W01–W34 / R101–R113 widget inventory sweep, and the eyeball

Closing receipt. Ledger row 5; PLAN **1.9 + 1.10**, the last phase-1 item. Spec §4 (W01–W34), §4.1
(R110–R113a), §5.1 R202, §7.1, R413, R507–R509, RULING-1/2/3, catalogue defects D1/D3.
**Verdict `[E]`** — Part B is a capture and a written side-by-side, which only a human eye closes. Long form: `05-phase1e.md` (fix-round log in §7); per-check sabotage map: `05-phase1e-sabotage-map.md`.

## 1. Files changed

```
 doc/claude/specs/calculator.md       |  41 +++++++++++++++++++++++++++++-----   (36 insertions, 5 deletions)
 tests/headless/test_calc_widgets.tcl | 1467 ++++++++++++++++++++++++++++++++   (new file, 244 checks)
```
Also committed: this receipt, `05-phase1e.md` (323 lines), `05-phase1e-sabotage-map.md` (188),
`05-phase1e.png` (658x737). **`src/calculator.tcl` is BYTE-IDENTICAL to HEAD** —
`70933f40d903bac498050f32468e8c21` = `git show HEAD:src/calculator.tcl`, re-verified after each of the
133 sabotage restores and at commit time; no W-row's widget was missing, so no inert control had to be
added. **No rebuild** (sourced at runtime, `xschem.tcl:14381`). `LEDGER.md`, `recon/`, `ref/` and
every other dirty path in this tree: untouched and unstaged.

## 2. Decisions taken, and the evidence

| ruling | evidence / why | written into |
|---|---|---|
| **The brief's "`calc::selmode` … is initialised (never the empty string)" is THREE facts, only one of them `{}`-shaped.** `{}` stays the normative *unarmed* value (W07, R201); what may never be empty is the **`-tristatevalue`**; "initialised" means **seeded before the first radiobutton exists**. | asserting "selmode is never `{}`" would have required breaking R201. The seeding rule is the browser's own (`wave_viewer.tcl:8051-8082`): a `-variable` that does not exist yet is minted by the widget at its off value, so nothing can then tell "deliberately unarmed" from "happened to be empty" | **spec §4 W07**; CW3 asserts all three separately |
| **R111 gains the function browser.** The rule named *widgets* and predates the pane tree; growth is a property of *panes*. | the build carries `.calc.pw.sel never`, `.buf`/`.stk` `always`, `.bot always`, `.bot.pad never` — every clause holds except the row it never mentioned. Pinning the browser instead would leave 56 entries in an eight-row box, which is what **R112** forbids. **No code changed**: the alternative was a phase-0 layout edit this item may not make | **spec §4.1 R111**; CW11 |
| **R111's keypad clause is finished, not dropped** (fix round): only the keypad's **width** and its **keys'** height are pinned; the frame grows with `.calc.pw.bot`. | measured on `:99`: `.calc.pad` 198 px at first open against `reqheight` 115, **345 px** at 900x1000, `.calc.pad.k1` 21 px throughout. The growth is the same `.bot -stretch always` that feeds the browser. The empty band stays item 4's **look debt**, not a frozen-layout edit | **spec §4.1 R111**; CW11 ×4 (`SF12`/`SF13` redden one leg each) |
| **R113 is proved by MOVING THE SOURCE, never by comparing two colours** — and the proof is a **walk**, not a table (fix round). | a check reading `cget -background` against `ase::palette panel` is equally green for a hardcoded `#f2f2f2`: `SF25` paints `.calc.mode` the palette's own `#f2f2f2` and the value comparison stays true while CW12 goes red. The 22-row table left **73 of 91 widgets** and every `-active*`/`-highlight*`/`-disabled*` option outside the proof; the walk covers **91 widgets / 580 colour options / 326 palette-fed** | **spec §11.3** test-table note; CW12 |
| **`winfo exists` + class + `cget` is not evidence a control is ON SCREEN** (fix round). | `SF1` (delete `pack .calc.mode.clip`) was `ALL PASS` in **both** calculator suites before the fix — including `W10 Clip is CHECKED at first open`, the check PLAN 1.9 names as this suite's marquee sabotage. CW2 now asserts `winfo manager` + `winfo ismapped` per W-row (`.calc.mbar` exempted by name) and the ordered slave list of all nine containers | **spec §11.3** note (3); CW2 ×12 |
| **R110 is NOT a phase-1 gap.** The View cascade exists with its disabled placeholder; per-panel collapse is PLAN 10.1. | the phase rule is "inert is allowed, absent is not" — the inert control is there. The one collapse that IS implemented (W03's toggle) is asserted instead | CW11; §5 below |
| **This file is an inventory, not a second geometry suite.** | `test_calc_skeleton` S11/S19/S21/S22/S23/S25 owns pixels, sash fractions, the derived minimum and the wheel. Proof it is a boundary and not a hole: `B75` and `SF26` redden **nothing here** and redden **S23** (2 checks) in the skeleton — measured both times | file header; **spec §11.3**; §4 below |

## 3. Tests

`tests/headless/test_calc_widgets.tcl` — **new**, **244 checks** in bands **CW1–CW13** (the W-row and
R-rule ids are the check names). Grepped both files: `test_calc_skeleton` uses `S1`–`S26` only and
carries no `W`/`R1`/`CW`/`§` id, so the bands do not collide; 244 `ok:` lines, 244 distinct names.
**`test_calc_skeleton` is untouched** — still 503 checks, nothing renumbered, deleted or weakened.

Verbatim, `run_suites.sh` on `:99`, identical on a direct `devdisplay.sh exec` run:
**`RESULT: ALL PASS (244 checks)`**. **Non-vacuity** with `99a2edfd:src/calculator.tcl` (phase 0) in
place: `RESULT: 213 FAILED (31 passed)`, **all 244 checks running**, no group aborting; the 31
survivors are phase-0's own features restated. `--nogui`: `RESULT: SKIP (no X: …)`, rc 0 — a
whole-file skip, never a per-group one; ends in `exit 0`.

**Audit diff vs `receipts/00b-audit-baseline-2026-08-14.txt`, by NAME and STATUS, both directions:**

| suite | baseline | this run |
|---|---|---|
| `test_calc_skeleton` | PASS | PASS (503) |
| `test_wave_viewer` | PASS | PASS (400) |
| `test_wave_trace_menu` | PASS | PASS (397) |
| `test_accelerators`, `test_bindings_file` | PASS | PASS |
| `test_ase_window` | **FAIL** | **FAIL** — the identical single line `W7 simulator produced output before Stop -> {0} (exp {1})`, recorded by items 1/2/13 |
| `test_calc_widgets` | *absent — NEW file, not a regression* | PASS (244) |

**NOTHING MOVED IN EITHER DIRECTION. No test went red that is not red at baseline.**
`full_audit.sh` was not run — item 99 owns it.

## 4. Sabotage

**133 breaks** (107 first pass + `SF1`–`SF26` fix round), each applied to a byte-exact copy of
`src/calculator.tcl`, run on `:99`, reverted from that copy (never `git checkout --`), md5 re-verified
after each. **The per-check mapping is the committed companion `05-phase1e-sabotage-map.md`** — one row
per sabotage naming *every* check it reddened, covering **240 of the 244**; too long to inline at 120
lines, so the families below index it and the 4 checks with **no** row are named underneath.

| check family (band) | what was broken | red? | green after restore? |
|---|---|---|---|
| CW2 existence/class, all 44 singleton legs + the 22/12/4 loops | each of the seven `build_*` procs returns early; the whole toplevel never built; single rows deleted (`me`, `dft`) | yes (9–188 each) | yes |
| CW2 **managed / MAPPED / slave order** ×12 (the fix round's headline) | `pack .calc.mode.clip`, `pack .calc.status.hist`, `grid .calc.fn.hsb`, `grid …stk.recall`, `…sel.data`, `…pad.u4` deleted; strip and toolbar re-ordered; `.calc configure -menu {}` | yes (`SF1`–`SF11`; 1–3 each, order legs redden **alone**) | yes |
| CW3 initial state (incl. **PLAN 1.9's mandated `set clip 1 → 0`**) | Clip → 0, `-onvalue 2`, dest → Replace, category → Arithmetic, a selector pre-armed, pickscope → wave, a seeded status line, undo/redo left enabled, five `readonly`s dropped | yes — `B1` reddens **exactly** `W10 Clip is CHECKED at first open`, 243 green | yes |
| CW3/CW9 labels and sets; CW3/CW5 selector grid + R202 | Pop/M+/ME/Push/user relabelled; the toolbar's ten, the six cascades, §7.1's categories, the twelve keys altered; a **digit** added to the pad (RULING-2); private radio variable; `-value` ≠ id; tristate sentinel back to `{}`; `mp`/RF un-disabled; the refusal bind and the tooltips deleted; a refusal that arms | yes | yes |
| CW8 RULING-3 / D1 / D3 / R413; CW10 R507–R509 | `fn_dead_routes` forgets `N`; everything drawn live; the refusal emptied and de-named; D1 and D3 re-introduced; hover writes a fixed string; cap → 60; `linsert`→`lappend`; `record` ignored; the empty-string arm deleted; recall re-records | yes (`SF23`/`SF24` redden **alone**) | yes |
| CW11 R110/R111/R112/R112a | six `paneconfigure` flips; status bar packed into a pane; `wm minsize` constant; wheel walk deleted, `break` dropped, combobox exclusion removed; `.calc.pad -expand 0`; keys `-sticky nsew` | yes (`SF12`–`SF15`) | yes |
| CW12 **R113/R113a** | `.calc.sel`/`.calc.mode` hand-painted literals; **16 `-activebackground` → `grey85`**; 3 `-highlightbackground` → `gray70`; `.calc.res.lab` → `red`/`blue`; a **cached** palette read carrying no literal at all (`SF21`/`SF22`); an unresolved source defaulting; the state map dropped | yes (`SF18`–`SF22`, `SF25`; three of these were `ALL PASS (226)` before the fix round) | yes |
| CW13 inertness | `calc::inert` stops speaking; a key writes the buffer; a selector wired to a later phase; the toggle loses its command | yes | yes |

**Reddened nothing, recorded rather than hidden:** `B71` (a no-op on the product — `results_refresh`
rewrites that label four lines later; `B71b` covers the check), `B75` and `SF26` (both owned by
`test_calc_skeleton` S23, verified by running it: `2 FAILED (501 passed)`; `SF26`'s two checks were
renamed to say they call `calc::fn_click`/`calc::fn_hover` and that the canvas **wiring** is S23's),
`C6b` (Tk mints a missing `-variable` — the trap W07's seeding rule names), `SF16`/`SF17` (aimed at the
restore guard below).

**UNSABOTAGED — NOT EVIDENCE (4 of 244):** `R101 no .calc before the first open` (a precondition on the
process); `W07 ::calc::selmode exists (seeded, not minted by a widget)` (see `C6b`); `R113 fixture: the
running calculator.tcl was located` (asserts the test found the file it reads); `R111 …and the window
went back to the size the rest of this file measures` (a restore guard; `SF14`–`SF17` left it green or
reddened its neighbours). One further check is **structurally weak** and says so in the file: `R113 no
role resolves to the empty string` cannot be reddened alone — `calc::palette` *throws* first (`B52`).

## 5. What was NOT verified

- **THE PIXELS — the whole reason the verdict is `[E]`.** `05-phase1e.png` is the first-open window on
  `:99`: client area **656x680** (`wm geometry .calc`), committed **PNG 658x737** (that window plus
  the openbox frame), against `ref/viva_xl_calculator.png` at **687x1037**; the region-by-region
  side-by-side is `05-phase1e.md` §6. 244 checks say every control is present, of the right class and in
  the right initial state; **none says the window READS right.** **Two look debts stand, recorded and
  uncleared** (only the user clears one) — the phase-1 window against the reference, and the **four
  unexplained DRIFTS** §6 records and deliberately did NOT fix (no red rule / no coloured header *bar*;
  the Results row's `v`/`...` glyphs unwritten in the spec; hairline vs boxed selector groups; the
  browser's ~30% of first-open height against ~40%). Both debts predate the fix round and quote
  "226 checks" — read as **244**.
- **Reviewer findings raised but NOT confirmed: none** — that list came back empty; all four confirmed
  findings were fixed in the fix round, each with its own sabotage above.
- **Reviewer-marked NOT PROVEN, carried forward:** the 133 sabotage rows were reproduced independently
  only in part (a reviewer re-ran 3, the fixer 26); `full_audit.sh` was not run (item 99's); landmine
  **D6** is invisible under Xvfb by construction and no race was forced; **keyboard** reachability of
  the disabled controls is untested (`-takefocus 0` is set, no Tab/Return replay); the wheel is
  asserted by binding, not by pointer-follows on a real screen; and `W30 the pad holds exactly k1..k12,
  no more` is **self-referential** (a 13th key renames it rather than reddening it) — left as it is,
  because RULING-2's count is positively pinned by `W30 the keypad set is the twelve operator tokens`.
- **Nothing ran on `:0`** (batch policy); a **suite debt** for `test_calc_widgets` stands — CW11's four
  resize legs and CW2's twelve `winfo ismapped` legs poll exactly the geometry traffic WSLg delivers
  3-vs-1 against Xvfb. **Known-red elsewhere, not this item's doing:** `test_ase_window` (baseline
  FAIL, same line); `test_ase_core`/`test_ase_final` (item 1 §3); `test_wave_sigbrowser_keys`,
  `test_reopen_readonly`, `test_action_log_dispatch` at baseline.
- **The R113 walk's anti-vacuity floor** (≥85 widgets / ≥550 options / ≥320 palette-fed) is measured
  against today's window, not a pinned count: a later phase that legitimately **removes** controls will
  redden it. The file says so in a comment.
