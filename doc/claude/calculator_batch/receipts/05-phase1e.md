# Item 05 — phase 1e: `test_calc_widgets.tcl`, the R101–R113 inventory sweep, and the eyeball

Closing receipt. Ledger row 5; plan **1.9 + 1.10**, the last phase-1 item. Spec §4 (W01–W34), §4.1
(R110–R113a), §5.1 R202, §7.1, R413, R507–R509, RULING-1/2/3. **Verdict `[E]`** — Part B is a
capture and a side-by-side, which only a human eye closes. **244 checks, 133 sabotages, 4 checks
named as unsabotaged.** No production code changed: `src/calculator.tcl` is byte-identical to HEAD
(`70933f40d903bac498050f32468e8c21` before and after every one of the 133 breaks).
The per-sabotage → per-check map is `05-phase1e-sabotage-map.md`, committed beside this.

> **FIX ROUND, 2026-08-15.** Review found four defects **in this item's own test file and receipt**,
> and this receipt is rewritten around them; §7 is the fix-round log with the sabotage evidence.
> In one line each: the inventory could not see a widget that was **built but never packed** (the
> LENS-2/LENS-3 reproducer: deleting `pack .calc.mode.clip` left both suites entirely green); the
> R113 colour scan was an allow-list of six option names and four colour words, so **every
> `-active*`/`-highlight*`/`-disabled*` literal was invisible** and CW12's 22-row shim table left 73
> of the window's 91 widgets outside the proof; the R111 amendment fixed the browser clause but left
> the **keypad "keeps natural height"** sentence in, which the build does not do and no check
> covered; and the eyeball receipt quoted the **capture's size wrongly** (658x737, not 656x680).
> `src/calculator.tcl` is still byte-identical to HEAD — every fix is in the test, the spec or here.

## 1. Files changed

```
 doc/claude/specs/calculator.md          |   +36   -5
 tests/headless/test_calc_widgets.tcl    | +1460   (new file, 244 checks)
```
Plus `receipts/05-phase1e.md` (this), `05-phase1e-sabotage-map.md`, `05-phase1e.png`. **No rebuild**
— the suite is a `--script` file and `calculator.tcl` is sourced at runtime (`xschem.tcl:14381`).
`src/calculator.tcl`, `LEDGER.md`, `recon/`, `ref/` untouched. Nothing else in this dirty tree staged.

## 2. Decisions taken, and the evidence

