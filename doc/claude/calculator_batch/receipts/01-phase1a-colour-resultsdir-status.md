# Item 01 — phase 1a: rulings, colour layer, Results Dir row, status area

Closing receipt. Ledger row 1; plan 1.1 / 1.8; spec §4 W03–W05, W30, W32–W34, R113, R506. Long-form working notes incl. the per-finding review log: `01-phase1a.md` (same dir). **Verdict `[E]`** — the payload is colour and layout; 192 green checks pin the values and say nothing about the look.

## 1. Files changed

```
 doc/claude/specs/calculator.md        |  97 +   4 -
 src/ase_window.tcl                    |  61 +  11 -
 src/calculator.tcl                    | 438 +  21 -
 tests/headless/test_calc_skeleton.tcl | 496 +   0 -
 4 files changed, 1092 insertions(+), 36 deletions(-)
```
New: `receipts/01-phase1a.md` (508 lines), `01-phase1a.png`, `01-phase1a-dropdown.png`, this file. No rebuild — both `.tcl` are runtime-sourced.

## 2. Decisions and evidence

**RULING-1 (driver) → spec §4.1 R113.** Now "colours come from the signal browser's palette, through one accessor", naming `ase::palette` and which role reads which source. Survivors of the old text: one palette, no hardcoded Cadence red. Ledger cited. Evidence: M04–M08, M76, M77b.

**RULING-2 (driver) → spec §4 table, W30.** Operators only; digits are typed. `grep -in digit doc/claude/specs/calculator.md` shows W30 was the only spec text naming digits; the phase-0 Keypad placeholder in `calculator.tcl` also said "digits" and was corrected. `PLAN.md:120` and `:135` still assume a digit pad — **not edited, the driver owns the plan** — flagged for items 4 and 7.

**Crew ruling → spec §8.1 R507–R510** (written into the unused gap between R506 and R601; nothing renumbered), because `calc::status` is called by every later item and its edges could not stay per-caller guesswork. R507: empty string clears the field, records nothing, returns what it wrote. R508: no window — and `--nogui`, where `winfo` does not exist — is a silent no-op that records nothing and never throws; the history belongs to the window, so close clears it. R509: 50 entries newest-first, the **oldest** drops, consecutive duplicates **kept** (`ciw_history` dedupes because it recalls *commands*; two identical status lines mean it happened twice, and hiding the second is the silence R506 forbids). R510: "reveals the last 50 messages" is a **rendering** requirement — a `-width 2` combobox whose popdown shows three characters does not satisfy W34. Evidence: M48–M58, M78, M90–M93c.

**Crew ruling (documented in the file header).** `.calc.res` stays a child of `.calc` (§4 paths are normative) and is drawn inside `.calc.pw.sel` via `pack -in` + `-before`; an explicit `raise .calc.res` is the guard, **not** creation order. M83 reddens when the raise goes; M84 (build the row first) stays green and is correct.

**Crew ruling: `src/ase_window.tcl` edited, outside the item's file list.** Unavoidable for two confirmed findings. (a) `ase::theme` is not a reader — it `font create`s and does a process-global `option add *TCombobox*Listbox.font`, so merely opening the Calculator changed the dropdown font of every combobox in xschem; a pure `ase::palette` was split out of it. (b) `fieldfg`/`selectbg`/`selectfg` were never declared by the browser and resolved from stock ttk; the browser now declares them on `Ase.Treeview` using the **measured** default values, so no pixel should move. `ase::theme`'s contract is unchanged for its ~30 callers; 12 ASE/browser suites green (§3).

**Disclosure the driver needs.** The brief says RULING-3/4/5 were "already written into spec §12", quoting the ledger. They were not — `git show HEAD:doc/claude/specs/calculator.md | grep -c RULED` → `0`. This item wrote those ~24 lines. §12 is *Open decisions*, not requirement text, and the text matches the ledger, so this is a disclosure gap, not a content one — but **three ledger rows need correcting**. LEDGER.md untouched (the driver owns it).

## 3. Tests

`tests/headless/test_calc_skeleton.tcl` — 140 new checks in S13–S16; phase-0 S1–S12 intact and unrenumbered.

```
RESULT: ALL PASS (192 checks)
```

Non-vacuity with `HEAD:src/calculator.tcl` **and** `HEAD:src/ase_window.tcl` in place: `RESULT: 133 FAILED (59 passed)`. (The first cut claimed 90/54; wrong, and one of its passers was vacuous — corrected, §5.)

**Audit diff vs `receipts/00b-audit-baseline-2026-08-14.txt`, by name and status, both directions.** 22 suites through `run_suites.sh` on `:99`:

