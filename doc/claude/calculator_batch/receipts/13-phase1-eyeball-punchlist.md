# Item 13 — the phase-1 eyeball punch-list

A wheel scrolling, B ASE-L's greyed Calculator entry, C Results Dir against a neighbouring raw, D a
`.sh` suite debt `drain` could never pay. Verdict **[E]** — A/B/C are behaviour, feel and wording.

## 1. Files changed

`git diff --stat`: **9 files, 1178 insertions(+), 23 deletions(-)** — `src/calculator.tcl` 333,
`src/ase_window.tcl` 21; `test_calc_skeleton.tcl` 492, `test_owed.sh` 104, `owed.sh` 95,
`test_ase_window.tcl` 48; specs `calculator.md` 53, `owed.md` 50, `ase_l.md` 5. Plus this receipt
(new). Nothing rebuilt — both `.tcl` sources are read at runtime, no `Makefile.in` touched.

## 2. Decisions taken, and the evidence

**A — which widget gets the event.** X delivers the wheel to the window under the pointer; Tk runs
*that widget's* bindtags and never walks up the tree, so `bind .calc.fn.list` covers the canvas and
nothing around it. Copied, not re-invented, from the house `nhse_bind_wheel_tree`
(`xschem.tcl:1589`): walk each region, bind **every** widget, exclude ttk comboboxes and do not
descend into one (a combobox owns the wheel; its popdown is a child). Measured on Tk 8.6.14,
`Listbox`/`Text`/`Scrollbar` already had class wheel bindings and **`Canvas` has none** — the
function browser was the genuinely dead region the user hit. Every binding `break`s or one notch
scrolls twice. New **R112a**, `calculator.md` §4.1.

**A, two open questions ruled.** (1) The walk binds scrollbars too and replaces `Scrollbar`'s class
binding, so the house 1-unit canvas step made the fn scrollbar 3× *slower* than before the item.
Excluding `Scrollbar` was rejected — its binding is `v`-only, so a wheel over a *horizontal*
scrollbar would do nothing and a dead strip returns. **Step is 3 canvas units**: one notch over
`.calc.fn.vsb` measured 0.22058823529411764 with Tk's own binding, 0.0735294… at 1 unit,
0.22058823529411764 at 3. (2) The pane holders `.calc.pw.{bot.fn,buf,stk}` draw each title strip and
padding — 16.0/25.2/10.8% of the panes' visible area — and were wheel-dead, the content frames being
children of `.calc` packed with `-in` and so unreachable from a walk rooted there; now region roots.

**B.** `ase_window.tcl:561`: `-state disabled` → `-command calc::open`, with **no `$key`** unlike
every `ase::ui::` entry beside it — `calc::open` is per-*process* idempotent (R101) and a session key
would promise a per-session Calculator the spec forbids. Grepped the tree: the **only** remaining
stub (`xschem.tcl:15143`, `wave_viewer.tcl:17599` were live). `specs/ase_l.md` corrected.