| ruling | evidence / why | written into |
|---|---|---|
| **The brief's "`calc::selmode` … is initialised (never the empty string)" is three requirements, and only one of them is `{}`-shaped.** `{}` stays the normative *unarmed* value (spec W07, R201); what may never be empty is the **`-tristatevalue`**; "initialised" means **seeded before the first radiobutton exists**. | the brief's parenthetical reads directly against W07 and against phase 1b's recorded crew ruling; asserting "selmode is never `{}`" would have required breaking R201. The seeding rule is the browser's own (`wave_viewer.tcl:8051-8082`): a `-variable` that does not exist yet is created by the widget at its off value | spec §4 W07; CW3 asserts all three separately |
| **R111 gains the function browser.** "Only the buffer and the stack take the extra vertical space" was written before the pane tree and named *widgets*; growth is a property of *panes*. | the build carries `.calc.pw.sel never`, `.buf/.stk always`, `.bot always`, `.bot.pad never` — every clause of R111 holds except that the row it never mentioned, the browser, is fed by `.calc.pw.bot`. That is **R112's** requirement (the browser is what *scrolls*), not a contradiction: pinned to natural height, 56 entries stay ten rows deep in an eight-row box however large the window gets. **No code changed** — the alternative fix would have been a phase-0 layout edit this item is forbidden to make | spec §4.1 R111; CW11 |
| **R110 is NOT a phase-1 gap.** The View cascade exists with its disabled placeholder; per-panel collapse is plan 10.1. | the plan's rule is "a control that is missing because it comes later is not allowed, a control that is inert is" — the inert control is there. The one collapse that IS implemented (W03's toggle) is asserted instead | CW11, and §5 below |
| **R113 is proved by MOVING THE SOURCE, never by comparing two colours.** CW12 shims `ase::palette`, rebuilds, and asserts 22 widgets followed; then restores and asserts they came back. | a check reading `.calc.sel cget -background` against `ase::palette panel` is equally green for a hardcoded `#f2f2f2` — vacuous evidence for a rule whose whole content is *through one accessor*. Measured: sabotage `B51` paints `.calc.sel` `#f2f2f2` by hand and the value-comparison stays true while CW12 goes red | spec §11.3 note; CW12 |
| **This file is an inventory, not a second geometry suite.** | `test_calc_skeleton` S11/S19/S21/S22/S23/S25 owns pixels, sash fractions, the derived minimum and the wheel. Proof the boundary is real and not a hole: sabotage `B75` (the category switch stops resetting the canvas view) reddens **nothing here** and reddens **S23 twice** in the skeleton — verified by running it | file header; §4 |
| **No W-row's widget is missing.** All 34 rows resolve, at the spec's paths, with the spec's classes. | CW2's 44 singleton legs + the 22/12/4 loops. Nothing had to be added, so nothing inert was invented | CW2 |
| **FIX ROUND — R111's keypad clause is finished, not quietly dropped.** Only the keypad's *width* and its *keys'* height are pinned; the frame grows with `.calc.pw.bot`. | measured on `:99`: `.calc.pad` 198 px at first open against `reqheight` 115, 345 px at `900x1000`, `.calc.pad.k1` 21 px throughout. The growth is the same `.calc.pw.bot -stretch always` that feeds the browser, so the two clauses cannot both be had without pinning the bottom pane. The empty band under the keys stays item 4's **look debt**, not a phase-0 layout edit | spec §4.1 R111; CW11 ×4, `SF12`/`SF13` each redden one leg alone |
| **FIX ROUND — R113's proof is a WALK, and the source scan anchors on the option-name SUFFIX.** | the window has 91 widgets / 580 colour options / 326 palette-fed; the 22-row table left 73 widgets and every `-active*`/`-highlight*`/`-disabled*` option outside the proof, and the scan's six-name allow-list could not see `-activebackground` at all. Both reproducers that were `ALL PASS (226)` now redden (`SF18`, `SF19`, `SF20`), and `SF21`/`SF22` show the walk catching a **cached** palette read that carries no literal for any scan to find | spec §11.3 test-table note; CW12 |
| **FIX ROUND — an inventory must ask whether a control is ON SCREEN.** `winfo exists` + class + `cget` is green for a widget that was built and never handed to a geometry manager. | `SF1` (delete `pack .calc.mode.clip`) was `ALL PASS` in **both** suites before the fix, including `W10 Clip is CHECKED at first open`, the check PLAN 1.9 names as this suite's own sabotage. CW2 now asserts `winfo manager` + `winfo ismapped` per W-row and the slave list of all nine containers | spec §11.3 note (3); CW2 ×12 |

## 3. Tests

`tests/headless/test_calc_widgets.tcl` — **new**, 244 checks in bands **CW1–CW13** (the W-row and
R-rule ids are the check names). Grepped both files: `test_calc_skeleton` uses `S1`–`S26` only and
carries no `W`/`R1`/`CW` check id, so the bands do not collide. **`test_calc_skeleton` is untouched:
still 503 checks, nothing renumbered, deleted or weakened.**

```
RESULT: ALL PASS (244 checks)          (run_suites.sh, dev display :99; + 3-run soak, all 244)
```