| suite | baseline | now |
|---|---|---|
| test_calc_skeleton | PASS | PASS (52→192 checks) |
| test_wave_viewer, test_accelerators, test_bindings_file | PASS | PASS |
| test_wave_sigbrowser, _2pane, _sea, sigsearch, trace_menu | PASS | PASS |
| test_wave_tabs, test_wave_legend, test_wave_hilight | PASS | PASS |
| test_ase_dialogs, _dirty, _view, _plot, _persist, _launch, _interact | PASS | PASS |
| test_ase_window | FAIL | FAIL (unchanged, W7) |
| **test_ase_core** | PASS | **FAIL** — not this item |
| **test_ase_final** | PASS | **FAIL** — not this item |

Both ASE reds fail **identically with `HEAD:src/calculator.tcl` and `HEAD:src/ase_window.tcl` restored** — I ran that A/B myself and restored from byte-exact backups (md5 verified). Message: "ase: design … is not the current schematic; open its design window first" — which schematic is current, not theming. Baseline is HEAD 8423240a; this tree is 6ce8bf3d, five commits later. Pre-existing on the branch. **No suite moved because of this item.** `full_audit.sh` not run — the closing item owns it.

## 4. Sabotage table

Every sabotage reverted from a byte-exact backup (never `git checkout --`) and re-run green. Rows group by edit; the last column names the checks that reddened.

| id | broken | red? | green again? | checks reddened |
|---|---|---|---|---|
| M70 | `color_sources` reads `ase::theme` again (the first cut) | y | y | created no ASE font; combobox predates; combobox created after |
| M71,M73,M74 | browser drops `-foreground` / `selected` selectbg / selectfg on `Ase.Treeview` | y | y | browser applies fieldfg / selectbg / selectfg |
| M72 | `ttk::style map Ase.Treeview` loses its `disabled` entries | y | y | tree style kept disabled fg, disabled bg |
| M75 | `calc::palette`'s `error` on an unresolved role → `grey70` | y | y | a role with no source throws (all 9) |
| M76,M77b | role `fieldfg` from a literal; role `selectbg` from a nonexistent style name | y | y | fieldfg = ase::palette fieldfg; every role reads the browser's palette, and nothing else |
| M04–M08, M10b–M12b | `window`/`panel`/`header`/`field`/`accent`/`selectbg`/`selectfg`/`disabledfg` mis-sourced | y | y | the 8 role-equality checks + accent is the browser's red + panel/field differ from stock grey |
| M01,M03,M67 | role dropped from the list / `calc::color` returns `{}` on unknown / phantom role added | y | y | roles; unknown role errors; every role resolves non-empty |
| M13,M78 | `calc::status` loses its `winfo exists` / `info commands winfo` guard | y | y | status with no window is a no-op; no window records nothing; status after close; no winfo is a silent no-op; no winfo records nothing |
| M65,M66 | `calc::build` returns `{}`; `calc::close` does not destroy | y | y | S14 open returns .calc; S13 no window open |
| M79,M80,M81 | menubar/cascades lose `-foreground`/`-activeforeground`; menubar loses `-background`/`-activebackground` | y | y | menubar fg, active fg, bg, active bg, is not stock grey; every cascade takes a palette foreground |
| M14,M17,M18,M19,M32 | toplevel / outer pw / inner pw / status bar / `.calc.res` lose `-background` | y | y | the 5 matching background checks |
| M15,M16 | labelframe loses `-background` / `-foreground` | y | y | `$lf` background, title accent, is not stock grey (5 panes each) |
| M82 | pane hint `-foreground` → literal `grey40` | y | y | hint text is the muted role (all 5 panes) |
| M83 | `raise .calc.res` → `lower .calc.res` | y | y | row stacks above the panedwindow; row is topmost at its own centre |
| M85,M86,M87,M88b,M89b | toggle `-foreground`/`-activeforeground`; label `-background`; Browse `-disabledforeground`/`-foreground` | y | y | toggle wears the accent; keeps it on hover; label background; no control still stock grey; Browse disabled text is the muted role; Browse has a palette foreground |
| M21,M25–M28b | `.calc.res`/`.tog`/`.lab`/`.path`/`.browse` built as the wrong class | y | y | the 5 class checks |
| M22,M23,M68 | `-before` dropped / row never packed / row never built | y | y | packed into the Selectors pane first; row sits at the top; row is mapped; parent is .calc |
| M29,M30,M31,M33 | label text; `-state readonly`; `-readonlybackground`; Browse `-state disabled` | y | y | label text; path is readonly; path field colour; Browse stub disabled |
| M34,M35,M36b,M37 | `results_path` sentinel; no-raw wording emptied; refresh throws; full path → `file tail` | y | y | results_path with no raw; entry says no raw is loaded; entry reads as a sentence; refresh back to no-raw; loaded raw shows its full path; shim installed cleanly; shim was live and is now gone |
| M38–M42 | `res_toggle` return; partial collapse; wrong labels; wrong re-pack order | y | y | collapse hides all but the toggle; expand restores; collapsed & expanded slaves; both toggle relabels |
| M43b–M47 | msg/hist class, `-state`, `-readonlybackground` | y | y | msg class, msg readonly, hist class, hist readonly, field colour |
| M48–M58 | empty-string clear; early return; return value; message mangled; `lappend` not `linsert`; `-values` push deleted; dedupe added; `histmax` 60; cap keeps the tail | y | y | msg/history start empty; status returns what it wrote; msg shows it; history has it; newest first; dropdown reveals the history & capped too; empty string returns/cleared/recorded nothing; duplicates are kept; capped at 50; newest kept; oldest dropped |
| M59,M61,M62,M64,M93c | recall does not display / does not clear the button; close keeps history; `build_status` seeds a message; recall re-records | y | y | recall re-displays; recall cleared the button; close cleared the history; reopened window starts silent; recall recorded nothing |
| M90,M91,M92 | `Calc.TCombobox` `-postoffset` dropped / shrunk / widget points at stock style | y | y | dropdown is wider than the button; wide enough for the longest message |
| M84 | `.calc.res` built **before** the panedwindows | **no** | y | deliberate — the explicit `raise` is the guard and M83 tests it. Not a hole. |
| M88 | Browse `-disabledforeground` removed entirely | **no** | y | semantic no-op — `disabledfg` **is** the option DB's `grey50`, so the DB supplies the identical value. M88b reddens. |