**C, ruled (spec §4 rows W04/W05).** `calc::results_source` resolves **self → viewer → ase → none**.
The viewer read goes through `wviewer::enter_ctx`/`leave_ctx` with **`borrow 1`** — a bare switch
clobbers the viewer's title (0173), an unborrowed one is refused from a menu callback holding the
semaphore (0314) — and a **refused** ticket is skipped, never read as "no raw there". Provenance
goes on **W04's label** (`Results Dir (waveform viewer):`), not into the path (readonly *so it can
be copied*) nor a new widget (the row's slave order is normative); the long form is the `balloon`
tooltip, and `self`/`none` keep phase 1a's label byte-for-byte. **R705 holds** — live at build, at
the raise arm and on row expand; never cached.

**D, ruled (`specs/owed.md` R308/R309, plan rows O13–O15).** New `_suite_file` resolves
`<name>.tcl`, `<name>.sh` or a path. `.tcl` still goes through `run_suites.sh` (the gate enrolment);
`.sh` is executed directly with the display in **both** spellings and deliberately **ungated**, the
suites needing it being the gate's own self-tests — R307 gains the clause that mid-drain Stop covers
`.tcl` debts only. A name resolving to neither is a *misnamed debt*, reported with the paths
`_suite_file` really stat'd, not run, and kept.

## 3. Tests and results

| suite | baseline | now (verbatim) |
|---|---|---|
| `test_calc_skeleton` 438→**503** | PASS | `RESULT: ALL PASS (503 checks)` |
| `test_wave_viewer` | PASS | `RESULT: ALL PASS (400 checks)` |
| `test_accelerators` | PASS | `RESULT: ALL PASS` |
| `test_ase_window` 166→**169** | **FAIL** | `RESULT: 1 FAILED (168 passed)` |
| `test_owed.sh` 30→**52** | absent (a `.sh`) | `RESULT: ALL PASS (52 checks)` |

Diff vs `receipts/00b-audit-baseline-2026-08-14.txt`: **nothing moved in either direction**.
`test_ase_window` is FAIL at baseline and still FAIL, on `W7 simulator produced output before Stop`
— an ngspice-timing leg this item does not touch (3/3; a HEAD-reverted control gave the same one
failure). `test_owed` is NEW, not a regression (`full_audit.sh` globs `*.tcl`). All runs through
`run_suites.sh` on dev display `:99`, **no `:0` run**; flake soak after the review round, 20
consecutive `test_calc_skeleton`, 20/20 ALL PASS.

## 4. Sabotages

90 new/restated checks, 40 runs; rows group the runs and name every check each reddens. Every new
check is in ≥1 row bar the four below. All reverted byte-exact from backup and re-run green.

| # | broke | checks that went red (all Y red → Y green) |
|---|---|---|
| A1/A2 | the `wheel_bind_all` call, then the walk recursion | 23 S25: BUILD-bound, holder, all 6 `$seq`, 3 step, 12 gesture, walk-report |
| A3-6 | `; break` dropped; each region's step altered | `stack 5 units`/`buffer 50 pixels`/`fn 3 canvas units`, `one notch … ONCE`, `SCRIPT byte-identical` |
| A7/A14 | TCombobox exclusion removed; comboboxes as roots | `no binding on the category combobox`, `nor on plot-dest/status`, `…scrolls ITSELF` |
| A8/A9/A15 | `<MouseWheel>`, then the Shift rows, deleted; Button-4/5 signs flipped | those `$seq`, the `%D` leg, both Shift gesture legs, `Button-4 scrolls UP` + 6 gesture legs |
| A10-13 | popdown bindtags cleared / destroyed; class bindings forged; `-scrollregion` shrunk | `bindtags carry Listbox`, `popdown … holds a Listbox`, both `fixture:` class checks, `all three regions overflow` + 3 fn legs |
| E1/E7 | pane holders dropped from roots; a holder given a child | `holder really is the pane title strip`, 3 title-strip legs, BUILD-bound, walk-report |
| E2/E3/E4/E6 | canvas step 3→1; Shift-`%D` wrong axis+sign; `bind` appends; re-walk changes step | `fn is 3 canvas units`, `fn scrollbar still Tk's own step`, `<Shift-MouseWheel> moves the X axis`, `SCRIPT byte-identical`, `…moves once after it` |
| B1/B2 | `results_source` always `none`; probe loop above `self` | 11 S26 viewer/ase/entry/borrow legs + `a raw in THIS context outranks` |
| B3/B4/B5 | `borrow 0`; no `leave_ctx`; refused ticket read as answer | `borrow=1`, `…given back`, `REFUSED loan is skipped`, `no leave` |
| B6/B7 | final `none`→`self`; label default text changed | `phase-1a wording`, `R705 … live`, 4 label legs incl. `…re-resolve reached the label` |
| B8/B9/E8 | `wviewer::enter_ctx` renamed; `results_tip` stubbed; `balloon` attach deleted | `shims installed cleanly` + 6 viewer legs, `tooltip names the source and the path`, `the ROW really carries it`, `…balloon reverted with it` |
| B10/E9b/E14 | `ase_raw` takes the first key blindly; active-token block deleted; registry order reversed | `ASE-L session's raw is reported`, `session with no results is skipped`, `ACTIVE viewer outranks it`, `with no ACTIVE viewer, registry order decides` |
| E10b/E11b/E12 | expand-arm refresh deleted; collapse arm refreshes too; `results_source` memoised | `re-expanding … re-resolves it`, `collapsing does NOT refresh`, 15 S26 incl. `R705: nothing was cached`, `shim 2 gone … live again` |
| C1/C2/C3 | entry back to `disabled`; `calc::open $key`; no `destroy .calc` | 4 `W1m`/`W7v` checks + `Calculator closed again, toplevel set back` |
| D1/D2/D3/D3c | `.sh` fallback deleted; `.sh` sent to `run_suites.sh`; each display spelling dropped alone | 6 O14 incl. `exits 0`, `really ran`, `NOT through run_suites.sh`, and the two display checks **independently** |
| D4/D5/D7/D8/D10/D11b | failure branch deletes the debt / forces rc 0; unresolved branch deletes / passes / runs anyway; warning composed from the name | `FAILING .sh … non-zero`, `…debt is KEPT (R303)`, 9 O15 incl. `keeps the debt`, `records WHY`, `does not run the runner`, `ONE path it really stat'd`, no doubling |

**Unsabotaged — NOT evidence** (fixtures with no production subject): `S25 fixture cleaned up`;
`S26 shims are gone again` (needs a C edit + rebuild); `S26 a raw appeared … (shim installed)`;
`S26 shim 2 gone, and the row is live again`.

## 5. What was NOT verified

- **Eyeball owed — why the verdict is [E].** Four `look` debts are in the ledger and only the user
  clears them: wheel scrolling in all three regions; the Results Dir provenance wording; the ASE-L
  Tools menu's Calculator entry live; and the review round's feel changes (fn step 1→3 units, strips
  scroll). Two `suite` debts (`test_calc_skeleton`, `test_ase_window`) want a `:0` run each.
- **Raised but NOT confirmed, deliberately not acted on:** `calc::open`'s raise arm uses a bare `wm
  deiconify`/`raise`/`focus` instead of `raise_activate_toplevel` (0054's WSLg no-op) — phase-0 code
  this item did not introduce, the symptom could not be shown on `:99`, and fixing it would smuggle
  a phase-0 edit into a punch-list item.
- **Not proven by the reviewers:** that the wheel follows the *pointer* on a real screen (every leg
  uses `event generate <widget>`, dispatching by name — the bindings are proven present, X delivery
  is asserted Tk semantics); Part C end-to-end without shims (one reviewer could not build the
  fixture; the verifier reports a real unshimmed run against `tr_preserve.raw`); `calc::ase_raw`'s
  ordering with two sessions holding raws (no "active session" exists in `ase.tcl`, so the older can
  win — provenance is still shown); reentrancy of the new context switch during `build_res`; a
  `balloon` re-attach race; repaint cost with several viewers open; anything WSLg-specific; one
  unreproducible `wrong # args` throw out of `calc::open`, seen once in ~13 runs.
- **Out of scope, recorded:** `_suite_file` prefers `.tcl` over `.sh`, and
  `test_readonly_guard`/`test_readonly_action_dispatch` exist as both with the `.sh` as driver
  (pre-item behaviour; R308 does not rule on collisions); an `owed.sh add` id collision for two long
  path-shaped names (`cmd_add` untouched). `full_audit.sh` not run — the closing item owns it.