**Non-vacuity, measured against the tree where the feature does not exist** — `99a2edfd`'s
`src/calculator.tcl` (phase 0, the skeleton), because HEAD already contains all of phase 1:
`RESULT: 213 FAILED (31 passed)`, and **all 244 checks ran** — no group aborted, which took three
rounds of hardening to get (§5), and one more in the fix round: the new CW11 geometry legs read
`winfo height` through `wh`/`wrh`/`ww`/`wrw`, which answer a negative sentinel for a widget that is
not there. Written bare, `winfo height .calc.pad` **threw and aborted the whole of CW11** on a torn
build — measured, and fixed before the legs were kept. The 31 survivors are phase-0's own features
restated by the inventory (R101 ×5, W01 ×4, W02 ×5, the pane tree's R111 ×8, `.calc.status`'s
existence, the View cascade, R112's floor, `calc::close`) plus one fixture; all but that fixture are
sabotaged elsewhere.

**Audit diff vs `receipts/00b-audit-baseline-2026-08-14.txt`, by name and status, both directions**
— six suites through `run_suites.sh` on `:99`:

| suite | baseline | now |
|---|---|---|
| `test_calc_skeleton` | PASS | PASS (503) |
| `test_wave_viewer` | PASS | PASS (400) |
| `test_accelerators`, `test_bindings_file` | PASS | PASS |
| `test_wave_trace_menu` | PASS | PASS (397) |
| `test_ase_window` | **FAIL** | **FAIL** — the same single `W7 simulator produced output before Stop` line items 1/2/13 recorded |
| `test_calc_widgets` | *absent (new file)* | PASS (244) |

**No suite moved in either direction.** `full_audit.sh` is item 99's.

## 4. Sabotage

**107 breaks, every one applied to a byte-exact copy of `src/calculator.tcl`, run, and reverted from
that copy (never `git checkout --`), with the md5 re-verified after every restore.** The full table —
one row per sabotage, naming every check it reddened — is `05-phase1e-sabotage-map.md`. By family:

| family | breaks | what goes red |
|---|---|---|
| the seven `build_*` procs return early; the Stack list, the fn scrollbars and the whole toplevel never built | A1–A10, C2, C5 | 9–188 checks each; this is what makes the CW2 inventory and every `MISSING` leg evidence |
| initial state: Clip → 0 (**PLAN 1.9's own sabotage**), `-onvalue 2`, dest → Replace, category → Arithmetic, a selector armed, pickscope → wave, a seeded status line, undo/redo left enabled | B1–B3, B7, B10, C6, C7, C8 | the matching CW3 leg, one per break; `B1` reddens exactly `W10 Clip is CHECKED at first open` |
| class and readonly-ness: `.calc.res` as a labelframe, both comboboxes editable, the status entry and history editable, the path entry editable | C4, B5, B8, B43, B44, B68 | the CW2 class legs and the five `readonly` legs |
| labels and sets: Pop, M+, ME, a Stack button, a user button, the toolbar's ten, the six cascades, §7.1's categories, the twelve keys | B9, B11–B13, B18, B26, B28, B67, C9 | the label legs, `W16 the toolbar holds exactly the ten spec buttons`, `W02`, `W27` |
| the selector grid: a private radio variable, a `-value` that is not its own id, the tristate sentinel back to `{}`, `mp` un-disabled, the RF ids un-disabled, the refusal bind and the tooltips deleted, a refusal that arms | B20–B25, B74, C10 | the six W07 legs and the four R202/§1.2 legs |
| RULING-2: a digit key added to the pad | B27 | `W30 NO keypad button carries a digit` + 4 more |
| RULING-3 and the catalogue: `fn_dead_routes` forgets N, the `dft` row deleted, everything drawn live, the refusal emptied, D1 undone, D3 undone, a short row, the schema, a row claiming `All` | B29–B34, C11, C13, C15 | the seven RULING-3/D1/D3 legs |
| R413 and the status contract: hover records, hover from a second string, cap → 60, `linsert`→`lappend`, `record` ignored, the empty-string arm, recall re-records / does not clear | B35–B42, C16 | the twelve CW10 legs |
| R112a and R111/R112: the walk deleted, the `break` dropped, the combobox exclusion removed, `wm minsize` never applied, the buffer pane un-stretched, the status bar packed into a pane | B45–B50 | the six R112a/R111/R112 legs (`B50` reddens 146 — a status bar inside a pane wrecks the window) |
| **R113/R113a**: `.calc.sel` and the Stack caption painted with literals, the panel role reading the WRONG browser colour, an unresolved source defaulting to grey, `calc::color` answering `{}` for an unknown role, the state map dropped, `disabledfg` taken from the palette / made equal to the live colour, a role dropped from the list | B51, B51b, B52, B52b, B53, B54, C12, C17, C19 | the eleven CW12 legs, including both `-fieldbackground {readonly …}` map legs |
| inertness: `calc::inert` stops speaking, a key writes to the buffer, a selector wired to a later phase's proc, the toggle loses its command / never restores | B55–B58, B70, C20 | the six CW13 legs |
| the rest: the browser ignoring its own category, title, raise-instead-of-rebuild, `WM_DELETE_WINDOW`, close, buffer height/undo/read-only, the Results Dir label's default text and sentinel, both fn scrollbars | B59–B66, B69, B71b, B72, B73, C1, C3 | one to ten each; `B62` (a read-only buffer) reddens ten, `B65` (close does not destroy) six |

**Reddened nothing, and why — recorded, not hidden.** `B71` (the label's build-time `-text`) is a
**no-op on the product**: `calc::results_refresh` rewrites that label four lines later, so the value
never reaches the screen; `B71b`, which changes `calc::results_label`'s default, reddens the check.
`B75` (the category switch stops resetting the view) is covered by `test_calc_skeleton` S23, verified
by running it — see §2. `C6b` (the selector variable not seeded) reddens nothing because **Tk mints a
missing `-variable` when the widget is created**, which is exactly the trap W07's seeding rule names
and the reason that check is listed as unsabotaged below.

**And the one the first pass did not declare — `SF26`, added by the fix round.** Deleting BOTH canvas
item bindings in `calc::fn_fill` (`$c bind fn$i <Enter>` and `$c bind fn$i <Button-1>`) leaves this
file **`RESULT: ALL PASS (244 checks)`**, and `test_calc_skeleton` goes **`RESULT: 2 FAILED (501
passed)`** (`S23 every entry carries its own click and hover binding`, `S23 a real click on an entry
reaches its handler`) — both measured in the fix round, restored from the byte-exact copy after each.
The two checks that a reader would expect to cover it were named after the **gesture** while calling
the **handler**, so they are now named for what they call:
`RULING-3 calc::fn_click on a dead entry refuses, and names it (the canvas WIRING is
test_calc_skeleton S23's)` and `R413 calc::fn_hover writes the table's own help line (the <Enter>
WIRING is test_calc_skeleton S23's)`. Both are still real checks with their own sabotages
(`SF23` drops the function NAME from the refusal → the first goes red alone; `SF24` makes
`fn_hover` write a fixed string → the second goes red alone). **This is a naming/declaration fix,
not a coverage hole**: S23 owns the wiring and reddens under the break.

**Unsabotaged — NOT evidence (4 of 244).** `R101 no .calc before the first open` (a precondition; no
edit to `calculator.tcl` can make a window exist before its own first call); `W07 ::calc::selmode
exists` (see `C6b` — reddened only by the grid's absence, A1/C2); `R113 fixture: the running
calculator.tcl was located` (it asserts the TEST found the file it is about to read); and, added by
the fix round,
`R111 ...and the window went back to the size the rest of this file measures` — a **restore guard**
for the checks that run after CW11's resize, and four attempts to redden it with a product break
(`SF15` a 900x1000 minimum, `SF16` a `wm minsize` ratchet on `<Configure>`, `SF17` the keypad frame
ratcheting its own `-height`, `SF14` an unstretched bottom pane) all either left it green or reddened
its neighbours instead. **The first pass over-declared by one**: `R113 fixture: the real palette is a
colour, and not the shim's` is NOT unsabotaged — it reddens under the phase-0 revert, as the
verifier pointed out — so the list gains the restore guard and loses that one.

## 5. What was NOT verified

- **THE PIXELS — this is why the verdict is `[E]`.** `05-phase1e.png` is the first-open window on
  `:99`. **Its two numbers, both stated because the first pass gave only one and gave it to the
  wrong thing:** the client area is `wm geometry .calc` = **656x680**; the committed **PNG is
  658x737**, which is that window *plus the openbox frame* (`file …/05-phase1e.png` →
  `PNG image data, 658 x 737`). §6 is the region-by-region note against
  `ref/viva_xl_calculator.png`, which is **687x1037** (not the "~686x1050" the first pass wrote).
  Nothing ran on `:0` (batch policy). **Two look debts recorded and uncleared** (only the user clears
  one): the phase-1 window against the reference, and the four *unexplained drifts* §6 lists.
  A **suite debt** for `test_calc_widgets` is recorded too: its CW3 `bbox 4.0` leg and CW11's
  `wm minsize` derivation read real geometry, which is what WSLg's 3-vs-1 `<Configure>` traffic has
  moved before.
- **Three checks are structurally weak and say so in the file**: `W07 ::calc::selmode exists`
  (above); `R113 no role resolves to the empty string`, which cannot be reddened alone because
  `calc::palette` *throws* on an unresolvable source before any role can come back empty — its real
  evidence is the throw check beside it (`B52`); and the two `R113 fixture:` legs.
- **Not proven here**: that the wheel follows the *pointer* on a real screen (CW11 asserts the
  bindings exist; `event generate` dispatches by name); anything WSLg-specific, including landmine
  D6, which is invisible under Xvfb by construction; that the disabled controls cannot be reached by
  keyboard (`-takefocus 0` is set, no Tab/Return replay was done); and the *look* of any colour —
  CW12 proves the plumbing, not that `#8b0000` on `#f2f2f2` reads well.
- **One robustness fact about this suite, found the hard way and fixed**: a `calculator.tcl` that
  throws *during the build* left the earlier draft of CW4 spinning in a `for` whose bound was an
  `ERR:` string, and the run then hung until SIGTERM (xschem's emergency-save path). Every menu
  bound now goes through `mlast`, and the whole file reads widgets through `wcls`/`wcg`/`wkids`/
  `nsv`/`pslaves`, which answer `MISSING`/`NOVAR`/`{}` instead of throwing. That hardening is why
  all 226 checks run against a phase-0 tree instead of eight groups aborting.
- **`full_audit.sh` was not run** — item 99 owns it. `test_ase_core`/`test_ase_final` are red on this
  branch at HEAD (item 1 §3) and are not this item's doing.

## 6. Part B — the eyeball, region by region

`05-phase1e.png` (ours, first open on `:99`: **client area 656x680, PNG 658x737 including the
openbox frame**) against `ref/viva_xl_calculator.png` (Virtuoso Visualization & Analysis **XL**
calculator, **687x1037**). **Deliberate** = a driver ruling, a spec §13 deviation
or a recorded crew ruling. **DRIFT** = unexplained, and a candidate for a later item — *not fixed
here*, and no sash, `-minsize` or `pw_list` fraction was touched to make the capture look closer.

| region | matches | differs | verdict |
|---|---|---|---|
| title + menubar | the six cascades, in order: File Tools View Options Constants Help | ref carries a `cādence` wordmark and a red rule under the bar; ref underlines mnemonics | wordmark **deliberate** (never imitate a vendor's branding); the red rule and the mnemonics are **DRIFT** (no spec row asks for either; the rule is the clearest "panel header accent" the ref has) |
| Results row | a collapse handle at the left, a caption, a wide path field, a button at the right | ref is `In Context Results DB:` with a red triangle and a folder icon, plus a history dropdown; ours is `Results Dir:` with `v` and `...`, and no history dropdown | wording **deliberate** (spec §13: a `.raw` FILE, not a PSF directory); `v`/`...` for the triangle/folder is the same "no icon set exists" reasoning phase 1b ruled for W11/W12/W14 but is **not recorded in the spec for this row** — DRIFT, cheap to close by writing it down; the history dropdown has no W-row → out of scope |
| selector grid | two rows of eleven in three groups, radio indicators, group separators | ref's ids are `os`/`ot` and no `data`; ref shows all live; ref boxes each group in a frame and ends with a `»` overflow chevron | ids **deliberate** (spec §5 is normative, the XL screenshot is the *colour* reference only — RULING-1); the eight greyed ids **deliberate** (§1.2); hairline vs boxed groups is **DRIFT** (cosmetic); `»` has no W-row |
| mode strip | Off/Family/Wave, Clip **checked**, a destination combobox reading `Append` | ref's plot/eval are ICONS; ref also has a `Rectangular` (complex format) combobox, a `»` and a gear button | icons→text **deliberate** (spec §4 W11/W12/W14); the extra two controls have no W-row → out of scope v1, worth a spec line later |
| buffer + toolbar | a wide white buffer with a button row under it | ref's toolbar is ~14 ICONS (Pop-insert, expr, `fn`, undo, redo…); ours is ten words | **deliberate**, same ruling as the mode strip. Whether ten words read as a toolbar is a human call |
| keypad | a docked block of operator keys + four `user N` | ref is a floating `Key ...` palette holding a 4×4 **digit** pad | **deliberate** — RULING-2 (digits are typed) and the phase-0 pane tree. The ~180 px of empty pane under `user 3`/`user 4` is the item-4 look debt, still open |
| Stack | present: caption, four side buttons, an empty list | the XL reference shows **no Stack at all** | **deliberate** — the spec targets the **L** calculator's layout (W23–W25); the reference is the XL |
| function browser | a category chooser reading `Special Functions`, six alphabetical column-major columns, 14 greyed names, both scrollbars | ref has a red **`Function Panel` title BAR** with window buttons, an `fx` button, a **search field**, and `Function Panel | Expression Editor` tabs; ref's list is 6 columns of ~40 rows in a much taller window | greying **deliberate** (RULING-3); search/`fx`/tabs have no W-row → out of scope; **the red header BAR vs our accent-coloured labelframe TITLE TEXT is the open question receipt 01 raised and is still open — DRIFT** |
| status area | a readonly line with a small dropdown at the right | ref adds a `307` counter box below it | counter has no W-row → out of scope |
| proportions | the five regions in the reference's vertical order | ref is **687x1037** and gives the function panel ~40% of the height; ours is **656x680 of client area** (the PNG is 658x737 with the WM frame) and gives it ~30%, so column 6 of the list is off the right edge and 2 of 10 rows are below the fold at first open | **DRIFT, recorded not fixed** — the fractions are frozen (`calc::pw_list`), the browser genuinely scrolls (R112, measured `xview 0…0.71`, `yview 0…0.78`), and moving a fraction is exactly what this item may not do |

**The four unexplained drifts, as a punch-list for a later item**: (1) no red rule under the menubar /
no coloured header *bar* on a panel — the accent is title text only; (2) the Results row's `v` and
`...` glyph substitutions are unwritten in the spec; (3) hairline group separators vs the reference's
boxed groups; (4) the function browser's share of the first-open height. None is a regression, none
is fixed here.

**What the user should look at** (both debts are in `owed.sh`): the capture beside the reference, and
then the live window — whether the greyed selectors and the 14 greyed function names read as
*information* or as breakage, whether six columns of names are legible at the default size, and
whether the accent-as-title-text is enough of a "coloured panel header".

*(Both `owed.sh` entries were recorded before the fix round and quote "226 checks" and "the default
656x680". Read those as **244 checks** and as the **client** size — the PNG the debt points at is
658x737 with the openbox frame. The debts themselves are untouched; only the user clears one.)*

## 7. Fix round — the four review defects, and the evidence they are closed

Product code untouched throughout: `src/calculator.tcl` is `70933f40d903bac498050f32468e8c21` before
and after every break below (the md5 is re-checked by the sabotage harness after each restore, and
each restore is from a byte-exact copy, never `git checkout --`). The file grew 1195 → 1460 lines and
**226 → 244 checks**; nothing was renumbered, deleted or weakened, and `test_calc_skeleton` was not
touched at all (503, still green).

### 7.1 A widget that is BUILT but never PACKED passed the whole inventory *(major)*

`winfo exists` + `winfo class` + `cget` cannot see a control that no geometry manager ever got, and
that control is simply not on the user's screen. Reviewers demonstrated it on six W-rows; the sharpest
is W10, the row PLAN 1.9 names as this suite's own marquee sabotage — *Clip* could be off the window
while `W10 Clip is CHECKED at first open` stayed green, because the check reads `::calc::clip`. This
is also the trap `src/calculator.tcl`'s own build comment records as previously **measured**
("`winfo ismapped .calc.btb` was 0 and the whole button row was simply not on screen, with every
widget check green because the widgets all existed").

**Fix**, all in CW2, driven off the same `cw_wtable` so it covers every row at once: a
`winfo manager` leg, a `winfo ismapped` leg (with the spec table's own row count as the anti-vacuity
floor, and `.calc.mbar` exempted **by name, in its own check**, because a menubar is attached with
`-menu`), and the **slave list, in order, of every container the spec gives rows to** —
`pack slaves` for `.calc`, `.calc.res`, `.calc.mode`, `.calc.btb`, `.calc.status`, `grid slaves` for
`.calc.sel`, `.calc.stk`, `.calc.fn`, `.calc.pad`. 12 new checks. The probe confirmed every W-row
widget IS mapped today, so they went in green.

| sabotage | before the fix | after |
|---|---|---|
| `SF1` delete `pack .calc.mode.clip` | **ALL PASS (226)** — and `test_calc_skeleton` ALL PASS too | **3 FAILED**: managed, MAPPED, mode-strip slaves |
| `SF2` `grid .calc.stk.$id` guarded with `if {$id ne {recall}}` | **ALL PASS (226)** / skeleton ALL PASS | **3 FAILED**: managed, MAPPED, Stack slaves |
| `SF3` delete `pack .calc.status.hist` | **ALL PASS (226)** / skeleton ALL PASS | **3 FAILED**: managed, MAPPED, status slaves |
| `SF8` selector `data` never gridded | (same family) | **3 FAILED**: managed, MAPPED, selector-grid slaves |
| `SF9` `.calc.fn.hsb` never gridded | green here (skeleton caught it) | **3 FAILED**: managed, MAPPED, browser slaves |
| `SF10` `.calc.pad.u4` never gridded | (same family) | **3 FAILED**: managed, MAPPED, keypad slaves |
| `SF4` mode strip re-ordered (Eval before Plot) | — | **1 FAILED**, the order leg **alone** — the order check is independent of the mapped one |
| `SF6` toolbar re-ordered (ME before M+) | — | **1 FAILED**, the toolbar order leg alone |
| `SF7` `.calc.res.browse` never packed (NOT a W-row) | — | **2 FAILED**: the Results-row slave list — the leg that reaches beyond the W-table |
| `SF5` status bar packed after the pane tree | 1 red (R111) | **2 FAILED**: + `.calc` pack order |
| `SF11` `.calc configure -menu {}` | 1 red | **2 FAILED**: + the menubar-exemption check |

### 7.2 R113's two coverage mechanisms missed the commonest hardcoded colour *(major)*

The source scan alternated **six exact option names** followed by **four colour words**, so it could
not see any prefixed family — and the file carries **60 palette-fed colour options under prefixed
names** (`-activebackground` ×16, `-activeforeground` ×13, `-disabledforeground` ×12,
`-selectbackground` ×4, `-selectforeground` ×4, `-highlightbackground` ×3, `-readonlybackground` ×2,
`-fieldbackground` ×2, `-insertbackground` ×1). CW12's shim comparison was a **22-row hand table**
against a window that carries **91 widgets and 580 colour options**, and it never read
`-activebackground` at all.

**Fix, both halves.** (1) The scan now anchors on the option-name **suffix** and whitelists the
*value forms* instead of blacklisting colour words: after any
`-<anything>(background|foreground|color|colour)` the value must be a command substitution, a
variable, a brace group or a quoted string; plus any executable `#`-hex of any length; plus any X11
colour word **on a line that carries a colour option** (that last rule is what catches
`[list readonly white]` inside a ttk state map, where the value token is itself a `[`). Verified
against the pristine file: **0 offenders**. The bare-colour-word rule is deliberately NOT free-
floating — measured, it flags the catalogue's `tan()` row. (2) CW12 now **walks the live window**:
`cw_census` reads every widget × every option whose name ends in background/foreground/colour, a
baseline is taken under the real palette, the shim moves **every** role the calculator sources from
the browser (`selectbg`/`selectfg` added, so those are decidable too), the window is rebuilt, and
every pair whose baseline was a moved palette value must arrive at one of that colour's shimmed
values. Measured on the shipped build: **91 widgets, 580 options, 326 palette-fed, 0 stuck** — so the
assertion went in green. The 22-row named table is **kept beside it**, renamed `every NAMED widget…`,
because it names paths in its failure message and because it reaches `.calc.mbar`, a `Menu`, which
`cwalk` deliberately skips.

| sabotage | before the fix | after |
|---|---|---|
| `SF18` all 16 `-activebackground [calc::color header]` → `grey85` (LENS-1 reproducer a) | **ALL PASS (226)**, with `R113 … no executable colour literal` printed `ok` | **2 FAILED**: the scan names all 16 lines; the walk's coverage floor drops 326 → 310 |
| `SF19` `.calc.res.lab` → `-background red -foreground blue` (LENS-1 reproducer b) | **ALL PASS (226)** | **1 FAILED**: the scan, `711:-background=red -foreground=blue` |
| `SF20` all 3 `-highlightbackground` → `gray70` (LENS-3 reproducer) | **ALL PASS (226)** | **1 FAILED**: the scan, all 3 lines |
| `SF21` the ten toolbar buttons read a **cached** palette value (`calc::cached_panel`, resolved once) — **no literal anywhere**, so the scan is blind by construction | (not reachable by the old table either — none of the ten is in it) | **2 FAILED**: the walk names all ten stuck pairs; floor drops |
| `SF22` the same cache on **four** Stack buttons only | — | **1 FAILED**: the walk **alone** — the `stuck` list is the detector, not the floor |
| `SF25` (= the original `B51`) `.calc.mode` hand-painted `#f2f2f2`, the palette's own colour | 1 red (the named table) | **3 FAILED**: scan, named table, walk |

### 7.3 The R111 amendment left a clause the build does not honour *(minor)*

The item's own amendment fixed the function-browser omission and left the same sentence asserting
that the keypad "keeps natural height". Measured on `:99`: `.calc.pad` is **198 px** tall at first
open against a `reqheight` of **115**, and **345 px** at `900x1000`, while `.calc.pad.k1` stays
**21 px**. The growth arrives through `.calc.pw.bot -stretch always` — the clause the amendment
introduces as the *browser's* justification — so the two cannot both be had without pinning the
bottom pane. **The crew's ruling** (spec §4.1 R111, rewritten): only the keypad's **width** and its
**keys'** height are pinned; the frame grows and the extra is empty pane, which stays item 4's open
**look debt** rather than becoming a phase-0 layout edit this item may not make. The sentence now has
an oracle — 4 new CW11 legs, which resize the window and put it back.

| sabotage | what goes red |
|---|---|
| `SF12` `.calc.pad` packed `-expand 0` (frame pinned to natural height) | `R111 the keypad's FRAME grows with the bottom pane` — **alone** |
| `SF13` keys gridded `-sticky nsew` + row weight (keys stretch) | `R111 …while the KEYS keep their natural height` — **alone** |
| `SF14` `.calc.pw.bot -stretch never` | 3: the existing bottom-pane leg, FRAME-grows, and the fixture leg |
| `SF15` `apply_minsize` pins a 900x1000 minimum | 2: FRAME-grows and the fixture leg |

The fourth leg, `R111 …and the window went back to the size the rest of this file measures`, is a
**restore guard** and is declared **unsabotaged** in §4: `SF14`/`SF15`/`SF16` (a `wm minsize` ratchet
on `<Configure>`) and `SF17` (the keypad frame ratcheting its own `-height`) either left it green or
reddened its neighbours instead.

One hardening fact came out of this: written bare, `winfo height .calc.pad` **throws** on a torn
build and aborted the whole of CW11 (measured under `SF11`'s first, more destructive form). The legs
read through `wh`/`wrh`/`ww`/`wrw`, which answer a negative sentinel, so a missing widget is a failed
check and not a lost group — the same contract as `wcls`/`wcg`/`nsv`. All **244** checks run against
the phase-0 tree (`213 FAILED (31 passed)`, no group aborted).

### 7.4 The two gesture-named checks, and the capture's size *(minor, minor)*

Both are honesty fixes and are written up where a reader meets them: the check renames and the
zero-red declaration in **§4** (with `SF26`'s measurement, and `SF23`/`SF24` showing both checks
still redden on their own), and the capture's two numbers in **§5** and **§6** — client area
**656x680**, committed PNG **658x737** (window + openbox frame), reference **687x1037**.

### 7.5 Raised but NOT confirmed

None. The review returned an empty not-confirmed list, and the verifier's two remaining
observations were taken as written: the over-declared unsabotaged check (fixed in §4) and the
self-referential `W30 the pad holds exactly k1..k12` (left as it is — RULING-2's real count is
positively pinned by `W30 the keypad set is the twelve operator tokens`, which does go red; the
`k1..k$nk` leg is a widgets-vs-data consistency check and its name says so).