**Unsabotaged — not evidence:** `S13 no ASE font existed before the Calculator was opened`; `S13 the stock dropdown font was readable at baseline`; `S13 every role has a source`; `S13 the palette resolves again once the source is back`; `S14 $lf hint background` (×5); `S14 every cascade takes the panel background`; `S15 toggle background`; `S15 toggle hover background`; `S15 label foreground`; `S15 Browse background`; `S16 the dropdown posts`; `S16 the pre-recall snapshot is a real 50-entry history`.

**Structurally weak:** `S15 .calc.res parent is .calc` can only fail when the widget is missing (the path fixes the parent and §4 forbids renaming it); `S14 open returns .calc` is a phase-0 assertion re-used as a fixture precondition. Four checks that pass against HEAD are **absence** assertions (the three font-purity ones plus "no ASE font existed") — a feature that does not exist has no side effects, so they cannot be non-vacuous by construction; their real evidence is M70.

## 5. What was NOT verified

- **The pixels.** Nothing ran on `:0` (batch policy — the user's screen); both captures are Xvfb `:99`. Unjudged: whether the accent as labelframe *title text* reads like the reference's coloured header *bar*; whether `v` and `...` stand in for the red triangle and folder icon; whether a 495px popdown opening leftwards from a 35px button reads as deliberate or broken; whether `#f2f2f2` panels beside xschem's `grey80` main window read as deliberate on a real screen. **Look debts recorded and uncleared** — only the user clears them. Suite debt `test_calc_skeleton` (a `:0` run) also uncleared.
- **The browser's own trees** after `ase::theme` was changed to declare `-foreground` and the selected/disabled map: values are the measured ttk defaults and 12 suites are green, but no suite sees a colour regression in the user's window. Look debt filed.
- **Reviewers' not-proven list, carried forward.** The deterministic trigger for the one-in-36 `Ase.Treeview` lookup fallthrough seen once (the mechanism is measured; the trigger is not — the source is now `ase::palette`, not a style lookup, which *should* remove it, but that is reasoning, not a reproduction). Whether the AseEntryFont leak ever caused a *visible* defect (the font change was proved, a broken dialog was not). The "full path" half of W05 with a **relatively** loaded raw — `xschem raw rawfile` returns `raw->rawfile` verbatim, so it is a full path only when the caller passed one; the test's shim passes an absolute path and no real `.raw` was loaded (fixture is item 6). Whether the disabled Browse stub or the disabled menu entries can be driven by keyboard (`-takefocus 0` confirmed; no Tab/Return replay). Landmine D6 under WSLg's extra Configure traffic.
- **Nothing was raised-but-unconfirmed** — all 19 reviewer findings were confirmed, and are fixed or, where the fix was "say the true thing", corrected in the spec and receipts: R113's false "no literal colour" (seven fallback literals incl. `#8b0000`; there are now zero executable literals, only documented values in comments), the false "these three roles come from the signal browser", the false "S15 … stacking is right", the wrong `wave_viewer.tcl:7861` citation (it is `:7886`), and the wrong 90/54 non-vacuity count (133/59, and `S16 recall recorded nothing` had compared two `pcall`s collapsing to the same `ERR:` string — rewritten, plus a positive control).
- **One observation deliberately not fixed:** the combobox popdown *listbox* is the option DB's light grey, not the palette's white `field`. `-fieldbackground` reaches the entry, not the lazily-created popdown; the only routes in are an option-DB pattern on a widget path or the process-global trick this round just removed. No requirement names it; no reviewer raised it.
- `full_audit.sh` not run. `test_ase_core` and `test_ase_final` are red on this branch at HEAD — the closing audit must not attribute them here.
